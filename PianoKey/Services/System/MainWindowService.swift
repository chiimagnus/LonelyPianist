import AppKit
import SwiftData
import SwiftUI

@MainActor
final class MainWindowService {
    private let modelContainer: ModelContainer
    private let viewModel: PianoKeyViewModel

    private var window: NSWindow?
    private var windowDelegate: WindowDelegate?

    init(modelContainer: ModelContainer, viewModel: PianoKeyViewModel) {
        self.modelContainer = modelContainer
        self.viewModel = viewModel
    }

    func show(section: PianoKeyViewModel.MainWindowSection? = nil) {
        if let section {
            viewModel.selectedMainWindowSection = section
        }

        if window == nil {
            window = buildWindow()
        }

        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() -> NSWindow {
        let rootView = MainWindowView(viewModel: viewModel)
            .modelContainer(modelContainer)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "PianoKey"
        window.minSize = NSSize(width: 860, height: 640)
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)

        let delegate = WindowDelegate { [weak self] in
            self?.window = nil
            self?.windowDelegate = nil
        }
        window.delegate = delegate
        windowDelegate = delegate

        return window
    }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

