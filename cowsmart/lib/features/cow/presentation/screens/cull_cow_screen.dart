import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
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
  sold('ขาย', Icons.monetization_on_outlined, Colors.green),
  removed('คัดออก', Icons.logout_outlined, Colors.orange),
  deceased('ตาย', Icons.warning_amber_rounded, Colors.red);

  final String label;
  final IconData icon;
  final Color color;
  const CullType(this.label, this.icon, this.color);
}

class CullCowScreen extends ConsumerStatefulWidget {
  final Cow cow;

  const CullCowScreen({super.key, required this.cow});

  @override
  ConsumerState<CullCowScreen> createState() => _CullCowScreenState();
}

class _CullCowScreenState extends ConsumerState<CullCowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _priceController = TextEditingController();

  CullType _selectedType = CullType.sold;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _noteController.dispose();
    _priceController.dispose();
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

  void _submitCull() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

    final record = CullingRecord(
      id: '',
      cowId: widget.cow.id,
      cullDate: _selectedDate,
      status: statusValue,
      price: double.tryParse(_priceController.text) ?? 0.0,
      note: _noteController.text,
    );

    await ref.read(cowProvider.notifier).cullCow(record);

    if (mounted) {
      final state = ref.read(cowProvider);
      if (state.errorMessage == null) {
        AppFeedback.showSuccess(
          context,
          'บันทึกการ${_selectedType.label}วัวหมายเลข ${widget.cow.tagNumber} เรียบร้อยแล้ว',
        );
        // Refresh zone counts for the dashboard
        final currentFarm = ref.read(farmProvider).currentFarm;
        if (currentFarm != null) {
          ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
        }

        context.go('/dashboard');
      } else {
        AppFeedback.showError(context, state.errorMessage!);
      }
    }
  }

  InputDecoration _buildInputDecoration(BuildContext context, String label, IconData icon, {String? hintText}) {
    final isDark = AppColors.isDark(context);
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: TextStyle(fontSize: 15, color: AppColors.subText(context)),
      hintStyle: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.6) : AppColors.hint(context)),
      prefixIcon: Icon(icon, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 22),
      filled: true,
      fillColor: AppColors.surfAlt(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.brd(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.brd(context)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Widget _buildCardContainer(BuildContext context, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.text(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cowState = ref.watch(cowProvider);
    final isLoading = cowState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('บันทึกการจำหน่ายและคัดออก', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card 1: Cow Info Header
                _buildCardContainer(
                  context,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const CowIcon(color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'วัวหมายเลข: ${widget.cow.tagNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: AppColors.text(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ชื่อ: ${widget.cow.name.isNotEmpty ? widget.cow.name : "-"}',
                                style: TextStyle(
                                  color: AppColors.subText(context),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Card 2: Cull Type Selection
                _buildCardContainer(
                  context,
                  children: [
                    _buildSectionHeader(context, 'รูปแบบการจำหน่าย/คัดออก'),
                    const SizedBox(height: 14),
                    Row(
                      children: CullType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              onTap: () => setState(() => _selectedType = type),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? type.color.withValues(alpha: 0.12)
                                      : AppColors.surfAlt(context),
                                  border: Border.all(
                                    color: isSelected ? type.color : AppColors.brd(context),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      type.icon,
                                      size: 26,
                                      color: isSelected
                                          ? type.color
                                          : AppColors.subText(context),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      type.label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isSelected
                                            ? type.color
                                            : AppColors.subText(context),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
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
                  ],
                ),

                // Card 3: Date & Details
                _buildCardContainer(
                  context,
                  children: [
                    _buildSectionHeader(context, 'ข้อมูลการดำเนินการ'),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: _buildInputDecoration(context, 'วันที่ดำเนินการ', Icons.calendar_today_rounded),
                        child: Text(
                          AppDateUtils.formatThaiDate(_selectedDate),
                          style: TextStyle(fontSize: 15, color: AppColors.text(context), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Conditional Price Field for "Sold"
                    if (_selectedType == CullType.sold) ...[
                      Builder(
                        builder: (context) {
                          final marketState = ref.watch(marketPriceProvider);
                          final breeds = ref.watch(breedProvider);
                          final breedName = breeds
                              .firstWhere(
                                (b) => b.id == widget.cow.breed,
                                orElse: () => Breed(id: widget.cow.breed, name: widget.cow.breed),
                              )
                              .name;
                          final weight = widget.cow.latestWeight;
                          final pricePerKg = marketState.calculatePricePerKg(breedName: breedName, weight: weight);
                          final estimatedVal = weight * pricePerKg;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (weight > 0) ...[
                                Builder(
                                  builder: (ctx) {
                                    final isDark = AppColors.isDark(ctx);
                                    final estimateColor = isDark ? const Color(0xFF8FD475) : AppColors.success;
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: estimateColor.withValues(alpha: isDark ? 0.16 : 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: estimateColor.withValues(alpha: isDark ? 0.4 : 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calculate_outlined, color: estimateColor, size: 24),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'ราคาประเมินเบื้องต้น: ฿${NumberFormat('#,##0').format(estimatedVal)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: estimateColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'คำนวณจากน้ำหนัก ${weight.toStringAsFixed(0)} กก. × ${pricePerKg.toStringAsFixed(2)} ฿/กก.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.subText(ctx),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _priceController.text = estimatedVal.toStringAsFixed(0);
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: estimateColor,
                                              foregroundColor: isDark ? const Color(0xFF141712) : Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            child: Text(
                                              'ใช้ราคานี้',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? const Color(0xFF141712) : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                                decoration: _buildInputDecoration(context, 'ราคาที่ขายได้ (บาท)', Icons.payments_rounded, hintText: '0.00'),
                                validator: (value) {
                                  if (_selectedType == CullType.sold &&
                                      (value == null || value.isEmpty)) {
                                    return 'กรุณากรอกราคาขาย';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                          );
                        },
                      ),
                    ],

                    // Note Field
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                      decoration: _buildInputDecoration(context, 'สาเหตุหรือหมายเหตุ', Icons.note_alt_rounded, hintText: 'เช่น สุขภาพไม่ดี, อายุมากแล้ว, ฯลฯ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      // ── Fixed Bottom Button ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _submitCull,
              icon: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Icon(_selectedType.icon, size: 22),
              label: Text(
                isLoading ? 'กำลังบันทึก...' : 'ยืนยันการ${_selectedType.label}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedType.color,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: _selectedType.color.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
