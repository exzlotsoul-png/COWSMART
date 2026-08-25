<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('report_topics', function (Blueprint $table) {
            $table->string('id', 10)->primary()->comment('รหัสหัวข้อรายงาน');
            $table->string('name', 255)->comment('ชื่อหัวข้อรายงาน');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('report_topics');
    }
};
