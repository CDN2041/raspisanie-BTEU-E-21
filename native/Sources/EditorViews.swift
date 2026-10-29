import SwiftUI

// ---------- Нативный редактор: вкладка «Неделя» ----------
struct EditorRoot: View {
  @EnvironmentObject var store: Store
  @Environment(\.dismiss) private var dismiss
  @StateObject private var ed = Editor()
  @State private var web = false

  var body: some View {
    ZStack(alignment: .top) {
      C.bg.ignoresSafeArea()
      switch ed.phase {
      case .checking:
        VStack(spacing: 12) { ProgressView(); Text("Проверяю ключ").font(.b(15)).foregroundColor(C.muted) }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .login(let err): EditorLogin(ed: ed, err: err, close: { dismiss() })
      case .failed(let t):
        VStack(spacing: 16) {
          Text(t).font(.b(15)).foregroundColor(C.muted).multilineTextAlignment(.center)
          Btn(title: "Повторить", kind: .primary) { Task { await ed.open(store: store) } }
          Btn(title: "Закрыть") { dismiss() }
        }.padding(24).frame(maxWidth: 420).frame(maxWidth: .infinity, maxHeight: .infinity)
      case .ready: EditorMain(ed: ed, web: $web, close: { dismiss() })
      }
      if let t = ed.toast {
        Text(t).font(.b(14, 600)).foregroundColor(C.fg).multilineTextAlignment(.center)
          .padding(.horizontal, 16).padding(.vertical, 11).glass(Capsule())
          .padding(.top, 6).padding(.horizontal, 24)
          .transition(.move(edge: .top).combined(with: .opacity))
          .onTapGesture { ed.toast = nil }
      }
    }
    .task { await ed.open(store: store) }
    .fullScreenCover(isPresented: $web, onDismiss: { Task { await ed.open(store: store); await store.fetch(force: true) } }) {
      EditorView().environmentObject(store)
    }
  }
}

struct EditorLogin: View {
  @ObservedObject var ed: Editor
  let err: String?
  let close: () -> Void
  @State private var t = ""
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack { Spacer(); CloseBtn(close) }
        Text("Редактор").font(.d(28, 700)).foregroundColor(C.fg)
        Text("Вставьте ключ GitHub. Он хранится только на этом телефоне, в связке ключей.").font(.b(15)).foregroundColor(C.muted)
        SecureField("ghp_…", text: $t).font(.m(15)).textInputAutocapitalization(.never).autocorrectionDisabled()
          .padding(14).card(14)
        if let err { Text(err).font(.b(14)).foregroundColor(C.warn) }
        Btn(title: "Войти", kind: .primary) { Task { await ed.enter(t.trimmingCharacters(in: .whitespacesAndNewlines)) } }
        Link("Создать ключ на GitHub", destination: URL(string: "https://github.com/settings/tokens/new?scopes=public_repo&description=%D0%A0%D0%B5%D0%B4%D0%B0%D0%BA%D1%82%D0%BE%D1%80")!)
          .font(.b(15, 600)).foregroundColor(C.fg)
      }.padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
    }
  }
}

struct CloseBtn: View {
  let a: () -> Void
  init(_ a: @escaping () -> Void) { self.a = a }
  var body: some View {
    Button { Haptic.tap(); a() } label: {
      Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundColor(C.fg).frame(width: 44, height: 44).glass(Circle())
    }.buttonStyle(Press(scale: 0.92))
  }
}

// Маленькая кнопка под карточкой пары
struct SmallBtn: View {
  let title: String
  var icon: String? = nil
  var danger = false
  let a: () -> Void
  var body: some View {
    Button { Haptic.tap(); a() } label: { label }.buttonStyle(Press(scale: 0.95))
  }
  var label: some View {
    HStack(spacing: 5) {
      if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
      Text(title).font(.b(14, 600)).lineLimit(1)
    }
    .foregroundColor(danger ? C.warn : C.fg).padding(.horizontal, 14).padding(.vertical, 9).glass(Capsule())
  }
}

