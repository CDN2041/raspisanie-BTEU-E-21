import SwiftUI
import UIKit
import CoreText

// ---------- Цвета: те же, что на сайте ----------
extension UIColor {
  convenience init(hex: UInt32, a: CGFloat = 1) {
    self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
  }
}
func dyn(_ l: UInt32, _ d: UInt32) -> Color {
  Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: d) : UIColor(hex: l) })
}
enum C {
  static let bg = dyn(0xEDEFF3, 0x050608)
  static let surface = dyn(0xFFFFFF, 0x101318)
  static let fg = dyn(0x141821, 0xE8EBF1)
  static let muted = dyn(0x646C7E, 0x8B93A5)
  static let line = dyn(0xD7DBE4, 0x1F242D)
  static let warn = dyn(0xB4231B, 0xFF7A70)
  static let note = dyn(0xA86A12, 0xE8A94B)
  static let noteSoft = dyn(0xFBF0DC, 0x21180A)
  static var live: Color { fg }
  static var liveSoft: Color { fg.opacity(0.26) }
  static var pastSoft: Color { muted.opacity(0.24) }
}

// ---------- Шрифты: Golos Text, Unbounded, JetBrains Mono из сборки ----------
enum Fonts {
  private static var descs: [String: CTFontDescriptor] = [:]
  private static var cache: [String: UIFont] = [:]
  static func load() {
    for n in ["GolosText", "Unbounded", "JetBrainsMono"] {
      guard let u = Bundle.main.url(forResource: n, withExtension: "ttf"),
            let arr = CTFontManagerCreateFontDescriptorsFromURL(u as CFURL) as? [CTFontDescriptor], let d = arr.first else { continue }
      descs[n] = d
    }
  }
  static func ui(_ name: String, _ size: CGFloat, _ w: CGFloat) -> UIFont {
    let ck = "\(name)|\(size)|\(w)"
    if let f = cache[ck] { return f }
    var f: UIFont
    if let d = descs[name] {
      let wght: UInt32 = 0x77676874 // ось 'wght'
      let vd = CTFontDescriptorCreateCopyWithAttributes(d, [kCTFontVariationAttribute: [wght: w]] as CFDictionary)
      f = CTFontCreateWithFontDescriptor(vd, size, nil) as UIFont
    } else {
      let sw: UIFont.Weight = w >= 700 ? .bold : w >= 600 ? .semibold : w >= 500 ? .medium : .regular
      f = name == "JetBrainsMono" ? .monospacedSystemFont(ofSize: size, weight: sw) : .systemFont(ofSize: size, weight: sw)
    }
    cache[ck] = f
    return f
  }
}
extension Font {
  static func b(_ s: CGFloat, _ w: CGFloat = 400) -> Font { Font(Fonts.ui("GolosText", s, w) as CTFont) }   // основной
  static func d(_ s: CGFloat, _ w: CGFloat = 700) -> Font { Font(Fonts.ui("Unbounded", s, w) as CTFont) }   // заголовки
  static func m(_ s: CGFloat, _ w: CGFloat = 500) -> Font { Font(Fonts.ui("JetBrainsMono", s, w) as CTFont) } // цифры
}

// ---------- Отклик ----------
enum Haptic {
  static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
  static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
  static func pick() { UISelectionFeedbackGenerator().selectionChanged() }
  static func ok() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
  static func warn() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// Нажатие: лёгкое сжатие на пружине, как у системных кнопок
struct Press: ButtonStyle {
  var scale: CGFloat = 0.97
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(Rectangle())
      .scaleEffect(configuration.isPressed ? scale : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
  }
}

// ---------- Мелкие элементы ----------
struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased()).font(.b(12, 600)).tracking(0.72).foregroundColor(C.muted)
  }
}

