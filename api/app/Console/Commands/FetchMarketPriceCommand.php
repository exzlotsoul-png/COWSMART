<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\MarketPrice;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class FetchMarketPriceCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'market-price:fetch {--force : Force refresh weekly prices} {--year_th= : Thai Year e.g. 2569} {--month= : Month e.g. 07}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Sync real weekly cattle market prices from NABC AgriAPI (agriapi.nabc.go.th)';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $inputYearTh = $this->option('year_th');
        $inputMonth = $this->option('month');

        $this->info('Connecting to Official NABC AGRI API (agriapi.nabc.go.th)...');
        Log::info('MARKET_PRICE_SYNC: Requesting official NABC AgriAPI weekly cattle price dataset...');

        $sourceName = 'NABC AGRI API (agriapi.nabc.go.th) & สศก. (รายสัปดาห์)';
        $syncedCount = 0;

        $queryPeriods = [];

        if ($inputYearTh && $inputMonth) {
            $queryPeriods[] = [
                'year_th' => intval($inputYearTh),
                'month' => sprintf('%02d', intval($inputMonth))
            ];
        } elseif ($inputYearTh) {
            for ($m = 1; $m <= 12; $m++) {
                $queryPeriods[] = [
                    'year_th' => intval($inputYearTh),
                    'month' => sprintf('%02d', $m)
                ];
            }
        } else {
            // Default: Current month, past 3 months, and standard 2569 dataset
            $currentDate = Carbon::now();
            $thaiYear = $currentDate->year + 543;

            for ($i = 0; $i < 6; $i++) {
                $d = Carbon::now()->subMonths($i);
                $queryPeriods[] = [
                    'year_th' => $d->year + 543,
                    'month' => sprintf('%02d', $d->month)
                ];
            }
            $queryPeriods[] = ['year_th' => 2569, 'month' => '07'];
            $queryPeriods[] = ['year_th' => 2569, 'month' => '08'];
        }

        // Deduplicate query periods
        $uniquePeriods = [];
        foreach ($queryPeriods as $p) {
            $key = "{$p['year_th']}-{$p['month']}";
            $uniquePeriods[$key] = $p;
        }

        foreach ($uniquePeriods as $period) {
            $apiUrl = "https://agriapi.nabc.go.th/api/weekly-prices/commod?commod=" . urlencode('โคเนื้อ') . "&page=1&year_th={$period['year_th']}&month={$period['month']}";

            try {
                $this->info("Requesting NABC API: {$apiUrl}");
                $response = Http::withoutVerifying()->withHeaders([
                    'User-Agent' => 'CowSmart-Platform/1.0 (NABC AGRI API Consumer)',
                    'Accept' => 'application/json',
                ])->timeout(8)->get($apiUrl);

                if ($response->successful()) {
                    $json = $response->json();
                    if (!empty($json['data']) && is_array($json['data'])) {
                        $this->info("Successfully received " . count($json['data']) . " weekly items from NABC for period {$period['year_th']}-{$period['month']}");
                        Log::info("MARKET_PRICE_SYNC: Received data from NABC: " . json_encode($json['data'], JSON_UNESCAPED_UNICODE));

                        foreach ($json['data'] as $item) {
                            $weekNum = intval($item['week'] ?? 1);
                            $yearCe = intval($item['year_th']) - 543;
                            $monthNum = intval($item['month']);
                            
                            // Estimate weekly effective date (e.g. week 1 = 7th, week 2 = 14th, week 3 = 21st, week 4 = 28th)
                            $day = min(28, max(1, $weekNum * 7));
                            $effectiveDate = sprintf('%04d-%02d-%02d', $yearCe, $monthNum, $day);

                            $pricePerHead = floatval($item['value'] ?? 0);
                            if ($pricePerHead > 0) {
                                // Convert THB/head to THB/kg (~220 kg standard weight for medium crossbred cattle)
                                $pricePerKg = round($pricePerHead / 220, 2);

                                MarketPrice::updateOrCreate(
                                    [
                                        'animal_type' => 'cattle',
                                        'category' => $item['product_name'] ?? 'โคพันธุ์ลูกผสม ขนาดกลาง',
                                        'effective_date' => $effectiveDate,
                                    ],
                                    [
                                        'price_per_kg' => $pricePerKg,
                                        'source' => $sourceName,
                                        'note' => "สัปดาห์ที่ {$weekNum} เดือน {$item['month']}/{$item['year_th']} (เฉลี่ย {$item['value']} บาท/ตัว)",
                                    ]
                                );
                                $syncedCount++;
                            }
                        }
                    }
                }
            } catch (\Exception $e) {
                $this->warn("Notice connecting to NABC API ({$period['year_th']}-{$period['month']}): " . $e->getMessage());
                Log::warning("MARKET_PRICE_SYNC: Error: " . $e->getMessage());
            }
        }

        $this->info("NABC AgriAPI live sync finished! Total synced records: {$syncedCount}");
        Log::info("MARKET_PRICE_SYNC: Total synced {$syncedCount} records from NABC AgriAPI.");
        return 0;
    }
}
