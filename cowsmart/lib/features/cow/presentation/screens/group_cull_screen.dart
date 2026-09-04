import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/culling_record.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/market/providers/market_price_provider.dart';

enum CullType {
  sold('ขาย', Icons.monetization_on_rounded, AppColors.success),
  removed('คัดออก', Icons.logout_rounded, AppColors.warning),
  deceased('ตาย', Icons.warning_amber_rounded, AppColors.error);

  final String label;
  final IconData icon;
  final Color color;
  const CullType(this.label, this.icon, this.color);
}

class GroupCullScreen extends ConsumerStatefulWidget {
  const GroupCullScreen({super.key});

  @override
  ConsumerState<GroupCullScreen> createState() => _GroupCullScreenState();
}

class _GroupCullScreenState extends ConsumerState<GroupCullScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  final Map<String, TextEditingController> _priceControllers = {};

  CullType _selectedType = CullType.sold;
  DateTime _selectedDate = DateTime.now();
  final Set<String> _selectedCowIds = {};
  String _searchQuery = '';
  CowType? _filterType;

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submitGroupCull() async {
    if (_selectedCowIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกวัวอย่างน้อย 1 ตัวที่ต้องการจำหน่าย/คัดออก',
              style: TextStyle(fontSize: 15)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      int statusValue;
      switch (_selectedType) {
        case CullType.sold:
          statusValue = 0;
          break;
        case CullType.deceased:
          statusValue = 1;
          break;
        case CullType.removed:
          statusValue = 2;
          break;
      }

      final records = _selectedCowIds.map((cowId) {
        final priceText = _priceControllers[cowId]?.text ?? '0.0';
        return CullingRecord(
          id: '',
          cowId: cowId,
          cullDate: _selectedDate,
          status: statusValue,
          price: double.tryParse(priceText) ?? 0.0,
          note: _noteController.text,
        );
      }).toList();

      await ref.read(cowProvider.notifier).cullCowsGroup(records);

      if (mounted) {
        final state = ref.read(cowProvider);
        if (state.errorMessage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'บันทึกการ${_selectedType.label}วัวแบบกลุ่ม (${records.length} ตัว) เรียบร้อยแล้ว',
                style: const TextStyle(fontSize: 15),
              ),
              backgroundColor: AppColors.success,
            ),
          );

          // Refresh zone counts
          final currentFarm = ref.read(farmProvider).currentFarm;
          if (currentFarm != null) {
            ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
          }

          context.go('/dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!,
                  style: const TextStyle(fontSize: 15)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {String? hintText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surfAlt(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cowState = ref.watch(cowProvider);

    // Filter active cows by search query and cow type
    final activeCows = cowState.allCows.where((cow) {
      final matchesQuery = _searchQuery.isEmpty ||
          cow.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cow.tagNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _filterType == null || cow.type == _filterType;
      return matchesQuery && matchesType;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'จำหน่าย/คัดออก (กลุ่ม)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'บันทึกขาย คัดออก หรือจำหน่ายวัวหลายตัว',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
            tooltip: 'ประวัติการจำหน่ายและคัดออก',
            onPressed: () => context.push('/culling_history'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cull Type Selection Header
                    Row(
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
                          'รูปแบบการจำหน่าย/คัดออก',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cull Type Segment Cards
                    Row(
                      children: CullType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              onTap: () => setState(() => _selectedType = type),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? type.color.withValues(alpha: 0.12)
                                      : AppColors.cardBg(context),
                                  border: Border.all(
                                    color: isSelected
                                        ? type.color
                                        : AppColors.brd(context),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: type.color.withValues(alpha: 0.15),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? type.color.withValues(alpha: 0.15)
                                            : AppColors.surfAlt(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        type.icon,
                                        color: isSelected
                                            ? type.color
                                            : AppColors.subText(context),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      type.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? type.color
                                            : AppColors.text(context),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Date Selection
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: _buildInputDecoration(
                          'วันที่ดำเนินการ',
                          Icons.calendar_today_rounded,
                        ),
                        child: Text(
                          AppDateUtils.formatThaiDate(_selectedDate),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Note Field
                    TextFormField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: _buildInputDecoration(
                        'สาเหตุหรือหมายเหตุ',
                        Icons.notes_rounded,
                        hintText:
                            'เช่น ขายส่งโรงฆ่า, คัดออกตามอายุ, ย้ายฟาร์ม ฯลฯ',
                      ),
                      style: TextStyle(
                          fontSize: 15, color: AppColors.text(context)),
                    ),
                    const SizedBox(height: 24),

                    // Cow List Selection Header
                    Row(
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
                          'เลือกวัวที่จะจำหน่าย (${_selectedCowIds.length} ตัว)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Bar (Matching group appointment style)
                    TextField(
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
                    const SizedBox(height: 10),

                    // Cow Type Filter Chips (ChoiceChips matching group appointment style)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('ทั้งหมด', style: TextStyle(fontSize: 14)),
                            selected: _filterType == null,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: _filterType == null ? AppColors.primary : AppColors.brd(context)),
                            labelStyle: TextStyle(
                              color: _filterType == null ? Colors.white : AppColors.text(context),
                              fontWeight: _filterType == null ? FontWeight.bold : FontWeight.w500,
                            ),
                            onSelected: (_) => setState(() => _filterType = null),
                          ),
                          const SizedBox(width: 8),
                          ...CowType.values.map((type) {
                            final isSelected = _filterType == type;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(type.label, style: const TextStyle(fontSize: 14)),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surfAlt(context),
                                side: BorderSide(color: isSelected ? AppColors.primary : AppColors.brd(context)),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.text(context),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                                onSelected: (_) => setState(() => _filterType = isSelected ? null : type),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Found Count & Select All Row (Matching group appointment style)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'พบวัวทั้งหมด ${activeCows.length} ตัว',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.subText(context)),
                        ),
                        if (activeCows.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final isAllSelected = activeCows.isNotEmpty && activeCows.every((c) => _selectedCowIds.contains(c.id));
                              return TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (isAllSelected) {
                                      _selectedCowIds.clear();
                                      _priceControllers.clear();
                                    } else {
                                      _selectedCowIds.addAll(activeCows.map((c) => c.id));
                                      for (var c in activeCows) {
                                        _priceControllers.putIfAbsent(c.id, () => TextEditingController());
                                      }
                                    }
                                  });
                                },
                                icon: Icon(
                                  isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                                  size: 19,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  isAllSelected ? 'ยกเลิกการเลือก' : 'เลือกทั้งหมด',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Cows List
                    if (activeCows.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            CowIcon(
                                size: 40,
                                color: AppColors.primary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'ไม่พบวัวที่ค้นหา'
                                  : 'ไม่มีวัวในระบบให้เลือก',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activeCows.length,
                        itemBuilder: (context, index) {
                          final cow = activeCows[index];
                          final isSelected = _selectedCowIds.contains(cow.id);

                          if (isSelected &&
                              !_priceControllers.containsKey(cow.id)) {
                            _priceControllers[cow.id] = TextEditingController();
                          }

                          final genderDisplay = (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male') ? 'ผู้' : 'เมีย';
                          final breedDisplay = cow.breed.isNotEmpty ? cow.breed : '-';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _selectedType.color.withValues(alpha: 0.05)
                                  : AppColors.cardBg(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? _selectedType.color
                                    : AppColors.brd(context).withValues(alpha: 0.5),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedCowIds.remove(cow.id);
                                    _priceControllers[cow.id]?.dispose();
                                    _priceControllers.remove(cow.id);
                                  } else {
                                    _selectedCowIds.add(cow.id);
                                    _priceControllers[cow.id] =
                                        TextEditingController();
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Cow Image Avatar on the LEFT
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            color: AppColors.surfAlt(context),
                                            child: (cow.imageFullUrl != null &&
                                                    cow.imageFullUrl!.isNotEmpty)
                                                ? Image.network(
                                                    cow.imageFullUrl!,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                        const Center(
                                                      child: CowIcon(
                                                          size: 24,
                                                          color: AppColors.textHint),
                                                    ),
                                                  )
                                                : (cow.imageUrl != null &&
                                                        cow.imageUrl!.isNotEmpty)
                                                    ? Image.network(
                                                        cow.imageUrl!,
                                                        width: 48,
                                                        height: 48,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __,
                                                                ___) =>
                                                            const Center(
                                                          child: CowIcon(
                                                              size: 24,
                                                              color: AppColors
                                                                  .textHint),
                                                        ),
                                                      )
                                                    : const Center(
                                                        child: CowIcon(
                                                            size: 24,
                                                            color: AppColors
                                                                .textHint),
                                                      ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Cow Details in the MIDDLE
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      cow.name.isNotEmpty
                                                          ? cow.name
                                                          : cow.tagNumber,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: AppColors.text(context)),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (cow.tagNumber.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                6),
                                                      ),
                                                      child: Text(
                                                        cow.tagNumber,
                                                        style: const TextStyle(
                                                            fontSize: 12.5,
                                                            color: AppColors
                                                                .primaryDark,
                                                            fontWeight:
                                                                FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'สายพันธุ์: $breedDisplay • เพศ: $genderDisplay${cow.latestWeight > 0 ? ' • ${cow.latestWeight.toStringAsFixed(0)} กก.' : ''}',
                                                style: const TextStyle(
                                                    fontSize: 13.5,
                                                    color: AppColors
                                                        .textSecondary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Checkbox on the RIGHT
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: _selectedType.color,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedCowIds.add(cow.id);
                                                _priceControllers[cow.id] =
                                                    TextEditingController();
                                              } else {
                                                _selectedCowIds.remove(cow.id);
                                                _priceControllers[cow.id]?.dispose();
                                                _priceControllers.remove(cow.id);
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price field if type is sold
                                  if (isSelected &&
                                      _selectedType == CullType.sold)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 0, 12, 12),
                                      child: Builder(
                                        builder: (context) {
                                          final marketState =
                                              ref.watch(marketPriceProvider);
                                          final breeds =
                                              ref.watch(breedProvider);
                                          final breedName = breeds
                                              .firstWhere(
                                                (b) => b.id == cow.breed,
                                                orElse: () => Breed(
                                                    id: cow.breed,
                                                    name: cow.breed),
                                              )
                                              .name;
                                          final weight = cow.latestWeight;
                                          final pricePerKg = marketState
                                              .calculatePricePerKg(
                                                  breedName: breedName,
                                                  weight: weight);
                                          final estVal = weight * pricePerKg;

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Divider(
                                                  height: 1,
                                                  thickness: 1,
                                                  color: AppColors.border),
                                              const SizedBox(height: 10),
                                              if (weight > 0) ...[
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'ราคาประเมิน: ฿${NumberFormat('#,##0').format(estVal)} (${weight.toStringAsFixed(0)}กก. × ${pricePerKg.toStringAsFixed(2)}฿)',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          _priceControllers[cow.id]
                                                                  ?.text =
                                                              estVal
                                                                  .toStringAsFixed(
                                                                      0);
                                                        });
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 8,
                                                            vertical: 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              AppColors.success,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: const Text(
                                                          'ใช้ราคานี้',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                              ],
                                              TextFormField(
                                                controller:
                                                    _priceControllers[cow.id],
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    _buildInputDecoration(
                                                  'ราคาขายของวัวตัวนี้ (บาท)',
                                                  Icons.payments_rounded,
                                                  hintText: '0.00',
                                                ),
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                validator: (value) {
                                                  if (_selectedType ==
                                                          CullType.sold &&
                                                      (value == null ||
                                                          value.isEmpty)) {
                                                    return 'กรุณากรอกราคาขายสำหรับวัวตัวนี้';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

      // Sticky Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Consumer(
            builder: (context, ref, child) {
              final isLoading = ref.watch(cowProvider).isLoading;
              final isButtonEnabled =
                  _selectedCowIds.isNotEmpty && !isLoading;

              return SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isButtonEnabled ? _submitGroupCull : null,
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : Icon(
                          _selectedCowIds.isEmpty
                              ? Icons.touch_app_rounded
                              : Icons.check_circle_rounded,
                          size: 22,
                        ),
                  label: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _selectedCowIds.isEmpty
                              ? 'กรุณาเลือกวัวที่ต้องการจำหน่าย/คัดออก'
                              : 'ยืนยัน${_selectedType.label}วัว ${_selectedCowIds.length} ตัว',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType.color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.surfAlt(context),
                    disabledForegroundColor: AppColors.subText(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
