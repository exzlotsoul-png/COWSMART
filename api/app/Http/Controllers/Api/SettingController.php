<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use Illuminate\Http\Request;

class SettingController extends Controller
{
    public function index()
    {
        return response()->json(Setting::all());
    }

    public function store(Request $request)
    {
        $data = Setting::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(Setting::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = Setting::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        Setting::destroy($id);
        return response()->json(null, 204);
    }
}
