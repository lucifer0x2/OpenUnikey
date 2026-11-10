// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// C entry points of the input method and of the taps' stand-down switch.
#include "VietCore.h"

#include "im/im_session.hpp"
#include "tap/key_sender.hpp"
#include "tap/key_log.hpp"
#include "tap/shared_state.hpp"

namespace {

// InputMethodKit calls in on the main thread only.
vk::ImSession& imSession() {
    static vk::ImSession session;
    return session;
}

} // namespace

extern "C" {

bool vk_im_handle_event(CGEventRef event) { return imSession().handle(event); }

void vk_im_reset(void) { imSession().reset(); }

void vk_im_set_poster(VKEventPoster poster, void* context) {
    vk::setUntappedPoster(poster, context);
}

void vk_set_input_method_active(bool active) {
    if (vk::sharedState().inputMethodActive.exchange(active) == active) return;
    vk::sharedState().resetRequested.store(true);
    vk::logKeyNote(active ? "input method selected: taps stand down"
                          : "input method left: taps watch for the switch key");
}

} // extern "C"
