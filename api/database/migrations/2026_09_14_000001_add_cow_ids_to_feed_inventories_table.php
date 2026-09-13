<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('feed_inventories', function (Blueprint $table) {
            $table->json('cow_ids')->nullable()->after('zone_id')
                  ->comment('รหัสวัวที่เจาะจงให้บันทึกนี้ (กรณีระบุรายตัว)');
        });
    }

    public function down(): void
    {
        Schema::table('feed_inventories', function (Blueprint $table) {
            $table->dropColumn('cow_ids');
        });
    }
};
