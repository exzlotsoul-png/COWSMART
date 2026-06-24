<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FeedingRecord;
use Illuminate\Http\Request;

class FeedingRecordController extends Controller
{
    public function index()
    {
        return response()->json(FeedingRecord::all());
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
