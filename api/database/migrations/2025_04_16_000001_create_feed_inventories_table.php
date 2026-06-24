<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('feed_inventories', function (Blueprint $table) {
            $table->string('feed_inventory_id', 10)->primary()->comment('รหัสคลังอาหาร');
            $table->string('farm_id', 10)->nullable()->comment('รหัสฟาร์ม');
            $table->string('name', 150)->nullable()->comment('ชื่ออาหาร');
            $table->string('category', 100)->nullable()->comment('หมวดหมู่ (หญ้า, อาหารข้น, อาหารเสริม)');
            $table->decimal('stock_quantity', 10, 2)->nullable()->default(0)->comment('จำนวนคงเหลือ (กก.)');
            $table->decimal('cost_per_kg', 10, 2)->nullable()->default(0)->comment('ราคาต่อกก. (บาท)');
            $table->text('notes')->nullable()->comment('หมายเหตุ');
            $table->timestamps();
            $table->foreign('farm_id')->references('farm_id')->on('farms');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('feed_inventories');
    }
};
