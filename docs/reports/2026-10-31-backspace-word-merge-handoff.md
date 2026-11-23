# Bàn giao điều tra: gõ, xóa, gõ lại làm nối từ và khôi phục Telex về phía trước

Ngày: 31/10/2026, múi giờ Asia/Ho_Chi_Minh.
Workspace: `/Users/luis/Workspace/OpenUnikey`.
HEAD khi điều tra: `4408fa98bec51d444cec27639507aec815d0b997`.

## 1. Yêu cầu và phạm vi của người dùng

Người dùng báo lỗi thỉnh thoảng xảy ra khi gõ, xóa rồi gõ lại:

- Câu mong muốn: `Tôi đoán là không có`.
- Câu bị lỗi: `Tôi đoán là khoongcos`.
- Xóa tiếp phần lỗi rồi gõ `không` có thể thành `Tôi đoán lafkhoong`.
- Cảm giác lỗi “lan” lùi về các từ trước đó khi tiếp tục xóa và gõ lại.

Nơi đã gặp: ô nhập prompt trong Claude. Người dùng yêu cầu rõ: **không giới hạn
điều tra hoặc cách sửa ở Claude; phạm vi là bộ gõ trên toàn bộ app**.

Chưa biết chính xác thao tác xóa: Backspace từng chữ, giữ Backspace hay xóa vùng
chọn. Chưa có chuỗi sự kiện đúng lần lỗi để phân biệt các trường hợp này.

## 2. Kết luận hiện tại và giới hạn quan trọng

**Đã xác nhận cơ chế tạo ra đúng hai chuỗi lỗi bằng engine độc lập. Chưa xác định
được sự kiện ban đầu khiến ranh giới từ bị mất trong lần lỗi thực tế.**

Khi dấu cách bị xóa, engine mở lại từ trước để sửa tiếp. Nếu gõ thêm làm cụm đó
không còn hợp lệ theo kiểm tra tiếng Việt, nhấn Space sẽ khôi phục toàn bộ cụm
thành phím Telex thô. Vì vậy `không` trở lại `khoong`, `là` trở lại `laf`.

Các ca tái hiện ở mục 3 **chủ động xóa dấu cách**. Chúng chứng minh đường tạo ra
triệu chứng, không chứng minh OpenUnikey tự nuốt dấu cách, cũng không chứng minh
người dùng đã xóa dư. Không được trình bày chúng như bằng chứng đã tìm đủ nguyên
nhân gốc của báo lỗi thực tế.

Khi dấu cách trước từ đang sửa còn nguyên, các probe đã chạy chưa tái hiện được
việc lỗi vượt về từ trước. Chưa kiểm thử giao diện từng app.

## 3. Các ca đã tái hiện và đối chứng

Cấu hình mặc định: Telex, freeMarking bật, spellCheck bật, autoRestore bật,
modernStyle tắt, bracketShortcuts tắt. `⌫` dưới đây là một Backspace.

Tiền tố phím chung: `Tooi ddoans laf ` → chữ hiển thị `Tôi đoán là `.

| Ca | Thao tác sau tiền tố | Kết quả |
|---|---|---|
| A | Gõ `khoong `, `⌫`, gõ `cos ` | `Tôi đoán là khoongcos ` |
| B | Sau A, nhấn `⌫` 11 lần, gõ `khoong ` | `Tôi đoán lafkhoong ` |
| C | Như A nhưng tắt autoRestore | `Tôi đoán là khôngcos ` |
| D | Gõ `khoong cos`, `⌫` 2 lần, gõ `khoong ` | `Tôi đoán là không không ` |

Trong B, `khoongcos` dài 9 ký tự; 11 Backspace xóa dấu cách cuối, 9 chữ của từ lỗi
và dấu cách trước nó. Sau đó con trỏ sát `là`. Đây là điều kiện có chủ đích của
probe, không phải số lần Backspace đã quan sát được từ người dùng.

Trích output thực tế của A:

```text
<SP> backs=0 out=[] screen=[Tôi đoán là không ]
<BS> backs=1 out=[] screen=[Tôi đoán là không]
c backs=0 out=[] screen=[Tôi đoán là khôngc]
o backs=0 out=[] screen=[Tôi đoán là khôngco]
s backs=0 out=[] screen=[Tôi đoán là khôngcos]
<SP> backs=8 out=[khoongcos ] screen=[Tôi đoán là khoongcos ]
```

Trích bước cuối của B:

```text
<BS> backs=1 out=[] screen=[Tôi đoán là]
k backs=0 out=[] screen=[Tôi đoán làk]
...
g backs=0 out=[] screen=[Tôi đoán làkhoong]
<SP> backs=8 out=[lafkhoong ] screen=[Tôi đoán lafkhoong ]
```

Ca C cho thấy tắt autoRestore chỉ ngăn việc đưa dấu về phím thô; dấu cách đã mất
thì vẫn mất. Đây chưa phải cách sửa đầy đủ. Ca D giữ dấu cách và không nối với từ
trước trong engine độc lập.

## 4. Đường code liên quan

