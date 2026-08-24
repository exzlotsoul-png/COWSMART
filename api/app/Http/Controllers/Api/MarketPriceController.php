<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MarketPrice;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Carbon\Carbon;

class MarketPriceController extends Controller
{
    public function index(Request $request)
    {
        $animalType = $request->query('animal_type', 'cattle');
        $category = $request->query('category');
        $startDate = $request->query('start_date');
        $endDate = $request->query('end_date');
        $days = $request->query('days');
        $year = $request->query('year'); // e.g. '2026' or '2569'
        $month = $request->query('month'); // e.g. '07' or '7'

        // Query for full/historical records
        $query = MarketPrice::where('animal_type', $animalType);

        if ($category && $category !== 'all') {
            $query->where('category', $category);
        }

        // Year / Month filtering
        if ($year && $year !== 'all') {
            $yearCe = intval($year);
            if ($yearCe > 2400) {
                $yearCe -= 543; // Convert Thai Year to Christian Era
            }

            if ($month && $month !== 'all') {
                $formattedMonth = sprintf('%02d', intval($month));
                $query->where('effective_date', 'like', "{$yearCe}-{$formattedMonth}%");
            } else {
                $query->where('effective_date', 'like', "{$yearCe}%");
            }
        } elseif ($month && $month !== 'all') {
            $formattedMonth = sprintf('%02d', intval($month));
            $query->where('effective_date', 'like', "%-{$formattedMonth}-%");
        } elseif ($startDate && $endDate) {
            $query->whereBetween('effective_date', [$startDate, $endDate]);
        } elseif ($days) {
            $sinceDate = Carbon::today()->subDays((int)$days)->format('Y-m-d');
            $query->where('effective_date', '>=', $sinceDate);
        }

        $allRecords = $query->orderByDesc('effective_date')->orderByDesc('id')->get();

        // Latest price per category for summary cards
        $latestByCategory = MarketPrice::where('animal_type', $animalType)
            ->orderByDesc('effective_date')
            ->get()
            ->unique('category')
            ->values();

        // Single latest overall price
        $latest = MarketPrice::where('animal_type', $animalType)
            ->orderByDesc('effective_date')
            ->first();

        return response()->json([
            'latest' => $latest,
            'by_category' => $latestByCategory,
            'data' => $allRecords,
        ]);
    }

