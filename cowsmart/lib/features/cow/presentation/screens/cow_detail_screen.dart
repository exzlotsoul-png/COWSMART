import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/cow.dart';
import '../../providers/cow_detail_provider.dart';
import '../../providers/cow_provider.dart';
import 'detail_tabs/basic_info_tab.dart';
import 'detail_tabs/breed_tab.dart';
import 'detail_tabs/placeholder_tabs.dart';

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
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 22),
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
                                child: Icon(Icons.pets, size: 90, color: AppColors.textHint),
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
                      // Dark gradient at bottom
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 90,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: const TabBar(
                  isScrollable: true,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(text: 'ข้อมูลทั่วไป'),
                    Tab(text: 'สุขภาพ'),
                    Tab(text: 'น้ำหนัก'),
                    Tab(text: 'ผสมพันธุ์'),
                    Tab(text: 'ค่าใช้จ่าย'),
                  ],
                ),
              ),
            ];
          },
          body: Container(
            color: AppColors.background,
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
