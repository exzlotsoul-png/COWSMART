<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CullingRecord;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\FinancialRecord;
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
                    
                    if (empty($rData['culling_record_id'])) {
                        $rData['culling_record_id'] = 'CL-' . substr(md5(uniqid(mt_rand(), true)), 0, 7);
                    }

                    // Create culling record
                    $record = CullingRecord::create($rData);
                    $createdRecords[] = $record;

                    // Update cow status
                    $cow = Cow::findOrFail($rData['cow_id']);
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
                    $cow->update(['status' => $statusStr]);

                    // If sold (status == 0) and has price > 0, auto-insert into financial records
                    $price = (double)($rData['price'] ?? 0);
                    if ((int)$rData['status'] === 0 && $price > 0) {
                        $cullDate = Carbon::parse($rData['cull_date'])->format('Y-m-d');
                        FinancialRecord::create([
                            'financial_record_id' => 'FR-' . substr(md5(uniqid(mt_rand(), true)), 0, 7),
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
                $data['culling_record_id'] = 'CL-' . substr(md5(uniqid(mt_rand(), true)), 0, 7);
            }

            // Create culling record
            $record = CullingRecord::create($data);

            // Update cow status
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
            $cow->update(['status' => $statusStr]);

            // If sold (status == 0) and has price > 0, auto-insert into financial records
            $price = (double)($request->price ?? 0);
            if ((int)$request->status === 0 && $price > 0) {
                $cullDate = Carbon::parse($request->cull_date)->format('Y-m-d');
                FinancialRecord::create([
                    'financial_record_id' => 'FR-' . substr(md5(uniqid(mt_rand(), true)), 0, 7),
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

            return response()->json($record, 201);
        });
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
