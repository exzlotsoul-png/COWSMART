import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cowsmart/core/theme/app_colors.dart';
import '../../providers/market_price_provider.dart';
import '../../domain/market_price.dart';
import 'market_price_history_screen.dart';

class MarketPriceScreen extends ConsumerStatefulWidget {
  const MarketPriceScreen({super.key});

  @override
  ConsumerState<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends ConsumerState<MarketPriceScreen> {
  String _selectedCategory = 'โคพันธุ์ลูกผสม ขนาดกลาง';
  String _selectedYear = '2569'; // Default to latest year (2569)
  String _selectedMonth = '08'; // Default to latest month (08 - สิงหาคม)
  int? _selectedPointIndex;

  final List<Map<String, String>> _thaiMonths = const [
    {'value': '01', 'name': 'มกราคม'},
    {'value': '02', 'name': 'กุมภาพันธ์'},
    {'value': '03', 'name': 'มีนาคม'},
    {'value': '04', 'name': 'เมษายน'},
    {'value': '05', 'name': 'พฤษภาคม'},
    {'value': '06', 'name': 'มิถุนายน'},
    {'value': '07', 'name': 'กรกฎาคม'},
    {'value': '08', 'name': 'สิงหาคม'},
    {'value': '09', 'name': 'กันยายน'},
    {'value': '10', 'name': 'ตุลาคม'},
    {'value': '11', 'name': 'พฤศจิกายน'},
    {'value': '12', 'name': 'ธันวาคม'},
    {'value': 'all', 'name': 'ทุกเดือน'},
  ];

  final List<Map<String, String>> _availableYears = const [
    {'value': '2569', 'name': '2569'},
    {'value': '2568', 'name': '2568'},
    {'value': '2567', 'name': '2567'},
    {'value': 'all', 'name': 'ทุกปี'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrices();
    });
  }

  void _loadPrices() {
    ref.read(marketPriceProvider.notifier).fetchLatest(
          year: _selectedYear,
          month: _selectedMonth,
        );
    _loadChartHistory();
  }

