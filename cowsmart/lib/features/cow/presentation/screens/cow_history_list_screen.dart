import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/health_record.dart';
import 'package:cowsmart/features/cow/domain/growth_record.dart';
import 'package:cowsmart/features/cow/domain/breeding_record.dart';
import 'package:cowsmart/features/cow/providers/cow_detail_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/health/providers/master_data_provider.dart';

class CowHistoryListScreen extends ConsumerStatefulWidget {
  final Cow cow;
  final String initialTab; // 'health', 'growth', 'breeding'

  const CowHistoryListScreen({
    super.key,
    required this.cow,
    this.initialTab = 'health',
  });

  @override
  ConsumerState<CowHistoryListScreen> createState() => _CowHistoryListScreenState();
}

class _CowHistoryListScreenState extends ConsumerState<CowHistoryListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Health Filters
  String _healthTypeFilter = 'ALL'; // ALL, CT01, CT02, CT03
  
  // Growth Filter / Search
  String _searchQuery = '';

  // Breeding Filter
  String _breedingResultFilter = 'ALL'; // ALL, PREGNANT, NOT_PREGNANT, CALVED

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialTab == 'growth') initialIndex = 1;
    if (widget.initialTab == 'breeding') initialIndex = 2;

    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    
    // Ensure detail data is loaded
    Future.microtask(() {
      ref.read(cowDetailProvider.notifier).fetchAllData(widget.cow.id);
      ref.read(masterDataProvider.notifier).fetchAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(cowDetailProvider);
    final masterData = ref.watch(masterDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ประวัติทั้งหมด',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${widget.cow.name} (${widget.cow.tagNumber})',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.health_and_safety, size: 20), text: 'ประวัติสุขภาพ'),
            Tab(icon: Icon(Icons.monitor_weight, size: 20), text: 'ประวัติน้ำหนัก'),
            Tab(icon: Icon(Icons.favorite, size: 20), text: 'ประวัติผสมพันธุ์'),
          ],
        ),
      ),
      body: detailState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHealthHistoryTab(detailState.healthRecords, masterData),
                _buildGrowthHistoryTab(detailState.growthRecords),
                _buildBreedingHistoryTab(detailState.breedingRecords),
              ],
            ),
    );
  }

  // --- 1. HEALTH HISTORY TAB ---
  Widget _buildHealthHistoryTab(List<HealthRecord> records, MasterDataState masterData) {
    // Filter
    final filtered = records.where((r) {
      if (_healthTypeFilter != 'ALL' && r.checkupTypeId != _healthTypeFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final note = (r.note ?? '').toLowerCase();
        final admin = (r.adminName ?? '').toLowerCase();
        final disease = (r.diseaseName ?? '').toLowerCase();
        final med = (r.medicineName ?? '').toLowerCase();
        final vac = (r.vaccineName ?? '').toLowerCase();
        return note.contains(q) || admin.contains(q) || disease.contains(q) || med.contains(q) || vac.contains(q);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ค้นหาโรค, ยา, วัคซีน, หมายเหตุ...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ทั้งหมด (${records.length})', 'ALL', _healthTypeFilter, (val) {
                      setState(() => _healthTypeFilter = val);
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('ตรวจสุขภาพทั่วไป', 'CT01', _healthTypeFilter, (val) {
                      setState(() => _healthTypeFilter = val);
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('ฉีดวัคซีน', 'CT02', _healthTypeFilter, (val) {
                      setState(() => _healthTypeFilter = val);
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('ให้ยารักษา', 'CT03', _healthTypeFilter, (val) {
                      setState(() => _healthTypeFilter = val);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        records.isEmpty ? 'ยังไม่มีประวัติการรักษา' : 'ไม่พบข้อมูลที่ตรงกับตัวกรอง',
                        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final r = filtered[index];
                    return _buildHealthCardItem(r);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHealthCardItem(HealthRecord record) {
    final typeLabels = {
      'CT01': 'ตรวจสุขภาพทั่วไป',
      'CT02': 'ฉีดวัคซีน',
      'CT03': 'รักษาโรค',
      'CT04': 'ถ่ายพยาธิ',
    };

    Color typeColor;
    IconData icon;
    switch (record.checkupTypeId) {
      case 'CT02':
        typeColor = AppColors.info;
        icon = Icons.vaccines;
        break;
      case 'CT03':
        typeColor = AppColors.error;
        icon = Icons.medical_services;
        break;
      case 'CT04':
        typeColor = AppColors.warning;
        icon = Icons.bug_report;
        break;
      default:
        typeColor = AppColors.success;
        icon = Icons.health_and_safety;
    }

    String? statusText;
    Color statusBgColor = AppColors.success;
    if (record.checkupTypeId == 'CT01') {
      if (record.status == 'normal') {
        statusText = 'ปกติ';
        statusBgColor = AppColors.success;
      } else if (record.status == 'sick') {
        statusText = 'ป่วย';
        statusBgColor = AppColors.error;
      } else if (record.status == 'injured') {
        statusText = 'บาดเจ็บ';
        statusBgColor = const Color(0xFFD97706);
      }
    }

    String dosageStr = '';
    if (record.amount != null) {
      final amt = record.amount!;
      final amtStr = amt % 1 == 0 ? amt.toInt().toString() : amt.toString();
      final unit = record.unitAbbreviation ?? record.unitName ?? '';
      dosageStr = ' ($amtStr $unit)'.trimRight();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: typeColor, width: 4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              typeLabels[record.checkupTypeId] ?? 'ตรวจสุขภาพ',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (statusText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusBgColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(color: statusBgColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(record.recordDate),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (record.cost != null && record.cost! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${NumberFormat('#,##0').format(record.cost)} ฿',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryDark, fontSize: 14),
                    ),
                  ),
              ],
            ),
            if (record.vaccineName != null || record.diseaseName != null || record.medicineName != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (record.vaccineName != null)
                      Text('💉 วัคซีน: ${record.vaccineName!}$dosageStr', style: const TextStyle(fontSize: 14)),
                    if (record.diseaseName != null)
                      Text('🦠 โรค: ${record.diseaseName!}', style: const TextStyle(fontSize: 14)),
                    if (record.medicineName != null)
                      Text('💊 ยา: ${record.medicineName!}$dosageStr', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
            if (record.note != null && record.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('📝 หมายเหตุ: ${record.note!}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            if (record.adminName != null && record.adminName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('👤 ผู้ดำเนินการ: ${record.adminName!}', style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
            ],
          ],
        ),
      ),
    );
  }

  // --- 2. GROWTH HISTORY TAB ---
  Widget _buildGrowthHistoryTab(List<GrowthRecord> records) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.monitor_weight_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'บันทึกน้ำหนักทั้งหมด (${records.length} ครั้ง)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text('ยังไม่มีประวัติน้ำหนัก', style: TextStyle(color: Colors.grey[600])),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  itemBuilder: (ctx, index) {
                    final r = records[index];
                    final prev = index < records.length - 1 ? records[index + 1].weight : null;
                    final diff = prev != null ? r.weight - prev : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.scale, color: AppColors.primary),
                        ),
                        title: Text(
                          '${r.weight.toStringAsFixed(1)} กก.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text(
                          'วันที่ชั่ง: ${DateFormat('dd/MM/yyyy').format(r.recordDate)}${r.girth != null ? " • รอบอก: ${r.girth!.toStringAsFixed(1)} ซม." : ""}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: diff != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (diff >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(1)} กก.',
                                  style: TextStyle(
                                    color: diff >= 0 ? Colors.green[800] : Colors.red[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- 3. BREEDING HISTORY TAB ---
  Widget _buildBreedingHistoryTab(List<BreedingRecord> records) {
    final filtered = records.where((r) {
      if (_breedingResultFilter == 'PREGNANT' && r.pregnancyResult != 'ตั้งท้อง') return false;
      if (_breedingResultFilter == 'NOT_PREGNANT' && r.pregnancyResult != 'ไม่ตั้งท้อง') return false;
      if (_breedingResultFilter == 'CALVED' && r.calvingDate == null) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ทั้งหมด (${records.length})', 'ALL', _breedingResultFilter, (val) {
                  setState(() => _breedingResultFilter = val);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('ตั้งท้อง', 'PREGNANT', _breedingResultFilter, (val) {
                  setState(() => _breedingResultFilter = val);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('ไม่ตั้งท้อง', 'NOT_PREGNANT', _breedingResultFilter, (val) {
                  setState(() => _breedingResultFilter = val);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('คลอดแล้ว', 'CALVED', _breedingResultFilter, (val) {
                  setState(() => _breedingResultFilter = val);
                }),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('ไม่พบข้อมูลประวัติผสมพันธุ์', style: TextStyle(color: Colors.grey[600])),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final r = filtered[index];
                    final allCows = ref.watch(cowProvider).allCows;

                    final stageColor = r.pregnancyResult == 'ตั้งท้อง'
                        ? Colors.teal
                        : r.pregnancyResult == 'ไม่ตั้งท้อง'
                            ? Colors.red
                            : Colors.orange;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: stageColor.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r.heatDate != null
                                      ? 'เป็นสัด: ${DateFormat('dd/MM/yyyy').format(r.heatDate!)}'
                                      : 'ผสมพันธุ์',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: stageColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r.pregnancyResult ?? 'รอตรวจท้อง',
                                    style: TextStyle(color: stageColor, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (r.matingDate != null)
                              Text('• วันที่ผสม: ${DateFormat('dd/MM/yyyy HH:mm น.').format(r.matingDate!)}', style: const TextStyle(fontSize: 14)),
                            if (r.sireId != null)
                              Text('• พ่อพันธุ์: ${_formatCowDisplayById(r.sireId, allCows)}', style: const TextStyle(fontSize: 14)),
                            if (r.expectedCalving != null)
                              Text('• คาดว่าจะคลอด: ${DateFormat('dd/MM/yyyy').format(r.expectedCalving!)}', style: const TextStyle(fontSize: 14)),
                            if (r.calvingDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '• คลอดจริง: ${DateFormat('dd/MM/yyyy').format(r.calvingDate!)} (${r.calvingResult ?? "-"})',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue, Function(String) onSelect) {
    final isSelected = value == currentValue;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey[100],
      onSelected: (_) => onSelect(value),
    );
  }

  String _formatCowDisplayById(String? id, List<Cow> allCows) {
    if (id == null || id.isEmpty || id == '-') return '-';
    final matches = allCows.where((c) => c.id == id || c.tagNumber == id || c.name == id).toList();
    if (matches.isNotEmpty) {
      final cow = matches.first;
      if (cow.name.isNotEmpty && cow.tagNumber.isNotEmpty && cow.name != cow.tagNumber) {
        return '${cow.name} (${cow.tagNumber})';
      } else if (cow.name.isNotEmpty) {
        return cow.name;
      } else if (cow.tagNumber.isNotEmpty) {
        return cow.tagNumber;
      }
    }
    return id;
  }
}
