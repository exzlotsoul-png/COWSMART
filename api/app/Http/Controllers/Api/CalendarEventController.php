<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CalendarEvent;
use App\Models\HealthAppointment;
use App\Models\BreedingRecord;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\Notification;
use App\Models\User;
use App\Services\FirebaseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Carbon\Carbon;

class CalendarEventController extends Controller
{
    public function index(Request $request)
    {
        $farmId = $request->get('farm_id');

        // 1. Fetch manual calendar events
        $query = CalendarEvent::query();
        if ($farmId) {
            $query->where('farm_id', $farmId);
        }
        $manualEvents = $query->orderBy('event_datetime')->get()->map(function ($e) {
            $data = $e->toArray();
            $data['event_type'] = 'general';
            return $data;
        })->toArray();

        if (!$farmId) {
            return response()->json($manualEvents);
        }

        // Get all cows for this farm and collect all possible identifiers
        $farmCows = Cow::where('farm_id', $farmId)->get();
        $farmCowIds = [];
        foreach ($farmCows as $c) {
            if ($c->id) $farmCowIds[] = (string)$c->id;
            if ($c->cow_id) $farmCowIds[] = (string)$c->cow_id;
            if ($c->tag_number) $farmCowIds[] = (string)$c->tag_number;
            if ($c->name) $farmCowIds[] = (string)$c->name;
        }
        $farmCowIds = array_unique(array_filter($farmCowIds));

        // 2. Synthesize Health Appointments into calendar events (only for cows in this farm)
        $healthEvents = [];
        if (!empty($farmCowIds)) {
            $appts = HealthAppointment::whereNotNull('appoint_datetime')
                ->whereIn('cow_id', $farmCowIds)
                ->get();

            // Separate grouped and ungrouped appointments
            $grouped = [];
            $ungrouped = [];

            foreach ($appts as $appt) {
                if (!empty($appt->group_id)) {
                    $grouped[$appt->group_id][] = $appt;
                } else {
                    $ungrouped[] = $appt;
                }
            }

            // Process grouped appointments → merge into single calendar event per group
            foreach ($grouped as $groupId => $groupAppts) {
                $cowNames = [];
                $firstAppt = $groupAppts[0];
                $allApptIds = [];

                $cowIds = [];
                foreach ($groupAppts as $appt) {
                    $cow = $this->findCow($appt->cow_id, $farmCows, $farmId);
                    if (!$cow) continue;
                    $cowName = $cow->name ?: ($cow->tag_number ?: $cow->cow_id);
                    $cowNames[] = $cowName;
                    $cowIds[] = (string)($cow->id ?? $cow->cow_id);
                    $allApptIds[] = str_starts_with($appt->health_appointment_id, 'HA-')
                        ? $appt->health_appointment_id
                        : 'HA-' . $appt->health_appointment_id;
                }

                if (empty($cowNames)) continue;

                $dt = Carbon::parse($firstAppt->appoint_datetime)->timezone('Asia/Bangkok')->toIso8601String();
                $calEventId = 'HAG-' . $groupId;

                $cowCount = count($cowNames);
                if ($cowCount <= 3) {
                    $cowDisplay = implode(', ', $cowNames);
                } else {
                    $cowDisplay = implode(', ', array_slice($cowNames, 0, 3)) . ' +' . ($cowCount - 3) . ' ตัว';
                }

                // Clean description: remove trailing ' (X ตัว)' if already present
                $rawDesc = $firstAppt->description ?: 'นัดหมายตรวจสุขภาพ / ฉีดวัคซีน / ถ่ายพยาธิ';
                $cleanDesc = preg_replace('/\s*\(\d+\s*ตัว\)$/u', '', $rawDesc);

                // Derive title from description if formatted as [Type] Title
                $eventTitle = 'นัดหมายสุขภาพ: ' . $cowDisplay;
                if (preg_match('/^\[(.*?)\]\s*(.*)$/u', $cleanDesc, $matches)) {
                    $extractedTitle = trim($matches[2]);
                    if (!empty($extractedTitle)) {
                        $eventTitle = $extractedTitle;
                    }
                }

                $healthEvents[] = [
                    'calendar_event_id' => $calEventId,
                    'farm_id' => $farmId,
                    'title' => $eventTitle,
                    'event_datetime' => $dt,
                    'description' => $cleanDesc . ' (' . $cowCount . ' ตัว)',
                    'reminder_setting' => $firstAppt->reminder_setting ?: 'ก่อน 1 วัน',
                    'cow_id' => null,
                    'event_type' => 'health',
                    '_group_id' => $groupId,
                    '_group_appt_ids' => $allApptIds,
                    '_cow_count' => $cowCount,
                    '_cow_ids' => array_values(array_unique($cowIds)),
                ];
            }

            // Process ungrouped appointments → one event per appointment (existing behavior)
            foreach ($ungrouped as $appt) {
                $cow = $this->findCow($appt->cow_id, $farmCows, $farmId);
                if (!$cow) continue;

                $cowName = $cow->name ?: ($cow->tag_number ?: $cow->cow_id);
                $dt = Carbon::parse($appt->appoint_datetime)->timezone('Asia/Bangkok')->toIso8601String();
                $calEventId = str_starts_with($appt->health_appointment_id, 'HA-')
                    ? $appt->health_appointment_id
                    : 'HA-' . $appt->health_appointment_id;

                $healthEvents[] = [
                    'calendar_event_id' => $calEventId,
                    'farm_id' => $farmId,
                    'title' => 'นัดหมายสุขภาพ: ' . $cowName,
                    'event_datetime' => $dt,
                    'description' => $appt->description ?: 'นัดหมายตรวจสุขภาพ / ฉีดวัคซีน / ถ่ายพยาธิ',
                    'reminder_setting' => $appt->reminder_setting ?: 'ก่อน 1 วัน',
                    'cow_id' => $cow->cow_id,
                    'event_type' => 'health',
                ];
            }
        }

        // 3. Synthesize Expected Calvings into calendar events (only for cows in this farm)
        $breedingEvents = [];
        if (!empty($farmCowIds)) {
            $records = BreedingRecord::where(function ($q) {
                    $q->whereNotNull('expected_calving')->where('expected_calving', '!=', '')
                      ->orWhere(function ($sub) {
                          $sub->whereNotNull('mating_date')->where('mating_date', '!=', '');
                      });
                })
                ->where(function ($q) {
                    $q->whereNull('calving_date')->orWhere('calving_date', '');
                })
                ->where(function ($q) {
                    // Do not show for cows that did not get pregnant or had a miscarriage
                    $q->whereNull('pregnancy_result')
                      ->orWhereNotIn('pregnancy_result', ['ไม่ท้อง', 'ไม่ตั้งท้อง', 'แท้ง', 'แท้งลูก']);
                })
                ->whereIn('dam_id', $farmCowIds)
                ->get();

            foreach ($records as $rec) {
                $cow = $this->findCow($rec->dam_id, $farmCows, $farmId);

                $calvingDate = $rec->expected_calving;
                if (empty($calvingDate) && !empty($rec->mating_date)) {
                    $calvingDate = Carbon::parse($rec->mating_date)->addDays(283)->format('Y-m-d');
                }
                if (empty($calvingDate)) continue;

                $cowName = $cow ? ($cow->name ?: ($cow->tag_number ?: $cow->cow_id)) : (string)$rec->dam_id;
                $cowId = $cow ? $cow->cow_id : (string)$rec->dam_id;
                $sireInfo = $rec->sire_id ? " (พ่อพันธุ์: {$rec->sire_id})" : '';
                $dt = Carbon::parse($calvingDate)->setTime(8, 0)->toIso8601String();
                $calEventId = str_starts_with($rec->breeding_record_id, 'BR-')
                    ? $rec->breeding_record_id
                    : 'BR-' . $rec->breeding_record_id;

                $statusNote = ($rec->pregnancy_result === 'ตั้งท้อง') ? ' (ตรวจยืนยันแล้ว)' : ' (คำนวณจากวันผสม)';

                $breedingEvents[] = [
                    'calendar_event_id' => $calEventId,
                    'farm_id' => $farmId,
                    'title' => 'กำหนดวันคลอด: ' . $cowName,
                    'event_datetime' => $dt,
                    'description' => 'คาดว่าจะคลอดลูกวัว' . $sireInfo . $statusNote,
                    'reminder_setting' => $rec->reminder_setting ?: 'ก่อน 7 วัน',
                    'cow_id' => $cowId,
                    'event_type' => 'breeding',
                ];
            }
        }

        $allEvents = array_merge($manualEvents, $healthEvents, $breedingEvents);
        usort($allEvents, function ($a, $b) {
            return strtotime($a['event_datetime']) <=> strtotime($b['event_datetime']);
        });

        return response()->json($allEvents);
    }

