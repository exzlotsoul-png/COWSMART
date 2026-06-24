<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CullingRecord;
use App\Models\Cow;
use App\Models\Farm;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class CullingRecordController extends Controller
{
    public function index(Request $request)
    {
        $query = CullingRecord::query();

        if ($request->has('farm_id')) {
            $cowIds = Cow::where('farm_id', $request->farm_id)->pluck('cow_id');
            $query->whereIn('cow_id', $cowIds);
        } elseif ($request->has('cow_id')) {
            $query->where('cow_id', $request->cow_id);
        }

        return response()->json(
            $query->orderBy('cull_date', 'desc')->get()
        );
    }

    public function store(Request $request)
    {
        $data = $request->all();
        if (empty($data['culling_record_id'])) {
            $data['culling_record_id'] = 'CL-' . substr(md5(uniqid(mt_rand(), true)), 0, 7);
        }
        $record = CullingRecord::create($data);
        return response()->json($record, 201);
    }

    public function show($id)
    {
        return response()->json(CullingRecord::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $data = CullingRecord::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        CullingRecord::destroy($id);
        return response()->json(null, 204);
    }
}
