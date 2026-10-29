import SwiftUI

// Выбор карточки при замене, разовой правке и новой паре
struct PickSheet: View {
  @ObservedObject var ed: Editor
  let mode: PickMode
  @Environment(\.dismiss) private var dismiss
  @State private var q = ""
  @State private var cur: ECard? = nil
  @State private var t = "lec"
  @State private var rooms: Set<String> = []
  @State private var room = ""

  var k: String { key(ed.date) }
  var p: Int { switch mode { case .once(let p), .sub(let p): return p; case .addPermanent(let p, _): return p } }
  var free: Bool { if case .once = mode { return true }; return false } // аудитория вписывается вручную
  var hint: (s: String, tch: String, t: String, r: String)? {
    let b = ed.baseFor(ed.date)[p], c = ed.changeOf(k, p)
    if case .addPermanent = mode { return nil }
    if let c, !c.cancel { return (c.s, c.tch, c.t, c.r) }
    if let b { return (b.s, b.tch, b.t, b.r) }
    return nil
  }
  var title: String {
    switch mode {
    case .once: return "Изменить на этот день"
    case .sub: return ed.baseFor(ed.date)[p] != nil ? "Замена" : "Дополнительная пара"
    case .addPermanent: return "Новая пара"
    }
  }
  var sub: String {
    let d = ed.date
    let base = DAYS_FULL[weekday(d)] + ", \(dnum(d)) " + MONF[mnum(d)] + ", \(p) пара"
    switch mode {
    case .once: return base + ". Остальные недели не меняются"
    case .sub: return base + (ed.baseFor(d)[p].map { ". По расписанию: " + short($0.s, $0.tch) } ?? "")
    case .addPermanent(_, let w): return DAYS_FULL[weekday(d)] + ", \(p) пара" + (w != "all" ? ", " + (WEEKS[w] ?? "").lowercased() : "") + ", каждую неделю"
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if let c = cur { details(c) } else { list }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(cur == nil ? "Отмена" : "Назад") { if cur == nil { dismiss() } else { withAnimation { cur = nil } } }
        }
      }
    }
    .tint(C.fg)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  var list: some View {
    let all = ed.allCards()
    let words = q.lowercased().replacingOccurrences(of: "ё", with: "е").split(separator: " ").map(String.init)
    let shown = all.filter { c in
      let hay = ([c.s, c.tch] + (free ? [] : c.r.map { "ауд " + $0 })).joined(separator: " ").lowercased().replacingOccurrences(of: "ё", with: "е")
      return words.allSatisfy { hay.contains($0) }
    }
    return List {
      Section { Text(sub).font(.b(13)).foregroundColor(C.muted) }
      ForEach(shown) { c in
        Button { Haptic.tap(); choose(c) } label: {
          VStack(alignment: .leading, spacing: 3) {
            Text(c.s).font(.b(16, 600)).foregroundColor(C.fg)
            if !c.tch.isEmpty { Text(c.tch).font(.b(14)).foregroundColor(C.muted) }
            if !free && !c.r.isEmpty { Text("ауд. " + c.r.joined(separator: " · ")).font(.m(13)).foregroundColor(C.muted) }
          }.padding(.vertical, 3)
        }
      }
      if shown.isEmpty { Text("Ничего не нашлось. Новую карточку можно добавить в «Общее → Карточки пар».").font(.b(14)).foregroundColor(C.muted) }
    }
    .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: free ? "Предмет, преподаватель" : "Предмет, преподаватель, аудитория")
  }

  func choose(_ c: ECard) {
    let h = hint.flatMap { $0.s == c.s && $0.tch == c.tch ? $0 : nil }
    t = ["lec", "prac"].contains(h?.t ?? "") ? h!.t : ["lec", "prac"].contains(c.main) ? c.main : "lec"
    var rs = Set(splitR(h?.r ?? "").filter { c.r.contains($0) })
    if rs.isEmpty, let f = c.r.first { rs = [f] }
    rooms = rs
    room = h?.r ?? hint?.r ?? ""
    // Одна аудитория и не разовая правка: спрашивать нечего, кроме типа
    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { cur = c }
  }

  func details(_ c: ECard) -> some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 3) {
          Text(c.s).font(.b(16, 600))
          if !c.tch.isEmpty { Text(c.tch).font(.b(14)).foregroundColor(C.muted) }
        }
      }
      Section("Лекция или практика") {
        Picker("Тип", selection: $t) { Text("Лекция").tag("lec"); Text("Практика").tag("prac") }.pickerStyle(.segmented)
      }
      if free {
        Section("Аудитория") { TextField("Например, 3-2", text: $room).font(.m(15)).textInputAutocapitalization(.never) }
      } else if c.r.count > 1 {
        Section {
          ForEach(c.r, id: \.self) { r in
            Button {
              Haptic.pick()
              if rooms.contains(r) { rooms.remove(r) } else { rooms.insert(r) }
            } label: {
              HStack { Text(r).font(.m(15)).foregroundColor(C.fg); Spacer(); if rooms.contains(r) { Image(systemName: "checkmark").foregroundColor(C.fg) } }
            }
          }
        } header: { Text("Аудитория") } footer: { Text("Можно отметить несколько, например для подгрупп") }
      }
      Section {
        Button { put(c) } label: { Text("Поставить").font(.b(16, 600)).frame(maxWidth: .infinity) }
          .buttonStyle(.borderedProminent).tint(C.fg).foregroundColor(C.bg)
          .listRowBackground(Color.clear)
      }
    }
  }

  func put(_ c: ECard) {
    var v = ELesson(); v.s = c.s; v.tch = c.tch; v.t = t
    if free { v.r = room.trimmingCharacters(in: .whitespaces) }
    else if c.r.count > 1 {
      guard !rooms.isEmpty else { ed.show("Выберите аудиторию"); Haptic.warn(); return }
      v.r = c.r.filter { rooms.contains($0) }.joined(separator: ", ")
    } else { v.r = c.r.first ?? "" }
    switch mode {
    case .once(let p): ed.once(k, p, v)
    case .sub(let p): ed.substitute(k, p, v)
    case .addPermanent(let p, let w):
      v.d = wd(ed.date); v.p = p; v.w = w
      if let e = ed.saveLesson(nil, v) { ed.show(e); Haptic.warn(); return }
      ed.show("Пара добавлена")
    }
    Haptic.ok()
    dismiss()
  }
}

