<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BreedingRecord;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\Notification;
use App\Models\User;
use App\Services\FirebaseService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class BreedingRecordController extends Controller
{
    public function index(Request $request)
    {
        $query = BreedingRecord::query();
        if ($request->has('cow_id')) {
            $cow = \App\Models\Cow::find($request->cow_id);
            if ($cow && $cow->gender === 'M') {
                $query->where('sire_id', $request->cow_id);
            } else {
                $query->where('dam_id', $request->cow_id);
            }
        }
        $records = $query->orderBy('created_at', 'desc')->get();
        foreach ($records as $record) {
            self::syncNotificationForBreedingRecord($record);
        }
        return response()->json($records);
    }

    public function store(Request $request)
    {
        $data = $request->all();
        // Auto-calculate expected calving date (~283 days) if mating_date is present and expected_calving is missing
        if (!empty($data['mating_date']) && empty($data['expected_calving'])) {
            $matingDt = Carbon::parse($data['mating_date']);
            $data['expected_calving'] = $matingDt->addDays(283)->format('Y-m-d');
        }
        $record = BreedingRecord::create($data);
        self::syncNotificationForBreedingRecord($record);
        return response()->json($record, 201);
    }

    public function show($id)
    {
        return response()->json(BreedingRecord::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $record = BreedingRecord::findOrFail($id);
        $data = $request->all();
        // Auto-calculate expected calving date if mating_date changed or set, and expected_calving not explicitly set or empty
        if (!empty($data['mating_date']) && empty($data['expected_calving']) && empty($record->expected_calving)) {
            $matingDt = Carbon::parse($data['mating_date']);
            $data['expected_calving'] = $matingDt->addDays(283)->format('Y-m-d');
        }
        // If pregnancy result is not pregnant or aborted, clear expected_calving
        if (isset($data['pregnancy_result']) && in_array($data['pregnancy_result'], ['ไม่ท้อง', 'ไม่ตั้งท้อง', 'แท้ง', 'แท้งลูก'])) {
            $data['expected_calving'] = null;
        }
        $record->update($data);
        self::syncNotificationForBreedingRecord($record);
        return response()->json($record);
    }

    public function destroy($id)
    {
        Notification::where('message', 'like', "%[ref:calving_{$id}]%")->delete();
        BreedingRecord::destroy($id);
        return response()->json(null, 204);
    }

    public static function syncNotificationForBreedingRecord(BreedingRecord $record)
    {
        $refKey = "[ref:calving_{$record->breeding_record_id}]";
        if (empty($record->expected_calving) || !empty($record->calving_date)) {
            Notification::where('message', 'like', "%{$refKey}%")->delete();
            return;
        }

        $setting = $record->reminder_setting ?: 'ก่อน 7 วัน';
        if (empty($setting) || $setting === 'ไม่แจ้งเตือน') {
            Notification::where('message', 'like', "%{$refKey}%")->delete();
            return;
        }

        $searchVal = trim((string)$record->dam_id);
        $cow = Cow::find($searchVal) ?? Cow::where('id', $searchVal)
            ->orWhere('cow_id', $searchVal)
            ->orWhere('tag_number', $searchVal)
            ->orWhere('name', $searchVal)
            ->first();
            
        $cowName = $cow ? ($cow->name ?: ($cow->tag_number ?: $cow->cow_id)) : (string)$record->dam_id;

        $userEmail = null;
        if ($cow->farm_id) {
            $farm = Farm::find($cow->farm_id);
            if ($farm && $farm->email) {
                $userEmail = $farm->email;
            }
        }
        if (!$userEmail && Auth::check()) {
            $userEmail = Auth::user()->email;
        }
        if (!$userEmail) {
            return;
        }

        $calvingDt = Carbon::parse($record->expected_calving)->startOfDay();
        $notifyDt = $calvingDt->copy();

        if (str_contains($setting, '1 วัน')) {
            $notifyDt->subDays(1);
        } elseif (str_contains($setting, '3 วัน')) {
            $notifyDt->subDays(3);
        } elseif (str_contains($setting, '1 สัปดาห์') || str_contains($setting, '7 วัน')) {
            $notifyDt->subDays(7);
        } elseif (str_contains($setting, '14 วัน')) {
            $notifyDt->subDays(14);
        } elseif (str_contains($setting, '30 วัน')) {
            $notifyDt->subDays(30);
        }

        $title = "วัวใกล้คลอด: {$cowName}";
        $message = "{$cowName} คาดว่าจะคลอด วันที่ {$calvingDt->format('d/m/Y')} {$refKey}";

        $existing = Notification::where('email', $userEmail)
            ->where('message', 'like', "%{$refKey}%")
            ->first();

        if ($existing) {
            $existing->update([
                'title' => $title,
                'message' => $message,
                'notify_datetime' => $notifyDt,
                'is_read' => 0,
            ]);
        } else {
            Notification::create([
                'id' => 'N-' . substr(md5(uniqid(mt_rand(), true)), 0, 8),
                'email' => $userEmail,
                'title' => $title,
                'message' => $message,
                'notify_datetime' => $notifyDt,
                'is_read' => 0,
            ]);
        }

        // Send live FCM push outside app if reminder time has arrived or is due now
        if (Carbon::now()->greaterThanOrEqualTo($notifyDt->copy()->subMinutes(1))) {
            $user = User::where('email', $userEmail)->first();
            if ($user && !empty($user->fcm_token)) {
                $pushBody = "{$cowName} คาดว่าจะคลอด วันที่ {$calvingDt->format('d/m/Y')}";
                FirebaseService::sendPushNotification(
                    $user->fcm_token,
                    $title,
                    $pushBody,
                    ['type' => 'calving', 'cow_id' => (string)$cow->cow_id]
                );
            }
        }
    }
}
