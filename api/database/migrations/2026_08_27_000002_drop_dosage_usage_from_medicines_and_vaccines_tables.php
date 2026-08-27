<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('medicines', function (Blueprint $table) {
            if (Schema::hasColumn('medicines', 'dosage_usage')) {
                $table->dropColumn('dosage_usage');
            }
        });

        Schema::table('vaccines', function (Blueprint $table) {
            if (Schema::hasColumn('vaccines', 'dosage_usage')) {
                $table->dropColumn('dosage_usage');
            }
        });
    }

    public function down(): void
    {
        Schema::table('medicines', function (Blueprint $table) {
            $table->text('dosage_usage')->nullable();
        });

        Schema::table('vaccines', function (Blueprint $table) {
            $table->text('dosage_usage')->nullable();
        });
    }
};
