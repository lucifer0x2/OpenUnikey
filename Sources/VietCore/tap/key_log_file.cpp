// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/key_log_file.hpp"

#include <fcntl.h>
#include <os/log.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>

namespace vk {
namespace {

constexpr int64_t kFlushInterval = 10 * 60 * (int64_t)NSEC_PER_SEC;
constexpr uint64_t kFlushLeeway = 30 * NSEC_PER_SEC;

bool writeAll(int fd, const std::string& text) {
    size_t done = 0;
    while (done < text.size()) {
        const ssize_t n = write(fd, text.data() + done, text.size() - done);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0) return false;
        done += (size_t)n;
    }
    return true;
}

} // namespace

// Never destroyed: the queue or timer may still run while the process exits.
KeyLogFile& keyLogFile() {
    static KeyLogFile* file = new KeyLogFile();
    return *file;
}

KeyLogFile::KeyLogFile()
    : queue_(dispatch_queue_create("io.github.openunikey.keylog", DISPATCH_QUEUE_SERIAL)) {}

void KeyLogFile::start(const std::string& path, uint64_t maxBytes) {
    stop();
    {
        std::lock_guard<std::mutex> lock(mutex_);
        pending_.clear();
        path_ = path;
        maxBytes_ = maxBytes;
    }
    timer_ = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue_);
    dispatch_set_context(timer_, this);
    dispatch_source_set_event_handler_f(
        timer_, [](void* file) { static_cast<KeyLogFile*>(file)->writePending(); });
    dispatch_source_set_timer(timer_, dispatch_time(DISPATCH_TIME_NOW, kFlushInterval),
                              kFlushInterval, kFlushLeeway);
    dispatch_resume(timer_);
    running_.store(true);
}

void KeyLogFile::stop() {
    if (!running_.exchange(false)) return;
    dispatch_source_cancel(timer_);
    dispatch_release(timer_);
    timer_ = nullptr;
    flush();
}

void KeyLogFile::append(const std::string& line) {
    if (!running()) return;
    std::lock_guard<std::mutex> lock(mutex_);
    pending_ += line;
    pending_ += '\n';
}

void KeyLogFile::flush() {
    dispatch_sync_f(queue_, this, [](void* file) { static_cast<KeyLogFile*>(file)->writePending(); });
}

void KeyLogFile::writePending() {
    std::string text, path;
    uint64_t maxBytes = 0;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        text.swap(pending_);
        path = path_;
        maxBytes = maxBytes_;
    }
    if (text.empty() || path.empty()) return;

    const int fd = open(path.c_str(), O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0600);
    if (fd < 0) {
        os_log_error(OS_LOG_DEFAULT, "OpenUnikey: key log not written, open failed (%d)", errno);
        return;
    }
    if (!writeAll(fd, text))
        os_log_error(OS_LOG_DEFAULT, "OpenUnikey: key log write failed (%d)", errno);
    struct stat info {};
    const bool full = fstat(fd, &info) == 0 && (uint64_t)info.st_size > maxBytes;
    close(fd);
    if (full) std::rename(path.c_str(), (path + ".1").c_str());
}

} // namespace vk
