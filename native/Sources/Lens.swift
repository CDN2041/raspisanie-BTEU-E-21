import SwiftUI

// Переключатель как панель вкладок в Apple Music на iOS 26:
// зажал, выделение превращается в стеклянную линзу, ведёшь пальцем, отпустил, и она садится на место.
struct Lens<Item: View>: View {
  let count: Int
  let index: Int
  var height: CGFloat = 40
  var radius: CGFloat = 20
  var fill: (Int) -> Color = { _ in C.fg }
  var disabled: (Int) -> Bool = { _ in false }
  let onPick: (Int) -> Void
  @ViewBuilder let item: (Int, Bool) -> Item // номер, выделен ли (при зажатии выделен тот, что под пальцем)

  @State private var finger: CGFloat? = Shot.screen == "lens" ? 150 : nil // для скриншота: линза как под пальцем
  @State private var settled: Int? = nil // куда отпустили: линза остаётся там, пока выбор не дойдёт до родителя
  @State private var hover: Int? = nil
  @State private var w: CGFloat = 1

  func row(sel: Bool) -> some View {
    let cw = w / CGFloat(max(1, count))
    return HStack(spacing: 0) {
      ForEach(0..<count, id: \.self) { i in
        item(i, sel).frame(width: cw, height: height).opacity(disabled(i) ? 0.3 : 1)
      }
    }
  }

  // Как панель вкладок в Telegram: выделение само и есть линза. Зажал, оно вырастает и едет за пальцем,
  // внутри него всё, что под ним, показано увеличенным и в «выбранном» виде, снаружи обычным.
  // Подписи не подменяются, а проплывают под линзой; выбор меняется, только когда отпустишь.
  var body: some View {
    let cw = w / CGFloat(max(1, count))
    let held = finger != nil
    let x = finger.map { min(max($0 - cw / 2, 0), w - cw) } ?? CGFloat(settled ?? index) * cw
    let cx = x + cw / 2
    let under = max(0, min(count - 1, Int(cx / max(1, cw))))
    let sx: CGFloat = held ? 1.2 : 1, sy: CGFloat = held ? 1.3 : 1
    let shape = RoundedRectangle(cornerRadius: held ? radius * 1.3 : radius, style: .continuous)
    ZStack(alignment: .leading) {
      row(sel: false)
      shape.fill(fill(under))
        .overlay {
          // Кромка стекла: тонкий блик с радужным отливом, виден только пока держишь
          shape.strokeBorder(AngularGradient(colors: [.white.opacity(0.9), .cyan.opacity(0.7), .clear, .purple.opacity(0.6), .orange.opacity(0.6), .clear, .white.opacity(0.9)], center: .center), lineWidth: 1.5)
            .opacity(held ? 1 : 0)
        }
        .frame(width: cw * sx, height: height * sy)
        .shadow(color: .black.opacity(held ? 0.35 : 0), radius: 10, y: 4)
        .offset(x: cx - cw * sx / 2)
      if w > 40 {
        row(sel: true)
          .frame(width: w, height: height)
          .scaleEffect(held ? 1.22 : 1, anchor: UnitPoint(x: cx / w, y: 0.5))
          .frame(height: height * 1.3)
          .mask(alignment: .leading) { shape.frame(width: cw * sx, height: height * sy).offset(x: cx - cw * sx / 2) }
          .allowsHitTesting(false)
      }
    }
    .frame(height: height)
    .frame(maxWidth: .infinity)
    .background(GeometryReader { g in Color.clear.onAppear { w = g.size.width }.onChange(of: g.size.width) { w = $0 } })
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { v in
          let i = max(0, min(count - 1, Int(v.location.x / max(1, cw))))
          if finger == nil { Haptic.soft() }
          withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.78)) { finger = v.location.x }
          if i != hover {
            if hover != nil { Haptic.pick() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { hover = i }
          }
        }
        .onEnded { v in
          var i = max(0, min(count - 1, Int(v.location.x / max(1, cw))))
          if disabled(i) { i = index }
          withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { finger = nil; hover = nil; settled = i }
          if i != index { onPick(i) }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { settled = nil } // на случай, если выбор не приняли
        }
    )
    .animation(.spring(response: 0.42, dampingFraction: 0.8), value: index)
    .onChange(of: index) { i in if settled == i { settled = nil } }
  }
}
