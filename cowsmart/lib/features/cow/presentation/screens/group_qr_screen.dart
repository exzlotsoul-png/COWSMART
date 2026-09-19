import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cow_icon.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../farm/providers/farm_provider.dart';
import '../../../farm/providers/zone_provider.dart';
import '../../domain/cow.dart';
import '../../domain/breed.dart';
import '../../providers/cow_provider.dart';
import '../../providers/breed_provider.dart';
import '../widgets/cow_qr_dialog.dart';
import '../../services/group_qr_pdf_export_service.dart';

class GroupQrScreen extends ConsumerStatefulWidget {
  const GroupQrScreen({super.key});

  @override
  ConsumerState<GroupQrScreen> createState() => _GroupQrScreenState();
}

class _GroupQrScreenState extends ConsumerState<GroupQrScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCowIds = {};

  String _searchQuery = '';
  String? _selectedZoneId;
  CowType? _filterType;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(cowProvider.notifier).fetchCows(currentFarm.id);
        ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
      }
      ref.read(breedProvider.notifier).fetchBreeds();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportPdfReport(List<Cow> selectedCows) async {
    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm == null) {
      AppFeedback.showError(context, 'ไม่พบข้อมูลฟาร์ม');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final breeds = ref.read(breedProvider);
      if (mounted) {
        setState(() => _isExporting = false);
        await GroupQrPdfExportService.exportGroupQrPdf(
          farm: currentFarm,
          cows: selectedCows,
          breeds: breeds,
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการสร้างเอกสาร: $e');
      }
    } finally {
      if (mounted && _isExporting) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _previewSingleCowQr(Cow cow) {
    showDialog(
      context: context,
      builder: (_) => CowQrDialog(cow: cow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cowState = ref.watch(cowProvider);
    final zoneState = ref.watch(zoneProvider);
    final breeds = ref.watch(breedProvider);
    final zones = zoneState.zones;

    // Filter cows following established project pattern
    final availableCows = cowState.allCows.where((c) {
      if (c.status == CowStatus.deceased ||
          c.status == CowStatus.sold ||
          c.status == CowStatus.removed) {
        return false;
      }
      if (_selectedZoneId != null && c.zoneId != _selectedZoneId) {
        return false;
      }
      if (_filterType != null && c.type != _filterType) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return c.tagNumber.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q) ||
            c.breed.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final isAllSelected = availableCows.isNotEmpty &&
        availableCows.every((c) => _selectedCowIds.contains(c.id));

    final selectedCowsList = cowState.allCows
        .where((c) => _selectedCowIds.contains(c.id))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'สร้าง QR Code กลุ่ม',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'เลือกวัวเพื่อพิมพ์ป้าย QR Code (${_selectedCowIds.length} ตัว)',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Container (Identical to group_health & group_appointment)
          Container(
            padding: const EdgeInsets.all(14),
            color: AppColors.cardBg(context),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาด้วยชื่อ, เบอร์วัว หรือสายพันธุ์...',
                    hintStyle: TextStyle(
                      fontSize: 14.5,
                      color: AppColors.hint(context),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.text(context),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 10),

                // Zone ChoiceChips Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('ทุกโซน', style: TextStyle(fontSize: 13.5)),
                        selected: _selectedZoneId == null,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(
                          color: _selectedZoneId == null
                              ? AppColors.primary
                              : AppColors.brd(context),
                        ),
                        labelStyle: TextStyle(
                          color: _selectedZoneId == null
                              ? Colors.white
                              : AppColors.text(context),
                          fontWeight: _selectedZoneId == null
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _selectedZoneId = null),
                      ),
                      const SizedBox(width: 8),
                      ...zones.map((zone) {
                        final isSelected = _selectedZoneId == zone.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(zone.name, style: const TextStyle(fontSize: 13.5)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.brd(context),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.text(context),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                            onSelected: (_) => setState(() => _selectedZoneId = zone.id),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // CowType ChoiceChips Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('ทุกประเภท', style: TextStyle(fontSize: 13)),
                        selected: _filterType == null,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(
                          color: _filterType == null
                              ? AppColors.primary
                              : AppColors.brd(context),
                        ),
                        labelStyle: TextStyle(
                          color: _filterType == null
                              ? Colors.white
                              : AppColors.text(context),
                          fontWeight: _filterType == null
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _filterType = null),
                      ),
                      const SizedBox(width: 8),
                      ...CowType.values.map((t) {
                        final isSelected = _filterType == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t.label, style: const TextStyle(fontSize: 13)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.brd(context),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.text(context),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                            onSelected: (_) =>
                                setState(() => _filterType = isSelected ? null : t),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Select All & Count Info Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surfAlt(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'พบวัวทั้งหมด ${availableCows.length} ตัว',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.subText(context),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (isAllSelected) {
                        _selectedCowIds.clear();
                      } else {
                        for (var c in availableCows) {
                          _selectedCowIds.add(c.id);
                        }
                      }
                    });
                  },
                  icon: Icon(
                    isAllSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    isAllSelected ? 'ยกเลิกการเลือก' : 'เลือกทั้งหมด',
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

          // Cows List
          Expanded(
            child: availableCows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CowIcon(
                          size: 48,
                          color: AppColors.subText(context).withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ไม่พบรายการวัวตรงตามเงื่อนไข',
                          style: TextStyle(
                            color: AppColors.subText(context),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: availableCows.length,
                    itemBuilder: (ctx, index) {
                      final cow = availableCows[index];
                      final isChecked = _selectedCowIds.contains(cow.id);

                      final breedObj = breeds.firstWhere(
                        (b) => b.id == cow.breed,
                        orElse: () => Breed(
                          id: cow.breed,
                          name: cow.breed.isNotEmpty ? cow.breed : '-',
                        ),
                      );
                      final breedDisplay =
                          breedObj.name.isNotEmpty ? breedObj.name : '-';
                      final genderDisplay =
                          (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male')
                              ? 'ผู้'
                              : 'เมีย';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isChecked
                                ? AppColors.primary
                                : AppColors.brd(context).withValues(alpha: 0.5),
                            width: isChecked ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isChecked) {
                                _selectedCowIds.remove(cow.id);
                              } else {
                                _selectedCowIds.add(cow.id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // Cow Avatar Image on the LEFT (with tap to preview QR)
                                InkWell(
                                  onTap: () => _previewSingleCowQr(cow),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Tooltip(
                                    message: 'แตะเพื่อดู QR Code',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        color: AppColors.surfAlt(context),
                                        child: (cow.imageFullUrl != null && cow.imageFullUrl!.isNotEmpty)
                                            ? Image.network(
                                                cow.imageFullUrl!,
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Center(
                                                  child: CowIcon(size: 24, color: AppColors.textHint),
                                                ),
                                              )
                                            : (cow.imageUrl != null && cow.imageUrl!.isNotEmpty)
                                                ? Image.network(
                                                    cow.imageUrl!,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: CowIcon(size: 24, color: AppColors.textHint),
                                                    ),
                                                  )
                                                : const Center(
                                                    child: CowIcon(size: 24, color: AppColors.textHint),
                                                  ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Cow Details in the MIDDLE
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Line 1: Name & Tag Number
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              cow.name.isNotEmpty
                                                  ? cow.name
                                                  : cow.tagNumber,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: AppColors.text(context),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (cow.tagNumber.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                cow.tagNumber,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: AppColors.primaryDark,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 5),

                                      // Line 2: Breed & Weight
                                      Text(
                                        'สายพันธุ์: $breedDisplay${cow.latestWeight > 0 ? ' • ${cow.latestWeight.toStringAsFixed(0)} กก.' : ''}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.text(context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 5),

                                      // Line 3: Gender Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male' ? Colors.blue : Colors.pink)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male' ? Colors.blue : Colors.pink)
                                                .withValues(alpha: 0.4),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male')
                                                  ? Icons.male_rounded
                                                  : Icons.female_rounded,
                                              size: 14,
                                              color: (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male')
                                                  ? Colors.blue[700]
                                                  : Colors.pink[600],
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              genderDisplay,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male')
                                                    ? Colors.blue[700]
                                                    : Colors.pink[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Checkbox on the RIGHT
                                Checkbox(
                                  value: isChecked,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedCowIds.add(cow.id);
                                      } else {
                                        _selectedCowIds.remove(cow.id);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เลือกแล้ว ${_selectedCowIds.length} ตัว',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    Text(
                      _selectedCowIds.isEmpty
                          ? 'แตะเลือกวัวที่ต้องการพิมพ์ QR'
                          : 'พร้อมพิมพ์เอกสาร QR Code',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subText(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: (_selectedCowIds.isEmpty || _isExporting)
                    ? null
                    : () => _exportPdfReport(selectedCowsList),
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  _isExporting
                      ? 'กำลังประมวลผล...'
                      : 'พิมพ์ QR (${_selectedCowIds.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
