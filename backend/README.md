# Backend API

The backend is a FastAPI service for a mobile image-inspection workflow. It
validates JPEG/PNG uploads, reads their actual dimensions, and passes decoded
images to a YOLO-compatible Ultralytics model when compatible weights are
available.

It intentionally does not return placeholder or synthetic detections. With no
configured model, detection responds with `503 Service Unavailable`, an empty
`detections` list, and a structured `model.status` explaining why inference is
unavailable.

## Setup

From the repository root:

```bash
python3 -m venv backend/.venv
backend/.venv/bin/python -m pip install --upgrade pip
backend/.venv/bin/python -m pip install -r backend/requirements.txt
PYTHONPATH=backend backend/.venv/bin/python -m uvicorn app.main:app --reload --port 8000
```

Open `http://127.0.0.1:8000/docs` for interactive API documentation.

## Model configuration

Provide weights trained for your own packaging-defect classes; generic YOLO
weights are not evidence of reliable defect detection.

```bash
export YOLO_MODEL_PATH="$PWD/backend/models/package-defects.pt"
export YOLO_CONFIDENCE=0.40       # optional, defaults to 0.40
export YOLO_DEVICE=cpu            # optional; use a CUDA device only if configured
backend/.venv/bin/python -m pip install -r backend/requirements-model.txt
PYTHONPATH=backend backend/.venv/bin/python -m uvicorn app.main:app --port 8000
```

`backend/models/` is ignored by Git so model weights are never committed by
accident. The server lazy-loads the model on the first detection request.

### Browser access / CORS

Native Flutter apps do not use browser CORS. CORS is disabled by default for
the API. If the Flutter web target is used during development, set only the
specific trusted development origin—never `*`:

```bash
export CORS_ALLOWED_ORIGINS=http://localhost:5173
```

Production deployment still needs HTTPS, authentication/authorization, rate
limiting, a reverse proxy with request limits, monitoring, and restricted
network exposure. This MVP does not provide those controls.

## API

### `GET /health`

Returns HTTP 200 and reports whether the configured model is ready or the
service is degraded because weights are absent/unavailable.

### `POST /api/v1/detect`

Send one multipart field named `file`. Only JPEG and PNG images are accepted.
The default maximum file size is 10 MiB and the maximum decoded image size is
20 million pixels; override with `MAX_UPLOAD_BYTES` and `MAX_IMAGE_PIXELS`.

```bash
curl -X POST http://127.0.0.1:8000/api/v1/detect \
  -F "file=@package.jpg;type=image/jpeg"
```

Successful responses include the original image dimensions and detections:

```json
{
  "model": {"name": "package-defects.pt", "status": "ready", "message": null},
  "image": {"width": 1920, "height": 1080, "content_type": "image/jpeg"},
  "detections": [
    {
      "label": "tear",
      "confidence": 0.91,
      "bounding_box": {"xmin": 0.1, "ymin": 0.2, "xmax": 0.3, "ymax": 0.5}
    }
  ]
}
```

All bounding-box values are normalized to `[0, 1]`, relative to the uploaded
image. Missing weights and inference failures return the same response shape
with HTTP 503 and an empty `detections` list.

## Tests

```bash
PYTHONPATH=backend backend/.venv/bin/python -m pytest backend/tests -q
```
