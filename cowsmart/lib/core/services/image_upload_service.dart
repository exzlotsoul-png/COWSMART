import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
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
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
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
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.name.isNotEmpty && imageFile.name.contains('.') 
        ? imageFile.name 
        : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

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
