import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/features/auth/providers/auth_provider.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/settings/presentation/screens/settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('บัญชีผู้ใช้'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: user?['avatar_full_url'] != null
                    ? NetworkImage(user!['avatar_full_url'])
                    : null,
                child: user?['avatar_full_url'] == null
                    ? Icon(
                        Icons.person,
                        size: 48,
                        color: AppColors.primary.withOpacity(0.5),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${user?['first_name'] ?? 'ผู้ใช้'} ${user?['last_name'] ?? ''}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              user?['email'] ?? '',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            _buildMenuItem(
              context,
              icon: Icons.edit_outlined,
              title: 'แก้ไขข้อมูลส่วนตัว',
              onTap: () => _navigateToEditProfile(context),
            ),
            _buildMenuItem(
              context,
              icon: Icons.lock_outline,
              title: 'เปลี่ยนรหัสผ่าน',
              onTap: () => _navigateToChangePassword(context),
            ),
            _buildMenuItem(
              context,
              icon: Icons.settings_outlined,
              title: 'ตั้งค่าแอปพลิเคชัน',
              onTap: () => _navigateToAppSettings(context),
            ),
            _buildMenuItem(
              context,
              icon: Icons.help_outline,
              title: 'ช่วยเหลือและแนะนำการใช้งาน',
              onTap: () => _navigateToHelp(context),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('ออกจากระบบ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
}
