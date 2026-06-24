<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FinancialRecord;
use Illuminate\Http\Request;

class FinancialRecordController extends Controller
{
    public function index()
    {
        return response()->json(FinancialRecord::all());
    }

    public function store(Request $request)
    {
        $data = FinancialRecord::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(FinancialRecord::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = FinancialRecord::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        FinancialRecord::destroy($id);
        return response()->json(null, 204);
    }
}
