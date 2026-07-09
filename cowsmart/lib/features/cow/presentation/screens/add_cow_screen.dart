import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/constants/app_constants.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:cowsmart/features/cow/domain/growth_record.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';
import 'package:cowsmart/core/network/api_client.dart';

class AddCowScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  const AddCowScreen({super.key, this.initialData});

  @override
  ConsumerState<AddCowScreen> createState() => _AddCowScreenState();
}

class _AddCowScreenState extends ConsumerState<AddCowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedBreedId;
  String? _selectedZoneId;
  String? _selectedFatherId;
  String? _selectedMotherId;

  XFile? _pendingImageFile;
  bool _isSaving = false;

  DateTime _selectedDate = DateTime.now();
  String _selectedGender = 'F';
  CowType _selectedType = CowType.breederFemale;
  CowStatus _selectedStatus = CowStatus.normal;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      if (data['mother_id'] != null) {
        _selectedMotherId = data['mother_id'];
      }
      if (data['father_id'] != null) {
        _selectedFatherId = data['father_id'];
      }
      if (data['breed_id'] != null) {
        _selectedBreedId = data['breed_id'];
      }
      if (data['birth_date'] != null) {
        _selectedDate = data['birth_date'] as DateTime;
      }
      if (data['type'] != null) {
        _selectedType = data['type'] as CowType;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _weightController.dispose();
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveCow() async {
    if (!_formKey.currentState!.validate()) return;

    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกฟาร์มก่อนบันทึก')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final initialWeight = double.tryParse(_weightController.text) ?? 0.0;
      final cowId = 'C${DateTime.now().millisecondsSinceEpoch % 1000000}';

      final newCow = Cow(
        id: cowId,
        farmId: currentFarm.id,
        zoneId: _selectedZoneId ?? '',
        name: _nameController.text,
        tagNumber: _tagController.text,
        birthDate: _selectedDate,
        gender: _selectedGender,
        type: _selectedType,
        breed: _selectedBreedId ?? '',
        latestWeight: initialWeight,
        status: _selectedStatus,
        fatherId: _selectedFatherId,
        motherId: _selectedMotherId,
      );

      await ref.read(cowProvider.notifier).addCow(newCow);

      final cowState = ref.read(cowProvider);
      if (cowState.errorMessage == null) {
        // Get actual cow id from newly added cow
        final createdCow = cowState.allCows.isNotEmpty
            ? cowState.allCows.last
            : null;

        if (createdCow != null) {
          // Upload image
          if (_pendingImageFile != null) {
            try {
              final uploadService = ref.read(imageUploadServiceProvider);
              final response = await uploadService.uploadImage(
                type: 'cow',
                entityId: createdCow.id,
                imageFile: _pendingImageFile!,
              );
              
              if (response.containsKey('cow')) {
                 final updatedCow = Cow.fromJson(response['cow']);
                 ref.read(cowProvider.notifier).syncCow(updatedCow);
              }
            } catch (e) {
              print('[ERROR] อัปโหลดรูปภาพไม่สำเร็จ: $e');
              // We don't block the success flow if image fails, just log it or show a minor warning
            }
          }

          // Save initial weight
          if (initialWeight > 0 && mounted) {
            final growthRecord = GrowthRecord(
              id: 'GR${DateTime.now().millisecondsSinceEpoch % 1000000}',
              cowId: createdCow.id,
              recordDate: _selectedDate,
              weight: initialWeight,
            );
            try {
              final api = ref.read(apiClientProvider);
              await api.post('/growth_records', data: growthRecord.toJson());
            } catch (e) {
              print('[ERROR] บันทึกน้ำหนักเริ่มต้นไม่สำเร็จ: $e');
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกข้อมูลสำเร็จ!'),
              backgroundColor: AppColors.success,
            ),
          );
          ref.read(cowProvider.notifier).clearFlags();
          ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
          context.pop();
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cowState = ref.watch(cowProvider);

    // Listen for error
    ref.listen<CowState>(cowProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(cowProvider.notifier).clearFlags();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มข้อมูลวัว'), actions: const []),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Picker
                Center(
                  child: ImagePickerWidget(
                    currentImageUrl: null,
                    uploadType: 'cow',
                    entityId: '', // Entity ID will be generated upon save
                    size: 120,
                    placeholderIcon: Icons.add_a_photo,
                    showConfirmButtons: false,
                    onImagePicked: (file) {
                      _pendingImageFile = file;
                    },
                    onImageCancelled: () {
                      _pendingImageFile = null;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Basic Info
                Text(
                  'ข้อมูลพื้นฐาน',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          labelText: 'หมายเลข (เบอร์หู)',
                          prefixIcon: Icon(Icons.tag),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'กรุณากรอกหมายเลข'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อ (ถ้ามี)',
                          prefixIcon: Icon(Icons.pets),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'กรุณากรอกชื่อ'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Breed and Weight
                Row(
                  children: [
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final breeds = ref.watch(breedProvider);

                          // Deduplicate breeds by ID to prevent crash if API returns duplicates
                          final uniqueBreeds = {
                            for (var b in breeds) b.id: b,
                          }.values.toList();

                          // Safety check: ensure _selectedBreedId exists in the items list to avoid crash
                          final bool isValueInList = uniqueBreeds.any(
                            (b) => b.id == _selectedBreedId,
                          );
                          final String? safeValue = isValueInList
                              ? _selectedBreedId
                              : null;

                          return DropdownButtonFormField<String>(
                            value: safeValue,
                            decoration: const InputDecoration(
                              labelText: 'สายพันธุ์',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: uniqueBreeds.map((breed) {
                              return DropdownMenuItem(
                                value: breed.id,
                                child: Text(breed.name),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedBreedId = val),
                            validator: (val) =>
                                val == null ? 'กรุณาเลือกสายพันธุ์' : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'น้ำหนัก (กก.)',
                          prefixIcon: Icon(Icons.scale),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Date of Birth
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'วันเกิด',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 24),

                // Gender & Type
                Text(
                  'ประเภทและเพศ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'M', label: Text('ตัวผู้')),
                          ButtonSegment(value: 'F', label: Text('ตัวเมีย')),
                        ],
                        selected: <String>{_selectedGender},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedGender = newSelection.first;
                            // Auto adjust type based on gender if needed, simplified here
                            if (_selectedGender == 'M' &&
                                _selectedType == CowType.breederFemale) {
                              _selectedType = CowType.breederMale;
                            } else if (_selectedGender == 'F' &&
                                _selectedType == CowType.breederMale) {
                              _selectedType = CowType.breederFemale;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CowType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'ประเภทวัว',
                    prefixIcon: Icon(Icons.merge_type),
                  ),
                  items: CowType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (CowType? newValue) {
                    setState(() {
                      if (newValue != null) _selectedType = newValue;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Zone Selection
                Text(
                  'ที่อยู่ (โซน)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final zoneState = ref.watch(zoneProvider);
                    final zones = zoneState.zones;

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedZoneId,
                      decoration: const InputDecoration(
                        labelText: 'เลือกโซน',
                        hintText: 'กรุณาเลือกโซน (ถ้ามี)',
                        prefixIcon: Icon(Icons.fence_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('ไม่ระบุโซน'),
                        ),
                        ...zones.map((zone) {
                          return DropdownMenuItem(
                            value: zone.id,
                            child: Text(zone.name),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _selectedZoneId = val),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Bloodline Info
                Text(
                  'สายเลือด (พ่อ/แม่)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final bool isFatherInList = cowState.allCows
                              .any((c) => c.gender == 'M' && c.id == _selectedFatherId);
                          final String? safeFatherValue = isFatherInList ? _selectedFatherId : null;

                          return DropdownButtonFormField<String>(
                            value: safeFatherValue,
                            decoration: const InputDecoration(
                              labelText: 'เลือกพ่อพันธุ์ (Sire)',
                              prefixIcon: Icon(Icons.male),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('ไม่ระบุพ่อพันธุ์'),
                              ),
                              ...cowState.allCows
                                  .where((c) => c.gender == 'M')
                                  .map((cow) {
                                return DropdownMenuItem(
                                  value: cow.id,
                                  child: Text(cow.name.isNotEmpty ? '${cow.name} (${cow.tagNumber})' : cow.tagNumber),
                                );
                              }),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedFatherId = val),
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final bool isMotherInList = cowState.allCows
                              .any((c) => c.gender == 'F' && c.id == _selectedMotherId);
                          final String? safeMotherValue = isMotherInList ? _selectedMotherId : null;

                          return DropdownButtonFormField<String>(
                            value: safeMotherValue,
                            decoration: const InputDecoration(
                              labelText: 'เลือกแม่พันธุ์ (Dam)',
                              prefixIcon: Icon(Icons.female),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('ไม่ระบุแม่พันธุ์'),
                              ),
                              ...cowState.allCows
                                  .where((c) => c.gender == 'F')
                                  .map((cow) {
                                return DropdownMenuItem(
                                  value: cow.id,
                                  child: Text(cow.name.isNotEmpty ? '${cow.name} (${cow.tagNumber})' : cow.tagNumber),
                                );
                              }),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedMotherId = val),
                          );
                        }
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Status
                Text(
                  'สถานะปัจจุบัน',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CowStatus>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'สถานะ',
                    prefixIcon: Icon(Icons.health_and_safety),
                  ),
                  items: CowStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    );
                  }).toList(),
                  onChanged: (CowStatus? newValue) {
                    setState(() {
                      if (newValue != null) _selectedStatus = newValue;
                    });
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isSaving || cowState.isLoading
          ? const SizedBox.shrink()
          : FloatingActionButton.extended(
              onPressed: _saveCow,
              icon: const Icon(Icons.save),
              label: const Text('บันทึก'),
              backgroundColor: AppColors.primary,
            ),
    );
  }
}
