import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../data/inspection_api_client.dart';
import 'inspection_page.dart';

class LiveCameraPage extends StatefulWidget {
  const LiveCameraPage({super.key, this.apiClient});

  final InspectionApiClient? apiClient;

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage> {
  CameraController? _controller;
  bool _initializing = true;
  bool _processing = false;
  String? _error;

  InspectionApiClient get _apiClient =>
      widget.apiClient ?? InspectionApiClient();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available.');
      }
      final preferred = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        preferred,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _error =
              error.description ??
              'Unable to open camera. Check camera permission.';
          _initializing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to initialize the camera.';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _inspectFrame() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }
    setState(() => _processing = true);
    try {
      final photo = await controller.takePicture();
      final response = await _apiClient.inspect(
        bytes: await photo.readAsBytes(),
        filename: photo.name.toLowerCase().endsWith('.jpg')
            ? photo.name
            : 'camera_capture.jpg',
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DetectionResultPage(image: photo, response: response),
        ),
      );
    } on InspectionApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not capture or inspect this frame. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Live Camera Inspection')),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: _initializing
                    ? const CircularProgressIndicator()
                    : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : controller != null && controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      )
                    : const Text(
                        'Camera unavailable',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Aim at the package, keep it in focus, then inspect the captured frame.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _initializing || _error != null || _processing
                      ? null
                      : _inspectFrame,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.center_focus_strong),
                  label: Text(
                    _processing
                        ? 'Inspecting frame...'
                        : 'Inspect Current Frame',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
