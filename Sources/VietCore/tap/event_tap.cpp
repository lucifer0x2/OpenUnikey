// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Runs the keyboard event tap on its own high-priority thread so a busy UI
// thread can never delay typing.
//
// The tap is active (it can swallow keys), so every key press system-wide
// waits for it. It therefore listens to key events only, and it stops itself
// rather than stall input when macOS reports it as unresponsive.
#include <ApplicationServices/ApplicationServices.h>
#include <dispatch/dispatch.h>
#include <os/log.h>
#include <pthread.h>

#include <algorithm>
#include <future>
#include <mutex>
#include <thread>

#include "VietCore.h"
#include "tap/tap_guard.hpp"
#include "tap/tap_session.hpp"

namespace vk {
namespace {

struct TapRuntime {
    CFMachPortRef port = nullptr;
    CFRunLoopSourceRef source = nullptr;
    CFRunLoopRef loop = nullptr;
    std::thread thread;
    TapSession session;
    TapGuard guard;
};

std::mutex gMutex;
TapRuntime* gRuntime = nullptr;
TapGuard::Clock::time_point gCooldownUntil{};
TapGuard::Clock::time_point gLastGiveUp{};
int gGiveUps = 0;

// vk_tap_stop joins the tap thread, so the tap thread hands it to the main queue.
// Each give-up in a row doubles the wait before the tap may run again
// (15 s ... 8 min), so a tap that keeps timing out cannot keep stalling input.
void stopFromMainQueue(void*) {
    {
        std::lock_guard<std::mutex> lock(gMutex);
        const auto now = TapGuard::Clock::now();
        if (now - gLastGiveUp > std::chrono::minutes(10)) gGiveUps = 0;
        gLastGiveUp = now;
        const auto cooldown = TapGuard::kCooldown * (1 << std::min(gGiveUps++, 5));
        gCooldownUntil = now + cooldown;
        os_log_error(OS_LOG_DEFAULT, "OpenUnikey: keyboard tap timed out, stopped for %lld s",
                     (long long)cooldown.count());
    }
    vk_tap_stop();
}

CGEventRef tapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* user) {
    auto* runtime = static_cast<TapRuntime*>(user);
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (runtime->guard.allowReenable(TapGuard::Clock::now(), AXIsProcessTrusted())) {
            CGEventTapEnable(runtime->port, true);
        } else {
            dispatch_async_f(dispatch_get_main_queue(), nullptr, stopFromMainQueue);
        }
        return event;
    }
    return runtime->session.handle(proxy, type, event);
}

// Key events only: mouse clicks are watched by the app with a passive monitor,
// so a misbehaving tap can never delay them.
CGEventMask eventMask() {
    return CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged);
}

void runLoop(TapRuntime* runtime, std::promise<CFRunLoopRef>* ready) {
    pthread_setname_np("OpenUnikey.EventTap");
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    CFRunLoopRef loop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(loop, runtime->source, kCFRunLoopCommonModes);
    CGEventTapEnable(runtime->port, true);
    ready->set_value(loop);
    CFRunLoopRun();
}

void destroy(TapRuntime* runtime) {
    if (runtime->source) CFRelease(runtime->source);
    if (runtime->port) {
        CFMachPortInvalidate(runtime->port);
        CFRelease(runtime->port);
    }
    delete runtime;
}

} // namespace
} // namespace vk

using namespace vk;

extern "C" bool vk_tap_start(void) {
    std::lock_guard<std::mutex> lock(gMutex);
    if (gRuntime) return true;
    if (TapGuard::Clock::now() < gCooldownUntil) return false; // gave up recently
    if (!AXIsProcessTrusted()) {
        os_log(OS_LOG_DEFAULT, "OpenUnikey: tap not started, process not trusted");
        return false;
    }

    auto* runtime = new TapRuntime();
    runtime->port = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                                     kCGEventTapOptionDefault, eventMask(), tapCallback, runtime);
    if (!runtime->port) {
        os_log_error(OS_LOG_DEFAULT, "OpenUnikey: CGEventTapCreate failed although trusted");
        destroy(runtime);
        return false;
    }
    runtime->source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, runtime->port, 0);

    std::promise<CFRunLoopRef> ready;
    std::future<CFRunLoopRef> loop = ready.get_future();
    runtime->thread = std::thread(runLoop, runtime, &ready);
    runtime->loop = loop.get();
    gRuntime = runtime;
    os_log(OS_LOG_DEFAULT, "OpenUnikey: keyboard tap started");
    return true;
}

extern "C" void vk_tap_stop(void) {
    std::lock_guard<std::mutex> lock(gMutex);
    if (!gRuntime) return;
    CGEventTapEnable(gRuntime->port, false); // stop sitting in the event path first
    CFRunLoopStop(gRuntime->loop);
    gRuntime->thread.join();
    destroy(gRuntime);
    gRuntime = nullptr;
}

extern "C" bool vk_tap_running(void) {
    std::lock_guard<std::mutex> lock(gMutex);
    return gRuntime != nullptr;
}
