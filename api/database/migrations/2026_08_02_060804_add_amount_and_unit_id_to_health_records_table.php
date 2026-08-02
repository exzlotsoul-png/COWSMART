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
        Schema::table('health_records', function (Blueprint $table) {
            $table->decimal('amount', 10, 2)->nullable()->after('cost')->comment('จำนวนยาหรือวัคซีนที่ใช้');
            $table->unsignedBigInteger('unit_id')->nullable()->after('amount')->comment('รหัสหน่วยวัด');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('health_records', function (Blueprint $table) {
            $table->dropColumn(['amount', 'unit_id']);
        });
    }
};
