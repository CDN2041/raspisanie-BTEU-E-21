import SwiftUI
import UIKit

// Жест вбок поверх прокрутки: начинается только если палец пошёл вбок,
// иначе сразу уступает прокрутке и её не задерживает
extension View {
  @ViewBuilder func sidePan(changed: @escaping (CGFloat) -> Void, ended: @escaping (CGFloat, CGFloat) -> Void) -> some View {
    if #available(iOS 18.0, *) { gesture(SidePan(changed: changed, ended: ended)) } else { self }
  }
}

@available(iOS 18.0, *)
struct SidePan: UIGestureRecognizerRepresentable {
  let changed: (CGFloat) -> Void
  let ended: (CGFloat, CGFloat) -> Void
  func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
    let g = UIPanGestureRecognizer()
    g.delegate = context.coordinator
    return g
  }
  func makeCoordinator(converter: CoordinateSpaceConverter) -> Co { Co() }
  func handleUIGestureRecognizerAction(_ g: UIPanGestureRecognizer, context: Context) {
    let t = g.translation(in: g.view).x
    switch g.state {
    case .changed: changed(t)
    case .ended: ended(t, g.velocity(in: g.view).x)
    case .cancelled, .failed: ended(0, 0)
    default: break
    }
  }
  final class Co: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
      guard let p = g as? UIPanGestureRecognizer else { return false }
      let v = p.velocity(in: p.view)
      return abs(v.x) > abs(v.y) * 1.3
    }
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
  }
}
