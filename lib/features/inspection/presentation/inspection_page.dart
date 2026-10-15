import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/inspection_api_client.dart';

class InspectionPage extends StatefulWidget {
  const InspectionPage({super.key, this.apiClient});

  final InspectionApiClient? apiClient;

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isProcessing = false;
  String? _inspectionError;

  InspectionApiClient get _apiClient =>
      widget.apiClient ?? InspectionApiClient();

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
          _inspectionError = null;
        });
      }
    } catch (_) {
      if (mounted) _showMessage('Could not select image.');
    }
  }

  Future<void> _processImage() async {
    final image = _selectedImage;
    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _inspectionError = null;
    });
    try {
      final response = await _apiClient.inspect(
        bytes: await image.readAsBytes(),
        filename: image.name,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);
      final inspectAnother = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => DetectionResultPage(image: image, response: response),
        ),
      );
      if (inspectAnother == true && mounted) {
        setState(() => _selectedImage = null);
      }
    } on InspectionApiException catch (error) {
      _showInspectionFailure(error.message);
    } catch (_) {
      _showInspectionFailure('Could not inspect this image. Please try again.');
    }
  }

  void _showInspectionFailure(String message) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _inspectionError = message;
    });
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Inspection')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _selectedImage == null
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64),
                          SizedBox(height: 12),
                          Text('Select a package image to inspect'),
                        ],
                      )
                    : _ImagePreview(image: _selectedImage!),
              ),
            ),
            if (_inspectionError != null) ...[
              const SizedBox(height: 12),
              _InspectionFailureNotice(message: _inspectionError!),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _isProcessing ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Select from Gallery'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selectedImage == null || _isProcessing
                  ? null
                  : _processImage,
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Inspecting...'),
                      ],
                    )
                  : Text(
                      _inspectionError == null
                          ? 'Inspect Image'
                          : 'Try Inspection Again',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectionFailureNotice extends StatelessWidget {
  const _InspectionFailureNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$message You can try again with the selected image.',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetectionResultPage extends StatelessWidget {
  const DetectionResultPage({
    super.key,
    required this.image,
    required this.response,
  });

  final XFile image;
  final InspectionResponse response;

  @override
  Widget build(BuildContext context) {
    final hasDetections = response.detections.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Detection Result')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _DetectionImage(image: image, response: response),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ResultStatusCard(
              model: response.model,
              detectionCount: response.detections.length,
            ),
            if (hasDetections) ...[
              const SizedBox(height: 12),
              _DetectionSummary(detections: response.detections),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.refresh),
              label: const Text('Inspect Another Image'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStatusCard extends StatelessWidget {
  const _ResultStatusCard({required this.model, required this.detectionCount});

  final ModelStatus model;
  final int detectionCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelReady = model.status == 'ready';
    final hasDetections = detectionCount > 0;
    final color = !modelReady
        ? colorScheme.error
        : hasDetections
        ? colorScheme.tertiary
        : colorScheme.primary;
    final title = !modelReady
        ? 'Model unavailable'
        : hasDetections
        ? '$detectionCount ${detectionCount == 1 ? 'defect' : 'defects'} detected'
        : 'No defects detected';
    final description = !modelReady
        ? model.message ?? 'The inspection model is currently unavailable.'
        : hasDetections
        ? 'Each detected region is highlighted on the image.'
        : 'The model returned no detections. This does not confirm the parcel is safe.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color,
              foregroundColor: colorScheme.onPrimary,
              child: Icon(
                !modelReady
                    ? Icons.cloud_off_outlined
                    : hasDetections
                    ? Icons.warning_amber_rounded
                    : Icons.manage_search_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionSummary extends StatelessWidget {
  const _DetectionSummary({required this.detections});

  final List<InspectionDetection> detections;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 6,
    children: detections
        .map(
          (detection) => Chip(
            avatar: const Icon(Icons.report_problem_outlined, size: 18),
            label: Text(
              '${_formatDefectLabel(detection.label)} · ${_formatConfidence(detection.confidence)} confidence',
            ),
          ),
        )
        .toList(growable: false),
  );
}

class _DetectionImage extends StatelessWidget {
  const _DetectionImage({required this.image, required this.response});

  final XFile image;
  final InspectionResponse response;

  @override
  Widget build(BuildContext context) {
    final width = response.image.width.toDouble();
    final height = response.image.height.toDouble();
    if (width <= 0 || height <= 0) return _ImagePreview(image: image);

    // The image and its normalized boxes share this exact coordinate plane.
    // FittedBox then applies the same contain scaling to both.
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ImagePreview(image: image, fit: BoxFit.fill),
              for (final detection in response.detections)
                _DetectionBox(
                  detection: detection,
                  imageSize: Size(width, height),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetectionBox extends StatelessWidget {
  const _DetectionBox({required this.detection, required this.imageSize});

  final InspectionDetection detection;
  final Size imageSize;

  @override
  Widget build(BuildContext context) {
    final box = detection.boundingBox;
    final left = box.xmin.clamp(0.0, 1.0).toDouble() * imageSize.width;
    final top = box.ymin.clamp(0.0, 1.0).toDouble() * imageSize.height;
    final right = box.xmax.clamp(0.0, 1.0).toDouble() * imageSize.width;
    final bottom = box.ymax.clamp(0.0, 1.0).toDouble() * imageSize.height;
    return Positioned(
      left: left,
      top: top,
      width: (right - left).clamp(0.0, imageSize.width).toDouble(),
      height: (bottom - top).clamp(0.0, imageSize.height).toDouble(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.redAccent, width: 3),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: ColoredBox(
            color: Colors.redAccent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '${_formatDefectLabel(detection.label)} ${_formatConfidence(detection.confidence)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image, this.fit = BoxFit.contain});

  final XFile image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: image.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to display image.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Image.memory(snapshot.data!, fit: fit);
        },
      );
    }
    return Image.file(File(image.path), fit: fit);
  }
}

String _formatDefectLabel(String label) => label
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _formatConfidence(double confidence) =>
    '${(confidence.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';
