<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Farm;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class FarmController extends Controller
{
    public function index()
    {
        $user = Auth::user();
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }
        return response()->json(Farm::where('email', $user->email)->get());
    }

    public function store(Request $request)
    {
        $user = Auth::user();
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }
        $request->validate([
            'name' => 'required|string|max:255',
            'address' => 'required|string',
            'image_url' => 'nullable|string',
        ]);
        
        $data = $request->all();
        $data['email'] = $user->email;
        
        $farm = Farm::create($data);
        return response()->json($farm, 201);
    }

    public function show($id)
    {
        $user = Auth::user();
        $farm = Farm::where('farm_id', $id)
                    ->where('email', $user->email)
                    ->firstOrFail();
                    
        return response()->json($farm);
    }

    public function update(Request $request, $id)
    {
        $user = Auth::user();
        $farm = Farm::where('farm_id', $id)
                    ->where('email', $user->email)
                    ->firstOrFail();
        $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'address' => 'sometimes|required|string',
            'image_url' => 'nullable|string',
        ]);
                    
        $data = $request->all();
        if (array_key_exists('image_url', $data) && $farm->image_url !== $data['image_url'] && $farm->image_url) {
            $oldPath = preg_match('/storage\/(.+)$/', $farm->image_url, $m) ? $m[1] : ltrim($farm->image_url, '/');
            if ($oldPath && !\Illuminate\Support\Str::startsWith($oldPath, 'http') && \Illuminate\Support\Facades\Storage::disk('public')->exists($oldPath)) {
                \Illuminate\Support\Facades\Storage::disk('public')->delete($oldPath);
            }
        }

        $farm->update($data);
        return response()->json($farm);
    }

    public function destroy($id)
    {
        $user = Auth::user();
        $farm = Farm::where('farm_id', $id)
                    ->where('email', $user->email)
                    ->firstOrFail();

        \Illuminate\Support\Facades\DB::transaction(function () use ($farm, $id) {
            // Collect all cow identifiers in this farm
            $cows = \App\Models\Cow::where('farm_id', $id)->get();
            $cowIds = [];
            foreach ($cows as $c) {
                if ($c->image_url) {
                    $cPath = preg_match('/storage\/(.+)$/', $c->image_url, $m) ? $m[1] : ltrim($c->image_url, '/');
                    if ($cPath && !\Illuminate\Support\Str::startsWith($cPath, 'http') && \Illuminate\Support\Facades\Storage::disk('public')->exists($cPath)) {
                        \Illuminate\Support\Facades\Storage::disk('public')->delete($cPath);
                    }
                }
                if ($c->id) $cowIds[] = (string)$c->id;
                if ($c->cow_id) $cowIds[] = (string)$c->cow_id;
                if ($c->tag_number) $cowIds[] = (string)$c->tag_number;
            }
            $cowIds = array_unique(array_filter($cowIds));

            if (!empty($cowIds)) {
                \App\Models\HealthAppointment::whereIn('cow_id', $cowIds)->delete();
                \App\Models\HealthRecord::whereIn('cow_id', $cowIds)->delete();
                \App\Models\BreedingRecord::whereIn('dam_id', $cowIds)->orWhereIn('sire_id', $cowIds)->delete();
                \App\Models\CalvingRecord::whereIn('cow_id', $cowIds)->delete();
                \App\Models\GrowthRecord::whereIn('cow_id', $cowIds)->delete();
                \App\Models\FeedingRecord::whereIn('cow_id', $cowIds)->delete();
                \App\Models\CullingRecord::whereIn('cow_id', $cowIds)->delete();
                \App\Models\Cow::where('farm_id', $id)->delete();
            }

            // Delete zones, calendar events, feed inventory, financial records
            \App\Models\Zone::where('farm_id', $id)->delete();
            \App\Models\CalendarEvent::where('farm_id', $id)->delete();
            \App\Models\FeedInventory::where('farm_id', $id)->delete();
            \App\Models\FinancialRecord::where('farm_id', $id)->delete();

            // Delete farm image file if exists locally
            if ($farm->image_url) {
                $fPath = preg_match('/storage\/(.+)$/', $farm->image_url, $m) ? $m[1] : ltrim($farm->image_url, '/');
                if ($fPath && !\Illuminate\Support\Str::startsWith($fPath, 'http') && \Illuminate\Support\Facades\Storage::disk('public')->exists($fPath)) {
                    \Illuminate\Support\Facades\Storage::disk('public')->delete($fPath);
                }
            }

            // Delete farm
            $farm->delete();
        });

        return response()->json(null, 204);
    }
}
