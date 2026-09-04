import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/auth/providers/auth_provider.dart';

class SelectFarmScreen extends ConsumerStatefulWidget {
  const SelectFarmScreen({super.key});

  @override
  ConsumerState<SelectFarmScreen> createState() => _SelectFarmScreenState();
}

class _SelectFarmScreenState extends ConsumerState<SelectFarmScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(farmProvider.notifier).fetchFarms();
    });
  }

  Future<void> _onSelectFarm(dynamic farm) async {
    ref.read(farmProvider.notifier).selectFarm(farm);

    // Initial fetch for the selected farm's data
    await Future.wait([
      ref.read(cowProvider.notifier).fetchCows(farm.id),
      ref.read(zoneProvider.notifier).fetchZones(farm.id),
    ]);

    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final authState = ref.watch(authProvider);
    final isNewUser = authState.isNewUser;

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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Column(
                    children: [
                      const Text(
                        'เลือกฟาร์มของคุณ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isNewUser ? 'ยินดีต้อนรับสู่ COWSMART!' : 'ยินดีต้อนรับกลับมา! เลือกฟาร์มที่คุณต้องการจัดการในวันนี้',
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (farmState.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (farmState.farms.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.holiday_village_outlined, size: 48, color: AppColors.primary),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'ยังไม่มีฟาร์มในระบบ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'เริ่มต้นด้วยการสร้างฟาร์มแรกของคุณเพื่อเริ่มจัดการข้อมูลวัวและกิจกรรมทั้งหมด',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.subText(context),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/create_farm'),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('สร้างฟาร์มแรกของคุณ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Section title
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
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
                          Text(
                            'รายชื่อฟาร์มทั้งหมด (${farmState.farms.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Farm Cards
                    ...farmState.farms.map((farm) {
                      final user = authState.user;
                      final ownerName = (user != null)
                          ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
                          : farm.ownerEmail;
                      final imageUrl = farm.imageFullUrl ?? farm.imageUrl;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _onSelectFarm(farm),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // ── Farm Image ──
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.house_siding_rounded,
                                                color: AppColors.primary,
                                                size: 32,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.house_siding_rounded,
                                              color: AppColors.primary,
                                              size: 32,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // ── Farm Details ──
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          farm.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: AppColors.text(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.person_outline_rounded, size: 14, color: AppColors.hint(context)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'เจ้าของ: ${ownerName.isNotEmpty ? ownerName : farm.ownerEmail}',
                                                style: TextStyle(
                                                  color: AppColors.subText(context),
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Chevron
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfAlt(context),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Add Farm Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/create_farm'),
                        icon: const Icon(Icons.add_rounded, size: 22),
                        label: const Text(
                          'สร้างฟาร์มเพิ่ม',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
