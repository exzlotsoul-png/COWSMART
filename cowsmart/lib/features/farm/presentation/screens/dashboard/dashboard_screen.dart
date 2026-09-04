import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/finance/providers/finance_provider.dart';
import 'package:cowsmart/features/finance/domain/finance.dart';
import 'package:cowsmart/features/market/providers/market_price_provider.dart';
import 'package:cowsmart/features/notifications/providers/notification_provider.dart';
import 'package:cowsmart/features/auth/providers/auth_provider.dart';
import 'package:cowsmart/features/calendar/providers/calendar_provider.dart';
import 'package:cowsmart/features/farm/services/farm_pdf_export_service.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/network/api_client.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _hasFetchedData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _fetchData() {
    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm != null && !_hasFetchedData) {
      _hasFetchedData = true;
      ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
      ref.read(financeProvider.notifier).fetchTransactions(currentFarm.id);
      ref.read(notificationProvider.notifier).fetchNotifications();
    }
  }

  Future<void> _refreshData() async {
    _hasFetchedData = false;
    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm != null) {
      await ref.read(farmProvider.notifier).fetchFarms();
      await Future.wait([
        ref.read(cowProvider.notifier).fetchCows(currentFarm.id),
        ref.read(zoneProvider.notifier).fetchZones(currentFarm.id),
        ref.read(financeProvider.notifier).fetchTransactions(currentFarm.id),
      ]);
      _hasFetchedData = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(farmProvider, (previous, next) {
      if (next.currentFarm?.id != previous?.currentFarm?.id &&
          next.currentFarm != null) {
        ref.read(cowProvider.notifier).fetchCows(next.currentFarm!.id);
        ref.read(zoneProvider.notifier).fetchZones(next.currentFarm!.id);
        ref
            .read(financeProvider.notifier)
            .fetchTransactions(next.currentFarm!.id);
      }
    });

    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final cowState = ref.watch(cowProvider);
    final marketState = ref.watch(marketPriceProvider);
    final breeds = ref.watch(breedProvider);

    if (farmState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (currentFarm == null) {
      return _buildEmptyFarmScreen(context);
    }

    final totalCows = cowState.allCows.length;
    final zoneCount = ref.watch(zoneProvider).zones.length;
    final culledThisMonth = ref.watch(currentMonthCulledCountProvider);
    final totalValue = cowState.allCows.fold<double>(0, (sum, cow) {
      final bName = breeds
          .firstWhere(
            (b) => b.id == cow.breed,
            orElse: () => Breed(id: cow.breed, name: cow.breed),
          )
          .name;
      return sum +
          marketState.calculateEstimatedValue(
            breedName: bName,
            weight: cow.latestWeight,
          );
    });

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
            children: [
              // ── 1. Top Bar (minimal) ──
              _buildTopBar(context),

              // ── 2. Farm Hero Banner Card ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: _buildFarmHeroBanner(context, currentFarm),
              ),

              // ── 3. Stats Unified Card ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildUnifiedStatsCard(
                  context,
                  totalCows,
                  zoneCount,
                  totalValue,
                  culledThisMonth,
                ),
              ),

              // ── 4. Finance Dual Cards ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildFinanceDualCards(context, ref),
              ),

              // ── 5. Zone List ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _buildZoneList(context, ref),
              ),

              // ── 6. Quick Actions ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _buildQuickActionsSection(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  Empty Farm Screen
  // ────────────────────────────────────────────────────────
  Widget _buildEmptyFarmScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ยังไม่มีข้อมูลฟาร์มของคุณ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'เริ่มต้นด้วยการสร้างฟาร์มใหม่เพื่อจัดการข้อมูลวัวของคุณ',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/create_farm'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'สร้างฟาร์มแรกของคุณ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  1. TOP BAR — minimal, no gradient
  // ────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Greeting
          Expanded(
            child: Builder(
              builder: (context) {
                final user = ref.watch(authProvider).user;
                final userName = user != null
                    ? '${user['first_name'] ?? ''}'
                    : 'ผู้ใช้งาน';
                final hour = DateTime.now().hour;
                final String greetingText;
                final IconData greetingIcon;
                final Color iconColor;

                if (hour >= 5 && hour < 12) {
                  greetingText = 'สวัสดีตอนเช้า';
                  greetingIcon = Icons.wb_sunny_rounded;
                  iconColor = const Color(0xFFF59E0B);
                } else if (hour >= 12 && hour < 17) {
                  greetingText = 'สวัสดีตอนบ่าย';
                  greetingIcon = Icons.wb_twilight_rounded;
                  iconColor = const Color(0xFFF97316);
                } else if (hour >= 17 && hour < 20) {
                  greetingText = 'สวัสดีตอนเย็น';
                  greetingIcon = Icons.nights_stay_rounded;
                  iconColor = const Color(0xFF6366F1);
                } else {
                  greetingText = 'สวัสดีตอนดึก';
                  greetingIcon = Icons.dark_mode_rounded;
                  iconColor = const Color(0xFF8B5CF6);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          greetingText,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(greetingIcon, size: 16, color: iconColor),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),

          // Action Buttons
          Row(
            children: [
              _buildCircleAction(
                context,
                icon: Icons.picture_as_pdf_rounded,
                onTap: _exportFarmPdfReport,
                tooltip: 'ส่งออกรายงาน PDF',
              ),
              const SizedBox(width: 8),
              _buildCircleAction(
                context,
                icon: Icons.swap_horiz_rounded,
                onTap: () => context.go('/select-farm'),
                tooltip: 'สลับฟาร์ม',
              ),
              const SizedBox(width: 8),
              _buildCircleAction(
                context,
                icon: Icons.calendar_month_rounded,
                onTap: () => context.push('/calendar'),
                tooltip: 'ปฏิทิน',
              ),
              const SizedBox(width: 8),
              _buildNotificationCircle(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAction(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: AppColors.cardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.6)),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.text(context), size: 22),
        ),
      ),
    );
  }

  Widget _buildNotificationCircle(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final unread = ref.watch(notificationProvider).unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildCircleAction(
              context,
              icon: Icons.notifications_outlined,
              onTap: () => context.push('/notifications'),
              tooltip: 'แจ้งเตือน',
            ),
            if (unread > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────
  //  2. FARM HERO BANNER — image with overlay
  // ────────────────────────────────────────────────────────
  Widget _buildFarmHeroBanner(BuildContext context, dynamic farm) {
    return InkWell(
      onTap: () => context.push('/edit_farm', extra: farm),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          image: DecorationImage(
            image: farm.imageFullUrl != null && farm.imageFullUrl!.isNotEmpty
                ? NetworkImage(farm.imageFullUrl!)
                : const NetworkImage(
                    'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=800&q=80',
                  ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.35),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Gradient overlay at bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),

            // Farm info
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          farm.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black38),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'แก้ไข',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final user = ref.watch(authProvider).user;
                      final ownerName = (user != null)
                          ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                                .trim()
                          : farm.ownerEmail;
                      return Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              ownerName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  3. UNIFIED STATS CARD — 3 Columns + Black Amount Valuation Row
  // ────────────────────────────────────────────────────────
  Widget _buildUnifiedStatsCard(
    BuildContext context,
    int totalCows,
    int zoneCount,
    double totalValue,
    int culledThisMonth,
  ) {
    final formatter = NumberFormat('#,##0');
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: 3 Core Stat Columns (วัวทั้งหมด, โซน, คัดทิ้งเดือนนี้)
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    context,
                    Icons.pets_rounded,
                    AppColors.primary,
                    '$totalCows',
                    'วัวทั้งหมด',
                  ),
                ),
                Container(
                  width: 1,
                  color: AppColors.div(context).withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _buildStatColumn(
                    context,
                    Icons.grass_rounded,
                    AppColors.secondary,
                    '$zoneCount',
                    'โซน',
                  ),
                ),
                Container(
                  width: 1,
                  color: AppColors.div(context).withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _buildStatColumn(
                    context,
                    Icons.output_rounded,
                    const Color(0xFFF59E0B),
                    '$culledThisMonth',
                    'คัดทิ้งเดือนนี้',
                    onTap: () => context.push('/culling_history'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 2: Dedicated Farm Valuation Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'มูลค่ารวมฟาร์ม',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '฿${formatter.format(totalValue)}',
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    dynamic icon,
    Color color,
    String value,
    String label, {
    VoidCallback? onTap,
  }) {
    final Widget iconWidget = icon is Widget
        ? icon
        : (icon == Icons.pets || icon == Icons.pets_rounded || icon == Icons.pets_outlined)
            ? CowIcon(color: color, size: 22)
            : Icon(icon as IconData, color: color, size: 22);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: iconWidget,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.text(context),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  4. FINANCE DUAL CARDS — income & expense side by side
  // ────────────────────────────────────────────────────────
  Widget _buildFinanceDualCards(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(financeProvider);
    final income = financeState.totalIncomeCurrentActualMonth;
    final expense = financeState.totalExpenseCurrentActualMonth;
    final balance = income - expense;
    final formatter = NumberFormat('#,##0');

    final now = DateTime.now();
    final fullThaiMonths = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final thaiYear = now.year > 2400 ? now.year : now.year + 543;
    final currentMonthLabel = '${fullThaiMonths[now.month]} $thaiYear';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance header row
        InkWell(
          onTap: () => context.push('/finance'),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
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
                    Expanded(
                      child: Text(
                        'การเงินเดือน $currentMonthLabel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Text(
                    '฿${formatter.format(balance)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: balance >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (balance >= 0 ? AppColors.success : AppColors.error)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      balance >= 0 ? 'กำไร' : 'ขาดทุน',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: balance >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.subText(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Dual cards
        Row(
          children: [
            // Income card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: AppColors.success,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'รายรับ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.text(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '฿${formatter.format(income)}',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Expense card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: AppColors.error,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'รายจ่าย',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.text(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '฿${formatter.format(expense)}',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  //  5. ZONE LIST — vertical card rows
  // ────────────────────────────────────────────────────────
  Widget _buildZoneList(BuildContext context, WidgetRef ref) {
    final zoneState = ref.watch(zoneProvider);
    final zones = zoneState.zones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
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
                  'โซนในฟาร์ม',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => context.push('/create_zone'),
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'เพิ่มโซน',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (zoneState.isLoading)
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.brd(context)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (zones.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.brd(context)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.grass_rounded,
                  size: 32,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ยังไม่มีข้อมูลโซน',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...zones
              .take(5)
              .map(
                (zone) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildZoneRow(context, zone),
                ),
              ),
          if (zones.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/all_zones'),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text(
                  'ดูโซนทั้งหมด (${zones.length} โซน)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildZoneRow(BuildContext context, dynamic zone) {
    return InkWell(
      onTap: () => context.push('/zone_detail', extra: zone),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.grass_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.text(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'จำนวนวัว ${zone.cowCount} ตัว',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${zone.cowCount}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  6. QUICK ACTIONS — 2 columns with subtitles
  // ────────────────────────────────────────────────────────
  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              'เมนูหลัก',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.65,
          children: [
            _buildActionTile(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              label: 'ผู้ช่วยหมอ',
              subtitle: 'ปรึกษาอาการวัว',
              color: AppColors.info,
              onTap: () => context.push('/ai_chat'),
            ),
            _buildActionTile(
              context,
              icon: Icons.health_and_safety_rounded,
              label: 'จัดการสุขภาพ',
              subtitle: 'บันทึกการรักษา',
              color: AppColors.primary,
              onTap: () => context.push('/group_health'),
            ),
            _buildActionTile(
              context,
              icon: Icons.delete_sweep_outlined,
              label: 'จำหน่าย/คัดออก',
              subtitle: 'จัดการวัวออกฟาร์ม',
              color: AppColors.error,
              onTap: () => context.push('/group_cull'),
            ),
            _buildActionTile(
              context,
              icon: Icons.event_available_rounded,
              label: 'สร้างนัดหมาย',
              subtitle: 'นัดตรวจ/วัคซีน',
              color: Colors.orange[800]!,
              onTap: () => context.push('/group_appointment'),
            ),
            _buildActionTile(
              context,
              icon: Icons.calendar_month_rounded,
              label: 'ปฏิทินกิจกรรม',
              subtitle: 'ตารางนัดหมาย',
              color: AppColors.secondary,
              onTap: () => context.push('/calendar'),
            ),
            _buildActionTile(
              context,
              icon: Icons.show_chart_rounded,
              label: 'ราคาตลาด',
              subtitle: 'ติดตามราคาวัว',
              color: AppColors.accent,
              onTap: () => context.push('/market_price'),
            ),
            _buildActionTile(
              context,
              icon: Icons.picture_as_pdf_rounded,
              label: 'รายงานฟาร์ม',
              subtitle: 'ส่งออกไฟล์ PDF',
              color: const Color(0xFFC2410C),
              onTap: _exportFarmPdfReport,
            ),
            _buildActionTile(
              context,
              icon: Icons.add_business_rounded,
              label: 'เพิ่มฟาร์ม',
              subtitle: 'สร้างฟาร์มใหม่',
              color: AppColors.secondaryDark,
              onTap: () => context.push('/create_farm'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.text(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.subText(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddGlobalAppointmentDialog(BuildContext context) async {
    final titleCtrl = TextEditingController(
      text: 'นัดหมายฉีดวัคซีน/ตรวจสุขภาพ',
    );
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    String selectedReminder = 'ก่อน 1 วัน';
    String selectedType = 'ฉีดวัคซีน/ถ่ายพยาธิ';
    final selectedCowIds = <String>{};

    List<String> types = [
      'ฉีดวัคซีน/ถ่ายพยาธิ',
      'ตรวจสุขภาพประจำปี/ประจำเดือน',
      'ตรวจระบบสืบพันธุ์',
      'ติดตามผลการรักษา',
      'อื่นๆ',
    ];

    // Fetch appointment types from API
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/appointment_types');
      final apiTypes = (res.data as List<dynamic>)
          .map((e) => e['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      if (apiTypes.isNotEmpty) {
        types = apiTypes;
        selectedType = types.first;
        titleCtrl.text = 'นัดหมาย${types.first}';
      }
    } catch (_) {}

    final reminderOptions = [
      'ตรงเวลาที่บันทึก',
      'ก่อน 15 นาที',
      'ก่อน 1 ชั่วโมง',
      'ก่อน 1 วัน',
      'ก่อน 3 วัน',
      'ก่อน 7 วัน',
      'ไม่แจ้งเตือน',
    ];

    final allCows = ref.read(cowProvider).allCows;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedCowNames = allCows
              .where((c) => selectedCowIds.contains(c.id))
              .map(
                (c) => c.name.isNotEmpty
                    ? '${c.name} (${c.tagNumber})'
                    : c.tagNumber,
              )
              .join(', ');

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  color: Colors.orange[800],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'นัดหมายตรวจสุขภาพ / ฉีดวัคซีน / ถ่ายพยาธิ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final tempSelected = Set<String>.from(selectedCowIds);
                      String dialogSearchQuery = '';
                      final result = await showDialog<Set<String>>(
                        context: ctx,
                        builder: (selectCtx) => StatefulBuilder(
                          builder: (selectCtx, setSelectState) {
                            final filteredCows = allCows.where((cow) {
                              if (dialogSearchQuery.isEmpty) return true;
                              final q = dialogSearchQuery.toLowerCase();
                              return cow.name.toLowerCase().contains(q) ||
                                  cow.tagNumber.toLowerCase().contains(q);
                            }).toList();

                            return AlertDialog(
                              title: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'เลือกวัวที่ต้องการนัดหมาย',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setSelectState(() {
                                        if (tempSelected.length ==
                                            allCows.length) {
                                          tempSelected.clear();
                                        } else {
                                          tempSelected.addAll(
                                            allCows.map((c) => c.id),
                                          );
                                        }
                                      });
                                    },
                                    child: Text(
                                      tempSelected.length == allCows.length
                                          ? 'ยกเลิกทั้งหมด'
                                          : 'เลือกทั้งหมด',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: MediaQuery.of(context).size.height * 0.65,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      onChanged: (val) {
                                        setSelectState(() {
                                          dialogSearchQuery = val.trim();
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'ค้นหาชื่อ หรือ เบอร์หู...',
                                        hintStyle: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textHint,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        suffixIcon: dialogSearchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  setSelectState(() {
                                                    dialogSearchQuery = '';
                                                  });
                                                },
                                              )
                                            : null,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                        filled: true,
                                        fillColor: AppColors.surfaceAlt,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: filteredCows.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'ไม่พบข้อมูลวัวที่ค้นหา',
                                                style: TextStyle(
                                                  color: AppColors.textHint,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: filteredCows.length,
                                              itemBuilder: (cCtx, i) {
                                                final cow = filteredCows[i];
                                                final isChecked = tempSelected
                                                    .contains(cow.id);
                                                return CheckboxListTile(
                                                  value: isChecked,
                                                  activeColor:
                                                      Colors.orange[800],
                                                  title: Text(
                                                    cow.name.isNotEmpty
                                                        ? '${cow.name} (${cow.tagNumber})'
                                                        : cow.tagNumber,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    'แท็ก: ${cow.tagNumber} · ${cow.type.label}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  onChanged: (val) {
                                                    setSelectState(() {
                                                      if (val == true) {
                                                        tempSelected.add(
                                                          cow.id,
                                                        );
                                                      } else {
                                                        tempSelected.remove(
                                                          cow.id,
                                                        );
                                                      }
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side: const BorderSide(color: AppColors.textSecondary),
                                        ),
                                        onPressed: () => Navigator.pop(selectCtx, null),
                                        child: const Text(
                                          'ยกเลิก',
                                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange[800],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                        onPressed: () => Navigator.pop(selectCtx, tempSelected),
                                        child: Text(
                                          'ตกลง (${tempSelected.length})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      );

                      if (result != null) {
                        setDialogState(() {
                          selectedCowIds.clear();
                          selectedCowIds.addAll(result);
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'ระบุกระบือ/วัว (เลือกได้หลายตัว)',
                        labelStyle: const TextStyle(fontSize: 15),
                        prefixIcon: CowIcon(size: 20, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        selectedCowIds.isEmpty
                            ? 'ทั้งฟาร์ม / ไม่เจาะจงวัว'
                            : 'เลือกแล้ว ${selectedCowIds.length} ตัว: $selectedCowNames',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedCowIds.isEmpty
                              ? AppColors.hint(context)
                              : AppColors.text(context),
                          fontWeight: selectedCowIds.isEmpty
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedType,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.text(context),
                    ),
                    decoration: const InputDecoration(
                      labelText: 'ประเภทนัดหมาย *',
                      labelStyle: TextStyle(fontSize: 15),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: types
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t,
                              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          selectedType = v;
                          titleCtrl.text = 'นัดหมาย: $v';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                    decoration: const InputDecoration(
                      labelText: 'หัวข้อการนัดหมาย *',
                      labelStyle: TextStyle(fontSize: 15),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.calendar_today,
                      color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary,
                    ),
                    title: Text(
                      'วันนัดหมาย',
                      style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                    ),
                    subtitle: Text(
                      AppDateUtils.formatThaiDate(
                        selectedDate,
                        useFullMonth: true,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                        helpText: 'เลือกวันที่',
                        cancelText: 'ยกเลิก',
                        confirmText: 'ตกลง',
                      );
                      if (picked != null)
                        setDialogState(() => selectedDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.access_time,
                      color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary,
                    ),
                    title: Text(
                      'เวลานัดหมาย',
                      style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                    ),
                    subtitle: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} น.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime,
                        helpText: 'ระบุเวลา',
                        cancelText: 'ยกเลิก',
                        confirmText: 'ตกลง',
                        hourLabelText: 'ชั่วโมง',
                        minuteLabelText: 'นาที',
                      );
                      if (picked != null)
                        setDialogState(() => selectedTime = picked);
                    },
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                    decoration: const InputDecoration(
                      labelText: 'รายละเอียด/หมายเหตุ (ไม่บังคับ)',
                      labelStyle: TextStyle(fontSize: 15),
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedReminder,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.text(context),
                    ),
                    decoration: const InputDecoration(
                      labelText: 'แจ้งเตือนล่วงหน้า',
                      labelStyle: TextStyle(fontSize: 15),
                      prefixIcon: Icon(Icons.notifications_active_outlined),
                    ),
                    items: reminderOptions
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              r,
                              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedReminder = v);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;

                        final dt = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        Navigator.pop(ctx);

                        if (mounted) {
                          try {
                            final api = ref.read(apiClientProvider);
                            final farmId = ref.read(farmProvider).currentFarm?.id ?? '';

                            if (selectedCowIds.isEmpty) {
                              await api.post(
                                '/health_appointments',
                                data: {
                                  'cow_id': null,
                                  'appoint_datetime': dt.toIso8601String(),
                                  'description': '$title ${descCtrl.text.trim()}'.trim(),
                                  'reminder_setting': selectedReminder,
                                  'status': 0,
                                },
                              );
                            } else {
                              for (final cowId in selectedCowIds) {
                                await api.post(
                                  '/health_appointments',
                                  data: {
                                    'cow_id': cowId,
                                    'appoint_datetime': dt.toIso8601String(),
                                    'description': '$title ${descCtrl.text.trim()}'.trim(),
                                    'reminder_setting': selectedReminder,
                                    'status': 0,
                                  },
                                );
                              }
                            }

                            if (farmId.isNotEmpty) {
                              ref.read(calendarProvider.notifier).fetchEvents(farmId);
                            }

                            if (mounted) {
                              AppFeedback.showSuccess(
                                context,
                                selectedCowIds.isEmpty
                                    ? 'บันทึกวันนัดหมายสุขภาพทั้งฟาร์มแล้ว'
                                    : 'บันทึกวันนัดหมายสุขภาพสำหรับวัว ${selectedCowIds.length} ตัวแล้ว',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการบันทึก: $e');
                            }
                          }
                        }
                      },
                      child: const Text(
                        'บันทึกนัดหมาย',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportFarmPdfReport() async {
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

      if (mounted) {
        AppFeedback.showSuccess(context, 'ส่งออกรายงาน PDF เรียบร้อยแล้ว');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการสร้าง PDF: $e');
      }
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }
}
