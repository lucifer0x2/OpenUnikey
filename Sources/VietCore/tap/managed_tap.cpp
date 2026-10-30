// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/managed_tap.hpp"

#include <dispatch/dispatch.h>
#include <os/log.h>
#include <pthread.h>

#include <algorithm>
#include <future>
#include <memory>
#include <thread>

namespace vk {

struct ManagedTap::Runtime {
    ManagedTap* owner = nullptr;
    CFMachPortRef port = nullptr;
    CFRunLoopSourceRef source = nullptr;
    CFRunLoopRef loop = nullptr;
    std::thread thread;
    TapGuard guard;

    ~Runtime() {
        if (source) CFRelease(source);
        if (port) {
            CFMachPortInvalidate(port);
            CFRelease(port);
        }
    }
};

ManagedTap::ManagedTap(const char* name, CGEventMask mask, Handler handler, void* context)
    : name_(name), mask_(mask), handler_(handler), context_(context) {}

CGEventRef ManagedTap::callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event,
                                void* user) {
    auto* runtime = static_cast<Runtime*>(user);
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (runtime->guard.allowReenable(TapGuard::Clock::now(), AXIsProcessTrusted())) {
            CGEventTapEnable(runtime->port, true);
        } else {
            // stop() joins this thread, so it has to run elsewhere.
            dispatch_async_f(dispatch_get_main_queue(), runtime->owner, giveUpOnMainQueue);
        }
        return event;
    }
    ManagedTap* tap = runtime->owner;
    return tap->handler_(tap->context_, proxy, type, event);
}

void ManagedTap::giveUpOnMainQueue(void* self) {
    auto* tap = static_cast<ManagedTap*>(self);
    {
        std::lock_guard<std::mutex> lock(tap->mutex_);
        const auto now = TapGuard::Clock::now();
        if (now - tap->lastGiveUp_ > std::chrono::minutes(10)) tap->giveUps_ = 0;
        tap->lastGiveUp_ = now;
        const auto cooldown = TapGuard::kCooldown * (1 << std::min(tap->giveUps_++, 5));
        tap->cooldownUntil_ = now + cooldown;
        os_log_error(OS_LOG_DEFAULT, "OpenUnikey: %{public}s timed out, stopped for %lld s",
                     tap->name_, (long long)cooldown.count());
    }
    tap->stop();
}

bool ManagedTap::start() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (runtime_) return true;
    if (TapGuard::Clock::now() < cooldownUntil_) return false; // gave up recently
    if (!AXIsProcessTrusted()) {
        os_log(OS_LOG_DEFAULT, "OpenUnikey: %{public}s not started, process not trusted", name_);
        return false;
    }

    auto* runtime = new Runtime();
    runtime->owner = this;
    runtime->port = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                                     kCGEventTapOptionDefault, mask_, callback, runtime);
    if (!runtime->port) {
        os_log_error(OS_LOG_DEFAULT, "OpenUnikey: %{public}s could not be created", name_);
        delete runtime;
        return false;
    }
    runtime->source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, runtime->port, 0);

    // Shared with the thread: it may still be inside set_value() when get()
    // returns here, so the promise must not die with this stack frame.
    auto ready = std::make_shared<std::promise<CFRunLoopRef>>();
    std::future<CFRunLoopRef> loop = ready->get_future();
    runtime->thread = std::thread([runtime, name = name_, ready] {
        pthread_setname_np(name);
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runtime->source, kCFRunLoopCommonModes);
        CGEventTapEnable(runtime->port, true);
        ready->set_value(CFRunLoopGetCurrent());
        CFRunLoopRun();
    });
    runtime->loop = loop.get();
    runtime_ = runtime;
    os_log(OS_LOG_DEFAULT, "OpenUnikey: %{public}s started", name_);
    return true;
}

void ManagedTap::stop() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!runtime_) return;
    CGEventTapEnable(runtime_->port, false); // leave the event path first
    CFRunLoopStop(runtime_->loop);
    runtime_->thread.join();
    delete runtime_;
    runtime_ = nullptr;
}

bool ManagedTap::running() {
    std::lock_guard<std::mutex> lock(mutex_);
    return runtime_ != nullptr;
}

} // namespace vk
