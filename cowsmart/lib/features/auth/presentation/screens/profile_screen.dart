import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/features/auth/providers/auth_provider.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/settings/presentation/screens/settings_screen.dart';
import 'package:cowsmart/features/settings/presentation/screens/report_issue_screen.dart';

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
    final firstName = user?['first_name'] ?? 'ผู้ใช้';
    final lastName = user?['last_name'] ?? '';
    final email = user?['email'] ?? '';
    final avatarUrl = user?['avatar_full_url'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header with Avatar ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      // ── Top Bar ──
                      const Center(
                        child: Text(
                          'บัญชีของฉัน',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Avatar ──
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? const Icon(Icons.person_rounded, size: 54, color: Colors.white70)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Name & Email ──
                      Text(
                        '$firstName $lastName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.email_outlined, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              email,
                              style: const TextStyle(color: Colors.white70, fontSize: 15),
                            ),
                          ],
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section: Account ──
                  const _SectionTitle(title: 'จัดการบัญชี'),
                  const SizedBox(height: 12),
                  _MenuCard(
                    children: [
                      _MenuTile(
                        icon: Icons.person_outline_rounded,
                        iconBgColor: const Color(0xFFE8F0E4),
                        iconColor: AppColors.primary,
                        title: 'แก้ไขข้อมูลส่วนตัว',
                        subtitle: 'ชื่อ, เบอร์โทร, รูปโปรไฟล์',
                        onTap: () => _navigateToEditProfile(context),
                      ),
                      const _MenuDivider(),
                      _MenuTile(
                        icon: Icons.lock_outline_rounded,
                        iconBgColor: const Color(0xFFFFF3E0),
                        iconColor: AppColors.warning,
                        title: 'เปลี่ยนรหัสผ่าน',
                        subtitle: 'ตั้งรหัสผ่านใหม่เพื่อความปลอดภัย',
                        onTap: () => _navigateToChangePassword(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Section: App ──
                  const _SectionTitle(title: 'แอปพลิเคชัน'),
                  const SizedBox(height: 12),
                  _MenuCard(
                    children: [
                      _MenuTile(
                        icon: Icons.tune_rounded,
                        iconBgColor: const Color(0xFFE3F2FD),
                        iconColor: AppColors.info,
                        title: 'ตั้งค่าแอปพลิเคชัน',
                        subtitle: 'การแจ้งเตือน, ธีม, ภาษา',
                        onTap: () => _navigateToAppSettings(context),
                      ),
                      const _MenuDivider(),
                      _MenuTile(
                        icon: Icons.help_outline_rounded,
                        iconBgColor: const Color(0xFFF3E5F5),
                        iconColor: const Color(0xFF9C6BAE),
                        title: 'ช่วยเหลือและแนะนำ',
                        subtitle: 'คู่มือการใช้งาน, ติดต่อเรา',
                        onTap: () => _navigateToHelp(context),
                      ),
                      const _MenuDivider(),
                      _MenuTile(
                        icon: Icons.report_problem_outlined,
                        iconBgColor: const Color(0xFFFFF3E0),
                        iconColor: const Color(0xFFE65100),
                        title: 'แจ้งรายงานการใช้งาน',
                        subtitle: 'แจ้งปัญหาการใช้งาน, ข้อเสนอแนะ',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReportIssueScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── App Version ──
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pets_rounded, size: 18, color: AppColors.textHint),
                            const SizedBox(width: 6),
                            Text(
                              'COWSMART',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'เวอร์ชัน 1.0.0',
                          style: TextStyle(
                            color: AppColors.textHint.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Logout Button ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutConfirmation(),
                      icon: const Icon(Icons.logout_rounded, size: 22),
                      label: const Text('ออกจากระบบ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: AppColors.error.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('ออกจากระบบ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?', style: TextStyle(fontSize: 15)),
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
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(authProvider.notifier).logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('ออกจากระบบ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
  }

  void _navigateToChangePassword(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
  }

  void _navigateToAppSettings(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AppSettingsScreen()));
  }

  void _navigateToHelp(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
  }
}

// ── Supporting Widgets ──

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64),
      child: Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
