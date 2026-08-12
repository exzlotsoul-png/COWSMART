<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FeedingRecord;
use App\Models\Farm;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class FeedingRecordController extends Controller
{
    public function index(Request $request)
    {
        $user = Auth::user();
        $query = FeedingRecord::query();

        if ($request->has('farm_id') && !empty($request->farm_id)) {
            $query->where('farm_id', $request->farm_id);
        } elseif ($user) {
            $userFarmIds = Farm::where('email', $user->email)->pluck('farm_id');
            $query->whereIn('farm_id', $userFarmIds);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $data = FeedingRecord::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(FeedingRecord::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = FeedingRecord::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        FeedingRecord::destroy($id);
        return response()->json(null, 204);
    }
}