enum PickMode: Identifiable {
  case once(Int), sub(Int), addPermanent(Int, String)
  var id: String {
    switch self { case .once(let p): return "o\(p)"; case .sub(let p): return "s\(p)"; case .addPermanent(let p, let w): return "a\(p)\(w)" }
  }
}
struct FormRef: Identifiable { let i: Int?; let l: ELesson; var id: String { "\(i ?? -1)" } }

struct EditorMain: View {
  @EnvironmentObject var store: Store
  @ObservedObject var ed: Editor
  @Binding var web: Bool
  let close: () -> Void
  @State private var tab = "week"
  @State private var pick: PickMode? = nil
  @State private var form: FormRef? = nil
  @State private var forever: Int? = nil
  @State private var askClose = false
  @State private var askWeb = false
  @State private var stripW: CGFloat = 1
  @State private var dir = 1
  @Namespace private var ns

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 10) {
          CloseBtn { if ed.dirty { askClose = true } else { close() } }
          Spacer()
          if !ed.login.isEmpty { Text("@" + ed.login).font(.b(13)).foregroundColor(C.muted) }
        }
        Text("Редактор").font(.d(28, 700)).foregroundColor(C.fg)
        Seg(items: [("week", "Неделя"), ("sess", "Сессия"), ("gen", "Общее")], value: Binding(get: { tab }, set: { v in
          if v == "week" { tab = v } else if ed.dirty { askWeb = true } else { web = true }
        }))
        week
      }
      .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 110)
      .frame(maxWidth: 560).frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) { if ed.dirty { saveBar } }
    .animation(.spring(response: 0.45, dampingFraction: 0.86), value: ed.dirty)
    .sheet(item: $pick) { m in PickSheet(ed: ed, mode: m).preferredColorScheme(store.colorScheme) }
    .sheet(item: $form) { f in LessonForm(ed: ed, i: f.i, l: f.l).preferredColorScheme(store.colorScheme) }
    .confirmationDialog("Удалить пару из расписания навсегда?", isPresented: Binding(get: { forever != nil }, set: { if !$0 { forever = nil } }), titleVisibility: .visible) {
      Button("Удалить навсегда", role: .destructive) { if let i = forever { withAnimation { ed.deleteForever(i) } } }
      Button("Отмена", role: .cancel) {}
    } message: { Text("Она пропадёт из постоянного расписания на все недели.") }
    .alert("Закрыть без сохранения?", isPresented: $askClose) {
      Button("Остаться", role: .cancel) {}
      Button("Закрыть", role: .destructive) { close() }
    } message: { Text("Несохранённые изменения пропадут.") }
    .alert("Сначала сохраните", isPresented: $askWeb) {
      Button("Понятно", role: .cancel) {}
    } message: { Text("Вкладки «Сессия» и «Общее» пока в веб-редакторе. Сохраните или отмените изменения в «Неделе».") }
  }

  var saveBar: some View {
    HStack(spacing: 10) {
      Text("Есть несохранённые изменения").font(.b(13)).foregroundColor(C.muted).lineLimit(2)
      Spacer(minLength: 6)
      Btn(title: "Отменить") { withAnimation { ed.undo() } }.frame(width: 120)
      Btn(title: ed.saving ? "Сохраняю" : "Сохранить", kind: .primary) { Task { await ed.save(store: store) } }
        .frame(width: 130).disabled(ed.saving)
    }
    .padding(.horizontal, 16).padding(.vertical, 10)
    .glass(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .padding(.horizontal, 12).padding(.bottom, 6)
    .frame(maxWidth: 580)
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  // ---------- Неделя ----------
  @ViewBuilder var week: some View {
    let d = ed.date, k = key(d), wt = ed.weekType(d), mon = mondayOf(d), by = ed.baseFor(d)
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        navBtn("chevron.left") { go(addDays(mon, -7)) }
        Spacer()
        DatePicker("", selection: Binding(get: { ed.date }, set: { v in go(v, exact: true) }), displayedComponents: .date)
          .labelsHidden().environment(\.locale, Locale(identifier: "ru_RU"))
        Spacer()
        navBtn("chevron.right") { go(addDays(mon, 7)) }
      }
      HStack {
        Text(DAYS_FULL[weekday(d)] + ", \(dnum(d)) " + MONF[mnum(d)]).font(.b(17, 600)).foregroundColor(C.fg)
        Spacer()
        Tag(text: WEEKS[wt] ?? "", style: .prac)
      }
      HStack(spacing: 4) {
        ForEach(0..<6, id: \.self) { i in
          let x = addDays(mon, i), on = i == wd(d)
          Button {
            Haptic.pick()
            dir = x > ed.date ? 1 : -1
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { ed.date = x }
          } label: {
            Text(DSHORT[i] + " \(dnum(x))").font(.b(14, on ? 600 : 500)).lineLimit(1).minimumScaleFactor(0.7)
              .foregroundColor(on ? C.bg : C.muted).frame(maxWidth: .infinity).padding(.vertical, 10)
              .background { if on { Capsule().fill(C.fg).matchedGeometryEffect(id: "d", in: ns) } }
          }.buttonStyle(Press(scale: 0.94))
        }
      }
      .padding(3).glass(Capsule())
      // Зажать и вести пальцем по дням: день меняется под пальцем
      .background(GeometryReader { g in Color.clear.onAppear { stripW = g.size.width }.onChange(of: g.size.width) { stripW = $0 } })
      .gesture(DragGesture(minimumDistance: 6).onChanged { v in
        let i = max(0, min(5, Int(v.location.x / max(1, stripW / 6))))
        let x = addDays(mon, i)
        if x != ed.date {
          Haptic.pick()
          dir = x > ed.date ? 1 : -1
          withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { ed.date = x }
        }
      })
    }
    .padding(14).card(20)

    // Свайп по парам влево и вправо: соседний день
    VStack(spacing: 10) {
      ForEach(Array(ed.bells.enumerated()), id: \.offset) { bi, bl in
        slot(bi + 1, bl, d: d, k: k, wt: wt, b: by[bi + 1])
      }
    }
    .id(k)
    .transition(.asymmetric(insertion: .offset(x: CGFloat(dir) * 40).combined(with: .opacity), removal: .opacity))
    .simultaneousGesture(DragGesture(minimumDistance: 25).onEnded { v in
      let dx = v.translation.width, dy = v.translation.height
      guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
      shiftDay(dx < 0 ? 1 : -1)
    })

    Btn(title: "Новая пара", kind: .primary) {
      form = FormRef(i: nil, l: { var l = ELesson(); l.d = wd(d); l.p = firstFree(wd(d)); l.t = "lec"; return l }())
    }
    Text("Нажмите на карточку, чтобы изменить пару в постоянном расписании. Кнопки под карточкой меняют только выбранный день.")
      .font(.b(13)).foregroundColor(C.muted)
    changesList
  }

  func shiftDay(_ n: Int) {
    var x = addDays(ed.date, n)
    if weekday(x) == 0 { x = addDays(x, n) }
    if let s = ed.start, x < s { return }
    if let e = ed.end, x > e { return }
    Haptic.pick()
    dir = n
    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { ed.date = x }
  }
  func firstFree(_ w: Int) -> Int {
    for p in 1...max(1, ed.bells.count) where !ed.lessons.contains(where: { $0.d == w && $0.p == p }) { return p }
    return 1
  }
  func navBtn(_ icon: String, _ a: @escaping () -> Void) -> some View {
    Button { Haptic.tap(); a() } label: {
      Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(C.fg).frame(width: 44, height: 44).glass(Circle())
    }.buttonStyle(Press(scale: 0.92))
  }
  // Листаем на первый день недели; воскресенье превращается в понедельник
  func go(_ d0: Date, exact: Bool = false) {
    var d = day0(d0)
    if let s = ed.start, d < s { d = s }
    if weekday(d) == 0 { d = addDays(d, 1) }
    withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { ed.date = d }
  }

  @ViewBuilder
  func slot(_ p: Int, _ bl: [String], d: Date, k: String, wt: String, b: ELesson?) -> some View {
    let c = ed.changeOf(k, p)
    let t0 = bl.first ?? "", t1 = bl.count > 1 ? bl[1] : ""
    if let c, c.cancel, let b {
      ECardView(p: p, t0: t0, t1: t1, s: b.s, tch: b.tch, r: b.r, tags: typeTags(b.t) + [("Отменена", .cancel)], note: "Только в этот день", faded: true) {
        SmallBtn(title: "Вернуть пару") { withAnimation { ed.restore(k, p) } }
      }
    } else if let c, c.ed, let b {
      let diff = ed.edDiff(b, c)
      ECardView(p: p, t0: t0, t1: t1, s: c.s, tch: c.tch, r: c.r, tags: typeTags(c.t) + [("Изменено", .sub)],
                note: "Только в этот день" + (diff.isEmpty ? "" : ". Обычно: " + diff)) {
        SmallBtn(title: "Изменить") { pick = .once(p) }
        SmallBtn(title: "Вернуть как было") { withAnimation { ed.restore(k, p) } }
      }
    } else if let c, !c.cancel {
      ECardView(p: p, t0: t0, t1: t1, s: c.s, tch: c.tch, r: c.r, tags: typeTags(c.t) + [(b != nil ? "Замена" : "Доп. пара", .sub)],
                note: (b != nil || !c.was.isEmpty) ? "Вместо: " + (c.was.isEmpty ? short(b!.s, b!.tch) : c.was) : nil) {
        SmallBtn(title: "Изменить") { pick = .once(p) }
        SmallBtn(title: "Другая пара") { pick = .sub(p) }
        SmallBtn(title: b != nil ? "Вернуть как было" : "Убрать") { withAnimation { ed.restore(k, p) } }
      }
    } else {
      let all = ed.indices(day: wd(d), p: p)
      let arr = all.filter { ed.lessons[$0].w == "all" || ed.lessons[$0].w == wt }
      if arr.isEmpty {
        let sw = all.isEmpty ? "all" : wt // если в этом месте стоит пара на другую неделю, новая будет только на эту
        ECardView(p: p, t0: t0, t1: t1, s: nil, tch: "", r: "", tags: [],
                  note: sw == "all" ? "Свободно" : "Свободно, только " + (WEEKS[wt] ?? "").lowercased(), free: true) {
          SmallBtn(title: "Постоянная пара", icon: "plus") { pick = .addPermanent(p, sw) }
          SmallBtn(title: "Только на этот день", icon: "plus") { pick = .sub(p) }
        }
      } else {
        ForEach(arr, id: \.self) { i in
          let l = ed.lessons[i], later = !l.from.isEmpty && l.from > k
          let tg = typeTags(l.t) + (l.w != "all" ? [(WEEKS[l.w] ?? "", Tag.Style.mix)] : []) + fromTags(l)
          ECardView(p: p, t0: t0, t1: t1, s: l.s, tch: l.tch, r: l.r, tags: tg,
                    note: later ? "В этот день ещё не идёт" : nil, faded: later, onTap: { form = FormRef(i: i, l: l) }) {
            if b == l {
              SmallBtn(title: "Изменить на день") { pick = .once(p) }
              SmallBtn(title: "Заменить") { pick = .sub(p) }
              Menu {
                Button { Haptic.tap(); withAnimation { ed.cancel(k, p) } } label: { Label("Только в этот день", systemImage: "calendar.badge.minus") }
                Button(role: .destructive) { Haptic.warn(); forever = i } label: { Label("Навсегда", systemImage: "trash") }
              } label: {
                SmallBtn(title: "Удалить", icon: "trash", danger: true) {}.label
              }
            } else {
              Menu {
                Button(role: .destructive) { Haptic.warn(); forever = i } label: { Label("Удалить навсегда", systemImage: "trash") }
              } label: { SmallBtn(title: "Удалить", icon: "trash", danger: true) {}.label }
            }
          }
        }
      }
    }
  }
  func typeTags(_ t: String) -> [(String, Tag.Style)] {
    t == "prac" ? [("Практика", .prac)] : t == "lec" ? [("Лекция", .lec)] : t == "mix" ? [("Лекция/Практика", .mix)] : []
  }
  func fromTags(_ l: ELesson) -> [(String, Tag.Style)] {
    guard !l.from.isEmpty, let f = pd(l.from) else { return [] }
    return [("с \(dnum(f)) " + MON[mnum(f)], .new)]
  }

  // ---------- Все изменения ----------
  var changesList: some View {
    let ks: [String] = ed.changes.keys.sorted()
    let today = key(Date())
    let rows: [(id: String, k: String, c: EChange)] = ks.flatMap { k in (ed.changes[k] ?? []).map { (id: k + "|\($0.p)", k: k, c: $0) } }
    return VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Все изменения").font(.d(19, 500)).foregroundColor(C.fg)
        Spacer()
        if ks.contains(where: { $0 < today }) { SmallBtn(title: "Убрать прошедшие") { withAnimation { ed.clearPast() } } }
      }
      if rows.isEmpty { Text("Изменений нет").font(.b(15)).foregroundColor(C.muted).padding(.vertical, 8) }
      ForEach(rows, id: \.id) { row in
        ChangeRow(ed: ed, k: row.k, c: row.c, past: row.k < today, go: { go($0, exact: true) })
      }
    }
    .padding(14).card(20)
  }
}

