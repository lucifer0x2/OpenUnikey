// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Keeps the key log in memory and appends it to a file every 10 minutes, so
// the tap thread never waits on the disk.
#pragma once

#include <dispatch/dispatch.h>

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>

namespace vk {

class KeyLogFile {
public:
    KeyLogFile();
    KeyLogFile(const KeyLogFile&) = delete;
    KeyLogFile& operator=(const KeyLogFile&) = delete;

    // Collects lines for `path` (created 0600). Past maxBytes the file becomes
    // path + ".1", replacing the one before, and a new file starts.
    void start(const std::string& path, uint64_t maxBytes);
    // Writes what is left, then drops further lines.
    void stop();
    bool running() const { return running_.load(std::memory_order_relaxed); }

    void append(const std::string& line); // any thread; adds the newline
    void flush();                         // writes now and waits; not on the tap thread

private:
    void writePending(); // on queue_ only

    std::atomic<bool> running_{false};
    std::mutex mutex_; // guards the three below
    std::string pending_;
    std::string path_;
    uint64_t maxBytes_ = 0;
    dispatch_queue_t queue_;
    dispatch_source_t timer_ = nullptr; // touched by start/stop only
};

KeyLogFile& keyLogFile();

} // namespace vk
