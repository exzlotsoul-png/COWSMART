<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BreedingRecord;
use Illuminate\Http\Request;

class BreedingRecordController extends Controller
{
    public function index(Request $request)
    {
        $query = BreedingRecord::query();
        if ($request->has('cow_id')) {
            $query->where('dam_id', $request->cow_id);
        }
        return response()->json($query->orderBy('created_at', 'desc')->get());
    }

    public function store(Request $request)
    {
        $data = $request->all();
        if (empty($data['breeding_record_id'])) {
            $data['breeding_record_id'] = 'BR-' . substr(md5(uniqid(mt_rand(), true)), 0, 7);
        }
        $record = BreedingRecord::create($data);
        return response()->json($record, 201);
    }

    public function show($id)
    {
        return response()->json(BreedingRecord::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = BreedingRecord::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        BreedingRecord::destroy($id);
        return response()->json(null, 204);
    }
}
