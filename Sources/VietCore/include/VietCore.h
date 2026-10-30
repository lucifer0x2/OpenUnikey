// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// C interface of the core: typing engine plus the system-wide event tap.
#ifndef VIETCORE_H
#define VIETCORE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum { VK_TELEX = 0, VK_VNI = 1, VK_SIMPLE_TELEX = 2 } VKInputMethod;
typedef enum { VK_SWITCH_CONTROL_SHIFT = 0, VK_SWITCH_OPTION_Z = 1 } VKSwitchKey;

// How a word is rewritten in apps whose autocomplete selects text as you type.
typedef enum {
    VK_AUTOCOMPLETE_NONE = 0,
    VK_AUTOCOMPLETE_FILLER = 1,      // type a throwaway char first (Safari, Firefox)
    VK_AUTOCOMPLETE_SELECT_LEFT = 2, // Shift+Left before deleting (Chromium browsers)
} VKAutocompleteFix;

typedef struct {
    VKInputMethod method;
    bool freeMarking;
    bool modernStyle;
    bool spellCheck;
    bool autoRestore;
    bool bracketShortcuts;
} VKOptions;

// Called on the event tap thread when the switch key toggles V/E.
typedef void (*VKModeCallback)(bool vietnamese, void *context);

// ---- Global input state (safe to call from any thread) ----
void vk_set_options(const VKOptions *options);
void vk_set_vietnamese(bool enabled);
bool vk_is_vietnamese(void);
void vk_set_switch_key(VKSwitchKey key);
// Autocomplete workaround for the focused app.
void vk_set_autocomplete_fix(VKAutocompleteFix fix);
// Forgets the word being typed (focus or app change).
void vk_reset(void);
void vk_set_mode_callback(VKModeCallback callback, void *context);

// ---- Event tap (needs the Accessibility permission) ----
bool vk_tap_start(void);
void vk_tap_stop(void);
bool vk_tap_running(void);

// ---- Standalone engine, used by tests ----
typedef struct VKEngine VKEngine;
VKEngine *vk_engine_create(const VKOptions *options);
void vk_engine_destroy(VKEngine *engine);
void vk_engine_reset(VKEngine *engine);
// Each call returns how many UTF-16 units to insert after deleting *backs
// characters. 0 inserted and 0 deleted means the key passes through unchanged.
int vk_engine_process(VKEngine *engine, uint8_t ch, bool shift, bool capsLock, int *backs);
int vk_engine_backspace(VKEngine *engine, int *backs);
int vk_engine_end_word(VKEngine *engine, int *backs);
const uint16_t *vk_engine_output(const VKEngine *engine);

#ifdef __cplusplus
}
#endif

#endif
