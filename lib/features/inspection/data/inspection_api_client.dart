import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class InspectionApiException implements Exception {
  const InspectionApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class InspectionApiClient {
  InspectionApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:8000',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<InspectionResponse> inspect({
    required Uint8List bytes,
    required String filename,
  }) async {
    final mediaType = _mediaTypeForFilename(filename);

    if (mediaType == null) {
      throw const InspectionApiException('Please select a JPEG or PNG image.');
    }

    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/v1/detect'))
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: mediaType,
            ),
          );

    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));

      final response = await http.Response.fromStream(streamedResponse);

      final body = _decodeJson(response.body);

      if (response.statusCode == 200 || response.statusCode == 503) {
        if (body is Map<String, dynamic>) {
          return InspectionResponse.fromJson(body);
        }
      }

      final detail = body is Map<String, dynamic> ? body['detail'] : null;

      throw InspectionApiException(
        detail is String ? detail : 'Inspection request failed.',
        statusCode: response.statusCode,
      );
    } on InspectionApiException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      debugPrint('Inspection API error: $error');
      debugPrintStack(stackTrace: stackTrace);

      throw InspectionApiException('Inspection request failed: $error');
    }
  }

  dynamic _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  MediaType? _mediaTypeForFilename(String filename) {
    final extension = filename.split('.').last.toLowerCase();

    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      _ => null,
    };
  }
}

class InspectionResponse {
  const InspectionResponse({
    required this.model,
    required this.image,
    required this.detections,
  });

  final ModelStatus model;
  final InspectedImage image;
  final List<InspectionDetection> detections;

  bool get isModelReady => model.status == 'ready';

  factory InspectionResponse.fromJson(Map<String, dynamic> json) {
    return InspectionResponse(
      model: ModelStatus.fromJson(json['model'] as Map<String, dynamic>),
      image: InspectedImage.fromJson(json['image'] as Map<String, dynamic>),
      detections: (json['detections'] as List<dynamic>)
          .map(
            (item) =>
                InspectionDetection.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

class ModelStatus {
  const ModelStatus({required this.name, required this.status, this.message});

  final String name;
  final String status;
  final String? message;

  factory ModelStatus.fromJson(Map<String, dynamic> json) {
    return ModelStatus(
      name: json['name'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
    );
  }
}

class InspectedImage {
  const InspectedImage({required this.width, required this.height});

  final int width;
  final int height;

  factory InspectedImage.fromJson(Map<String, dynamic> json) {
    return InspectedImage(
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }
}

class InspectionDetection {
  const InspectionDetection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  final String label;
  final double confidence;
  final NormalizedBoundingBox boundingBox;

  factory InspectionDetection.fromJson(Map<String, dynamic> json) {
    return InspectionDetection(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: NormalizedBoundingBox.fromJson(
        json['bounding_box'] as Map<String, dynamic>,
      ),
    );
  }
}

class NormalizedBoundingBox {
  const NormalizedBoundingBox({
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
  });

  final double xmin;
  final double ymin;
  final double xmax;
  final double ymax;

  factory NormalizedBoundingBox.fromJson(Map<String, dynamic> json) {
    return NormalizedBoundingBox(
      xmin: (json['xmin'] as num).toDouble(),
      ymin: (json['ymin'] as num).toDouble(),
      xmax: (json['xmax'] as num).toDouble(),
      ymax: (json['ymax'] as num).toDouble(),
    );
  }
}
