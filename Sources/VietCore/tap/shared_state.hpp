// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// State written by the UI thread and read by the event tap thread.
#pragma once

#include <atomic>
#include <cstdint>

#include "VietCore.h"
#include "engine/engine.hpp"

namespace vk {

struct SharedState {
    std::atomic<bool> vietnamese{true};
    std::atomic<uint32_t> optionBits{0};
    std::atomic<uint32_t> optionVersion{0};
    std::atomic<bool> resetRequested{false};
    std::atomic<int> autocompleteFix{VK_AUTOCOMPLETE_NONE};
    std::atomic<int> switchKey{VK_SWITCH_CONTROL_SHIFT};
    std::atomic<VKModeCallback> modeCallback{nullptr};
    std::atomic<void*> modeContext{nullptr};
    std::atomic<VKSwitchCallback> switchCallback{nullptr};
    std::atomic<void*> switchContext{nullptr};
    // OpenUnikey's input method is the selected input source: it types, the
    // taps only let keys through.
    std::atomic<bool> inputMethodActive{false};
};

SharedState& sharedState();

Options toEngineOptions(const VKOptions& options);
uint32_t packOptions(const Options& options);
Options unpackOptions(uint32_t bits);

} // namespace vk
