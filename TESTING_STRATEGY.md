# 📋 Testing Strategy: Mobile App, Backend API & AI Inference

## 1. Overview & Scope
This document outlines the testing strategy for the end-to-end image detection pipeline across the Flutter mobile app, FastAPI backend, and YOLO inference engine.

---

## 2. Standard Bug Report Format
All bugs discovered during manual or automated testing must follow this template:

### Title: [Short, descriptive summary of the bug]

**Environment:**
- Device / OS: [e.g., Pixel 7 / Android 14 or iPhone 13 / iOS 17]
- App Build / Commit: [e.g., v0.1.0 or commit hash]
- Backend URL / Environment: [e.g., localhost:8000 or staging.api.com]

**Steps to Reproduce:**
1. Open the app and navigate to the camera screen.
2. Capture a photo of an object in low light.
3. Tap "Analyze Image".

**Expected Result:**
[Describe what should have occurred, e.g., A loading indicator appears followed by detection results with bounding boxes.]

**Actual Result:**
[Describe what actually happened, e.g., The app freezes on a white screen with no error feedback.]

**Error / Log:**
```
[Paste relevant Flutter debug console output or FastAPI terminal log here]
```

**Screenshot / Recording:**
[Attach a screenshot or screen recording showing the error]

**Severity:** [Low / Medium / High / Critical]

---

## 3. Initial Test Cases Matrix

### A. Mobile App (Flutter)
| Test ID | Test Scenario | Steps | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-MOB-01** | Camera Permission Grant | Open camera for first time; tap "Allow". | Viewfinder opens smoothly with live camera feed. |
| **TC-MOB-02** | Camera Permission Denial | Open camera; tap "Deny". | Informative empty state screen appears with button: *"Grant Permission in Settings"*. |
| **TC-MOB-03** | Image Pick from Gallery | Tap gallery icon; select valid `.jpg` image. | Image preview loads with an active "Scan" button. |
| **TC-MOB-04** | Detection Loading State | Tap "Scan / Analyze". | Shimmer/spinner loads; user cannot spam the button repeatedly. |
| **TC-MOB-05** | Result Screen Rendering | Wait for backend response. | Image renders with colored bounding boxes and confidence percentages. |

### B. Backend API (FastAPI)
| Test ID | Test Scenario | Request Details | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-API-01** | Health Check | `GET /health` | Status `200 OK`, JSON: `{"status": "healthy"}`. |
| **TC-API-02** | Valid Image Upload | `POST /api/v1/detect` with valid `.jpeg` multipart file | Status `200 OK`, returns detected objects array with bounding coordinates and confidence scores. |
| **TC-API-03** | Invalid File Format | `POST /api/v1/detect` with `.txt` or `.pdf` file | Status `422 Unprocessable Entity` or `400 Bad Request` with message: *"Only JPEG/PNG supported"*. |
| **TC-API-04** | Empty Payload | `POST /api/v1/detect` with no file attached | Status `400 Bad Request` with descriptive validation error. |
| **TC-API-05** | Missing / Expired Auth | `POST /api/v1/detect` without Authorization token (if required) | Status `401 Unauthorized`. |

### C. AI Inference Flow (YOLO)
| Test ID | Test Scenario | Test Input | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-AI-01** | Standard Clear Image | High-res photo with 1 centered target object | Object detected with confidence score >= 0.75; tight bounding box. |
| **TC-AI-02** | Multi-Object Detection | Photo containing 3+ target objects | All target objects detected with individual bounding boxes. |
| **TC-AI-03** | Negative Test (No Target) | Photo of a blank wall or unrelated object | Status `200 OK` with empty detections list: `[]`. |
| **TC-AI-04** | Coordinate Normalization | Any detection | Bounding box coordinates [xmin, ymin, xmax, ymax] are normalized between 0.0 and 1.0. |

---

## 4. API Test Scenarios (Deep-Dive)

1. **Happy Path:**
   - Input: Clean `.jpg` image under 5 MB.
   - Output: HTTP `200 OK`, inference response time < 1500 ms.
2. **Payload Size Limit:**
   - Input: Image > 15 MB.
   - Output: HTTP `413 Payload Too Large`.
3. **Corrupted File:**
   - Input: Non-image file renamed to `photo.jpg`.
   - Output: HTTP `400 Bad Request` (*"Invalid image stream"*), no server crash.
4. **Concurrent Requests:**
   - Input: 10 concurrent requests to `/api/v1/detect`.
   - Output: All requests processed within acceptable latency without memory exhaustion.

---

## 5. Image Detection Test Scenarios (Deep-Dive)

1. **Varying Lighting:**
   - Test images taken in direct sunlight, dim room lighting, and night mode.
2. **Angles and Orientations:**
   - Test portrait, landscape, upside-down, and 45-degree angled shots.
3. **Partial Occlusion:**
   - Target object is 30%–50% covered by another object.
4. **Background Clutter:**
   - Target object placed in a noisy, complex background to test false positive rates.

---

## 6. Error & Edge Cases

| Layer | Edge Case | Expected System Behavior |
| :--- | :--- | :--- |
| **Mobile (Flutter)** | Device goes offline / Wi-Fi drops mid-upload | Shows clear error snackbar: *"Network connection lost. Please check your internet and try again."* (No crash). |
| **Mobile (Flutter)** | App sent to background while waiting for response | App resumes in loading state or safely recovers previous state without crashing. |
| **Backend (FastAPI)** | Model worker times out (> 10s) | Returns HTTP `504 Gateway Timeout` with message: *"Inference server took too long to respond."* |
| **Backend (FastAPI)** | High load / memory spike | Graceful error response rather than crashing the Uvicorn/FastAPI process. |
| **AI (YOLO)** | Extremely low confidence (< 0.25) | Filters out low-confidence predictions to prevent noisy bounding boxes on the UI. |
| **UI Rendering** | Bounding box at image extreme border (x=1.0, y=0.0) | Label badges do not clip off the mobile screen edge or cause RenderFlex layout overflow. |
