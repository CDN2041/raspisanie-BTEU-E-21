import SwiftUI
import CoreText

// ---------- Вид: тёмная тема сайта, те же шрифты ----------
extension Color {
  init(hex: UInt32) {
    self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
  }
}
enum W {
  static let surface = Color(hex: 0x14171D)
  static let fg = Color(hex: 0xE8EBF1)
  static let muted = Color(hex: 0x8B93A5)
  static let line = Color(hex: 0x2A303A)
  static let warn = Color(hex: 0xFF7A70)
  static let note = Color(hex: 0xE8A94B)
}
enum WFonts {
  private static var descs: [String: CTFontDescriptor] = [:]
  static func load() {
    for n in ["GolosText", "JetBrainsMono"] {
      guard let u = Bundle.main.url(forResource: n, withExtension: "ttf"),
            let arr = CTFontManagerCreateFontDescriptorsFromURL(u as CFURL) as? [CTFontDescriptor], let d = arr.first else { continue }
      descs[n] = d
    }
  }
  static func font(_ name: String, _ size: CGFloat, _ w: CGFloat) -> Font {
    guard let d = descs[name] else {
      let sw: Font.Weight = w >= 700 ? .bold : w >= 500 ? .medium : .regular
      return .system(size: size, weight: sw, design: name == "JetBrainsMono" ? .monospaced : .default)
    }
    let wght: UInt32 = 0x77676874
    let vd = CTFontDescriptorCreateCopyWithAttributes(d, [kCTFontVariationAttribute: [wght: w]] as CFDictionary)
    return Font(CTFontCreateWithFontDescriptor(vd, size, nil))
  }
}
extension Font {
  static func b(_ s: CGFloat, _ w: CGFloat = 400) -> Font { WFonts.font("GolosText", s, w) }
  static func m(_ s: CGFloat, _ w: CGFloat = 500) -> Font { WFonts.font("JetBrainsMono", s, w) }
}

// ---------- Данные: своя копия расписания, обновление с сайта ----------
enum WShot {
  static let env = ProcessInfo.processInfo.environment
  static let now: Date? = {
    guard let s = env["SHOT_NOW"] else { return nil }
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)
  }()
  static let page = env["SHOT_PAGE"] ?? ""
}

final class WStore: ObservableObject {
  @Published var sc: Sched?
  @Published var rev = 0
  private let file: URL = {
    let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d.appendingPathComponent("schedule.json")
  }()
  private var last = Date.distantPast

  init() {
    if let d = try? Data(contentsOf: file), adopt(d) { return }
    if let u = Bundle.main.url(forResource: "schedule", withExtension: "json"), let d = try? Data(contentsOf: u) { _ = adopt(d) }
  }

  func now(_ t: Date = Date()) -> Date { WShot.now ?? t }

  @discardableResult private func adopt(_ d: Data) -> Bool {
    guard let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any], Sched.valid(o) else { return false }
    let u = UserDefaults.standard
    guard let s = Sched(o, p2: u.string(forKey: "pary-e21-p2") == "1", noFive: u.string(forKey: "pary-e21-nofive") == "1") else { return false }
    sc = s; rev += 1
    return true
  }

  // Не чаще раза в 5 минут, только если расписание изменилось
  @MainActor func fetch() async {
    if WShot.now != nil || Date().timeIntervalSince(last) < 300 { return }
    last = Date()
    var req = URLRequest(url: URL(string: "https://cdn2041.github.io/raspisanie-BTEU-E-21/schedule.json")!,
                         cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    guard let res = try? await URLSession.shared.data(for: req), (res.1 as? HTTPURLResponse)?.statusCode == 200 else { return }
    let d = res.0
    if let old = try? Data(contentsOf: file), old == d { return }
    if adopt(d) { try? d.write(to: file, options: .atomic) }
  }
}

// ---------- Приложение ----------
@main
struct ParyWatchApp: App {
  @StateObject private var st = WStore()
  @Environment(\.scenePhase) private var phase
  init() { WFonts.load() }
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(st)
        .task { await st.fetch() }
        .onChange(of: phase) { _, p in if p == .active { Task { await st.fetch() } } }
    }
  }
}

