import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/features/auth/providers/auth_provider.dart';

class ImageUploadService {
  final ApiClient _api;
  final Ref _ref;
  final ImagePicker _picker = ImagePicker();

  ImageUploadService(this._ref) : _api = _ref.read(apiClientProvider);

  /// Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
      );
    } catch (e) {
      debugPrint('❌ Error picking from gallery: $e');
      return null;
    }
  }

  /// Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
      );
    } catch (e) {
      debugPrint('❌ Error picking from camera: $e');
      return null;
    }
  }

  /// Upload image to server
  /// [type]: 'avatar', 'farm', or 'cow'
  /// [entityId]: email for avatar, farm_id for farm, cow_id for cow
  /// [imageFile]: XFile from image picker
  Future<Map<String, dynamic>> uploadImage({
    required String type,
    required String entityId,
    required XFile imageFile,
  }) async {
    // Ensure token is set
    final authState = _ref.read(authProvider);
    if (authState.token != null) {
      _api.setToken(authState.token);
    }

    // Build multipart form data
    var bytes = await imageFile.readAsBytes();
    
    // Compress image to avoid slow upload and PHP limits
    if (!kIsWeb) {
      try {
        final compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1024,
          minHeight: 1024,
          quality: 70,
        );
        bytes = compressedBytes;
      } catch (e) {
        debugPrint('❌ Image compression failed: $e');
      }
    }

    final filename = imageFile.name.isNotEmpty && imageFile.name.contains('.') 
        ? imageFile.name 
        : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // File size check (2MB limit to prevent server 422 error)
    final double fileSizeMB = bytes.length / (1024 * 1024);
    if (fileSizeMB > 2.0) {
      throw Exception('รูปภาพมีขนาดใหญ่เกินไป (${fileSizeMB.toStringAsFixed(2)}MB) \nระบบรองรับไม่เกิน 2MB กรุณาเลือกรูปอื่นหรือถ่ายรูปใหม่ครับ');
    }

    final formData = FormData.fromMap({
      'type': type,
      'entity_id': entityId,
      'image': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
    });

    final response = await _api.post('/images/upload', data: formData);
    return response.data as Map<String, dynamic>;
  }
}

/// Global provider
final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService(ref);
});
