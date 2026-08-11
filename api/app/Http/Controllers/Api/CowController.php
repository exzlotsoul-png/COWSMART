<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\Zone;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class CowController extends Controller
{
    protected function deleteStorageFile($imageUrl)
    {
        if (empty($imageUrl)) return;
        $path = $imageUrl;
        if (preg_match('/storage\/(.+)$/', $path, $matches)) {
            $path = $matches[1];
        } else {
            $path = ltrim($path, '/');
            $path = preg_replace('/^storage\//', '', $path);
        }

        if ($path && !str_starts_with($path, 'http') && Storage::disk('public')->exists($path)) {
            Storage::disk('public')->delete($path);
        }
    }

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

        // Sanitize foreign keys
        foreach (['zone_id', 'sire_id', 'dam_id', 'breed_id'] as $fk) {
            if (array_key_exists($fk, $data)) {
                if (empty($data[$fk]) || $data[$fk] === '' || $data[$fk] === 'null') {
                    $data[$fk] = null;
                }
            }
        }
        if (!empty($data['zone_id'])) {
            $exists = Zone::where('zone_id', $data['zone_id'])->exists();
            if (!$exists) {
                $data['zone_id'] = null;
            }
        }

        if (isset($data['cow_type_id']) && !empty($data['cow_type_id'])) {
            \App\Models\CowType::firstOrCreate(
                ['cow_type_id' => $data['cow_type_id']],
                ['cow_type_name' => $data['cow_type_id'] == 'T004' ? 'ลูกวัว' : $data['cow_type_id']]
            );
        }

        // Generate sequential cow_id (e.g. C001, C002, ...)
        if (empty($data['cow_id']) || str_contains($data['cow_id'], 'C-')) {
            $lastCow = Cow::where('cow_id', 'LIKE', 'C%')
                ->whereRaw('cow_id REGEXP "^C[0-9]+$"')
                ->orderByRaw('CAST(SUBSTRING(cow_id, 2) AS UNSIGNED) DESC')
                ->first();

            $nextNum = 1;
            if ($lastCow) {
                $numPart = (int) substr($lastCow->cow_id, 1);
                $nextNum = $numPart + 1;
            }
            $data['cow_id'] = 'C' . str_pad($nextNum, 3, '0', STR_PAD_LEFT);
        }

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

        $data = $request->all();

        // Check if image_url is changing or deleted
        if (array_key_exists('image_url', $data) && $cow->image_url !== $data['image_url']) {
            $this->deleteStorageFile($cow->image_url);
        }

        // Sanitize foreign keys: convert empty strings or non-existent FKs to null
        foreach (['zone_id', 'sire_id', 'dam_id', 'breed_id'] as $fk) {
            if (array_key_exists($fk, $data)) {
                if (empty($data[$fk]) || $data[$fk] === '' || $data[$fk] === 'null') {
                    $data[$fk] = null;
                }
            }
        }

        if (!empty($data['zone_id'])) {
            $exists = Zone::where('zone_id', $data['zone_id'])->exists();
            if (!$exists) {
                $data['zone_id'] = null;
            }
        }

        $cow->update($data);
        return response()->json($cow);
    }

    public function destroy($id)
    {
        $user = Auth::user();
        $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');

        $cow = Cow::where('cow_id', $id)
                  ->whereIn('farm_id', $userFarmIds)
                  ->firstOrFail();
                  
        if ($cow->image_url) {
            $this->deleteStorageFile($cow->image_url);
        }

        $cow->delete();
        return response()->json(null, 204);
    }
}
