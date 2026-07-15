<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cow;
use App\Models\FinancialRecord;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CowCostController extends Controller
{
    /**
     * GET /api/cow_costs/{cowId}
     * Returns cost summary for a specific cow with breakdown by category
     */
    public function show(Request $request, $cowId)
    {
        $cow = Cow::findOrFail($cowId);
        $purchasePrice = (double) ($cow->purchase_price ?? 0);

        // 1. Health costs (from health_records)
        $healthCost = DB::table('health_records')
            ->where('cow_id', $cowId)
            ->sum('cost') ?? 0;

        // 2. Feed costs (from feeding_records AND feed_inventories with matching zone_id weighted by body weight)
        $feedCost = 0;
        $zoneId = $cow->zone_id;
        if ($zoneId) {
            $totalFeedingRecordsCost = DB::table('feeding_records')
                ->where('zone_id', $zoneId)
                ->sum('cost') ?? 0;

            $totalFeedInventoriesCost = DB::table('feed_inventories')
                ->where('zone_id', $zoneId)
                ->sum('cost_per_kg') ?? 0;

            $totalFeedCost = $totalFeedingRecordsCost + $totalFeedInventoriesCost;

            // Get total weight of all cows in this zone
            $cowsList = Cow::where('zone_id', $zoneId)->get();
            $totalWeight = $cowsList->sum(function($c) {
                return (double) ($c->latest_weight > 0 ? $c->latest_weight : 100);
            });

            if ($totalWeight > 0) {
                $cowWeight = (double) ($cow->latest_weight > 0 ? $cow->latest_weight : 100);
                $weightRatio = $cowWeight / $totalWeight;
                $feedCost = round($totalFeedCost * $weightRatio, 2);
            }
        }

        // 3. Direct financial records linked to this cow
        $directCosts = FinancialRecord::where('related_cow_id', $cowId)
            ->where('trans_type', 'expense')
            ->get();

        $directCostTotal = $directCosts->sum('amount');

        // 4. Direct income linked to this cow
        $directIncome = FinancialRecord::where('related_cow_id', $cowId)
            ->where('trans_type', 'income')
            ->sum('amount');

        // Build breakdown
        $totalCost = $healthCost + $feedCost + $directCostTotal + $purchasePrice;

        // Get detailed health record list
        $healthDetails = DB::table('health_records')
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
                'diseases.name as disease_name',
                'medicines.name as medicine_name',
                'vaccines.name as vaccine_name'
            )
            ->orderBy('health_records.record_date', 'desc')
            ->get();

        // Get feeding records & feed inventories for this zone
        $feedDetails = [];
        if ($zoneId) {
            $cowsList = Cow::where('zone_id', $zoneId)->get();
            $totalWeight = $cowsList->sum(function($c) {
                return (double) ($c->latest_weight > 0 ? $c->latest_weight : 100);
            });
            $cowWeight = (double) ($cow->latest_weight > 0 ? $cow->latest_weight : 100);
            $weightRatio = $totalWeight > 0 ? ($cowWeight / $totalWeight) : 0;

            // Fetch from feeding_records
            $feedingRecs = DB::table('feeding_records')
                ->where('zone_id', $zoneId)
                ->whereNotNull('cost')
                ->where('cost', '>', 0)
                ->select('feeding_record_id as id', 'feed_date as date', 'feed_type as type', 'amount', 'cost')
                ->get()
                ->map(function ($item) use ($weightRatio) {
                    $item->cost_per_cow = round($item->cost * $weightRatio, 2);
                    $item->source = 'feeding_record';
                    return (array) $item;
                })
                ->toArray();

            // Fetch from feed_inventories linked to this zone
            $feedInvs = DB::table('feed_inventories')
                ->where('zone_id', $zoneId)
                ->whereNotNull('cost_per_kg')
                ->where('cost_per_kg', '>', 0)
                ->select('feed_inventory_id as id', 'created_at as date', 'name as type', 'stock_quantity as amount', 'cost_per_kg as cost')
                ->get()
                ->map(function ($item) use ($weightRatio) {
                    $item->cost_per_cow = round($item->cost * $weightRatio, 2);
                    $item->source = 'feed_inventory';
                    return (array) $item;
                })
                ->toArray();

            $feedDetails = array_merge($feedingRecs, $feedInvs);

            // Sort merged array by date desc
            usort($feedDetails, function ($a, $b) {
                return strcmp($b['date'], $a['date']);
            });

            // Limit to 50 items
            $feedDetails = array_slice($feedDetails, 0, 50);
        }

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
                'health' => $healthDetails,
                'feed' => $feedDetails,
                'direct' => $directCosts,
            ],
        ]);
    }
}
