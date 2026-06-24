<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\BreedingRecord;
use App\Models\HealthAppointment;
use App\Models\Cow;
use App\Models\Farm;
use App\Models\Notification;
use Carbon\Carbon;

class GenerateFarmNotifications extends Command
{
    protected $signature = 'notifications:generate';
    protected $description = 'Generate notifications for calving and health appointments';

    public function handle()
    {
        $this->checkCalvingNotifications();
        $this->checkHealthAppointmentNotifications();
        $this->info('Notifications generated successfully.');
    }

    private function checkCalvingNotifications()
    {
        $today = Carbon::today();

        // Find pregnant cows with expected calving in 7, 3, or 1 day(s)
        $daysAhead = [7, 3, 1];

        foreach ($daysAhead as $days) {
            $targetDate = $today->copy()->addDays($days);

            $records = BreedingRecord::whereNotNull('expected_calving')
                ->whereNull('calving_date')
                ->where('pregnancy_result', 'like', '%ตั้งท้อง%')
                ->whereDate('expected_calving', $targetDate->toDateString())
                ->get();

            foreach ($records as $record) {
                $cow = Cow::find($record->dam_id);
                if (!$cow) continue;

                $farm = Farm::find($cow->farm_id);
                if (!$farm) continue;

                $existingKey = "calving_{$record->breeding_record_id}_{$days}d";
                $alreadySent = Notification::where('email', $farm->email)
                    ->where('message', 'like', "%{$existingKey}%")
                    ->whereDate('created_at', $today->toDateString())
                    ->exists();

                if ($alreadySent) continue;

                $daysLabel = $days === 1 ? 'พรุ่งนี้' : "อีก {$days} วัน";
                $cowName = $cow->name ?? $cow->cow_id;

                Notification::create([
                    'id' => 'N-' . substr(md5(uniqid(mt_rand(), true)), 0, 8),
                    'email' => $farm->email,
                    'title' => 'วัวใกล้คลอด',
                    'message' => "{$cowName} คาดว่าจะคลอด{$daysLabel} ({$targetDate->format('d/m/Y')}) [ref:{$existingKey}]",
                    'notify_datetime' => now(),
                    'is_read' => 0,
                ]);

                $this->info("Created calving notification for cow {$cowName} ({$days} days)");
            }
        }
    }

    private function checkHealthAppointmentNotifications()
    {
        $today = Carbon::today();
        $daysAhead = [3, 1];

        foreach ($daysAhead as $days) {
            $targetDate = $today->copy()->addDays($days);

            $appointments = HealthAppointment::whereDate('appoint_datetime', $targetDate->toDateString())
                ->where(function ($q) {
                    $q->whereNull('status')->orWhere('status', 0);
                })
                ->get();

            foreach ($appointments as $appt) {
                $cow = Cow::find($appt->cow_id);
                if (!$cow) continue;

                $farm = Farm::find($cow->farm_id);
                if (!$farm) continue;

                $existingKey = "appt_{$appt->health_appointment_id}_{$days}d";
                $alreadySent = Notification::where('email', $farm->email)
                    ->where('message', 'like', "%{$existingKey}%")
                    ->whereDate('created_at', $today->toDateString())
                    ->exists();

                if ($alreadySent) continue;

                $cowName = $cow->name ?? $cow->cow_id;
                $daysLabel = $days === 1 ? 'พรุ่งนี้' : "อีก {$days} วัน";
                $apptTime = Carbon::parse($appt->appoint_datetime)->format('d/m/Y HH:mm');
                $desc = $appt->description ? " ({$appt->description})" : '';

                Notification::create([
                    'id' => 'N-' . substr(md5(uniqid(mt_rand(), true)), 0, 8),
                    'email' => $farm->email,
                    'title' => 'นัดหมายสุขภาพวัว',
                    'message' => "{$cowName} มีนัดหมาย{$daysLabel} วันที่ {$apptTime}{$desc} [ref:{$existingKey}]",
                    'notify_datetime' => now(),
                    'is_read' => 0,
                ]);

                $this->info("Created health appointment notification for cow {$cowName} ({$days} days)");
            }
        }
    }
}
