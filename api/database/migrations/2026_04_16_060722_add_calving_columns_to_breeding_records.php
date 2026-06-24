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
            if (!Schema::hasColumn('breeding_records', 'calving_date')) {
                $table->date('calving_date')->nullable()->comment('วันที่คลอดจริง');
            }
            if (!Schema::hasColumn('breeding_records', 'calving_result')) {
                $table->string('calving_result', 100)->nullable()->comment('ผลการคลอด (คลอดปกติ, คลอดยาก, แท้ง, ลูกตาย, แฝด)');
            }
            if (!Schema::hasColumn('breeding_records', 'calf_id')) {
                $table->string('calf_id', 10)->nullable()->comment('รหัสลูกวัวที่เกิดใหม่');
                $table->foreign('calf_id')->references('cow_id')->on('cows');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('breeding_records', function (Blueprint $table) {
            //
        });
    }
};
