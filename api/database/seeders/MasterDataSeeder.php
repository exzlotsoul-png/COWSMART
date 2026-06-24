<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class MasterDataSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Diseases (โรค) - schema: disease_id, name
        $diseases = [
            ['disease_id' => 'DIS001', 'name' => 'อหิวาต์โค (FMD) - เชื้อไวรัส'],
            ['disease_id' => 'DIS002', 'name' => 'ปากเปื่อย - เชื้อไวรัส'],
            ['disease_id' => 'DIS003', 'name' => 'แบล็คเลก - แบคทีเรีย'],
            ['disease_id' => 'DIS004', 'name' => 'ปอดบวม - เชื้อแบคทีเรีย/ไวรัส'],
            ['disease_id' => 'DIS005', 'name' => 'โรคผิวหนัง - เชื้อรา/แบคทีเรีย'],
            ['disease_id' => 'DIS006', 'name' => 'พยาธิในท้อง - พยาธิตัวกลม/ตัวตืด'],
            ['disease_id' => 'DIS007', 'name' => 'เห็บหมัด - เห็บ หมัด'],
            ['disease_id' => 'DIS008', 'name' => 'ตัวอ่อน (ท้องเสีย) - เชื้อแบคทีเรีย/ไวรัส'],
            ['disease_id' => 'DIS009', 'name' => 'ติดเชื้อแบคทีเรีย - แบคทีเรีย'],
            ['disease_id' => 'DIS010', 'name' => 'ท้องอืด - กินอาหารมากเกิน'],
        ];

        foreach ($diseases as $disease) {
            DB::table('diseases')->updateOrInsert(
                ['disease_id' => $disease['disease_id']],
                array_merge($disease, [
                    'created_at' => now(),
                    'updated_at' => now(),
                ])
            );
        }

        // 2. Medicines (ยา) - schema: medicine_id, name
        $medicines = [
            ['medicine_id' => 'MED001', 'name' => 'เพนิซิลลิน (ยาปฏิชีวนะ)'],
            ['medicine_id' => 'MED002', 'name' => 'อ็อกซิเตตราซีคลิน (ยาปฏิชีวนะ)'],
            ['medicine_id' => 'MED003', 'name' => 'อิโวร์เมกติน (ยาถ่ายพยาธิ)'],
            ['medicine_id' => 'MED004', 'name' => 'เฟนเบนดาโซล (ยาถ่ายพยาธิ)'],
            ['medicine_id' => 'MED005', 'name' => 'ฟลูนิกซิน (ยาแก้อักเสบ)'],
            ['medicine_id' => 'MED006', 'name' => 'เดกซาเมทาโซน (สเตอรอยด์)'],
            ['medicine_id' => 'MED007', 'name' => 'วิตามิน B คอมเพล็กซ์'],
            ['medicine_id' => 'MED008', 'name' => 'คัลเซียมบอรอน (แร่ธาตุ)'],
            ['medicine_id' => 'MED009', 'name' => 'โพรไบโอติกส์ (จุลินทรีย์)'],
            ['medicine_id' => 'MED010', 'name' => 'ยาฆ่าเห็บหมัด (ยาภายนอก)'],
        ];

        foreach ($medicines as $medicine) {
            DB::table('medicines')->updateOrInsert(
                ['medicine_id' => $medicine['medicine_id']],
                array_merge($medicine, [
                    'created_at' => now(),
                    'updated_at' => now(),
                ])
            );
        }

        // 3. Vaccines (วัคซีน) - schema: vaccine_id, name
        $vaccines = [
            ['vaccine_id' => 'VAC001', 'name' => 'วัคซีนอหิวาต์โค (FMD)'],
            ['vaccine_id' => 'VAC002', 'name' => 'วัคซีนแบล็คเลก'],
            ['vaccine_id' => 'VAC003', 'name' => 'วัคซีนบรูเซลโลซิส'],
            ['vaccine_id' => 'VAC004', 'name' => 'วัคซีนปากเปื่อย'],
            ['vaccine_id' => 'VAC005', 'name' => 'วัคซีนปอดบวม'],
            ['vaccine_id' => 'VAC006', 'name' => 'วัคซีนไข้รากสาดน้ำคาง'],
            ['vaccine_id' => 'VAC007', 'name' => 'วัคซีนตัวอ่อน (ลูกวัว)'],
            ['vaccine_id' => 'VAC008', 'name' => 'วัคซีนโคลีบาซิลโลซิส'],
        ];

        foreach ($vaccines as $vaccine) {
            DB::table('vaccines')->updateOrInsert(
                ['vaccine_id' => $vaccine['vaccine_id']],
                array_merge($vaccine, [
                    'created_at' => now(),
                    'updated_at' => now(),
                ])
            );
        }

        $this->command->info('Master data seeded successfully!');
        $this->command->info('- Diseases: ' . count($diseases));
        $this->command->info('- Medicines: ' . count($medicines));
        $this->command->info('- Vaccines: ' . count($vaccines));
    }
}
