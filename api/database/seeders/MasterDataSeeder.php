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

        // 2. Medicines (ยา) - schema: medicine_id, category, name, indications, dosage_usage
        $medicines = [
            ['medicine_id' => 'MED001', 'category' => 'ยาปฏิชีวนะ', 'name' => 'เพนิซิลลิน (Penicillin)', 'indications' => 'รักษาการติดเชื้อแบคทีเรีย'],
            ['medicine_id' => 'MED002', 'category' => 'ยาปฏิชีวนะ', 'name' => 'อ็อกซิเตตราซีคลิน (Oxytetracycline)', 'indications' => 'รักษาโรคติดเชื้อทางเดินหายใจและทางเดินอาหาร'],
            ['medicine_id' => 'MED003', 'category' => 'ยาถ่ายพยาธิ', 'name' => 'อิโวร์เมกติน (Ivermectin)', 'indications' => 'ถ่ายพยาธิภายในและภายนอก'],
            ['medicine_id' => 'MED004', 'category' => 'ยาถ่ายพยาธิ', 'name' => 'เฟนเบนดาโซล (Fenbendazole)', 'indications' => 'ถ่ายพยาธิตัวกลมและพยาธิใบไม้'],
            ['medicine_id' => 'MED005', 'category' => 'ยาแก้ปวด/อักเสบ', 'name' => 'ฟลูนิกซิน (Flunixin Meglumine)', 'indications' => 'ลดไข้ แก้ปวด ลดการอักเสบ'],
            ['medicine_id' => 'MED006', 'category' => 'ยาแก้ปวด/อักเสบ', 'name' => 'เดกซาเมทาโซน (Dexamethasone)', 'indications' => 'ยาลดการอักเสบกลุ่มสเตอรอยด์'],
            ['medicine_id' => 'MED007', 'category' => 'วิตามินและแร่ธาตุ', 'name' => 'วิตามิน B คอมเพล็กซ์ (Vitamin B Complex)', 'indications' => 'บำรุงร่างกาย กระตุ้นการเจริญอาหาร'],
            ['medicine_id' => 'MED008', 'category' => 'วิตามินและแร่ธาตุ', 'name' => 'คัลเซียมบอรอน (Calcium Borogluconate)', 'indications' => 'รักษาโรคไข้นม ภาวะขาดแคลเซียม'],
            ['medicine_id' => 'MED009', 'category' => 'ยาสมุนไพร/จุลินทรีย์', 'name' => 'โพรไบโอติกส์ (Probiotics)', 'indications' => 'ปรับสมดุลจุลินทรีย์ในกระเพาะอาหาร'],
            ['medicine_id' => 'MED010', 'category' => 'ยากำจัดภายนอก', 'name' => 'ยาฆ่าเห็บหมัด (Ectoparasiticide)', 'indications' => 'กำจัดเห็บ หมัด ริ้น และแมลง'],
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

        // 3. Vaccines (วัคซีน) - schema: vaccine_id, category, name, indications, dosage_usage
        $vaccines = [
            ['vaccine_id' => 'VAC001', 'category' => 'วัคซีนโรคติดต่อร้ายแรง', 'name' => 'วัคซีนปากและเท้าเปื่อย (FMD)', 'indications' => 'ป้องกันโรคปากและเท้าเปื่อย'],
            ['vaccine_id' => 'VAC002', 'category' => 'วัคซีนโรคติดต่อร้ายแรง', 'name' => 'วัคซีนแบล็คเลก (Blackleg)', 'indications' => 'ป้องกันโรคโรคไข้ขาบวม (แบล็คเลก)'],
            ['vaccine_id' => 'VAC003', 'category' => 'วัคซีนระบบระบบสืบพันธุ์', 'name' => 'วัคซีนบรูเซลโลซิส (Brucellosis)', 'indications' => 'ป้องกันโรคเเท้งติดต่อ'],
            ['vaccine_id' => 'VAC004', 'category' => 'วัคซีนโรคติดต่อร้ายแรง', 'name' => 'วัคซีนเฮโมรายิกเซปทิซีเมีย (คอบวม)', 'indications' => 'ป้องกันโรคคอบวม'],
            ['vaccine_id' => 'VAC005', 'category' => 'วัคซีนระบบทางเดินหายใจ', 'name' => 'วัคซีนปอดบวม (Pneumonia Vaccine)', 'indications' => 'ป้องกันโรคติดเชื้อระบบทางเดินหายใจ'],
            ['vaccine_id' => 'VAC006', 'category' => 'วัคซีนโรคจากไวรัส', 'name' => 'วัคซีนไข้รากสาดน้ำคาง (MCF)', 'indications' => 'ป้องกันโรคไข้รากสาดน้ำคาง'],
            ['vaccine_id' => 'VAC007', 'category' => 'วัคซีนลูกวัว', 'name' => 'วัคซีนท้องเสียลูกวัว (Calf Scours)', 'indications' => 'ป้องกันโรคท้องเสียในลูกวัวแรกเกิด'],
            ['vaccine_id' => 'VAC008', 'category' => 'วัคซีนโรคจากแบคทีเรีย', 'name' => 'วัคซีนโคลีบาซิลโลซิส (Colibacillosis)', 'indications' => 'ป้องกันการติดเชื้อ E. coli ในลูกวัว'],
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

        // 4. Units (หน่วยวัด)
        $units = [
            ['unit_id' => 1, 'name' => 'มิลลิลิตร', 'type' => 'volume', 'abbreviation' => 'มล.'],
            ['unit_id' => 2, 'name' => 'ซีซี', 'type' => 'volume', 'abbreviation' => 'ซีซี'],
            ['unit_id' => 3, 'name' => 'โดส', 'type' => 'count', 'abbreviation' => 'โดส'],
            ['unit_id' => 4, 'name' => 'กรัม', 'type' => 'weight', 'abbreviation' => 'ก.'],
            ['unit_id' => 5, 'name' => 'กิโลกรัม', 'type' => 'weight', 'abbreviation' => 'กก.'],
            ['unit_id' => 6, 'name' => 'เม็ด', 'type' => 'count', 'abbreviation' => 'เม็ด'],
            ['unit_id' => 7, 'name' => 'ขวด', 'type' => 'container', 'abbreviation' => 'ขวด'],
            ['unit_id' => 8, 'name' => 'หลอด', 'type' => 'container', 'abbreviation' => 'หลอด'],
        ];

        foreach ($units as $unit) {
            DB::table('units')->updateOrInsert(
                ['unit_id' => $unit['unit_id']],
                array_merge($unit, [
                    'created_at' => now(),
                    'updated_at' => now(),
                ])
            );
        }

        // 5. Issue Reports (รายงานปัญหาการใช้งาน)
        $reports = [
            [
                'id' => 'REP001',
                'email' => 'thanapat.tienatnunt@gmail.com',
                'topic' => 'สอบถามขั้นตอนการเพิ่มบันทึกวัคซีน',
                'description' => 'อยากทราบว่าเมื่อบันทึกฉีดวัคซีนแล้ว สามารถเลือกหน่วยวัดโดสเพิ่มเติมได้จากตรงไหนครับ',
                'status' => 1,
                'created_at' => now()->subDays(3),
                'updated_at' => now()->subDays(2),
            ],
            [
                'id' => 'REP002',
                'email' => 'thanapat.tienatnunt@gmail.com',
                'topic' => 'กราฟการเติบโตแสดงผลช้า',
                'description' => 'เมื่อเลือกดูแท็บการเจริญเติบโตรวมของวัวขุน กราฟใช้เวลาโหลดเล็กน้อย',
                'status' => 0,
                'created_at' => now()->subDays(1),
                'updated_at' => now()->subDays(1),
            ],
            [
                'id' => 'REP003',
                'email' => 'admin@cowsmart.com',
                'topic' => 'เสนอเพิ่มระบบส่งการแจ้งเตือนทาง SMS',
                'description' => 'อยากให้ระบบส่ง SMS แจ้งเตือนวันกำหนดคลอดล่วงหน้า 3 วันครับ',
                'status' => 0,
                'created_at' => now()->subHours(5),
                'updated_at' => now()->subHours(2),
            ],
        ];

        foreach ($reports as $report) {
            DB::table('issue_reports')->updateOrInsert(
                ['id' => $report['id']],
                $report
            );
        }
        // 6. Appointment Types (ประเภทนัดหมาย)
        $appointmentTypes = [
            ['id' => 'APT001', 'name' => 'ฉีดวัคซีน/ถ่ายพยาธิ'],
            ['id' => 'APT002', 'name' => 'ตรวจสุขภาพประจำปี/ประจำเดือน'],
            ['id' => 'APT003', 'name' => 'ตรวจระบบสืบพันธุ์'],
            ['id' => 'APT004', 'name' => 'ติดตามผลการรักษา'],
            ['id' => 'APT005', 'name' => 'อื่นๆ'],
        ];

        foreach ($appointmentTypes as $type) {
            DB::table('appointment_types')->updateOrInsert(
                ['id' => $type['id']],
                array_merge($type, [
                    'created_at' => now(),
                    'updated_at' => now(),
                ])
            );
        }

        $this->command->info('Master data seeded successfully!');
        $this->command->info('- Diseases: ' . count($diseases));
        $this->command->info('- Medicines: ' . count($medicines));
        $this->command->info('- Vaccines: ' . count($vaccines));
        $this->command->info('- Units: ' . count($units));
        $this->command->info('- Issue Reports: ' . count($reports));
        $this->command->info('- Appointment Types: ' . count($appointmentTypes));
    }
}
