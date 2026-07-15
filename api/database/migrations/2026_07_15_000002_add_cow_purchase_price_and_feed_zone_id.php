<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Add purchase_price to cows table
        Schema::table('cows', function (Blueprint $table) {
            $table->decimal('purchase_price', 10, 2)->default(0.00)->after('latest_weight')
                  ->comment('ราคาที่ซื้อวัวมา (บาท)');
        });

        // 2. Add zone_id to feed_inventories table
        Schema::table('feed_inventories', function (Blueprint $table) {
            $table->string('zone_id', 10)->nullable()->after('farm_id')
                  ->comment('รหัสโซนที่ใช้อาหารนี้ (สำหรับเฉลี่ยค่าใช้จ่าย)');
            $table->foreign('zone_id')->references('zone_id')->on('zones');
        });
    }

    public function down(): void
    {
        Schema::table('feed_inventories', function (Blueprint $table) {
            $table->dropForeign(['zone_id']);
            $table->dropColumn('zone_id');
        });

        Schema::table('cows', function (Blueprint $table) {
            $table->dropColumn('purchase_price');
        });
    }
};
