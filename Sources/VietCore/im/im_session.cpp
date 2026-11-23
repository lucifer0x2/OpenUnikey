// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "im/im_session.hpp"

#include "VietCore.h"

namespace vk {

bool ImSession::handle(CGEventRef event, VKTextReplacer replacer, void* context) {
    if (!event) return false;
    session_.setReplacementHandler(replacer, context);
    const bool consumed = session_.handle(nullptr, CGEventGetType(event), event) == nullptr;
    // Client pointers are only valid for this call, never across focus changes.
    session_.setReplacementHandler(nullptr, nullptr);
    return consumed;
}

void ImSession::reset() { vk_reset(); }

} // namespace vk
