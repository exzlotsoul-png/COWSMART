<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CheckupType;
use Illuminate\Http\Request;

class CheckupTypeController extends Controller
{
    public function index()
    {
        return response()->json(CheckupType::all());
    }

    public function store(Request $request)
    {
        $data = CheckupType::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(CheckupType::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = CheckupType::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        CheckupType::destroy($id);
        return response()->json(null, 204);
    }
}
