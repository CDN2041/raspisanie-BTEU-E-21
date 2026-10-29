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

  @State private var finger: CGFloat? = nil
  @State private var settled: Int? = nil // куда отпустили: линза остаётся там, пока выбор не дойдёт до родителя
  @State private var hover: Int? = nil
  @State private var w: CGFloat = 1

  var body: some View {
    let cw = w / CGFloat(max(1, count))
    let held = finger != nil
    let shown = hover ?? settled ?? index
    let x = finger.map { min(max($0 - cw / 2, 0), w - cw) } ?? CGFloat(settled ?? index) * cw
    ZStack(alignment: .leading) {
      // Выделение: в покое залито, под пальцем стеклянная линза чуть больше ячейки
      Group {
        if held {
          RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill(shown).opacity(0.14))
            .glass(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
          RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill(shown))
        }
      }
      .frame(width: cw, height: height)
      .scaleEffect(held ? 1.14 : 1)
      .offset(x: x)
      HStack(spacing: 0) {
        ForEach(0..<count, id: \.self) { i in
          item(i, !held && i == shown)
            .frame(width: cw, height: height)
            .scaleEffect(held && i == hover ? 1.08 : 1)
            .opacity(disabled(i) ? 0.3 : 1)
        }
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
