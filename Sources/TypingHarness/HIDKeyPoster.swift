import Foundation
import IOKit
import IOKit.hidsystem

/// Posts key events through the HID system (IOHIDPostEvent), the path a real
/// keyboard takes, instead of CGEventPost: the events reach event taps with
/// source pid 0 like hardware keys, so behaviour that depends on that shows up.
final class HIDKeyPoster: @unchecked Sendable {
    private var connect: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
                == KERN_SUCCESS else { return nil }
    }

    deinit { IOServiceClose(connect) }

    func key(_ code: UInt16, down: Bool, char: UInt16, flags: UInt32 = 0) -> Bool {
        var data = NXEventData()
        data.key.keyCode = code
        data.key.charCode = char
        data.key.origCharCode = char
        data.key.charSet = UInt16(NX_ASCIISET)
        data.key.repeat = 0
        data.key.keyboardType = 46
        let type = UInt32(down ? NX_KEYDOWN : NX_KEYUP)
        let result = IOHIDPostEvent(connect, type, IOGPoint(x: 0, y: 0), &data,
                                    UInt32(kNXEventDataVersion), flags, 0)
        return result == KERN_SUCCESS
    }
}
