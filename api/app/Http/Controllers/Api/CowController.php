<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cow;
use App\Models\Farm;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class CowController extends Controller
{
    public function index(Request $request)
    {
        $user = Auth::user();
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $query = Cow::query()->whereIn('farm_id', $userFarmIds)
            ->where(function ($q) {
                $q->whereNotIn('status', ['sold', 'deceased', 'removed'])
                  ->orWhereNull('status');
            });

        // Allow specific farm filtering if provided
        if ($request->has('farm_id')) {
            $query->where('farm_id', $request->farm_id);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $user = Auth::user();
        
        // Ensure the cow is assigned to a farm owned by the user
        $farmId = $request->farm_id;
        $ownsFarm = Farm::where('farm_id', $farmId)->where('email', $user->email)->exists();
        
        if (!$ownsFarm) {
            return response()->json(['message' => 'Unauthorized or farm not found'], 403);
        }

        $data = $request->all();

        if (isset($data['cow_type_id']) && !empty($data['cow_type_id'])) {
            \App\Models\CowType::firstOrCreate(
                ['cow_type_id' => $data['cow_type_id']],
                ['cow_type_name' => $data['cow_type_id'] == 'T004' ? 'ลูกวัว' : $data['cow_type_id']]
            );
        }

        // Generate unique cow_id (max 10 chars)
        $data['cow_id'] = 'C-' . substr(md5(uniqid(mt_rand(), true)), 0, 8);

        $cow = Cow::create($data);
        return response()->json($cow, 201);
    }

    public function show($id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $cow = Cow::where('cow_id', $id)
                  ->whereIn('farm_id', $userFarmIds)
                  ->firstOrFail();

        return response()->json($cow);
    }

    public function update(Request $request, $id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $cow = Cow::where('cow_id', $id)
                  ->whereIn('farm_id', $userFarmIds)
                  ->firstOrFail();

        $cow->update($request->all());
        return response()->json($cow);
    }

    public function destroy($id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $cow = Cow::where('cow_id', $id)
                  ->whereIn('farm_id', $userFarmIds)
                  ->firstOrFail();
                  
        $cow->delete();
        return response()->json(null, 204);
    }
}
