import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

class UploadService {
  static const allowedTypes = ['jpg', 'jpeg', 'png'];

  /// Validates file extension and uploads image to the server.
  /// Returns the image URL if successful.
  static Future<String> uploadProofImage(File imageFile) async {
    final fileExtension = imageFile.path.split('.').last.toLowerCase();

    if (!allowedTypes.contains(fileExtension)) {
      throw Exception("Only JPG, JPEG, or PNG files are allowed.");
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://capstone.x10.mx/upload'),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', fileExtension),
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    try {
      final decoded = json.decode(utf8.decode(responseBody.codeUnits));
      print("🧪 RAW SERVER RESPONSE:\n$responseBody");

      if (decoded['success'] == true && decoded['url'] != null) {
        return decoded['url'];
      } else {
        throw Exception(decoded['error'] ?? 'Unknown upload error');
      }
    } catch (e) {
      print("❌ JSON decode error: $e");
      throw Exception("Failed to decode server response");
    }
  }
}
