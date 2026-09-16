<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CullingRecord;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\FinancialRecord;
use App\Models\HealthAppointment;
use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class CullingRecordController extends Controller
{
    public function index(Request $request)
    {
        $query = CullingRecord::query()->with('cow');

        if ($request->has('farm_id')) {
            $cowIds = Cow::where('farm_id', $request->farm_id)->pluck('cow_id');
            $query->whereIn('cow_id', $cowIds);
        } elseif ($request->has('cow_id')) {
            $query->where('cow_id', $request->cow_id);
        }

        return response()->json(
            $query->orderBy('cull_date', 'desc')->get()
        );
    }

    public function store(Request $request)
    {
        // Bulk store support
        if ($request->has('records') && is_array($request->records)) {
            return DB::transaction(function () use ($request) {
                $createdRecords = [];
                foreach ($request->records as $rData) {
                    if (empty($rData['cow_id']) || !isset($rData['status']) || empty($rData['cull_date'])) {
                        continue;
                    }

                    // Validate cow_id exists to prevent FK constraint violation
                    $cow = Cow::find($rData['cow_id']);
                    if (!$cow) {
                        \Log::warning('[CullingRecord] Skipped: cow_id not found: ' . $rData['cow_id']);
                        continue;
                    }

                    // Normalize cull_date: parse ISO 8601 / any format → MySQL datetime
                    $rData['cull_date'] = Carbon::parse($rData['cull_date'])->format('Y-m-d H:i:s');

                    if (empty($rData['culling_record_id'])) {
                        unset($rData['culling_record_id']);
                    }
                    $createData = $rData;
                    unset($createData['delete_appointments'], $createData['cow']);

                    // Create culling record
                    $record = CullingRecord::create($createData);
                    $createdRecords[] = $record;

                    // Update cow status and clear zone_id
                    $statusStr = 'normal';
                    switch ((int)$rData['status']) {
                        case 0:
                            $statusStr = 'sold';
                            break;
                        case 1:
                            $statusStr = 'deceased';
                            break;
                        case 2:
                            $statusStr = 'removed';
                            break;
                    }
                    $cow->update([
                        'status' => $statusStr,
                        'zone_id' => null,
                    ]);

                    // If sold (status == 0) and has price > 0, auto-insert into financial records
                    $price = (double)($rData['price'] ?? 0);
                    if ((int)$rData['status'] === 0 && $price > 0) {
                        $cullDate = Carbon::parse($rData['cull_date'])->format('Y-m-d');
                        
                        $lastFR = FinancialRecord::where('financial_record_id', 'LIKE', 'FR%')
                            ->whereRaw('financial_record_id REGEXP "^FR[0-9]+$"')
                            ->orderByRaw('CAST(SUBSTRING(financial_record_id, 3) AS UNSIGNED) DESC')
                            ->first();
                        $nextFRNum = $lastFR ? ((int)substr($lastFR->financial_record_id, 2)) + 1 : 1;
                        $frId = 'FR' . str_pad($nextFRNum, 3, '0', STR_PAD_LEFT);

                        FinancialRecord::create([
                            'financial_record_id' => $frId,
                            'farm_id' => $cow->farm_id,
                            'title' => "ขายวัว หมายเลข " . ($cow->tag_number ?? $cow->cow_id),
                            'trans_type' => 'income',
                            'category' => 'ขายวัว',
                            'related_cow_id' => $cow->cow_id,
                            'amount' => $price,
                            'transaction_date' => $cullDate,
                            'notes' => "ระบบบันทึกรายรับอัตโนมัติจากการคัดทิ้งขายวัว: " . ($rData['note'] ?? ''),
                        ]);
                    }

                    // If delete_appointments is requested, clean up appointments for this cow
                    $shouldDeleteAppts = filter_var($rData['delete_appointments'] ?? $request->input('delete_appointments', false), FILTER_VALIDATE_BOOLEAN);
                    if ($shouldDeleteAppts) {
                        $this->removeCowAppointments($cow);
                    }
                }
                return response()->json($createdRecords, 201);
            });
        }

        // Single record fallback
        $request->validate([
            'cow_id' => 'required|exists:cows,cow_id',
            'status' => 'required|integer',
            'cull_date' => 'required',
        ]);

        return DB::transaction(function () use ($request) {
            $data = $request->all();
            if (empty($data['culling_record_id'])) {
                unset($data['culling_record_id']);
            }
            $createData = $data;
            unset($createData['delete_appointments'], $createData['cow']);

            // Create culling record
            $record = CullingRecord::create($createData);

            // Update cow status and clear zone_id
            $cow = Cow::findOrFail($request->cow_id);
            $statusStr = 'normal';
            switch ((int)$request->status) {
                case 0:
                    $statusStr = 'sold';
                    break;
                case 1:
                    $statusStr = 'deceased';
                    break;
                case 2:
                    $statusStr = 'removed';
                    break;
            }
            $cow->update([
                'status' => $statusStr,
                'zone_id' => null,
            ]);

            // If sold (status == 0) and has price > 0, auto-insert into financial records
            $price = (double)($request->price ?? 0);
            if ((int)$request->status === 0 && $price > 0) {
                $cullDate = Carbon::parse($request->cull_date)->format('Y-m-d');
                $lastFR = FinancialRecord::where('financial_record_id', 'LIKE', 'FR%')
                    ->whereRaw('financial_record_id REGEXP "^FR[0-9]+$"')
                    ->orderByRaw('CAST(SUBSTRING(financial_record_id, 3) AS UNSIGNED) DESC')
                    ->first();
                $nextFRNum = $lastFR ? ((int)substr($lastFR->financial_record_id, 2)) + 1 : 1;
                $frId = 'FR' . str_pad($nextFRNum, 3, '0', STR_PAD_LEFT);

                FinancialRecord::create([
                    'financial_record_id' => $frId,
                    'farm_id' => $cow->farm_id,
                    'title' => "ขายวัว หมายเลข " . ($cow->tag_number ?? $cow->cow_id),
                    'trans_type' => 'income',
                    'category' => 'ขายวัว',
                    'related_cow_id' => $cow->cow_id,
                    'amount' => $price,
                    'transaction_date' => $cullDate,
                    'notes' => "ระบบบันทึกรายรับอัตโนมัติจากการคัดทิ้งขายวัว: " . ($request->note ?? ''),
                ]);
            }

            // If delete_appointments is requested, clean up appointments for this cow
            if ($request->boolean('delete_appointments')) {
                $this->removeCowAppointments($cow);
            }

            return response()->json($record, 201);
        });
    }

    /**
     * Remove appointments for a specific cow:
     * - If single-cow appointment: delete completely and clear related notification.
     * - If group appointment (with group_id): delete this cow's record in the group.
     *   If this was the only cow left in the group, the group is now gone.
     */
    private function removeCowAppointments(Cow $cow)
    {
        $identifiers = array_unique(array_filter([
            (string)$cow->id,
            (string)$cow->cow_id,
            (string)$cow->tag_number,
            (string)$cow->name,
        ]));

        $appts = HealthAppointment::whereIn('cow_id', $identifiers)->get();

        foreach ($appts as $appt) {
            $realId = preg_replace('/^(HA-)+/', '', $appt->health_appointment_id);
            Notification::where('message', 'like', "%appt_{$realId}%")->delete();
            $appt->delete();
        }
    }

    public function show($id)
    {
        return response()->json(CullingRecord::with('cow')->findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $record = CullingRecord::findOrFail($id);
        
        return DB::transaction(function () use ($request, $record) {
            $record->update($request->all());
            
            // Re-sync cow status if status changed
            if ($request->has('status')) {
                $cow = Cow::findOrFail($record->cow_id);
                $statusStr = 'normal';
                switch ((int)$request->status) {
                    case 0:
                        $statusStr = 'sold';
                        break;
                    case 1:
                        $statusStr = 'deceased';
                        break;
                    case 2:
                        $statusStr = 'removed';
                        break;
                }
                $cow->update(['status' => $statusStr]);
            }
            
            return response()->json($record);
        });
    }

    public function destroy($id)
    {
        $record = CullingRecord::findOrFail($id);

        DB::transaction(function () use ($record) {
            // Restore cow status to normal
            $cow = Cow::find($record->cow_id);
            if ($cow) {
                $cow->update(['status' => 'normal']);
            }

            // Delete automatic financial records related to this culling sale
            FinancialRecord::where('related_cow_id', $record->cow_id)
                ->where('trans_type', 'income')
                ->where('category', 'ขายวัว')
                ->delete();

            $record->delete();
        });

        return response()->json(null, 204);
    }
}
