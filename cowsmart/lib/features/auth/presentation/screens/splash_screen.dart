import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cowsmart_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Stack(
          children: [
            // Center Logo and Title Content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App Logo
                      const CowSmartLogo(
                        size: 112,
                        borderRadius: 28,
                        showShadow: true,
                      ),
                      const SizedBox(height: 28),

                      // App Name
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: isDark ? const Color(0xFF8FA584) : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Slogan / Subtitle
                      Text(
                        'ระบบบริหารจัดการฟาร์มวัวอัจฉริยะ',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.subText(context),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Loading Indicator & Version
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? const Color(0xFF8FA584) : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'เวอร์ชัน 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.hint(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
