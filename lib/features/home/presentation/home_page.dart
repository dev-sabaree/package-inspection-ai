import 'package:flutter/material.dart';

import '../../inspection/presentation/inspection_page.dart';
import '../../inspection/presentation/live_camera_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Package Inspection AI'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.inventory_2_outlined, size: 80),
            const SizedBox(height: 20),
            Text(
              'Smart Package Inspection',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inspect package images with our AI-powered workflow.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const InspectionPage(),
                  ),
                );
              },
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Start Inspection'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LiveCameraPage(),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Live Camera Inspection'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Inspection history will be added later.'),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('History'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings will be added later.'),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
