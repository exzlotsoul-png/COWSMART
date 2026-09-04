import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
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

  // Search Query
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
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 68.0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ประวัติทั้งหมด',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${widget.cow.name} (${widget.cow.tagNumber})',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.health_and_safety_rounded, size: 18), text: 'ประวัติสุขภาพ'),
                Tab(icon: Icon(Icons.monitor_weight_rounded, size: 18), text: 'ประวัติน้ำหนัก'),
                Tab(icon: Icon(Icons.favorite_rounded, size: 18), text: 'ประวัติผสมพันธุ์'),
              ],
            ),
          ),
        ),
      ),
      body: detailState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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

  // ── 1. HEALTH HISTORY TAB ──
  Widget _buildHealthHistoryTab(List<HealthRecord> records, MasterDataState masterData) {
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
        // Filter & Search Header Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.25 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                decoration: InputDecoration(
                  hintText: 'ค้นหาโรค, ยา, วัคซีน, หมายเหตุ...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.hint(context)),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
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
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: Icons.health_and_safety_outlined,
                  message: records.isEmpty ? 'ยังไม่มีประวัติการรักษา' : 'ไม่พบข้อมูลที่ตรงกับคำค้นหา',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
        icon = Icons.vaccines_rounded;
        break;
      case 'CT03':
        typeColor = AppColors.error;
        icon = Icons.medical_services_rounded;
        break;
      case 'CT04':
        typeColor = AppColors.warning;
        icon = Icons.bug_report_rounded;
        break;
      default:
        typeColor = AppColors.success;
        icon = Icons.health_and_safety_rounded;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: typeColor, width: 4.5)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: typeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                typeLabels[record.checkupTypeId] ?? 'ตรวจสุขภาพ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text(context),
                                ),
                              ),
                            ),
                            if (statusText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusBgColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusBgColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppDateUtils.formatThaiDate(record.recordDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.text(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (record.cost != null && record.cost! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (AppColors.isDark(context) ? AppColors.warning : AppColors.secondaryDark).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${NumberFormat('#,##0').format(record.cost)} ฿',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.isDark(context) ? const Color(0xFFFBBF24) : AppColors.secondaryDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),

              // Items Section (Vaccine, Disease, Medicine) using Icons instead of Emojis
              if (record.vaccineName != null || record.diseaseName != null || record.medicineName != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfAlt(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brd(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (record.vaccineName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.vaccines_outlined, size: 16, color: AppColors.info),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'วัคซีน: ${record.vaccineName!}$dosageStr',
                                  style: TextStyle(fontSize: 13.5, color: AppColors.text(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (record.diseaseName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.coronavirus_outlined, size: 16, color: AppColors.error),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'โรค: ${record.diseaseName!}',
                                  style: TextStyle(fontSize: 13.5, color: AppColors.text(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (record.medicineName != null)
                        Row(
                          children: [
                            const Icon(Icons.medication_outlined, size: 16, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'ยา: ${record.medicineName!}$dosageStr',
                                style: TextStyle(fontSize: 13.5, color: AppColors.text(context)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],

              // Note using Icon instead of Emoji
              if (record.note != null && record.note!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note_alt_outlined, size: 15, color: AppColors.subText(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'หมายเหตุ: ${record.note!}',
                        style: TextStyle(fontSize: 13, color: AppColors.text(context)),
                      ),
                    ),
                  ],
                ),
              ],

              // Admin name using Icon instead of Emoji
              if (record.adminName != null && record.adminName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 15, color: AppColors.subText(context)),
                    const SizedBox(width: 6),
                    Text(
                      'ผู้ดำเนินการ: ${record.adminName!}',
                      style: TextStyle(fontSize: 12.5, color: AppColors.subText(context), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 2. GROWTH HISTORY TAB ──
  Widget _buildGrowthHistoryTab(List<GrowthRecord> records) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.cardBg(context),
          child: Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'บันทึกน้ำหนักทั้งหมด (${records.length} ครั้ง)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text(context)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: records.isEmpty
              ? _buildEmptyState(
                  icon: Icons.scale_outlined,
                  message: 'ยังไม่มีประวัติน้ำหนัก',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: records.length,
                  itemBuilder: (ctx, index) {
                    final r = records[index];
                    final prev = index < records.length - 1 ? records[index + 1].weight : null;
                    final diff = prev != null ? r.weight - prev : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.25 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.scale_rounded, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary, size: 22),
                        ),
                        title: Text(
                          '${r.weight.toStringAsFixed(1)} กก.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.text(context)),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'วันที่ชั่ง: ${AppDateUtils.formatThaiDate(r.recordDate)}${r.girth != null ? " • รอบอก: ${r.girth!.toStringAsFixed(1)} ซม." : ""}',
                            style: TextStyle(fontSize: 13, color: AppColors.subText(context), fontWeight: FontWeight.w500),
                          ),
                        ),
                        trailing: diff != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (diff >= 0 ? (AppColors.isDark(context) ? const Color(0xFF8FD475) : AppColors.success) : AppColors.error).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(1)} กก.',
                                  style: TextStyle(
                                    color: diff >= 0 ? (AppColors.isDark(context) ? const Color(0xFF8FD475) : AppColors.success) : AppColors.error,
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

  // ── 3. BREEDING HISTORY TAB ──
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
          color: AppColors.cardBg(context),
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
              ? _buildEmptyState(
                  icon: Icons.favorite_border_rounded,
                  message: 'ไม่พบข้อมูลประวัติผสมพันธุ์',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final r = filtered[index];
                    final allCows = ref.watch(cowProvider).allCows;

                    final stageColor = r.pregnancyResult == 'ตั้งท้อง'
                        ? (AppColors.isDark(context) ? const Color(0xFFC084FC) : Colors.purple)
                        : r.pregnancyResult == 'ไม่ตั้งท้อง'
                            ? AppColors.error
                            : AppColors.warning;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: stageColor.withValues(alpha: AppColors.isDark(context) ? 0.4 : 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.25 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.favorite_rounded, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      r.heatDate != null
                                          ? 'เป็นสัด: ${AppDateUtils.formatThaiDate(r.heatDate!)}'
                                          : 'ผสมพันธุ์',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.text(context),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: stageColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    r.pregnancyResult ?? 'รอตรวจท้อง',
                                    style: TextStyle(
                                      color: stageColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (r.matingDate != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.event_available_outlined, size: 15, color: AppColors.subText(context)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'วันที่ผสม: ${AppDateUtils.formatThaiDate(r.matingDate!, includeTime: true)}',
                                        style: TextStyle(fontSize: 13.5, color: AppColors.text(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (r.sireId != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    CowIcon(size: 15, color: AppColors.subText(context)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'พ่อพันธุ์: ${_formatCowDisplayById(r.sireId, allCows)}',
                                        style: TextStyle(fontSize: 13.5, color: AppColors.text(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (r.expectedCalving != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_calendar_outlined, size: 15, color: AppColors.subText(context)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'คาดว่าจะคลอด: ${AppDateUtils.formatThaiDate(r.expectedCalving!)}',
                                        style: TextStyle(fontSize: 13.5, color: AppColors.text(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (r.calvingDate != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.child_care_rounded, size: 16, color: AppColors.isDark(context) ? const Color(0xFF2DD4BF) : Colors.teal),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'คลอดจริง: ${AppDateUtils.formatThaiDate(r.calvingDate!)} (${r.calvingResult ?? "-"})',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.isDark(context) ? const Color(0xFF2DD4BF) : Colors.teal,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ],
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
          color: isSelected ? Colors.white : AppColors.text(context),
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfAlt(context),
      elevation: isSelected ? 1 : 0,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.brd(context).withValues(alpha: 0.5),
      ),
      onSelected: (_) => onSelect(value),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfAlt(context),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: AppColors.hint(context)),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: AppColors.subText(context), fontWeight: FontWeight.w500),
          ),
        ],
      ),
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
