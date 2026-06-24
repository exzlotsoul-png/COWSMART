<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Unit;
use Illuminate\Http\Request;

class UnitController extends Controller
{
    public function index()
    {
        return response()->json(Unit::all());
    }

    public function store(Request $request)
    {
        $data = Unit::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(Unit::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = Unit::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        Unit::destroy($id);
        return response()->json(null, 204);
    }
}
