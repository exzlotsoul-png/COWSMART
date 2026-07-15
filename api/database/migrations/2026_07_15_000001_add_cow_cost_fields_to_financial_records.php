<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('financial_records', function (Blueprint $table) {
            $table->string('related_cow_id', 10)->nullable()->after('category')
                  ->comment('รหัสวัวที่เกี่ยวข้อง (กรณีค่าใช้จ่ายรายตัว)');
            $table->text('notes')->nullable()->after('amount')
                  ->comment('หมายเหตุเพิ่มเติม');
            $table->string('title', 255)->nullable()->after('farm_id')
                  ->comment('หัวข้อรายการ');
        });
    }

    public function down(): void
    {
        Schema::table('financial_records', function (Blueprint $table) {
            $table->dropColumn(['related_cow_id', 'notes', 'title']);
        });
    }
};
