import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/constants/app_constants.dart';
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

    // Listen for errors
    ref.listen<CowState>(cowProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(cowProvider.notifier).clearFlags();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายชื่อวัวทั้งหมด'),
        actions: [
          if (cowState.hasActiveFilter)
            TextButton(
              onPressed: () => ref.read(cowProvider.notifier).clearFilters(),
              child: const Text('ล้าง', style: TextStyle(color: Colors.white)),
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: cowState.hasActiveFilter,
              backgroundColor: Colors.red,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(cowProvider.notifier).setSearchQuery(value),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อ หรือ หมายเลขวัว...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(cowProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
            ),
          ),

          // Active filter chips
          if (cowState.hasActiveFilter)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (cowState.filterStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(cowState.filterStatus!.label),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => ref
                            .read(cowProvider.notifier)
                            .setFilter(filterStatus: null),
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        side: const BorderSide(color: AppColors.primary),
                        labelStyle: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (cowState.filterType != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(cowState.filterType!.label),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => ref
                            .read(cowProvider.notifier)
                            .setFilter(filterType: null),
                        backgroundColor: AppColors.secondary.withOpacity(0.12),
                        side: const BorderSide(color: AppColors.secondary),
                        labelStyle: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (cowState.filterGender != null)
                    Chip(
                      label: Text(
                        cowState.filterGender == 'M' ? 'เพศผู้' : 'เพศเมีย',
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => ref
                          .read(cowProvider.notifier)
                          .setFilter(filterGender: null),
                      backgroundColor: AppColors.info.withOpacity(0.12),
                      side: const BorderSide(color: AppColors.info),
                      labelStyle: const TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),

          // Cow List
          Expanded(
            child: cowState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedCows.isEmpty
                ? Center(
                    child: Text(
                      cowState.searchQuery?.isNotEmpty == true
                          ? 'ไม่พบวัวที่ค้นหา'
                          : 'ยังไม่มีข้อมูลวัวในฟาร์มนี้',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                      vertical: 8,
                    ),
                    itemCount: displayedCows.length,
                    itemBuilder: (context, index) {
                      final cow = displayedCows[index];
                      return _buildCowCard(context, cow);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/add_cow');
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'เพิ่มวัว',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                  const Text(
                    'กรองรายการวัว',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Status filter
              const Text(
                'สถานะ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: CowStatus.values.map((s) {
                  final selected = tempStatus == s;
                  return FilterChip(
                    label: Text(s.label),
                    selected: selected,
                    onSelected: (v) =>
                        setSheetState(() => tempStatus = v ? s : null),
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Type filter
              const Text(
                'ประเภท',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: CowType.values.map((t) {
                  final selected = tempType == t;
                  return FilterChip(
                    label: Text(t.label),
                    selected: selected,
                    onSelected: (v) =>
                        setSheetState(() => tempType = v ? t : null),
                    selectedColor: AppColors.secondary.withOpacity(0.2),
                    checkmarkColor: AppColors.secondary,
                    side: BorderSide(
                      color: selected ? AppColors.secondary : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Gender filter
              const Text(
                'เพศ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('เพศผู้'),
                    selected: tempGender == 'M',
                    onSelected: (v) =>
                        setSheetState(() => tempGender = v ? 'M' : null),
                    selectedColor: AppColors.info.withOpacity(0.2),
                    checkmarkColor: AppColors.info,
                    side: BorderSide(
                      color: tempGender == 'M'
                          ? AppColors.info
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: tempGender == 'M'
                          ? AppColors.info
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  FilterChip(
                    label: const Text('เพศเมีย'),
                    selected: tempGender == 'F',
                    onSelected: (v) =>
                        setSheetState(() => tempGender = v ? 'F' : null),
                    selectedColor: AppColors.info.withOpacity(0.2),
                    checkmarkColor: AppColors.info,
                    side: BorderSide(
                      color: tempGender == 'F'
                          ? AppColors.info
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: tempGender == 'F'
                          ? AppColors.info
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

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
                        ref
                            .read(cowProvider.notifier)
                            .setFilter(
                              filterStatus: tempStatus,
                              filterType: tempType,
                              filterGender: tempGender,
                            );
                        Navigator.pop(ctx);
                      },
                      child: const Text('ใช้งาน'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          context.push('/cow_detail', extra: cow);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cow Image Placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(12),
                  image: (cow.imageFullUrl != null || cow.imageUrl != null)
                      ? DecorationImage(
                          image: NetworkImage(cow.imageFullUrl ?? cow.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (cow.imageFullUrl == null && cow.imageUrl == null)
                    ? const Icon(Icons.pets, size: 40, color: AppColors.textHint)
                    : null,
              ),
              const SizedBox(width: 16),

              // Cow Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${cow.tagNumber} | ${cow.name}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusBadge(cow.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cow.breed} • ${cow.type.label}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.cake_outlined,
                          '${cow.ageInMonths} เดือน',
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.scale_outlined,
                          cow.latestWeight > 0
                              ? '${cow.latestWeight.toStringAsFixed(0)} กก.'
                              : '- กก.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
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
      case CowStatus.pregnant:
        bgColor = AppColors.info;
        break;
      case CowStatus.recovering:
        bgColor = AppColors.warning;
        textColor = AppColors.textPrimary;
        break;
      case CowStatus.sold:
        bgColor = AppColors.textHint;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
