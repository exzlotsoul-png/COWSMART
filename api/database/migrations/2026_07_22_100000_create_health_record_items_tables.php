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
        Schema::create('health_record_medicines', function (Blueprint $table) {
            $table->id();
            $table->string('health_record_id', 10);
            $table->string('medicine_id', 10);
            $table->timestamps();

            $table->foreign('health_record_id')->references('health_record_id')->on('health_records')->onDelete('cascade');
            $table->foreign('medicine_id')->references('medicine_id')->on('medicines')->onDelete('cascade');
        });

        Schema::create('health_record_vaccines', function (Blueprint $table) {
            $table->id();
            $table->string('health_record_id', 10);
            $table->string('vaccine_id', 10);
            $table->timestamps();

            $table->foreign('health_record_id')->references('health_record_id')->on('health_records')->onDelete('cascade');
            $table->foreign('vaccine_id')->references('vaccine_id')->on('vaccines')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('health_record_vaccines');
        Schema::dropIfExists('health_record_medicines');
    }
};
