<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('breeding_records', function (Blueprint $table) {
            if (!Schema::hasColumn('breeding_records', 'reminder_setting')) {
                $table->string('reminder_setting', 100)->nullable()->default('ก่อน 7 วัน')->after('expected_calving');
            }
        });
    }

    public function down(): void
    {
        Schema::table('breeding_records', function (Blueprint $table) {
            if (Schema::hasColumn('breeding_records', 'reminder_setting')) {
                $table->dropColumn('reminder_setting');
            }
        });
    }
};
