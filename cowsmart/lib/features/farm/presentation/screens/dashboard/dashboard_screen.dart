import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/constants/app_constants.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/finance/providers/finance_provider.dart';
import 'package:cowsmart/features/market/providers/market_price_provider.dart';
import 'package:cowsmart/features/notifications/providers/notification_provider.dart';

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

      // Fetch zones
      ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);

      // Fetch finance data
      ref.read(financeProvider.notifier).fetchTransactions(currentFarm.id);

      // Fetch notifications
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
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final cowState = ref.watch(cowProvider);
    final marketPrice =
        ref.watch(marketPriceProvider).latest?.pricePerKg ?? 120.0;

    if (farmState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (currentFarm == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('COWSMART ฟาร์ม')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.agriculture,
                  size: 80,
                  color: AppColors.border,
                ),
                const SizedBox(height: 24),
                Text(
                  'ยังไม่มีข้อมูลฟาร์มของคุณ',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'เริ่มต้นด้วยการสร้างฟาร์มใหม่เพื่อจัดการข้อมูลวัวของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.push('/create_farm'),
                  icon: const Icon(Icons.add),
                  label: const Text('สร้างฟาร์มแรกของคุณ'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalValue = cowState.allCows.fold<double>(
      0,
      (sum, cow) => sum + (cow.latestWeight * marketPrice),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'COWSMART ฟาร์ม',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.swap_horiz_outlined),
          onPressed: () => context.go('/select-farm'),
          tooltip: 'เปลี่ยนฟาร์ม',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/calendar'),
            tooltip: 'ปฏิทินกิจกรรม',
          ),
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(notificationProvider).unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Farm Overview Header
                _buildFarmOverview(
                  context,
                  currentFarm,
                  cowState.allCows.length,
                  totalValue,
                ),
                const SizedBox(height: 16),

                // 2. Financial Summary Card
                _buildFinancialSummary(context, ref),
                const SizedBox(height: 24),

                // 3. Zone Overview List
                _buildZoneOverview(context, ref),
                const SizedBox(height: 24),

                // 4. Quick Actions (Chatbot, Health, Cull)
                Text(
                  'เมนูหลัก',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildQuickActions(context),
                const SizedBox(height: 80), // Padding for bottom nav bar
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFarmOverview(
    BuildContext context,
    dynamic farm,
    int totalCows,
    double totalValue,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryDark.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: farm.imageFullUrl != null && farm.imageFullUrl!.isNotEmpty
                      ? NetworkImage(farm.imageFullUrl!)
                      : const NetworkImage(
                          'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1500&q=80',
                        ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farm.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'เจ้าของ: ${farm.ownerEmail}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Stats Row
                  Row(
                    children: [
                      _buildMiniStat(context, Icons.pets, '$totalCows ตัว'),
                      const SizedBox(width: 12),
                      _buildMiniStat(
                        context,
                        Icons.payments_outlined,
                        '฿${NumberFormat('#,##0').format(totalValue)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/edit_farm', extra: farm),
              tooltip: 'แก้ไขข้อมูลฟาร์ม',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(financeProvider);

    final income = financeState.totalIncomeThisMonth;
    final expense = financeState.totalExpenseThisMonth;
    final balance = income - expense;

    final formatter = NumberFormat('#,##0');

    return InkWell(
      onTap: () => context.push('/finance'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 93, 117, 80),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'สรุปธุรกรรมในฟาร์ม',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '฿ ${formatter.format(balance)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFinanceMiniStat(
                  'รายรับ',
                  '฿${formatter.format(income)}',
                  const Color.fromARGB(205, 123, 245, 98),
                ),
                _buildFinanceMiniStat(
                  'รายจ่าย',
                  '฿${formatter.format(expense)}',
                  const Color.fromARGB(255, 248, 36, 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceMiniStat(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildZoneOverview(BuildContext context, WidgetRef ref) {
    final zoneState = ref.watch(zoneProvider);
    final zones = zoneState.zones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'โซนในฟาร์ม',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                context.push('/create_zone');
              },
              child: const Text('จัดการโซน'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        zoneState.isLoading
            ? Container(
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            : zones.isEmpty
            ? Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'ยังไม่มีข้อมูลโซน',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            : SizedBox(
                height: 110,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: zones.map((zone) {
                        return InkWell(
                          onTap: () =>
                              context.push('/zone_detail', extra: zone),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 130,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.surface,
                                  const Color.fromARGB(255, 248, 244, 238),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondaryDark.withOpacity(
                                    0.08,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.grass,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  zone.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${zone.cowCount} ตัว',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        _buildActionCard(
          context,
          icon: Icons.chat_bubble_outline,
          label: 'ผู้ช่วยหมอ',
          color: AppColors.info,
          onTap: () {},
        ),
        _buildActionCard(
          context,
          icon: Icons.health_and_safety_outlined,
          label: 'จัดการสุขภาพ',
          color: AppColors.primary,
          onTap: () {},
        ),
        _buildActionCard(
          context,
          icon: Icons.delete_sweep_outlined,
          label: 'คัดทิ้งกลุ่ม',
          color: AppColors.error,
          onTap: () => context.push('/culling_history'),
        ),
        _buildActionCard(
          context,
          icon: Icons.calendar_month_outlined,
          label: 'ปฏิทินกิจกรรม',
          color: AppColors.secondary,
          onTap: () => context.push('/calendar'),
        ),
        _buildActionCard(
          context,
          icon: Icons.show_chart,
          label: 'ราคาตลาด',
          color: AppColors.accent,
          onTap: () => context.push('/market_price'),
        ),
        _buildActionCard(
          context,
          icon: Icons.add_business_outlined,
          label: 'เพิ่มฟาร์ม',
          color: AppColors.secondaryDark,
          onTap: () => context.push('/create_farm'),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
