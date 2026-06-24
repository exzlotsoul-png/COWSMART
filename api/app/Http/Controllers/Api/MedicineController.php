<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Medicine;
use Illuminate\Http\Request;

class MedicineController extends Controller
{
    public function index()
    {
        return response()->json(Medicine::all());
    }

    public function store(Request $request)
    {
        $data = Medicine::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(Medicine::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = Medicine::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        Medicine::destroy($id);
        return response()->json(null, 204);
    }
}
