import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/constants/app_constants.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';

class EditCowScreen extends ConsumerStatefulWidget {
  final Cow cow;

  const EditCowScreen({super.key, required this.cow});

  @override
  ConsumerState<EditCowScreen> createState() => _EditCowScreenState();
}

class _EditCowScreenState extends ConsumerState<EditCowScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _tagController;
  String? _selectedBreedId;
  String? _selectedZoneId;
  String? _selectedFatherId;
  String? _selectedMotherId;

  late DateTime _selectedDate;
  late String _selectedGender;
  late CowType _selectedType;
  late CowStatus _selectedStatus;

  XFile? _pendingImageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cow.name);
    _tagController = TextEditingController(text: widget.cow.tagNumber);
    _selectedBreedId = widget.cow.breed;
    _selectedDate = widget.cow.birthDate;
    _selectedGender = widget.cow.gender;
    _selectedType = widget.cow.type;
    _selectedStatus = widget.cow.status;
    _selectedZoneId = widget.cow.zoneId.isEmpty ? null : widget.cow.zoneId;
    _selectedFatherId = widget.cow.fatherId;
    _selectedMotherId = widget.cow.motherId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
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

    setState(() => _isSaving = true);

    try {
      final updatedCow = Cow(
        id: widget.cow.id,
        farmId: widget.cow.farmId,
        zoneId: _selectedZoneId ?? '',
        name: _nameController.text,
        tagNumber: _tagController.text,
        birthDate: _selectedDate,
        gender: _selectedGender,
        type: _selectedType,
        breed: _selectedBreedId ?? widget.cow.breed,
        latestWeight: widget.cow.latestWeight,
        status: _selectedStatus,
        fatherId: _selectedFatherId,
        motherId: _selectedMotherId,
        imageUrl: widget.cow.imageUrl,
        imageFullUrl: widget.cow.imageFullUrl,
      );

      await ref.read(cowProvider.notifier).updateCow(updatedCow);

      final cowState = ref.read(cowProvider);
      if (cowState.errorMessage == null) {
        // Upload image
        if (_pendingImageFile != null) {
          try {
            final uploadService = ref.read(imageUploadServiceProvider);
            final response = await uploadService.uploadImage(
              type: 'cow',
              entityId: widget.cow.id,
              imageFile: _pendingImageFile!,
            );
            
            if (response.containsKey('cow')) {
               final syncedCow = Cow.fromJson(response['cow']);
               ref.read(cowProvider.notifier).syncCow(syncedCow);
            }
          } catch (e) {
            print('[ERROR] อัปโหลดรูปภาพไม่สำเร็จ: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกการแก้ไขเรียบร้อยแล้ว!'),
              backgroundColor: AppColors.success,
            ),
          );
          ref.read(cowProvider.notifier).clearFlags();
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
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลวัว'),
        actions: [
          _isSaving || cowState.isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveCow,
                  child: const Text(
                    'บันทึก',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ImagePickerWidget(
                    currentImageUrl: widget.cow.imageFullUrl ?? widget.cow.imageUrl,
                    uploadType: 'cow',
                    entityId: widget.cow.id,
                    size: 120,
                    placeholderIcon: Icons.pets,
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

                Row(
                  children: [
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final breeds = ref.watch(breedProvider);
                          final uniqueBreeds = {
                            for (var b in breeds) b.id: b,
                          }.values.toList();
                          final bool isValueInList = uniqueBreeds.any(
                            (b) => b.id == _selectedBreedId,
                          );
                          final String? safeValue = isValueInList
                              ? _selectedBreedId
                              : null;

                          return DropdownButtonFormField<String>(
                            initialValue: safeValue,
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
                  ],
                ),
                const SizedBox(height: 24),

                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'วันเกิด / วันที่เข้าฟาร์ม',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 24),

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
                      value: _selectedZoneId,
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
                      child: DropdownButtonFormField<String>(
                        value: _selectedFatherId,
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
                              .where((c) => c.gender == 'M' && c.id != widget.cow.id)
                              .map((cow) {
                            return DropdownMenuItem(
                              value: cow.id,
                              child: Text(cow.name.isNotEmpty ? '${cow.name} (${cow.tagNumber})' : cow.tagNumber),
                            );
                          }),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedFatherId = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMotherId,
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
                              .where((c) => c.gender == 'F' && c.id != widget.cow.id)
                              .map((cow) {
                            return DropdownMenuItem(
                              value: cow.id,
                              child: Text(cow.name.isNotEmpty ? '${cow.name} (${cow.tagNumber})' : cow.tagNumber),
                            );
                          }),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedMotherId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

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
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isSaving || cowState.isLoading ? null : _saveCow,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving || cowState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'บันทึกการแก้ไข',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