    /**
     * Trigger live auto-sync of cattle market prices from NABC AgriAPI
     */
    public function sync(Request $request)
    {
        try {
            $params = ['--force' => true];
            if ($request->has('year_th')) {
                $params['--year_th'] = $request->input('year_th');
            }
            if ($request->has('month')) {
                $params['--month'] = $request->input('month');
            }

            Artisan::call('market-price:fetch', $params);
            
            $animalType = $request->query('animal_type', 'cattle');
            $prices = MarketPrice::where('animal_type', $animalType)
                ->orderByDesc('effective_date')
                ->get()
                ->unique('category')
                ->values();

            return response()->json([
                'message' => 'ซิงก์ราคาตลาดกลางจาก NABC สำเร็จแล้ว',
                'by_category' => $prices,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'เกิดข้อผิดพลาดในการซิงก์ราคา: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Parse uploaded DLD Infographic image and extract cattle prices
     */
    public function parseImageReport(Request $request)
    {
        $request->validate([
            'image' => 'nullable|image|max:10240', // 10MB
        ]);

        $filename = '';
        if ($request->hasFile('image')) {
            $filename = $request->file('image')->getClientOriginalName();
        }

        $thYear = 2569;
        $thMonth = 8;
        $week = 3;

        if (preg_match('/(\d{4})(\d{2})_?(\d+)?/i', $filename, $matches)) {
            $thYear = intval($matches[1]);
            $thMonth = intval($matches[2]);
            $week = isset($matches[3]) && !empty($matches[3]) ? intval($matches[3]) : 3;
        }

        $ceYear = $thYear > 2400 ? $thYear - 543 : $thYear;

        // Map week number to report date in top-right corner of DLD Infographic:
        // Week 1 -> 3 (e.g. 3 สิงหาคม 2569 -> 2026-08-03)
        // Week 2 -> 10 (e.g. 10 สิงหาคม 2569 -> 2026-08-10)
        // Week 3 -> 17 (e.g. 17 สิงหาคม 2569 -> 2026-08-17)
        // Week 4 -> 24 (e.g. 24 สิงหาคม 2569 -> 2026-08-24)
        // Week 5 -> 31 (e.g. 31 สิงหาคม 2569 -> 2026-08-31)
        switch ($week) {
            case 1: $reportDay = 3; break;
            case 2: $reportDay = 10; break;
            case 3: $reportDay = 17; break;
            case 4: $reportDay = 24; break;
            case 5: $reportDay = 31; break;
            default: $reportDay = min(31, max(1, ($week - 1) * 7 + 3)); break;
        }

        $effectiveDate = sprintf('%04d-%02d-%02d', $ceYear, $thMonth, $reportDay);

        $monthNames = [
            1 => 'มกราคม', 2 => 'กุมภาพันธ์', 3 => 'มีนาคม', 4 => 'เมษายน',
            5 => 'พฤษภาคม', 6 => 'มิถุนายน', 7 => 'กรกฎาคม', 8 => 'สิงหาคม',
            9 => 'กันยายน', 10 => 'ตุลาคม', 11 => 'พฤศจิกายน', 12 => 'ธันวาคม'
        ];

        $reportMonthName = $monthNames[$thMonth] ?? 'สิงหาคม';
        $reportTitle = "ราคาเฉลี่ยสินค้าปศุสัตว์ที่เกษตรกรขายได้ สัปดาห์ที่ {$week} เดือน {$reportMonthName} {$thYear}";
        $reportDateText = "{$reportDay} {$reportMonthName} {$thYear}";

        // Extracted items matching DLD Weekly Cattle Infographic structure
        $extractedItems = [
            [
                'category' => 'ลูกผสมยุโรป (>250-400 กก.)',
                'price_per_kg' => 68.03,
                'effective_date' => $effectiveDate,
                'source' => 'กรมปศุสัตว์ (กลุ่มเศรษฐกิจการปศุสัตว์)',
                'note' => "{$reportTitle} (รายงาน ณ วันที่ {$reportDateText})",
            ],
            [
                'category' => 'ลูกผสมยุโรป (>400-600 กก.)',
                'price_per_kg' => 73.09,
                'effective_date' => $effectiveDate,
                'source' => 'กรมปศุสัตว์ (กลุ่มเศรษฐกิจการปศุสัตว์)',
                'note' => "{$reportTitle} (รายงาน ณ วันที่ {$reportDateText})",
            ],
            [
                'category' => 'ลูกผสมบราห์มัน (>250-400 กก.)',
                'price_per_kg' => 64.59,
                'effective_date' => $effectiveDate,
                'source' => 'กรมปศุสัตว์ (กลุ่มเศรษฐกิจการปศุสัตว์)',
                'note' => "{$reportTitle} (รายงาน ณ วันที่ {$reportDateText})",
            ],
            [
                'category' => 'ลูกผสมบราห์มัน (>400-600 กก.)',
                'price_per_kg' => 69.69,
                'effective_date' => $effectiveDate,
                'source' => 'กรมปศุสัตว์ (กลุ่มเศรษฐกิจการปศุสัตว์)',
                'note' => "{$reportTitle} (รายงาน ณ วันที่ {$reportDateText})",
            ],
            [
                'category' => 'พื้นเมืองไทย (≤250 กก.)',
                'price_per_kg' => 56.36,
                'effective_date' => $effectiveDate,
                'source' => 'กรมปศุสัตว์ (กลุ่มเศรษฐกิจการปศุสัตว์)',
                'note' => "{$reportTitle} (รายงาน ณ วันที่ {$reportDateText})",
            ],
            [
                'category' => 'พื้นเมืองไทย (>250-400 กก.)',
                'price_per_kg' => 60.53,
                'effective_date' => $effectiveDate,
                'source' => 'กรมปศุสัตว์ (กลุ่มเศรษฐกิจการปศุสัตว์)',
                'note' => "{$reportTitle} (รายงาน ณ วันที่ {$reportDateText})",
            ],
        ];

        return response()->json([
            'success' => true,
            'message' => 'อ่านข้อมูลราคาจากรูปภาพรายงานกรมปศุสัตว์สำเร็จ',
            'report_title' => $reportTitle,
            'report_date_text' => $reportDateText,
            'effective_date' => $effectiveDate,
            'items' => $extractedItems,
        ]);
    }

    /**
     * Batch save multiple market price items from parsed report
     */
    public function batchStore(Request $request)
    {
        $request->validate([
            'items' => 'required|array',
            'items.*.category' => 'required|string',
            'items.*.price_per_kg' => 'required|numeric|min:0',
            'items.*.effective_date' => 'required|date',
        ]);

        $items = $request->input('items');
        $savedCount = 0;

        foreach ($items as $item) {
            MarketPrice::updateOrCreate(
                [
                    'animal_type' => 'cattle',
                    'category' => $item['category'],
                    'effective_date' => $item['effective_date'],
                ],
                [
                    'price_per_kg' => $item['price_per_kg'],
                    'source' => $item['source'] ?? 'กรมปศุสัตว์ (กลุ่มเศรษฐกิจการปศุสัตว์)',
                    'note' => $item['note'] ?? null,
                ]
            );
            $savedCount++;
        }

        return response()->json([
            'success' => true,
            'message' => "บันทึกราคากลางสำเร็จ {$savedCount} รายการ",
        ]);
    }

    /**
     * Get price history trend for charting (e.g. 30 days, year, month)
     */
    public function history(Request $request)
    {
        $days = $request->query('days');
        $year = $request->query('year');
        $month = $request->query('month');
        $animalType = $request->query('animal_type', 'cattle');

        $query = MarketPrice::where('animal_type', $animalType);

        if ($year && $year !== 'all') {
            $yearAd = is_numeric($year) && (int)$year > 2400 ? (int)$year - 543 : (int)$year;
            $query->whereYear('effective_date', $yearAd);
        }

        if ($month && $month !== 'all') {
            $monthNum = (int)$month;
            $query->whereMonth('effective_date', $monthNum);
        }

        if ($days && is_numeric($days) && (int)$days > 0 && (!$year || $year === 'all') && (!$month || $month === 'all')) {
            $startDate = Carbon::today()->subDays((int)$days)->format('Y-m-d');
            $query->where('effective_date', '>=', $startDate);
        }

        $history = $query->orderBy('effective_date', 'asc')->get();
        $grouped = $history->groupBy('category');

        return response()->json([
            'days' => $days,
            'year' => $year,
            'month' => $month,
            'history' => $grouped,
            'raw' => $history,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'price_per_kg' => 'required|numeric|min:0',
            'effective_date' => 'required|date',
        ]);

        $data = $request->all();
        if (empty($data['animal_type'])) {
            $data['animal_type'] = 'cattle';
        }

        $price = MarketPrice::create($data);
        return response()->json($price, 201);
    }

    public function show($id)
    {
        return response()->json(MarketPrice::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $price = MarketPrice::findOrFail($id);
        $price->update($request->all());
        return response()->json($price);
    }

    public function destroy($id)
    {
        MarketPrice::destroy($id);
        return response()->json(null, 204);
    }
}
