// lib/screens/cloudinary_service.dart
//
// ══════════════════════════════════════════════════════════════════
// CLOUDINARY — FREE image hosting (25GB free, no credit card)
//
// SETUP (sirf ek baar):
//   1. cloudinary.com par free account banao
//   2. Dashboard se ye 3 cheezein copy karo:
//      - Cloud Name
//      - Upload Preset (Settings > Upload > Add preset > Unsigned)
//   3. Neeche apni values daal do
// ══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // ▼▼▼ YAHAN APNI VALUES DAALEIN ▼▼▼
  static const String cloudName    = 'dfdtvifsm';   // e.g. 'karim-nagar'
  static const String uploadPreset = 'kn_preset'; // e.g. 'kn_unsigned'
  // ▲▲▲ ▲▲▲ ▲▲▲

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Image upload karo — permanent HTTPS URL milega
  /// Koi bhi phone par yeh URL se picture dikhe gi
  static Future<String> uploadImage(File imageFile, {String folder = 'karim_nagar'}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder']        = folder;
      request.fields['quality']       = 'auto:low';

      request.files.add(await http.MultipartFile.fromPath(
        'file', imageFile.path,
      ));

      final response = await request.send();
      final body     = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(body);
        final url  = json['secure_url'] as String? ?? '';
        debugPrint('Cloudinary upload OK: $url');
        return url;
      } else {
        debugPrint('Cloudinary error ${response.statusCode}: $body');
        return '';
      }
    } catch (e) {
      debugPrint('Cloudinary upload failed: $e');
      return '';
    }
  }
}