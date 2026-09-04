import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';

class CowListScreen extends ConsumerStatefulWidget {
  const CowListScreen({super.key});

  @override
  ConsumerState<CowListScreen> createState() => _CowListScreenState();
}

class _CowListScreenState extends ConsumerState<CowListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(cowProvider.notifier).fetchCows(currentFarm.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cowState = ref.watch(cowProvider);
    final displayedCows = ref.watch(activeCowsProvider);
    final currentFarm = ref.watch(farmProvider).currentFarm;

    // Listen for farm changes
    ref.listen(farmProvider, (previous, next) {
      if (next.currentFarm?.id != previous?.currentFarm?.id && next.currentFarm != null) {
        ref.read(cowProvider.notifier).fetchCows(next.currentFarm!.id);
      }
    });

    // Auto-fetch if farm changed or empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentFarm != null &&
          !cowState.isLoading &&
          (cowState.allCows.isEmpty || (cowState.allCows.isNotEmpty && cowState.allCows.first.farmId != currentFarm.id))) {
        ref.read(cowProvider.notifier).fetchCows(currentFarm.id);
      }
    });

    // Listen for errors
    ref.listen<CowState>(cowProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        AppFeedback.showError(context, next.errorMessage!);
        ref.read(cowProvider.notifier).clearFlags();
      }
    });

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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'รายชื่อวัวทั้งหมด',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (cowState.hasActiveFilter)
                            TextButton(
                              onPressed: () =>
                                  ref.read(cowProvider.notifier).clearFilters(),
                              child: const Text(
                                'ล้างตัวกรอง',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: 'รีเฟรชข้อมูล',
                            onPressed: () {
                              if (currentFarm != null) {
                                ref
                                    .read(cowProvider.notifier)
                                    .fetchCows(currentFarm.id);
                              }
                            },
                          ),
                          IconButton(
                            icon: Badge(
                              isLabelVisible: cowState.hasActiveFilter,
                              backgroundColor: AppColors.error,
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            tooltip: 'ตัวกรองค้นหา',
                            onPressed: () => _showFilterSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'จัดการ ค้นหา และติดตามสถานะวัวในฟาร์มของคุณ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Search & Filter Controls ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar Input
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.brd(context).withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.text(context),
                      ),
                      onChanged: (value) =>
                          ref.read(cowProvider.notifier).setSearchQuery(value),
                      decoration: InputDecoration(
                        hintText:
                            'ค้นหาด้วยชื่อหรือหมายเลขประจำตัว...',
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textHint,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 22,
                          color: AppColors.primary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(cowProvider.notifier)
                                      .setSearchQuery('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 18,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),

                  // Active Filter Chips
                  if (cowState.hasActiveFilter) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (cowState.filterStatus != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(cowState.filterStatus!.label),
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                ),
                                onDeleted: () => ref
                                    .read(cowProvider.notifier)
                                    .setFilter(filterStatus: null),
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.1,
                                ),
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                labelStyle: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (cowState.filterType != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(cowState.filterType!.label),
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                ),
                                onDeleted: () => ref
                                    .read(cowProvider.notifier)
                                    .setFilter(filterType: null),
                                backgroundColor: AppColors.secondary.withValues(
                                  alpha: 0.1,
                                ),
                                side: const BorderSide(
                                  color: AppColors.secondary,
                                ),
                                labelStyle: const TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (cowState.filterGender != null)
                            Chip(
                              label: Text(
                                cowState.filterGender == 'M'
                                    ? 'เพศผู้'
                                    : 'เพศเมีย',
                              ),
                              deleteIcon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                              ),
                              onDeleted: () => ref
                                  .read(cowProvider.notifier)
                                  .setFilter(filterGender: null),
                              backgroundColor: AppColors.info.withValues(
                                alpha: 0.1,
                              ),
                              side: const BorderSide(color: AppColors.info),
                              labelStyle: const TextStyle(
                                color: AppColors.info,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Results Count Header Bar
                  const SizedBox(height: 14),
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
                        'พบวัวทั้งหมด ${displayedCows.length} ตัว',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.text(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Cow Cards List ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            sliver: cowState.isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : displayedCows.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CowIcon(
                            size: 56,
                            color: Colors.grey[350],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cowState.searchQuery?.isNotEmpty == true
                                ? 'ไม่พบวัวที่ค้นหา'
                                : 'ยังไม่มีข้อมูลวัวในฟาร์มนี้',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final cow = displayedCows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCowCard(context, cow),
                      );
                    }, childCount: displayedCows.length),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cow_list_fab',
        onPressed: () {
          context.push('/add_cow');
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        label: const Text(
          'เพิ่มวัวใหม่',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final cowState = ref.read(cowProvider);
    CowStatus? tempStatus = cowState.filterStatus;
    CowType? tempType = cowState.filterType;
    String? tempGender = cowState.filterGender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'กรองรายการวัว',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(ctx),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        tempStatus = null;
                        tempType = null;
                        tempGender = null;
                      });
                    },
                    child: const Text(
                      'ล้างทั้งหมด',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(color: AppColors.div(ctx)),
              const SizedBox(height: 12),

              // Status filter
              Text(
                'สถานะวัว',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(ctx),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CowStatus.values.map((s) {
                  final selected = tempStatus == s;
                  return ChoiceChip(
                    label: Text(s.label),
                    selected: selected,
                    onSelected: (v) =>
                        setSheetState(() => tempStatus = v ? s : null),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundColor: AppColors.surfAlt(ctx),
                    side: BorderSide(color: selected ? AppColors.primary : AppColors.brd(ctx)),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.text(ctx),
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Type filter
              Text(
                'ประเภทวัว',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(ctx),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CowType.values.map((t) {
                  final selected = tempType == t;
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: selected,
                    onSelected: (v) =>
                        setSheetState(() => tempType = v ? t : null),
                    selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                    backgroundColor: AppColors.surfAlt(ctx),
                    side: BorderSide(color: selected ? AppColors.secondary : AppColors.brd(ctx)),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.secondary
                          : AppColors.text(ctx),
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Gender filter
              Text(
                'เพศวัว',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(ctx),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('เพศผู้'),
                    selected: tempGender == 'M',
                    onSelected: (v) =>
                        setSheetState(() => tempGender = v ? 'M' : null),
                    selectedColor: AppColors.info.withValues(alpha: 0.15),
                    backgroundColor: AppColors.surfAlt(ctx),
                    side: BorderSide(color: tempGender == 'M' ? AppColors.info : AppColors.brd(ctx)),
                    labelStyle: TextStyle(
                      color: tempGender == 'M'
                          ? AppColors.info
                          : AppColors.text(ctx),
                      fontSize: 14,
                      fontWeight: tempGender == 'M'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('เพศเมีย'),
                    selected: tempGender == 'F',
                    onSelected: (v) =>
                        setSheetState(() => tempGender = v ? 'F' : null),
                    selectedColor: AppColors.info.withValues(alpha: 0.15),
                    backgroundColor: AppColors.surfAlt(ctx),
                    side: BorderSide(color: tempGender == 'F' ? AppColors.info : AppColors.brd(ctx)),
                    labelStyle: TextStyle(
                      color: tempGender == 'F'
                          ? AppColors.info
                          : AppColors.text(ctx),
                      fontSize: 14,
                      fontWeight: tempGender == 'F'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                      onPressed: () {
                        ref
                            .read(cowProvider.notifier)
                            .setFilter(
                              filterStatus: tempStatus,
                              filterType: tempType,
                              filterGender: tempGender,
                            );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ใช้งานตัวกรอง',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCowCard(BuildContext context, Cow cow) {
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            context.push('/cow_detail', extra: cow);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Cow Image Preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 92,
                    height: 92,
                    color: AppColors.surfAlt(context),
                    child: (cow.imageFullUrl != null || cow.imageUrl != null)
                        ? Image.network(
                            cow.imageFullUrl ?? cow.imageUrl!,
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: CowIcon(
                                size: 40,
                                color: AppColors.hint(context),
                              ),
                            ),
                          )
                        : Center(
                            child: CowIcon(
                              size: 40,
                              color: AppColors.hint(context),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Cow Information Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & Status Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cow.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                                color: AppColors.text(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildStatusBadge(cow.status),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Tag Number & Breed Details
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.nfc_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cow.tagNumber,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${cow.breed} • ${cow.type.label}',
                              style: TextStyle(
                                color: AppColors.subText(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Information Chips (Age, Weight, Gender)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildInfoChip(context, Icons.cake_outlined, cow.ageYearsOnly),
                            const SizedBox(width: 6),
                            _buildInfoChip(
                              context,
                              Icons.scale_outlined,
                              cow.latestWeight > 0
                                  ? '${cow.latestWeight.toStringAsFixed(0)} กก.'
                                  : '- กก.',
                            ),
                            const SizedBox(width: 6),
                            _buildInfoChip(
                              context,
                              cow.gender == 'M'
                                  ? Icons.male_rounded
                                  : Icons.female_rounded,
                              cow.gender == 'M' ? 'ผู้' : 'เมีย',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.hint(context),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfAlt(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.subText(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.subText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(CowStatus status) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (status) {
      case CowStatus.normal:
        bgColor = AppColors.success;
        break;
      case CowStatus.sick:
        bgColor = AppColors.error;
        break;
      case CowStatus.injured:
        bgColor = const Color(0xFFD97706); // Amber / orange-red
        textColor = Colors.white;
        break;
      case CowStatus.estrous:
        bgColor = const Color(0xFFEC4899); // Pink
        textColor = Colors.white;
        break;
      case CowStatus.pregnant:
        bgColor = const Color(0xFF9333EA); // Purple
        textColor = Colors.white;
        break;
      case CowStatus.recovering:
        bgColor = const Color(0xFF2563EB); // Royal Blue for resting / recovery
        textColor = Colors.white;
        break;
      case CowStatus.sold:
        bgColor = AppColors.textHint;
        break;
      case CowStatus.deceased:
        bgColor = AppColors.error;
        break;
      case CowStatus.removed:
        bgColor = AppColors.warning;
        textColor = AppColors.textPrimary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
