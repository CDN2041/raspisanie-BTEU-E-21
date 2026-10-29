import SwiftUI

// Заголовок пары на экране «Сейчас»
struct LessonHead: View {
  let l: Lesson
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Tags(list: tags(l, nil))
      // Длинное слово не влезает в строку на телефоне: шрифт чуть меньше, чтобы слово не рвалось
      let long = l.s.components(separatedBy: " ").contains { $0.count > 13 }
      Text(l.s).font(.d(long ? 22 : 27, 700)).lineSpacing(2).foregroundColor(C.fg).fixedSize(horizontal: false, vertical: true)
      if !l.tch.isEmpty || !l.r.isEmpty {
        FlowRow(spacing: 14) {
          if !l.tch.isEmpty { Text(l.tch).font(.b(15)).foregroundColor(C.muted) }
          if !l.r.isEmpty { Text("ауд. " + l.r).font(.b(15)).foregroundColor(C.fg) }
        }
      }
      if !l.was.isEmpty { Text("Вместо: " + l.was).font(.b(13)).foregroundColor(C.muted) }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// Кнопка заметки под парой
struct NoteBlock: View {
  @EnvironmentObject var store: Store
  @EnvironmentObject var nav: Nav
  let l: Lesson, d: Date
  var body: some View {
    if canNote(l) {
      let t = store.note(d, l)
      Button { nav.openNote(d, l) } label: {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "pencil").font(.system(size: 15, weight: .semibold)).foregroundColor(t != nil ? C.note : C.muted).padding(.top, 2)
          Text(t ?? "Добавить заметку").font(.b(15)).foregroundColor(t != nil ? C.fg : C.muted)
            .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
        }
        .padding(14)
        .dashed(16, t != nil ? C.note : C.line)
      }
      .buttonStyle(Press())
    }
  }
}

// Короткий список пар: время, предмет, аудитория
struct Rows: View {
  @EnvironmentObject var store: Store
  let list: [Lesson], d: Date
  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(list.enumerated()), id: \.element.id) { i, l in
        HStack(spacing: 12) {
          Text(l.kind != nil ? l.time : (store.sched?.pairTime(l.p).0 ?? "")).font(.m(14, 700)).frame(width: 52, alignment: .leading)
          HStack(spacing: 6) {
            Text(l.s).font(.b(15, 500)).lineLimit(1).strikethrough(l.cancel).foregroundColor(l.cancel ? C.muted : C.fg)
            if store.note(d, l) != nil { Circle().fill(C.note).frame(width: 6, height: 6) }
          }.frame(maxWidth: .infinity, alignment: .leading)
          Text(l.cancel ? "отменена" : l.r).font(.m(13)).foregroundColor(C.muted)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { if i < list.count - 1 { Rectangle().fill(C.line).frame(height: 1) } }
      }
    }
  }
}

struct Section_: View {
  let title: String
  var body: some View { Eyebrow(text: title).frame(maxWidth: .infinity, alignment: .leading) }
}

struct CancelNote: View {
  @EnvironmentObject var store: Store
  let l: Lesson
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
      (Text("Отменена \(l.p) пара, \(store.sched?.pairTime(l.p).0 ?? ""): ") + Text(l.s).strikethrough())
        .font(.b(14)).frame(maxWidth: .infinity, alignment: .leading)
    }
    .foregroundColor(C.muted).padding(.horizontal, 14).padding(.vertical, 10).dashed(14)
  }
}

// Карточка пары в полном расписании
struct LessonCard: View {
  @EnvironmentObject var store: Store
  @EnvironmentObject var nav: Nav
  let l: Lesson, d: Date, cmp: Int, m: Int
  var body: some View {
    let isNow = !l.cancel && cmp == 0 && m >= l.a && m < l.b
    let isPast = cmp < 0 || (cmp == 0 && m >= l.b)
    let nt = store.note(d, l)
    let t = store.sched?.pairTime(l.p) ?? ("", "")
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 0) {
        Text("\(l.p) ПАРА").font(.b(11, 600)).tracking(0.44).foregroundColor(C.muted).padding(.bottom, 2)
        Text(t.0).font(.m(17, 700)).foregroundColor(C.fg)
        Text(t.1).font(.m(13)).foregroundColor(C.muted)
      }
      .frame(width: 62, alignment: .leading)
      CardBody(l: l, d: d, note: nt) {
        if isNow {
          let left = leftOf(l, m)
          PairBar(s: l.a, e: l.b, m: m, h1: l.h1, h2: l.h2).padding(.top, 6)
          Text(left.0 + dur(left.1)).font(.b(12, 600)).foregroundColor(C.live)
        }
      }
    }
    .padding(14)
    .padding(.trailing, canNote(l) ? 26 : 0)
    .card(16, border: isNow ? C.live : C.line, width: isNow ? 2 : 1)
    .overlay(alignment: .topTrailing) { pen(nt) }
    .opacity(l.cancel ? 0.55 : (isPast && nt == nil ? 0.45 : 1))
  }
  @ViewBuilder func pen(_ nt: String?) -> some View {
    if canNote(l) {
      Button { nav.openNote(d, l) } label: {
        Image(systemName: "pencil").font(.system(size: 17, weight: .medium)).foregroundColor(nt != nil ? C.note : C.muted)
          .frame(width: 40, height: 40)
      }.buttonStyle(Press(scale: 0.85)).padding(8)
    }
  }
}

