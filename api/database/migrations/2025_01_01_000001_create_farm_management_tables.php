<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Master Data Tables
        Schema::create('diseases', function (Blueprint $table) {
            $table->string('disease_id', 10)->primary()->comment('รหัสโรค (เช่น DIS-0001)');
            $table->string('name', 150)->nullable()->comment('ชื่อโรคและอาการป่วย');
            $table->text('cause')->nullable()->comment('สาเหตุการเกิดโรคและการแพร่โรค');
            $table->text('symptoms')->nullable()->comment('ลักษณะอาการของโรค');
            $table->text('observation')->nullable()->comment('วิธีสังเกตอาการเบื้องต้น');
            $table->text('treatment')->nullable()->comment('วิธีการดูแลรักษาเบื้องต้น');
            $table->text('prevention')->nullable()->comment('การควบคุมและการป้องกันโรค');
            $table->timestamps();
        });

        Schema::create('medicines', function (Blueprint $table) {
            $table->string('medicine_id', 10)->primary()->comment('รหัสยา (เช่น MED-0001)');
            $table->string('category', 100)->nullable()->comment('หมวดหมู่ยา');
            $table->string('name', 150)->nullable()->comment('ชื่อยา');
            $table->text('indications')->nullable()->comment('ข้อบ่งใช้');
            $table->text('dosage_usage')->nullable()->comment('ขนาดและวิธีการใช้ยา');
            $table->timestamps();
        });

        Schema::create('vaccines', function (Blueprint $table) {
            $table->string('vaccine_id', 10)->primary()->comment('รหัสวัคซีน (เช่น VAC-0001)');
            $table->string('category', 100)->nullable()->comment('หมวดหมู่วัคซีน');
            $table->string('name', 150)->nullable()->comment('ชื่อวัคซีน');
            $table->text('indications')->nullable()->comment('ข้อบ่งใช้');
            $table->text('dosage_usage')->nullable()->comment('ขนาดและวิธีการฉีดวัคซีน');
            $table->timestamps();
        });

        Schema::create('checkup_types', function (Blueprint $table) {
            $table->string('checkup_types_id', 10)->primary()->comment('รหัสประเภทการตรวจ');
            $table->string('type_name', 100)->nullable()->comment('ชื่อประเภท');
            $table->timestamps();
        });

        Schema::create('breeds', function (Blueprint $table) {
            $table->string('breed_id', 10)->primary()->comment('รหัสสายพันธุ์');
            $table->string('name', 100)->nullable()->comment('ชื่อสายพันธุ์');
            $table->text('description')->nullable()->comment('รายละเอียดสายพันธุ์');
            $table->timestamps();
        });

        Schema::create('cow_types', function (Blueprint $table) {
            $table->string('cow_type_id', 10)->primary()->comment('รหัสประเภทวัว');
            $table->string('cow_type_name', 100)->nullable()->comment('ชื่อประเภท');
            $table->timestamps();
        });

        // 2. Foreign Key Tables
        Schema::create('farms', function (Blueprint $table) {
            $table->string('farm_id', 10)->primary()->comment('รหัสฟาร์ม');
            $table->string('email', 255)->nullable()->comment('อีเมลผู้ใช้งานที่เป็นเจ้าของฟาร์ม');
            $table->string('name', 150)->nullable()->comment('ชื่อฟาร์ม');
            $table->text('address')->nullable()->comment('ที่อยู่ของฟาร์ม');
            $table->string('image_url', 255)->nullable()->comment('รูปภาพฟาร์ม');
            $table->timestamps();
            $table->foreign('email')->references('email')->on('users')->onUpdate('cascade');
        });

        Schema::create('zones', function (Blueprint $table) {
            $table->string('zone_id', 10)->primary()->comment('รหัสโซน');
            $table->string('farm_id', 10)->nullable()->comment('รหัสฟาร์มที่โซนนี้สังกัดอยู่');
            $table->string('name', 100)->nullable()->comment('ชื่อโซนหรือคอก');
            $table->timestamps();
            $table->foreign('farm_id')->references('farm_id')->on('farms');
        });

        Schema::create('cows', function (Blueprint $table) {
            $table->string('cow_id', 10)->primary()->comment('รหัสวัว');
            $table->string('farm_id', 10)->nullable()->comment('รหัสฟาร์ม');
            $table->string('zone_id', 10)->nullable()->comment('รหัสโซนที่อยู่ปัจจุบัน');
            $table->string('breed_id', 10)->nullable()->comment('รหัสสายพันธุ์');
            $table->string('cow_type_id', 10)->nullable()->comment('รหัสประเภทวัว');
            $table->string('tag_number', 50)->nullable()->comment('หมายเลขประจำตัวหรือเบอร์หู');
            $table->string('name', 100)->nullable()->comment('ชื่อวัว');
            $table->date('birth_date')->nullable()->comment('วันเกิดวัว');
            $table->string('gender', 20)->nullable()->comment('เพศ');
            $table->string('sire_id', 10)->nullable()->comment('รหัสพ่อพันธุ์ (อ้างอิงรหัสวัว)');
            $table->string('dam_id', 10)->nullable()->comment('รหัสแม่พันธุ์ (อ้างอิงรหัสวัว)');
            $table->string('status', 50)->nullable()->comment('สถานะปัจจุบันของวัว');
            $table->string('nfc_tag', 100)->nullable()->comment('รหัสข้อมูล NFC Tag');
            $table->string('qr_code', 100)->nullable()->comment('รหัสข้อมูล QR Code');
            $table->string('image_url', 255)->nullable()->comment('รูปภาพวัว');
            $table->timestamps();

            $table->foreign('farm_id')->references('farm_id')->on('farms');
            $table->foreign('zone_id')->references('zone_id')->on('zones');
            $table->foreign('breed_id')->references('breed_id')->on('breeds');
            $table->foreign('cow_type_id')->references('cow_type_id')->on('cow_types');
            $table->foreign('sire_id')->references('cow_id')->on('cows');
            $table->foreign('dam_id')->references('cow_id')->on('cows');
        });

        Schema::create('growth_records', function (Blueprint $table) {
            $table->string('growth_records_id', 10)->primary()->comment('รหัสบันทึกการเติบโต');
            $table->string('cow_id', 10)->nullable()->comment('รหัสวัว');
            $table->dateTime('record_date')->nullable()->comment('วันที่บันทึกข้อมูล');
            $table->decimal('girth', 8, 2)->nullable()->comment('รอบอก');
            $table->decimal('weight', 8, 2)->nullable()->comment('น้ำหนัก');
            $table->timestamps();
            $table->foreign('cow_id')->references('cow_id')->on('cows');
        });

        Schema::create('culling_records', function (Blueprint $table) {
            $table->string('culling_record_id', 10)->primary()->comment('รหัสรายการคัดทิ้ง');
            $table->string('cow_id', 10)->nullable()->comment('รหัสวัว');
            $table->dateTime('cull_date')->nullable()->comment('วันที่คัดทิ้งหรือจำหน่าย');
            $table->integer('status')->nullable()->comment('สาเหตุการคัดทิ้ง (0 = ขาย, 1 = ตาย ฯลฯ)');
            $table->decimal('price', 10, 2)->nullable()->comment('ราคาที่ขายได้ (บาท)');
            $table->text('note')->nullable()->comment('หมายเหตุเพิ่มเติม');
            $table->timestamps();
            $table->foreign('cow_id')->references('cow_id')->on('cows');
        });

        Schema::create('health_records', function (Blueprint $table) {
            $table->string('health_record_id', 10)->primary()->comment('รหัสบันทึกสุขภาพ');
            $table->string('cow_id', 10)->nullable()->comment('รหัสวัว');
            $table->dateTime('record_date')->nullable()->comment('วันที่บันทึก');
            $table->string('checkup_type_id', 10)->nullable()->comment('รหัสประเภทการตรวจ');
            $table->string('disease_id', 10)->nullable()->comment('รหัสโรค');
            $table->string('med_id', 10)->nullable()->comment('รหัสยา');
            $table->string('vac_id', 10)->nullable()->comment('รหัสวัคซีน');
            $table->decimal('cost', 10, 2)->nullable()->comment('ค่าใช้จ่าย (บาท)');
            $table->string('admin_name', 100)->nullable()->comment('ชื่อผู้ดำเนินการรักษา/ฉีดวัคซีน');
            $table->timestamps();

            $table->foreign('cow_id')->references('cow_id')->on('cows');
            $table->foreign('checkup_type_id')->references('checkup_types_id')->on('checkup_types');
            $table->foreign('disease_id')->references('disease_id')->on('diseases');
            $table->foreign('med_id')->references('medicine_id')->on('medicines');
            $table->foreign('vac_id')->references('vaccine_id')->on('vaccines');
        });

        Schema::create('health_appointments', function (Blueprint $table) {
            $table->string('health_appointment_id', 10)->primary()->comment('รหัสการนัดหมาย');
            $table->string('health_record_id', 10)->nullable()->comment('อ้างอิงรหัสบันทึกสุขภาพครั้งก่อนหน้า');
            $table->string('cow_id', 10)->nullable()->comment('รหัสวัว');
            $table->dateTime('appoint_datetime')->nullable()->comment('วันที่และเวลานัดหมาย');
            $table->text('description')->nullable()->comment('รายละเอียดการนัดหมาย');
            $table->integer('status')->nullable()->comment('สถานะ (0 = รอถึงกำหนด, 1 = ดำเนินการแล้ว)');
            $table->timestamps();
            $table->foreign('health_record_id')->references('health_record_id')->on('health_records');
            $table->foreign('cow_id')->references('cow_id')->on('cows');
        });

        Schema::create('breeding_records', function (Blueprint $table) {
            $table->string('breeding_record_id', 10)->primary()->comment('รหัสบันทึกผสมพันธุ์');
            $table->string('dam_id', 10)->nullable()->comment('รหัสวัวแม่พันธุ์');
            $table->date('heat_date')->nullable()->comment('วันที่เป็นสัด');
            $table->date('mating_date')->nullable()->comment('วันที่ผสมพันธุ์');
            $table->string('sire_id', 10)->nullable()->comment('รหัสพ่อพันธุ์ที่ใช้ผสม');
            $table->date('check_date')->nullable()->comment('วันที่ตรวจผลการตั้งท้อง');
            $table->string('pregnancy_result', 100)->nullable()->comment('ผลตรวจท้อง (ท้อง/ไม่ติด)');
            $table->date('expected_calving')->nullable()->comment('วันที่คาดว่าจะคลอด');
            $table->date('calving_date')->nullable()->comment('วันที่คลอดจริง');
            $table->string('calving_result', 100)->nullable()->comment('ผลการคลอด (คลอดปกติ, คลอดยาก, แท้ง, ลูกตาย, แฝด)');
            $table->string('calf_id', 10)->nullable()->comment('รหัสลูกวัวที่เกิดใหม่');
            $table->timestamps();
            $table->foreign('dam_id')->references('cow_id')->on('cows');
            $table->foreign('sire_id')->references('cow_id')->on('cows');
            $table->foreign('calf_id')->references('cow_id')->on('cows');
        });

        Schema::create('calving_records', function (Blueprint $table) {
            $table->string('calving_record_id', 10)->primary()->comment('รหัสบันทึกการคลอด');
            $table->string('breeding_record_id', 10)->nullable()->comment('อ้างอิงรหัสรอบการผสมพันธุ์');
            $table->string('dam_id', 10)->nullable()->comment('รหัสแม่พันธุ์');
            $table->dateTime('calving_datetime')->nullable()->comment('วันที่และเวลาที่คลอด');
            $table->string('calf_id', 10)->nullable()->comment('รหัสลูกวัวที่เกิดใหม่');
            $table->string('calving_result', 100)->nullable()->comment('ผลการคลอด (ปกติ, แท้ง ฯลฯ)');
            $table->timestamps();
            $table->foreign('breeding_record_id')->references('breeding_record_id')->on('breeding_records');
            $table->foreign('dam_id')->references('cow_id')->on('cows');
            $table->foreign('calf_id')->references('cow_id')->on('cows');
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
            $table->foreign('zone_id')->references('zone_id')->on('zones');
        });

        Schema::create('financial_records', function (Blueprint $table) {
            $table->string('financial_record_id', 10)->primary()->comment('รหัสธุรกรรม');
            $table->string('farm_id', 10)->nullable()->comment('รหัสฟาร์ม');
            $table->dateTime('transaction_date')->nullable()->comment('วันที่เกิดธุรกรรม');
            $table->string('trans_type', 50)->nullable()->comment('ประเภทธุรกรรม (รายรับ,รายจ่าย)');
            $table->string('category', 100)->nullable()->comment('หมวดหมู่ (เช่น ค่าอาหาร, ขายวัว)');
            $table->decimal('amount', 10, 2)->nullable()->comment('จำนวนเงิน');
            $table->timestamps();
            $table->foreign('farm_id')->references('farm_id')->on('farms');
        });

        Schema::create('calendar_events', function (Blueprint $table) {
            $table->string('calendar_event_id', 10)->primary()->comment('รหัสกิจกรรม');
            $table->string('farm_id', 10)->nullable()->comment('รหัสฟาร์ม');
            $table->string('title', 255)->nullable()->comment('หัวข้อกิจกรรม');
            $table->dateTime('event_datetime')->nullable()->comment('วันที่และเวลากิจกรรม');
            $table->text('description')->nullable()->comment('รายละเอียดกิจกรรม');
            $table->string('reminder_setting', 100)->nullable()->comment('การตั้งค่าแจ้งเตือนล่วงหน้า');
            $table->string('cow_id', 10)->nullable()->comment('รหัสวัว (กรณีเกี่ยวข้องกับวัวเฉพาะตัว)');
            $table->timestamps();
            $table->foreign('farm_id')->references('farm_id')->on('farms');
            $table->foreign('cow_id')->references('cow_id')->on('cows');
        });

        Schema::create('notifications', function (Blueprint $table) {
            $table->string('id', 10)->primary()->comment('รหัสแจ้งเตือน');
            $table->string('email', 255)->nullable()->comment('อีเมลผู้ใช้งาน');
            $table->string('title', 255)->nullable()->comment('หัวข้อแจ้งเตือน');
            $table->text('message')->nullable()->comment('ข้อความแจ้งเตือน');
            $table->dateTime('notify_datetime')->nullable()->comment('วันและเวลาที่แจ้งเตือน');
            $table->integer('is_read')->default(0)->comment('สถานะการอ่าน (0=ยังไม่อ่าน, 1=อ่านแล้ว)');
            $table->timestamps();
            $table->foreign('email')->references('email')->on('users')->onUpdate('cascade');
        });

        Schema::create('issue_reports', function (Blueprint $table) {
            $table->string('id', 10)->primary()->comment('รหัสรายงานปัญหา');
            $table->string('email', 255)->nullable()->comment('อีเมลผู้ใช้งานที่แจ้งปัญหา');
            $table->string('topic', 255)->nullable()->comment('หัวข้อปัญหา');
            $table->text('description')->nullable()->comment('รายละเอียดปัญหา');
            $table->string('image_url', 255)->nullable()->comment('รูปภาพแนบ');
            $table->integer('status')->default(0)->comment('สถานะการดำเนินการ (เช่น 0 =รอตรวจสอบ, 1 = ดำเนินการเสร็จสิ้น)');
            $table->timestamps();
            $table->foreign('email')->references('email')->on('users')->onUpdate('cascade');
        });

        Schema::create('chat_histories', function (Blueprint $table) {
            $table->string('id', 10)->primary()->comment('รหัสแชท');
            $table->string('email', 255)->nullable()->comment('อีเมลผู้ใช้งาน');
            $table->text('user_message')->nullable()->comment('ข้อความจากผู้ใช้งาน');
            $table->text('ai_response')->nullable()->comment('คำตอบจาก AI');
            $table->dateTime('chat_datetime')->nullable()->comment('วันที่และเวลาที่สนทนา');
            $table->timestamps();
            $table->foreign('email')->references('email')->on('users')->onUpdate('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chat_histories');
        Schema::dropIfExists('issue_reports');
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('calendar_events');
        Schema::dropIfExists('financial_records');
        Schema::dropIfExists('feeding_records');
        Schema::dropIfExists('calving_records');
        Schema::dropIfExists('breeding_records');
        Schema::dropIfExists('health_appointments');
        Schema::dropIfExists('health_records');
        Schema::dropIfExists('culling_records');
        Schema::dropIfExists('growth_records');
        Schema::dropIfExists('cows');
        Schema::dropIfExists('zones');
        Schema::dropIfExists('farms');
        Schema::dropIfExists('cow_types');
        Schema::dropIfExists('breeds');
        Schema::dropIfExists('checkup_types');
        Schema::dropIfExists('vaccines');
        Schema::dropIfExists('medicines');
        Schema::dropIfExists('diseases');
    }
};
