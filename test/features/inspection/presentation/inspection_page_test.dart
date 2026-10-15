import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_inspection_ai/features/inspection/data/inspection_api_client.dart';
import 'package:package_inspection_ai/features/inspection/presentation/inspection_page.dart';

void main() {
  late Directory temporaryDirectory;
  late XFile image;

  setUpAll(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'inspection_ui_test_',
    );
    final imageFile = File('${temporaryDirectory.path}/parcel.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLkWAAAAABJRU5ErkJggg==',
        ),
      );
    image = XFile(imageFile.path);
  });

  tearDownAll(() => temporaryDirectory.deleteSync(recursive: true));

  testWidgets('presents a clear defect summary and formatted confidence', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      image,
      _response(
        detections: [_detection('torn_seal', .92), _detection('dent', .81)],
      ),
    );

    expect(find.text('2 defects detected'), findsOneWidget);
    expect(find.text('Torn Seal · 92% confidence'), findsOneWidget);
    expect(find.text('Dent · 81% confidence'), findsOneWidget);
    expect(
      find.text('Each detected region is highlighted on the image.'),
      findsOneWidget,
    );
  });

  testWidgets('does not equate empty detections with parcel safety', (
    tester,
  ) async {
    await _pumpResult(tester, image, _response());

    expect(find.text('No defects detected'), findsOneWidget);
    expect(
      find.text(
        'The model returned no detections. This does not confirm the parcel is safe.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses source-image coordinates for normalized bounding boxes', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      image,
      _response(detections: [_detection('tear', .9)]),
    );

    final box = tester.widget<Positioned>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Positioned && widget.left == 100 && widget.top == 50,
      ),
    );
    expect(box.width, 400);
    expect(box.height, 200);
  });
}

Future<void> _pumpResult(
  WidgetTester tester,
  XFile image,
  InspectionResponse response,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DetectionResultPage(image: image, response: response),
    ),
  );
  await tester.pump();
}

InspectionResponse _response({
  List<InspectionDetection> detections = const [],
}) => InspectionResponse(
  model: const ModelStatus(name: 'Package detector', status: 'ready'),
  image: const InspectedImage(width: 1000, height: 500),
  detections: detections,
);

InspectionDetection _detection(String label, double confidence) =>
    InspectionDetection(
      label: label,
      confidence: confidence,
      boundingBox: const NormalizedBoundingBox(
        xmin: .1,
        ymin: .1,
        xmax: .5,
        ymax: .5,
      ),
    );
