import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
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
  late TextEditingController _purchasePriceController;
  String? _selectedBreedId;
  String? _selectedZoneId;
  String? _selectedFatherId;
  String? _selectedMotherId;

  late DateTime _selectedDate;
  late DateTime _selectedEntryDate;
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
    _purchasePriceController = TextEditingController(
      text: widget.cow.purchasePrice > 0 ? widget.cow.purchasePrice.toString() : '',
    );
    _selectedBreedId = widget.cow.breed;
    _selectedDate = widget.cow.birthDate;
    _selectedEntryDate = widget.cow.entryDate ?? DateTime.now();
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
    if (!_formKey.currentState!.validate()) {
      AppFeedback.showError(context, 'กรุณาตรวจสอบข้อมูลและกรอกข้อมูลในช่องที่จำเป็นให้ถูกต้อง');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
      final updatedCow = Cow(
        id: widget.cow.id,
        farmId: widget.cow.farmId,
        zoneId: _selectedZoneId ?? '',
        name: _nameController.text,
        tagNumber: _tagController.text,
        birthDate: _selectedDate,
        entryDate: _selectedEntryDate,
        gender: _selectedGender,
        type: _selectedType,
        breed: _selectedBreedId ?? widget.cow.breed,
        latestWeight: widget.cow.latestWeight,
        purchasePrice: purchasePrice,
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
            debugPrint('[ERROR] อัปโหลดรูปภาพไม่สำเร็จ: $e');
          }
        }

        if (mounted) {
          AppFeedback.showSuccess(context, 'อัปเดตและบันทึกข้อมูลการแก้ไขเรียบร้อยแล้ว');
          ref.read(cowProvider.notifier).clearFlags();
          context.pop();
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _buildInputDecoration(
    String labelText,
    dynamic icon, {
    String? hintText,
    String? suffixText,
  }) {
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
      labelStyle: TextStyle(
        fontSize: 14,
        color: AppColors.subText(context),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        color: AppColors.hint(context),
        fontSize: 14,
      ),
      suffixText: suffixText,
      suffixStyle: TextStyle(
        color: AppColors.subText(context),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
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

  Widget _buildResponsiveRow(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 500) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 14),
              Expanded(child: second),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: 14),
              second,
            ],
          );
        }
      },
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

    ref.listen<CowState>(cowProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        AppFeedback.showError(context, next.errorMessage!);
        ref.read(cowProvider.notifier).clearFlags();
      }
    });

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
                              'แก้ไขข้อมูลวัว',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.cow.name.isNotEmpty
                                  ? '${widget.cow.name} (${widget.cow.tagNumber})'
                                  : 'เบอร์วัว: ${widget.cow.tagNumber}',
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
                            currentImageUrl: widget.cow.imageFullUrl ?? widget.cow.imageUrl,
                            uploadType: 'cow',
                            entityId: widget.cow.id,
                            size: 110,
                            placeholderIcon: Icons.pets_rounded,
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
                        Center(
                          child: Text(
                            'แตะเพื่อเปลี่ยนรูปถ่ายวัว',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.subText(context),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Card 2: Basic Info
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('ข้อมูลพื้นฐาน'),
                        const SizedBox(height: 16),

                        _buildResponsiveRow(
                          TextFormField(
                            controller: _tagController,
                            decoration: _buildInputDecoration('เบอร์วัว (Tag)', Icons.tag_rounded, hintText: 'เช่น kp-001'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'กรุณากรอกหมายเลข';
                              }
                              final allCows = ref.read(cowProvider).allCows;
                              final isDup = allCows.any(
                                (c) => c.id != widget.cow.id && c.tagNumber.trim().toLowerCase() == value.trim().toLowerCase(),
                              );
                              if (isDup) {
                                return 'เบอร์วัวนี้มีในระบบแล้ว';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: _nameController,
                            decoration: _buildInputDecoration('ชื่อวัว (ถ้ามี)', Icons.pets_rounded, hintText: 'ถ้ามี'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'กรุณากรอกชื่อ';
                              }
                              final allCows = ref.read(cowProvider).allCows;
                              final isDup = allCows.any(
                                (c) => c.id != widget.cow.id && c.name.trim().toLowerCase() == value.trim().toLowerCase(),
                              );
                              if (isDup) {
                                return 'ชื่อวัวนี้มีในระบบแล้ว';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        Consumer(
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
                                    style: const TextStyle(fontSize: 14),
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
                        const SizedBox(height: 14),

                        _buildResponsiveRow(
                          InkWell(
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
                          InkWell(
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
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _purchasePriceController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration('ราคาที่ซื้อมา (บาท)', Icons.payments_rounded, hintText: '0.00'),
                        ),
                      ],
                    ),

                    // Card 3: Type & Gender
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('ประเภทและเพศ'),
                        const SizedBox(height: 14),
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
                                selected: <String>{_selectedGender},
                                style: SegmentedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: AppColors.surfAlt(context),
                                  selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                  selectedForegroundColor: AppColors.primary,
                                  foregroundColor: AppColors.text(context),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: AppColors.brd(context)),
                                ),
                                onSelectionChanged: (Set<String> newSelection) {
                                  setState(() {
                                    _selectedGender = newSelection.first;
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
                        const SizedBox(height: 14),
                        DropdownButtonFormField<CowType>(
                          value: _selectedType,
                          dropdownColor: AppColors.cardBg(context),
                          isExpanded: true,
                          style: TextStyle(color: AppColors.text(context), fontSize: 14),
                          decoration: _buildInputDecoration('ประเภทวัว', Icons.merge_type_rounded),
                          items: CowType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.label, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (CowType? newValue) {
                            setState(() {
                              if (newValue != null) {
                                _selectedType = newValue;
                                if (newValue == CowType.breederMale) {
                                  _selectedGender = 'M';
                                } else if (newValue == CowType.breederFemale) {
                                  _selectedGender = 'F';
                                }
                              }
                            });
                          },
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
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('ไม่ระบุโซน', overflow: TextOverflow.ellipsis),
                                ),
                                ...zones.map((zone) {
                                  return DropdownMenuItem<String?>(
                                    value: zone.id,
                                    child: Text(zone.name, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (val) => setState(() => _selectedZoneId = val),
                            );
                          },
                        ),
                      ],
                    ),

                    // Card 5: Bloodline Info
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('สายเลือด (พ่อ/แม่)'),
                        const SizedBox(height: 14),
                        _buildResponsiveRow(
                          Builder(
                            builder: (context) {
                              final fathers = cowState.allCows
                                  .where((c) => c.gender == 'M' && c.id != widget.cow.id)
                                  .toList();
                              final validFatherId = (_selectedFatherId != null && fathers.any((c) => c.id == _selectedFatherId))
                                  ? _selectedFatherId
                                  : null;

                              return DropdownButtonFormField<String?>(
                                value: validFatherId,
                                dropdownColor: AppColors.cardBg(context),
                                isExpanded: true,
                                style: TextStyle(color: AppColors.text(context), fontSize: 14),
                                decoration: _buildInputDecoration('พ่อพันธุ์ (Sire)', Icons.male_rounded),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('ไม่ระบุพ่อพันธุ์', overflow: TextOverflow.ellipsis),
                                  ),
                                  ...fathers.map((cow) {
                                    return DropdownMenuItem<String?>(
                                      value: cow.id,
                                      child: Text(
                                        cow.name.isNotEmpty ? ' ()' : cow.tagNumber,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedFatherId = val),
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              final mothers = cowState.allCows
                                  .where((c) => c.gender == 'F' && c.id != widget.cow.id)
                                  .toList();
                              final validMotherId = (_selectedMotherId != null && mothers.any((c) => c.id == _selectedMotherId))
                                  ? _selectedMotherId
                                  : null;

                              return DropdownButtonFormField<String?>(
                                value: validMotherId,
                                dropdownColor: AppColors.cardBg(context),
                                isExpanded: true,
                                style: TextStyle(color: AppColors.text(context), fontSize: 14),
                                decoration: _buildInputDecoration('แม่พันธุ์ (Dam)', Icons.female_rounded),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('ไม่ระบุแม่พันธุ์', overflow: TextOverflow.ellipsis),
                                  ),
                                  ...mothers.map((cow) {
                                    return DropdownMenuItem<String?>(
                                      value: cow.id,
                                      child: Text(
                                        cow.name.isNotEmpty ? ' ()' : cow.tagNumber,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedMotherId = val),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // Card 6: Current Status
                    _buildCardContainer(
                      children: [
                        _buildSectionHeader('สถานะปัจจุบัน'),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<CowStatus>(
                          value: _selectedStatus,
                          dropdownColor: AppColors.cardBg(context),
                          isExpanded: true,
                          style: TextStyle(color: AppColors.text(context), fontSize: 14),
                          decoration: _buildInputDecoration('สถานะสุขภาพ/การเลี้ยง', Icons.health_and_safety_rounded),
                          items: {
                            CowStatus.normal,
                            CowStatus.sick,
                            CowStatus.injured,
                            _selectedStatus,
                          }.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status.label, overflow: TextOverflow.ellipsis),
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
                _isSaving || cowState.isLoading ? 'กำลังบันทึก...' : 'บันทึกการแก้ไข',
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
