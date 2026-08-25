<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class HealthRecordSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Clear existing health records completely
        DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        DB::table('health_records')->truncate();
        DB::statement('SET FOREIGN_KEY_CHECKS=1;');

        $availableCows = DB::table('cows')->pluck('cow_id')->toArray();
        if (empty($availableCows)) {
            $availableCows = ['C001', 'C002', 'C003', 'C004', 'C005', 'C006', 'C007', 'C008', 'C009', 'C010', 'C011', 'C012', 'C013', 'C014', 'C015', 'C016', 'C017', 'C018', 'C019', 'C020', 'C021', 'C022', 'C023', 'C024', 'C025', 'C026', 'C027', 'C028', 'C029', 'C030', 'C031', 'C032', 'C033', 'C034'];
        }

        $records = [];
        $idCounter = 1;

        // Month 7 (กรกฎาคม 2569) - 4 diseases (4, 3, 2, 1 cases - all unique counts)
        $m7_data = [
            ['disease' => 'DIS001', 'counts' => 4, 'cost' => 1200, 'type' => 'CT03', 'notes' => 'ตรวจพบแผลในช่องปากและกีบเท้า ทำการล้างแผลและให้ยาปฏิชีวนะ'],
            ['disease' => 'DIS002', 'counts' => 3, 'cost' => 850,  'type' => 'CT03', 'notes' => 'พบตุ่มนูนตามลำตัว ฉีดยารักษาตามอาการและพ่นยากันแมลง'],
            ['disease' => 'DIS003', 'counts' => 2, 'cost' => 950,  'type' => 'CT03', 'notes' => 'กล้ามเนื้อสะโพกบวม มีไข้สูง ให้ยาต้านเชื้อแบคทีเรีย'],
            ['disease' => 'DIS004', 'counts' => 1, 'cost' => 500,  'type' => 'CT03', 'notes' => 'ท้องอืดซ้าย สวนท่อระบายแก๊สและกรอกยาลดฟอง'],
        ];

        // Month 8 (สิงหาคม 2569) - 3 diseases (5, 3, 1 cases - all unique counts)
        $m8_data = [
            ['disease' => 'DIS002', 'counts' => 5, 'cost' => 850,  'type' => 'CT03', 'notes' => 'พบตุ่มลัมปีสกิน รักษาแผลภายนอกและให้ยาลดไข้'],
            ['disease' => 'DIS003', 'counts' => 3, 'cost' => 950,  'type' => 'CT03', 'notes' => 'อาการแบล็คเลก ขาบวมเจ็บ ให้ยาเพนิซิลลิน'],
            ['disease' => 'DIS005', 'counts' => 1, 'cost' => 600,  'type' => 'CT03', 'notes' => 'เจาะเลือดพบพยาธิในเม็ดเลือด ฉีดยาฆ่าพยาธิและวิตามินบำรุง'],
        ];

        // Month 9 (กันยายน 2569) - 4 diseases (6, 4, 2, 1 cases - all unique counts)
        $m9_data = [
            ['disease' => 'DIS003', 'counts' => 6, 'cost' => 950,  'type' => 'CT03', 'notes' => 'ระบาดในแปลงหญ้า กล้ามเนื้อบวม ให้ยาต้านจุลชีพ'],
            ['disease' => 'DIS001', 'counts' => 4, 'cost' => 1200, 'type' => 'CT03', 'notes' => 'ปากเปื่อย น้ำลายไหล ย้ายเข้าคอกกักและรักษา'],
            ['disease' => 'DIS010', 'counts' => 2, 'cost' => 750,  'type' => 'CT03', 'notes' => 'เต้านมอักเสบ น้ำนมขุ่น สอดยารักษาเต้านม'],
            ['disease' => 'DIS006', 'counts' => 1, 'cost' => 800,  'type' => 'CT03', 'notes' => 'ปอดบวม หายใจหอบ ให้ยาขยายหลอดลมและยาฆ่าเชื้อ'],
        ];

        // Month 10 (ตุลาคม 2569) - 3 diseases (4, 2, 1 cases - all unique counts)
        $m10_data = [
            ['disease' => 'DIS005', 'counts' => 4, 'cost' => 650,  'type' => 'CT03', 'notes' => 'ซูบผอม โลหิตจางจากพยาธิ ฉีดยาบำรุงเลือด'],
            ['disease' => 'DIS004', 'counts' => 2, 'cost' => 500,  'type' => 'CT03', 'notes' => 'กินอาหารข้นมากเกินไป ท้องอืด ให้ยาระบายและลดกรด'],
            ['disease' => 'DIS001', 'counts' => 1, 'cost' => 1100, 'type' => 'CT03', 'notes' => 'แผลที่กีบเท้า ล้างแผลใส่ยาและพันแผล'],
        ];

        $allMonths = [
            7 => $m7_data,
            8 => $m8_data,
            9 => $m9_data,
            10 => $m10_data,
        ];

        $cowIdx = 0;
        foreach ($allMonths as $month => $diseaseGroups) {
            $day = 3;
            foreach ($diseaseGroups as $group) {
                for ($i = 0; $i < $group['counts']; $i++) {
                    $assignedCow = $availableCows[$cowIdx % count($availableCows)];
                    $cowIdx++;

                    $recordDate = Carbon::create(2026, $month, min($day, 28), rand(8, 16), rand(10, 50))->toDateTimeString();
                    $day += 2;

                    $records[] = [
                        'health_record_id' => 'HR' . str_pad($idCounter++, 4, '0', STR_PAD_LEFT),
                        'cow_id' => $assignedCow,
                        'record_date' => $recordDate,
                        'checkup_type_id' => $group['type'],
                        'disease_id' => $group['disease'],
                        'cost' => $group['cost'],
                        'admin_name' => 'หมอสมหมาย สัตวแพทย์',
                        'created_at' => $recordDate,
                        'updated_at' => $recordDate,
                    ];
                }
            }
        }

        foreach ($records as $record) {
            DB::table('health_records')->insert($record);
        }
    }
}
