# Nghiên cứu khả thi: áp dụng cách làm của Karabiner-Elements vào OpenUnikey

Ngày: 10/11/2026, múi giờ Asia/Ho_Chi_Minh. Nhánh: `research/karabiner-virtual-hid`.

Phạm vi: đọc log chẩn đoán trên máy, đọc mã nguồn Karabiner-Elements và Karabiner-DriverKit-VirtualHIDDevice (bản clone nông, ngày 10/11/2026), thử mở bàn phím qua IOKit. Không sửa mã nguồn app.

## 1. Kết luận ngắn

- Tap ở mức HID (commit `7304f20`) **không** chữa được lỗi mất phím. Khi focus bàn phím được chuyển sang một cửa sổ ViewBridge (ReClaude / bản Claude đóng gói), WindowServer giao phím thẳng cho app mà không cho đi qua bất kỳ CGEventTap nào, kể cả tap ở mức HID.
- Cách làm của Karabiner tránh được lỗi này vì nó đứng **trước** WindowServer: giành (seize) thiết bị bàn phím ở IOKit, rồi phát lại phím qua một bàn phím ảo. WindowServer có định tuyến thế nào thì phím đi tới app cũng đã được xử lý xong.
- Nhưng Karabiner không gõ được Unicode. Bàn phím ảo chỉ gửi mã phím HID. Chữ tiếng Việt vẫn phải gửi bằng `CGEventPost` + `CGEventKeyboardSetUnicodeString`, tức là có hai kênh xuất song song và phải tự lo thứ tự giữa chúng.
- Muốn áp dụng đầy đủ cần một daemon chạy root, cài thêm driver của Karabiner (system extension), và app phải được ký. Khả thi về kỹ thuật nhưng nặng và rủi ro (xem mục 5).
- Đề xuất: làm trước bước 0 (IOHID witness, không cần root) để đo chính xác phím nào bị bỏ qua, rồi chọn giữa "chế độ sửa sau" (không root) và bộ gõ InputMethodKit. Phương án Karabiner đầy đủ để sau cùng.

## 2. Bằng chứng lỗi trên bản HID tap

Đối chiếu log WindowServer (`com.apple.SkyLight:KeyboardEvent`, dòng `delivery manager destinations for kCGSEventKeyDown`) với `~/Library/Logs/OpenUnikey/keys.log` (app PID 17772, chạy bản HID tap từ 09:34).

| Khoảng thời gian | WindowServer giao | Tap của OpenUnikey thấy | Đích |
|---|---|---|---|
| 11:21:08 – 11:21:35 | 92 key down | khoảng 10 (4 Backspace + `viet`) | `pid 5379; token: viewbridge-key-window` (ClaudeCourses) |
| 11:11:36.592 – 11:11:41.749 | 8 key down | 0 | như trên |

Kết quả người dùng thấy: câu "Tooi ddang khoong theer gox tieensg việt nafy". Chỉ "việt" được bộ gõ xử lý.

Kiểu lặp lại: ngay sau một cú click (`engine reset` trong keys.log), vài phím đầu còn đi qua tap, rồi các phím sau bị bỏ qua. Log WindowServer cùng lúc cho thấy `DeferringManager` chuyển focus từ ClaudeCourses sang `<pid: 5379>` (ViewBridge). Suy luận: khi luật chuyển focus (deferring rule) đã có hiệu lực, BackBoard giao phím theo một đường không qua chuỗi CGEventTap.

Cả hai tap vẫn bật suốt thời gian đó, không có ghi chú tap bị tắt. Các tap khác trên máy: Crisp (session, keyDown), Mac Mouse Fix (HID, chỉ cuộn chuột), ViewBridgeAuxiliary (session, chỉ nghe). Không có tap nào chặn phím trước OpenUnikey.

## 3. Karabiner làm gì

Đường dẫn trích dẫn tương đối so với bản clone; `ke` = Karabiner-Elements, `vhid` = Karabiner-DriverKit-VirtualHIDDevice. Cả hai là public domain (Unlicense).

