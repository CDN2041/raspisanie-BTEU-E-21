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

  func row(held: Bool, shown: Int, cw: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(0..<count, id: \.self) { i in
        item(i, !held && i == shown)
          .frame(width: cw, height: height)
          .opacity(disabled(i) ? 0.3 : 1)
      }
    }
  }

  var body: some View {
    let cw = w / CGFloat(max(1, count))
    let held = finger != nil
    let shown = hover ?? settled ?? index
    let x = finger.map { min(max($0 - cw / 2, 0), w - cw) } ?? CGFloat(settled ?? index) * cw
    ZStack(alignment: .leading) {
      // Выделение в покое: залитая плашка под подписями
      RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill(shown))
        .frame(width: cw, height: height)
        .opacity(held ? 0 : 1)
        .offset(x: x)
      row(held: held, shown: shown, cw: cw)
      // Под пальцем: стеклянная лупа поверх подписей. Внутри неё то же самое, что лежит под ней,
      // только увеличенное: подписи плывут под стеклом и не подменяются, выбор меняется только когда отпустишь.
      if held && w > 40 { // пока ширина не измерена, лупу не рисуем: иначе размеры выходят отрицательными
        let lw = cw * 1.22, lh = height * 1.3, cx = x + cw / 2
        let shape = RoundedRectangle(cornerRadius: radius * 1.2, style: .continuous)
        ZStack(alignment: .leading) {
          Color.clear.frame(width: lw, height: lh).clearGlass(shape)
            .offset(x: cx - lw / 2)
          row(held: true, shown: shown, cw: cw)
            .frame(width: w, height: height)
            .scaleEffect(1.2, anchor: UnitPoint(x: cx / max(1, w), y: 0.5))
            .frame(height: lh)
            .mask(alignment: .leading) { shape.frame(width: max(1, lw - 4), height: max(1, lh - 4)).offset(x: cx - lw / 2 + 2) }
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .transition(.scale(scale: 0.85, anchor: UnitPoint(x: cx / max(1, w), y: 0.5)).combined(with: .opacity))
        .zIndex(2)
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
