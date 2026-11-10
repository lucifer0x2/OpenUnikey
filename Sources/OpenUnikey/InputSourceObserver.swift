import Carbon
import Foundation
import OpenUnikeyShared
import VietCore

/// Follows the selected input source. While it is OpenUnikey's input method,
/// the taps let every key through (the switch key included: the input method
/// sees it); otherwise they watch for the switch key only.
@MainActor
final class InputSourceObserver {
    private var token: NSObjectProtocol?
    private(set) var isVietnamese = false

    func start(onChange: @escaping @MainActor () -> Void) {
        update()
        token = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.update()
                onChange()
            }
        }
    }

    private func update() {
        isVietnamese = InputSources.isVietnameseSelected
        vk_set_input_method_active(isVietnamese)
    }
}
