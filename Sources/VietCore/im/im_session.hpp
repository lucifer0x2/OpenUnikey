// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// InputMethodKit reuses the tap's engine and key semantics, but commits text
// through the focused client synchronously. No synthetic keys, echo matching,
// timeout, or pending rewrite can outlive a physical key's handler.
#pragma once

#include "tap/tap_session.hpp"

namespace vk {

class ImSession {
public:
    bool handle(CGEventRef event, VKTextReplacer replacer = nullptr, void* context = nullptr);
    void reset();

private:
    TapSession session_{true};
};

} // namespace vk