    private function findCow($cowIdOrTag, $farmCows, $farmId)
    {
        if (empty($cowIdOrTag)) {
            return null;
        }

        $searchVal = trim((string)$cowIdOrTag);

        $cow = $farmCows->first(function ($c) use ($searchVal) {
            return trim((string)$c->id) === $searchVal 
                || trim((string)$c->cow_id) === $searchVal 
                || trim((string)$c->tag_number) === $searchVal 
                || trim((string)$c->name) === $searchVal;
        });

        if ($cow) {
            return $cow;
        }

        return Cow::where('farm_id', $farmId)
            ->where(function ($q) use ($searchVal) {
                $q->where('id', $searchVal)
                    ->orWhere('cow_id', $searchVal)
                    ->orWhere('tag_number', $searchVal)
                    ->orWhere('name', $searchVal);
            })->first();
    }

    public function store(Request $request)
    {
        $data = $request->except(['event_type']);
        $event = CalendarEvent::create($data);
        $this->syncNotificationForEvent($event);

        $res = $event->toArray();
        $res['event_type'] = 'general';
        return response()->json($res, 201);
    }

    public function show($id)
    {
        // Handle grouped health appointments (HAG-<group_id>)
        if (str_starts_with($id, 'HAG-')) {
            $groupId = substr($id, 4);
            $appts = HealthAppointment::where('group_id', $groupId)->get();
            if ($appts->isNotEmpty()) {
                $firstAppt = $appts[0];
                $cowIds = $appts->pluck('cow_id')->filter()->toArray();
                $cows = Cow::whereIn('cow_id', $cowIds)->get();
                $cowNames = $cows->map(fn($c) => $c->name ?: ($c->tag_number ?: $c->cow_id))->toArray();
                $cowCount = count($cowNames);
                $cowDisplay = $cowCount <= 3 ? implode(', ', $cowNames) : implode(', ', array_slice($cowNames, 0, 3)) . ' +' . ($cowCount - 3) . ' ตัว';

                $farmId = $cows->isNotEmpty() ? ($cows->first()->farm_id ?? '') : '';

                // Clean description
                $rawDesc = $firstAppt->description ?: 'นัดหมายตรวจสุขภาพ / ฉีดวัคซีน / ถ่ายพยาธิ';
                $cleanDesc = preg_replace('/\s*\(\d+\s*ตัว\)$/u', '', $rawDesc);

                // Derive title from description if formatted as [Type] Title
                $eventTitle = 'นัดหมายสุขภาพ: ' . $cowDisplay;
                if (preg_match('/^\[(.*?)\]\s*(.*)$/u', $cleanDesc, $matches)) {
                    $extractedTitle = trim($matches[2]);
                    if (!empty($extractedTitle)) {
                        $eventTitle = $extractedTitle;
                    }
                }

                return response()->json([
                    'calendar_event_id' => $id,
                    'farm_id' => $farmId,
                    'title' => $eventTitle,
                    'event_datetime' => Carbon::parse($firstAppt->appoint_datetime)->timezone('Asia/Bangkok')->toIso8601String(),
                    'description' => $cleanDesc . ' (' . $cowCount . ' ตัว)',
                    'reminder_setting' => $firstAppt->reminder_setting ?: 'ก่อน 1 วัน',
                    'cow_id' => null,
                    'event_type' => 'health',
                    '_group_id' => $groupId,
                    '_cow_count' => $cowCount,
                    '_cow_ids' => array_values(array_unique(array_map('strval', $cowIds))),
                ]);
            }
        }

        // Handle single health appointment (HA-<id>)
        if (str_starts_with($id, 'HA-')) {
            $realId = preg_replace('/^(HA-)+/', '', $id);
            $appt = HealthAppointment::find($realId) ?? HealthAppointment::find('HA-' . $realId);
            if ($appt) {
                $cow = Cow::find($appt->cow_id) ?? Cow::where('cow_id', $appt->cow_id)->orWhere('tag_number', $appt->cow_id)->first();
                $cowName = $cow ? ($cow->name ?: ($cow->tag_number ?: $cow->cow_id)) : $appt->cow_id;
                $farmId = $cow ? ($cow->farm_id ?? '') : '';

                $rawDesc = $appt->description ?: 'นัดหมายตรวจสุขภาพ / ฉีดวัคซีน / ถ่ายพยาธิ';
                $eventTitle = 'นัดหมายสุขภาพ: ' . $cowName;
                if (preg_match('/^\[(.*?)\]\s*(.*)$/u', $rawDesc, $matches)) {
                    $extractedTitle = trim($matches[2]);
                    if (!empty($extractedTitle)) {
                        $eventTitle = $extractedTitle;
                    }
                }

                return response()->json([
                    'calendar_event_id' => str_starts_with($appt->health_appointment_id, 'HA-') ? $appt->health_appointment_id : 'HA-' . $appt->health_appointment_id,
                    'farm_id' => $farmId,
                    'title' => $eventTitle,
                    'event_datetime' => Carbon::parse($appt->appoint_datetime)->timezone('Asia/Bangkok')->toIso8601String(),
                    'description' => $rawDesc,
                    'reminder_setting' => $appt->reminder_setting ?: 'ก่อน 1 วัน',
                    'cow_id' => $appt->cow_id,
                    'event_type' => 'health',
                ]);
            }
        }

        // Handle breeding record (BR-<id>)
        if (str_starts_with($id, 'BR-')) {
            $realId = preg_replace('/^(BR-)+/', '', $id);
            $rec = BreedingRecord::find($realId) ?? BreedingRecord::find('BR-' . $realId);
            if ($rec) {
                $cow = Cow::find($rec->dam_id);
                $cowName = $cow ? ($cow->name ?: ($cow->tag_number ?: $cow->cow_id)) : $rec->dam_id;
                $sireInfo = $rec->sire_id ? " (พ่อพันธุ์: {$rec->sire_id})" : '';
                $calvingDate = $rec->expected_calving ?: ($rec->mating_date ? Carbon::parse($rec->mating_date)->addDays(283)->format('Y-m-d') : null);
                return response()->json([
                    'calendar_event_id' => str_starts_with($rec->breeding_record_id, 'BR-') ? $rec->breeding_record_id : 'BR-' . $rec->breeding_record_id,
                    'farm_id' => $rec->farm_id,
                    'title' => 'กำหนดวันคลอด: ' . $cowName,
                    'event_datetime' => $calvingDate ? Carbon::parse($calvingDate)->setTime(8, 0)->toIso8601String() : null,
                    'description' => 'คาดว่าจะคลอดลูกวัว' . $sireInfo,
                    'reminder_setting' => $rec->reminder_setting ?: 'ก่อน 7 วัน',
                    'cow_id' => $rec->dam_id,
                    'event_type' => 'breeding',
                ]);
            }
        }

        $event = CalendarEvent::findOrFail($id);
        $res = $event->toArray();
        $res['event_type'] = 'general';
        return response()->json($res);
    }

