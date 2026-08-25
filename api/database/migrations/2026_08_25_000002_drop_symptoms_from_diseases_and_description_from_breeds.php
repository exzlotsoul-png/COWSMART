<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('diseases', function (Blueprint $table) {
            if (Schema::hasColumn('diseases', 'symptoms')) {
                $table->dropColumn('symptoms');
            }
        });

        Schema::table('breeds', function (Blueprint $table) {
            if (Schema::hasColumn('breeds', 'description')) {
                $table->dropColumn('description');
            }
        });
    }

    public function down(): void
    {
        Schema::table('diseases', function (Blueprint $table) {
            $table->text('symptoms')->nullable();
        });

        Schema::table('breeds', function (Blueprint $table) {
            $table->text('description')->nullable();
        });
    }
};
