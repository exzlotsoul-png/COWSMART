<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\BreedingRecord;
use App\Models\HealthAppointment;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\Notification;
use Carbon\Carbon;

use App\Models\CalendarEvent;

class GenerateFarmNotifications extends Command
{
    protected $signature = 'notifications:generate';
    protected $description = 'Generate notifications for calving, health appointments, and calendar events';

    public function handle()
    {
        $this->checkCalvingNotifications();
        $this->checkHealthAppointmentNotifications();
        $this->checkCalendarEventNotifications();
        $this->info('Notifications generated successfully.');
    }

    private function checkCalvingNotifications()
    {
        $today = Carbon::today();
        $records = BreedingRecord::whereNotNull('expected_calving')
            ->whereNull('calving_date')
            ->where('pregnancy_result', 'like', '%ตั้งท้อง%')
            ->get();

        foreach ($records as $record) {
            $setting = $record->reminder_setting ?: 'ก่อน 7 วัน';
            if ($setting === 'ไม่แจ้งเตือน') continue;

            $cow = Cow::find($record->dam_id) ?? Cow::where('cow_id', $record->dam_id)->orWhere('tag_number', $record->dam_id)->first();
            if (!$cow) continue;

            $farm = Farm::find($cow->farm_id);
            if (!$farm) continue;

            $targetCalvingDate = Carbon::parse($record->expected_calving)->startOfDay();
            $notifyDt = $targetCalvingDate->copy();

            if (str_contains($setting, '1 วัน')) {
                $notifyDt->subDays(1);
            } elseif (str_contains($setting, '3 วัน')) {
                $notifyDt->subDays(3);
            } elseif (str_contains($setting, '7 วัน')) {
                $notifyDt->subDays(7);
            } elseif (str_contains($setting, '14 วัน')) {
                $notifyDt->subDays(14);
            } elseif (str_contains($setting, '30 วัน')) {
                $notifyDt->subDays(30);
            }

            if ($today->isSameDay($notifyDt) || ($today->greaterThanOrEqualTo($notifyDt) && $today->lessThanOrEqualTo($targetCalvingDate))) {
                $existingKey = "calving_{$record->breeding_record_id}";
                $alreadySent = Notification::where('email', $farm->email)
                    ->where('message', 'like', "%{$existingKey}%")
                    ->whereDate('created_at', $today->toDateString())
                    ->exists();

                if ($alreadySent) continue;

                $diffDays = $today->diffInDays($targetCalvingDate, false);
                $daysLabel = $diffDays == 0 ? 'วันนี้' : ($diffDays == 1 ? 'พรุ่งนี้' : "อีก {$diffDays} วัน");
                $cowName = $cow->name ?: ($cow->tag_number ?: $cow->cow_id);

                Notification::create([
                    'id' => 'N-' . substr(md5(uniqid(mt_rand(), true)), 0, 8),
                    'email' => $farm->email,
                    'title' => 'วัวใกล้คลอด',
                    'message' => "{$cowName} คาดว่าจะคลอด{$daysLabel} ({$targetCalvingDate->format('d/m/Y')}) [ref:{$existingKey}]",
                    'notify_datetime' => now(),
                    'is_read' => 0,
                ]);

                $this->info("Created calving notification for cow {$cowName}");
            }
        }
    }

    private function checkHealthAppointmentNotifications()
    {
        $today = Carbon::today();
        $appointments = HealthAppointment::whereNotNull('appoint_datetime')
            ->where(function ($q) {
                $q->whereNull('status')->orWhere('status', 0);
            })
            ->get();

        foreach ($appointments as $appt) {
            $setting = $appt->reminder_setting ?: 'ก่อน 1 วัน';
            if ($setting === 'ไม่แจ้งเตือน') continue;

            $cow = Cow::find($appt->cow_id) ?? Cow::where('cow_id', $appt->cow_id)->orWhere('tag_number', $appt->cow_id)->first();
            if (!$cow) continue;

            $farm = Farm::find($cow->farm_id);
            if (!$farm) continue;

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

            if ($today->isSameDay($notifyDt->startOfDay()) || ($today->greaterThanOrEqualTo($notifyDt->startOfDay()) && $today->lessThanOrEqualTo($apptDt))) {
                $existingKey = "appt_{$appt->health_appointment_id}";
                $alreadySent = Notification::where('email', $farm->email)
                    ->where('message', 'like', "%{$existingKey}%")
                    ->whereDate('created_at', $today->toDateString())
                    ->exists();

                if ($alreadySent) continue;

                $cowName = $cow->name ?: ($cow->tag_number ?: $cow->cow_id);
                $diffDays = $today->diffInDays($apptDt->startOfDay(), false);
                $daysLabel = $diffDays == 0 ? 'วันนี้' : ($diffDays == 1 ? 'พรุ่งนี้' : "อีก {$diffDays} วัน");
                $apptTime = $apptDt->format('d/m/Y H:i');
                $desc = $appt->description ? " ({$appt->description})" : '';

                Notification::create([
                    'id' => 'N-' . substr(md5(uniqid(mt_rand(), true)), 0, 8),
                    'email' => $farm->email,
                    'title' => 'นัดหมายสุขภาพวัว',
                    'message' => "{$cowName} มีนัดหมาย{$daysLabel} วันที่ {$apptTime}{$desc} [ref:{$existingKey}]",
                    'notify_datetime' => now(),
                    'is_read' => 0,
                ]);

                $this->info("Created health appointment notification for cow {$cowName}");
            }
        }
    }

    private function checkCalendarEventNotifications()
    {
        $events = CalendarEvent::whereNotNull('reminder_setting')
            ->where('reminder_setting', '!=', 'ไม่แจ้งเตือน')
            ->get();

        foreach ($events as $event) {
            $refKey = "[ref:cal_{$event->calendar_event_id}]";
            
            $userEmail = null;
            if ($event->farm_id) {
                $farm = Farm::find($event->farm_id);
                if ($farm) $userEmail = $farm->email;
            }
            if (!$userEmail) {
                $userEmail = Notification::value('email') ?? 'admin@cowsmart.com';
            }

            $alreadySent = Notification::where('email', $userEmail)
                ->where('message', 'like', "%{$refKey}%")
                ->exists();

            if ($alreadySent) continue;

            $eventDt = Carbon::parse($event->event_datetime);
            $notifyDt = $eventDt->copy();

            $setting = $event->reminder_setting;
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

            $cowText = '';
            if ($event->cow_id) {
                $cow = Cow::find($event->cow_id);
                if ($cow) {
                    $cowName = $cow->name ?: $cow->cow_id;
                    $cowText = " (เกี่ยวข้องกับวัว: {$cowName})";
                }
            }

            $descText = $event->description ? "\n{$event->description}" : '';

            Notification::create([
                'id' => 'N-' . substr(md5(uniqid(mt_rand(), true)), 0, 8),
                'email' => $userEmail,
                'title' => "กิจกรรมปฏิทิน: {$event->title}",
                'message' => "กิจกรรม \"{$event->title}\" กำหนดวันที่ {$eventDt->format('d/m/Y H:i')}{$cowText}{$descText} {$refKey}",
                'notify_datetime' => $notifyDt,
                'is_read' => 0,
            ]);

            $this->info("Created calendar notification for event {$event->title}");
        }
    }
}
