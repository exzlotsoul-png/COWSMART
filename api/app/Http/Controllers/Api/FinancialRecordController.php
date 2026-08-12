<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FinancialRecord;
use App\Models\Farm;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class FinancialRecordController extends Controller
{
    public function index(Request $request)
    {
        $user = Auth::user();
        $query = FinancialRecord::query();

        if ($request->has('farm_id') && !empty($request->farm_id)) {
            $query->where('farm_id', $request->farm_id);
        } elseif ($user) {
            $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');
            $query->whereIn('farm_id', $userFarmIds);
        }

        return response()->json($query->orderBy('transaction_date', 'desc')->get());
    }

    public function store(Request $request)
    {
        $payload = $request->all();
        if (empty($payload['financial_record_id'])) {
            $lastFR = FinancialRecord::where('financial_record_id', 'LIKE', 'FR%')
                ->whereRaw('financial_record_id REGEXP "^FR[0-9]+$"')
                ->orderByRaw('CAST(SUBSTRING(financial_record_id, 3) AS UNSIGNED) DESC')
                ->first();
            $nextFRNum = $lastFR ? ((int)substr($lastFR->financial_record_id, 2)) + 1 : 1;
            $payload['financial_record_id'] = 'FR' . str_pad($nextFRNum, 6, '0', STR_PAD_LEFT);
        }

        $data = FinancialRecord::create($payload);
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(FinancialRecord::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = FinancialRecord::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        FinancialRecord::destroy($id);
        return response()->json(null, 204);
    }
}
