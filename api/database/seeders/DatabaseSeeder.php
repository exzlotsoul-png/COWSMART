<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Breed;
use App\Models\CowType;
use App\Models\CheckupType;
use App\Models\Farm;
use App\Models\Zone;
use App\Models\Cow;
use App\Models\FinancialRecord;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // 1. Users
        User::firstOrCreate(
            ['email' => 'admin@cowsmart.com'],
            [
                'password' => Hash::make('password'),
                'first_name' => 'ธนินท์',
                'last_name' => 'เกษตรกร',
                'role' => '1',
                'created_at' => now(),
            ]
        );

        // 2. Master Data
        Breed::firstOrCreate(['breed_id' => 'B001'], ['name' => 'บราห์มันเบอร์แดง', 'description' => 'ทนทานต่อสภาพอากาศร้อน']);
        Breed::firstOrCreate(['breed_id' => 'B002'], ['name' => 'แองกัส (Angus)', 'description' => 'ให้เนื้อคุณภาพดี ไขมันแทรกสูง']);
        Breed::firstOrCreate(['breed_id' => 'B003'], ['name' => 'ชาร์โรเลส์ (Charolais)', 'description' => 'วัวเนื้อขนาดใหญ่ โตเร็ว']);
        Breed::firstOrCreate(['breed_id' => 'B004'], ['name' => 'เฮียฟอร์ด (Hereford)', 'description' => 'ทนทาน เลี้ยงง่าย ให้เนื้อคุณภาพดี']);
        Breed::firstOrCreate(['breed_id' => 'B005'], ['name' => 'ซิมเมนทัล (Simmental)', 'description' => 'วัวเอนกประสงค์ ให้ทั้งนมและเนื้อ']);
        Breed::firstOrCreate(['breed_id' => 'B006'], ['name' => 'วากิว (Wagyu)', 'description' => 'เนื้อนุ่ม มีลายไขมันแทรกสวยงาม']);
        Breed::firstOrCreate(['breed_id' => 'B007'], ['name' => 'ลิมูซิน (Limousin)', 'description' => 'กล้ามเนื้อแน่น โครงสร้างใหญ่']);
        Breed::firstOrCreate(['breed_id' => 'B008'], ['name' => 'โฮลสไตน์ ฟรีเชียน (Holstein Friesian)', 'description' => 'วัวนม พันธุ์ขาว-ดำ ให้ปริมาณน้ำนมสูง']);
        Breed::firstOrCreate(['breed_id' => 'B009'], ['name' => 'กำแพงแสน (Kamphaeng Saen)', 'description' => 'วัวเนื้อพันธุ์ปรับปรุงของไทย ทนร้อน']);
        Breed::firstOrCreate(['breed_id' => 'B010'], ['name' => 'ตาก (Tak Beef)', 'description' => 'ลูกผสมตาก ทนโรคและแมลง']);
        Breed::firstOrCreate(['breed_id' => 'B011'], ['name' => 'วัวพื้นเมืองไทย (Thai Native)', 'description' => 'วัวพื้นเมือง ทนทาน ปรับตัวเข้ากับสภาพแวดล้อมได้ดี']);
        Breed::firstOrCreate(['breed_id' => 'B012'], ['name' => 'บราห์มันเทา (Grey Brahman)', 'description' => 'โครงสร้างใหญ่ ทนทานต่ออากาศร้อน']);
        Breed::firstOrCreate(['breed_id' => 'B013'], ['name' => 'ลูกผสม (Crossbred)', 'description' => 'วัวลูกผสมข้ามสายพันธุ์']);
        
        CowType::firstOrCreate(['cow_type_id' => 'T001'], ['cow_type_name' => 'พ่อพันธุ์']);
        CowType::firstOrCreate(['cow_type_id' => 'T002'], ['cow_type_name' => 'แม่พันธุ์']);
        CowType::firstOrCreate(['cow_type_id' => 'T003'], ['cow_type_name' => 'วัวขุน']);
        CowType::firstOrCreate(['cow_type_id' => 'T004'], ['cow_type_name' => 'ลูกวัว']);

        CheckupType::firstOrCreate(['checkup_types_id' => 'CT01'], ['type_name' => 'ตรวจสุขภาพประจำปี']);
        CheckupType::firstOrCreate(['checkup_types_id' => 'CT02'], ['type_name' => 'ฉีดวัคซีน']);
        CheckupType::firstOrCreate(['checkup_types_id' => 'CT03'], ['type_name' => 'ให้ยารักษา']);
        CheckupType::firstOrCreate(['checkup_types_id' => 'CT04'], ['type_name' => 'ถ่ายพยาธิ']);

        // Run MasterDataSeeder for diseases, medicines, vaccines
        $this->call(MasterDataSeeder::class);

        // 3. Farm & Zones
        Farm::firstOrCreate(
            ['farm_id' => 'F001'],
            [
                'email' => 'admin@cowsmart.com',
                'name' => 'ฟาร์มโชคดี',
                'address' => '123 หมู่ 4 ต.เมืองช้าง อ.เมือง จ.ชัยนาท',
            ]
        );

        Zone::firstOrCreate(['zone_id' => 'Z001'], ['farm_id' => 'F001', 'name' => 'คอกแม่พันธุ์']);
        Zone::firstOrCreate(['zone_id' => 'Z002'], ['farm_id' => 'F001', 'name' => 'คอกขุน ก.']);

        // 4. Cows
        Cow::firstOrCreate(
            ['cow_id' => 'C001'],
            [
                'farm_id' => 'F001',
                'zone_id' => 'Z001',
                'breed_id' => 'B001',
                'cow_type_id' => 'T002',
                'tag_number' => 'TH-001',
                'name' => 'ทองคำ',
                'birth_date' => '2022-03-15',
                'gender' => 'F',
                'status' => 'normal',
            ]
        );

        Cow::firstOrCreate(
            ['cow_id' => 'C002'],
            [
                'farm_id' => 'F001',
                'zone_id' => 'Z002',
                'breed_id' => 'B002',
                'cow_type_id' => 'T003',
                'tag_number' => 'TH-002',
                'name' => 'เจ้าพายุ',
                'birth_date' => '2023-01-10',
                'gender' => 'M',
                'status' => 'normal',
            ]
        );

        Cow::firstOrCreate(
            ['cow_id' => 'C013'],
            [
                'farm_id' => 'F001',
                'zone_id' => 'Z001',
                'breed_id' => 'B001',
                'cow_type_id' => 'T002',
                'tag_number' => 'TH-003',
                'name' => 'ร่ำรวย',
                'birth_date' => '2022-05-12',
                'gender' => 'F',
                'latest_weight' => 470.00,
                'purchase_price' => 45000.00,
                'status' => 'normal',
            ]
        );

        Cow::firstOrCreate(
            ['cow_id' => 'C014'],
            [
                'farm_id' => 'F001',
                'zone_id' => 'Z002',
                'breed_id' => 'B003',
                'cow_type_id' => 'T003',
                'tag_number' => 'TH-004',
                'name' => 'ขุนทัพ',
                'birth_date' => '2023-02-18',
                'gender' => 'M',
                'latest_weight' => 420.00,
                'purchase_price' => 40000.00,
                'status' => 'normal',
            ]
        );

        Cow::firstOrCreate(
            ['cow_id' => 'C015'],
            [
                'farm_id' => 'F001',
                'zone_id' => 'Z001',
                'breed_id' => 'B004',
                'cow_type_id' => 'T002',
                'tag_number' => 'TH-005',
                'name' => 'สายฝน',
                'birth_date' => '2022-09-05',
                'gender' => 'F',
                'latest_weight' => 440.00,
                'purchase_price' => 42000.00,
                'status' => 'normal',
            ]
        );

        Cow::firstOrCreate(
            ['cow_id' => 'C016'],
            [
                'farm_id' => 'F001',
                'zone_id' => 'Z002',
                'breed_id' => 'B006',
                'cow_type_id' => 'T003',
                'tag_number' => 'TH-006',
                'name' => 'ซูโม่',
                'birth_date' => '2023-07-22',
                'gender' => 'M',
                'latest_weight' => 390.00,
                'purchase_price' => 50000.00,
                'status' => 'normal',
            ]
        );

        // User thanapat.tienatnunt@gmail.com
        $userEmail = 'thanapat.tienatnunt@gmail.com';
        User::firstOrCreate(
            ['email' => $userEmail],
            [
                'password' => Hash::make('123456'),
                'first_name' => 'ธนภัทร',
                'last_name' => 'เทียรนันท์',
                'role' => '1',
                'created_at' => now(),
            ]
        );

        // Farm 0: ฟาร์มยินดี (F-7ede35e7) ของคุณ thanapat.tienatnunt@gmail.com
        Cow::firstOrCreate(
            ['cow_id' => 'C017'],
            [
                'farm_id' => 'F-7ede35e7',
                'zone_id' => 'Z-16511431',
                'breed_id' => 'B001',
                'cow_type_id' => 'T001',
                'tag_number' => 'YD-001',
                'name' => 'บราโว่',
                'birth_date' => '2021-04-10',
                'gender' => 'M',
                'latest_weight' => 620.00,
                'purchase_price' => 70000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C018'],
            [
                'farm_id' => 'F-7ede35e7',
                'zone_id' => 'Z-5e876a56',
                'breed_id' => 'B001',
                'cow_type_id' => 'T002',
                'tag_number' => 'YD-002',
                'name' => 'สร้อยทอง',
                'birth_date' => '2022-02-14',
                'gender' => 'F',
                'latest_weight' => 460.00,
                'purchase_price' => 43000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C019'],
            [
                'farm_id' => 'F-7ede35e7',
                'zone_id' => 'Z-cf5e3727',
                'breed_id' => 'B002',
                'cow_type_id' => 'T003',
                'tag_number' => 'YD-003',
                'name' => 'พลายแก้ว',
                'birth_date' => '2023-01-20',
                'gender' => 'M',
                'latest_weight' => 400.00,
                'purchase_price' => 39000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C020'],
            [
                'farm_id' => 'F-7ede35e7',
                'zone_id' => 'Z-cf5e3727',
                'breed_id' => 'B003',
                'cow_type_id' => 'T003',
                'tag_number' => 'YD-004',
                'name' => 'ยอดขุนพล',
                'birth_date' => '2023-05-11',
                'gender' => 'M',
                'latest_weight' => 430.00,
                'purchase_price' => 41000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C021'],
            [
                'farm_id' => 'F-7ede35e7',
                'zone_id' => 'Z-28f2af6d',
                'breed_id' => 'B006',
                'cow_type_id' => 'T004',
                'tag_number' => 'YD-005',
                'name' => 'นำโชค',
                'birth_date' => '2024-03-05',
                'gender' => 'F',
                'latest_weight' => 115.00,
                'purchase_price' => 22000.00,
                'status' => 'normal',
            ]
        );

        // Farm 1: ฟาร์มธนภัทร 1 (โคเนื้อ)
        Farm::firstOrCreate(
            ['farm_id' => 'F002'],
            [
                'email' => $userEmail,
                'name' => 'ธนภัทรฟาร์ม โคเนื้อ',
                'address' => '45/1 หมู่ 2 ต.หนองบัว อ.เมือง จ.กาญจนบุรี',
            ]
        );
        Zone::firstOrCreate(['zone_id' => 'Z003'], ['farm_id' => 'F002', 'name' => 'คอกพ่อพันธุ์-แม่พันธุ์']);
        Zone::firstOrCreate(['zone_id' => 'Z004'], ['farm_id' => 'F002', 'name' => 'คอกวัวขุนเนื้อ']);

        // 5 Cows for Farm 1
        Cow::firstOrCreate(
            ['cow_id' => 'C003'],
            [
                'farm_id' => 'F002',
                'zone_id' => 'Z003',
                'breed_id' => 'B001',
                'cow_type_id' => 'T001',
                'tag_number' => 'TP-001',
                'name' => 'ขุนศึก',
                'birth_date' => '2021-05-10',
                'gender' => 'M',
                'latest_weight' => 650.00,
                'purchase_price' => 75000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C004'],
            [
                'farm_id' => 'F002',
                'zone_id' => 'Z003',
                'breed_id' => 'B001',
                'cow_type_id' => 'T002',
                'tag_number' => 'TP-002',
                'name' => 'มะลิ',
                'birth_date' => '2022-01-15',
                'gender' => 'F',
                'latest_weight' => 480.00,
                'purchase_price' => 45000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C005'],
            [
                'farm_id' => 'F002',
                'zone_id' => 'Z004',
                'breed_id' => 'B002',
                'cow_type_id' => 'T003',
                'tag_number' => 'TP-003',
                'name' => 'แบล็ค',
                'birth_date' => '2023-03-20',
                'gender' => 'M',
                'latest_weight' => 380.00,
                'purchase_price' => 38000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C006'],
            [
                'farm_id' => 'F002',
                'zone_id' => 'Z004',
                'breed_id' => 'B003',
                'cow_type_id' => 'T003',
                'tag_number' => 'TP-004',
                'name' => 'ขาวผ่อง',
                'birth_date' => '2023-06-12',
                'gender' => 'M',
                'latest_weight' => 410.00,
                'purchase_price' => 42000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C007'],
            [
                'farm_id' => 'F002',
                'zone_id' => 'Z003',
                'breed_id' => 'B006',
                'cow_type_id' => 'T004',
                'tag_number' => 'TP-005',
                'name' => 'เจ้าจิ๋ว',
                'birth_date' => '2024-02-01',
                'gender' => 'F',
                'latest_weight' => 120.00,
                'purchase_price' => 25000.00,
                'status' => 'normal',
            ]
        );

        // Farm 2: ธนภัทรฟาร์ม สมาร์ทแดรี่ (โคนมและผสม)
        Farm::firstOrCreate(
            ['farm_id' => 'F003'],
            [
                'email' => $userEmail,
                'name' => 'ธนภัทรฟาร์ม สมาร์ทแดรี่',
                'address' => '88 หมู่ 5 ต.มิตรภาพ อ.มวกเหล็ก จ.สระบุรี',
            ]
        );
        Zone::firstOrCreate(['zone_id' => 'Z005'], ['farm_id' => 'F003', 'name' => 'คอกโคนมปลดรีด']);
        Zone::firstOrCreate(['zone_id' => 'Z006'], ['farm_id' => 'F003', 'name' => 'คอกลูกวัวและวัวรุ่น']);

        // 5 Cows for Farm 2
        Cow::firstOrCreate(
            ['cow_id' => 'C008'],
            [
                'farm_id' => 'F003',
                'zone_id' => 'Z005',
                'breed_id' => 'B008',
                'cow_type_id' => 'T002',
                'tag_number' => 'TM-001',
                'name' => 'ดวงดาว',
                'birth_date' => '2021-08-25',
                'gender' => 'F',
                'latest_weight' => 520.00,
                'purchase_price' => 55000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C009'],
            [
                'farm_id' => 'F003',
                'zone_id' => 'Z005',
                'breed_id' => 'B008',
                'cow_type_id' => 'T002',
                'tag_number' => 'TM-002',
                'name' => 'ขวัญใจ',
                'birth_date' => '2022-04-18',
                'gender' => 'F',
                'latest_weight' => 490.00,
                'purchase_price' => 50000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C010'],
            [
                'farm_id' => 'F003',
                'zone_id' => 'Z006',
                'breed_id' => 'B005',
                'cow_type_id' => 'T002',
                'tag_number' => 'TM-003',
                'name' => 'สร้อยเพชร',
                'birth_date' => '2022-11-30',
                'gender' => 'F',
                'latest_weight' => 460.00,
                'purchase_price' => 48000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C011'],
            [
                'farm_id' => 'F003',
                'zone_id' => 'Z006',
                'breed_id' => 'B009',
                'cow_type_id' => 'T003',
                'tag_number' => 'TM-004',
                'name' => 'สิงโต',
                'birth_date' => '2023-05-14',
                'gender' => 'M',
                'latest_weight' => 350.00,
                'purchase_price' => 32000.00,
                'status' => 'normal',
            ]
        );
        Cow::firstOrCreate(
            ['cow_id' => 'C012'],
            [
                'farm_id' => 'F003',
                'zone_id' => 'Z006',
                'breed_id' => 'B011',
                'cow_type_id' => 'T004',
                'tag_number' => 'TM-005',
                'name' => 'ทองดี',
                'birth_date' => '2024-01-10',
                'gender' => 'M',
                'latest_weight' => 110.00,
                'purchase_price' => 18000.00,
                'status' => 'normal',
            ]
        );
    }
}
