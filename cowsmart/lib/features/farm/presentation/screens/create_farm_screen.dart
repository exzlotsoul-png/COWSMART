import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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
          } catch (e) {
            debugPrint('[ERROR] อัปโหลดรูปภาพฟาร์มไม่สำเร็จ: $e');
          }
        }

        // Re-fetch farms to ensure updated image URLs are synced in Riverpod state
        await ref.read(farmProvider.notifier).fetchFarms();

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
      backgroundColor: AppColors.bg(context),
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 20),
                  child: Column(
                    children: [
                      // Top Row with Back Button
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                context.go('/select-farm');
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          ),
                          const Expanded(
                            child: Text(
                              'สร้างฟาร์มใหม่',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Balance back button space
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'กรอกข้อมูลเพื่อเริ่มต้นการจัดการฟาร์มของคุณ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body Form Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'รูปโปรไฟล์ฟาร์ม',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Image Picker Widget
                        Center(
                          child: ImagePickerWidget(
                            currentImageUrl: null,
                            uploadType: 'farm',
                            entityId: '',
                            size: 130,
                            placeholderIcon: Icons.agriculture_rounded,
                            showConfirmButtons: false,
                            onImagePicked: (file) {
                              _pendingImageFile = file;
                            },
                            onImageCancelled: () {
                              _pendingImageFile = null;
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Farm Name Field
                        Text(
                          'ชื่อฟาร์ม',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _farmNameController,
                          style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                          decoration: InputDecoration(
                            hintText: 'เช่น ฟาร์มวัวขุนสุขใจ...',
                            hintStyle: TextStyle(fontSize: 14, color: AppColors.hint(context)),
                            prefixIcon: const Icon(Icons.agriculture_rounded, color: AppColors.primary, size: 22),
                            filled: true,
                            fillColor: AppColors.surfAlt(context),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.8)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(14)),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Address Field
                        Text(
                          'ที่อยู่ฟาร์ม',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _addressController,
                          style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'รายละเอียดที่อยู่, ตำบล, อำเภอ, จังหวัด...',
                            hintStyle: TextStyle(fontSize: 14, color: AppColors.hint(context)),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 40),
                              child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
                            ),
                            filled: true,
                            fillColor: AppColors.surfAlt(context),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.8)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(14)),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || farmState.isLoading ? null : _createFarm,
                      icon: _isSaving || farmState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 22),
                      label: Text(
                        _isSaving || farmState.isLoading ? 'กำลังบันทึก...' : 'สร้างฟาร์ม และไปต่อ',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
