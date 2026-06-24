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
                expandedHeight: 250,
                pinned: true,
                title: Text(currentCow.tagNumber),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      context.push('/edit_cow', extra: currentCow);
                    },
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
                              color: AppColors.primary.withOpacity(0.1),
                              child: const Center(
                                child: Icon(Icons.pets, size: 80, color: AppColors.textHint),
                              ),
                            ),
                      // Add a dark gradient at the top so the AppBar text is readable
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 100,
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
                      // Add a dark gradient at the bottom so the TabBar text is readable
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
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
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
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
