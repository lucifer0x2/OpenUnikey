# Báo cáo lỗi: Space khôi phục chữ đã huỷ dấu Telex

Ngày kiểm tra: 30/10/2026, múi giờ Asia/Ho_Chi_Minh.

Workspace: `/Users/luis/Workspace/OpenUnikey`.

Phạm vi: review mã nguồn hiện tại, đọc log chẩn đoán sẵn có và chạy engine độc lập. Không sửa mã nguồn, test hay cấu hình app.

## 1. Kết quả

**[P1] Bước tự khôi phục từ không phải tiếng Việt có thể ghi đè kết quả huỷ dấu Telex khi người dùng nhấn Space.**

| Chuỗi phím engine nhận | Chữ hiển thị ngay trước Space | Sau Space | Kỳ vọng theo báo lỗi |
|---|---|---|---|
| `p u s s h` | `push` | `pussh ` | `push ` |
| `u r r l` | `url` | `urrl ` | `url ` |

Trong hai trường hợp này, chữ `s` hoặc `r` thứ hai đã huỷ dấu. Engine vẫn giữ toàn bộ chuỗi phím thô, rồi đưa chữ đó trở lại khi kết thúc từ.

Lỗi tái hiện được ngay trong engine, không cần event tap hay app đích. Điều này giải thích phạm vi ảnh hưởng ở mọi app mà người dùng báo cáo. Chưa thực hiện kiểm thử giao diện lần lượt trên từng app.

## 2. Điều kiện kiểm tra

- OpenUnikey ở chế độ tiếng Việt, kiểu gõ Telex.
- `spellCheck = true`, `autoRestore = true`; hai tuỳ chọn này cùng bật nhánh khôi phục bổ sung.
- Probe dùng cấu hình mặc định của `vk::Engine`: `freeMarking = true`, `modernStyle = false`, `bracketShortcuts = false`.
- App đang chạy khi đọc log: PID `30101`, đường dẫn `/Users/luis/Workspace/OpenUnikey/build/OpenUnikey.app/Contents/MacOS/OpenUnikey`.
- Workspace có sẵn thay đổi chưa commit trước khi review. Kết luận áp dụng cho nội dung workspace đã đọc; không chỉ cho bản commit gần nhất.

## 3. Cách tái hiện bằng bàn phím

Các bước dưới đây được suy ra từ chuỗi phím trong log và đã kiểm chứng bằng engine độc lập. Phiên review không điều khiển GUI để gõ thử lại.

1. Với cấu hình ở mục 2, đặt con trỏ vào một ô nhập văn bản trống.
2. Nhấn lần lượt `p`, `u`, `s`: chữ đang hiển thị là `pú`.
3. Nhấn thêm `s` để huỷ dấu: chữ trở thành `pus`.
4. Nhấn `h`: chữ đang hiển thị là `push`.
5. Nhấn Space: chữ bị thay bằng `pussh `.

Trường hợp thứ hai: nhấn `u`, `r`, `r`, `l`. Chữ hiển thị lần lượt là `u`, `ủ`, `ur`, `url`; nhấn Space sẽ thành `urrl `.

**Phân biệt chữ đang nhìn thấy với phím đã nhấn:** `push` trước Space trong ca lỗi tương ứng với chuỗi phím `pussh`. Khi engine chỉ nhận đúng một `s` trong `push`, kết quả sau Space vẫn là `push `. Tương tự, chuỗi phím `url` chỉ có một `r` vẫn kết thúc thành `url `.

## 4. Bằng chứng từ log app đang chạy

Đã đọc unified log có sẵn, subsystem `io.github.openunikey`, category `keys`. Chỉ trích các sự kiện liên quan đến hai ca lỗi. Thời gian dưới đây là ngày 30/10/2026, giờ địa phương.

### Ca `push`

| Thời gian | Ký tự vào | Hành động | Số ký tự xoá | Văn bản engine xuất |
|---|---|---|---:|---|
| 14:28:21.643 | `p` | pass | 0 | rỗng |
| 14:28:21.871 | `u` | pass | 0 | rỗng |
| 14:28:21.984 | `s` | rewrite | 1 | `ú` |
| 14:28:22.161 | `s` | rewrite | 1 | `us` |
| 14:28:22.356 | `h` | pass | 0 | rỗng |
| 14:28:22.497 | Space | rewrite | 4 | `pussh ` |

### Ca `url`

