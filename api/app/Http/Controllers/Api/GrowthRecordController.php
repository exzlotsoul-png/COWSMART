<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GrowthRecord;
use App\Models\Cow;
use App\Models\Farm;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class GrowthRecordController extends Controller
{
    public function index(Request $request)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');
        $userCowIds = Cow::whereIn('farm_id', $userFarmIds)->pluck('cow_id');

        $query = GrowthRecord::query()->whereIn('cow_id', $userCowIds);

        if ($request->has('cow_id')) {
            $query->where('cow_id', $request->cow_id);
        }

        return response()->json($query->orderBy('record_date', 'desc')->get());
    }

    public function store(Request $request)
    {
        $user = Auth::user();
        $cowId = $request->cow_id;
        
        // Verify user owns the cow
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');
        $ownsCow = Cow::where('cow_id', $cowId)->whereIn('farm_id', $userFarmIds)->exists();
        
        if (!$ownsCow) {
            return response()->json(['message' => 'Unauthorized or cow not found'], 403);
        }

        $data = $request->all();
        // Generate unique growth_records_id (max 10 chars)
        $data['growth_records_id'] = 'G-' . substr(md5(uniqid(mt_rand(), true)), 0, 8);

        $record = GrowthRecord::create($data);
        return response()->json($record, 201);
    }

    public function show($id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');
        $userCowIds = Cow::whereIn('farm_id', $userFarmIds)->pluck('cow_id');

        $record = GrowthRecord::where('growth_records_id', $id)
                              ->whereIn('cow_id', $userCowIds)
                              ->firstOrFail();

        return response()->json($record);
    }

    public function update(Request $request, $id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');
        $userCowIds = Cow::whereIn('farm_id', $userFarmIds)->pluck('cow_id');

        $record = GrowthRecord::where('growth_records_id', $id)
                              ->whereIn('cow_id', $userCowIds)
                              ->firstOrFail();

        $record->update($request->all());
        return response()->json($record);
    }

    public function destroy($id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');
        $userCowIds = Cow::whereIn('farm_id', $userFarmIds)->pluck('cow_id');

        $record = GrowthRecord::where('growth_records_id', $id)
                              ->whereIn('cow_id', $userCowIds)
                              ->firstOrFail();
                  
        $record->delete();
        return response()->json(null, 204);
    }
}
