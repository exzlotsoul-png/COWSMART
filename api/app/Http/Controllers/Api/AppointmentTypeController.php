<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppointmentType;
use Illuminate\Http\Request;

class AppointmentTypeController extends Controller
{
    public function index()
    {
        return response()->json(AppointmentType::orderBy('id')->get());
    }

    public function store(Request $request)
    {
        $data = AppointmentType::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(AppointmentType::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = AppointmentType::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        AppointmentType::destroy($id);
        return response()->json(null, 204);
    }
}
