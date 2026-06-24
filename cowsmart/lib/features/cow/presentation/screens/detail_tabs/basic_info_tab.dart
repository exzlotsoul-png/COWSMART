import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/cow.dart';
import '../../../domain/breed.dart';
import '../../../providers/breed_provider.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../../farm/providers/zone_provider.dart';
import '../../../../market/providers/market_price_provider.dart';

class BasicInfoTab extends ConsumerWidget {
  final Cow cow;

  const BasicInfoTab({super.key, required this.cow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breeds = ref.watch(breedProvider);
    final breedName = breeds
        .firstWhere(
          (b) => b.id == cow.breed,
          orElse: () => Breed(id: cow.breed, name: cow.breed),
        )
        .name;

    final marketPrice =
        ref.watch(marketPriceProvider).latest?.pricePerKg ?? 120.0;

    final zones = ref.watch(zoneProvider).zones;
    final zoneName = zones.isNotEmpty
        ? zones
              .firstWhere((z) => z.id == cow.zoneId, orElse: () => zones.first)
              .name
        : cow.zoneId;

    // Use latest weight from growth records if available, otherwise fallback to cow.latestWeight
    final growthRecords = ref.watch(cowDetailProvider).growthRecords;
    final latestWeight = growthRecords.isNotEmpty
        ? growthRecords.first.weight
        : cow.latestWeight;
    final estimatedValue = latestWeight * marketPrice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(
            context,
            title: 'ข้อมูลเบื้องต้น',
            children: [
              _buildInfoRow('หมายเลข (เบอร์หู)', cow.tagNumber),
              _buildInfoRow('ชื่อ', cow.name.isNotEmpty ? cow.name : '-'),
              _buildInfoRow('สายพันธุ์', breedName),
              _buildInfoRow('ประเภท', cow.type.label),
              _buildInfoRow('เพศ', cow.gender == 'M' ? 'ผู้' : 'เมีย'),
              _buildInfoRow('อายุ', '${cow.ageInMonths} เดือน'),
              _buildInfoRow(
                'วันเกิด/เข้าฟาร์ม',
                DateFormat('dd MMM yyyy').format(cow.birthDate),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            title: 'สถานะปัจจุบัน',
            children: [
              _buildInfoRow(
                'สถานะสุขภาพ',
                cow.status.label,
                isStatus: true,
                statusDef: cow.status,
              ),
              _buildInfoRow(
                'น้ำหนักล่าสุด',
                latestWeight > 0
                    ? '${latestWeight.toStringAsFixed(1)} กก.'
                    : 'ยังไม่มีข้อมูล',
              ),
              _buildInfoRow(
                'มูลค่าประเมิน (โดยประมาณ)',
                latestWeight > 0
                    ? '฿${NumberFormat('#,##0').format(estimatedValue)}'
                    : '-',
              ),
              _buildInfoRow('โซน/คอกปัจจุบัน', zoneName),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            title: 'สายเลือด/พ่อแม่',
            children: [
              _buildInfoRow('พ่อกำเนิด', cow.fatherId ?? 'ไม่ทราบข้อมูล'),
              _buildInfoRow('แม่กำเนิด', cow.motherId ?? 'ไม่ทราบข้อมูล'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/cull_cow', extra: cow),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text(
                'คัดวัวตัวนี้ทิ้ง',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isStatus = false,
    CowStatus? statusDef,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: isStatus && statusDef != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadge(statusDef),
                  )
                : Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(CowStatus status) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (status) {
      case CowStatus.normal:
        bgColor = AppColors.success;
        break;
      case CowStatus.sick:
        bgColor = AppColors.error;
        break;
      case CowStatus.pregnant:
        bgColor = AppColors.info;
        break;
      case CowStatus.recovering:
        bgColor = AppColors.warning;
        textColor = AppColors.textPrimary;
        break;
      case CowStatus.sold:
        bgColor = AppColors.textHint;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