// Пара в постоянном расписании: системная форма
struct LessonForm: View {
  @ObservedObject var ed: Editor
  let i: Int?
  @State var l: ELesson
  @Environment(\.dismiss) private var dismiss
  @State private var err: String? = nil
  @State private var hasFrom = false
  @State private var from = Date()
  @State private var askDel = false

  init(ed: Editor, i: Int?, l: ELesson) {
    self.ed = ed; self.i = i
    var x = l; if x.t != "prac" { x.t = "lec" }
    _l = State(initialValue: x)
    _hasFrom = State(initialValue: !l.from.isEmpty)
    _from = State(initialValue: pd(l.from) ?? Date())
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("День", selection: $l.d) { ForEach(0..<6, id: \.self) { Text(DAYS_FULL[($0 + 1) % 7]).tag($0) } }
          Picker("Пара", selection: $l.p) {
            ForEach(Array(ed.bells.enumerated()), id: \.offset) { j, b in Text("\(j + 1) пара, " + (b.first ?? "") + "-" + (b.count > 1 ? b[1] : "")).tag(j + 1) }
          }
          Picker("Неделя", selection: $l.w) {
            Text("Каждую").tag("all"); Text("Над чертой").tag("over"); Text("Под чертой").tag("under")
          }.pickerStyle(.segmented)
        }
        Section("Пара") {
          field("Предмет", $l.s, ed.suggestions { $0.s })
          Picker("Тип", selection: $l.t) { Text("Лекция").tag("lec"); Text("Практика").tag("prac") }.pickerStyle(.segmented)
          field("Преподаватель", $l.tch, ed.suggestions { $0.tch })
          field("Аудитория", $l.r, ed.suggestions { $0.r }, mono: true)
        }
        Section {
          Toggle("Начинается не с начала семестра", isOn: $hasFrom.animation())
          if hasFrom { DatePicker("С какого дня", selection: $from, displayedComponents: .date).environment(\.locale, Locale(identifier: "ru_RU")) }
        }
        if let err { Section { Text(err).foregroundColor(C.warn) } }
        if i != nil {
          Section { Button("Удалить пару навсегда", role: .destructive) { askDel = true } }
        }
      }
      .navigationTitle(i != nil ? "Изменить пару" : "Новая пара")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Готово") { done() }.fontWeight(.semibold) }
      }
      .confirmationDialog("Удалить пару навсегда?", isPresented: $askDel, titleVisibility: .visible) {
        Button("Удалить", role: .destructive) { if let i { ed.deleteForever(i) }; Haptic.ok(); dismiss() }
      } message: { Text("Она пропадёт из постоянного расписания на все недели.") }
    }
    .tint(C.fg)
  }

  func field(_ title: String, _ v: Binding<String>, _ sug: [String], mono: Bool = false) -> some View {
    HStack {
      TextField(title, text: v).font(mono ? .m(15) : .b(16)).textInputAutocapitalization(mono ? .never : .sentences)
      if !sug.isEmpty {
        Menu {
          ForEach(sug.filter { v.wrappedValue.isEmpty || $0.lowercased().contains(v.wrappedValue.lowercased()) }.prefix(30), id: \.self) { s in
            Button(s) { v.wrappedValue = s }
          }
        } label: { Image(systemName: "chevron.down.circle").foregroundColor(C.muted) }
      }
    }
  }

  func done() {
    var n = l
    n.s = n.s.trimmingCharacters(in: .whitespaces); n.tch = n.tch.trimmingCharacters(in: .whitespaces); n.r = n.r.trimmingCharacters(in: .whitespaces)
    n.from = hasFrom ? key(from) : ""
    if let e = ed.saveLesson(i, n) { withAnimation { err = e }; Haptic.warn(); return }
    Haptic.ok()
    ed.show(i != nil ? "Пара изменена" : "Пара добавлена")
    dismiss()
  }
}
