<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Vaccine;
use Illuminate\Http\Request;

class VaccineController extends Controller
{
    public function index()
    {
        return response()->json(Vaccine::all());
    }

    public function store(Request $request)
    {
        $data = Vaccine::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(Vaccine::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = Vaccine::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        Vaccine::destroy($id);
        return response()->json(null, 204);
    }
}
