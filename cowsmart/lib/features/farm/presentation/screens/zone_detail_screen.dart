import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:cowsmart/features/farm/domain/zone.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';

class ZoneDetailScreen extends ConsumerStatefulWidget {
  final Zone zone;

  const ZoneDetailScreen({super.key, required this.zone});

  @override
  ConsumerState<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends ConsumerState<ZoneDetailScreen> {
  bool _isLoading = false;

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

  List<Cow> get _cowsInZone {
    final cowState = ref.watch(cowProvider);
    return cowState.allCows
        .where((cow) => cow.zoneId == widget.zone.id)
        .toList();
  }

  List<Cow> get _cowsNotInZone {
    final cowState = ref.watch(cowProvider);
    return cowState.allCows
        .where((cow) => cow.zoneId != widget.zone.id)
        .toList();
  }

  Color _getStatusColor(Cow cow) {
    switch (cow.status.colorType) {
      case 'success':
        return AppColors.success;
      case 'error':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      case 'info':
        return AppColors.info;
      default:
        return AppColors.textHint;
    }
  }

  Future<void> _removeCowFromZone(Cow cow) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'ยืนยันการนำวัวออกจากโซน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'นำ ${cow.name} ออกจาก ${widget.zone.name}?',
          style: const TextStyle(fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('ยกเลิก',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('ยืนยัน',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        final currentFarm = ref.read(farmProvider).currentFarm;
        if (currentFarm != null) {
          await ref
              .read(cowProvider.notifier)
              .updateCowZone(cow.id, '', currentFarm.id);
          await ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('นำ ${cow.name} ออกจากโซนแล้ว', style: const TextStyle(fontSize: 15)),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e', style: const TextStyle(fontSize: 15)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _moveMultipleCowsToZone(List<Cow> cows) async {
    setState(() => _isLoading = true);
    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm == null) {
      setState(() => _isLoading = false);
      return;
    }

    int successCount = 0;
    int failCount = 0;

    for (final cow in cows) {
      try {
        await ref
            .read(cowProvider.notifier)
            .updateCowZone(cow.id, widget.zone.id, currentFarm.id);
        successCount++;
      } catch (e) {
        failCount++;
      }
    }

    await ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เพิ่มวัวสำเร็จ $successCount ตัว${failCount > 0 ? ', ไม่สำเร็จ $failCount ตัว' : ''}',
            style: const TextStyle(fontSize: 15),
          ),
          backgroundColor: failCount > 0 ? AppColors.warning : AppColors.success,
        ),
      );
    }
  }

  void _showAddCowBottomSheet() {
    final allCowsInFarm = _cowsNotInZone; // All cows not in this specific current zone
    if (allCowsInFarm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีวัวที่สามารถเพิ่มเข้าโซนนี้ได้', style: TextStyle(fontSize: 15))),
      );
      return;
    }

    final allZonesMap = {for (final z in ref.read(zoneProvider).zones) z.id: z.name};
    final selectedCows = <Cow>{};
    bool showOnlyUnassigned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isCowUnassigned = (Cow c) => c.zoneId.isEmpty || c.zoneId == 'null' || c.zoneId == '0';
            final filteredCows = showOnlyUnassigned
                ? allCowsInFarm.where((c) => isCowUnassigned(c)).toList()
                : allCowsInFarm;

            final unassignedCount = allCowsInFarm.where((c) => isCowUnassigned(c)).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'เพิ่มวัวเข้า ${widget.zone.name}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'เลือกวัวที่ต้องการย้ายเข้าโซนนี้',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textSecondary, size: 24),
                        ),
                      ],
                    ),
                  ),

                  // Filter Chips (ทั้งหมด / ยังไม่มีโซน)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        FilterChip(
                          selected: !showOnlyUnassigned,
                          label: Text('ทั้งหมด (${allCowsInFarm.length})'),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: !showOnlyUnassigned ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: !showOnlyUnassigned ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() {
                                showOnlyUnassigned = false;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: showOnlyUnassigned,
                          label: Text('ยังไม่มีโซน ($unassignedCount)'),
                          selectedColor: Colors.orange.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: showOnlyUnassigned ? Colors.orange[800] : AppColors.textSecondary,
                            fontWeight: showOnlyUnassigned ? FontWeight.bold : FontWeight.normal,
                          ),
                          avatar: showOnlyUnassigned
                              ? Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange[800])
                              : null,
                          onSelected: (selected) {
                            setModalState(() {
                              showOnlyUnassigned = selected;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Select All + Counter
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 16, 4),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              final isAllSelectedInFilter = filteredCows.every((c) => selectedCows.contains(c));
                              if (isAllSelectedInFilter) {
                                selectedCows.removeAll(filteredCows);
                              } else {
                                selectedCows.addAll(filteredCows);
                              }
                            });
                          },
                          icon: Icon(
                            filteredCows.isNotEmpty && filteredCows.every((c) => selectedCows.contains(c))
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          label: Text(
                            filteredCows.isNotEmpty && filteredCows.every((c) => selectedCows.contains(c))
                                ? 'ยกเลิกทั้งหมด'
                                : 'เลือกทั้งหมด',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${selectedCows.length}/${filteredCows.length} ตัว',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.border),

                  // Cow List
                  Expanded(
                    child: filteredCows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pets_rounded, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  showOnlyUnassigned ? 'ไม่มีวัวที่ยังไม่มีโซน' : 'ไม่มีวัวในระบบ',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredCows.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: 76,
                              color: AppColors.border.withValues(alpha: 0.5),
                            ),
                            itemBuilder: (context, index) {
                              final cow = filteredCows[index];
                              final isSelected = selectedCows.contains(cow);
                              final statusColor = _getStatusColor(cow);
                              final isUnassigned = cow.zoneId.isEmpty || cow.zoneId == 'null' || cow.zoneId == '0';
                              final currentZoneName = isUnassigned
                                  ? 'ยังไม่มีโซน'
                                  : (allZonesMap[cow.zoneId] ?? 'โซนอื่น (${cow.zoneId})');

                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      selectedCows.remove(cow);
                                    } else {
                                      selectedCows.add(cow);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.border,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded,
                                                color: Colors.white, size: 18)
                                            : null,
                                      ),
                                      const SizedBox(width: 14),

                                      // Avatar
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: cow.imageFullUrl != null &&
                                                cow.imageFullUrl!.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.network(
                                                  cow.imageFullUrl!,
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : const Icon(Icons.pets_rounded,
                                                color: AppColors.primary, size: 22),
                                      ),
                                      const SizedBox(width: 14),

                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    cow.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 17,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withValues(
                                                        alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    cow.status.label,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isUnassigned
                                                        ? Colors.amber[100]
                                                        : Colors.blue[50],
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: isUnassigned
                                                          ? Colors.orange[300]!
                                                          : Colors.blue[200]!,
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isUnassigned ? 'ยังไม่มีโซน' : 'ย้ายจาก: $currentZoneName',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isUnassigned
                                                          ? Colors.orange[900]
                                                          : Colors.blue[900],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'แท็ก: ${cow.tagNumber} · ${cow.type.label}',
                                                    style: const TextStyle(
                                                      color: AppColors.textSecondary,
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
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom action bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: selectedCows.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(modalContext);
                                  _moveMultipleCowsToZone(
                                      selectedCows.toList());
                                },
                          icon: const Icon(Icons.check_circle_rounded,
                              size: 22),
                          label: Text(
                            selectedCows.isEmpty
                                ? 'เลือกวัวที่ต้องการเพิ่ม'
                                : 'เพิ่ม ${selectedCows.length} ตัวเข้าโซน',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.border.withValues(alpha: 0.5),
                            disabledForegroundColor: AppColors.textHint,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cowsInZone = _cowsInZone;
    final cowState = ref.watch(cowProvider);

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
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                  child: Column(
                    children: [
                      // Top Row
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.zone.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'จัดการวัวในโซนนี้',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed:
                                  _isLoading ? null : _showAddCowBottomSheet,
                              icon: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 26),
                              tooltip: 'เพิ่มวัวเข้าโซน',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Zone Stats Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.grass_rounded,
                                  color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.zone.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${cowsInZone.length} ตัว ในโซนนี้',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${cowsInZone.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

          // ── Section Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'รายชื่อวัว (${cowsInZone.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading / Empty / Cow List ──
          if (cowState.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary)),
              ),
            )
          else if (cowsInZone.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pets_rounded,
                          size: 44, color: AppColors.primary),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'ยังไม่มีวัวในโซนนี้',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'แตะปุ่มด้านล่างเพื่อเพิ่มวัวเข้าโซนนี้',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _showAddCowBottomSheet,
                        icon: const Icon(Icons.add_rounded, size: 22),
                        label: const Text('เพิ่มวัวเข้าโซน',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cow = cowsInZone[index];
                  return Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildCowCard(context, cow),
                  );
                },
                childCount: cowsInZone.length,
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),

      // FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showAddCowBottomSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text('เพิ่มวัว',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildCowCard(BuildContext context, Cow cow) {
    final statusColor = _getStatusColor(cow);

    return InkWell(
      onTap: () => context.push('/cow_detail', extra: cow),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: cow.imageFullUrl != null &&
                      cow.imageFullUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        cow.imageFullUrl!,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.pets_rounded,
                      color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          cow.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cow.status.label,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildInfoChip('แท็ก: ${cow.tagNumber}'),
                      _buildInfoChip(cow.type.label),
                      _buildInfoChip(cow.breed),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Remove button
            InkWell(
              onTap: () => _removeCowFromZone(cow),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.remove_circle_outline_rounded,
                    color: AppColors.error, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