struct Tag: View {
  enum Style { case lec, prac, mix, new, sub, cancel, exam, credit, plain }
  let text: String
  let style: Style
  var body: some View {
    Text(text.uppercased())
      .font(.b(11, 600)).tracking(0.44)
      .padding(.horizontal, 6).padding(.vertical, 2)
      .foregroundColor(fgc)
      .background(RoundedRectangle(cornerRadius: 6).fill(fill))
      .overlay(border)
  }
  private var fgc: Color {
    switch style { case .prac, .exam: return C.bg; case .cancel: return C.muted; default: return C.fg }
  }
  private var fill: Color {
    switch style { case .prac, .exam: return C.fg; case .new: return C.liveSoft; default: return .clear }
  }
  @ViewBuilder private var border: some View {
    switch style {
    case .lec, .cancel, .plain: RoundedRectangle(cornerRadius: 6).strokeBorder(C.muted, lineWidth: 1)
    case .mix, .credit: RoundedRectangle(cornerRadius: 6).strokeBorder(C.fg, lineWidth: 1)
    case .sub: RoundedRectangle(cornerRadius: 6).strokeBorder(C.fg, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
    default: EmptyView()
    }
  }
}

func tags(_ l: Lesson, _ d: Date?) -> [(String, Tag.Style)] {
  var r: [(String, Tag.Style)] = []
  if let k = l.kind {
    r.append((KINDS[k] ?? "", k == "exam" ? .exam : k == "credit" ? .credit : .plain))
    return r
  }
  if l.t == "lec" { r.append(("Лекция", .lec)) }
  if l.t == "prac" { r.append(("Практика", .prac)) }
  if l.t == "mix" { r.append(("Лекция/Практика", .mix)) }
  if l.cancel { r.append(("Отменена", .cancel)) }
  else if l.ed { r.append(("Изменено", .sub)) }
  else if l.sub == "rep" { r.append(("Замена", .sub)) }
  else if l.sub == "add" { r.append(("Доп. пара", .sub)) }
  if let d, !l.from.isEmpty, l.from == key(d), let f = pd(l.from) { r.append(("с \(dnum(f)) \(MON[mnum(f)])", .new)) }
  return r
}

struct Tags: View {
  let list: [(String, Tag.Style)]
  var body: some View {
    FlowRow(spacing: 6) { ForEach(Array(list.enumerated()), id: \.offset) { Tag(text: $0.element.0, style: $0.element.1) } }
  }
}

// Строка, которая переносит элементы, если не влезают
struct FlowRow: Layout {
  var spacing: CGFloat = 6
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let w = proposal.width ?? .infinity
    var x: CGFloat = 0, y: CGFloat = 0, rh: CGFloat = 0, mw: CGFloat = 0
    for s in subviews {
      let z = s.sizeThatFits(.unspecified)
      if x > 0 && x + z.width > w { x = 0; y += rh + spacing; rh = 0 }
      x += z.width + spacing; rh = max(rh, z.height); mw = max(mw, x - spacing)
    }
    return CGSize(width: min(mw, w), height: y + rh)
  }
  func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = b.minX, y = b.minY, rh: CGFloat = 0
    for s in subviews {
      let z = s.sizeThatFits(.unspecified)
      if x > b.minX && x + z.width > b.maxX { x = b.minX; y += rh + spacing; rh = 0 }
      s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
      x += z.width + spacing; rh = max(rh, z.height)
    }
  }
}

// Шкала пары: если в звонках есть пятиминутка, она показывается ровно в своё время
struct PairBar: View {
  let s: Int, e: Int, m: Int
  let h1: Int?, h2: Int?
  var height: CGFloat = 4
  var split: Bool { guard let h1, let h2 else { return false }; return h1 > s && h2 < e && h2 > h1 }
  var body: some View {
    GeometryReader { g in
      if split, let h1, let h2 {
        let w = max(0, g.size.width - 6), t = CGFloat(max(1, e - s))
        HStack(spacing: 3) {
          seg(Double(m - s) / Double(h1 - s)).frame(width: w * CGFloat(h1 - s) / t)
          brk(m < h1 ? 0 : Double(m - h1) / Double(h2 - h1)).frame(width: w * CGFloat(h2 - h1) / t)
          seg(m < h2 ? 0 : Double(m - h2) / Double(e - h2)).frame(width: w * CGFloat(e - h2) / t)
        }
      } else {
        seg(Double(m - s) / Double(max(1, e - s)))
      }
    }
    .frame(height: height)
    .animation(.spring(response: 1, dampingFraction: 0.9), value: m)
  }
  func seg(_ f: Double) -> some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(C.line)
        Capsule().fill(C.live).frame(width: g.size.width * CGFloat(max(0, min(1, f))))
      }
    }.frame(height: height).clipShape(Capsule())
  }
  func brk(_ f: Double) -> some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().strokeBorder(C.line, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        Capsule().fill(C.live).frame(width: g.size.width * CGFloat(max(0, min(1, f))))
      }
    }.frame(height: height).clipShape(Capsule())
  }
}
// Значок недели: черта и точка над или под ней
struct WeekGlyph: View {
  let over: Bool
  var body: some View {
    Canvas { ctx, size in
      let w = size.width, h = size.height
      var p = Path(); p.move(to: CGPoint(x: w * 0.12, y: h / 2)); p.addLine(to: CGPoint(x: w * 0.88, y: h / 2))
      ctx.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
      let cy = over ? h * 0.25 : h * 0.75, r = w * 0.133
      ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - r, y: cy - r, width: r * 2, height: r * 2)), with: .foreground)
    }
  }
}

// Плавное появление блоков по очереди
struct Rise: ViewModifier {
  let i: Int
  let on: Bool
  @State private var shown = false
  func body(content: Content) -> some View {
    content
      .opacity(shown || !on ? 1 : 0)
      .offset(y: shown || !on ? 0 : 10)
      .onAppear {
        guard on, !shown else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(Double(min(i, 8)) * 0.04)) { shown = true }
      }
  }
}
// Liquid Glass на iOS 26, на старых системах обычная карточка
extension View {
  @ViewBuilder func glass<S: Shape>(_ s: S, tint: Color? = nil) -> some View {
    if #available(iOS 26.0, *) {
      self.glassEffect(Glass.regular.tint(tint).interactive(), in: s)
    } else {
      self.background(s.fill(tint ?? C.surface)).overlay(s.stroke(tint == nil ? C.line : .clear, lineWidth: 1))
    }
  }
}

extension View {
  func rise(_ i: Int, _ on: Bool = true) -> some View { modifier(Rise(i: i, on: on)) }
  func card(_ r: CGFloat = 16, border: Color = C.line, width: CGFloat = 1) -> some View {
    self.background(RoundedRectangle(cornerRadius: r, style: .continuous).fill(C.surface))
      .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).strokeBorder(border, lineWidth: width))
  }
  func dashed(_ r: CGFloat, _ c: Color = C.line) -> some View {
    overlay(RoundedRectangle(cornerRadius: r, style: .continuous).strokeBorder(c, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
  }
}
