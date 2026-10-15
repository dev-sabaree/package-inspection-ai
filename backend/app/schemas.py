from __future__ import annotations

from pydantic import BaseModel, Field


class BoundingBox(BaseModel):
    """A bounding box normalized to the original image dimensions."""

    xmin: float = Field(ge=0, le=1)
    ymin: float = Field(ge=0, le=1)
    xmax: float = Field(ge=0, le=1)
    ymax: float = Field(ge=0, le=1)


class Detection(BaseModel):
    label: str = Field(min_length=1)
    confidence: float = Field(ge=0, le=1)
    bounding_box: BoundingBox


class ImageInfo(BaseModel):
    width: int = Field(gt=0)
    height: int = Field(gt=0)
    content_type: str


class ModelInfo(BaseModel):
    name: str
    status: str
    message: str | None = None


class DetectionResponse(BaseModel):
    model: ModelInfo
    image: ImageInfo
    detections: list[Detection]


class HealthResponse(BaseModel):
    status: str
    model: ModelInfo