    public function update(Request $request, $id)
    {
        // Handle grouped health appointments (HAG-<group_id>)
        if (str_starts_with($id, 'HAG-')) {
            $groupId = substr($id, 4);
            $appts = HealthAppointment::where('group_id', $groupId)->get();
            if ($appts->isNotEmpty()) {
                $rawDesc = $request->get('description');
                if ($rawDesc === null) {
                    $rawDesc = $request->get('title', $appts[0]->description);
                }
                // Strip trailing count if passed back
                $cleanDesc = preg_replace('/\s*\(\d+\s*ตัว\)$/u', '', $rawDesc);
                $targetDatetime = $request->get('event_datetime', $appts[0]->appoint_datetime);
                $targetReminder = $request->get('reminder_setting', $appts[0]->reminder_setting);

                // Handle cow_ids update if provided
                if ($request->has('cow_ids') && is_array($request->get('cow_ids'))) {
                    $newCowIds = array_unique(array_filter(array_map('strval', $request->get('cow_ids'))));

                    // If all cows removed, delete the whole group appointment
                    if (empty($newCowIds)) {
                        return $this->destroy($id);
                    }

                    // Existing appointments mapped by cow_id
                    $existingByCow = [];
                    foreach ($appts as $appt) {
                        $existingByCow[(string)$appt->cow_id] = $appt;
                    }

                    // Remove cows not in new list
                    foreach ($existingByCow as $cowId => $appt) {
                        if (!in_array((string)$cowId, $newCowIds, true)) {
                            $realId = preg_replace('/^(HA-)+/', '', $appt->health_appointment_id);
                            Notification::where('message', 'like', "%appt_{$realId}%")->delete();
                            $appt->delete();
                        }
                    }

                    // Add newly selected cows or update existing
                    foreach ($newCowIds as $cowId) {
                        if (isset($existingByCow[$cowId])) {
                            $existingByCow[$cowId]->update([
                                'appoint_datetime' => $targetDatetime,
                                'description' => $cleanDesc,
                                'reminder_setting' => $targetReminder,
                            ]);
                            HealthAppointmentController::syncNotificationForHealthAppt($existingByCow[$cowId]);
                        } else {
                            $newAppt = HealthAppointment::create([
                                'cow_id' => $cowId,
                                'appoint_datetime' => $targetDatetime,
                                'description' => $cleanDesc,
                                'reminder_setting' => $targetReminder,
                                'status' => 0,
                                'group_id' => $groupId,
                            ]);
                            HealthAppointmentController::syncNotificationForHealthAppt($newAppt);
                        }
                    }
                } else {
                    // Update existing records in group without altering cow membership
                    foreach ($appts as $appt) {
                        $appt->update([
                            'appoint_datetime' => $targetDatetime,
                            'description' => $cleanDesc,
                            'reminder_setting' => $targetReminder,
                        ]);
                        HealthAppointmentController::syncNotificationForHealthAppt($appt);
                    }
                }

                return $this->show($id);
            }
        }

        if (str_starts_with($id, 'HA-')) {
            $realId = preg_replace('/^(HA-)+/', '', $id);
            $appt = HealthAppointment::find($realId) ?? HealthAppointment::find('HA-' . $realId);
            if ($appt) {
                $appt->update([
                    'appoint_datetime' => $request->get('event_datetime', $appt->appoint_datetime),
                    'description' => $request->get('description', $appt->description) ?: $request->get('title', $appt->description),
                    'cow_id' => $request->get('cow_id', $appt->cow_id),
                    'reminder_setting' => $request->get('reminder_setting', $appt->reminder_setting),
                ]);
                HealthAppointmentController::syncNotificationForHealthAppt($appt);
                return $this->show($id);
            }
        }

        if (str_starts_with($id, 'BR-')) {
            $realId = preg_replace('/^(BR-)+/', '', $id);
            $rec = BreedingRecord::find($realId) ?? BreedingRecord::find('BR-' . $realId);
            if ($rec) {
                $rec->update([
                    'reminder_setting' => $request->get('reminder_setting', $rec->reminder_setting),
                ]);
                return $this->show($id);
            }
        }

        $event = CalendarEvent::findOrFail($id);
        $data = $request->except(['event_type']);
        $event->update($data);
        $this->syncNotificationForEvent($event);

        $res = $event->toArray();
        $res['event_type'] = 'general';
        return response()->json($res);
    }

