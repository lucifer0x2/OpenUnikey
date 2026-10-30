# OpenUnikey

Bộ gõ tiếng Việt cho macOS dùng ukengine, engine của x-unikey (Phạm Kim Long) lấy
từ fcitx5-unikey. Gõ trực tiếp, không gạch chân: app bắt phím bằng `CGEventTap`, xoá
phần chữ cần sửa rồi gõ lại bằng ký tự Unicode dựng sẵn. Cách gửi phím tham khảo
[OpenKey](https://github.com/tuyenvm/OpenKey).

## Tính năng

- Kiểu gõ Telex, VNI và Simple Telex; bỏ dấu tự do, bỏ dấu kiểu mới (oà, uý)
- Xử lý theo cả âm tiết: `dduocwj`, `nguowif` ra `được`, `người`
- Kiểm tra chính tả và tự khôi phục từ không phải tiếng Việt (`windows`, `text`)
- Biểu tượng V/E trên thanh menu; nhấp trái để chuyển, nhấp phải để mở menu
- Phím chuyển V/E: Control + Shift (nhấn rồi thả) hoặc Option + Z
- Sửa lỗi gợi ý trên thanh địa chỉ trình duyệt: Shift+← với Chrome, Edge, Arc, Brave;
  ký tự đệm với Safari, Firefox
- Khởi động cùng macOS

## Cấu trúc

| Thư mục | Vai trò |
|---|---|
| `Sources/VietCore/ukengine` | ukengine vendored từ fcitx5-unikey (xem README trong thư mục) |
| `Sources/VietCore/engine` | Lớp bọc ukengine: cấu hình, đổi UTF-8 sang UTF-16 |
| `Sources/VietCore/tap` | Event tap trên luồng riêng, gửi Backspace và ký tự Unicode |
| `Sources/VietCore/api` | C API (`include/VietCore.h`) cho Swift |
| `Sources/OpenUnikey` | App thanh menu (AppKit): icon V/E, menu, cài đặt, quyền |
| `Tests/VietCoreTests` | Test gõ Telex/VNI qua C API |

## Build và chạy

```bash
swift test
./scripts/build-app.sh
open build/OpenUnikey.app
```

Lần đầu chạy, cấp quyền tại System Settings → Privacy & Security → Accessibility.

### Giữ quyền Accessibility khi build lại

Ký ad-hoc thì macOS nhận diện app bằng mã băm của file chạy, nên mỗi lần build là
một app mới và phải cấp lại quyền. Ký bằng chứng chỉ thì macOS nhận diện theo chứng
chỉ cộng bundle ID, nên quyền được giữ. Tạo chứng chỉ tự ký một lần:

1. Mở Keychain Access → menu Keychain Access → Certificate Assistant → Create a Certificate…
2. Name: `OpenUnikey Dev`, Identity Type: Self Signed Root, Certificate Type: Code Signing → Create.

Từ đó `scripts/build-app.sh` và `scripts/run-harness.sh` tự ký bằng chứng chỉ này
(kiểm tra bằng `scripts/signing-identity.sh`). Thiếu chứng chỉ thì build báo lỗi,
trừ khi đặt `ALLOW_ADHOC=1`. `build-app.sh` tự tắt OpenUnikey đang chạy trước khi
thay app. Cấp quyền lại một lần cuối cho bản ký mới là xong. Nếu quyền cũ bị kẹt:

```bash
tccutil reset Accessibility io.github.openunikey
```

### Event tap không được làm treo input

Event tap chủ động nằm trên đường đi của mọi phím bấm, nên nếu nó ngừng trả lời
thì cả hệ thống bị treo input. OpenUnikey phòng chuyện này bằng cách:

- chỉ nghe phím (keyDown, flagsChanged); click chuột theo dõi bằng monitor thụ động;
- dừng tap ngay khi mất quyền Accessibility (kiểm tra mỗi giây và khi danh sách quyền đổi);
- khi macOS báo tap timeout 2 lần trong 10 giây, tap tự dừng và chờ 15 giây, gấp đôi
  sau mỗi lần lặp lại (tối đa 8 phút). Sự kiện này được ghi log `OpenUnikey:`.

## Kiểm thử với văn bản dài

```bash
scripts/fetch-corpus.sh                 # tải bài Wikipedia tiếng Việt vào Tests/Corpus
swift run -c release typing-check Tests/Corpus/*.txt
swift run -c release typing-check --method vni --tone vowel Tests/Corpus/*.txt
```

`typing-check` chạy headless: đổi văn bản ra phím Telex/VNI, gõ qua engine rồi so
từng từ (bỏ qua khác biệt vị trí dấu như hòa/hoà). `--interrupt N` mô phỏng gõ dở
một từ, Space, Backspace rồi gõ tiếp, cứ mỗi N từ một lần.

Kiểm thử đầu cuối qua event tap thật (cần OpenUnikey đang chạy ở chế độ V, và cấp
quyền Accessibility cho `build/TypingHarness.app` một lần):

```bash
scripts/run-harness.sh --limit 20 --corpus "$PWD/Tests/Corpus/wiki-Phở.txt"
scripts/run-harness.sh --web --delay 3 --corpus "$PWD/Tests/Corpus/wiki-Hà_Nội.txt"
scripts/run-harness.sh --interrupt 3 --corpus "$PWD/Tests/Corpus/wiki-Phở.txt"
```

Harness gõ vào cửa sổ riêng (AppKit hoặc WebKit với `--web`) và dừng ngay khi mất focus.

## Giấy phép

GNU GPL phiên bản 2 trở lên (xem `LICENSE`). ukengine © 2000-2005 Phạm Kim Long,
giấy phép LGPL-2.0-or-later, có một chỉnh sửa ghi trong `Sources/VietCore/ukengine/README.md`.
