import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/constants/app_constants.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/culling_record.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'บันทึกการ${_selectedType.label}วัวหมายเลข ${widget.cow.tagNumber} เรียบร้อยแล้ว',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          // Refresh zone counts for the dashboard
          final currentFarm = ref.read(farmProvider).currentFarm;
          if (currentFarm != null) {
            ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
          }

          context.go('/dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cowState = ref.watch(cowProvider);
    final isLoading = cowState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.pets_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'วัวหมายเลข: ${widget.cow.tagNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ชื่อ: ${widget.cow.name.isNotEmpty ? widget.cow.name : "-"}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
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
                  children: [
                    _buildSectionHeader('รูปแบบการจำหน่าย/คัดออก'),
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
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected ? type.color : AppColors.border,
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
                                          : AppColors.textHint,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      type.label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isSelected
                                            ? type.color
                                            : AppColors.textSecondary,
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
                  children: [
                    _buildSectionHeader('ข้อมูลการดำเนินการ'),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: _buildInputDecoration('วันที่ดำเนินการ', Icons.calendar_today_rounded),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Conditional Price Field for "Sold"
                    if (_selectedType == CullType.sold) ...[
                      Builder(
                        builder: (context) {
                          final marketPrice = ref.watch(marketPriceProvider).latest?.pricePerKg ?? 120.0;
                          final weight = widget.cow.latestWeight;
                          final estimatedVal = weight * marketPrice;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (weight > 0) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calculate_outlined, color: AppColors.success, size: 24),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ราคาประเมินเบื้องต้น: ฿${NumberFormat('#,##0').format(estimatedVal)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppColors.success,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'คำนวณจากน้ำหนัก ${weight.toStringAsFixed(0)} กก. × ${marketPrice.toStringAsFixed(0)} ฿/กก.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800],
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
                                          backgroundColor: AppColors.success,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('ใช้ราคานี้', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 15),
                                decoration: _buildInputDecoration('ราคาที่ขายได้ (บาท)', Icons.payments_rounded, hintText: '0.00'),
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
                      style: const TextStyle(fontSize: 15),
                      decoration: _buildInputDecoration('สาเหตุหรือหมายเหตุ', Icons.note_alt_rounded, hintText: 'เช่น สุขภาพไม่ดี, อายุมากแล้ว, ฯลฯ'),
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
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
