<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Cow;
use Illuminate\Support\Facades\DB;

class CleanDuplicateCows extends Command
{
    protected $signature = 'cows:clean-duplicates {--dry-run : Only show duplicates without deleting}';
    protected $description = 'Find and clean up duplicate cow records within the same farm';

    public function handle()
    {
        $dryRun = $this->option('dry-run');
        if ($dryRun) {
            $this->info('Running in DRY-RUN mode (no changes will be committed)...');
        }

        $allCows = Cow::all();
        $grouped = [];

        foreach ($allCows as $cow) {
            $farmId = $cow->farm_id ?? 'DEFAULT';
            $tagKey = !empty($cow->tag_number) ? mb_strtolower(trim($cow->tag_number)) : null;
            $nameKey = !empty($cow->name) ? mb_strtolower(trim($cow->name)) : null;

            $key = null;
            if ($tagKey) {
                $key = "tag:{$farmId}:{$tagKey}";
            } else if ($nameKey) {
                $key = "name:{$farmId}:{$nameKey}";
            }

            if ($key) {
                $grouped[$key][] = $cow;
            }
        }

        $duplicateGroupsCount = 0;
        $totalRemovedCount = 0;

        foreach ($grouped as $key => $cows) {
            if (count($cows) <= 1) {
                continue;
            }

            $duplicateGroupsCount++;
            $primaryCow = $cows[0]; // Keep the first created cow
            $duplicateCows = array_slice($cows, 1);

            $this->warn("พบวัวซ้ำกลุ่ม [{$key}] ปริมาณ " . count($cows) . " ตัว. ตัวหลัก: {$primaryCow->cow_id} ({$primaryCow->name} / {$primaryCow->tag_number})");

            foreach ($duplicateCows as $dupCow) {
                $this->line("  -> ซ้ำ: {$dupCow->cow_id} ({$dupCow->name} / {$dupCow->tag_number})");

                if (!$dryRun) {
                    DB::transaction(function () use ($primaryCow, $dupCow) {
                        // Re-link references in related tables if exists
                        DB::table('growth_records')->where('cow_id', $dupCow->cow_id)->update(['cow_id' => $primaryCow->cow_id]);
                        DB::table('health_records')->where('cow_id', $dupCow->cow_id)->update(['cow_id' => $primaryCow->cow_id]);
                        DB::table('breeding_records')->where('dam_id', $dupCow->cow_id)->update(['dam_id' => $primaryCow->cow_id]);
                        DB::table('breeding_records')->where('sire_id', $dupCow->cow_id)->update(['sire_id' => $primaryCow->cow_id]);
                        DB::table('breeding_records')->where('calf_id', $dupCow->cow_id)->update(['calf_id' => $primaryCow->cow_id]);
                        
                        if (SchemaHasTable('culling_records')) {
                            DB::table('culling_records')->where('cow_id', $dupCow->cow_id)->update(['cow_id' => $primaryCow->cow_id]);
                        }
                        if (SchemaHasTable('financial_records')) {
                            if (\Illuminate\Support\Facades\Schema::hasColumn('financial_records', 'related_cow_id')) {
                                DB::table('financial_records')->where('related_cow_id', $dupCow->cow_id)->update(['related_cow_id' => $primaryCow->cow_id]);
                            } else if (\Illuminate\Support\Facades\Schema::hasColumn('financial_records', 'cow_id')) {
                                DB::table('financial_records')->where('cow_id', $dupCow->cow_id)->update(['cow_id' => $primaryCow->cow_id]);
                            }
                        }

                        // Delete duplicate cow record
                        $dupCow->delete();
                    });
                    $totalRemovedCount++;
                }
            }
        }

        if ($dryRun) {
            $this->info("ตรวจสอบพบกลุ่มวัวซ้ำทั้งหมด {$duplicateGroupsCount} กลุ่ม");
        } else {
            $this->info("ทำความสะอาดวัวซ้ำสำเร็จ! รวมการลบวัวที่ซ้ำกันไปแล้ว {$totalRemovedCount} ตัว จาก {$duplicateGroupsCount} กลุ่ม");
        }
    }
}

function SchemaHasTable($table) {
    return \Illuminate\Support\Facades\Schema::hasTable($table);
}
