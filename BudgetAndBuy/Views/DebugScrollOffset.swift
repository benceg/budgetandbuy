import SwiftUI
import UIKit

#if DEBUG
/// Scrolls the enclosing list down by a number of points, for reproducing
/// scroll-position bugs in the simulator.
struct DebugScrollOffset: UIViewRepresentable {
    let points: Double

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            // The page's own scroll view: the largest one on screen.
            guard let window = view.window,
                  let scrollView = Self.scrollViews(in: window).max(by: { $0.bounds.height * $0.bounds.width < $1.bounds.height * $1.bounds.width })
            else { return }
            scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top + points), animated: false)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        let own = (view as? UIScrollView).map { [$0] } ?? []
        return own + view.subviews.flatMap(scrollViews(in:))
    }
}
#endif
