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
            // Drop foreign key if it exists. Note: the constraint name might vary, 
            // usually it's table_column_foreign, e.g., 'breeding_records_calf_id_foreign' or 'farm_management_calf_id_foreign'.
            // Drop the foreign key constraint on calf_id if it exists.
            // By passing an array, Laravel automatically guesses the constraint name
            // (e.g. 'breeding_records_calf_id_foreign').
            $table->dropForeign(['calf_id']);

        });

        Schema::table('breeding_records', function (Blueprint $table) {
            $table->string('calf_id', 255)->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('breeding_records', function (Blueprint $table) {
            // Revert back to original size. Note: it may truncate data!
            $table->string('calf_id', 10)->nullable()->change();
            // Re-adding foreign key might fail if data is invalid, so just leave it out in down() or add it cautiously.
        });
    }
};
