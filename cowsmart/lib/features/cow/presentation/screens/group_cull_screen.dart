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
          content: Text('กรุณาเลือกวัวอย่างน้อย 1 ตัวที่ต้องการคัดทิ้ง'),
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
    final cowState = ref.watch(cowProvider);
    
    // Filter active cows by search query
    final activeCows = cowState.allCows.where((cow) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return cow.name.toLowerCase().contains(q) ||
          cow.tagNumber.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('คัดทิ้งกลุ่ม'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'ประวัติการคัดทิ้ง',
            onPressed: () => context.push('/culling_history'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Configuration Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cull Type Selection
                    Text(
                      'รูปแบบการคัดทิ้ง',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                                padding: const EdgeInsets.symmetric(vertical: 14),
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
                                      size: 22,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      type.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? type.color
                                            : AppColors.textHint,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 14,
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
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'วันที่ดำเนินการ',
                          prefixIcon: Icon(Icons.calendar_today, size: 20),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Note Field
                    TextFormField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'สาเหตุหรือหมายเหตุ',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(Icons.note_alt_outlined, size: 20),
                        ),
                        hintText: 'เช่น คัดทิ้งเนื่องจากอายุมาก, ย้ายออก, ฯลฯ',
                        alignLabelWithHint: true,
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 24),

                    // Cow List Selection Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'เลือกวัวที่จะคัดทิ้ง (${_selectedCowIds.length} ตัว)',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                                    _priceControllers.putIfAbsent(c.id, () => TextEditingController());
                                  }
                                }
                              });
                            },
                            child: Text(
                              _selectedCowIds.length == activeCows.length
                                  ? 'ล้างทั้งหมด'
                                  : 'เลือกทั้งหมด',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ค้นหาด้วยชื่อ หรือ เบอร์หู...',
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),

                    // Cows checkbox list
                    if (activeCows.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Text(
                          _searchQuery.isNotEmpty ? 'ไม่พบวัวที่ค้นหา' : 'ไม่มีวัวในระบบให้เลือก',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activeCows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cow = activeCows[index];
                          final isSelected = _selectedCowIds.contains(cow.id);
                          
                          if (isSelected && !_priceControllers.containsKey(cow.id)) {
                            _priceControllers[cow.id] = TextEditingController();
                          }

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? _selectedType.color
                                    : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  value: isSelected,
                                  activeColor: _selectedType.color,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedCowIds.add(cow.id);
                                        _priceControllers[cow.id] = TextEditingController();
                                      } else {
                                        _selectedCowIds.remove(cow.id);
                                        _priceControllers[cow.id]?.dispose();
                                        _priceControllers.remove(cow.id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    '${cow.name} (${cow.tagNumber})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'สายพันธุ์: ${cow.breed} | ล่าสุด: ${cow.latestWeight.toStringAsFixed(0)} กก.',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  secondary: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.pets,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                if (isSelected && _selectedType == CullType.sold)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                    child: TextFormField(
                                      controller: _priceControllers[cow.id],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'ราคาขายของวัวตัวนี้ (บาท)',
                                        prefixIcon: Icon(Icons.payments_outlined, size: 18),
                                        hintText: '0.00',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      style: const TextStyle(fontSize: 14),
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
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Consumer(
              builder: (context, ref, child) {
                final isLoading = ref.watch(cowProvider).isLoading;
                final isButtonEnabled = _selectedCowIds.isNotEmpty && !isLoading;
                
                return ElevatedButton(
                  onPressed: isButtonEnabled ? _submitGroupCull : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType.color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _selectedCowIds.isEmpty
                              ? 'กรุณาเลือกวัวที่ต้องการคัดทิ้ง'
                              : 'ยืนยันคัดทิ้งวัว ${_selectedCowIds.length} ตัว (${_selectedType.label})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
