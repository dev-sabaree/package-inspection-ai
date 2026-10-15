from __future__ import annotations

from io import BytesIO

from fastapi.testclient import TestClient
from PIL import Image

from app.inference import InferenceResult
from app.main import app
from app.schemas import BoundingBox, Detection, ModelInfo


def image_upload(image_format: str = "PNG", content_type: str = "image/png") -> dict[str, tuple[str, bytes, str]]:
    buffer = BytesIO()
    Image.new("RGB", (20, 10), color="white").save(buffer, format=image_format)
    return {"file": (f"package.{image_format.lower()}", buffer.getvalue(), content_type)}


class FakeDetector:
    def model_info(self) -> ModelInfo:
        return ModelInfo(name="test-model.pt", status="ready")

    def detect(self, image: Image.Image) -> InferenceResult:
        return InferenceResult(
            detections=[
                Detection(
                    label="tear",
                    confidence=0.91,
                    bounding_box=BoundingBox(xmin=0.1, ymin=0.2, xmax=0.6, ymax=0.8),
                )
            ]
        )


def test_health_reports_unavailable_model_when_weights_are_not_configured() -> None:
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "degraded"
    assert body["model"]["status"] == "unavailable"


def test_detect_returns_normalized_detections_from_the_adapter() -> None:
    original_detector = app.state.detector
    app.state.detector = FakeDetector()
    try:
        with TestClient(app) as client:
            response = client.post("/api/v1/detect", files=image_upload())
    finally:
        app.state.detector = original_detector

    assert response.status_code == 200
    assert response.json() == {
        "model": {"name": "test-model.pt", "status": "ready", "message": None},
        "image": {"width": 20, "height": 10, "content_type": "image/png"},
        "detections": [
            {
                "label": "tear",
                "confidence": 0.91,
                "bounding_box": {"xmin": 0.1, "ymin": 0.2, "xmax": 0.6, "ymax": 0.8},
            }
        ],
    }


def test_detect_rejects_an_invalid_content_type() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/detect", files={"file": ("notes.txt", b"not an image", "text/plain")}
        )

    assert response.status_code == 415
    assert response.json()["detail"] == "Only JPEG and PNG image uploads are supported."


def test_detect_rejects_corrupt_image_content() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/detect", files={"file": ("fake.png", b"not a png", "image/png")}
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "The uploaded file is not a valid image."


def test_detect_rejects_a_request_with_an_oversized_content_length() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/detect",
            headers={"content-length": str(10 * 1024 * 1024 + 64 * 1024 + 1)},
        )

    assert response.status_code == 413
    assert "Upload exceeds" in response.json()["detail"]


def test_detect_reports_a_missing_model_without_fabricating_detections() -> None:
    with TestClient(app) as client:
        response = client.post("/api/v1/detect", files=image_upload())

    assert response.status_code == 503
    body = response.json()
    assert body["model"]["status"] == "unavailable"
    assert body["image"]["width"] == 20
    assert body["detections"] == []
