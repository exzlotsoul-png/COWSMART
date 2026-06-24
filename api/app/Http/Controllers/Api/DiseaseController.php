<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Disease;
use Illuminate\Http\Request;

class DiseaseController extends Controller
{
    public function index()
    {
        return response()->json(Disease::all());
    }

    public function store(Request $request)
    {
        $data = Disease::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(Disease::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = Disease::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        Disease::destroy($id);
        return response()->json(null, 204);
    }
}
