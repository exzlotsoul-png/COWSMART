import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/domain/farm.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/features/auth/providers/auth_provider.dart';

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
      AppFeedback.showError(context, 'กรุณากรอกชื่อฟาร์ม');
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

      // 3. Re-fetch farms to ensure updated image URLs are fully synced in Riverpod state
      await ref.read(farmProvider.notifier).fetchFarms();

      if (mounted) {
        AppFeedback.showSuccess(context, 'บันทึกข้อมูลฟาร์มเรียบร้อยแล้ว');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Text('ยืนยันการลบฟาร์ม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'คุณต้องการลบฟาร์ม "${widget.farm.name}" ใช่หรือไม่?\n\nข้อมูลวัวและการบันทึกทั้งหมดในฟาร์มนี้จะถูกลบ และไม่สามารถกู้คืนได้',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ยกเลิก', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final success = await ref.read(farmProvider.notifier).deleteFarm(widget.farm.id);
                    if (mounted) {
                      setState(() => _isLoading = false);
                      if (success) {
                        AppFeedback.showSuccess(context, 'ลบฟาร์มเรียบร้อยแล้ว');
                        context.go('/select-farm');
                      } else {
                        final error = ref.read(farmProvider).errorMessage ?? 'เกิดข้อผิดพลาดในการลบฟาร์ม';
                        AppFeedback.showError(context, error);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('ลบฟาร์ม', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final ownerName = (user != null)
        ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
        : widget.farm.ownerEmail;

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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  child: Column(
                    children: [
                      // Header Navigation Bar
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          ),
                          const Expanded(
                            child: Text(
                              'แก้ไขข้อมูลฟาร์ม',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Delete Farm Action Icon Button in Header
                          IconButton(
                            onPressed: _isLoading ? null : _showDeleteConfirmation,
                            tooltip: 'ลบฟาร์ม',
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ปรับแต่งชื่อ ที่อยู่ และรูปโปรไฟล์ของฟาร์ม',
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

          // ── Body Content ──
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
                            currentImageUrl: widget.farm.imageFullUrl ?? widget.farm.imageUrl,
                            uploadType: 'farm',
                            entityId: widget.farm.id,
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
                          controller: _nameController,
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
                            hintText: 'รายละเอียดที่อยู่...',
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
                        const SizedBox(height: 14),

                        // Owner Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfAlt(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 18, color: AppColors.subText(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'เจ้าของฟาร์ม: ${ownerName.isNotEmpty ? ownerName : widget.farm.ownerEmail}',
                                  style: TextStyle(color: AppColors.subText(context), fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Save Changes Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveFarm,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 22),
                      label: Text(
                        _isLoading ? 'กำลังบันทึก...' : 'บันทึกการเปลี่ยนแปลง',
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

                  const SizedBox(height: 14),

                  // Delete Farm Button
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _showDeleteConfirmation,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text(
                        'ลบฟาร์มนี้',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5), width: 1.5),
                        backgroundColor: AppColors.error.withValues(alpha: 0.05),
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
