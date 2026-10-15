from __future__ import annotations

import base64
import os
from typing import Any

import httpx
from PIL import Image

from .inference import InferenceError, InferenceResult, ModelUnavailableError
from .schemas import BoundingBox, Detection, ModelInfo


class RoboflowInferenceAdapter:
    def __init__(self) -> None:
        self.model_id = os.getenv(
            "ROBOFLOW_MODEL_ID", "detecting-a-damaged-parcel/6"
        ).strip()
        self.api_key = os.getenv("ROBOFLOW_API_KEY", "").strip()

    def model_info(self) -> ModelInfo:
        if not self.api_key:
            return ModelInfo(
                name=self.model_id,
                status="unavailable",
                message="ROBOFLOW_API_KEY is not configured.",
            )
        return ModelInfo(name=self.model_id, status="ready")

    def detect(self, image: Image.Image) -> InferenceResult:
        if not self.api_key:
            raise ModelUnavailableError("Roboflow API key is not configured.")

        import io

        buffer = io.BytesIO()
        image.convert("RGB").save(buffer, format="JPEG")
        encoded_image = base64.b64encode(buffer.getvalue()).decode("ascii")

        try:
            response = httpx.post(
                f"https://serverless.roboflow.com/{self.model_id}",
                params={
                    "api_key": self.api_key,
                    "confidence": 40,
                    "format": "json",
                },
                content=encoded_image,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                timeout=45.0,
            )
            response.raise_for_status()
            payload: dict[str, Any] = response.json()
        except (httpx.HTTPError, ValueError) as error:
            # Do not expose credentials or provider response bodies to clients.
            raise InferenceError("Roboflow inference request failed.") from error

        predictions = payload.get("predictions")
        if not isinstance(predictions, list):
            raise InferenceError("Roboflow returned an unexpected response.")

        detections: list[Detection] = []
        width, height = image.size

        for item in predictions:
            if not isinstance(item, dict):
                continue
            try:
                x = float(item["x"])
                y = float(item["y"])
                box_width = float(item["width"])
                box_height = float(item["height"])
                confidence = float(item["confidence"])
                label = str(item["class"]).strip()
            except (KeyError, TypeError, ValueError):
                raise InferenceError("Roboflow returned an invalid prediction.")

            if not label or not 0 <= confidence <= 1:
                raise InferenceError("Roboflow returned an invalid prediction.")

            xmin = max(0.0, min(1.0, (x - box_width / 2) / width))
            ymin = max(0.0, min(1.0, (y - box_height / 2) / height))
            xmax = max(0.0, min(1.0, (x + box_width / 2) / width))
            ymax = max(0.0, min(1.0, (y + box_height / 2) / height))

            if xmax <= xmin or ymax <= ymin:
                continue

            detections.append(
                Detection(
                    label=label,
                    confidence=confidence,
                    bounding_box=BoundingBox(
                        xmin=xmin, ymin=ymin, xmax=xmax, ymax=ymax
                    ),
                )
            )

        return InferenceResult(detections=detections)
