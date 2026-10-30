// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "VietCore.h"

#include "engine/engine.hpp"
#include "tap/key_log.hpp"
#include "tap/shared_state.hpp"

namespace vk {

SharedState& sharedState() {
    static SharedState state;
    return state;
}

Options toEngineOptions(const VKOptions& o) {
    Options options;
    switch (o.method) {
    case VK_VNI:
        options.method = InputMethod::Vni;
        break;
    case VK_SIMPLE_TELEX:
        options.method = InputMethod::SimpleTelex;
        break;
    default:
        options.method = InputMethod::Telex;
    }
    options.freeMarking = o.freeMarking;
    options.modernStyle = o.modernStyle;
    options.spellCheck = o.spellCheck;
    options.autoRestore = o.autoRestore;
    options.bracketShortcuts = o.bracketShortcuts;
    return options;
}

uint32_t packOptions(const Options& o) {
    return (uint32_t)o.method | (o.freeMarking << 8) | (o.modernStyle << 9) |
           (o.spellCheck << 10) | (o.autoRestore << 11) | (o.bracketShortcuts << 12);
}

Options unpackOptions(uint32_t bits) {
    Options o;
    o.method = (InputMethod)(bits & 0xFF);
    o.freeMarking = bits & (1u << 8);
    o.modernStyle = bits & (1u << 9);
    o.spellCheck = bits & (1u << 10);
    o.autoRestore = bits & (1u << 11);
    o.bracketShortcuts = bits & (1u << 12);
    return o;
}

} // namespace vk

using vk::sharedState;

extern "C" {

void vk_set_options(const VKOptions* options) {
    sharedState().optionBits.store(vk::packOptions(vk::toEngineOptions(*options)));
    sharedState().optionVersion.fetch_add(1);
}

void vk_set_vietnamese(bool enabled) {
    sharedState().vietnamese.store(enabled);
    sharedState().resetRequested.store(true);
}

bool vk_is_vietnamese(void) { return sharedState().vietnamese.load(); }

void vk_set_switch_key(VKSwitchKey key) { sharedState().switchKey.store(key); }

void vk_set_autocomplete_fix(VKAutocompleteFix fix) { sharedState().autocompleteFix.store(fix); }

void vk_reset(void) { sharedState().resetRequested.store(true); }

void vk_set_key_logging(bool enabled) { vk::setKeyLogEnabled(enabled); }

void vk_set_mode_callback(VKModeCallback callback, void* context) {
    sharedState().modeContext.store(context);
    sharedState().modeCallback.store(callback);
}

struct VKEngine {
    vk::Engine engine;
};

VKEngine* vk_engine_create(const VKOptions* options) {
    auto* handle = new VKEngine();
    if (options) handle->engine.configure(vk::toEngineOptions(*options));
    return handle;
}

void vk_engine_destroy(VKEngine* engine) { delete engine; }

void vk_engine_reset(VKEngine* engine) { engine->engine.reset(); }

static int result(const vk::Engine& engine, int* backs) {
    if (backs) *backs = engine.backs();
    return engine.outputLength();
}

int vk_engine_process(VKEngine* engine, uint8_t ch, bool shift, bool capsLock, int* backs) {
    engine->engine.process(ch, shift, capsLock);
    return result(engine->engine, backs);
}

int vk_engine_backspace(VKEngine* engine, int* backs) {
    engine->engine.backspace();
    return result(engine->engine, backs);
}

int vk_engine_end_word(VKEngine* engine, int* backs) {
    engine->engine.endWord();
    return result(engine->engine, backs);
}

const uint16_t* vk_engine_output(const VKEngine* engine) { return engine->engine.output(); }

} // extern "C"