Các đường dẫn dưới đây tính từ workspace; số dòng áp dụng cho HEAD ở đầu báo cáo.

| Vị trí | Trách nhiệm / điều đã đọc được |
|---|---|
| `Sources/VietCore/engine/engine.cpp:120` | `Engine::backspace()` gọi ukengine; có thể lấy lại tracker của từ trước khi xóa ký tự ngắt từ. |
| `Sources/VietCore/ukengine/ukengine.cpp:2570` | `processBackspace()` sửa buffer chữ và đồng bộ buffer phím. Xóa dấu cách cho phép tiếp tục sửa từ trước. |
| `Sources/VietCore/ukengine/ukengine.cpp:2942` | `processWordEnd()` gọi khôi phục khi autoRestore bật và từ bị coi là không hợp lệ. |
| `Sources/VietCore/ukengine/ukengine.cpp:2826` | `restoreKeyStrokes()` tìm ranh giới trong lịch sử phím, xóa cụm trong buffer chữ rồi xuất phím thô. Đây là bước tạo `khoongcos` / `lafkhoong`. |
| `Sources/VietCore/ukengine/keystroke_sync.cpp:37` | `resyncWordKeyStrokes()` thử bỏ phím và replay để tìm lịch sử khớp chữ còn lại; giới hạn 256 replay. |
| `Sources/VietCore/ukengine/ukengine.cpp:2549` | Nếu resync không thành công hoặc không áp dụng, fallback giảm con trỏ phím theo cách cũ; không có trạng thái riêng để cấm khôi phục lịch sử chưa xác nhận. |
| `Sources/VietCore/engine/engine.cpp:131` | `tracker_.invalidate()` chỉ vô hiệu tracker của lớp bọc; không tự vô hiệu hóa autoRestore bên trong ukengine. |
| `Sources/VietCore/tap/tap_session.cpp:85` | Mỗi Backspace gọi engine; output rỗng và backs ≤ 1 thì cho phím thật đi qua. |
| `Sources/VietCore/tap/key_sender.cpp:62` | Gửi số Backspace và Unicode engine yêu cầu; chưa đối chiếu chữ/vùng chọn thực tế của app trước khi thay chữ. |
| `Sources/OpenUnikey/TapSupervisor.swift` | Click chuột yêu cầu reset engine qua global monitor. |
| `Sources/OpenUnikey/FrontmostAppObserver.swift` | Theo dõi đổi app và chọn workaround autocomplete cho các trình duyệt. |

Fallback khi resync thất bại và việc chưa kiểm chứng context là **điểm cần điều
tra**, chưa phải bằng chứng rằng chúng đã gây lần lỗi của người dùng. Một số lần
resync trả false là bình thường, ví dụ xóa dấu cách hoặc không có phím biến đổi;
không được đồng nhất mọi false với mất đồng bộ.

Commit `4408fa9` đã sửa một nhóm lỗi lịch sử phím còn sót sau Backspace. Không
được giả định commit này đã xử lý hết mọi tình huống hoặc mặc định bản chạy chưa
có nó. Binary app tại thời điểm kiểm tra có symbol `resyncWordKeyStrokes()`.

## 5. Kiểm chứng đã thực hiện

- Biên dịch trực tiếp các file C++ hiện tại, không sửa source/test của repo.
- Áp dụng `backs()` và `output()` vào buffer UTF-16 theo cách `EngineTypist` và
  `TapSession` xử lý; đã chạy được A–D, exit code 0.
- Probe ngẫu nhiên với tiền tố `Tôi đoán là ` được bảo vệ, không cho Backspace
  xóa quá tiền tố: 1.500 lượt × 65 sự kiện = 97.500 sự kiện, seed 123456; chưa thấy
  output sửa tiền tố đó. Đây là kiểm tra giới hạn, không chứng minh mọi chuỗi an toàn.
- Probe riêng trên ukengine: 80.000 sự kiện ngẫu nhiên, chưa thấy buffer chữ lệch
  khỏi phần đuôi văn bản mô phỏng. Probe này không đi qua đầy đủ lớp bọc hoặc app.
- Đọc log hiện có của subsystem `io.github.openunikey`, category `keys`: không có
  chuỗi lỗi đang báo. Log trong khoảng 45 phút truy vấn rỗng; phạm vi 24 giờ chỉ
  tìm thấy các bản ghi cũ ngày 30/10. Không bật thêm logging.
- Không chạy full test suite, không build/restart/thay app, không điều khiển GUI.
- Working tree sạch trước khi tạo chính file bàn giao này.

Các executable chẩn đoán được tạo tại `/private/tmp/openunikey-*-review`; đây là
file tạm, phiên sau không nên phụ thuộc vào việc chúng còn tồn tại.

## 6. Lệnh tái hiện độc lập, tự chứa

Chạy trên macOS có Xcode Command Line Tools. Lệnh chỉ tạo executable trong `/private/tmp`.

