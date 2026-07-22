import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import '../../domain/culling_record.dart';

final _cullingHistoryProvider = FutureProvider.autoDispose<List<CullingRecord>>(
  (ref) async {
    final farmId = ref.watch(farmProvider).currentFarm?.id;
    if (farmId == null) return [];
    final api = ref.read(apiClientProvider);
    final response = await api.get(
      '/culling_records',
      query: {'farm_id': farmId},
    );
    final list = (response.data as List)
        .map((j) => CullingRecord.fromJson(j))
        .toList();
    list.sort((a, b) => b.cullDate.compareTo(a.cullDate));
    return list;
  },
);

class CullingHistoryScreen extends ConsumerStatefulWidget {
  const CullingHistoryScreen({super.key});

  @override
  ConsumerState<CullingHistoryScreen> createState() => _CullingHistoryScreenState();
}

class _CullingHistoryScreenState extends ConsumerState<CullingHistoryScreen> {
  CowType? _filterCowType;

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(_cullingHistoryProvider);
    final allCows = ref.watch(cowProvider).allCows;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ประวัติการจำหน่ายและคัดออก'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_sweep_outlined,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ยังไม่มีประวัติการจำหน่ายและคัดออก',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final filteredRecords = records.where((r) {
            if (_filterCowType == null) return true;
            final cow = r.cow ?? allCows.cast<Cow?>().firstWhere((c) => c?.id == r.cowId, orElse: () => null);
            return cow?.type == _filterCowType;
          }).toList();

          final sold = records.where((r) => r.status == 0).length;
          final dead = records.where((r) => r.status == 1).length;
          final removed = records.where((r) => r.status == 2).length;

          return Column(
            children: [
              _buildSummaryBar(context, records.length, sold, dead, removed),
              const SizedBox(height: 8),
              // Cow Type Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('ประเภท: ทั้งหมด'),
                      selected: _filterCowType == null,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) setState(() => _filterCowType = null);
                      },
                    ),
                    const SizedBox(width: 8),
                    ...CowType.values.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type.label),
                          selected: _filterCowType == type,
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          onSelected: (selected) {
                            setState(() {
                              _filterCowType = selected ? type : null;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filteredRecords.isEmpty
                    ? const Center(
                        child: Text(
                          'ไม่พบประวัติการจำหน่ายและคัดออกในประเภทนี้',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRecords.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final r = filteredRecords[index];
                          final cow = allCows.cast<Cow?>().firstWhere(
                                (c) => c?.id == r.cowId,
                                orElse: () => null,
                              );
                          return _CullingCard(record: r, cow: cow);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryBar(
    BuildContext context,
    int total,
    int sold,
    int dead,
    int removed,
  ) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _SummaryChip(
            label: 'ทั้งหมด',
            value: '$total ตัว',
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'ขาย',
            value: '$sold ตัว',
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'คัดออก',
            value: '$removed ตัว',
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'ตาย',
            value: '$dead ตัว',
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CullingCard extends ConsumerWidget {
  final CullingRecord record;
  final Cow? cow;

  const _CullingCard({required this.record, this.cow});

  Color get _statusColor {
    switch (record.status) {
      case 0:
        return AppColors.success;
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      default:
        return AppColors.textHint;
    }
  }

  IconData get _statusIcon {
    switch (record.status) {
      case 0:
        return Icons.sell_outlined;
      case 1:
        return Icons.sentiment_very_dissatisfied_outlined;
      case 2:
        return Icons.remove_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref, Cow displayCow) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.settings_backup_restore, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('ยืนยันดึงวัวกลับคืน'),
          ],
        ),
        content: Text(
          'คุณต้องการดึงข้อมูลของวัว "${displayCow.name.isNotEmpty ? displayCow.name : displayCow.tagNumber}" กลับเข้าฝูงหลักใช่หรือไม่?\n\n'
          'สถานะของวัวจะเปลี่ยนเป็นปกติ และยอดเงินรายรับจากการขาย (หากมี) ในระบบการเงินจะถูกลบออกโดยอัตโนมัติ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(cowProvider.notifier).restoreCulledCow(record.id, displayCow);
              ref.invalidate(_cullingHistoryProvider);
            },
            child: const Text('ยืนยันดึงกลับ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,##0');
    final color = _statusColor;
    final displayCow = record.cow ?? cow;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayCow != null
                                  ? '${displayCow.name} (${displayCow.tagNumber})'
                                  : record.cowId,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              record.statusLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 13, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd MMMM yyyy').format(record.cullDate),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      if (record.price > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.payments_outlined,
                                size: 13, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(
                              '฿${formatter.format(record.price)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success),
                            ),
                          ],
                        ),
                      ],
                      if (record.note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            record.note,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (displayCow != null && record.status != 1) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showRestoreDialog(context, ref, displayCow),
                    icon: const Icon(Icons.settings_backup_restore, size: 16),
                    label: const Text(
                      'ดึงวัวกลับคืนฝูง',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