// Время до перерыва или до конца пары
func leftOf(_ l: Lesson, _ m: Int) -> (String, Int) {
  if let h1 = l.h1, let h2 = l.h2, h1 > l.a, h2 < l.b, h2 > h1 {
    if m < h1 { return ("До перерыва ", h1 - m) }
    if m < h2 { return ("До конца перерыва ", h2 - m) }
  }
  return ("До конца пары осталось ", l.b - m)
}

struct CardBody<Extra: View>: View {
  let l: Lesson, d: Date, note: String?
  @ViewBuilder var extra: () -> Extra
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Tags(list: tags(l, d))
      Text(l.s).font(.b(16, 600)).foregroundColor(C.fg).strikethrough(l.cancel).fixedSize(horizontal: false, vertical: true)
      if !l.tch.isEmpty { Text(l.tch).font(.b(14)).foregroundColor(C.muted) }
      if !l.was.isEmpty { Text("Вместо: " + l.was).font(.b(12)).foregroundColor(C.muted) }
      if !l.r.isEmpty { (Text("ауд. ").font(.b(12)).foregroundColor(C.muted) + Text(l.r).font(.m(13)).foregroundColor(C.fg)) }
      extra()
      if let n = note {
        HStack(spacing: 6) {
          Image(systemName: "pencil").font(.system(size: 12, weight: .semibold))
          Text(n.components(separatedBy: "\n").first ?? n).font(.b(13)).lineLimit(1)
        }
        .foregroundColor(C.note).padding(.top, 8)
        .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1).mask(DashMask()).padding(.top, -2) }
        .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
struct DashMask: View {
  var body: some View {
    GeometryReader { g in
      Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: g.size.width * 4, y: 0)) }
        .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
    }
  }
}

// Событие сессии в полном расписании
struct ItemCard: View {
  @EnvironmentObject var store: Store
  @EnvironmentObject var nav: Nav
  let l: Lesson, d: Date, cmp: Int
  var body: some View {
    let nt = store.note(d, l)
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 0) {
        Text("НАЧАЛО").font(.b(11, 600)).tracking(0.44).foregroundColor(C.muted).padding(.bottom, 2)
        Text(l.time).font(.m(17, 700)).foregroundColor(C.fg)
      }.frame(width: 62, alignment: .leading)
      CardBody(l: l, d: d, note: nt) { EmptyView() }
    }
    .padding(14).padding(.trailing, 26).card(16)
    .overlay(alignment: .topTrailing) {
      Button { nav.openNote(d, l) } label: {
        Image(systemName: "pencil").font(.system(size: 17, weight: .medium)).foregroundColor(nt != nil ? C.note : C.muted).frame(width: 40, height: 40)
      }.buttonStyle(Press(scale: 0.85)).padding(8)
    }
    .opacity(cmp < 0 && nt == nil ? 0.45 : 1)
  }
}

