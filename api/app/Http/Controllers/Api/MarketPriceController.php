<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MarketPrice;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
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
            'image' => 'required|image|max:10240', // 10MB
        ]);

        $file = $request->file('image');
        $imgData = base64_encode(file_get_contents($file->getRealPath()));
        $mimeType = $file->getMimeType() ?: 'image/png';

        $geminiApiKey = config('services.gemini.api_key') ?: env('GEMINI_API_KEY');

        if (empty($geminiApiKey)) {
            return response()->json([
                'success' => false,
                'message' => 'ไม่พบการตั้งค่า GEMINI_API_KEY สำหรับการตรวจสอบรูปภาพรายงาน',
            ], 500);
        }

        $prompt = <<<EOT
คำสั่งสำคัญ: คุณคือระบบตรวจสอบและอ่านเอกสารรายงานราคาปศุสัตว์
จงตรวจสอบรูปภาพที่ได้รับอย่างละเอียดและเข้มงวด:

รูปภาพนี้เป็น "ภาพอินโฟกราฟิกรายงานราคาเฉลี่ยสินค้าปศุสัตว์ที่เกษตรกรขายได้ จากกรมปศุสัตว์" หรือไม่?
เกณฑ์การพิจารณาว่า ใช่ (is_dld_report = true):
1. ต้องเป็นภาพอินโฟกราฟิกตารางสรุปรายงานราคาสินค้าปศุสัตว์ (เช่น มีหัวข้อ "ราคาเฉลี่ยสินค้าปศุสัตว์ที่เกษตรกรขายได้", มีโลโก้กรมปศุสัตว์/กระทรวงเกษตรและสหกรณ์ หรือระบุกลุ่มเศรษฐกิจการปศุสัตว์)
2. มีตารางหรือส่วนแสดงราคาปศุสัตว์ โดยเฉพาะหัวข้อ "โคเนื้อและกระบือ" หรือสัตว์ปศุสัตว์อื่นๆ พร้อมตัวเลขราคา

เกณฑ์การพิจารณาว่า ไม่ใช่ (is_dld_report = false):
- ภาพถ่ายวัวหรือสัตว์เลี้ยงเดี่ยวๆ ทั่วไปในฟาร์ม
- ภาพหน้าจอแอปพลิเคชัน (Mobile App / Web Dashboard Screen)
- ภาพสลิปโอนเงิน ใบเสร็จ เอกสารอื่นๆ ที่ไม่ใช่ภาพอินโฟกราฟิกรายงานราคาของกรมปศุสัตว์
- ภาพบุคคล ภาพทิวทัศน์ หรือภาพกราฟิกอื่นๆ

หากไม่ใช่ (is_dld_report = false):
ให้ตอบ JSON:
{
  "is_dld_report": false,
  "reason": "ระบุเหตุผลภาษาไทยสั้นๆ ชัดเจน เช่น รูปภาพที่อัปโหลดไม่ใช่ภาพรายงานราคาของกรมปศุสัตว์ แต่เป็นภาพถ่ายสัตว์ทั่วไป/หน้าจอแอป"
}

