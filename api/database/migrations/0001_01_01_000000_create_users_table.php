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
        Schema::create('users', function (Blueprint $table) {
            $table->string('email', 255)->primary()->comment('อีเมลสำหรับเข้าสู่ระบบ');
            $table->string('password', 128)->comment('รหัสผ่าน (เข้ารหัส)');
            $table->string('first_name', 50)->nullable()->comment('ชื่อจริง');
            $table->string('last_name', 50)->nullable()->comment('นามสกุล');
            $table->string('profile_image', 255)->nullable()->comment('รูปโปรไฟล์');
            $table->string('role', 5)->nullable()->comment('บทบาทและสิทธิ์การใช้งาน');
            $table->dateTime('created_at')->nullable()->comment('วันที่และเวลาที่สร้างบัญชี');
            $table->timestamp('updated_at')->nullable();
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('user_id', 255)->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('users');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('sessions');
    }
};