| Thời gian | Ký tự vào | Hành động | Số ký tự xoá | Văn bản engine xuất |
|---|---|---|---:|---|
| 14:27:49.238 | `u` | pass | 0 | rỗng |
| 14:27:49.387 | `r` | rewrite | 1 | `ủ` |
| 14:27:49.764 | `r` | rewrite | 1 | `ur` |
| 14:27:49.927 | `l` | pass | 0 | rỗng |
| 14:27:50.100 | Space | rewrite | 3 | `urrl ` |

Các dòng trên đều có `srcpid=0`, `repeat=0`. Có hai sự kiện `s`/`r` riêng biệt trước Space. Ngay tại Space, log đã ghi output sai do engine yêu cầu, trước bước gửi chữ vào app đích. Bằng chứng này không xác định được ý định của người gõ, nhưng xác nhận được chuỗi phím engine đã nhận và quyết định khôi phục của nó.

## 5. Cách đã tái hiện độc lập với giao diện

Đã biên dịch trực tiếp các file C++ hiện tại của engine và ukengine, đưa từng phím vào `vk::Engine::process()`, rồi áp dụng kết quả vào một buffer văn bản: xoá `backs()` ký tự, chèn `output()`; nếu cả hai bằng 0 thì cho phím gốc đi qua.

Probe chỉ tạo executable tạm tại `/private/tmp/openunikey-engine-review`; mã probe truyền qua stdin, không ghi hay sửa file nguồn trong repo.

Có thể chạy lại trên macOS có Xcode Command Line Tools bằng lệnh sau:

```bash
cd /Users/luis/Workspace/OpenUnikey
xcrun clang++ -std=c++17 -I Sources/VietCore -x c++ - Sources/VietCore/engine/*.cpp Sources/VietCore/ukengine/*.cpp -o /private/tmp/openunikey-engine-review <<'CPP'
#include "engine/engine.hpp"
#include <algorithm>
#include <codecvt>
#include <iostream>
#include <locale>
#include <string>
std::string utf8(const std::u16string& s) {
    return std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t>{}.to_bytes(s);
}
int main() {
    for (const std::string keys : {"push ", "url ", "pussh ", "urrl ", "text ", "windows ", "push url ", "pussh url "}) {
        vk::Engine engine;
        std::u16string screen;
        std::cout << "INPUT [" << keys << "]\n";
        for (unsigned char key : keys) {
            engine.process(key, false, false);
            int backs = engine.backs(), count = engine.outputLength();
            std::u16string out(engine.output(), engine.output() + count);
            if (backs == 0 && count == 0) screen.push_back(key);
            else {
                screen.resize(screen.size() - std::min(screen.size(), (size_t)backs));
                screen += out;
            }
            std::cout << "  key=" << key << " backs=" << backs << " out=[" << utf8(out) << "] screen=[" << utf8(screen) << "]\n";
        }
    }
}
CPP
/private/tmp/openunikey-engine-review
```

Lệnh đã hoàn tất với exit code 0. Trình biên dịch có cảnh báo deprecated về `codecvt`/`wstring_convert` trong probe và `sprintf` trong mã vendored; các cảnh báo không ngăn chạy kiểm tra.

Trích output của hai ca lỗi:

```text
INPUT [pussh ]
  key=p backs=0 out=[] screen=[p]
  key=u backs=0 out=[] screen=[pu]
  key=s backs=1 out=[ú] screen=[pú]
  key=s backs=1 out=[us] screen=[pus]
  key=h backs=0 out=[] screen=[push]
  key=  backs=4 out=[pussh ] screen=[pussh ]
INPUT [urrl ]
  key=u backs=0 out=[] screen=[u]
  key=r backs=1 out=[ủ] screen=[ủ]
  key=r backs=1 out=[ur] screen=[ur]
  key=l backs=0 out=[] screen=[url]
  key=  backs=3 out=[urrl ] screen=[urrl ]
```

Các ca đối chứng đã chạy:

| Chuỗi phím | Kết quả cuối |
|---|---|
| `push ` | `push ` |
| `url ` | `url ` |
| `text ` | `text ` |
| `windows ` | `windows ` |
| `push url ` | `push url ` |
| `pussh url ` | `pussh url ` |

Đã chạy lại executable probe ở lượt soạn báo cáo và nhận cùng kết quả. Đây là probe chẩn đoán; không chạy toàn bộ test suite hay build lại app.

## 6. Nguyên nhân trong mã nguồn

