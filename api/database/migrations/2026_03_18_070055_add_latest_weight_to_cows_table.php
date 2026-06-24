<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('cows', function (Blueprint $table) {
            $table->decimal('latest_weight', 8, 2)->nullable()->default(0)->comment('น้ำหนักล่าสุด (กก.)')->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('cows', function (Blueprint $table) {
            $table->dropColumn('latest_weight');
        });
    }
};
