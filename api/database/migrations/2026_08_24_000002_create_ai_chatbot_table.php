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
        if (Schema::hasTable('ai_knowledges')) {
            Schema::dropIfExists('ai_knowledges');
        }

        Schema::create('ai_chatbot', function (Blueprint $table) {
            $table->id();
            $table->string('category', 100)->comment('หมวดหมู่อาการหรือความรู้');
            $table->string('title', 255)->comment('หัวข้อคำถามหรืออาการ');
            $table->text('keywords')->nullable()->comment('คำค้นหาที่เกี่ยวข้อง คั่นด้วยจุลภาค');
            $table->text('prompt')->comment('คำถามด่วนสำหรับผู้ใช้งาน');
            $table->longText('answer')->comment('คำตอบและคำแนะนำการรักษาของสัตวแพทย์');
            $table->json('suggested_actions')->nullable()->comment('ปุ่มดำเนินการ เช่น create_appointment, record_health');
            $table->boolean('is_active')->default(true)->comment('เปิดหรือปิดการใช้งาน');
            $table->integer('sort_order')->default(0)->comment('ลำดับการแสดงผล');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_chatbot');
    }
};
