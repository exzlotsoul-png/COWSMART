<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('health_appointments', function (Blueprint $table) {
            if (!Schema::hasColumn('health_appointments', 'reminder_setting')) {
                $table->string('reminder_setting', 100)->nullable()->default('ก่อน 1 วัน')->after('description');
            }
        });
    }

    public function down(): void
    {
        Schema::table('health_appointments', function (Blueprint $table) {
            if (Schema::hasColumn('health_appointments', 'reminder_setting')) {
                $table->dropColumn('reminder_setting');
            }
        });
    }
};
