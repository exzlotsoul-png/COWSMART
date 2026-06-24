<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HealthAppointment;
use Illuminate\Http\Request;

class HealthAppointmentController extends Controller
{
    public function index()
    {
        return response()->json(HealthAppointment::all());
    }

    public function store(Request $request)
    {
        $data = HealthAppointment::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(HealthAppointment::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = HealthAppointment::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        HealthAppointment::destroy($id);
        return response()->json(null, 204);
    }
}
