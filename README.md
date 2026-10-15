# package-inspection-ai
AI-powered real-time packaging defect detection system using Flutter, FastAPI, and custom YOLO.

## Backend MVP

The FastAPI image-inspection API lives in [`backend/`](backend/). It accepts JPEG
and PNG uploads, validates and decodes them, and returns normalized YOLO-style
detections. It does **not** fabricate detections: until compatible trained
weights are configured, `/api/v1/detect` returns an explicit `503` response with
`model.status` set to `unavailable`.

See [`backend/README.md`](backend/README.md) for setup, configuration, API
examples, and how to provide trained YOLO-compatible weights.

## Mobile API configuration

The Flutter app uploads the selected JPEG/PNG as multipart field `file` to
`POST /api/v1/detect`, then displays the model status and any returned normalized
detection boxes. Android emulator builds default to `http://10.0.2.2:8000`.

For a physical device or a deployed HTTPS API, provide the URL at build/run time:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

The debug Android manifest permits local clear-text HTTP only for emulator
development. Release builds should target HTTPS.
