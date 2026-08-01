import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/culling_record.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';

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
          id: 'CUL${DateTime.now().millisecondsSinceEpoch % 1000000 + cowId.hashCode % 10000}',
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
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
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
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'จำหน่าย/คัดออก (กลุ่ม)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'บันทึกขาย คัดออก หรือจำหน่ายวัวหลายตัว',
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
                              icon: const Icon(Icons.history_rounded,
                                  color: Colors.white, size: 24),
                              tooltip: 'ประวัติการจำหน่ายและคัดออก',
                              onPressed: () => context.push('/culling_history'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Form Content ──
          SliverToBoxAdapter(
            child: Padding(
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
                        const Text(
                          'รูปแบบการจำหน่าย/คัดออก',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
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
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? type.color
                                        : AppColors.border.withValues(alpha: 0.5),
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
                                            : AppColors.surfaceAlt,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        type.icon,
                                        color: isSelected
                                            ? type.color
                                            : AppColors.textSecondary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      type.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? type.color
                                            : AppColors.textPrimary,
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
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
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
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 24),

                    // Cow List Selection Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        if (activeCows.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedCowIds.length == activeCows.length) {
                                  _selectedCowIds.clear();
                                  _priceControllers.clear();
                                } else {
                                  _selectedCowIds.addAll(
                                    activeCows.map((c) => c.id),
                                  );
                                  for (var c in activeCows) {
                                    _priceControllers.putIfAbsent(
                                        c.id, () => TextEditingController());
                                  }
                                }
                              });
                            },
                            child: Text(
                              _selectedCowIds.length == activeCows.length
                                  ? 'ยกเลิกทั้งหมด'
                                  : 'เลือกทั้งหมด',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Cow Type Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ทั้งหมด', _filterType == null, () {
                            setState(() => _filterType = null);
                          }),
                          const SizedBox(width: 8),
                          ...CowType.values.map((type) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildFilterChip(
                                  type.label, _filterType == type, () {
                                setState(() {
                                  _filterType =
                                      _filterType == type ? null : type;
                                });
                              }),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: _buildInputDecoration(
                        'ค้นหาด้วยชื่อ หรือ แท็ก/NFC',
                        Icons.search_rounded,
                        hintText: 'พิมพ์ชื่อวัว หรือ หมายเลขแท็ก...',
                      ).copyWith(
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      style: const TextStyle(fontSize: 15),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 16),

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
                            Icon(Icons.pets_rounded,
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
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activeCows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final cow = activeCows[index];
                          final isSelected = _selectedCowIds.contains(cow.id);

                          if (isSelected &&
                              !_priceControllers.containsKey(cow.id)) {
                            _priceControllers[cow.id] = TextEditingController();
                          }

                          return InkWell(
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
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? _selectedType.color
                                      : AppColors.border.withValues(alpha: 0.5),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? _selectedType.color
                                            .withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        // Checkbox
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _selectedType.color
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected
                                                  ? _selectedType.color
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

                                        // Cow Avatar
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: cow.imageFullUrl != null &&
                                                  cow.imageFullUrl!.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Image.network(
                                                    cow.imageFullUrl!,
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : const Icon(Icons.pets_rounded,
                                                  color: AppColors.primary,
                                                  size: 24),
                                        ),
                                        const SizedBox(width: 14),

                                        // Cow Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cow.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  _buildCowChip(
                                                      'แท็ก: ${cow.tagNumber}'),
                                                  _buildCowChip(
                                                      '${cow.latestWeight.toStringAsFixed(0)} กก.'),
                                                  _buildCowChip(cow.breed),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price field if type is sold
                                  if (isSelected &&
                                      _selectedType == CullType.sold)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          14, 0, 14, 14),
                                      child: TextFormField(
                                        controller: _priceControllers[cow.id],
                                        keyboardType: TextInputType.number,
                                        decoration: _buildInputDecoration(
                                          'ราคาขายของวัวตัวนี้ (บาท)',
                                          Icons.payments_rounded,
                                          hintText: '0.00',
                                        ),
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                        validator: (value) {
                                          if (_selectedType == CullType.sold &&
                                              (value == null || value.isEmpty)) {
                                            return 'กรุณากรอกราคาขายสำหรับวัวตัวนี้';
                                          }
                                          return null;
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
          ),
        ],
      ),

      // Sticky Bottom Action Bar
      bottomNavigationBar: Container(
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
                        AppColors.border.withValues(alpha: 0.5),
                    disabledForegroundColor: AppColors.textHint,
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildCowChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
