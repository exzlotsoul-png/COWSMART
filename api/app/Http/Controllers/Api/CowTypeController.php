<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CowType;
use Illuminate\Http\Request;

class CowTypeController extends Controller
{
    public function index()
    {
        return response()->json(CowType::all());
    }

    public function store(Request $request)
    {
        $data = CowType::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(CowType::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = CowType::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        CowType::destroy($id);
        return response()->json(null, 204);
    }
}
