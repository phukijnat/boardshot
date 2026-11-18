<div align="center">
  <img src="Resources/AppIcon-preview.png" width="128" alt="ไอคอน Boardshot">
  <h1>Boardshot</h1>
  <p><strong>screenshot ล่าสุด เรียกใช้ได้ด้วยคีย์ลัดเดียว</strong></p>

  <a href="https://github.com/phukijnat/boardshot/releases/latest/download/Boardshot.dmg"><img src="https://img.shields.io/badge/Download_for_macOS-Boardshot.dmg-0A84FF?style=for-the-badge&logo=apple&logoColor=white" alt="ดาวน์โหลด Boardshot สำหรับ macOS" height="44"></a>

  [![Latest version](https://img.shields.io/github/v/release/phukijnat/boardshot?include_prereleases&label=version)](https://github.com/phukijnat/boardshot/releases)
  ![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
  [![License: MIT](https://img.shields.io/github/license/phukijnat/boardshot)](LICENSE)

  [English](README.md) · ภาษาไทย
</div>

<p align="center"><img src="docs/demo.gif" width="800" alt="ถ่ายจอ กด Shift-Command-Space แล้วลากภาพไปวางในแชต"></p>

ถ่ายจอแบบที่ทำอยู่ทุกวัน กด `⇧⌘Space` แล้วลากภาพไปวางใน Slack, Figma, แชต หรือ issue ได้เลย ไม่ต้องเปิด Finder หาไฟล์ Boardshot อยู่บนแถบเมนู เก็บทุกภาพไว้ในโฟลเดอร์เดียว และได้ Desktop ที่สะอาดเป็นของแถม

> [!NOTE]
> **Beta** Boardshot ยังใหม่และอยู่ระหว่างทดสอบ อาจมีบั๊กได้ เจออะไร[แจ้งได้ที่นี่](https://github.com/phukijnat/boardshot/issues/new/choose)

## ความสามารถ

- **หน้าต่างเรียกใช้เร็ว** กด `⇧⌘Space` เห็นทุกภาพ ชี้เพื่อดูภาพใหญ่ ลากไปวางในแอปไหนก็ได้ คัดลอก หรือลบ
- **คีย์ลัดเดิม Desktop สะอาด** `⌘⇧3`, `⌘⇧4` และ `⌘⇧5` บันทึกไปที่ `~/Pictures/Boardshot` แทน Desktop
- **ไฟล์มาทันที** รูปเล็กมุมจอของระบบถูกแทนด้วยของ Boardshot ไฟล์จึงเข้าโฟลเดอร์ทันที ถ้าอยากใช้ Markup ของ Mac เปลี่ยนกลับเป็นรูปเล็กของ macOS ได้ในตั้งค่า
- **คืนค่าเดิมได้ทุกเมื่อ** แอปจำค่าเดิมของ Mac ไว้ และคืนให้ด้วยการเอาติ๊กออกช่องเดียว
- **อัปเดตเอง** บอกเมื่อมีเวอร์ชันใหม่และติดตั้งให้
- **เป็นส่วนตัว** ไม่ต้องสมัครบัญชี ไม่เก็บสถิติ ออกอินเทอร์เน็ตแค่ตอนเช็กอัปเดต
- มีภาษาไทยและอังกฤษ ใช้ได้กับ macOS 14 ขึ้นไป ทั้งเครื่อง Apple Silicon และ Intel

## ติดตั้ง

1. [ดาวน์โหลด **Boardshot.dmg**](https://github.com/phukijnat/boardshot/releases/latest/download/Boardshot.dmg) (เป็นเวอร์ชันล่าสุดเสมอ) เวอร์ชันเก่าอยู่ที่หน้า [Releases](https://github.com/phukijnat/boardshot/releases)
2. เปิดไฟล์ แล้วลาก **Boardshot** ไปใส่ **Applications**
3. เปิด Boardshot จาก Applications

### ถ้าขึ้นว่า "Apple could not verify Boardshot…"
Boardshot ยังไม่ได้ผ่านการตรวจ (notarize) ของ Apple เพราะต้องสมัครบัญชีนักพัฒนาแบบเสียเงิน macOS เลยบล็อกตอนเปิดครั้งแรก ให้กด **Done** อย่ากด Move to Trash:

<img src="docs/first-launch-done.png" width="260" alt="หน้าต่าง Boardshot Not Opened วงปุ่ม Done ไว้">

จากนั้นทำแค่ครั้งเดียว:

- **macOS 15 ขึ้นไป:** กด **Done** แล้วดับเบิลคลิก **Open Anyway** ในหน้าต่างติดตั้ง (หรือไปที่ **System Settings → Privacy & Security** เอง) เลื่อนลงไปกด **Open Anyway** ข้าง Boardshot แล้วยืนยัน
- **macOS 14:** คลิกขวาที่ Boardshot ใน Applications เลือก **Open** แล้วกด **Open** อีกครั้ง

อัปเดตที่ติดตั้งจากในแอปไม่ต้องทำขั้นตอนนี้อีก

## วิธีใช้

| ทำอะไร | ทำยังไง |
|---|---|
| เปิด / ปิดหน้าต่าง | `⇧⌘Space` (เปลี่ยนได้ในหน้าตั้งค่า) หรือคลิกไอคอนกล้องบนแถบเมนู |
| ดูภาพใหญ่ | ชี้เมาส์ค้างบนรูป (ปิดได้ในหน้าตั้งค่า) |
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
- รูปเล็กหลังถ่าย: ของ Boardshot (ไฟล์เข้าทันที), ของ macOS (แก้ไขด้วย Markup ได้ แต่ไฟล์เข้าหลังรูปเล็กหายไป และอาจไม่ขึ้นบนจอที่สอง) หรือไม่แสดง
- แสดงภาพใหญ่เมื่อชี้เมาส์ค้างบนรูป
- เปิดอัตโนมัติตอนเข้าเครื่อง
- แสดงไอคอนบนแถบเมนู
- ตรวจหาอัปเดตอัตโนมัติ หรือกด **ตรวจเดี๋ยวนี้**

## Boardshot เปลี่ยนอะไรในเครื่อง

แอปเปลี่ยนค่าระบบ 2 ค่า (`com.apple.screencapture`: `location` กับ `show-thumbnail`) และจำค่าเดิมไว้ เอาติ๊ก "เก็บ screenshot ไว้ที่ Boardshot" ออกเมื่อไหร่ก็คืนค่าเดิมให้ แต่การปิดแอปจะไม่คืนค่า

## คำถามที่พบบ่อย

**ภาพที่อยู่บน Desktop อยู่แล้วจะถูกย้ายไหม?**
ไม่ย้าย เฉพาะภาพที่ถ่ายใหม่เท่านั้นที่ไปอยู่ `~/Pictures/Boardshot` ถ้าอยากให้ภาพเก่าขึ้นในหน้าต่างด้วย ย้ายเข้าโฟลเดอร์นั้นเองได้

**ถ้าเคยตั้งโฟลเดอร์เก็บ screenshot เองไว้ จะเป็นยังไง?**
Boardshot จำค่านั้นไว้ และคืนให้เมื่อเอาติ๊ก "เก็บ screenshot ไว้ที่ Boardshot" ออก

**Boardshot ส่งอะไรออกอินเทอร์เน็ตไหม?**
มีแค่การเช็กอัปเดต ซึ่งอ่านไฟล์ [`appcast.xml`](appcast.xml) จาก repo นี้ ปิดการเช็กอัตโนมัติได้ในหน้าตั้งค่า

**ทำไมยังไม่ผ่าน notarize?**
ต้องใช้บัญชีนักพัฒนา Apple แบบเสียเงิน แอปนี้เป็นโอเพนซอร์ส [build เองได้](#build-เอง)

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

## แจ้งปัญหาและร่วมพัฒนา

เจอบั๊กหรือมีไอเดีย [เปิด issue ได้เลย](https://github.com/phukijnat/boardshot/issues/new/choose) ส่ง Pull Request ได้เช่นกัน วิธี build และปล่อยเวอร์ชันดูใน [CONTRIBUTING.md](CONTRIBUTING.md)

ถ้า Boardshot ทำให้ส่ง screenshot ได้ไวขึ้น กด ⭐ ให้ repo จะช่วยให้คนอื่นเจอแอปนี้ง่ายขึ้น

## ขอบคุณ

- [Sparkle](https://sparkle-project.org) สำหรับระบบอัปเดตในแอป

## License

Boardshot เป็นซอฟต์แวร์ฟรีและโอเพนซอร์ส ภายใต้ [MIT License](LICENSE) © 2026 phukijnat
