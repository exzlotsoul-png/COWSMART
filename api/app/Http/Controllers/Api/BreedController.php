<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Breed;
use Illuminate\Http\Request;

class BreedController extends Controller
{
    public function index()
    {
        return response()->json(Breed::all());
    }

    public function store(Request $request)
    {
        $data = Breed::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(Breed::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = Breed::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        Breed::destroy($id);
        return response()->json(null, 204);
    }
}
