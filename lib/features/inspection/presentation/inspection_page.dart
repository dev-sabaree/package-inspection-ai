
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class InspectionPage extends StatefulWidget {
  const InspectionPage({super.key});

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null && mounted) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not select image.')),
      );
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    // Temporary processing until AI integration.
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _isProcessing = false);

    final inspectAnother = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => DetectionResultPage(
          image: _selectedImage!,
        ),
      ),
    );

    if (inspectAnother == true && mounted) {
      setState(() => _selectedImage = null);
    }
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
                  color: Theme.of(context)
                      .colorScheme.surfaceContainerHighest,
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
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _isProcessing ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Select from Gallery'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Camera integration will be added later.'),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Use Camera (Coming Soon)'),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Processing...'),
                      ],
                    )
                  : const Text('Continue to Inspection'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetectionResultPage extends StatelessWidget {
  final XFile image;

  const DetectionResultPage({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detection Result')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _ImagePreview(image: image),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.hourglass_top_rounded,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              'Detection Pending',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your image is ready for inspection. '
              'AI detection will be connected later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.refresh),
              label: const Text('Inspect Another Image'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final XFile image;

  const _ImagePreview({required this.image});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: image.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Unable to display image.');
          }

          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }

          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
          );
        },
      );
    }

    return Image.file(
      File(image.path),
      fit: BoxFit.contain,
    );
  }
}
