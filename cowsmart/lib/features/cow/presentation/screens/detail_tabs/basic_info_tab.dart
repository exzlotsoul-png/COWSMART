import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../domain/cow.dart';
import '../../../domain/breed.dart';
import '../../../providers/breed_provider.dart';
import '../../../providers/cow_provider.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../../farm/providers/zone_provider.dart';
import '../../../../market/providers/market_price_provider.dart';

class BasicInfoTab extends ConsumerWidget {
  final Cow cow;

  const BasicInfoTab({super.key, required this.cow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCows = ref.watch(cowProvider).allCows;
    final breeds = ref.watch(breedProvider);

    String formatCowNameWithBreed(String? id) {
      if (id == null || id.isEmpty) return 'ไม่ทราบข้อมูล';
      final matches = allCows.where((c) => c.id == id || c.tagNumber == id || c.name == id).toList();
      if (matches.isNotEmpty) {
        final c = matches.first;
        final cBreedName = breeds.firstWhere(
          (b) => b.id == c.breed,
          orElse: () => Breed(id: c.breed, name: c.breed.isNotEmpty ? c.breed : '-'),
        ).name;
        
        final String displayName;
        if (c.name.isNotEmpty && c.tagNumber.isNotEmpty && c.name != c.tagNumber) {
          displayName = '${c.name} (${c.tagNumber})';
        } else if (c.name.isNotEmpty) {
          displayName = c.name;
        } else if (c.tagNumber.isNotEmpty) {
          displayName = c.tagNumber;
        } else {
          displayName = id;
        }

        return cBreedName.isNotEmpty && cBreedName != '-'
            ? '$displayName • พันธุ์: $cBreedName'
            : displayName;
      }
      return id;
    }

    final breedName = breeds
        .firstWhere(
          (b) => b.id == cow.breed,
          orElse: () => Breed(id: cow.breed, name: cow.breed),
        )
        .name;

    final marketState = ref.watch(marketPriceProvider);

    final zones = ref.watch(zoneProvider).zones;
    final String zoneName;
    if (cow.zoneId.isEmpty) {
      zoneName = 'ไม่ระบุ';
    } else if (zones.isNotEmpty) {
      final matchingZone = zones.where((z) => z.id == cow.zoneId).toList();
      zoneName = matchingZone.isNotEmpty ? matchingZone.first.name : cow.zoneId;
    } else {
      zoneName = cow.zoneId;
    }

    // Use latest weight from growth records if available, otherwise fallback to cow.latestWeight
    final growthRecords = ref.watch(cowDetailProvider).growthRecords;
    final latestWeight = growthRecords.isNotEmpty
        ? growthRecords.first.weight
        : cow.latestWeight;
    final pricePerKg = marketState.calculatePricePerKg(breedName: breedName, weight: latestWeight);
    final estimatedValue = latestWeight * pricePerKg;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Highlight Stats Cards
          _buildQuickStats(context, cow, latestWeight, estimatedValue),
          const SizedBox(height: 18),

          // Card 1: ข้อมูลประจำตัวและประวัติเบื้องต้น
          _buildSectionCard(
            context,
            icon: Icons.badge_outlined,
            iconColor: AppColors.primary,
            title: 'ข้อมูลเบื้องต้น',
            children: [
              _buildModernInfoTile(
                context,
                icon: Icons.tag_rounded,
                label: 'หมายเลขประจำตัว',
                value: cow.tagNumber,
                isHighlightValue: true,
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.label_outline_rounded,
                label: 'ชื่อวัว',
                value: cow.name.isNotEmpty ? cow.name : '-',
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.category_outlined,
                label: 'สายพันธุ์',
                value: breedName,
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.pets_outlined,
                label: 'ประเภท',
                value: cow.type.label,
              ),
              _buildModernInfoTile(
                context,
                icon: cow.gender == 'M' ? Icons.male_rounded : Icons.female_rounded,
                label: 'เพศ',
                value: cow.gender == 'M' ? 'ผู้ (Male)' : 'เมีย (Female)',
                valueColor: cow.gender == 'M' ? Colors.blue[700] : Colors.pink[600],
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.cake_outlined,
                label: 'อายุ',
                value: cow.ageDetailed,
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.calendar_today_outlined,
                label: 'วันเกิด',
                value: AppDateUtils.formatThaiDate(cow.birthDate, useFullMonth: true),
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.login_rounded,
                label: 'วันที่เข้าฟาร์ม',
                value: cow.entryDate != null
                    ? AppDateUtils.formatThaiDate(cow.entryDate!, useFullMonth: true)
                    : 'ไม่ได้ระบุ',
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card 2: สถานะและความเป็นอยู่ปัจจุบัน
          _buildSectionCard(
            context,
            icon: Icons.monitor_heart_outlined,
            iconColor: const Color(0xFF10B981),
            title: 'สถานะและความเป็นอยู่',
            children: [
              _buildModernInfoTile(
                context,
                icon: Icons.health_and_safety_outlined,
                label: 'สถานะสุขภาพ',
                customValueWidget: _buildStatusBadge(cow.status),
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.scale_outlined,
                label: 'น้ำหนักล่าสุด',
                value: latestWeight > 0
                    ? '${latestWeight.toStringAsFixed(1)} กก.'
                    : 'ยังไม่มีข้อมูล',
                isHighlightValue: latestWeight > 0,
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.monetization_on_outlined,
                label: 'มูลค่าประเมินในตลาด',
                value: latestWeight > 0
                    ? '฿${NumberFormat('#,##0').format(estimatedValue)}'
                    : '-',
                valueColor: const Color(0xFF10B981),
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.roofing_outlined,
                label: 'โซน / คอกปัจจุบัน',
                value: zoneName,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card 3: ข้อมูลสายเลือด / พันธุกรรม
          _buildSectionCard(
            context,
            icon: Icons.account_tree_outlined,
            iconColor: const Color(0xFF6366F1),
            title: 'สายเลือด / พ่อแม่พันธุ์',
            children: [
              _buildModernInfoTile(
                context,
                icon: Icons.male_rounded,
                label: 'พ่อกำเนิด (Sire)',
                value: formatCowNameWithBreed(cow.fatherId),
                valueColor: Colors.blue[700],
              ),
              _buildModernInfoTile(
                context,
                icon: Icons.female_rounded,
                label: 'แม่กำเนิด (Dam)',
                value: formatCowNameWithBreed(cow.motherId),
                valueColor: Colors.pink[600],
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Button: Cull Cow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/cull_cow', extra: cow),
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 22),
              label: const Text(
                'จำหน่าย / คัดออกวัวตัวนี้',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.2),
                backgroundColor: Colors.red.withValues(alpha: 0.03),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, Cow cow, double weight, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.isDark(context)
              ? [const Color(0xFF2C3E28), const Color(0xFF1E2C1B)]
              : [const Color(0xFF4D6544), const Color(0xFF384C31)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.3 : 0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickStatItem(
              icon: Icons.scale_rounded,
              label: 'น้ำหนักล่าสุด',
              value: weight > 0 ? '${weight.toStringAsFixed(0)} กก.' : '-',
            ),
          ),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: 0.2)),
          Expanded(
            child: _buildQuickStatItem(
              icon: Icons.payments_rounded,
              label: 'มูลค่าประเมิน',
              value: weight > 0 ? '฿${NumberFormat('#,##0').format(value)}' : '-',
            ),
          ),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: 0.2)),
          Expanded(
            child: _buildQuickStatItem(
              icon: Icons.cake_rounded,
              label: 'อายุ',
              value: cow.ageDetailed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16.5,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.5,
                      color: AppColors.text(context),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.brd(context).withValues(alpha: 0.5)),
            // Body rows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? value,
    Widget? customValueWidget,
    Color? valueColor,
    bool isHighlightValue = false,
    bool isLast = false,
  }) {
    final effectiveValueColor = valueColor ??
        (isHighlightValue
            ? (AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary)
            : AppColors.text(context));

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 4 : 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfAlt(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: AppColors.subText(context)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: AppColors.subText(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: customValueWidget ??
                    Text(
                      value ?? '-',
                      style: TextStyle(
                        color: effectiveValueColor,
                        fontSize: 15,
                        fontWeight: isHighlightValue ? FontWeight.bold : FontWeight.w600,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
            ),
          ],
        ),
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
      case CowStatus.injured:
        bgColor = const Color(0xFFD97706);
        textColor = Colors.white;
        break;
      case CowStatus.estrous:
        bgColor = const Color(0xFFEC4899);
        textColor = Colors.white;
        break;
      case CowStatus.pregnant:
        bgColor = const Color(0xFF9333EA); // Purple
        textColor = Colors.white;
        break;
      case CowStatus.recovering:
        bgColor = const Color(0xFF2563EB); // Royal Blue
        textColor = Colors.white;
        break;
      case CowStatus.sold:
        bgColor = AppColors.textHint;
        break;
      case CowStatus.deceased:
        bgColor = AppColors.error;
        break;
      case CowStatus.removed:
        bgColor = AppColors.warning;
        textColor = AppColors.textPrimary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
