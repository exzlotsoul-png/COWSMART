<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HealthRecord;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class HealthRecordController extends Controller
{
    private function getJoinedQuery()
    {
        return DB::table('health_records')
            ->leftJoin('diseases', 'health_records.disease_id', '=', 'diseases.disease_id')
            ->leftJoin('medicines', 'health_records.med_id', '=', 'medicines.medicine_id')
            ->leftJoin('vaccines', 'health_records.vac_id', '=', 'vaccines.vaccine_id')
            ->select(
                'health_records.*',
                'diseases.name as disease_name',
                'medicines.name as medicine_name',
                'vaccines.name as vaccine_name'
            );
    }

    private function attachPivotDetails($recordData)
    {
        if (!$recordData) return null;

        $recordId = is_object($recordData) ? $recordData->health_record_id : $recordData['health_record_id'];

        // Get medicines from junction table
        $meds = DB::table('health_record_medicines')
            ->join('medicines', 'health_record_medicines.medicine_id', '=', 'medicines.medicine_id')
            ->where('health_record_medicines.health_record_id', $recordId)
            ->select('medicines.medicine_id', 'medicines.name')
            ->get();

        // Get vaccines from junction table
        $vacs = DB::table('health_record_vaccines')
            ->join('vaccines', 'health_record_vaccines.vaccine_id', '=', 'vaccines.vaccine_id')
            ->where('health_record_vaccines.health_record_id', $recordId)
            ->select('vaccines.vaccine_id', 'vaccines.name')
            ->get();

        $medIds = $meds->pluck('medicine_id')->toArray();
        $medNames = $meds->pluck('name')->toArray();
        $vacIds = $vacs->pluck('vaccine_id')->toArray();
        $vacNames = $vacs->pluck('name')->toArray();

        // If junction table has data, override/supplement med_id / vac_id and names
        if (is_object($recordData)) {
            $recordData->med_ids = !empty($medIds) ? $medIds : ($recordData->med_id ? [$recordData->med_id] : []);
            $recordData->vac_ids = !empty($vacIds) ? $vacIds : ($recordData->vac_id ? [$recordData->vac_id] : []);
            
            if (!empty($medNames)) {
                $recordData->medicine_name = implode(', ', $medNames);
            }
            if (!empty($vacNames)) {
                $recordData->vaccine_name = implode(', ', $vacNames);
            }
            if (isset($recordData->images)) {
                $imgs = is_string($recordData->images) ? (json_decode($recordData->images, true) ?? []) : (is_array($recordData->images) ? $recordData->images : []);
                $recordData->images = array_map(function($img) {
                    if (str_starts_with($img, 'http://') || str_starts_with($img, 'https://')) {
                        return $img;
                    }
                    return asset('storage/' . ltrim($img, '/'));
                }, $imgs);
            }
        } else {
            $recordData['med_ids'] = !empty($medIds) ? $medIds : ($recordData['med_id'] ? [$recordData['med_id']] : []);
            $recordData['vac_ids'] = !empty($vacIds) ? $vacIds : ($recordData['vac_id'] ? [$recordData['vac_id']] : []);
            if (!empty($medNames)) {
                $recordData['medicine_name'] = implode(', ', $medNames);
            }
            if (!empty($vacNames)) {
                $recordData['vaccine_name'] = implode(', ', $vacNames);
            }
            if (isset($recordData['images'])) {
                $imgs = is_string($recordData['images']) ? (json_decode($recordData['images'], true) ?? []) : (is_array($recordData['images']) ? $recordData['images'] : []);
                $recordData['images'] = array_map(function($img) {
                    if (str_starts_with($img, 'http://') || str_starts_with($img, 'https://')) {
                        return $img;
                    }
                    return asset('storage/' . ltrim($img, '/'));
                }, $imgs);
            }
        }

        return $recordData;
    }

    public function index(Request $request)
    {
        $query = $this->getJoinedQuery();

        if ($request->has('cow_id')) {
            $query->where('health_records.cow_id', $request->cow_id);
        }

        $records = $query->orderBy('health_records.record_date', 'desc')->get();

        foreach ($records as $record) {
            $this->attachPivotDetails($record);
        }

        return response()->json($records);
    }

    public function store(Request $request)
    {
        $payload = $request->except(['med_ids', 'vac_ids']);
        
        // Handle backward compatibility for med_id and vac_id from arrays
        if ($request->has('med_ids') && is_array($request->med_ids) && count($request->med_ids) > 0) {
            $payload['med_id'] = $request->med_ids[0];
        }
        if ($request->has('vac_ids') && is_array($request->vac_ids) && count($request->vac_ids) > 0) {
            $payload['vac_id'] = $request->vac_ids[0];
        }

        // Handle images array to json string, converting full URLs to relative path
        if ($request->has('images') && is_array($request->images)) {
            $cleaned = array_map(function($img) {
                if (preg_match('/storage\/(.+)$/', $img, $matches)) {
                    return $matches[1];
                }
                return $img;
            }, $request->images);
            $payload['images'] = json_encode(array_slice($cleaned, 0, 3));
        }

        $record = HealthRecord::create($payload);

        // Sync medicines in junction table
        if ($request->has('med_ids') && is_array($request->med_ids)) {
            foreach ($request->med_ids as $medId) {
                if ($medId) {
                    DB::table('health_record_medicines')->insert([
                        'health_record_id' => $record->health_record_id,
                        'medicine_id' => $medId,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        // Sync vaccines in junction table
        if ($request->has('vac_ids') && is_array($request->vac_ids)) {
            foreach ($request->vac_ids as $vacId) {
                if ($vacId) {
                    DB::table('health_record_vaccines')->insert([
                        'health_record_id' => $record->health_record_id,
                        'vaccine_id' => $vacId,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        $data = $this->getJoinedQuery()
            ->where('health_records.health_record_id', $record->health_record_id)
            ->first();

        $this->attachPivotDetails($data);

        return response()->json($data, 201);
    }

    public function show($id)
    {
        $data = $this->getJoinedQuery()
            ->where('health_records.health_record_id', $id)
            ->firstOrFail();

        $this->attachPivotDetails($data);

        return response()->json($data);
    }

    public function update(Request $request, $id)
    {
        $record = HealthRecord::findOrFail($id);
        $payload = $request->except(['med_ids', 'vac_ids']);

        if ($request->has('med_ids') && is_array($request->med_ids) && count($request->med_ids) > 0) {
            $payload['med_id'] = $request->med_ids[0];
        }
        if ($request->has('vac_ids') && is_array($request->vac_ids) && count($request->vac_ids) > 0) {
            $payload['vac_id'] = $request->vac_ids[0];
        }

        if ($request->has('images') && is_array($request->images)) {
            $oldImgs = is_string($record->images) ? (json_decode($record->images, true) ?? []) : (is_array($record->images) ? $record->images : []);
            $cleaned = array_map(function($img) {
                if (preg_match('/storage\/(.+)$/', $img, $matches)) {
                    return $matches[1];
                }
                return $img;
            }, $request->images);
            $newImgs = array_slice($cleaned, 0, 3);

            // Delete images that are no longer present in the updated list
            foreach ($oldImgs as $oldImg) {
                $oldPath = preg_match('/storage\/(.+)$/', $oldImg, $m) ? $m[1] : ltrim($oldImg, '/');
                if ($oldPath && !in_array($oldPath, $newImgs) && !str_starts_with($oldPath, 'http')) {
                    Storage::disk('public')->delete($oldPath);
                }
            }

            $payload['images'] = json_encode($newImgs);
        }

        $record->update($payload);

        if ($request->has('med_ids') && is_array($request->med_ids)) {
            DB::table('health_record_medicines')->where('health_record_id', $id)->delete();
            foreach ($request->med_ids as $medId) {
                if ($medId) {
                    DB::table('health_record_medicines')->insert([
                        'health_record_id' => $id,
                        'medicine_id' => $medId,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        if ($request->has('vac_ids') && is_array($request->vac_ids)) {
            DB::table('health_record_vaccines')->where('health_record_id', $id)->delete();
            foreach ($request->vac_ids as $vacId) {
                if ($vacId) {
                    DB::table('health_record_vaccines')->insert([
                        'health_record_id' => $id,
                        'vaccine_id' => $vacId,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        $data = $this->getJoinedQuery()
            ->where('health_records.health_record_id', $id)
            ->first();

        $this->attachPivotDetails($data);

        return response()->json($data);
    }

    public function destroy($id)
    {
        $record = HealthRecord::find($id);
        if ($record && $record->images) {
            $imgs = is_string($record->images) ? (json_decode($record->images, true) ?? []) : (is_array($record->images) ? $record->images : []);
            foreach ($imgs as $img) {
                if (preg_match('/storage\/(.+)$/', $img, $matches)) {
                    $path = $matches[1];
                } else {
                    $path = ltrim($img, '/');
                }
                if ($path && !str_starts_with($path, 'http')) {
                    Storage::disk('public')->delete($path);
                }
            }
        }

        DB::table('health_record_medicines')->where('health_record_id', $id)->delete();
        DB::table('health_record_vaccines')->where('health_record_id', $id)->delete();
        HealthRecord::destroy($id);
        return response()->json(null, 204);
    }
}
