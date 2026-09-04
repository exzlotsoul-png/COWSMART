import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/features/farm/domain/zone.dart';
import '../../../../core/network/api_client.dart';
import 'package:dio/dio.dart';

class CreateZoneScreen extends ConsumerStatefulWidget {
  const CreateZoneScreen({super.key});

  @override
  ConsumerState<CreateZoneScreen> createState() => _CreateZoneScreenState();
}

class _CreateZoneScreenState extends ConsumerState<CreateZoneScreen> {
  final List<Zone> _zones =
      []; // Current visible zones (including unsaved ones)
  final Set<Zone> _zonesToDelete = {}; // Existing zones marked for deletion
  final Map<String, String> _zonesToEdit = {}; // zoneId -> new name
  final _zoneNameController = TextEditingController();
  String? _zoneNameError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingZones();
    });
  }

  Future<void> _loadExistingZones() async {
    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm == null) return;

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        '/zones',
        query: {'farm_id': currentFarm.id},
      );
      final List<dynamic> data = response.data;

      final loadedZones = data.map((z) => Zone.fromJson(z)).toList();
      setState(() {
        _zones.clear();
        _zones.addAll(loadedZones);
        if (_zones.isEmpty) {
          _zones.add(
            Zone(id: 'NEW', name: 'โซนหลัก (เริ่มต้น)', farmId: currentFarm.id),
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading existing zones: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _zoneNameController.dispose();
    super.dispose();
  }

  void _addLocalZone() {
    final name = _zoneNameController.text.trim();
    final currentFarm = ref.read(farmProvider).currentFarm;
    
    setState(() {
      _zoneNameError = name.isEmpty ? 'กรุณากรอกชื่อโซน' : null;
    });

    if (_zoneNameError != null) return;

    if (currentFarm != null) {
      if (_zones.any((z) => z.name == name)) {
        setState(() {
          _zoneNameError = 'ชื่อโซนนี้มีอยู่แล้ว';
        });
        return;
      }
      setState(() {
        _zones.add(Zone(id: 'NEW', name: name, farmId: currentFarm.id));
        _zoneNameController.clear();
        _zoneNameError = null;
      });
    }
  }

  void _showEditZoneDialog(int index) {
    final zone = _zones[index];
    final controller = TextEditingController(text: zone.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขชื่อโซน'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อโซน',
            prefixIcon: Icon(Icons.fence_outlined),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) return;
                    setState(() {
                      _zones[index] = Zone(
                        id: zone.id,
                        name: newName,
                        farmId: zone.farmId,
                        cowCount: zone.cowCount,
                      );
                      if (zone.id != 'NEW') {
                        _zonesToEdit[zone.id] = newName;
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('บันทึก'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _removeLocalZone(int index) {
    final zone = _zones[index];
    setState(() {
      if (zone.id != 'NEW') {
        _zonesToDelete.add(zone); // Mark for deletion later
      }
      _zones.removeAt(index);
    });
  }

  Future<void> _saveAllChanges() async {
    if (_isLoading) return;
    
    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm == null) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);

      // 1. Perform Deletions
      List<String> failedDeletes = [];
      for (final zone in _zonesToDelete) {
        try {
          debugPrint('[DELETE] กำลังลบโซน: ${zone.name}...');
          await api.delete('/zones/${zone.id}');
        } catch (e) {
          String errMsg = 'ลบไม่สำเร็จ';
          if (e is DioException && e.response?.data != null) {
            errMsg = e.response!.data['message'] ?? errMsg;
          }
          failedDeletes.add('${zone.name}: $errMsg');
        }
      }

      // 2. Perform Updates (rename)
      for (final entry in _zonesToEdit.entries) {
        final zoneId = entry.key;
        final newName = entry.value;
        if (!_zonesToDelete.any((z) => z.id == zoneId)) {
          debugPrint('[UPDATE] กำลังแก้ไขชื่อโซน $zoneId -> $newName...');
          await api.put('/zones/$zoneId', data: {'name': newName});
        }
      }

      // 3. Perform Additions
      int newCount = 0;
      for (final zone in _zones) {
        if (zone.id == 'NEW') {
          debugPrint('[CREATE] กำลังสร้างโซนใหม่: ${zone.name}...');
          await api.post(
            '/zones',
            data: {'farm_id': currentFarm.id, 'name': zone.name},
          );
          newCount++;
        }
      }

      // Refresh state
      await ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);

      if (mounted) {
        if (failedDeletes.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('ผลการบันทึก'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('สร้างสำเร็จ $newCount โซน'),
                  const SizedBox(height: 8),
                  const Text(
                    'การลบที่ล้มเหลว (โซนที่มีวัวอยู่ห้ามลบ):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  ...failedDeletes.map(
                    (f) => Text('• $f', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ℹ️ กรุณาย้ายวัวออกจากโซนดังกล่าวก่อนทำการลบอีกครั้ง',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('ตกลง'),
                ),
              ],
            ),
          );
        } else {
          AppFeedback.showSuccess(context, 'บันทึกข้อมูลเรียบร้อยแล้ว');
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการบันทึก: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'จัดการโซนในฟาร์ม',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'เพิ่ม แก้ไข หรือลบโซนพื้นที่เลี้ยงวัว',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Header Input Card ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.primary],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _zoneNameController,
                    style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ชื่อโซนใหม่ เช่น โซน ก., คอกอนุบาล...',
                      hintStyle: TextStyle(color: AppColors.hint(context), fontSize: 13),
                      prefixIcon: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary, size: 22),
                      filled: true,
                      fillColor: AppColors.cardBg(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      errorText: _zoneNameError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _addLocalZone,
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 4),
                          Text('เพิ่ม', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Status Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'รายการโซนในระบบ (${_zones.length} โซน)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                if (_zonesToDelete.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'เตรียมลบ ${_zonesToDelete.length} รายการ',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Zones List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _zones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grass_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text(
                              'ยังไม่มีโซน',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _zones.length,
                        itemBuilder: (context, index) {
                          final zone = _zones[index];
                          final isNew = zone.id == 'NEW';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isNew ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardBg(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isNew
                                      ? AppColors.primary.withValues(alpha: 0.8)
                                      : AppColors.brd(context).withValues(alpha: 0.6),
                                  width: isNew ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isNew
                                          ? AppColors.primary
                                          : AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.grass_rounded,
                                      color: isNew ? Colors.white : AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          zone.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.text(context),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        isNew
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.auto_awesome,
                                                    size: 14,
                                                    color: AppColors.primary,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'โซนใหม่ (ยังไม่บันทึก)',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                'วัวในโซน: ${zone.cowCount} ตัว',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.subText(context),
                                                ),
                                              ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                                    onPressed: () => _showEditZoneDialog(index),
                                    tooltip: 'แก้ไขชื่อโซน',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
                                    onPressed: () => _removeLocalZone(index),
                                    tooltip: 'ลบโซน',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ── Save Changes Bar ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAllChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'บันทึกการเปลี่ยนแปลงทั้งหมด',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
