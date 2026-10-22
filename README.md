# เจ้าเหมียว

แอปค้นหาพนักงานบนมือถือ ข้อมูลอยู่ที่เครื่องใน SQLite ครั้งแรกที่เปิดจะนำเข้าจาก `assets/employees.csv` หลังจากนั้นเปิดใช้ได้โดยไม่ต้องต่อเน็ต

ใช้ Flutter **3.38.7** ตามไฟล์ `.fvmrc`

## เตรียมเครื่อง

ติดตั้ง [Flutter 3.38.7](https://docs.flutter.dev/install) หรือใช้ FVM:

```bash
fvm install
fvm flutter pub get
```

ถ้าไม่ได้ใช้ FVM ให้เรียก `flutter` แทน `fvm flutter` ในคำสั่งด้านล่าง

วางไฟล์ข้อมูลที่ `assets/employees.csv` ไฟล์นี้ไม่ถูกเก็บใน git เพราะมีเบอร์โทรและอีเมล แถวหัวตารางต้องมีคอลัมน์เหล่านี้ ลำดับไม่สำคัญ และมีคอลัมน์เกินมาได้:

`person_id`, `first_name`, `last_name`, `first_name_alt1`, `last_name_alt1`, `nick_name`, `employee_status`, `position_desc`, `employee_type`, `company`, `business_name`, `division_hq_name`, `division_branch_name`, `section_name`, `unit_name`, `supervisor`, `branch_name`, `location_desc`, `mobile_phone`, `business_phone`, `email_company`, `hire_date`, `resign_date`, `termination_date`, `last_working_date`

## รัน

```bash
fvm flutter devices
fvm flutter run -d <รหัสเครื่อง>
```

- Android: เปิดเครื่องจำลองหรือเสียบเครื่อง แล้วเลือกรหัสจาก `flutter devices`
- iPhone จำลอง: เลือกรายการที่เป็น simulator

ครั้งแรกแอปจะแสดงความคืบหน้าตอนบันทึกข้อมูลลงเครื่อง พอครบแล้วจะเข้าหน้าค้นหา

## ติดตั้งบน iPhone จริง

เครื่องต้องเป็น iOS 15 ขึ้นไป

1. เสียบสาย ปลดล็อกเครื่อง แล้วกด **Trust** เมื่อถามว่าเชื่อถือคอมพิวเตอร์นี้
2. เปิด **Settings → Privacy & Security → Developer Mode** แล้วรีสตาร์ทถ้าเครื่องถาม
3. เปิด Xcode ไปที่ **Settings → Accounts** ล็อกอิน Apple ID จากนั้นเปิด `ios/Runner.xcworkspace` แล้วที่ **Signing & Capabilities** เลือกทีมของตัวเอง
4. ติดตั้งแบบใช้งานเองได้โดยไม่ต้องเปิดโหมดดีบัก

```bash
fvm flutter devices
fvm flutter run --release -d <รหัสเครื่อง>
```

ครั้งแรกที่เปิดไอคอนบนเครื่อง ไปที่ **Settings → General → VPN & Device Management** แล้วเชื่อถือใบรับรองนักพัฒนา บัญชีนักพัฒนาฟรีใช้ได้ประมาณ 7 วัน แล้วต้องติดตั้งใหม่

## ทดสอบ

```bash
fvm flutter test
```
