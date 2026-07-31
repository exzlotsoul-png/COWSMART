<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HealthAppointment;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\Notification;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class HealthAppointmentController extends Controller
{
    public function index(Request $request)
    {
        $query = HealthAppointment::query();
        if ($request->has('farm_id')) {
            $farmCows = Cow::where('farm_id', $request->farm_id)->get();
            $cowIds = [];
            foreach ($farmCows as $c) {
                if ($c->id) $cowIds[] = (string)$c->id;
                if ($c->cow_id) $cowIds[] = (string)$c->cow_id;
                if ($c->tag_number) $cowIds[] = (string)$c->tag_number;
                if ($c->name) $cowIds[] = (string)$c->name;
            }
            $query->whereIn('cow_id', array_unique(array_filter($cowIds)));
        }
        $appts = $query->get();
        return response()->json($appts);
    }

    public function store(Request $request)
    {
        $data = $request->all();
        if (empty($data['health_appointment_id'])) {
            $data['health_appointment_id'] = 'HA-' . substr(md5(uniqid(mt_rand(), true)), 0, 7);
        }
        $appt = HealthAppointment::create($data);
        self::syncNotificationForHealthAppt($appt);
        return response()->json($appt, 201);
    }

    public function show($id)
    {
        return response()->json(HealthAppointment::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $appt = HealthAppointment::findOrFail($id);
        $appt->update($request->all());
        self::syncNotificationForHealthAppt($appt);
        return response()->json($appt);
    }

    public function destroy($id)
    {
        $realId = preg_replace('/^(HA-)+/', '', $id);
        Notification::where('message', 'like', "%[ref:appt_{$realId}]%")->delete();
        HealthAppointment::destroy($id);
        return response()->json(null, 204);
    }

    public static function syncNotificationForHealthAppt(HealthAppointment $appt)
    {
        $realId = preg_replace('/^(HA-)+/', '', $appt->health_appointment_id);
        $refKey = "[ref:appt_{$realId}]";
        $setting = $appt->reminder_setting ?: 'ก่อน 1 วัน';

        if (empty($setting) || $setting === 'ไม่แจ้งเตือน') {
            Notification::where('message', 'like', "%{$refKey}%")->delete();
            return;
        }

        $cow = Cow::find($appt->cow_id) ?? Cow::where('cow_id', $appt->cow_id)->orWhere('tag_number', $appt->cow_id)->first();
        if (!$cow) {
            return;
        }

        $cowName = $cow->name ?: ($cow->tag_number ?: $cow->cow_id);

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

        $apptDt = Carbon::parse($appt->appoint_datetime);
        $notifyDt = $apptDt->copy();

        if (str_contains($setting, '15 นาที')) {
            $notifyDt->subMinutes(15);
        } elseif (str_contains($setting, '1 ชั่วโมง')) {
            $notifyDt->subHours(1);
        } elseif (str_contains($setting, '1 วัน')) {
            $notifyDt->subDays(1);
        } elseif (str_contains($setting, '3 วัน')) {
            $notifyDt->subDays(3);
        } elseif (str_contains($setting, '7 วัน')) {
            $notifyDt->subDays(7);
        }

        $descText = $appt->description ? "\n{$appt->description}" : '';
        $title = "นัดหมายสุขภาพ: {$cowName}";
        $message = "{$cowName} มีนัดหมายตรวจสุขภาพ/ฉีดวัคซีน/ถ่ายพยาธิ วันที่ {$apptDt->format('d/m/Y H:i')}{$descText} {$refKey}";

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
    }
}