```bash
cd /Users/luis/Workspace/OpenUnikey
xcrun clang++ -std=c++17 -Wno-deprecated-declarations -I Sources/VietCore \
  -x c++ - Sources/VietCore/engine/*.cpp Sources/VietCore/ukengine/*.cpp \
  -o /private/tmp/openunikey-merge-handoff <<'CPP'
#include "engine/engine.hpp"
#include <algorithm>
#include <codecvt>
#include <iostream>
#include <locale>
#include <string>

std::string utf8(const std::u16string& text) {
    return std::wstring_convert<
        std::codecvt_utf8_utf16<char16_t>, char16_t>{}.to_bytes(text);
}

bool check(const char* name, const std::string& keys,
           const std::u16string& expected, bool restore = true) {
    vk::Engine engine;
    vk::Options options;
    options.autoRestore = restore;
    engine.configure(options);
    std::u16string screen;
    for (unsigned char key : keys) {
        if (key == 8) engine.backspace();
        else engine.process(key, key >= 'A' && key <= 'Z', false);
        const int backs = engine.backs(), count = engine.outputLength();
        if (count == 0 && (key == 8 ? backs <= 1 : backs == 0)) {
            if (key == 8) {
                if (!screen.empty()) screen.pop_back();
            } else screen.push_back(key);
        } else {
            screen.resize(screen.size() - std::min(screen.size(), (size_t)backs));
            screen.append(engine.output(), engine.output() + count);
        }
    }
    const bool ok = screen == expected;
    std::cout << name << ": " << (ok ? "PASS" : "FAIL")
              << " [" << utf8(screen) << "]\n";
    return ok;
}

int main() {
    const std::string prefix = "Tooi ddoans laf ";
    const std::string first = prefix + "khoong \bcos ";
    bool ok = check("A: deleted separator", first, u"Tôi đoán là khoongcos ");
    ok &= check("B: delete through next separator",
                first + std::string(11, '\b') + "khoong ", u"Tôi đoán lafkhoong ");
    ok &= check("C: autoRestore off", first, u"Tôi đoán là khôngcos ", false);
    ok &= check("D: separator preserved",
                prefix + "khoong cos\b\bkhoong ", u"Tôi đoán là không không ");
    return ok ? 0 : 1;
}
CPP
/private/tmp/openunikey-merge-handoff
```

PASS ở đây chỉ xác nhận hành vi hiện tại đúng với kết quả chẩn đoán đã ghi, không
phải xác nhận hành vi đó đáp ứng mong muốn của người dùng hay lỗi đã được sửa.

## 7. Công việc để phiên tiếp theo tiếp tục

1. Đọc quy tắc workspace và kiểm tra lại HEAD/working tree trước khi làm.
2. Tìm trigger ban đầu: dấu cách bị xóa trong chuỗi sự kiện thật, engine và app
   lệch context, hay lỗi ở đường đồng bộ Backspace. Cần phân biệt bằng trace; không
   suy ra trigger chỉ từ output cuối. Nếu cần thu log mới, giới hạn trong ca tái hiện.
3. Kiểm tra cả Backspace rời/giữ phím, sửa lặp nhiều lần, đi qua ranh giới từ,
   vùng chọn, di chuyển con trỏ, và thay đổi văn bản do app. Ưu tiên ca có bằng
   chứng; không mặc định mọi khả năng trên đều là lỗi đã tồn tại.
4. Khi có reproducer của lỗi thực, thêm regression ở đúng lớp và sửa nguyên nhân
   chung của core/tap. Không thêm workaround riêng Claude chỉ vì nơi gặp lỗi là Claude.
5. Giữ khả năng sửa từ sau khi xóa Space. Không reset engine ở mọi Backspace để
   che triệu chứng; cách đó có thể làm hỏng hành vi đang được yêu cầu và kiểm thử.

Các test liên quan có sẵn trong `Tests/VietCoreTests/EngineTests.swift`:

- `backspaceEditsTheBufferedWord` — dòng 65.
- `continueAWordAfterDeletingTheSpace` — dòng 84; gồm âm tiết gõ dở và undo restore.
- `doubledToneKeyStaysUndone` — dòng 109; gồm xóa từ và ranh giới với từ trước.
- `backspaceKeepsTheKeysOfTheWord` — dòng 125.

Tiêu chí kiểm chứng cho bản sửa: thay/xóa từ mà giữ dấu cách thì không đổi từ
trước; không hồi sinh phím của phần đã xóa; không khôi phục cả cụm từ dựa trên
lịch sử đã mất đồng bộ; các hành vi sửa từ hợp lệ hiện có vẫn đúng. Kiểm chứng
engine và đường gửi phím thật, với một app native và một editor web/Electron;
ghi rõ phạm vi đã kiểm thay vì tuyên bố đã kiểm mọi app.

## 8. Trạng thái bàn giao

Chỉ điều tra và viết tài liệu. Chưa sửa mã nguồn/test, chưa chọn phương án sửa,
chưa commit/push và chưa thay binary app đang chạy.

Báo cáo cũ `docs/reports/2026-10-30-telex-restore-duplicate.md` mô tả một nhóm lỗi
khác ở trạng thái code trước đây; không dùng các tên hàm hoặc số dòng trong báo
cáo đó làm bằng chứng cho HEAD hiện tại nếu chưa đối chiếu lại.