// Перерывы между парами
struct GapView: View {
  enum Kind { case small, big, window }
  let kind: Kind, gs: Int, ge: Int, m: Int, cmp: Int
  var body: some View {
    let on = cmp == 0 && m >= gs && m < ge
    let past = cmp < 0 || (cmp == 0 && m >= ge)
    let fill = cmp < 0 ? 1 : cmp > 0 ? 0 : max(0, min(1, Double(m - gs) / Double(max(1, ge - gs))))
    let col = on ? C.live : C.muted
    Group {
      switch kind {
      case .small:
        HStack(spacing: 12) {
          Text(dur(ge - gs)).font(.m(12)).frame(width: 62, alignment: .leading)
          Text(on ? "Перерыв, ещё " + dur(ge - m) : "Перерыв").font(.b(12, on ? 600 : 400))
          Spacer(minLength: 0)
        }
        .foregroundColor(col).padding(.horizontal, 14).padding(.vertical, 6)
        .background(fillBar(fill, on, 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? C.live : C.line, style: StrokeStyle(lineWidth: 1, dash: on ? [] : [4, 3])))
        .padding(.vertical, -3)
      case .big:
        HStack(spacing: 12) {
          Image(systemName: "cup.and.saucer").font(.system(size: 16)).frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 10).fill(C.bg))
          VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
              Text("Большой перерыв").font(.b(15, 600))
              Spacer()
              Text(on ? "ещё " + dur(ge - m) : dur(ge - gs)).font(.b(13, 600))
            }
            Text(fmtMin(gs) + " - " + fmtMin(ge)).font(.m(12)).opacity(0.8)
          }
        }
        .foregroundColor(col).padding(.horizontal, 14).padding(.vertical, 12)
        .background(fillBar(fill, on, 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(on ? C.live : C.line, style: StrokeStyle(lineWidth: 1, dash: on ? [] : [4, 3])))
      case .window:
        HStack(spacing: 10) {
          DashLine()
          Text("Окно " + dur(ge - gs) + (on ? ", ещё " + dur(ge - m) : "")).font(.b(13, on ? 600 : 400)).fixedSize()
          DashLine()
        }.foregroundColor(col).padding(.vertical, 2)
      }
    }
    .opacity(past && !on ? 1 : 1)
  }
  func fillBar(_ f: Double, _ on: Bool, _ r: CGFloat) -> some View {
    GeometryReader { g in
      Rectangle().fill(on ? C.liveSoft : C.pastSoft).frame(width: g.size.width * CGFloat(f))
    }.clipShape(RoundedRectangle(cornerRadius: r))
  }
}
struct DashLine: View {
  var body: some View {
    GeometryReader { g in
      Path { p in p.move(to: CGPoint(x: 0, y: g.size.height / 2)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height / 2)) }
        .stroke(C.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    }.frame(height: 10)
  }
}

// Сегментированный переключатель как на сайте
struct Seg: View {
  let items: [(String, String)]
  @Binding var value: String
  @Namespace private var ns
  var body: some View {
    HStack(spacing: 4) {
      ForEach(items, id: \.0) { it in
        Button {
          guard value != it.0 else { return }
          Haptic.pick()
          withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { value = it.0 }
        } label: {
          Text(it.1).font(.b(14, value == it.0 ? 600 : 500)).foregroundColor(value == it.0 ? C.bg : C.muted)
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 4)
            .background {
              if value == it.0 { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(C.fg).matchedGeometryEffect(id: "k", in: ns) }
            }
        }.buttonStyle(Press(scale: 0.96))
      }
    }
    .padding(3)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.bg))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(C.line, lineWidth: 1))
  }
}

// Кнопки шторок
struct Btn: View {
  enum Kind { case primary, ghost, del, danger }
  let title: String
  var kind: Kind = .ghost
  let action: () -> Void
  var body: some View {
    Button { Haptic.tap(); action() } label: {
      Text(title).font(.b(15, 600))
        .foregroundColor(kind == .primary ? C.bg : kind == .del ? C.warn : kind == .danger ? C.bg : C.fg)
        .frame(maxWidth: kind == .del ? nil : .infinity).padding(.vertical, 14).padding(.horizontal, 16)
        .glass(Capsule(), tint: kind == .primary ? C.fg : kind == .danger ? C.warn : nil)
    }.buttonStyle(Press(scale: 0.96))
  }
}

// Номер версии внизу: 20 быстрых нажатий включают режим «телефон 2»
struct VersionFooter: View {
  @EnvironmentObject var store: Store
  @State private var n = 0
  @State private var last = Date.distantPast
  @State private var flash: String? = nil
  var body: some View {
    let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    Text(flash ?? "v " + v).font(.b(12)).monospacedDigit().foregroundColor(C.muted)
      .frame(maxWidth: .infinity).padding(.top, 24).padding(.bottom, 8)
      .contentShape(Rectangle())
      .onTapGesture {
        if Date().timeIntervalSince(last) > 1.5 { n = 0 }
        last = Date(); n += 1
        guard n >= 20 else { return }
        n = 0
        let was = store.p2
        store.toggleP2()
        Haptic.ok()
        flash = was ? "·" : "··"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { flash = nil }
      }
  }
}
