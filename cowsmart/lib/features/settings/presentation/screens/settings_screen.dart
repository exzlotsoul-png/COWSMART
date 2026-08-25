import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/features/auth/providers/auth_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/finance/providers/finance_provider.dart';
import 'package:cowsmart/features/finance/domain/finance.dart';
import 'package:cowsmart/features/market/providers/market_price_provider.dart';
import 'package:cowsmart/features/farm/services/farm_pdf_export_service.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            icon: Icons.picture_as_pdf_rounded,
            title: 'ส่งออกรายงานสรุปภาพรวมฟาร์ม (PDF)',
            onTap: () => _exportFarmPdf(context, ref),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.edit,
            title: 'แก้ไขข้อมูลส่วนตัว',
            onTap: () {
              debugPrint('Tapped: Edit Profile');
              _navigateToEditProfile(context);
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.lock_outline,
            title: 'เปลี่ยนรหัสผ่าน',
            onTap: () => _navigateToChangePassword(context),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.settings_outlined,
            title: 'ตั้งค่าแอปพลิเคชัน',
            onTap: () => _navigateToAppSettings(context),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.help_outline,
            title: 'ช่วยเหลือและแนะนำการใช้งาน',
            onTap: () => _navigateToHelp(context),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutConfirm(context),
              icon: const Icon(Icons.logout),
              label: const Text('ออกจากระบบ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // App Version
          Center(
            child: Text(
              'Beef Farm v1.0.0',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  void _navigateToChangePassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  void _navigateToAppSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
    );
  }

  void _navigateToHelp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpScreen()),
    );
  }

  Future<void> _exportFarmPdf(BuildContext context, WidgetRef ref) async {
    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm == null) {
      AppFeedback.showError(context, 'ไม่พบข้อมูลฟาร์มสำหรับการส่งออกรายงาน');
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'กำลังประมวลผลข้อมูลรายงาน PDF...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final cows = ref.read(cowProvider).allCows;
      final breeds = ref.read(breedProvider);
      final zones = ref.read(zoneProvider).zones;
      final marketState = ref.read(marketPriceProvider);
      final financeState = ref.read(financeProvider);
      final user = ref.read(authProvider).user;
      final userName = user != null
          ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
          : null;

      final totalIncome = financeState.transactions
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);
      final totalExpense = financeState.transactions
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (sum, t) => sum + t.amount);
      final netBalance = totalIncome - totalExpense;

      await FarmPdfExportService.exportFarmOverviewReport(
        farm: currentFarm,
        cows: cows,
        breeds: breeds,
        zones: zones,
        marketState: marketState,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netBalance: netBalance,
        issuedBy: userName,
      );

      if (context.mounted) {
        AppFeedback.showSuccess(context, 'ส่งออกรายงาน PDF เรียบร้อยแล้ว');
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการสร้าง PDF: $e');
      }
    } finally {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('ออกจากระบบ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Pending image file (picked but not yet uploaded)
  XFile? _pendingImageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _firstNameController.text = user['first_name'] ?? '';
      _lastNameController.text = user['last_name'] ?? '';
      _phoneController.text = user['phone'] ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = ref.read(authProvider).user;

      // 1. Upload image if there's a pending one
      if (_pendingImageFile != null) {
        final uploadService = ref.read(imageUploadServiceProvider);
        await uploadService.uploadImage(
          type: 'avatar',
          entityId: user?['email'] ?? '',
          imageFile: _pendingImageFile!,
        );
      }

      // 2. Update profile data
      if (user != null) {
        final api = ref.read(apiClientProvider);
        final email = user['email'];
        await api.put('/users/$email', data: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        });
      }

      // 3. Refresh user data
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('บันทึกข้อมูลสำเร็จ'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Color? iconColor,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header with Avatar ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 28),
                  child: Column(
                    children: [
                      // ── Top bar ──
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'แก้ไขข้อมูลส่วนตัว',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Balance the back button
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Avatar ──
                      ImagePickerWidget(
                        currentImageUrl: user?['avatar_full_url'],
                        uploadType: 'avatar',
                        entityId: user?['email'] ?? '',
                        size: 110,
                        placeholderIcon: Icons.person_rounded,
                        showConfirmButtons: false,
                        borderColor: Colors.white.withValues(alpha: 0.6),
                        borderWidth: 3,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        onImagePicked: (file) {
                          setState(() {
                            _pendingImageFile = file;
                          });
                        },
                        onImageCancelled: () {
                          setState(() {
                            _pendingImageFile = null;
                          });
                        },
                      ),
                      if (_pendingImageFile == null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'แตะเพื่อเปลี่ยนรูปโปรไฟล์',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Form Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section label
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ข้อมูลส่วนตัว',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _firstNameController,
                            decoration: _inputDecoration(label: 'ชื่อ', icon: Icons.person_outline_rounded),
                            validator: (v) => v?.isEmpty ?? true ? 'กรุณากรอกชื่อ' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: _inputDecoration(label: 'นามสกุล', icon: Icons.badge_outlined),
                            validator: (v) => v?.isEmpty ?? true ? 'กรุณากรอกนามสกุล' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: _inputDecoration(
                              label: 'เบอร์โทรศัพท์',
                              icon: Icons.phone_outlined,
                              iconColor: AppColors.info,
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Save Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.check_rounded, size: 22),
                        label: Text(
                          _isSaving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primaryLight,
                          elevation: 2,
                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('รหัสผ่านใหม่ไม่ตรงกัน'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      // Ensure token is set
      final authState = ref.read(authProvider);
      if (authState.token != null) {
        api.setToken(authState.token);
      }

      final response = await api.post('/change-password', data: {
        'current_password': _currentPasswordController.text,
        'new_password': _newPasswordController.text,
        'new_password_confirmation': _confirmPasswordController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(response.data['message'] ?? 'เปลี่ยนรหัสผ่านสำเร็จ'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        String errorMsg = 'เกิดข้อผิดพลาด';
        if (e.response?.statusCode == 422) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'];
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _pwInputDecoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 12, right: 8),
        child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 22),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppColors.textHint,
          size: 22,
        ),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 32),
                  child: Column(
                    children: [
                      // ── Top bar ──
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'เปลี่ยนรหัสผ่าน',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Shield Icon ──
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(Icons.shield_rounded, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'เปลี่ยนรหัสผ่านเพื่อความปลอดภัย',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Form Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section label
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'รหัสผ่านปัจจุบัน',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Current password card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        decoration: _pwInputDecoration(
                          label: 'กรอกรหัสผ่านปัจจุบัน',
                          obscure: _obscureCurrent,
                          onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                        validator: (v) => v?.isEmpty ?? true ? 'กรุณากรอกรหัสผ่านปัจจุบัน' : null,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section label
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ตั้งรหัสผ่านใหม่',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // New password card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            decoration: _pwInputDecoration(
                              label: 'รหัสผ่านใหม่',
                              obscure: _obscureNew,
                              onToggle: () => setState(() => _obscureNew = !_obscureNew),
                            ),
                            validator: (v) => (v?.length ?? 0) < 6
                                ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัว'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: _pwInputDecoration(
                              label: 'ยืนยันรหัสผ่านใหม่',
                              obscure: _obscureConfirm,
                              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            validator: (v) => v?.isEmpty ?? true ? 'กรุณายืนยันรหัสผ่าน' : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Hint
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 6),
                          Text(
                            'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
                            style: TextStyle(fontSize: 12, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Change Password Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _changePassword,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.lock_reset_rounded, size: 22),
                        label: Text(
                          _isLoading ? 'กำลังเปลี่ยน...' : 'เปลี่ยนรหัสผ่าน',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primaryLight,
                          elevation: 2,
                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notifications = true;
  bool _darkMode = false;
  String _language = 'ไทย';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 32),
                  child: Column(
                    children: [
                      // ── Top Bar ──
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'ตั้งค่าแอปพลิเคชัน',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Icon Badge ──
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(Icons.settings_suggest_rounded, size: 42, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ปรับแต่งการทำงานของแอปตามที่คุณต้องการ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section 1: Notifications ──
                  const _SettingsSectionHeader(
                    title: 'การแจ้งเตือน',
                    barColor: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    child: SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      title: const Text(
                        'การแจ้งเตือนในแอป',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      subtitle: const Text(
                        'รับการแจ้งเตือนกำหนดการคาวและสุขภาพ',
                        style: TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                      secondary: _buildTileIcon(Icons.notifications_active_rounded, const Color(0xFFE8F0E4), AppColors.primary),
                      value: _notifications,
                      onChanged: (v) => setState(() => _notifications = v),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Section 2: Theme ──
                  const _SettingsSectionHeader(
                    title: 'การแสดงผล',
                    barColor: AppColors.info,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    child: SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      title: const Text(
                        'โหมดมืด (Dark Mode)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      subtitle: const Text(
                        'เปลี่ยนโทนสีแอปเป็นสีมืดเพื่อถนอมสายตา',
                        style: TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                      secondary: _buildTileIcon(Icons.dark_mode_rounded, const Color(0xFFE3F2FD), AppColors.info),
                      value: _darkMode,
                      onChanged: (v) => setState(() => _darkMode = v),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Section 3: Language ──
                  const _SettingsSectionHeader(
                    title: 'ภาษา / Language',
                    barColor: AppColors.warning,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    child: ListTile(
                      onTap: () => _showLanguageDialog(context),
                      leading: _buildTileIcon(Icons.language_rounded, const Color(0xFFFFF3E0), AppColors.warning),
                      title: const Text(
                        'ภาษาของแอปพลิเคชัน',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        _language,
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _language,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Section 4: System ──
                  const _SettingsSectionHeader(
                    title: 'ระบบ & ข้อมูล',
                    barColor: AppColors.secondary,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: _buildTileIcon(Icons.info_outline_rounded, const Color(0xFFF5F1E8), AppColors.secondary),
                          title: const Text(
                            'เวอร์ชันแอปพลิเคชัน',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'v1.0.0',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 60),
                          child: Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
                        ),
                        ListTile(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 10),
                                    Text('ล้างข้อมูลแคชสำเร็จเรียบร้อยแล้ว'),
                                  ],
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                          leading: _buildTileIcon(Icons.cleaning_services_rounded, const Color(0xFFFFEBEE), AppColors.error),
                          title: const Text(
                            'ล้างข้อมูลแคช',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          subtitle: const Text(
                            'คืนพื้นที่หน่วยความจำชั่วคราว',
                            style: TextStyle(fontSize: 12, color: AppColors.textHint),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 22),
                        ),
                      ],
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

  Widget _buildTileIcon(IconData icon, Color bgColor, Color iconColor) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.language_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('เลือกภาษา / Select Language', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLangTile('ไทย', 'ภาษาไทย', ctx),
            const SizedBox(height: 8),
            _buildLangTile('English', 'English (US)', ctx),
          ],
        ),
      ),
    );
  }

  Widget _buildLangTile(String code, String label, BuildContext ctx) {
    final isSelected = _language == code;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _language = code);
          Navigator.pop(ctx);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  final List<Map<String, String>> faqs = const [
    {
      'question': 'วิธีเพิ่มวัวใหม่เข้าสู่ระบบ',
      'answer': 'ไปที่เมนู "รายชื่อวัว" บริเวณแถบล่าง แล้วกดปุ่ม + ที่มุมขวาล่าง กรอกข้อมูลวัว สายพันธุ์ และรูปถ่าย จากนั้นกดบันทึก',
    },
    {
      'question': 'วิธีบันทึกการผสมพันธุ์และตั้งครรภ์',
      'answer': 'เข้าไปที่รายละเอียดของแม่วัว → เลือกแท็บ "การผสมพันธุ์" → กดปุ่ม "บันทึกผสมพันธุ์" ระบบจะคำนวณวันคลอดและสร้างแจ้งเตือนให้อัตโนมัติ',
    },
    {
      'question': 'วิธีบันทึกน้ำหนักและการเติบโต',
      'answer': 'เข้าไปที่รายละเอียดวัว → เลือกแท็บ "น้ำหนัก" → กดปุ่ม "บันทึกน้ำหนัก" ระบบจะคำนวณอัตราการเจริญเติบโต (ADG) ให้อัตโนมัติ',
    },
    {
      'question': 'ลืมรหัสผ่านทำอย่างไร',
      'answer': 'ในหน้าเข้าสู่ระบบ กดลิงก์ "ลืมรหัสผ่าน" กรอกอีเมลของคุณ ระบบจะส่งรหัส OTP 6 หลักไปยังอีเมลจริงของคุณเพื่อตั้งรหัสผ่านใหม่',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 32),
                  child: Column(
                    children: [
                      // ── Top Bar ──
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'ช่วยเหลือ & แนะนำ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Icon Badge ──
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(Icons.headset_mic_rounded, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ศูนย์ช่วยเหลือและคำถามที่พบบ่อย COWSMART',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── FAQ Section ──
                  const _SettingsSectionHeader(
                    title: 'คำถามที่พบบ่อย (FAQ)',
                    barColor: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  ...faqs.map(
                    (faq) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.quiz_rounded, color: AppColors.primary, size: 20),
                          ),
                          title: Text(
                            faq['question']!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Text(
                                faq['answer']!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Contact Section ──
                  const _SettingsSectionHeader(
                    title: 'ช่องทางติดต่อเรา',
                    barColor: AppColors.info,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0E4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.email_rounded, color: AppColors.primary, size: 22),
                          ),
                          title: const Text(
                            'อีเมลฝ่ายสนับสนุน',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          subtitle: const Text('support@cowsmart.com', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textHint),
                          onTap: () {},
                        ),
                      ],
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

// ── Shared Helper Components for Settings Screens ──

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  final Color barColor;

  const _SettingsSectionHeader({
    required this.title,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

