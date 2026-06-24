<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\IssueReport;
use Illuminate\Http\Request;

class IssueReportController extends Controller
{
    public function index()
    {
        return response()->json(IssueReport::all());
    }

    public function store(Request $request)
    {
        $data = IssueReport::create($request->all());
        return response()->json($data, 201);
    }

    public function show($id)
    {
        return response()->json(IssueReport::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = IssueReport::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        IssueReport::destroy($id);
        return response()->json(null, 204);
    }
}
