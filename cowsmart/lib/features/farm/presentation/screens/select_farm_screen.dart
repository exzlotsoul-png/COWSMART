import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';

class SelectFarmScreen extends ConsumerStatefulWidget {
  const SelectFarmScreen({super.key});

  @override
  ConsumerState<SelectFarmScreen> createState() => _SelectFarmScreenState();
}

class _SelectFarmScreenState extends ConsumerState<SelectFarmScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(farmProvider.notifier).fetchFarms();
    });
  }

  Future<void> _onSelectFarm(dynamic farm) async {
    ref.read(farmProvider.notifier).selectFarm(farm);

    // Initial fetch for the selected farm's data
    await Future.wait([
      ref.read(cowProvider.notifier).fetchCows(farm.id),
      ref.read(zoneProvider.notifier).fetchZones(farm.id),
    ]);

    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('เลือกฟาร์มของคุณ'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'ยินดีต้อนรับกลับมา!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'เลือกฟาร์มที่คุณต้องการจัดการในวันนี้',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            if (farmState.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (farmState.farms.isEmpty)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.agriculture,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text('ยังไม่มีฟาร์มในระบบ'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/create_farm'),
                      child: const Text('สร้างฟาร์มแรกของคุณ'),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: farmState.farms.length,
                  itemBuilder: (context, index) {
                    final farm = farmState.farms[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      elevation: 0,
                      child: InkWell(
                        onTap: () => _onSelectFarm(farm),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withOpacity(
                                    0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.house_siding,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      farm.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      'อีเมลเจ้าของ: ${farm.ownerEmail}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (farmState.farms.isNotEmpty)
              TextButton.icon(
                onPressed: () => context.push('/create_farm'),
                icon: const Icon(Icons.add),
                label: const Text('สร้างฟาร์มเพิ่ม'),
              ),
          ],
        ),
      ),
    );
  }
}
