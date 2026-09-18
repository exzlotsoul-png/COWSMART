<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('breeding_records', function (Blueprint $table) {
            $table->string('mating_method', 50)->nullable()->comment('วิธีผสมพันธุ์ (เช่น natural, ai)');
            $table->string('ai_sire_name', 150)->nullable()->comment('ชื่อหรือรหัสหลอดน้ำเชื้อของพ่อพันธุ์ที่กรอกเอง');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('breeding_records', function (Blueprint $table) {
            $table->dropColumn(['mating_method', 'ai_sire_name']);
        });
    }
};
