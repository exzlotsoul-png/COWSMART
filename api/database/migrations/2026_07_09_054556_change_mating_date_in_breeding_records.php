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
            $table->dateTime('heat_date')->nullable()->change();
            $table->dateTime('mating_date')->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('breeding_records', function (Blueprint $table) {
            $table->date('heat_date')->nullable()->change();
            $table->date('mating_date')->nullable()->change();
        });
    }
};
