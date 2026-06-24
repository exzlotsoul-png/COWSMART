import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';

class CreateFarmScreen extends ConsumerStatefulWidget {
  const CreateFarmScreen({super.key});

  @override
  ConsumerState<CreateFarmScreen> createState() => _CreateFarmScreenState();
}

class _CreateFarmScreenState extends ConsumerState<CreateFarmScreen> {
  final _farmNameController = TextEditingController();
  final _addressController = TextEditingController();
  
  XFile? _pendingImageFile;
  bool _isSaving = false;

  @override
  void dispose() {
    _farmNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _createFarm() async {
    final name = _farmNameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newFarm = await ref
          .read(farmProvider.notifier)
          .addFarm(name: name, address: address);

      if (newFarm != null) {
        // Upload image if selected
        if (_pendingImageFile != null) {
          try {
            final uploadService = ref.read(imageUploadServiceProvider);
            await uploadService.uploadImage(
              type: 'farm',
              entityId: newFarm.id,
              imageFile: _pendingImageFile!,
            );
            // We don't strictly need to sync the farm here because it will be refetched
            // or the user is going to the zone creation screen anyway.
          } catch (e) {
            print('[ERROR] อัปโหลดรูปภาพฟาร์มไม่สำเร็จ: $e');
          }
        }

        if (mounted) {
          context.push('/create_zone');
        }
      } else if (mounted) {
        final error =
            ref.read(farmProvider).errorMessage ??
            'เกิดข้อผิดพลาดในการสร้างฟาร์ม';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('สร้างฟาร์มใหม่')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'ข้อมูลฟาร์มของคุณ',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'เพิ่มฟาร์มใหม่เพื่อเริ่มต้นการจัดการ',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Farm Image Picker
              Center(
                child: ImagePickerWidget(
                  currentImageUrl: null,
                  uploadType: 'farm',
                  entityId: '', // Entity ID will be assigned after creation
                  size: 140,
                  placeholderIcon: Icons.agriculture,
                  showConfirmButtons: false,
                  onImagePicked: (file) {
                    _pendingImageFile = file;
                  },
                  onImageCancelled: () {
                    _pendingImageFile = null;
                  },
                ),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _farmNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อฟาร์ม',
                  hintText: 'ฟาร์มวัวเนื้อ...',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่ฟาร์ม',
                  hintText: 'รายละเอียดที่อยู่...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48.0),
                    child: Icon(Icons.location_on_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: _isSaving || farmState.isLoading ? null : _createFarm,
                child: _isSaving || farmState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('สร้างฟาร์ม และไปต่อ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
