import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/domain/farm.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';

class EditFarmScreen extends ConsumerStatefulWidget {
  final Farm farm;

  const EditFarmScreen({super.key, required this.farm});

  @override
  ConsumerState<EditFarmScreen> createState() => _EditFarmScreenState();
}

class _EditFarmScreenState extends ConsumerState<EditFarmScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  bool _isLoading = false;

  // Pending image file (picked but not yet uploaded)
  XFile? _pendingImageFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.farm.name);
    _addressController = TextEditingController(text: widget.farm.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveFarm() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อฟาร์ม')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Upload image if there's a pending one
      if (_pendingImageFile != null) {
        final uploadService = ref.read(imageUploadServiceProvider);
        await uploadService.uploadImage(
          type: 'farm',
          entityId: widget.farm.id,
          imageFile: _pendingImageFile!,
        );
      }

      // 2. Update farm data
      await ref
          .read(farmProvider.notifier)
          .updateFarm(farmId: widget.farm.id, name: name, address: address);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกข้อมูลฟาร์มเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลฟาร์ม'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Farm image picker (preview only, upload on save)
              Center(
                child: ImagePickerWidget(
                  currentImageUrl: widget.farm.imageFullUrl ?? widget.farm.imageUrl,
                  uploadType: 'farm',
                  entityId: widget.farm.id,
                  size: 120,
                  placeholderIcon: Icons.agriculture,
                  showConfirmButtons: false, // Parent handles save
                  onImagePicked: (file) {
                    _pendingImageFile = file;
                  },
                  onImageCancelled: () {
                    _pendingImageFile = null;
                  },
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'ข้อมูลฟาร์ม',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อฟาร์ม',
                  hintText: 'เช่น ฟาร์มวัวขุนสุขใจ',
                  prefixIcon: const Icon(Icons.agriculture_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ที่อยู่ / สถานที่',
                  hintText: 'เช่น 123 ม.4 ต.บ้านใหม่ อ.เมือง จ.เชียงใหม่',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'เจ้าของ: ${widget.farm.ownerEmail}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveFarm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'บันทึกการเปลี่ยนแปลง',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
