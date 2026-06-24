<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('market_prices', function (Blueprint $table) {
            $table->id();
            $table->string('animal_type', 50)->default('cattle')->comment('ประเภทสัตว์ เช่น cattle');
            $table->string('category', 100)->nullable()->comment('หมวดหมู่ เช่น วัวขุน, แม่พันธุ์');
            $table->decimal('price_per_kg', 8, 2)->comment('ราคา บาท/กก.');
            $table->date('effective_date')->comment('วันที่ราคามีผล');
            $table->string('source', 200)->nullable()->comment('แหล่งที่มาของราคา');
            $table->text('note')->nullable()->comment('หมายเหตุ');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('market_prices');
    }
};
