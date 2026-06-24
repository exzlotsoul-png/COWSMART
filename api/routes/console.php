<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;
use App\Console\Commands\GenerateFarmNotifications;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Schedule::command('notifications:generate')
    ->dailyAt('08:00')
    ->timezone('Asia/Bangkok')
    ->withoutOverlapping()
    ->appendOutputTo(storage_path('logs/notifications.log'));
