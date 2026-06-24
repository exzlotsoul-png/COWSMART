import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cowsmart/core/services/image_upload_service.dart';
import 'package:cowsmart/core/theme/app_colors.dart';

/// Reusable image picker widget with preview-then-upload flow.
///
/// Two modes:
/// 1. **Standalone** (showConfirmButtons = true):
///    Pick → Preview → Confirm/Cancel buttons → Upload
/// 2. **Form-integrated** (showConfirmButtons = false):
///    Pick → Preview → Parent calls upload via [onImagePicked] callback
class ImagePickerWidget extends ConsumerStatefulWidget {
  /// Current image URL to display (can be null)
  final String? currentImageUrl;

  /// Upload type: 'avatar', 'farm', 'cow'
  final String uploadType;

  /// Entity ID to send with the upload (email for avatar, farm_id, cow_id)
  final String entityId;

  /// Size of the widget (width & height)
  final double size;

  /// Shape of the widget
  final BoxShape shape;

  /// Placeholder icon when no image is set
  final IconData placeholderIcon;

  /// Called when upload succeeds, with the full API response
  final void Function(Map<String, dynamic> response)? onUploadSuccess;

  /// Called when user picks an image (before upload).
  /// Use this in form-integrated mode to get the pending file.
  final void Function(XFile file)? onImagePicked;

  /// Called when user cancels the pending image.
  final VoidCallback? onImageCancelled;

  /// Whether to show confirm/cancel buttons below the image.
  /// Set to false when the parent form handles the save/upload.
  final bool showConfirmButtons;

  /// Whether the widget is enabled for picking
  final bool enabled;

  const ImagePickerWidget({
    super.key,
    this.currentImageUrl,
    required this.uploadType,
    required this.entityId,
    this.size = 120,
    this.shape = BoxShape.circle,
    this.placeholderIcon = Icons.image,
    this.onUploadSuccess,
    this.onImagePicked,
    this.onImageCancelled,
    this.showConfirmButtons = true,
    this.enabled = true,
  });

  @override
  ConsumerState<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends ConsumerState<ImagePickerWidget> {
  bool _isUploading = false;
  String? _displayUrl;

  // Pending image (picked but not yet uploaded)
  XFile? _pendingFile;
  Uint8List? _pendingBytes;

  @override
  void initState() {
    super.initState();
    _displayUrl = widget.currentImageUrl;
  }

  @override
  void didUpdateWidget(covariant ImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentImageUrl != widget.currentImageUrl) {
      _displayUrl = widget.currentImageUrl;
    }
  }

  bool get _hasPendingImage => _pendingFile != null && _pendingBytes != null;

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'เลือกรูปภาพ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: const Text('เลือกจากคลังรูปภาพ'),
                subtitle: const Text('เลือกรูปที่มีอยู่ในเครื่อง'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(fromCamera: false);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.orange),
                  ),
                  title: const Text('ถ่ายรูป'),
                  subtitle: const Text('เปิดกล้องถ่ายรูปใหม่'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(fromCamera: true);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick image and show preview (no upload yet)
  Future<void> _pickImage({required bool fromCamera}) async {
    final uploadService = ref.read(imageUploadServiceProvider);

    final XFile? pickedFile = fromCamera
        ? await uploadService.pickImageFromCamera()
        : await uploadService.pickImageFromGallery();

    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();

    if (mounted) {
      setState(() {
        _pendingFile = pickedFile;
        _pendingBytes = bytes;
      });

      // Notify parent about the picked file
      widget.onImagePicked?.call(pickedFile);
    }
  }

  /// Cancel pending image and revert to original
  void _cancelPending() {
    setState(() {
      _pendingFile = null;
      _pendingBytes = null;
    });
    widget.onImageCancelled?.call();
  }

  /// Confirm and upload the pending image (standalone mode)
  Future<void> _confirmUpload() async {
    if (_pendingFile == null) return;

    setState(() => _isUploading = true);

    try {
      final uploadService = ref.read(imageUploadServiceProvider);
      final response = await uploadService.uploadImage(
        type: widget.uploadType,
        entityId: widget.entityId,
        imageFile: _pendingFile!,
      );

      if (mounted) {
        String? newUrl;
        if (response.containsKey('user')) {
          newUrl = response['user']?['avatar_full_url'] ?? response['user']?['avatar_url'];
        } else if (response.containsKey('farm')) {
          newUrl = response['farm']?['image_full_url'] ?? response['farm']?['image_url'];
        } else if (response.containsKey('cow')) {
          newUrl = response['cow']?['image_full_url'] ?? response['cow']?['image_url'];
        }

        setState(() {
          _isUploading = false;
          _pendingFile = null;
          _pendingBytes = null;
          if (newUrl != null) {
            _displayUrl = newUrl;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'อัปโหลดรูปภาพสำเร็จ'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        widget.onUploadSuccess?.call(response);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปโหลดไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Mark upload as complete from external call (used by parent form)
  void clearPending() {
    if (mounted) {
      setState(() {
        _pendingFile = null;
        _pendingBytes = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image display
        GestureDetector(
          onTap: (widget.enabled && !_isUploading) ? _showPickerOptions : null,
          child: Stack(
            children: [
              // Image container
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: widget.shape,
                  color: AppColors.primary.withOpacity(0.08),
                  border: Border.all(
                    color: _hasPendingImage
                        ? Colors.orange
                        : AppColors.primary.withOpacity(0.3),
                    width: _hasPendingImage ? 3 : 2,
                  ),
                ),
                child: ClipOval(
                  child: _hasPendingImage
                      ? Image.memory(
                          _pendingBytes!,
                          width: widget.size,
                          height: widget.size,
                          fit: BoxFit.cover,
                        )
                      : _displayUrl != null
                          ? Image.network(
                              _displayUrl!,
                              width: widget.size,
                              height: widget.size,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                widget.placeholderIcon,
                                size: widget.size * 0.4,
                                color: AppColors.primary.withOpacity(0.5),
                              ),
                            )
                          : Center(
                              child: Icon(
                                widget.placeholderIcon,
                                size: widget.size * 0.4,
                                color: AppColors.primary.withOpacity(0.5),
                              ),
                            ),
                ),
              ),

              // Loading overlay
              if (_isUploading)
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: widget.shape,
                    color: Colors.black45,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),

              // Camera button overlay
              if (widget.enabled && !_isUploading && !_hasPendingImage)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: widget.size * 0.15,
                      color: Colors.white,
                    ),
                  ),
                ),

              // "Pending" badge
              if (_hasPendingImage && !_isUploading)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ใหม่',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Confirm / Cancel buttons (only in standalone mode)
        if (_hasPendingImage && !_isUploading && widget.showConfirmButtons) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _cancelPending,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('ยกเลิก'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _confirmUpload,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('บันทึกรูป'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],

        // Uploading indicator
        if (_isUploading) ...[
          const SizedBox(height: 8),
          const Text(
            'กำลังอัปโหลด...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],

        // Hint text for form-integrated mode
        if (_hasPendingImage && !_isUploading && !widget.showConfirmButtons) ...[
          const SizedBox(height: 8),
          const Text(
            'เลือกรูปใหม่แล้ว — กด "บันทึก" เพื่ออัปโหลด',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
