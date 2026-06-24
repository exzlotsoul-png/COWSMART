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
        id: 'CUL${DateTime.now().millisecondsSinceEpoch % 1000000}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('บันทึกการคัดทิ้ง')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cow Info Header
              Card(
                color: AppColors.primary.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.pets, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'วัวหมายเลข: ${widget.cow.tagNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'ชื่อ: ${widget.cow.name.isNotEmpty ? widget.cow.name : "-"}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Cull Type Selection
              Text(
                'รูปแบบการคัดทิ้ง',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: CullType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: InkWell(
                        onTap: () => setState(() => _selectedType = type),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? type.color.withOpacity(0.1)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? type.color : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                type.icon,
                                color: isSelected
                                    ? type.color
                                    : AppColors.textHint,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                type.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? type.color
                                      : AppColors.textHint,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
              const SizedBox(height: 24),

              // Date Selection
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'วันที่ดำเนินการ',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              // Conditional Price Field for "Sold"
              if (_selectedType == CullType.sold) ...[
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ราคาที่ขายได้ (บาท)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    hintText: '0.00',
                  ),
                  validator: (value) {
                    if (_selectedType == CullType.sold &&
                        (value == null || value.isEmpty)) {
                      return 'กรุณากรอกราคาขาย';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Note Field
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'สาเหตุหรือหมายเหตุ',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.note_alt_outlined),
                  ),
                  hintText: 'เช่น สุขภาพไม่ดี, อายุมากแล้ว, ฯลฯ',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 40),

              // Submit Button
              Consumer(
                builder: (context, ref, child) {
                  final isLoading = ref.watch(cowProvider).isLoading;
                  return ElevatedButton(
                    onPressed: isLoading ? null : _submitCull,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedType.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'ยืนยันการ${_selectedType.label}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
