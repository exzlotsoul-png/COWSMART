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
        Schema::dropIfExists('health_record_medicines');
        Schema::dropIfExists('health_record_vaccines');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::create('health_record_medicines', function (Blueprint $table) {
            $table->id();
            $table->string('health_record_id', 10);
            $table->string('medicine_id', 10);
            $table->timestamps();
        });

        Schema::create('health_record_vaccines', function (Blueprint $table) {
            $table->id();
            $table->string('health_record_id', 10);
            $table->string('vaccine_id', 10);
            $table->timestamps();
        });
    }
};