struct ChangeRow: View {
  @ObservedObject var ed: Editor
  let k: String, c: EChange, past: Bool
  let go: (Date) -> Void
  var title: String {
    guard let dd = pd(k) else { return k }
    return DSHORT[min(5, wd(dd))] + ", \(dnum(dd)) " + MONF[mnum(dd)] + " · \(c.p) пара"
  }
  var text: String {
    let b: ELesson? = pd(k).flatMap { ed.baseFor($0)[c.p] }
    if c.cancel { return "Отмена: " + (b.map { short($0.s, $0.tch) } ?? c.was) }
    let kind = c.ed && b != nil ? "Изменено: " : b != nil ? "Замена: " : "Доп. пара: "
    return kind + short(c.s, c.tch)
  }
  var body: some View {
    HStack(spacing: 10) {
      Button { Haptic.tap(); if let d = pd(k) { go(d) } } label: {
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.b(15, 600)).foregroundColor(C.fg)
          Text(text).font(.b(13)).foregroundColor(C.muted).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading)
      }.buttonStyle(Press(scale: 0.98))
      Button { Haptic.tap(); withAnimation { ed.setChange(k, c.p, nil) } } label: {
        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundColor(C.muted).frame(width: 36, height: 36).glass(Circle())
      }.buttonStyle(Press(scale: 0.9))
    }
    .opacity(past ? 0.55 : 1)
    .padding(.vertical, 4)
  }
}