หากใช่ (is_dld_report = true):
ให้อ่านและสกัดข้อมูลราคาของหมวด 'โคเนื้อและกระบือ' โดยยึดตัวเลขราคา ณ วันที่ล่าสุด (ช่องสัปดาห์นี้ หรือ ราคา ณ วันที่ล่าสุด) ออกมาดังนี้:
{
  "is_dld_report": true,
  "title": "หัวข้อรายงาน เช่น ราคาเฉลี่ยสินค้าปศุสัตว์ที่เกษตรกรขายได้ สัปดาห์ที่ 1 เดือน กันยายน 2569",
  "report_date_text": "วันที่ที่ระบุมุมบนขวาของภาพอย่างแม่นยำ เช่น 7 กันยายน 2569",
  "effective_date": "วันที่มุมบนขวาของภาพในรูปแบบ YYYY-MM-DD โดยแปลงปี พ.ศ. เป็น ค.ศ. (ต้องตรงกับวันที่มุมบนขวาเป๊ะๆ เช่น รายงาน ณ วันที่ 7 กันยายน 2569 จะได้ 2026-09-07)",
  "cattle_prices": [
    {
      "category": "สายพันธุ์และพิกัดน้ำหนัก เช่น ลูกผสมยุโรป (>250-400 กก.)",
      "price_per_kg": 69.82
    }
  ]
}
ตอบเฉพาะ JSON เท่านั้น
EOT;

        $models = ['gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-3.7-flash'];
        $aiParsed = null;
        $lastError = null;

        foreach ($models as $model) {
            try {
                $response = Http::timeout(35)->post("https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$geminiApiKey}", [
                    'contents' => [
                        [
                            'role' => 'user',
                            'parts' => [
                                ['text' => $prompt],
                                [
                                    'inline_data' => [
                                        'mime_type' => $mimeType,
                                        'data' => $imgData
                                    ]
                                ]
                            ]
                        ]
                    ],
                    'generationConfig' => [
                        'temperature' => 0.1,
                        'responseMimeType' => 'application/json'
                    ]
                ]);

                if ($response->successful()) {
                    $jsonText = $response->json()['candidates'][0]['content']['parts'][0]['text'] ?? '';
                    $decoded = json_decode($jsonText, true);
                    if ($decoded && isset($decoded['is_dld_report'])) {
                        $aiParsed = $decoded;
                        break;
                    }
                } else {
                    $lastError = "Model {$model} returned status " . $response->status() . ": " . $response->body();
                    Log::warning("Gemini Vision failed with {$model}: " . $response->body());
                }
            } catch (\Exception $e) {
                $lastError = $e->getMessage();
                Log::error("Gemini Vision Exception with {$model}: " . $e->getMessage());
            }
        }

        if (!$aiParsed) {
            return response()->json([
                'success' => false,
                'message' => 'ระบบ AI ขัดข้องชั่วคราว ไม่สามารถตรวจสอบรูปภาพได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง (' . ($lastError ? substr($lastError, 0, 100) : 'Service Unavailable') . ')',
            ], 503);
        }

        // Validate whether it's truly a DLD livestock report
        if (empty($aiParsed['is_dld_report'])) {
            $reason = $aiParsed['reason'] ?? 'รูปภาพที่อัปโหลดไม่ใช่รายงานราคาสินค้าปศุสัตว์จากกรมปศุสัตว์';
            return response()->json([
                'success' => false,
                'message' => "ไม่สามารถดำเนินการได้: {$reason} กรุณาอัปโหลดรูปภาพอินโฟกราฟิกรายงานราคาของกรมปศุสัตว์เท่านั้น",
                'reason' => $reason,
            ], 422);
        }

        $reportTitle = $aiParsed['title'] ?? 'ราคาเฉลี่ยสินค้าปศุสัตว์ที่เกษตรกรขายได้ กรมปศุสัตว์';
        $reportDateText = $aiParsed['report_date_text'] ?? '';
        $effectiveDate = !empty($aiParsed['effective_date']) ? $aiParsed['effective_date'] : date('Y-m-d');

        $extractedItems = [];
        if (!empty($aiParsed['cattle_prices']) && is_array($aiParsed['cattle_prices'])) {
            foreach ($aiParsed['cattle_prices'] as $item) {
                if (empty($item['category']) || !isset($item['price_per_kg'])) continue;
                $extractedItems[] = [
                    'category' => $item['category'],
                    'price_per_kg' => floatval($item['price_per_kg']),
                    'effective_date' => $effectiveDate,
                    'source' => 'กรมปศุสัตว์ (กลุ่มเศรษฐกิจการปศุสัตว์)',
                    'note' => "{$reportTitle}" . ($reportDateText ? " (รายงาน ณ วันที่ {$reportDateText})" : ""),
                ];
            }
        }

        if (empty($extractedItems)) {
            return response()->json([
                'success' => false,
                'message' => 'ตรวจพบเป็นรายงานของกรมปศุสัตว์ แต่ไม่พบข้อมูลตารางราคาโคเนื้อในรูปภาพ กรุณาตรวจสอบรูปภาพอีกครั้ง',
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => 'ตรวจสอบผ่าน: อ่านข้อมูลราคาจากรูปภาพรายงานกรมปศุสัตว์สำเร็จ',
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
