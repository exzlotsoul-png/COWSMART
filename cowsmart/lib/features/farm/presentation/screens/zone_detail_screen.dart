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

  Future<void> _removeCowFromZone(Cow cow) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการนำวัวออกจากโซน'),
        content: Text('นำ ${cow.name} ออกจาก ${widget.zone.name}?'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ยืนยัน'),
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
              .updateCowZone(
                cow.id,
                '', // Empty zoneId to remove from zone
                currentFarm.id,
              );
          // Refresh zones to update cow count on dashboard
          await ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('นำ ${cow.name} ออกจากโซนแล้ว'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
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
        print('[ERROR] ย้ายวัว ${cow.name} ไม่สำเร็จ: $e');
      }
    }

    // Refresh zones to update cow count on dashboard
    await ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เพิ่มวัวสำเร็จ $successCount ตัว${failCount > 0 ? ', ไม่สำเร็จ $failCount ตัว' : ''}',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : AppColors.success,
        ),
      );
    }
  }

  void _showAddCowDialog() {
    final availableCows = _cowsNotInZone;
    if (availableCows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีวัวที่สามารถเพิ่มเข้าโซนได้')),
      );
      return;
    }

    final selectedCows = <Cow>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('เพิ่มวัวเข้า ${widget.zone.name}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  // Select All / Clear All buttons
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            if (selectedCows.length == availableCows.length) {
                              selectedCows.clear();
                            } else {
                              selectedCows.addAll(availableCows);
                            }
                          });
                        },
                        icon: Icon(
                          selectedCows.length == availableCows.length
                              ? Icons.check_box_outlined
                              : Icons.check_box_outline_blank,
                        ),
                        label: Text(
                          selectedCows.length == availableCows.length
                              ? 'ยกเลิกเลือกทั้งหมด'
                              : 'เลือกทั้งหมด',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${selectedCows.length}/${availableCows.length} ตัว',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  // List with checkboxes
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableCows.length,
                      itemBuilder: (context, index) {
                        final cow = availableCows[index];
                        final isSelected = selectedCows.contains(cow);

                        Color statusColor;
                        switch (cow.status.colorType) {
                          case 'success':
                            statusColor = Colors.green;
                            break;
                          case 'error':
                            statusColor = Colors.red;
                            break;
                          case 'warning':
                            statusColor = Colors.orange;
                            break;
                          case 'info':
                            statusColor = Colors.blue;
                            break;
                          default:
                            statusColor = Colors.grey;
                        }

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedCows.add(cow);
                              } else {
                                selectedCows.remove(cow);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cow.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  cow.status.label,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'แท็ก: ${cow.tagNumber} | ${cow.type.label}',
                          ),
                          secondary: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.pets,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedCows.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _moveMultipleCowsToZone(selectedCows.toList());
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('เพิ่ม ${selectedCows.length} ตัว'),
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

  @override
  Widget build(BuildContext context) {
    final cowsInZone = _cowsInZone;
    final cowState = ref.watch(cowProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.zone.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _showAddCowDialog,
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่มวัวเข้าโซน',
          ),
        ],
      ),
      body: cowState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final currentFarm = ref.read(farmProvider).currentFarm;
                if (currentFarm != null) {
                  await ref
                      .read(cowProvider.notifier)
                      .fetchCows(currentFarm.id);
                  await ref
                      .read(zoneProvider.notifier)
                      .fetchZones(currentFarm.id);
                }
              },
              child: Column(
                children: [
                  // Zone Info Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.fence, color: AppColors.primary, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.zone.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${cowsInZone.length} ตัว ในฟาร์ม',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cows List
                  Expanded(
                    child: cowsInZone.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.pets_outlined,
                                  size: 64,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'ยังไม่มีวัวในโซนนี้',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _showAddCowDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('เพิ่มวัวเข้าโซน'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: cowsInZone.length,
                            itemBuilder: (context, index) {
                              final cow = cowsInZone[index];
                              return _CowCard(
                                cow: cow,
                                onRemove: () => _removeCowFromZone(cow),
                                onTap: () =>
                                    context.push('/cow_detail', extra: cow),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showAddCowDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'เพิ่มวัว',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _CowCard extends StatelessWidget {
  final Cow cow;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _CowCard({
    required this.cow,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (cow.status.colorType) {
      case 'success':
        statusColor = Colors.green;
        break;
      case 'error':
        statusColor = Colors.red;
        break;
      case 'warning':
        statusColor = Colors.orange;
        break;
      case 'info':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: cow.imageFullUrl != null && cow.imageFullUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          cow.imageFullUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.pets, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cow.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'แท็ก: ${cow.tagNumber}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cow.status.label,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cow.type.label} | ${cow.breed}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                tooltip: 'นำออกจากโซน',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