// Карточка пары в редакторе: как в приложении, с кнопками снизу
struct ECardView<Acts: View>: View {
  let p: Int, t0: String, t1: String
  let s: String?, tch: String, r: String
  let tags: [(String, Tag.Style)]
  var note: String? = nil
  var faded = false
  var free = false
  var onTap: (() -> Void)? = nil
  @ViewBuilder var acts: () -> Acts
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 0) {
        Text("\(p) ПАРА").font(.b(11, 600)).tracking(0.44).foregroundColor(C.muted).padding(.bottom, 2)
        Text(t0).font(.m(17, 700)).foregroundColor(C.fg)
        Text(t1).font(.m(13)).foregroundColor(C.muted)
      }.frame(width: 62, alignment: .leading)
      VStack(alignment: .leading, spacing: 4) {
        if !tags.isEmpty { Tags(list: tags) }
        if let s { Text(s).font(.b(16, 600)).foregroundColor(C.fg).strikethrough(faded && note == "Только в этот день").fixedSize(horizontal: false, vertical: true) }
        if !tch.isEmpty { Text(tch).font(.b(14)).foregroundColor(C.muted) }
        if !r.isEmpty { Text("ауд. ").font(.b(12)).foregroundColor(C.muted) + Text(r).font(.m(13)).foregroundColor(C.fg) }
        if let note { Text(note).font(.b(13)).foregroundColor(C.muted) }
        FlowRow(spacing: 8) { acts() }.padding(.top, 8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14).padding(.trailing, onTap != nil ? 22 : 0)
    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(free ? Color.clear : C.surface))
    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(C.line, style: StrokeStyle(lineWidth: 1, dash: free || faded ? [4, 3] : [])))
    .overlay(alignment: .topTrailing) {
      if onTap != nil { Image(systemName: "pencil").font(.system(size: 15, weight: .medium)).foregroundColor(C.muted).padding(16) }
    }
    .opacity(faded ? 0.6 : 1)
    .contentShape(Rectangle())
    .onTapGesture { if let onTap { Haptic.tap(); onTap() } }
  }
}
