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
        if (Schema::hasColumn('ai_knowledges', 'suggested_actions')) {
            Schema::table('ai_knowledges', function (Blueprint $table) {
                $table->dropColumn('suggested_actions');
            });
        }
        
        if (Schema::hasColumn('ai_chatbot', 'suggested_actions')) {
            Schema::table('ai_chatbot', function (Blueprint $table) {
                $table->dropColumn('suggested_actions');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ai_knowledges', function (Blueprint $table) {
            $table->json('suggested_actions')->nullable()->comment('ปุ่มดำเนินการ เช่น create_appointment, record_health');
        });
        
        Schema::table('ai_chatbot', function (Blueprint $table) {
            $table->json('suggested_actions')->nullable()->comment('ปุ่มดำเนินการ เช่น create_appointment, record_health');
        });
    }
};
