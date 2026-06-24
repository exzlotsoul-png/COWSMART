import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
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
      print('Error loading existing zones: $e');
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
    if (name.isNotEmpty && currentFarm != null) {
      if (_zones.any((z) => z.name == name)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ชื่อโซนนี้มีอยู่แล้ว')));
        return;
      }
      setState(() {
        _zones.add(Zone(id: 'NEW', name: name, farmId: currentFarm.id));
        _zoneNameController.clear();
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
    final currentFarm = ref.read(farmProvider).currentFarm;
    if (currentFarm == null) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);

      // 1. Perform Deletions
      List<String> failedDeletes = [];
      for (final zone in _zonesToDelete) {
        try {
          print('[DELETE] กำลังลบโซน: ${zone.name}...');
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
          print('[UPDATE] กำลังแก้ไขชื่อโซน $zoneId -> $newName...');
          await api.put('/zones/$zoneId', data: {'name': newName});
        }
      }

      // 3. Perform Additions
      int newCount = 0;
      for (final zone in _zones) {
        if (zone.id == 'NEW') {
          print('[CREATE] กำลังสร้างโซนใหม่: ${zone.name}...');
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อยแล้ว')),
          );
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึก: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการโซนในฟาร์ม')),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'แบ่งพื้นที่ฟาร์มของคุณ',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'คุณสามารถเพิ่มและลบโซนได้จากหน้านี้ ข้อมูลจะถูกบันทึกเมื่อกดปุ่ม "บันทึก" เท่านั้น',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Add Zone Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _zoneNameController,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อโซนใหม่',
                            hintText: 'เช่น โซน ก., คอกอนุบาล...',
                            prefixIcon: Icon(Icons.fence_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addLocalZone,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'รายการโซนที่คุณเลือก',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_zonesToDelete.isNotEmpty)
                        Text(
                          'ลบออก ${_zonesToDelete.length} รายการ',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Zones List
                  Expanded(
                    child: _zones.isEmpty && !_isLoading
                        ? Center(
                            child: Text(
                              'ยังไม่มีโซน',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _zones.length,
                            itemBuilder: (context, index) {
                              final zone = _zones[index];
                              final isNew = zone.id == 'NEW';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: isNew
                                    ? AppColors.primaryLight.withOpacity(0.05)
                                    : AppColors.surface,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isNew
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isNew
                                        ? AppColors.primary
                                        : AppColors.primaryLight.withOpacity(
                                            0.2,
                                          ),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isNew
                                            ? Colors.white
                                            : AppColors.primaryDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    zone.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isNew
                                        ? 'โซนใหม่ (ยังไม่บันทึก)'
                                        : 'วัวในโซน: ${zone.cowCount} ตัว',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _showEditZoneDialog(index),
                                        tooltip: 'แก้ไขชื่อ',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _removeLocalZone(index),
                                        tooltip: 'ลบโซน',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Save Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAllChanges,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('บันทึกการเปลี่ยนแปลงทั้งหมด'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
