# OpenUnikey

Bộ gõ tiếng Việt cho macOS dùng ukengine, engine của x-unikey (Phạm Kim Long) lấy
từ fcitx5-unikey. Gõ trực tiếp, không gạch chân: app bắt phím bằng `CGEventTap`, xoá
phần chữ cần sửa rồi gõ lại bằng ký tự Unicode dựng sẵn. Cách gửi phím tham khảo
[OpenKey](https://github.com/tuyenvm/OpenKey).

## Tính năng

- Kiểu gõ Telex, VNI và Simple Telex; bỏ dấu tự do, bỏ dấu kiểu mới (oà, uý)
- Xử lý theo cả âm tiết: `dduocwj`, `nguowif` ra `được`, `người`
- Kiểm tra chính tả và tự khôi phục từ không phải tiếng Việt (`windows`, `text`)
- Tiếng Việt / tiếng Anh là nguồn nhập của macOS: "OpenUnikey" gõ tiếng Việt, ABC gõ
  tiếng Anh
- Biểu tượng V/E trên thanh menu theo nguồn đang chọn; nhấp trái để đổi nguồn, nhấp
  phải để mở menu
- Phím đổi nguồn: Control + Shift (nhấn rồi thả) hoặc Option + Z; Control + Space hay
  phím 🌐 của macOS cũng được
- Sửa lỗi gợi ý trên thanh địa chỉ trình duyệt bằng ký tự đệm (Chrome, Edge, Arc, Brave,
  Safari, Firefox…)
- Beta: nút chuột 4/5 chuyển Space phải/trái (bật trong Tuỳ chọn)
- Khởi động cùng macOS

## Cấu trúc

| Thư mục | Vai trò |
|---|---|
| `Sources/VietCore/ukengine` | ukengine vendored từ fcitx5-unikey (xem README trong thư mục) |
| `Sources/VietCore/engine` | Lớp bọc ukengine: cấu hình, đổi UTF-8 sang UTF-16 |
| `Sources/VietCore/tap` | Event tap trên luồng riêng, gửi Backspace và ký tự Unicode |
| `Sources/VietCore/im` | Xử lý phím cho bộ gõ InputMethodKit, dùng chung engine với tap |
| `Sources/VietCore/api` | C API (`include/VietCore.h`) cho Swift |
| `Sources/OpenUnikey` | App thanh menu (AppKit): icon V/E, menu, cài đặt, quyền, phím đổi nguồn khi đang ở ABC |
| `Sources/OpenUnikeyIM` | Bộ gõ InputMethodKit, cài vào `~/Library/Input Methods` |
| `Sources/OpenUnikeyShared` | Phần dùng chung giữa app và bộ gõ: danh sách trình duyệt, định danh, đổi nguồn nhập |
| `Tests/VietCoreTests` | Test gõ Telex/VNI qua C API |

## Build và chạy

```bash
swift test
./scripts/build-app.sh
./scripts/build-input-method.sh
open build/OpenUnikey.app
```

`build-input-method.sh` cài bộ gõ vào `~/Library/Input Methods`, đăng ký và chọn nó
làm nguồn nhập. Cấp quyền Accessibility (System Settings → Privacy & Security →
Accessibility) cho cả `OpenUnikey` và `OpenUnikeyIM`.

### Vì sao gõ bằng bộ gõ InputMethodKit

Có app WindowServer giao phím thẳng, không qua event tap nào (cửa sổ ViewBridge,
ví dụ bản Claude đóng gói trong ReClaude), nên một event tap không sửa được chữ. Bộ
gõ InputMethodKit nhận phím ngay trong app đích nên không bị lọt. Nó không dùng
marked text (không gạch chân): vẫn gửi Backspace + chữ như trước.

Bộ gõ đọc cài đặt của app (kiểu gõ, chính tả...). Khi đang ở nguồn khác (ABC), event
tap của app không gõ gì, chỉ bắt phím đổi nguồn để chọn lại OpenUnikey. Trong cửa sổ
ViewBridge tap có thể không thấy phím đó; khi ấy dùng Control + Space hoặc phím 🌐.

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
Để thử trong Chromium, mở một phiên Chrome riêng (profile tạm) rồi gõ vào đó:

```bash
PID=$(scripts/chromium-test-page.sh prosemirror)   # hoặc textarea, editable
scripts/run-harness.sh --external "$PID" --corpus "$PWD/Tests/Corpus/wiki-Phở.txt"
kill "$PID"
```

`--switch-check` kiểm tra Control+Shift, `--mouse-check` kiểm tra nút chuột 4/5.
`--hid` gửi phím qua tầng HID như bàn phím thật, `--hold MS` giữ mỗi phím một lúc.

Lỗi chỉ gặp khi gõ tay thì bật log phím. Log ghi mọi phím gõ ở chế độ V, giữ trong RAM
và ghi vào `~/Library/Logs/OpenUnikey/keys.log` mỗi 10 phút và khi Quit (quá 20 MB thì
chuyển sang `keys.log.1`). Log chạy liên tục tới khi tắt:

```bash
defaults write io.github.openunikey keyLogging -bool true   # rồi mở lại app
defaults delete io.github.openunikey keyLogging             # tắt, rồi mở lại app
```

## Giấy phép

GNU GPL phiên bản 2 trở lên (xem `LICENSE`). ukengine © 2000-2005 Phạm Kim Long,
giấy phép LGPL-2.0-or-later, có một chỉnh sửa ghi trong `Sources/VietCore/ukengine/README.md`.