1. [WordTracker::onKey()](/Users/luis/Workspace/OpenUnikey/Sources/VietCore/engine/word_tracker.cpp:12) giữ đồng thời `keys_` — toàn bộ phím đã nhận — và `shown_` — chữ hiển thị theo kết quả engine. Với ca thứ nhất, trước Space: `keys_ = "pussh"`, `shown_ = "push"`.
2. [Engine::process()](/Users/luis/Workspace/OpenUnikey/Sources/VietCore/engine/engine.cpp:104) gọi engine gốc trước; khi nhận ký tự ngắt từ, nó gọi tiếp `restoreForeignWord()`.
3. [WordTracker::shouldRestore()](/Users/luis/Workspace/OpenUnikey/Sources/VietCore/engine/word_tracker.cpp:26) chấp nhận khôi phục khi chữ đang hiển thị chỉ gồm chữ ASCII và ngắn hơn chuỗi phím. Ngoại lệ cuối hàm so sánh `keys_` bỏ phím cuối với `shown_`, nên chỉ tránh khôi phục một số ca huỷ dấu ở cuối từ, chẳng hạn `ass → as`.
4. Với `pussh`, chuỗi bỏ phím cuối là `puss`, khác `push`, nên hàm trả về true. Với `urrl`, `urr` cũng khác `url`.
5. [Engine::restoreForeignWord()](/Users/luis/Workspace/OpenUnikey/Sources/VietCore/engine/engine.cpp:160) xoá toàn bộ chữ đang hiển thị và xuất lại `tracker_.keys()` kèm Space. Vì vậy, output đã là `pussh ` hoặc `urrl ` trước khi đi qua lớp gửi phím.

Nhánh bổ sung này hoạt động khi cả `spellCheck` và `autoRestore` bật, theo [Engine::configure()](/Users/luis/Workspace/OpenUnikey/Sources/VietCore/engine/engine.cpp:77).

Mục đích của logic là giữ chữ đôi trong từ nước ngoài như `Kissinger`, vốn có thể bị Telex rút ngắn. Nhưng cùng một chuỗi phím đôi cũng có thể là thao tác huỷ dấu có chủ ý. Heuristic hiện tại ưu tiên khôi phục phím thô khi người dùng gõ tiếp sau thao tác đó.

## 7. Khoảng trống kiểm thử và yêu cầu cho bước sửa sau này

[Tests/VietCoreTests/EngineTests.swift](/Users/luis/Workspace/OpenUnikey/Tests/VietCoreTests/EngineTests.swift:100) có kiểm tra giữ chữ đôi trong từ nước ngoài và ngoại lệ `ass → as`. Chưa có assertion giữ `push`/`url` sau khi huỷ dấu rồi gõ tiếp và kết thúc từ. Hai ca có sẵn chứa `pussh` kiểm tra việc xoá chữ bằng Backspace sau khôi phục, không kiểm tra kỳ vọng này.

Trước khi sửa cần chốt chính sách cho sự nhập nhằng giữa giữ chữ đôi và giữ kết quả huỷ dấu. Chỉ dựa vào chuỗi phím không thể luôn biết người dùng định gõ `Kissinger` có hai `s` hay cố ý huỷ dấu rồi gõ tiếp. Một thay đổi ưu tiên huỷ dấu có thể tác động đến hành vi giữ chữ đôi đang được test.

Các trường hợp cần kiểm chứng khi có phương án sửa:

- Huỷ dấu rồi gõ tiếp: `pussh`, `urrl`, sau đó Space.
- Huỷ dấu ở cuối từ: các ca như `ass` vẫn theo chính sách đã chốt.
- Từ có chữ đôi thực sự: `Kissinger`, `Pierre`, `truffle`, `Harrison`.
- Kết thúc từ bằng dấu câu, Return, Tab; nhánh khôi phục cũng được gọi ở các đường xử lý liên quan, nhưng phiên này chỉ tái hiện độc lập các ca Space đã nêu.
- Backspace ngay sau khôi phục và xoá toàn bộ từ, tránh làm lệch trạng thái engine với chữ trên màn hình.

## 8. Giới hạn và trạng thái bàn giao

- Đã xác nhận bằng mã nguồn, log app thực tế và probe độc lập.
- Không bật thêm logging, không đổi tuỳ chọn, không restart hay thay binary app.
- Không kiểm tra hết các kiểu gõ khác hoặc mọi tổ hợp tuỳ chọn.
- Chưa chọn hay triển khai phương án sửa.
- Không sửa mã nguồn hoặc test. File báo cáo này là tài liệu mới được tạo theo yêu cầu sau review.
