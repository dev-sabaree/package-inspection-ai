from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _positive_int(name: str, default: int) -> int:
    value = int(os.getenv(name, str(default)))
    if value <= 0:
        raise ValueError(f"{name} must be greater than zero")
    return value


@dataclass(frozen=True)
class Settings:
    """Runtime configuration read from environment variables."""

    max_upload_bytes: int
    max_image_pixels: int
    yolo_model_path: Path | None
    yolo_confidence: float
    yolo_device: str | None
    cors_allowed_origins: tuple[str, ...]

    @classmethod
    def from_environment(cls) -> "Settings":
        model_value = os.getenv("YOLO_MODEL_PATH", "").strip()
        confidence = float(os.getenv("YOLO_CONFIDENCE", "0.40"))
        if not 0 <= confidence <= 1:
            raise ValueError("YOLO_CONFIDENCE must be between 0 and 1")

        return cls(
            max_upload_bytes=_positive_int("MAX_UPLOAD_BYTES", 10 * 1024 * 1024),
            max_image_pixels=_positive_int("MAX_IMAGE_PIXELS", 20_000_000),
            yolo_model_path=Path(model_value).expanduser() if model_value else None,
            yolo_confidence=confidence,
            yolo_device=os.getenv("YOLO_DEVICE", "").strip() or None,
            cors_allowed_origins=tuple(
                origin.strip()
                for origin in os.getenv("CORS_ALLOWED_ORIGINS", "").split(",")
                if origin.strip()
            ),
        )