  void _loadChartHistory() {
    ref.read(marketPriceProvider.notifier).fetchHistory(
          year: _selectedYear,
          month: _selectedMonth,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketPriceProvider);
    final formatter = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ราคาตลาดกลางวัว', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'เครื่องคิดเลขคำนวณมูลค่าราคาโค',
            icon: const Icon(Icons.calculate_outlined, size: 24),
            onPressed: () => _showPriceCalculatorBottomSheet(context, state),
          ),
          IconButton(
            tooltip: 'ดูประวัติทั้งหมด',
            icon: const Icon(Icons.history_rounded, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const MarketPriceHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'ซิงก์ราคา NABC อัตโนมัติ',
            icon: state.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 24),
            onPressed: state.isSyncing
                ? null
                : () async {
                    await ref.read(marketPriceProvider.notifier).syncLivePrice(
                          yearTh: _selectedYear,
                          month: _selectedMonth,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ซิงก์ราคาตลาดกลางจาก NABC สำเร็จแล้ว')),
                      );
                    }
                  },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: () async => _loadPrices(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 📊 UNIFIED PRICE TABLE (ตัวเลขราคาสีดำคมชัด + ฟอนต์ขนาดใหญ่)
                    _buildUnifiedPriceTable(state, formatter),
                    const SizedBox(height: 16),

                    // 🧮 QUICK CALCULATOR ACTION BUTTON
                    _buildQuickCalculatorButton(context, state),
                    const SizedBox(height: 20),

                    // 📈 PRICE TREND CHART SECTION พร้อมตัวเลขขนาดใหญ่ และเปิดมาที่เดือนล่าสุด
                    _buildPriceTrendSection(state),
                    const SizedBox(height: 35),
                  ],
                ),
              ),
            ),
    );
  }

  /// 🧮 ปุ่มเรียกเครื่องคิดเลขคำนวณมูลค่าราคาโค
  Widget _buildQuickCalculatorButton(BuildContext context, MarketPriceState state) {
    return InkWell(
      onTap: () => _showPriceCalculatorBottomSheet(context, state),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.calculate_outlined, color: AppColors.accent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'เครื่องคิดเลขคำนวณมูลค่าวัวตามน้ำหนักตัว',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              'คำนวณ ➔',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📊 ตารางสรุปราคาตลาดกลางและราคาหน้าฟาร์ม (Unified Price Table)
  Widget _buildUnifiedPriceTable(MarketPriceState state, NumberFormat formatter) {
    // NABC National Cattle Price
    final nabcItem = _getNabcPriceItem(state);
    final nabcPrice = nabcItem != null ? nabcItem.pricePerKg.toStringAsFixed(2) : '95.43';

    // DLD Prices
    final euroHigh = _getPriceForCategory(state, 'ลูกผสมยุโรป (>400') ?? '73.09';
    final euroMid = _getPriceForCategory(state, 'ลูกผสมยุโรป (>250') ?? '68.03';

    final brahmanHigh = _getPriceForCategory(state, 'ลูกผสมบราห์มัน (>400') ?? '69.69';
    final brahmanMid = _getPriceForCategory(state, 'ลูกผสมบราห์มัน (>250') ?? '64.59';

    final nativeMid = _getPriceForCategory(state, 'พื้นเมืองไทย (>250') ?? '60.53';
    final nativeLow = _getPriceForCategory(state, 'พื้นเมืองไทย (≤250') ?? _getPriceForCategory(state, 'พื้นเมืองไทย (<=250') ?? '56.36';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. NABC National Index Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ราคากลางโคเนื้อ (สศก. / NABC)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'โคพันธุ์ลูกผสม ขนาดกลาง (เฉลี่ยทั่วประเทศ)',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '฿ $nabcPrice',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary, // ดำเข้มคมชัด
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Text(
                      'บาท / กก.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. DLD Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ราคาโคมีชีวิตหน้าฟาร์ม (กรมปศุสัตว์)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const MarketPriceHistoryScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'ประวัติทั้งหมด ➔',
                    style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 3. Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            color: const Color(0xFFF1F5F9),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'สายพันธุ์ / พิกัดน้ำหนัก',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'ราคา (บาท/กก.)',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),

          // 4. Table Rows (ราคาสีดำคมชัด ฟอนต์ใหญ่)
          _buildTableRow('ลูกผสมยุโรป', '>400 - 600 กก.', euroHigh, isAlt: false),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildTableRow('ลูกผสมยุโรป', '>250 - 400 กก.', euroMid, isAlt: false),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          _buildTableRow('ลูกผสมบราห์มัน', '>400 - 600 กก.', brahmanHigh, isAlt: true),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildTableRow('ลูกผสมบราห์มัน', '>250 - 400 กก.', brahmanMid, isAlt: true),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          _buildTableRow('พื้นเมืองไทย', '>250 - 400 กก.', nativeMid, isAlt: false),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildTableRow('พื้นเมืองไทย', '≤ 250 กก.', nativeLow, isAlt: false, isLast: true),
        ],
      ),
    );
  }

  Widget _buildTableRow(String breed, String weight, String price, {bool isAlt = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isAlt ? const Color(0xFFFAFBFD) : Colors.white,
        borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(18)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Text(
                  breed,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    weight,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '฿ $price',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary, // ดำเข้มคมชัด
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📈 กราฟแนวโน้มราคา พร้อมแถบเลือกช่วงเวลาในกราฟ + รายละเอียดตัวเลขครบถ้วน
  Widget _buildPriceTrendSection(MarketPriceState state) {
    final historyMap = state.history;
    final catList = historyMap.keys.toList();
    if (catList.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!catList.contains(_selectedCategory) && catList.isNotEmpty) {
      _selectedCategory = catList.first;
    }

    final currentHistory = historyMap[_selectedCategory] ?? [];

    // Calculate Summary Stats
    double minPrice = 0;
    double maxPrice = 0;
    double avgPrice = 0;
    if (currentHistory.isNotEmpty) {
      final prices = currentHistory.map((e) => e.pricePerKg).toList();
      minPrice = prices.reduce((a, b) => a < b ? a : b);
      maxPrice = prices.reduce((a, b) => a > b ? a : b);
      avgPrice = prices.reduce((a, b) => a + b) / prices.length;
    }

    // Default or clamp selected point index
    final selectedIdx = _selectedPointIndex != null && _selectedPointIndex! < currentHistory.length
        ? _selectedPointIndex!
        : (currentHistory.isNotEmpty ? currentHistory.length - 1 : 0);

    final selectedItem = currentHistory.isNotEmpty ? currentHistory[selectedIdx] : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header + Category selector dropdown
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'แนวโน้มราคาย้อนหลัง',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(maxWidth: 145),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isDense: true,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 20),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    items: catList.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                          _selectedPointIndex = null;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: 📅 แถบเลือกช่วงเวลาในกราฟ (Time Selector Bar for Chart)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'ช่วงเวลา:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                // Year Filter
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      isDense: true,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      items: _availableYears.map((y) {
                        return DropdownMenuItem<String>(
                          value: y['value'],
                          child: Text('ปี ${y['name']}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedYear = val;
                            _selectedPointIndex = null;
                          });
                          _loadChartHistory();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Month Filter
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMonth,
                      isDense: true,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      items: _thaiMonths.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['value'],
                          child: Text(m['name']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedMonth = val;
                            _selectedPointIndex = null;
                          });
                          _loadChartHistory();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Row 3: 📊 Summary Stats Pills (Min / Avg / Max)
          if (currentHistory.isNotEmpty) ...[
            Row(
              children: [
                _buildStatPill('ต่ำสุด', '฿${minPrice.toStringAsFixed(2)}', const Color(0xFFDC2626)),
                const SizedBox(width: 8),
                _buildStatPill('เฉลี่ย', '฿${avgPrice.toStringAsFixed(2)}', const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                _buildStatPill('สูงสุด', '฿${maxPrice.toStringAsFixed(2)}', const Color(0xFF059669)),
              ],
            ),
            const SizedBox(height: 14),

            // Row 4: 📌 Interactive Tooltip Box showing selected date & price
            if (selectedItem != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.touch_app_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                _formatChartDate(selectedItem.effectiveDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (selectedItem.note != null && selectedItem.note!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              selectedItem.note!,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '฿ ${selectedItem.pricePerKg.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // Chart Canvas with Touch Interaction
            GestureDetector(
              onTapDown: (details) {
                _handleChartTap(details.localPosition, currentHistory);
              },
              onHorizontalDragUpdate: (details) {
                _handleChartTap(details.localPosition, currentHistory);
              },
              child: SizedBox(
                height: 175,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: PriceTrendPainter(
                    currentHistory,
                    selectedIndex: selectedIdx,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.query_stats_rounded, size: 38, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 8),
                    Text(
                      'ไม่มีข้อมูลกราฟในช่วงเวลาที่เลือก',
                      style: TextStyle(fontSize: 13, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleChartTap(Offset localPosition, List<MarketPrice> currentHistory) {
    if (currentHistory.isEmpty) return;
    const paddingLeft = 40.0;
    const paddingRight = 16.0;
    final chartWidth = context.size != null ? context.size!.width - 64 : 300.0;
    final usableWidth = chartWidth - paddingLeft - paddingRight;

    final touchX = localPosition.dx - paddingLeft;
    if (touchX < 0) {
      setState(() => _selectedPointIndex = 0);
      return;
    }
    if (touchX > usableWidth) {
      setState(() => _selectedPointIndex = currentHistory.length - 1);
      return;
    }

    final step = usableWidth / (currentHistory.length > 1 ? currentHistory.length - 1 : 1);
    final index = (touchX / step).round().clamp(0, currentHistory.length - 1);

    setState(() => _selectedPointIndex = index);
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _formatChartDate(DateTime date) {
    final thaiYear = date.year > 2400 ? date.year : date.year + 543;
    final months = [
      '',
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    return '${date.day} ${months[date.month]} $thaiYear';
  }

  /// 🧮 BottomSheet เครื่องคิดเลขคำนวณมูลค่าราคาโคตามน้ำหนักตัว (พร้อมจำกัดช่วงน้ำหนักตามพิกัดที่เลือก)
  void _showPriceCalculatorBottomSheet(BuildContext context, MarketPriceState state) {
    final nabcPrice = _getNabcPriceItem(state)?.pricePerKg ?? 95.43;

    final categories = [
      {
        'name': 'โคเนื้อ (สศก. กลางประเทศ)',
        'price': nabcPrice,
        'minWeight': 100.0,
        'maxWeight': 700.0,
        'defaultWeight': 350.0,
        'rangeLabel': 'ทั่วไป (100 - 700 กก.)',
        'chips': [250, 300, 350, 400, 500],
      },
      {
        'name': 'ลูกผสมยุโรป (>400-600 กก.)',
        'price': double.tryParse(_getPriceForCategory(state, 'ลูกผสมยุโรป (>400') ?? '73.09') ?? 73.09,
        'minWeight': 401.0,
        'maxWeight': 600.0,
        'defaultWeight': 500.0,
        'rangeLabel': '>400 - 600 กก.',
        'chips': [420, 450, 500, 550, 600],
      },
      {
        'name': 'ลูกผสมยุโรป (>250-400 กก.)',
        'price': double.tryParse(_getPriceForCategory(state, 'ลูกผสมยุโรป (>250') ?? '68.03') ?? 68.03,
        'minWeight': 251.0,
        'maxWeight': 400.0,
        'defaultWeight': 320.0,
        'rangeLabel': '>250 - 400 กก.',
        'chips': [260, 280, 320, 360, 400],
      },
      {
        'name': 'ลูกผสมบราห์มัน (>400-600 กก.)',
        'price': double.tryParse(_getPriceForCategory(state, 'ลูกผสมบราห์มัน (>400') ?? '69.69') ?? 69.69,
        'minWeight': 401.0,
        'maxWeight': 600.0,
        'defaultWeight': 500.0,
        'rangeLabel': '>400 - 600 กก.',
        'chips': [420, 450, 500, 550, 600],
      },
      {
        'name': 'ลูกผสมบราห์มัน (>250-400 กก.)',
        'price': double.tryParse(_getPriceForCategory(state, 'ลูกผสมบราห์มัน (>250') ?? '64.59') ?? 64.59,
        'minWeight': 251.0,
        'maxWeight': 400.0,
        'defaultWeight': 320.0,
        'rangeLabel': '>250 - 400 กก.',
        'chips': [260, 280, 320, 360, 400],
      },
      {
        'name': 'พื้นเมืองไทย (>250-400 กก.)',
        'price': double.tryParse(_getPriceForCategory(state, 'พื้นเมืองไทย (>250') ?? '60.53') ?? 60.53,
        'minWeight': 251.0,
        'maxWeight': 400.0,
        'defaultWeight': 300.0,
        'rangeLabel': '>250 - 400 กก.',
        'chips': [260, 280, 300, 350, 400],
      },
      {
        'name': 'พื้นเมืองไทย (≤250 กก.)',
        'price': double.tryParse(_getPriceForCategory(state, 'พื้นเมืองไทย (≤250') ?? '56.36') ?? 56.36,
        'minWeight': 50.0,
        'maxWeight': 250.0,
        'defaultWeight': 200.0,
        'rangeLabel': '≤ 250 กก.',
        'chips': [100, 150, 180, 200, 250],
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PriceCalculatorModal(categories: categories),
    );
  }

  /// Specifically extract the latest NABC / OAE record
  MarketPrice? _getNabcPriceItem(MarketPriceState state) {
    try {
      return state.allPrices.firstWhere(
        (p) => (p.category != null && p.category!.contains('โคพันธุ์ลูกผสม')) ||
               (p.source != null && p.source!.contains('NABC')),
      );
    } catch (_) {
      try {
        return state.byCategory.firstWhere(
          (p) => (p.category != null && p.category!.contains('โคพันธุ์ลูกผสม')) ||
                 (p.source != null && p.source!.contains('NABC')),
        );
      } catch (_) {
        return null;
      }
    }
  }

  String? _getPriceForCategory(MarketPriceState state, String keyword) {
    try {
      final match = state.allPrices.firstWhere(
        (p) => p.category != null && p.category!.contains(keyword),
      );
      return match.pricePerKg > 0 ? match.pricePerKg.toStringAsFixed(2) : null;
    } catch (_) {
      try {
        final match = state.byCategory.firstWhere(
          (p) => p.category != null && p.category!.contains(keyword),
        );
        return match.pricePerKg > 0 ? match.pricePerKg.toStringAsFixed(2) : null;
      } catch (_) {
        return null;
      }
    }
  }
}

/// Modal BottomSheet Widget สำหรับเครื่องคิดเลขประเมินราคาโค
class _PriceCalculatorModal extends StatefulWidget {
  final List<Map<String, dynamic>> categories;

  const _PriceCalculatorModal({required this.categories});

  @override
  State<_PriceCalculatorModal> createState() => _PriceCalculatorModalState();
}

class _PriceCalculatorModalState extends State<_PriceCalculatorModal> {
  late Map<String, dynamic> _selectedCat;
  late TextEditingController _weightController;
  late double _weight;

  @override
  void initState() {
    super.initState();
    _selectedCat = widget.categories.first;
    _weight = (_selectedCat['defaultWeight'] as num).toDouble();
    _weightController = TextEditingController(text: _weight.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(Map<String, dynamic>? val) {
    if (val != null) {
      setState(() {
        _selectedCat = val;
        final defaultW = (val['defaultWeight'] as num).toDouble();
        _weight = defaultW;
        _weightController.text = defaultW.toStringAsFixed(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricePerKg = (_selectedCat['price'] as num).toDouble();
    final minWeight = (_selectedCat['minWeight'] as num).toDouble();
    final maxWeight = (_selectedCat['maxWeight'] as num).toDouble();
    final rangeLabel = _selectedCat['rangeLabel'] as String;
    final chips = (_selectedCat['chips'] as List<dynamic>).map((e) => (e as num).toInt()).toList();

    final isOutOfBounds = _weight < minWeight || _weight > maxWeight;
    final totalPrice = _weight * pricePerKg;
    final formatter = NumberFormat('#,##0.00');

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calculate_outlined, color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เครื่องคิดเลขคำนวณมูลค่าโค',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'ประเมินราคาขายโดยประมาณตามน้ำหนักตัว',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Field 1: เลือกสายพันธุ์ / ราคากลางอ้างอิง
            const Text(
              'สายพันธุ์และราคากลางอ้างอิง:',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedCat,
                  isExpanded: true,
                  items: widget.categories.map((cat) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: cat,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              cat['name'] as String,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '฿${(cat['price'] as num).toStringAsFixed(2)} /กก.',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _onCategoryChanged,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Field 2: กรอกน้ำหนักตัว (พร้อมแจ้งช่วงน้ำหนักที่อนุญาต)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'น้ำหนักตัวโค (กิโลกรัม):',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOutOfBounds ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isOutOfBounds ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Text(
                    'พิกัด: $rangeLabel',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isOutOfBounds ? const Color(0xFFDC2626) : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'ระบุน้ำหนัก (${minWeight.toInt()} - ${maxWeight.toInt()} กก.)',
                suffixText: 'กก.',
                suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                filled: true,
                fillColor: isOutOfBounds ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isOutOfBounds ? const Color(0xFFF87171) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isOutOfBounds ? const Color(0xFFF87171) : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isOutOfBounds ? const Color(0xFFDC2626) : AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (val) {
                final parsed = double.tryParse(val) ?? 0;
                setState(() => _weight = parsed);
              },
            ),
            if (isOutOfBounds) ...[
              const SizedBox(height: 4),
              Text(
                '⚠️ น้ำหนักสำหรับพิกัดนี้ต้องอยู่ในช่วง ${minWeight.toInt()} - ${maxWeight.toInt()} กก.',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
            const SizedBox(height: 8),

            // Preset Weight Chips (เฉพาะช่วงน้ำหนักของพิกัดที่เลือก)
            Wrap(
              spacing: 6,
              children: chips.map((w) {
                final isSelected = _weight == w.toDouble();
                return ActionChip(
                  label: Text('$w กก.', style: const TextStyle(fontSize: 12)),
                  backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  onPressed: () {
                    setState(() {
                      _weight = w.toDouble();
                      _weightController.text = w.toString();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Result Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOutOfBounds ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOutOfBounds ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isOutOfBounds ? 'มูลค่าคำนวณตามน้ำหนักที่ระบุ (นอกช่วงพิกัด)' : 'มูลค่าประเมินโดยประมาณ',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isOutOfBounds ? const Color(0xFF92400E) : const Color(0xFF166534),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '฿ ${formatter.format(totalPrice)}',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: isOutOfBounds ? const Color(0xFFD97706) : const Color(0xFF15803D),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '($_weight กก. × ${pricePerKg.toStringAsFixed(2)} บาท/กก.)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOutOfBounds ? const Color(0xFF92400E) : const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Close Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('เสร็จสิ้น', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for rendering rich weekly price trend line chart with Axis, labels, and tooltips
class PriceTrendPainter extends CustomPainter {
  final List<MarketPrice> data;
  final int? selectedIndex;

  PriceTrendPainter(this.data, {this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double paddingLeft = 40.0;
    const double paddingRight = 14.0;
    const double paddingTop = 24.0;
    const double paddingBottom = 24.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final prices = data.map((e) => e.pricePerKg).toList();
    double minPrice = prices.reduce((a, b) => a < b ? a : b);
    double maxPrice = prices.reduce((a, b) => a > b ? a : b);

    if (minPrice == maxPrice) {
      minPrice -= 2;
      maxPrice += 2;
    } else {
      final range = maxPrice - minPrice;
      minPrice -= range * 0.15;
      maxPrice += range * 0.15;
    }

    final priceRange = maxPrice - minPrice;

    // 1. Draw horizontal grid lines and Y-axis Price Labels
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;

    for (int i = 0; i <= 2; i++) {
      final y = paddingTop + (chartHeight * (i / 2));
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      // Y-axis label text
      final labelPrice = maxPrice - (priceRange * (i / 2));
      final textSpan = TextSpan(
        text: labelPrice.toStringAsFixed(1),
        style: const TextStyle(
          fontSize: 10.5,
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(2, y - (textPainter.height / 2)));
    }

    // 2. Points calculation
    final points = <Offset>[];
    final dx = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth / 2;

    for (int i = 0; i < data.length; i++) {
      final x = paddingLeft + (data.length > 1 ? i * dx : chartWidth / 2);
      final normalizedPrice = (data[i].pricePerKg - minPrice) / priceRange;
      final y = paddingTop + chartHeight - (normalizedPrice * chartHeight);
      points.add(Offset(x, y));
    }

    // 3. Draw gradient area under the curve
    final path = Path();
    path.moveTo(points.first.dx, paddingTop + chartHeight);
    for (var pt in points) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.lineTo(points.last.dx, paddingTop + chartHeight);
    path.close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1E3A8A).withValues(alpha: 0.22),
          const Color(0xFF1E3A8A).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, chartWidth, chartHeight));

    canvas.drawPath(path, gradientPaint);

    // 4. Draw Line
    final linePaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // 5. Draw Selected Point Indicator (Vertical Dashed Line & Glow)
    if (selectedIndex != null && selectedIndex! < points.length) {
      final selPt = points[selectedIndex!];
      final dashedPaint = Paint()
        ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.4)
        ..strokeWidth = 1;

      // Draw subtle vertical line to bottom
      canvas.drawLine(
        Offset(selPt.dx, paddingTop),
        Offset(selPt.dx, paddingTop + chartHeight),
        dashedPaint,
      );

      // Glow circle
      final glowPaint = Paint()
        ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPt, 9.0, glowPaint);
    }

    // 6. Draw point circles & value labels
    final circleFillPaint = Paint()..color = Colors.white;
    final circleBorderPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final months = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final item = data[i];
      final isSelected = selectedIndex == i;

      // Circle
      canvas.drawCircle(pt, isSelected ? 5.0 : 3.5, circleFillPaint);
      canvas.drawCircle(pt, isSelected ? 5.0 : 3.5, circleBorderPaint);

      // Price Tag above point
      final priceText = item.pricePerKg.toStringAsFixed(1);
      final priceSpan = TextSpan(
        text: priceText,
        style: TextStyle(
          fontSize: isSelected ? 11.5 : 9.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
        ),
      );
      final pricePainter = TextPainter(
        text: priceSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      pricePainter.paint(canvas, Offset(pt.dx - (pricePainter.width / 2), pt.dy - pricePainter.height - 4));

      // X-Axis Date label at bottom
      // If many points, show step to avoid overlap
      final shouldShowDate = data.length <= 6 || i == 0 || i == data.length - 1 || (i % 2 == 0);
      if (shouldShowDate) {
        final dateText = '${item.effectiveDate.day} ${months[item.effectiveDate.month]}';
        final dateSpan = TextSpan(
          text: dateText,
          style: TextStyle(
            fontSize: isSelected ? 10.5 : 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF94A3B8),
          ),
        );
        final datePainter = TextPainter(
          text: dateSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        datePainter.paint(
          canvas,
          Offset(pt.dx - (datePainter.width / 2), size.height - paddingBottom + 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PriceTrendPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.selectedIndex != selectedIndex;
  }
}
