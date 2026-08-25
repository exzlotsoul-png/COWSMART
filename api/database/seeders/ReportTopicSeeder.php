<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ReportTopicSeeder extends Seeder
{
    public function run(): void
    {
        $topics = [
            ['id' => 'TOPIC001', 'name' => 'ปัญหาการใช้งานแอปพลิเคชัน'],
            ['id' => 'TOPIC002', 'name' => 'ข้อเสนอแนะ / ติชม'],
            ['id' => 'TOPIC003', 'name' => 'ปัญหาการคำนวณ / ข้อมูลวัว'],
            ['id' => 'TOPIC004', 'name' => 'ปัญหาบัญชีผู้ใช้ / ฟาร์ม'],
            ['id' => 'TOPIC005', 'name' => 'สอบถามการใช้งานทั่วไป'],
            ['id' => 'TOPIC006', 'name' => 'อื่นๆ'],
        ];

        foreach ($topics as $topic) {
            DB::table('report_topics')->updateOrInsert(
                ['id' => $topic['id']],
                [
                    'name' => $topic['name'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }
    }
}
