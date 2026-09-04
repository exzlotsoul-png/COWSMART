import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cow_icon.dart';
import '../../domain/cow.dart';
import '../../providers/cow_detail_provider.dart';
import '../../providers/cow_provider.dart';
import 'detail_tabs/basic_info_tab.dart';
import 'detail_tabs/breed_tab.dart';
import 'detail_tabs/placeholder_tabs.dart';
import '../widgets/cow_qr_dialog.dart';
import '../widgets/nfc_writer_dialog.dart';

class CowDetailScreen extends ConsumerStatefulWidget {
  final Cow cow;

  const CowDetailScreen({super.key, required this.cow});

  @override
  ConsumerState<CowDetailScreen> createState() => _CowDetailScreenState();
}

class _CowDetailScreenState extends ConsumerState<CowDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(cowDetailProvider.notifier).resetState();
      ref.read(cowDetailProvider.notifier).fetchAllData(widget.cow.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch cow from provider so it updates immediately when edited
    final cowState = ref.watch(cowProvider);
    final currentCow = cowState.allCows.firstWhere(
      (c) => c.id == widget.cow.id,
      orElse: () => widget.cow,
    );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                title: Text(
                  '${currentCow.name} (${currentCow.tagNumber})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, size: 22, color: Colors.white),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => CowQrDialog(cow: currentCow),
                        );
                      },
                      tooltip: 'QR Code วัว',
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.nfc_rounded, size: 22, color: Colors.white),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => NfcWriterDialog(cow: currentCow),
                        );
                      },
                      tooltip: 'ฝังข้อมูลลงเหรียญ NFC',
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 22, color: Colors.white),
                      onPressed: () {
                        context.push('/edit_cow', extra: currentCow);
                      },
                      tooltip: 'แก้ไขข้อมูล',
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      (currentCow.imageFullUrl != null || currentCow.imageUrl != null)
                          ? Image.network(
                              currentCow.imageFullUrl ?? currentCow.imageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.15),
                                    AppColors.primaryLight.withValues(alpha: 0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: CowIcon(size: 90, color: AppColors.textHint),
                              ),
                            ),
                      // Dark gradient at top
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 110,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Dark gradient at bottom for max contrast
                      // Soft gradient at bottom of header image
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: TabBar(
                      isScrollable: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.subText(context),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.subText(context),
                      ),
                      tabs: const [
                        Tab(
                            child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('ข้อมูลทั่วไป'))),
                        Tab(
                            child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('สุขภาพ'))),
                        Tab(
                            child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('น้ำหนัก'))),
                        Tab(
                            child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('ผสมพันธุ์'))),
                        Tab(
                            child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('ค่าใช้จ่าย'))),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: Container(
            color: AppColors.bg(context),
            child: TabBarView(
              children: [
                BasicInfoTab(cow: currentCow),
                HealthTab(cow: currentCow),
                GrowthTab(cow: currentCow),
                BreedTab(cow: currentCow),
                CostTab(cow: currentCow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
