<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('health_appointments', function (Blueprint $table) {
            if (!Schema::hasColumn('health_appointments', 'group_id')) {
                $table->string('group_id', 40)->nullable()->after('cow_id')->index()->comment('รหัสกลุ่มนัดหมาย สำหรับรวมนัดหมายที่สร้างพร้อมกัน');
            }
        });
    }

    public function down(): void
    {
        Schema::table('health_appointments', function (Blueprint $table) {
            if (Schema::hasColumn('health_appointments', 'group_id')) {
                $table->dropColumn('group_id');
            }
        });
    }
};
