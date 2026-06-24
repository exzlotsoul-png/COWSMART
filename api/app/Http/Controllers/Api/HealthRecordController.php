<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HealthRecord;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class HealthRecordController extends Controller
{
    public function index(Request $request)
    {
        $query = HealthRecord::query()
            ->leftJoin('diseases', 'health_records.disease_id', '=', 'diseases.disease_id')
            ->leftJoin('medicines', 'health_records.med_id', '=', 'medicines.medicine_id')
            ->leftJoin('vaccines', 'health_records.vac_id', '=', 'vaccines.vaccine_id')
            ->select(
                'health_records.*',
                'diseases.name as disease_name',
                'medicines.name as medicine_name',
                'vaccines.name as vaccine_name'
            );

        // Filter by cow_id if provided
        if ($request->has('cow_id')) {
            $query->where('health_records.cow_id', $request->cow_id);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $record = HealthRecord::create($request->all());
        // Fetch with joined names
        $data = HealthRecord::query()
            ->leftJoin('diseases', 'health_records.disease_id', '=', 'diseases.disease_id')
            ->leftJoin('medicines', 'health_records.med_id', '=', 'medicines.medicine_id')
            ->leftJoin('vaccines', 'health_records.vac_id', '=', 'vaccines.vaccine_id')
            ->select(
                'health_records.*',
                'diseases.name as disease_name',
                'medicines.name as medicine_name',
                'vaccines.name as vaccine_name'
            )
            ->where('health_records.health_record_id', $record->health_record_id)
            ->first();
        return response()->json($data, 201);
    }

    public function show($id)
    {
        $data = HealthRecord::query()
            ->leftJoin('diseases', 'health_records.disease_id', '=', 'diseases.disease_id')
            ->leftJoin('medicines', 'health_records.med_id', '=', 'medicines.medicine_id')
            ->leftJoin('vaccines', 'health_records.vac_id', '=', 'vaccines.vaccine_id')
            ->select(
                'health_records.*',
                'diseases.name as disease_name',
                'medicines.name as medicine_name',
                'vaccines.name as vaccine_name'
            )
            ->where('health_records.health_record_id', $id)
            ->firstOrFail();
        return response()->json($data);
    }

    public function update(Request $request, $id)
    {
        $data = HealthRecord::findOrFail($id);
        $data->update($request->all());
        return response()->json($data);
    }

    public function destroy($id)
    {
        HealthRecord::destroy($id);
        return response()->json(null, 204);
    }
}
