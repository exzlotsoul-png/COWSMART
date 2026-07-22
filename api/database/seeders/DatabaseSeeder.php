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
        User::create([
            'email' => 'admin@cowsmart.com',
            'password' => Hash::make('password'),
            'first_name' => 'ธนินท์',
            'last_name' => 'เกษตรกร',
            'role' => '1', // Using short role as per schema
            'created_at' => now(),
        ]);

        // 2. Master Data
        Breed::create(['breed_id' => 'B001', 'name' => 'บราห์มันเบอร์แดง', 'description' => 'ทนทานต่อสภาพอากาศร้อน']);
        Breed::create(['breed_id' => 'B002', 'name' => 'แองกัส', 'description' => 'ให้เนื้อคุณภาพดี']);
        
        CowType::create(['cow_type_id' => 'T001', 'cow_type_name' => 'พ่อพันธุ์']);
        CowType::create(['cow_type_id' => 'T002', 'cow_type_name' => 'แม่พันธุ์']);
        CowType::create(['cow_type_id' => 'T003', 'cow_type_name' => 'วัวขุน']);
        CowType::create(['cow_type_id' => 'T004', 'cow_type_name' => 'ลูกวัว']);

        CheckupType::create(['checkup_types_id' => 'CT01', 'type_name' => 'ตรวจสุขภาพประจำปี']);
        CheckupType::create(['checkup_types_id' => 'CT02', 'type_name' => 'ฉีดวัคซีน']);
        CheckupType::create(['checkup_types_id' => 'CT03', 'type_name' => 'ให้ยารักษา']);
        CheckupType::create(['checkup_types_id' => 'CT04', 'type_name' => 'ถ่ายพยาธิ']);

        // Run MasterDataSeeder for diseases, medicines, vaccines
        $this->call(MasterDataSeeder::class);

        // 3. Farm & Zones
        Farm::create([
            'farm_id' => 'F001',
            'email' => 'admin@cowsmart.com',
            'name' => 'ฟาร์มโชคดี',
            'address' => '123 หมู่ 4 ต.เมืองช้าง อ.เมือง จ.ชัยนาท',
        ]);

        Zone::create(['zone_id' => 'Z001', 'farm_id' => 'F001', 'name' => 'คอกแม่พันธุ์']);
        Zone::create(['zone_id' => 'Z002', 'farm_id' => 'F001', 'name' => 'คอกขุน ก.']);

        // 4. Cows
        Cow::create([
            'cow_id' => 'C001',
            'farm_id' => 'F001',
            'zone_id' => 'Z001',
            'breed_id' => 'B001',
            'cow_type_id' => 'T002',
            'tag_number' => 'TH-001',
            'name' => 'ทองคำ',
            'birth_date' => '2022-03-15',
            'gender' => 'F',
            'status' => 'normal',
        ]);

        Cow::create([
            'cow_id' => 'C002',
            'farm_id' => 'F001',
            'zone_id' => 'Z002',
            'breed_id' => 'B002',
            'cow_type_id' => 'T003',
            'tag_number' => 'TH-002',
            'name' => 'เจ้าพายุ',
            'birth_date' => '2023-01-10',
            'gender' => 'M',
            'status' => 'normal',
        ]);

        // 5. Financial Records
        FinancialRecord::create([
            'financial_record_id' => 'TX001',
            'farm_id' => 'F001',
            'transaction_date' => now(),
            'trans_type' => 'income',
            'category' => 'Cow Sale',
            'amount' => 85000.00,
        ]);
        
        FinancialRecord::create([
            'financial_record_id' => 'TX002',
            'farm_id' => 'F001',
            'transaction_date' => now()->subDays(2),
            'trans_type' => 'expense',
            'category' => 'Feed',
            'amount' => 4500.00,
        ]);
    }
}
