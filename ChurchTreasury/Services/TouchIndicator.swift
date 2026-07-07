#if DEBUG
import SwiftUI
import UIKit

/// Demo helper: draws an expanding ripple wherever the screen is tapped, so a
/// screen recording visibly shows every "click". Enabled only in DEBUG builds
/// launched with `-showTouches` (used for the walkthrough video). Never runs in
/// a normal launch.
@MainActor
enum TouchIndicator {
    static func enableIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-showTouches") else { return }
        // The window/scene isn't ready at launch — poll briefly until it is.
        attach(retries: 20)
    }

    private static func attach(retries: Int) {
        guard retries > 0 else { return }
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let appWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                attach(retries: retries - 1)
            }
            return
        }
        // Transparent, non-interactive overlay window on top of everything.
        let overlay = PassthroughWindow(windowScene: scene)
        overlay.backgroundColor = .clear
        overlay.windowLevel = .alert + 10
        overlay.isUserInteractionEnabled = false
        overlay.isHidden = false
        Holder.overlay = overlay

        // Observe every touch without consuming it.
        let observer = TouchObserver()
        observer.onTouchDown = { point in ripple(at: point, in: overlay) }
        appWindow.addGestureRecognizer(observer)
        Holder.observer = observer
    }

    private static func ripple(at point: CGPoint, in window: UIWindow) {
        let d: CGFloat = 78
        let dot = UIView(frame: CGRect(x: point.x - d/2, y: point.y - d/2, width: d, height: d))
        dot.layer.cornerRadius = d/2
        dot.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.28)
        dot.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.95).cgColor
        dot.layer.borderWidth = 3.5
        dot.isUserInteractionEnabled = false
        dot.transform = CGAffineTransform(scaleX: 0.45, y: 0.45)
        window.addSubview(dot)
        UIView.animate(withDuration: 0.55, delay: 0, options: [.curveEaseOut], animations: {
            dot.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            dot.alpha = 0
        }, completion: { _ in dot.removeFromSuperview() })
    }

    @MainActor
    private enum Holder {
        static var overlay: UIWindow?
        static var observer: UIGestureRecognizer?
    }
}

/// Window that never intercepts touches (so the app underneath stays usable).
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

/// A recognizer that only reports touch-down locations and never recognizes,
/// so it observes taps without cancelling them.
private final class TouchObserver: UIGestureRecognizer {
    var onTouchDown: ((CGPoint) -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let p = touches.first?.location(in: nil) { onTouchDown?(p) }
        // Stay .possible so we keep observing future touches; never block them.
    }
}
#endif