### 3.1 Giành bàn phím

- Karabiner-Core-Service chạy như LaunchDaemon dưới quyền root (`KeepAlive`, `ProcessType Interactive`). Một bản chạy dưới user chỉ để kiểm tra quyền (`ke/src/apps/CoreService/src/main.cpp:37-43`).
- Tìm thiết bị bằng `IOHIDManager`. Mở bằng `IOHIDDeviceOpen(device, kIOHIDOptionsTypeSeizeDevice)`, khởi động `IOHIDQueue` trước khi mở để không rơi phím (`ke/vendor/vendor/include/pqrs/osx/iokit_hid_device_events_monitor.hpp:275-293`).
- Chỉ giành thiết bị khi bàn phím ảo đã sẵn sàng, để phím không bao giờ bị "nuốt mất" (`device_grabber.hpp:943-975`).
- Mở thất bại thì thử lại mỗi 1 s. Có thể bật chế độ dự phòng bằng CGEventTap ở mức HID, kèm bộ chống vòng lặp (`ke/src/share/monitor/event_tap_monitor.hpp:132-148`).
- Quyền cần: Input Monitoring (`IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)`) và Accessibility.
- Secure Keyboard Entry không chặn `IOHIDDeviceOpen`; chỉ chặn event tap (`device_grabber.hpp:405-432`).
- Tiến trình chết thì kernel nhả thiết bị (suy luận), launchd khởi động lại. Có cảnh báo: đặt "Delay to grab device" bằng 0 có thể làm thiết bị không dùng được sau khi thoát.

### 3.2 Phát lại phím

- Bàn phím ảo là một DriverKit system extension. Client nói chuyện với daemon qua Unix socket `/Library/Application Support/org.pqrs/tmp/rootonly/karabiner_virtual_hid_device_service.sock`; **chỉ root mới kết nối được**.
- Report bàn phím: byte modifier + tối đa 32 mã phím. Có thêm report consumer (phím media), Apple vendor (Fn/Globe), con trỏ.
- Mọi output đi qua một hàng đợi duy nhất, cách nhau ít nhất 5 ms để WindowServer không đảo thứ tự (1 ms từng gây lỗi trên Chrome; `queue.hpp:662-690`).
- Key repeat do macOS tự sinh vì bàn phím ảo là thiết bị HID thật. Đèn Caps Lock được đồng bộ ngược về bàn phím thật.
- **Không có Unicode.** `CGEventKeyboardSetUnicodeString` không xuất hiện trong mã; `CGEventPost` chỉ dùng cho double-click chuột.

### 3.3 Driver và cài đặt

- Driver cần các entitlement DriverKit do Apple cấp riêng (`com.apple.developer.driverkit.family.hid.virtual.device`, `...userclient-access`...). OpenUnikey không thể tự ký driver riêng nếu không xin Apple.
- Dùng lại gói đã ký của Karabiner thì được: người dùng cài `.pkg`, kích hoạt system extension, daemon chạy root. Client là thư viện header-only C++23 (`vhid/examples/virtual-hid-device-service-client`).
- Giao thức có phiên bản (`client_protocol_version` 7); daemon từ chối client khác phiên bản, nên phải bám theo từng bản phát hành của Karabiner.
- Hỗ trợ macOS 13–27.

## 4. Thử trên máy này

- `seize_check` (tiến trình thường, uid 501) mở 5 thiết bị: Apple Internal Keyboard / Trackpad, Gaming Keyboard (2 interface USB), Razer DeathAdder (2 interface). Cả mở thường lẫn seize đều trả `0xe00002e2` (kIOReturnNotPermitted) vì tiến trình chạy thử chưa có Input Monitoring. Chưa thử được với quyền đã cấp hay dưới root.
- Đồng hồ: trường `ts=` trong keys.log (timestamp CGEvent ở mức HID) là mach absolute time, cùng đồng hồ với `IOHIDValueGetTimeStamp`. Khác với witness cũ ở mức session (lệch nền thời gian), một witness IOHID có thể ghép từng phím với HID tap một cách chính xác.

