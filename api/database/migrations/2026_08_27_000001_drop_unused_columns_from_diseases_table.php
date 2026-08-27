<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('diseases', function (Blueprint $table) {
            $columnsToDrop = [];
            foreach (['cause', 'observation', 'treatment', 'prevention', 'symptoms'] as $col) {
                if (Schema::hasColumn('diseases', $col)) {
                    $columnsToDrop[] = $col;
                }
            }
            if (!empty($columnsToDrop)) {
                $table->dropColumn($columnsToDrop);
            }
        });
    }

    public function down(): void
    {
        Schema::table('diseases', function (Blueprint $table) {
            $table->text('cause')->nullable();
            $table->text('observation')->nullable();
            $table->text('treatment')->nullable();
            $table->text('prevention')->nullable();
        });
    }
};