struct RootView: View {
  @EnvironmentObject var st: WStore
  @State private var page = WShot.page == "day" ? 1 : 0
  var body: some View {
    if let sc = st.sc {
      NavigationStack {
        TabView(selection: $page) {
          NowPage(sc: sc).tag(0)
          DayPage(sc: sc).tag(1)
        }
        .tabViewStyle(.verticalPage)
      }
      .id(st.rev)
    } else {
      VStack(spacing: 6) {
        Text("Нет расписания").font(.b(15, 600)).foregroundStyle(W.fg)
        Text("Нужен интернет для первой загрузки").font(.b(12)).foregroundStyle(W.muted).multilineTextAlignment(.center)
      }
    }
  }
}

// ---------- «Сейчас»: крупно свежее, внизу следующая пара ----------
struct NowPage: View {
  @EnvironmentObject var st: WStore
  let sc: Sched
  var body: some View {
    TimelineView(.everyMinute) { ctx in
      let t = st.now(ctx.date)
      let s = widgetState(sc, t)
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          if s.kind == .done { done(s, t) } else { live(s) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle(s.date)
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @ViewBuilder func live(_ s: WState) -> some View {
    Text(s.head).font(.m(12)).foregroundStyle(W.muted).lineLimit(1).minimumScaleFactor(0.7)
    Text(s.big).font(.m(36, 700)).foregroundStyle(W.fg).lineLimit(1).minimumScaleFactor(0.5)
    if let f = s.frac { Bar(f: f).padding(.top, 4) }
    Text(s.subj).font(.b(15, 500)).foregroundStyle(W.fg).lineLimit(3).padding(.top, 8)
    HStack {
      Text(s.range).foregroundStyle(W.muted)
      Spacer(minLength: 4)
      Text(s.room).foregroundStyle(W.fg)
    }.font(.m(13)).padding(.top, 3)
    if let n = s.next {
      VStack(alignment: .leading, spacing: 2) {
        HStack { Text("Далее · " + n.time).foregroundStyle(W.muted); Spacer(minLength: 4); Text(n.room).foregroundStyle(W.fg) }
          .font(.m(12))
        Text(n.subj).font(.b(13)).foregroundStyle(W.fg).lineLimit(2)
      }
      .padding(.top, 9)
      .overlay(alignment: .top) { Rectangle().fill(W.line).frame(height: 1) }
      .padding(.top, 10)
    } else if s.last {
      Text("Последняя на сегодня").font(.m(12)).foregroundStyle(W.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 9)
        .overlay(alignment: .top) { Rectangle().fill(W.line).frame(height: 1) }
        .padding(.top, 10)
    }
  }

  @ViewBuilder func done(_ s: WState, _ t: Date) -> some View {
    Text(s.big).font(.m(20, 700)).foregroundStyle(W.fg).fixedSize(horizontal: false, vertical: true)
    if let nd = nextDay(t) {
      let d = nd.0, l = nd.1
      VStack(alignment: .leading, spacing: 2) {
        Text(DAYS_FULL[weekday(d)] + ", \(dnum(d)) " + MON[mnum(d)]).font(.m(12)).foregroundStyle(W.muted)
        HStack {
          Text(l.kind != nil ? l.time : "\(l.p) пара · " + sc.pairTime(l.p).0).foregroundStyle(W.fg)
          Spacer(minLength: 4)
          Text(l.r).foregroundStyle(W.fg)
        }.font(.m(13))
        Text(l.s).font(.b(13)).foregroundStyle(W.fg).lineLimit(2)
      }
      .padding(.top, 9)
      .overlay(alignment: .top) { Rectangle().fill(W.line).frame(height: 1) }
      .padding(.top, 10)
    }
  }

  // Первая пара ближайшего дня, где что-то есть
  func nextDay(_ t: Date) -> (Date, Lesson)? {
    for i in 1...14 {
      let d = addDays(t, i)
      if sc.afterEnd(d) { return nil }
      let items = sc.active(sc.lessonsFor(d)) + sc.itemsFor(d)
      if let f = items.min(by: { ($0.kind != nil ? $0.m : $0.a) < ($1.kind != nil ? $1.m : $1.a) }) { return (d, f) }
    }
    return nil
  }
}

struct Bar: View {
  let f: Double
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(W.line)
        Capsule().fill(W.fg).frame(width: g.size.width * CGFloat(max(0, min(1, f))))
      }
    }.frame(height: 5)
  }
}

