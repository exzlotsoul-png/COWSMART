<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * ลบตารางที่ไม่ได้ใช้งานใน Flutter app
     * - calving_records: ซ้ำซ้อนกับ breeding_records ซึ่งมีข้อมูลการคลอดอยู่แล้ว
     * - chat_histories: AI chatbot ส่งตรงไป Gemini API ไม่ได้ save history ใน DB
     * - feeding_records: ไม่มี UI ใน Flutter app (ต่างจาก feed_inventories ที่มีหน้าแสดง)
     */
    public function up(): void
    {
        Schema::dropIfExists('calving_records');
        Schema::dropIfExists('chat_histories');
        Schema::dropIfExists('feeding_records');
    }

    /**
     * Reverse: สร้างตารางคืนถ้า rollback (ไม่มี FK เพื่อความง่ายในการ restore)
     */
    public function down(): void
    {
        Schema::create('calving_records', function (Blueprint $table) {
            $table->string('calving_record_id', 10)->primary()->comment('รหัสบันทึกการคลอด');
            $table->string('breeding_record_id', 10)->nullable()->comment('อ้างอิงรหัสรอบการผสมพันธุ์');
            $table->string('dam_id', 10)->nullable()->comment('รหัสแม่พันธุ์');
            $table->dateTime('calving_datetime')->nullable()->comment('วันที่และเวลาที่คลอด');
            $table->string('calf_id', 10)->nullable()->comment('รหัสลูกวัวที่เกิดใหม่');
            $table->string('calving_result', 100)->nullable()->comment('ผลการคลอด');
            $table->timestamps();
        });

        Schema::create('chat_histories', function (Blueprint $table) {
            $table->string('id', 10)->primary()->comment('รหัสแชท');
            $table->string('email', 255)->nullable()->comment('อีเมลผู้ใช้งาน');
            $table->text('user_message')->nullable()->comment('ข้อความจากผู้ใช้งาน');
            $table->text('ai_response')->nullable()->comment('คำตอบจาก AI');
            $table->dateTime('chat_datetime')->nullable()->comment('วันที่และเวลาที่สนทนา');
            $table->timestamps();
        });

        Schema::create('feeding_records', function (Blueprint $table) {
            $table->string('feeding_record_id', 10)->primary()->comment('รหัสบันทึกการให้อาหาร');
            $table->string('zone_id', 10)->nullable()->comment('รหัสโซนที่รับอาหาร');
            $table->date('feed_date')->nullable()->comment('วันที่ให้อาหาร');
            $table->time('feed_time')->nullable()->comment('เวลาที่ให้อาหาร');
            $table->string('feed_type', 150)->nullable()->comment('ประเภทอาหาร');
            $table->decimal('amount', 8, 2)->nullable()->comment('ปริมาณอาหารที่ให้');
            $table->decimal('cost', 10, 2)->nullable()->comment('ราคาค่าอาหารรวม (บาท)');
            $table->timestamps();
        });
    }
};
