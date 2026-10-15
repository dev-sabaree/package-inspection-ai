from __future__ import annotations

from io import BytesIO

from fastapi import FastAPI, File, HTTPException, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image, UnidentifiedImageError

from .config import Settings
from .inference import InferenceError, ModelUnavailableError, YoloInferenceAdapter
from .roboflow_inference import RoboflowInferenceAdapter
import os
from .schemas import DetectionResponse, HealthResponse, ImageInfo, ModelInfo

settings = Settings.from_environment()
app = FastAPI(title="Package Inspection AI API", version="0.1.0")
app.state.detector = (
    RoboflowInferenceAdapter()
    if os.getenv("ROBOFLOW_API_KEY", "").strip()
    else YoloInferenceAdapter(settings)
)

if settings.cors_allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_allowed_origins),
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
    )

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png"}
ALLOWED_FORMATS = {"JPEG": "image/jpeg", "PNG": "image/png"}


@app.middleware("http")
async def reject_oversized_requests(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length:
        try:
            if int(content_length) > settings.max_upload_bytes + 64 * 1024:
                return JSONResponse(
                    status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                    content={"detail": f"Upload exceeds the {settings.max_upload_bytes} byte limit."},
                )
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "Invalid Content-Length header."})
    return await call_next(request)


def _model_status() -> ModelInfo:
    return app.state.detector.model_info()


def _response_for_model_problem(*, image: ImageInfo, model_status: str) -> JSONResponse:
    safe_message = (
        "The configured model could not be loaded."
        if model_status == "unavailable"
        else "The model could not process this image."
    )
    info = _model_status().model_copy(update={"status": model_status, "message": safe_message})
    payload = DetectionResponse(model=info, image=image, detections=[])
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content=payload.model_dump(mode="json"),
    )


async def _decode_upload(upload: UploadFile) -> tuple[Image.Image, ImageInfo]:
    if upload.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=415, detail="Only JPEG and PNG image uploads are supported.")

    payload = await upload.read(settings.max_upload_bytes + 1)
    if not payload:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")
    if len(payload) > settings.max_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=f"Upload exceeds the {settings.max_upload_bytes} byte limit.",
        )

    try:
        with Image.open(BytesIO(payload)) as candidate:
            image_format = candidate.format
            candidate.verify()
        with Image.open(BytesIO(payload)) as candidate:
            if image_format not in ALLOWED_FORMATS:
                raise HTTPException(status_code=415, detail="Only JPEG and PNG image uploads are supported.")
            if candidate.width * candidate.height > settings.max_image_pixels:
                raise HTTPException(status_code=413, detail="Image dimensions exceed the pixel limit.")
            decoded = candidate.convert("RGB").copy()
    except HTTPException:
        raise
    except (UnidentifiedImageError, OSError, ValueError) as error:
        raise HTTPException(status_code=400, detail="The uploaded file is not a valid image.") from error

    return decoded, ImageInfo(
        width=decoded.width,
        height=decoded.height,
        content_type=ALLOWED_FORMATS[image_format],
    )


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    model = _model_status()
    return HealthResponse(status="healthy" if model.status == "ready" else "degraded", model=model)


@app.post("/api/v1/detect", response_model=DetectionResponse)
async def detect(file: UploadFile = File(...)) -> DetectionResponse | JSONResponse:
    image, image_info = await _decode_upload(file)
    try:
        inference = app.state.detector.detect(image)
    except ModelUnavailableError:
        return _response_for_model_problem(image=image_info, model_status="unavailable")
    except InferenceError:
        return _response_for_model_problem(image=image_info, model_status="error")

    return DetectionResponse(
        model=_model_status(), image=image_info, detections=inference.detections
    )
