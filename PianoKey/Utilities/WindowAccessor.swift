import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        AccessorView(onWindow: onWindow)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class AccessorView: NSView {
    private let onWindow: (NSWindow) -> Void
    private var didConfigure = false

    init(onWindow: @escaping (NSWindow) -> Void) {
        self.onWindow = onWindow
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window, !didConfigure else { return }
        didConfigure = true

        DispatchQueue.main.async { [onWindow] in
            onWindow(window)
        }
    }
}

