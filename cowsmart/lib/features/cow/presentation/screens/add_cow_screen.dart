import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:cowsmart/features/cow/domain/growth_record.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
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
  final _purchasePriceController = TextEditingController();
  String? _selectedBreedId;
  String? _selectedZoneId;
  String? _selectedFatherId;
  String? _selectedMotherId;

  XFile? _pendingImageFile;
  bool _isSaving = false;

  DateTime _selectedDate = DateTime.now();
  DateTime _selectedEntryDate = DateTime.now();
  String? _selectedGender;
  CowType? _selectedType;
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
      if (data['entry_date'] != null) {
        _selectedEntryDate = data['entry_date'] as DateTime;
      }
      if (data['type'] != null) {
        _selectedType = data['type'] as CowType;
      }
      if (data['gender'] != null) {
        _selectedGender = data['gender'] as String;
      }
    }
    Future.microtask(() {
      final allCows = ref.read(cowProvider).allCows;
      _checkAndAutoSetBreed(allCows);
    });
  }

  void _checkAndAutoSetBreed(List<Cow> allCows) {
    if (_selectedFatherId != null && _selectedMotherId != null) {
      final fatherMatches = allCows.where((c) => c.id == _selectedFatherId).toList();
      final motherMatches = allCows.where((c) => c.id == _selectedMotherId).toList();
      if (fatherMatches.isNotEmpty && motherMatches.isNotEmpty) {
        final fatherBreed = fatherMatches.first.breed;
        final motherBreed = motherMatches.first.breed;
        // If father breed and mother breed are different, auto-select B013 (Crossbred)
        if (fatherBreed.isNotEmpty && motherBreed.isNotEmpty && fatherBreed != motherBreed) {
          final breeds = ref.read(breedProvider);
          final crossbred = breeds.firstWhere(
            (b) => b.id == 'B013' || b.name.contains('ลูกผสม'),
            orElse: () => breeds.isNotEmpty ? breeds.first : Breed(id: 'B013', name: 'ลูกผสม (Crossbred)'),
          );
          _selectedBreedId = crossbred.id;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _weightController.dispose();
    _purchasePriceController.dispose();
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

  Future<void> _selectEntryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEntryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedEntryDate) {
      setState(() {
        _selectedEntryDate = picked;
      });
    }
  }

  Future<void> _saveCow() async {
    // If the form is not valid (fields are missing), the inline errors will show automatically.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm == null) {
      AppFeedback.showError(context, 'กรุณาเลือกฟาร์มก่อนทำการบันทึกข้อมูล');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final initialWeight = double.tryParse(_weightController.text) ?? 0.0;
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;

      final newCow = Cow(
        id: '',
        farmId: currentFarm.id,
        zoneId: _selectedZoneId ?? '',
        name: _nameController.text,
        tagNumber: _tagController.text,
        birthDate: _selectedDate,
        entryDate: _selectedEntryDate,
        gender: _selectedGender!,
        type: _selectedType!,
        breed: _selectedBreedId ?? '',
        latestWeight: initialWeight,
        purchasePrice: purchasePrice,
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
              debugPrint('[ERROR] อัปโหลดรูปภาพไม่สำเร็จ: $e');
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
              debugPrint('[ERROR] บันทึกน้ำหนักเริ่มต้นไม่สำเร็จ: $e');
            }
          }

          // Link calf_id back to breeding record if registered from breeding tab.
          // Appends new calf ID to existing ones (supports twins/triplets).
          if (widget.initialData?['breeding_record_id'] != null) {
            try {
              final api = ref.read(apiClientProvider);
              final breedingRecordId = widget.initialData!['breeding_record_id'];
              final existingCalfId = widget.initialData?['existing_calf_id'] as String?;
              final String newCalfId = (existingCalfId != null && existingCalfId.trim().isNotEmpty)
                  ? '$existingCalfId,${createdCow.id}'
                  : createdCow.id;
              await api.put('/breeding_records/$breedingRecordId', data: {
                'calf_id': newCalfId,
              });
              debugPrint('[SUCCESS] ผูกลูกวัว ID ${createdCow.id} กับประวัติผสมพันธุ์ $breedingRecordId (calf_id: $newCalfId) สำเร็จ');
            } catch (e) {
              debugPrint('[ERROR] อัปเดต calf_id ใน breeding_record ไม่สำเร็จ: $e');
            }
          }
        }

        if (mounted) {
          AppFeedback.showSuccess(context, 'เพิ่มและบันทึกข้อมูลวัวเข้าสู่ระบบเรียบร้อยแล้ว');
          ref.read(cowProvider.notifier).clearFlags();
          ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
          context.pop(true);
        }
      } else if (mounted) {
        AppFeedback.showError(context, cowState.errorMessage!);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _buildInputDecoration(String labelText, dynamic icon, {String? hintText}) {
    Widget prefixWidget;
    if (icon is Widget) {
      prefixWidget = icon;
    } else if (icon == Icons.pets || icon == Icons.pets_rounded || icon == Icons.pets_outlined) {
      prefixWidget = const CowIcon(size: 20, color: AppColors.primary);
    } else if (icon is IconData) {
      prefixWidget = Icon(icon, color: AppColors.primary, size: 20);
    } else {
      prefixWidget = const SizedBox.shrink();
    }

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(color: AppColors.hint(context)),
      prefixIcon: prefixWidget,
      filled: true,
      fillColor: AppColors.surfAlt(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.brd(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.brd(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brd(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cowState = ref.watch(cowProvider);

    // NOTE: Error handling for addCow is done inline in _submit() after awaiting
    // addCow(). We do NOT listen to cowProvider errors globally here because
    // other operations (e.g., cullCowsGroup) can set errorMessage on the same
    // provider while this screen is open, causing unrelated errors to appear.

    return Scaffold(
      backgroundColor: AppColors.bg(context),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เพิ่มข้อมูลวัว',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ลงทะเบียนวัวตัวใหม่เข้าสู่ฟาร์มของคุณ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Form Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Image Picker
                    _buildCardContainer(
                      children: [
                        Center(
                          child: ImagePickerWidget(
                            currentImageUrl: null,
                            uploadType: 'cow',
                            entityId: '',
                            size: 110,
                            placeholderIcon: Icons.add_a_photo_rounded,
                            showConfirmButtons: false,
                            onImagePicked: (file) {
                              _pendingImageFile = file;
                            },
                            onImageCancelled: () {
                              _pendingImageFile = null;
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'แตะเพื่อเพิ่มรูปถ่ายวัว',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Card 2: Basic Info
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('ข้อมูลพื้นฐาน'),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tagController,
                                decoration: _buildInputDecoration('เบอร์วัว (Tag)', Icons.tag_rounded),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'กรุณากรอกหมายเลข';
                                  }
                                  final allCows = ref.read(cowProvider).allCows;
                                  final isDup = allCows.any(
                                    (c) => c.tagNumber.trim().toLowerCase() == value.trim().toLowerCase(),
                                  );
                                  if (isDup) {
                                    return 'เบอร์วัวนี้มีในระบบแล้ว';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                decoration: _buildInputDecoration('ชื่อ (ถ้ามี)', Icons.pets_rounded),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'กรุณากรอกชื่อ';
                                  }
                                  final allCows = ref.read(cowProvider).allCows;
                                  final isDup = allCows.any(
                                    (c) => c.name.trim().toLowerCase() == value.trim().toLowerCase(),
                                  );
                                  if (isDup) {
                                    return 'ชื่อวัวนี้มีในระบบแล้ว';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

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

                                  return DropdownButtonFormField<String?>(
                                    value: safeValue,
                                    dropdownColor: AppColors.cardBg(context),
                                    isExpanded: true,
                                    style: TextStyle(color: AppColors.text(context), fontSize: 14),
                                    decoration: _buildInputDecoration('สายพันธุ์', Icons.category_rounded),
                                    items: uniqueBreeds.map((breed) {
                                      return DropdownMenuItem<String?>(
                                        value: breed.id,
                                        child: Text(
                                          breed.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration('น้ำหนัก (กก.)', Icons.scale_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context),
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: _buildInputDecoration('วันเกิด', Icons.cake_rounded),
                                  child: Text(
                                    AppDateUtils.formatThaiDate(_selectedDate),
                                    style: TextStyle(fontSize: 14, color: AppColors.text(context), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectEntryDate(context),
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: _buildInputDecoration('วันเข้าฟาร์ม', Icons.login_rounded),
                                  child: Text(
                                    AppDateUtils.formatThaiDate(_selectedEntryDate),
                                    style: TextStyle(fontSize: 14, color: AppColors.text(context), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _purchasePriceController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration('ราคาซื้อมา (บาท)', Icons.payments_rounded, hintText: '0.00'),
                        ),
                      ],
                    ),

                    // Card 3: Type & Gender
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('ประเภทและเพศ'),
                        const SizedBox(height: 14),
                        FormField<String>(
                          key: ValueKey(_selectedGender),
                          validator: (_) => _selectedGender == null ? 'กรุณาเลือกเพศ' : null,
                          builder: (FormFieldState<String> state) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SegmentedButton<String>(
                                        segments: const [
                                          ButtonSegment(
                                            value: 'M',
                                            label: Text('ตัวผู้', style: TextStyle(fontWeight: FontWeight.bold)),
                                            icon: Icon(Icons.male_rounded, size: 18),
                                          ),
                                          ButtonSegment(
                                            value: 'F',
                                            label: Text('ตัวเมีย', style: TextStyle(fontWeight: FontWeight.bold)),
                                            icon: Icon(Icons.female_rounded, size: 18),
                                          ),
                                        ],
                                        emptySelectionAllowed: true,
                                        selected: _selectedGender != null ? <String>{_selectedGender!} : <String>{},
                                        style: SegmentedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: AppColors.surfAlt(context),
                                          selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                          selectedForegroundColor: AppColors.primary,
                                          foregroundColor: AppColors.text(context),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          side: BorderSide(
                                            color: state.hasError ? Theme.of(context).colorScheme.error : AppColors.brd(context),
                                          ),
                                        ),
                                        onSelectionChanged: (Set<String> newSelection) {
                                          setState(() {
                                            _selectedGender = newSelection.isEmpty ? null : newSelection.first;
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
                                if (state.hasError) ...[
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text(
                                      state.errorText ?? '',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<CowType>(
                          key: ValueKey(_selectedType),
                          initialValue: _selectedType,
                          dropdownColor: AppColors.cardBg(context),
                          isExpanded: true,
                          style: TextStyle(color: AppColors.text(context), fontSize: 14),
                          decoration: _buildInputDecoration('ประเภทวัว', Icons.merge_type_rounded, hintText: 'กรุณาเลือกประเภทวัว'),
                          items: CowType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(
                                type.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.text(context)),
                              ),
                            );
                          }).toList(),
                          onChanged: (CowType? newValue) {
                            setState(() {
                              _selectedType = newValue;
                              if (newValue == CowType.breederMale) {
                                _selectedGender = 'M';
                              } else if (newValue == CowType.breederFemale) {
                                _selectedGender = 'F';
                              }
                            });
                          },
                          validator: (val) => val == null ? 'กรุณาเลือกประเภทวัว' : null,
                        ),
                      ],
                    ),

                    // Card 4: Zone
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('ที่อยู่ (โซน)'),
                        const SizedBox(height: 14),
                        Consumer(
                          builder: (context, ref, child) {
                            final zoneState = ref.watch(zoneProvider);
                            final zones = zoneState.zones;
                            final validZoneId = (_selectedZoneId != null && zones.any((z) => z.id == _selectedZoneId))
                                ? _selectedZoneId
                                : null;

                            return DropdownButtonFormField<String?>(
                              value: validZoneId,
                              dropdownColor: AppColors.cardBg(context),
                              isExpanded: true,
                              style: TextStyle(color: AppColors.text(context), fontSize: 14),
                              decoration: _buildInputDecoration('เลือกโซน', Icons.fence_rounded, hintText: 'กรุณาเลือกโซน (ถ้ามี)'),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('ไม่ระบุโซน', overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.text(context))),
                                ),
                                ...zones.map((zone) {
                                  return DropdownMenuItem<String?>(
                                    value: zone.id,
                                    child: Text(zone.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.text(context))),
                                  );
                                }),
                              ],
                              onChanged: (val) => setState(() => _selectedZoneId = val),
                            );
                          },
                        ),
                      ],
                    ),

                    // Card 5: Bloodline (Sire/Dam)
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('สายเลือด (พ่อ/แม่)'),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final bool isFatherInList = cowState.allCows
                                      .any((c) => c.gender == 'M' && c.id == _selectedFatherId);
                                  final String? safeFatherValue = isFatherInList ? _selectedFatherId : null;

                                  return DropdownButtonFormField<String?>(
                                    value: safeFatherValue,
                                    dropdownColor: AppColors.cardBg(context),
                                    isExpanded: true,
                                    style: TextStyle(color: AppColors.text(context), fontSize: 14),
                                    decoration: _buildInputDecoration('พ่อพันธุ์ (Sire)', Icons.male_rounded),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('ไม่ระบุพ่อพันธุ์', overflow: TextOverflow.ellipsis),
                                      ),
                                      ...cowState.allCows
                                          .where((c) => c.gender == 'M')
                                          .map((cow) {
                                        return DropdownMenuItem<String?>(
                                          value: cow.id,
                                          child: Text(
                                            cow.name.isNotEmpty ? '${cow.name} (${cow.tagNumber})' : cow.tagNumber,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedFatherId = val;
                                        _checkAndAutoSetBreed(cowState.allCows);
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final bool isMotherInList = cowState.allCows
                                      .any((c) => c.gender == 'F' && c.id == _selectedMotherId);
                                  final String? safeMotherValue = isMotherInList ? _selectedMotherId : null;

                                  return DropdownButtonFormField<String?>(
                                    value: safeMotherValue,
                                    dropdownColor: AppColors.cardBg(context),
                                    isExpanded: true,
                                    style: TextStyle(color: AppColors.text(context), fontSize: 14),
                                    decoration: _buildInputDecoration('แม่พันธุ์ (Dam)', Icons.female_rounded),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('ไม่ระบุแม่พันธุ์', overflow: TextOverflow.ellipsis),
                                      ),
                                      ...cowState.allCows
                                          .where((c) => c.gender == 'F')
                                          .map((cow) {
                                        return DropdownMenuItem<String?>(
                                          value: cow.id,
                                          child: Text(
                                            cow.name.isNotEmpty ? '${cow.name} (${cow.tagNumber})' : cow.tagNumber,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedMotherId = val;
                                        _checkAndAutoSetBreed(cowState.allCows);
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Card 6: Current Status
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('สถานะปัจจุบัน'),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<CowStatus>(
                          initialValue: _selectedStatus,
                          dropdownColor: AppColors.cardBg(context),
                          isExpanded: true,
                          style: TextStyle(color: AppColors.text(context), fontSize: 14),
                          decoration: _buildInputDecoration('สถานะสุขภาพ/การเลี้ยง', Icons.health_and_safety_rounded),
                          items: [
                            CowStatus.normal,
                            CowStatus.sick,
                            CowStatus.injured,
                          ].map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status.label, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.text(context))),
                            );
                          }).toList(),
                          onChanged: (CowStatus? newValue) {
                            setState(() {
                              if (newValue != null) _selectedStatus = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Fixed Bottom Save Button ──
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
              onPressed: (_isSaving || cowState.isLoading) ? null : _saveCow,
              icon: _isSaving || cowState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(
                _isSaving || cowState.isLoading ? 'กำลังบันทึก...' : 'บันทึกข้อมูลวัว',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
