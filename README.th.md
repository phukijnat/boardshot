# Boardshot

แอปเล็กๆ บนแถบเมนูของ Mac ที่เก็บ screenshot ไว้ที่เดียว ถ่ายด้วยคีย์ลัดเดิม แล้วหา ดูภาพ ลากไปใช้ หรือลบ ได้จากหน้าต่างเดียว

[English](README.md)

> **Beta** Boardshot ยังใหม่และอยู่ระหว่างทดสอบ อาจมีบั๊กได้ เจออะไร[แจ้งได้ที่นี่](https://github.com/phukijnat/boardshot/issues/new/choose)

<!-- TODO: ใส่ภาพหน้าจอ docs/screenshot.png -->

- ถ่ายจอด้วยคีย์ลัดเดิม (`⌘⇧3`, `⌘⇧4`, `⌘⇧5`) ไฟล์จะไปอยู่ที่ `~/Pictures/Boardshot` แทน Desktop
- รูปเล็กมุมจอของระบบถูกแทนด้วยของ Boardshot ไฟล์จึงเข้าโฟลเดอร์ทันที
- อัปเดตในแอปได้ แอปจะบอกเมื่อมีเวอร์ชันใหม่และติดตั้งให้เอง
- มีภาษาไทยและอังกฤษ

ใช้ได้กับ macOS 14 ขึ้นไป ทั้งเครื่อง Apple Silicon และ Intel

## ติดตั้ง

1. โหลด `Boardshot-x.y.z.dmg` ตัวล่าสุดจาก [Releases](https://github.com/phukijnat/boardshot/releases)
2. เปิดไฟล์ แล้วลาก **Boardshot** ไปใส่ **Applications**
3. เปิด Boardshot จาก Applications

### ถ้าขึ้นว่า "Apple could not verify Boardshot…"
Boardshot ยังไม่ได้ผ่านการตรวจ (notarize) ของ Apple เพราะต้องสมัครบัญชีนักพัฒนาแบบเสียเงิน macOS เลยบล็อกตอนเปิดครั้งแรก ให้กด **Done** อย่ากด Move to Trash:

<img src="docs/first-launch-done.png" width="260" alt="หน้าต่าง Boardshot Not Opened วงปุ่ม Done ไว้">

จากนั้นทำแค่ครั้งเดียว:

- **macOS 15 ขึ้นไป:** กด **Done** แล้วไปที่ **System Settings → Privacy & Security** เลื่อนลงไปกด **Open Anyway** ข้าง Boardshot แล้วยืนยัน
- **macOS 14:** คลิกขวาที่ Boardshot ใน Applications เลือก **Open** แล้วกด **Open** อีกครั้ง

อัปเดตที่ติดตั้งจากในแอปไม่ต้องทำขั้นตอนนี้อีก

## วิธีใช้

| ทำอะไร | ทำยังไง |
|---|---|
| เปิด / ปิดหน้าต่าง | `⇧⌘Space` (เปลี่ยนได้ในหน้าตั้งค่า) หรือคลิกไอคอนกล้องบนแถบเมนู |
| ดูภาพใหญ่ | ชี้เมาส์ค้างบนรูป |
| เลือกหลายรูป | `⌘`+คลิก, `⇧`+คลิก, `⌘A` หรือลากคลุมพื้นที่ว่าง |
| ใช้รูป | ลากออกไปวาง หน้าต่างจะหายไปเอง |
| คัดลอก | `⌘C` |
| เปิดด้วย Preview | ดับเบิลคลิก หรือ `Return` |
| ลบ (ย้ายไปถังขยะ) | `⌫` |
| ลบทั้งหมด | ปุ่มถังขยะบนแถบหัว (ถามยืนยันก่อน) |
| ย้ายหน้าต่าง | ลากที่แถบหัว |
| ปิด | `Esc` หรือคลิกที่อื่น |

## ตั้งค่า

เปิดได้ 3 ทาง: ไอคอนกล้องบนแถบเมนู → ตั้งค่า…, ปุ่ม ⋯ ในหน้าต่าง Boardshot หรือกด `⌘,` ตอนหน้าต่างเปิดอยู่

- คีย์ลัดเปิดหน้าต่าง (ต้องมี `⌘`, `⌃` หรือ `⌥` อย่างน้อยหนึ่งตัว)
- ภาษา: ไทย / English
- เก็บ screenshot ไว้ที่ Boardshot: เปิด/ปิด
- รูปเล็กมุมจอหลังถ่าย
- เปิดอัตโนมัติตอนเข้าเครื่อง
- แสดงไอคอนบนแถบเมนู
- ตรวจหาอัปเดตอัตโนมัติ หรือกด **ตรวจเดี๋ยวนี้**

## Boardshot เปลี่ยนอะไรในเครื่อง

แอปเปลี่ยนค่าระบบ 2 ค่า (`com.apple.screencapture`: `location` กับ `show-thumbnail`) และจำค่าเดิมไว้ เอาติ๊ก "เก็บ screenshot ไว้ที่ Boardshot" ออกเมื่อไหร่ก็คืนค่าเดิมให้ แต่การปิดแอปจะไม่คืนค่า

## ลบแอป

1. ตั้งค่า… → เอาติ๊ก "เก็บ screenshot ไว้ที่ Boardshot" ออก
2. ออกจากแอป แล้วย้าย `/Applications/Boardshot.app` ไปถังขยะ

ถ้าลบแอปไปก่อนแล้ว คืนค่าเองได้ด้วยคำสั่งนี้:

```bash
defaults delete com.apple.screencapture location; defaults delete com.apple.screencapture show-thumbnail; killall SystemUIServer
```

รูปที่ถ่ายไว้ยังอยู่ที่ `~/Pictures/Boardshot`

## Build เอง

ต้องมี Xcode Command Line Tools (`xcode-select --install`)

```bash
./build.sh --install
```

ชื่อแอป, bundle ID, เวอร์ชัน และลิงก์อัปเดต อยู่ใน [`config.sh`](config.sh) วิธีปล่อยเวอร์ชันใหม่ดูใน [CONTRIBUTING.md](CONTRIBUTING.md)

## License

[MIT](LICENSE)
