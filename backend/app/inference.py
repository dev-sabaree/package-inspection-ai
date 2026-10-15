from __future__ import annotations

from importlib.util import find_spec
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image

from .config import Settings
from .schemas import BoundingBox, Detection, ModelInfo


class ModelUnavailableError(RuntimeError):
    """Raised when inference cannot be attempted because no usable model is loaded."""


class InferenceError(RuntimeError):
    """Raised when an already configured model fails while running inference."""


@dataclass(frozen=True)
class InferenceResult:
    detections: list[Detection]


class YoloInferenceAdapter:
    """Lazy Ultralytics adapter that turns YOLO result boxes into API schemas.

    Model import and loading are deliberately deferred until the first request so
    `/health` can accurately report an unconfigured service without requiring a
    GPU, model file, or the optional Ultralytics dependency at startup.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._model: Any | None = None
        self._load_error: str | None = None

    @property
    def model_name(self) -> str:
        path = self._settings.yolo_model_path
        return path.name if path else "unconfigured-yolo-model"

    def model_info(self) -> ModelInfo:
        model_path = self._settings.yolo_model_path
        if model_path is None:
            return ModelInfo(
                name=self.model_name,
                status="unavailable",
                message="YOLO_MODEL_PATH is not configured.",
            )
        if not model_path.is_file():
            return ModelInfo(
                name=self.model_name,
                status="unavailable",
                message="Configured model weights were not found.",
            )
        if find_spec("ultralytics") is None:
            return ModelInfo(
                name=self.model_name,
                status="unavailable",
                message="The optional ultralytics runtime is not installed.",
            )
        if self._load_error:
            return ModelInfo(name=self.model_name, status="error", message=self._load_error)
        return ModelInfo(name=self.model_name, status="ready")

    def _load_model(self) -> Any:
        info = self.model_info()
        if info.status != "ready":
            raise ModelUnavailableError(info.message or "Model is unavailable.")
        if self._model is not None:
            return self._model

        try:
            from ultralytics import YOLO

            self._model = YOLO(str(self._settings.yolo_model_path))
            return self._model
        except Exception as error:  # pragma: no cover - dependent on model runtime
            self._load_error = f"Unable to load YOLO weights: {error}"
            raise ModelUnavailableError(self._load_error) from error

    def detect(self, image: Image.Image) -> InferenceResult:
        model = self._load_model()
        try:
            options: dict[str, Any] = {"conf": self._settings.yolo_confidence, "verbose": False}
            if self._settings.yolo_device:
                options["device"] = self._settings.yolo_device
            result = model(image, **options)[0]
            return InferenceResult(detections=self._to_detections(result, image.width, image.height))
        except ModelUnavailableError:
            raise
        except Exception as error:  # pragma: no cover - dependent on model runtime
            raise InferenceError(f"YOLO inference failed: {error}") from error

    @staticmethod
    def _to_detections(result: Any, width: int, height: int) -> list[Detection]:
        boxes = getattr(result, "boxes", None)
        if boxes is None:
            return []

        names = getattr(result, "names", {})
        detections: list[Detection] = []
        for coordinates, confidence, class_id in zip(boxes.xyxy, boxes.conf, boxes.cls):
            xmin, ymin, xmax, ymax = (float(value) for value in coordinates.tolist())
            class_index = int(float(class_id))
            if isinstance(names, dict):
                label = names.get(class_index, str(class_index))
            elif isinstance(names, (list, tuple)) and 0 <= class_index < len(names):
                label = names[class_index]
            else:
                label = str(class_index)
            detections.append(
                Detection(
                    label=str(label),
                    confidence=float(confidence),
                    bounding_box=BoundingBox(
                        xmin=max(0.0, min(1.0, xmin / width)),
                        ymin=max(0.0, min(1.0, ymin / height)),
                        xmax=max(0.0, min(1.0, xmax / width)),
                        ymax=max(0.0, min(1.0, ymax / height)),
                    ),
                )
            )
        return detections
