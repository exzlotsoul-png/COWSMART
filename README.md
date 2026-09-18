# COWSMART

ระบบจัดการฟาร์มโคเนื้อครบวงจร (Farm Management System)

โปรเจกต์นี้แบ่งออกเป็น 3 ส่วนหลัก ได้แก่:

1. **API (Backend)** - สร้างด้วย Laravel
2. **Admin Web (Frontend)** - สร้างด้วย React + Vite
3. **COWSMART App (Mobile)** - สร้างด้วย Flutter

---

## 🛠 สิ่งที่ต้องมีในเครื่องก่อนติดตั้ง (Prerequisites)

ก่อนเริ่มติดตั้งและใช้งานโปรเจกต์ กรุณาตรวจสอบให้แน่ใจว่าเครื่องคอมพิวเตอร์ของคุณมีโปรแกรมเหล่านี้ติดตั้งอยู่:

- [PHP](https://windows.php.net/download/) (แนะนำเวอร์ชัน 8.2 ขึ้นไป) และ [Composer](https://getcomposer.org/)
- [Node.js](https://nodejs.org/) (แนะนำเวอร์ชัน 18 ขึ้นไป) และ npm
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [MySQL](https://www.mysql.com/) หรือใช้งานผ่าน XAMPP / MAMP สำหรับฐานข้อมูลจำลอง
- Android Studio หรือ VS Code

---

## 🚀 วิธีการติดตั้งและรันโปรเจกต์ (Setup Guide)

### 1. การตั้งค่าระบบหลังบ้าน (API / Backend)

ระบบ API สร้างด้วยเฟรมเวิร์ก Laravel ทำหน้าที่จัดการฐานข้อมูลและลอจิกทั้งหมด

1. เปิดเทอร์มินัลเข้าไปที่โฟลเดอร์ `api`:
   ```bash
   cd api
   ```
2. ติดตั้งไลบรารีที่จำเป็นผ่าน Composer:
   ```bash
   composer install
   ```
3. คัดลอกไฟล์ตั้งค่า Environment:
   ```bash
   cp .env.example .env
   ```
4. สร้าง Application Key:
   ```bash
   php artisan key:generate
   ```
5. **ตั้งค่าฐานข้อมูล:**
   - เปิดโปรแกรมจัดการฐานข้อมูล (เช่น phpMyAdmin หรือ TablePlus) สร้าง Database ใหม่ชื่อ `COWSMART`
   - เปิดไฟล์ `.env` ที่เพิ่งสร้างขึ้น และแก้ไขค่าให้ตรงกับฐานข้อมูลของคุณ:
     ```env
     DB_CONNECTION=mysql
     DB_HOST=127.0.0.1
     DB_PORT=3306
     DB_DATABASE=cowsmart
     DB_USERNAME=root
     DB_PASSWORD=
     ```
6. สร้างตารางในฐานข้อมูล (Migrate):
   ```bash
   php artisan migrate
   ```
7. สร้างโฟลเดอร์ลิงก์สำหรับเก็บรูปภาพอัปโหลด:
   ```bash
   php artisan storage:link
   ```
8. สั่งรันเซิร์ฟเวอร์ API:
   ```bash
   php artisan serve
   ```
   _เซิร์ฟเวอร์จะรันอยู่ที่ `http://localhost:8000` (ให้เปิดทิ้งไว้)_

---

### 2. การตั้งค่าเว็บผู้ดูแลระบบ (Admin Web / Frontend)

ระบบจัดการฟาร์มสำหรับแอดมิน สร้างด้วย React + Vite

1. เปิดเทอร์มินัล (หน้าต่างใหม่) เข้าไปที่โฟลเดอร์ `admin-web`:
   ```bash
   cd admin-web
   ```
2. ติดตั้งไลบรารีที่จำเป็นผ่าน npm:
   ```bash
   npm install
   ```
3. ตรวจสอบไฟล์ `.env` (ถ้ามี) ให้แน่ใจว่า API URL ชี้ไปที่ `http://localhost:8000` (หรือ URL ของเซิร์ฟเวอร์จริง)
4. สั่งรันระบบเว็บแอดมิน:
   ```bash
   npm run dev
   ```
   _ระบบจะแสดง URL บนเทอร์มินัล (เช่น `http://localhost:5173`) ให้คลิกเพื่อเปิดบนเบราว์เซอร์_

---

### 3. การตั้งค่าแอปพลิเคชันมือถือ (COWSMART / Mobile App)

แอปสำหรับผู้ใช้งานทั่วไป (เจ้าของฟาร์ม) สร้างด้วย Flutter

1. เปิดเทอร์มินัล (หน้าต่างใหม่) เข้าไปที่โฟลเดอร์ `COWSMART`:
   ```bash
   cd COWSMART
   ```
2. ติดตั้งแพ็กเกจที่จำเป็นสำหรับ Flutter:
   ```bash
   flutter pub get
   ```
3. **การตั้งค่า API URL:**
   - ตรวจสอบไฟล์ตั้งค่าเครือข่าย เช่น `lib/core/network/api_client.dart` หรือตำแหน่งที่มีการตั้งค่า Base URL
   - หากรันทดสอบบน Emulator (Android) และใช้เซิร์ฟเวอร์ในเครื่อง ให้ตั้ง URL เป็น `http://10.0.2.2:8000`
   - หากรันทดสอบบนอุปกรณ์จริง (เสียบสาย) ตรวจสอบให้แน่ใจว่ามือถือต่อ Wi-Fi วงเดียวกับคอมพิวเตอร์ และเปลี่ยน URL เป็น IP ของเครื่องคอมพิวเตอร์ (เช่น `http://192.168.1.x:8000`)
   - _หมายเหตุ: หากคุณใช้เซิร์ฟเวอร์ที่ออนไลน์แล้ว (เช่น Render) ก็สามารถใช้ URL ของ Render ได้เลย_
4. สั่งรันแอปพลิเคชัน:
   ```bash
   flutter run
   ```
   _ตรวจสอบให้แน่ใจว่าเปิด Emulator หรือเชื่อมต่อโทรศัพท์มือถือเรียบร้อยแล้ว_

---

## 📝 ข้อมูลเพิ่มเติม (Notes)

- การอัปโหลดรูปภาพในระบบจะมีการบันทึกลงใน **Cloudinary** (ตั้งค่า API Keys ในไฟล์ `.env` ฝั่ง `api` หากจำเป็น) หรือเซฟลง Storage ภายใน
- แอป Flutter มีการใช้งาน `flutter_image_compress` ในการบีบอัดรูปภาพก่อนอัปโหลด ซึ่งต้องการการรันแบบ Full Restart (`flutter run`) เมื่อมีการเพิ่มหรือแก้ไขแพ็กเกจนี้
