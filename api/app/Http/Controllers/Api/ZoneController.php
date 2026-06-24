<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Zone;
use App\Models\Farm;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ZoneController extends Controller
{
    public function index(Request $request)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $query = Zone::query()->whereIn('farm_id', $userFarmIds)->withCount('cows');

        if ($request->has('farm_id')) {
            $query->where('farm_id', $request->farm_id);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $user = Auth::user();
        $farmId = $request->farm_id;
        $ownsFarm = Farm::where('farm_id', $farmId)->where('email', $user->email)->exists();
        
        if (!$ownsFarm) {
            return response()->json(['message' => 'Unauthorized or farm not found'], 403);
        }

        $data = $request->all();
        // Auto generate zone_id (max 10 chars)
        $data['zone_id'] = 'Z-' . substr(md5(uniqid(mt_rand(), true)), 0, 8);
        
        $zone = Zone::create($data);
        return response()->json($zone, 201);
    }

    public function show($id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $zone = Zone::where('zone_id', $id)
                    ->whereIn('farm_id', $userFarmIds)
                    ->firstOrFail();

        return response()->json($zone);
    }

    public function update(Request $request, $id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $zone = Zone::where('zone_id', $id)
                    ->whereIn('farm_id', $userFarmIds)
                    ->firstOrFail();

        $zone->update($request->all());
        return response()->json($zone);
    }

    public function destroy($id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $zone = Zone::where('zone_id', $id)
                    ->whereIn('farm_id', $userFarmIds)
                    ->firstOrFail();

        // Check if zone has cows
        if ($zone->cows()->count() > 0) {
            return response()->json([
                'message' => 'ไม่สามารถลบโซนนี้ได้ เนื่องจากมีวัวในโซนนี้อยู่ กรุณาย้ายวัวออกไปโซนอื่นก่อนลบ',
                'status' => 'error'
            ], 400);
        }

        $zone->delete();
        return response()->json([
            'message' => 'ลบโซนสำเร็จ',
            'status' => 'success'
        ], 200);
    }
}
