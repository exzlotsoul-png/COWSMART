<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cow;
use App\Models\FinancialRecord;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class CowCostController extends Controller
{
    /**
     * GET /api/cow_costs/{cowId}
     * Returns cost summary for a specific cow with breakdown by category.
     * Highly optimized for fast query execution and low latency.
     */
    public function show(Request $request, $cowId)
    {
        // 1. Fetch cow minimal attributes needed
        $cow = Cow::select('cow_id', 'farm_id', 'zone_id', 'purchase_price', 'latest_weight')
            ->findOrFail($cowId);

        $purchasePrice = (double) ($cow->purchase_price ?? 0);
        $zoneId = $cow->zone_id;
        $cowWeight = (double) ($cow->latest_weight > 0 ? $cow->latest_weight : 100);

        // 2. Health costs & details (Single direct query with joins)
        $healthDetailsRaw = DB::table('health_records')
            ->leftJoin('diseases', 'health_records.disease_id', '=', 'diseases.disease_id')
            ->leftJoin('medicines', 'health_records.med_id', '=', 'medicines.medicine_id')
            ->leftJoin('vaccines', 'health_records.vac_id', '=', 'vaccines.vaccine_id')
            ->where('health_records.cow_id', $cowId)
            ->whereNotNull('health_records.cost')
            ->where('health_records.cost', '>', 0)
            ->select(
                'health_records.health_record_id',
                'health_records.record_date',
                'health_records.cost',
                'health_records.checkup_type_id',
                'health_records.items_json',
                'diseases.name as disease_name',
                'medicines.name as medicine_name',
                'vaccines.name as vaccine_name'
            )
            ->orderBy('health_records.record_date', 'desc')
            ->get();

        $healthCost = (double) $healthDetailsRaw->sum('cost');

        // 3. Feed costs (by zone + direct assignment)
        $feedCost = 0.0;
        $feedDetails = [];

        if ($zoneId) {
            // Feeding records cost for this zone
            $totalFeedingRecordsCost = (double) DB::table('feeding_records')
                ->where('zone_id', $zoneId)
                ->sum('cost');

            // Feed inventories cost for this zone (excluding direct-assigned ones)
            $totalFeedInventoriesCost = (double) DB::table('feed_inventories')
                ->where('zone_id', $zoneId)
                ->where(function ($q) {
                    $q->whereNull('cow_ids')->orWhere('cow_ids', '[]')->orWhere('cow_ids', '');
                })
                ->sum('cost_per_kg');

            $totalFeedCost = $totalFeedingRecordsCost + $totalFeedInventoriesCost;

            // Direct SQL aggregation for total weight in zone (fast, cached briefly)
            $totalWeight = (double) Cache::remember("zone_weight_sum_{$zoneId}", 60, function () use ($zoneId) {
                return DB::table('cows')
                    ->where('zone_id', $zoneId)
                    ->selectRaw('SUM(CASE WHEN latest_weight IS NOT NULL AND latest_weight > 0 THEN latest_weight ELSE 100 END) as total_weight')
                    ->value('total_weight') ?? 0;
            });

            $weightRatio = $totalWeight > 0 ? ($cowWeight / $totalWeight) : 0;
            $feedCost = round($totalFeedCost * $weightRatio, 2);

            // Fetch feeding records breakdown (limit to 30 newest)
            $feedingRecs = DB::table('feeding_records')
                ->where('zone_id', $zoneId)
                ->whereNotNull('cost')
                ->where('cost', '>', 0)
                ->select('feeding_record_id as id', 'feed_date as date', 'feed_type as type', 'amount', 'cost')
                ->orderBy('feed_date', 'desc')
                ->limit(30)
                ->get()
                ->map(function ($item) use ($weightRatio) {
                    return [
                        'id' => $item->id,
                        'date' => $item->date,
                        'type' => $item->type,
                        'amount' => $item->amount,
                        'cost' => (double) $item->cost,
                        'cost_per_cow' => round($item->cost * $weightRatio, 2),
                        'source' => 'feeding_record',
                    ];
                })
                ->toArray();

            // Fetch zone feed inventories breakdown (limit to 30 newest)
            $feedInvs = DB::table('feed_inventories')
                ->where('zone_id', $zoneId)
                ->whereNotNull('cost_per_kg')
                ->where('cost_per_kg', '>', 0)
                ->where(function ($q) {
                    $q->whereNull('cow_ids')->orWhere('cow_ids', '[]')->orWhere('cow_ids', '');
                })
                ->select('feed_inventory_id as id', 'created_at as date', 'name as type', 'stock_quantity as amount', 'cost_per_kg as cost')
                ->orderBy('created_at', 'desc')
                ->limit(30)
                ->get()
                ->map(function ($item) use ($weightRatio) {
                    return [
                        'id' => $item->id,
                        'date' => (string) $item->date,
                        'type' => $item->type,
                        'amount' => $item->amount,
                        'cost' => (double) $item->cost,
                        'cost_per_cow' => round($item->cost * $weightRatio, 2),
                        'source' => 'feed_inventory',
                    ];
                })
                ->toArray();

            $feedDetails = array_merge($feedingRecs, $feedInvs);
        }

        // Direct feed assigned specifically to this cow (fast JSON search or filtering)
        $directCowFeeds = DB::table('feed_inventories')
            ->whereNotNull('cow_ids')
            ->whereNotNull('cost_per_kg')
            ->where('cost_per_kg', '>', 0)
            ->where(function ($q) use ($cowId) {
                // Filter at DB level if JSON contains cowId to avoid loading all feed rows
                $q->where('cow_ids', 'like', "%\"$cowId\"%")
                  ->orWhere('cow_ids', 'like', "%$cowId%");
            })
            ->select('feed_inventory_id', 'created_at', 'name', 'stock_quantity', 'cost_per_kg', 'cow_ids')
            ->get();

        foreach ($directCowFeeds as $feedRecord) {
            $targetCowIds = is_string($feedRecord->cow_ids)
                ? json_decode($feedRecord->cow_ids, true)
                : (array) $feedRecord->cow_ids;

            if (is_array($targetCowIds) && in_array($cowId, $targetCowIds)) {
                $numCows = count($targetCowIds);
                $allocatedCost = $numCows > 0 ? round(((double) $feedRecord->cost_per_kg) / $numCows, 2) : 0;
                $feedCost += $allocatedCost;

                $feedDetails[] = [
                    'id' => $feedRecord->feed_inventory_id,
                    'date' => (string) $feedRecord->created_at,
                    'type' => $feedRecord->name . ($numCows > 1 ? " (ระบุ $numCows ตัว)" : " (ระบุเฉพาะตัว)"),
                    'amount' => $numCows > 0 ? round(((double) $feedRecord->stock_quantity) / $numCows, 2) : 0,
                    'cost' => (double) $feedRecord->cost_per_kg,
                    'cost_per_cow' => $allocatedCost,
                    'source' => 'feed_inventory_direct',
                ];
            }
        }

        // Sort feed details by date descending and slice
        usort($feedDetails, function ($a, $b) {
            return strcmp($b['date'] ?? '', $a['date'] ?? '');
        });
        $feedDetails = array_slice($feedDetails, 0, 50);

        // 4. Direct financial records linked to this cow (combined query)
        $directRecords = DB::table('financial_records')
            ->where('related_cow_id', $cowId)
            ->select('financial_record_id', 'farm_id', 'title', 'trans_type', 'category', 'amount', 'record_date', 'notes', 'created_at')
            ->orderBy('record_date', 'desc')
            ->get();

        $directCosts = $directRecords->where('trans_type', 'expense')->values();
        $directCostTotal = (double) $directCosts->sum('amount');
        $directIncome = (double) $directRecords->where('trans_type', 'income')->sum('amount');

        // 5. Summary calculations
        $totalCost = $healthCost + $feedCost + $directCostTotal + $purchasePrice;

        return response()->json([
            'cow_id' => $cowId,
            'summary' => [
                'total_cost' => round($totalCost, 2),
                'total_income' => round($directIncome, 2),
                'net_cost' => round($totalCost - $directIncome, 2),
                'health_cost' => round($healthCost, 2),
                'feed_cost' => round($feedCost, 2),
                'direct_cost' => round($directCostTotal, 2),
                'purchase_price' => $purchasePrice,
            ],
            'breakdown' => [
                'health' => $healthDetailsRaw,
                'feed' => $feedDetails,
                'direct' => $directCosts,
            ],
        ]);
    }
}
