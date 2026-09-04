import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
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
  int? _filterStatus; // null = all, 0 = sold, 2 = removed, 1 = dead
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(_cullingHistoryProvider);
    final allCows = ref.watch(cowProvider).allCows;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
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
            final cow = r.cow ?? allCows.cast<Cow?>().firstWhere((c) => c?.id == r.cowId, orElse: () => null);

            // Filter by culling status: 0=sold, 1=dead, 2=removed
            if (_filterStatus != null && r.status != _filterStatus) {
              return false;
            }

            // Filter by cow type
            if (_filterCowType != null && cow?.type != _filterCowType) {
              return false;
            }

            // Filter by search query (name, tag, or note)
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final name = (cow?.name ?? '').toLowerCase();
              final tag = (cow?.tagNumber ?? '').toLowerCase();
              final note = r.note.toLowerCase();
              if (!name.contains(q) && !tag.contains(q) && !note.contains(q)) {
                return false;
              }
            }

            return true;
          }).toList();

          final sold = records.where((r) => r.status == 0).length;
          final dead = records.where((r) => r.status == 1).length;
          final removed = records.where((r) => r.status == 2).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top 4 Summary Cards (Clickable to filter by status)
              _buildSummaryBar(context, records.length, sold, dead, removed),

              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาด้วยชื่อ หรือรหัสหูวัว...',
                    hintStyle: TextStyle(fontSize: 14.5, color: AppColors.hint(context)),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfAlt(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),

              // Status Filter Chips
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('ทั้งหมด', style: TextStyle(fontSize: 13.5)),
                        selected: _filterStatus == null,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(color: _filterStatus == null ? AppColors.primary : AppColors.brd(context)),
                        labelStyle: TextStyle(
                          color: _filterStatus == null ? Colors.white : AppColors.text(context),
                          fontWeight: _filterStatus == null ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _filterStatus = null),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('ขาย', style: TextStyle(fontSize: 13.5)),
                        selected: _filterStatus == 0,
                        selectedColor: AppColors.success,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(color: _filterStatus == 0 ? AppColors.success : AppColors.brd(context)),
                        labelStyle: TextStyle(
                          color: _filterStatus == 0 ? Colors.white : AppColors.text(context),
                          fontWeight: _filterStatus == 0 ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _filterStatus = _filterStatus == 0 ? null : 0),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('คัดออก', style: TextStyle(fontSize: 13.5)),
                        selected: _filterStatus == 2,
                        selectedColor: AppColors.warning,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(color: _filterStatus == 2 ? AppColors.warning : AppColors.brd(context)),
                        labelStyle: TextStyle(
                          color: _filterStatus == 2 ? Colors.white : AppColors.text(context),
                          fontWeight: _filterStatus == 2 ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _filterStatus = _filterStatus == 2 ? null : 2),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('ตาย', style: TextStyle(fontSize: 13.5)),
                        selected: _filterStatus == 1,
                        selectedColor: AppColors.error,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(color: _filterStatus == 1 ? AppColors.error : AppColors.brd(context)),
                        labelStyle: TextStyle(
                          color: _filterStatus == 1 ? Colors.white : AppColors.text(context),
                          fontWeight: _filterStatus == 1 ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _filterStatus = _filterStatus == 1 ? null : 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Cow Type Filter Chips
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('ทุกประเภท', style: TextStyle(fontSize: 13.5)),
                        selected: _filterCowType == null,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(color: _filterCowType == null ? AppColors.primary : AppColors.brd(context)),
                        labelStyle: TextStyle(
                          color: _filterCowType == null ? Colors.white : AppColors.text(context),
                          fontWeight: _filterCowType == null ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _filterCowType = null),
                      ),
                      const SizedBox(width: 6),
                      ...CowType.values.map((type) {
                        final isSelected = _filterCowType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(type.label, style: const TextStyle(fontSize: 13.5)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: isSelected ? AppColors.primary : AppColors.brd(context)),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.text(context),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                            onSelected: (_) => setState(() => _filterCowType = isSelected ? null : type),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              Expanded(
                child: filteredRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'ไม่พบประวัติที่ตรงกับ "$_searchQuery"'
                                  : 'ไม่พบประวัติการจำหน่ายและคัดออกตามเงื่อนไขที่เลือก',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            ),
                          ],
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
      color: AppColors.cardBg(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _SummaryChip(
            label: 'ทั้งหมด',
            value: '$total ตัว',
            color: AppColors.primary,
            isSelected: _filterStatus == null,
            onTap: () {
              setState(() => _filterStatus = null);
            },
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'ขาย',
            value: '$sold ตัว',
            color: AppColors.success,
            isSelected: _filterStatus == 0,
            onTap: () {
              setState(() {
                _filterStatus = _filterStatus == 0 ? null : 0;
              });
            },
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'คัดออก',
            value: '$removed ตัว',
            color: AppColors.warning,
            isSelected: _filterStatus == 2,
            onTap: () {
              setState(() {
                _filterStatus = _filterStatus == 2 ? null : 2;
              });
            },
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'ตาย',
            value: '$dead ตัว',
            color: AppColors.error,
            isSelected: _filterStatus == 1,
            onTap: () {
              setState(() {
                _filterStatus = _filterStatus == 1 ? null : 1;
              });
            },
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
  final bool isSelected;
  final VoidCallback onTap;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.18)
                  : AppColors.surfAlt(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : AppColors.brd(context),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : color.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : AppColors.subText(context),
                  ),
                ),
              ],
            ),
          ),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ยกเลิก', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(cowProvider.notifier).restoreCulledCow(record.id, displayCow);
                    ref.invalidate(_cullingHistoryProvider);
                  },
                  child: const Text('ยืนยันดึงกลับ'),
                ),
              ),
            ],
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
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      color: AppColors.cardBg(context),
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
                    color: color.withValues(alpha: 0.12),
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
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.text(context)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
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
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            AppDateUtils.formatThaiDate(record.cullDate, useFullMonth: true),
                            style: TextStyle(
                                fontSize: 12, color: AppColors.subText(context), fontWeight: FontWeight.w600),
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
                            color: AppColors.surfAlt(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            record.note,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.subText(context)),
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
              Divider(height: 1, color: AppColors.div(context)),
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