## 5. Các phương án

### A. Karabiner đầy đủ: root daemon seize + bàn phím ảo + CGEventPost cho chữ có dấu

- Ưu: không phím nào lọt; key repeat, Fn, phím media, đèn Caps Lock đều đúng như bàn phím thật.
- Nhược:
  - Cần root daemon (SMAppService hoặc plist cài tay), app phải ký Developer ID, người dùng phải cài gói driver của Karabiner.
  - Hai kênh xuất (HID ảo cho phím thường, CGEventPost cho Unicode) có thể đảo thứ tự. Phải đưa mọi output qua một hàng đợi và chờ giữa hai kênh, kiểu nhịp 5 ms của Karabiner, làm chậm gõ nhanh.
  - Xung đột trực tiếp nếu người dùng cũng chạy Karabiner-Elements: một thiết bị chỉ seize được bởi một tiến trình.
  - Daemon treo thì bàn phím chết cho tới khi launchd khởi động lại.
- Ước lượng: lớn (vài tuần), nhiều rủi ro vận hành.

### B. Root daemon seize + CGEventPost tất cả (không driver)

- Bỏ được driver nhưng phải tự làm key repeat, phím media / độ sáng / Fn, đèn Caps Lock. Phím CGEventPost không phải phím HID nên một số app (game, máy ảo, remote desktop) xử lý khác.
- Không đề xuất.

### C. IOHID witness + sửa sau (không root)

- Một `IOHIDManager` chỉ nghe (Input Monitoring) thấy mọi phím vật lý. Ghép với HID tap bằng timestamp. Phím nào witness thấy mà tap không thấy trong vài ms coi là bị bỏ qua.
- Với phím bị bỏ qua: phím thô đã tới app, engine vẫn xử lý nó; nếu engine muốn sửa thì gửi `backs + 1` Backspace và chuỗi mới.
- Rủi ro: không chặn được phím thô, nên nếu người dùng gõ nhanh, phím kế tiếp có thể chen giữa Backspace và chữ mới. Cần đo thực tế.
- Ước lượng: vừa. Không root, không driver. Bước đo (witness) dùng lại được cho mọi phương án.

### D. Bộ gõ InputMethodKit

- Bộ gõ chạy bên trong hệ thống nhập liệu của app đích, nhận phím sau khi WindowServer đã định tuyến, nên đường đi ViewBridge không ảnh hưởng. Không cần Backspace giả.
- Nhược: viết lại lớp tích hợp (engine giữ nguyên), marked text có gạch chân, một số app Electron/terminal xử lý IMK chưa tốt.
- Kiểm chứng nhanh: bộ gõ Vietnamese – Telex có sẵn của macOS gõ đúng trong ReClaude không. Nếu đúng, D chữa được đúng lỗi này.

## 6. Đề xuất các bước

1. **Bước 0 (đo):** thêm IOHID witness vào bản chẩn đoán, ghi `hid key=… ts=…` vào keys.log; cần cấp Input Monitoring cho OpenUnikey. Mục tiêu: đếm chính xác phím bị bỏ qua theo app và theo thời điểm, thay vì dựa vào log WindowServer (log này cũng làm rơi dòng).
2. Thử bộ gõ Telex của macOS trong ReClaude để xác nhận hướng D.
3. Chọn C (sửa nhanh, không root) hoặc D (sửa tận gốc). Chỉ đi tiếp A nếu cả C và D không đạt.

## 7. Chưa kiểm

- Chưa seize thử với quyền Input Monitoring hoặc root.
- Chưa cài gói driver của Karabiner trên máy này (máy chưa có system extension nào ngoài FortiClient).
- Chưa xác nhận lỗi có xảy ra với Claude.app chính thức (`/Applications/Claude.app`) hay chỉ với các bản ReClaude đóng gói.