    public function destroy($id)
    {
        // Handle grouped health appointment deletion (HAG-<group_id>)
        if (str_starts_with($id, 'HAG-')) {
            $groupId = substr($id, 4); // Remove 'HAG-' prefix
            $appts = HealthAppointment::where('group_id', $groupId)->get();
            foreach ($appts as $appt) {
                $realId = preg_replace('/^(HA-)+/', '', $appt->health_appointment_id);
                Notification::where('message', 'like', "%appt_{$realId}%")->delete();
            }
            HealthAppointment::where('group_id', $groupId)->delete();
            return response()->json(null, 204);
        }

        if (str_starts_with($id, 'HA-')) {
            $realId = preg_replace('/^(HA-)+/', '', $id);
            Notification::where('message', 'like', "%appt_{$realId}%")->delete();
            HealthAppointment::where('health_appointment_id', $realId)->orWhere('health_appointment_id', 'HA-' . $realId)->delete();
            return response()->json(null, 204);
        }

        Notification::where('message', 'like', "%[ref:cal_{$id}]%")->delete();
        CalendarEvent::destroy($id);

        return response()->json(null, 204);
    }

    private function syncNotificationForEvent(CalendarEvent $event)
    {
        $refKey = "[ref:cal_{$event->calendar_event_id}]";
        $setting = $event->reminder_setting;

        if (empty($setting) || $setting === 'ไม่แจ้งเตือน') {
            Notification::where('message', 'like', "%{$refKey}%")->delete();
            return;
        }

        // Determine farm email
        $userEmail = null;
        if ($event->farm_id) {
            $farm = Farm::find($event->farm_id);
            if ($farm && $farm->email) {
                $userEmail = $farm->email;
            }
        }
        if (!$userEmail && Auth::check()) {
            $userEmail = Auth::user()->email;
        }
        if (!$userEmail) {
            $userEmail = Notification::value('email') ?? 'admin@cowsmart.com';
        }

        $eventDt = Carbon::parse($event->event_datetime);
        $notifyDt = $eventDt->copy();

        if (str_contains($setting, '30 นาที')) {
            $notifyDt->subMinutes(30);
        } elseif (str_contains($setting, '15 นาที')) {
            $notifyDt->subMinutes(15);
        } elseif (str_contains($setting, '1 ชั่วโมง')) {
            $notifyDt->subHours(1);
        } elseif (str_contains($setting, '1 วัน')) {
            $notifyDt->subDays(1);
        } elseif (str_contains($setting, '2 วัน')) {
            $notifyDt->subDays(2);
        } elseif (str_contains($setting, '3 วัน')) {
            $notifyDt->subDays(3);
        } elseif (str_contains($setting, '1 สัปดาห์') || str_contains($setting, '7 วัน')) {
            $notifyDt->subDays(7);
        }

        $cowText = '';
        if ($event->cow_id) {
            $cow = Cow::find($event->cow_id);
            if ($cow) {
                $cowName = $cow->name ?: $cow->cow_id;
                $cowText = " (เกี่ยวข้องกับวัว: {$cowName})";
            }
        }

        $descText = $event->description ? "\n{$event->description}" : '';

        $title = "กิจกรรมปฏิทิน: {$event->title}";
        $message = "กิจกรรม \"{$event->title}\" กำหนดวันที่ {$eventDt->format('d/m/Y H:i')}{$cowText}{$descText} {$refKey}";

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
                $pushBody = "กิจกรรม \"{$event->title}\" กำหนดวันที่ {$eventDt->format('d/m/Y H:i')}{$cowText}";
                FirebaseService::sendPushNotification(
                    $user->fcm_token,
                    $title,
                    $pushBody,
                    ['type' => 'calendar_event', 'event_id' => (string)$event->calendar_event_id]
                );
            }
        }
    }
}