// ---------- День: все пары, листание кнопками ----------
struct DayPage: View {
  @EnvironmentObject var st: WStore
  let sc: Sched
  @State private var day: Date? = nil

  var body: some View {
    TimelineView(.everyMinute) { ctx in
      let t = st.now(ctx.date)
      let d = day ?? sc.clamp(t)
      let list = sc.lessonsFor(d), items = sc.itemsFor(d)
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          Text(sc.inSession(d) ? "Сессия" : "Неделя " + sc.weekName(d)).font(.m(11)).foregroundStyle(W.muted)
          if list.isEmpty && items.isEmpty {
            Text(sc.inSession(d) ? "Экзаменов нет" : "Пар нет").font(.b(15, 500)).foregroundStyle(W.fg).padding(.top, 6)
          }
          ForEach(list) { PairRow(sc: sc, l: $0, d: d, t: t) }
          ForEach(items) { PairRow(sc: sc, l: $0, d: d, t: t) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle(DSHORT[min(5, wd(d))] + ", \(dnum(d)) " + MON[mnum(d)])
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button { day = step(d, -1) } label: { Image(systemName: "chevron.left") }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button { day = step(d, 1) } label: { Image(systemName: "chevron.right") }
        }
      }
      .onTapGesture(count: 2) { day = nil }
    }
  }

  func step(_ d: Date, _ by: Int) -> Date {
    var x = d
    for _ in 0..<14 {
      x = addDays(x, by)
      if sc.inStrip(x) { return sc.clamp(x) }
    }
    return d
  }
}

struct PairRow: View {
  let sc: Sched
  let l: Lesson
  let d: Date
  let t: Date

  var body: some View {
    let isToday = key(d) == key(t), m = nowMin(t)
    let live = isToday && !l.cancel && l.kind == nil && m >= l.a && m < l.b
    let past = isToday && (l.kind != nil ? m > l.m : m >= l.b)
    VStack(alignment: .leading, spacing: 3) {
      HStack {
        Text(l.kind != nil ? (KSHORT[l.kind!] ?? "") + " " + l.time : "\(l.p)  " + sc.pairTime(l.p).0 + "–" + sc.pairTime(l.p).1)
          .foregroundStyle(W.muted)
        Spacer(minLength: 4)
        Text(l.r).foregroundStyle(W.fg)
      }.font(.m(12))
      Text(l.s).font(.b(14, 500)).foregroundStyle(l.cancel ? W.muted : W.fg).strikethrough(l.cancel).lineLimit(3)
      if let tag = tag { Text(tag).font(.m(11)).foregroundStyle(l.cancel ? W.warn : l.sub.isEmpty && !l.ed ? W.muted : W.note) }
      if !l.tch.isEmpty { Text(l.tch).font(.b(12)).foregroundStyle(W.muted).lineLimit(1) }
      if live { Bar(f: Double(m - l.a) / Double(max(1, l.b - l.a))).padding(.top, 3) }
    }
    .padding(9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 12).fill(W.surface))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(live ? W.fg.opacity(0.8) : .clear, lineWidth: 1))
    .opacity(past && !live ? 0.55 : 1)
  }

  var tag: String? {
    if let k = l.kind { return KINDS[k] }
    var r: [String] = []
    if l.t == "lec" { r.append("Лекция") } else if l.t == "prac" { r.append("Практика") } else if l.t == "mix" { r.append("Лек/Прак") }
    if l.cancel { r.append("Отменена") } else if l.ed { r.append("Изменено") }
    else if l.sub == "rep" { r.append("Замена") } else if l.sub == "add" { r.append("Доп. пара") }
    return r.isEmpty ? nil : r.joined(separator: " · ")
  }
}
