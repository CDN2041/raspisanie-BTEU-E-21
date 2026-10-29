import SwiftUI

// ---------- Сессия ----------
struct ItemRef: Identifiable { let i: Int?; let it: EItem; var id: String { "\(i ?? -1)" } }

struct SessionTab: View {
  @EnvironmentObject var store: Store
  @ObservedObject var ed: Editor
  @State private var dates = false
  @State private var item: ItemRef? = nil
  @State private var askDel = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let s = ed.session {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("Сессия").font(.d(19, 500)).foregroundColor(C.fg)
            Spacer()
            SmallBtn(title: "Изменить даты") { dates = true }
          }
          Text(period(s.from, s.to)).font(.b(15)).foregroundColor(s.from.isEmpty ? C.warn : C.fg)
        }.padding(14).card(20)
        let items = s.items.enumerated().sorted { a, b in
          a.element.date != b.element.date ? a.element.date < b.element.date : toMin(a.element.time) < toMin(b.element.time)
        }
        ForEach(items, id: \.offset) { x in
          let it = x.element, d = pd(it.date)
          ECardView(p: 0, t0: it.time, t1: "", s: it.s, tch: it.tch, r: it.r,
                    tags: [(EKINDS.first { $0.0 == it.kind }?.1 ?? "", it.kind == "exam" ? .prac : .mix)],
                    note: d.map { DAYS_FULL[weekday($0)] + ", \(dnum($0)) " + MONF[mnum($0)] },
                    onTap: { item = ItemRef(i: x.offset, it: it) },
                    top: d.map { DSHORT[min(5, wd($0))].uppercased() + " \(dnum($0)).\(String(format: "%02d", mnum($0) + 1))" }) { EmptyView() }
        }
        Button { Haptic.tap(); var n = EItem(); n.date = s.from; item = ItemRef(i: nil, it: n) } label: {
          Label("Добавить экзамен, зачёт или консультацию", systemImage: "plus").font(.b(15, 600)).foregroundColor(C.fg)
            .frame(maxWidth: .infinity).padding(16).dashed(16)
        }.buttonStyle(Press(scale: 0.98))
        Btn(title: "Удалить сессию", kind: .del) { askDel = true }.frame(maxWidth: .infinity)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          Text("Сессии нет").font(.d(19, 500)).foregroundColor(C.fg)
          Text("Добавьте период сессии, потом экзамены, зачёты и консультации. В приложении они появятся в своих днях, а на экране «Сейчас» будет отсчёт до ближайшего.")
            .font(.b(14)).foregroundColor(C.muted)
          Btn(title: "Добавить сессию", kind: .primary) { dates = true }
        }.padding(14).card(20)
      }
    }
    .sheet(isPresented: $dates) { SessionDates(ed: ed).preferredColorScheme(store.colorScheme) }
    .sheet(item: $item) { r in ItemForm(ed: ed, i: r.i, it: r.it).preferredColorScheme(store.colorScheme) }
    .confirmationDialog("Удалить сессию?", isPresented: $askDel, titleVisibility: .visible) {
      Button("Удалить", role: .destructive) { withAnimation { ed.deleteSession() } }
    } message: { Text("Удалятся период и все экзамены, зачёты и консультации.") }
  }
  func period(_ f: String, _ t: String) -> String {
    guard let a = pd(f), let b = pd(t) else { return "Укажите даты" }
    return "С \(dnum(a)) " + MONF[mnum(a)] + " по \(dnum(b)) " + MONF[mnum(b)]
  }
}

struct SessionDates: View {
  @ObservedObject var ed: Editor
  @Environment(\.dismiss) private var dismiss
  @State private var from = Date()
  @State private var to = addDays(Date(), 21)
  @State private var err: String? = nil
  var body: some View {
    NavigationStack {
      Form {
        DatePicker("Начало", selection: $from, displayedComponents: .date)
        DatePicker("Конец", selection: $to, displayedComponents: .date)
        if let err { Text(err).foregroundColor(C.warn) }
      }
      .environment(\.locale, Locale(identifier: "ru_RU"))
      .navigationTitle("Период сессии").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Готово") {
            if day0(from) > day0(to) { err = "Конец раньше начала"; Haptic.warn(); return }
            ed.setSession(from: key(from), to: key(to), items: ed.session?.items ?? [])
            Haptic.ok(); dismiss()
          }.fontWeight(.semibold)
        }
      }
      .onAppear {
        if let s = ed.session { from = pd(s.from) ?? from; to = pd(s.to) ?? to }
      }
    }
    .tint(C.fg).presentationDetents([.medium])
  }
}

struct ItemForm: View {
  @ObservedObject var ed: Editor
  let i: Int?
  @State var it: EItem
  @Environment(\.dismiss) private var dismiss
  @State private var date = Date()
  @State private var time = Date()
  @State private var err: String? = nil
  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Дата", selection: $date, displayedComponents: .date)
          DatePicker("Начало", selection: $time, displayedComponents: .hourAndMinute)
          Picker("Что", selection: $it.kind) { ForEach(EKINDS, id: \.0) { Text($0.1).tag($0.0) } }
        }
        Section("Предмет") {
          TextField("Предмет", text: $it.s)
          TextField("Преподаватель", text: $it.tch)
          TextField("Аудитория", text: $it.r).font(.m(15)).textInputAutocapitalization(.never)
        }
        if let err { Section { Text(err).foregroundColor(C.warn) } }
        if let i {
          Section {
            Button("Удалить", role: .destructive) {
              var items = ed.session?.items ?? []
              if items.indices.contains(i) { items.remove(at: i) }
              if let s = ed.session { ed.setSession(from: s.from, to: s.to, items: items) }
              Haptic.ok(); dismiss()
            }
          }
        }
      }
      .environment(\.locale, Locale(identifier: "ru_RU"))
      .navigationTitle(i == nil ? "Добавить" : "Изменить").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Готово") { done() }.fontWeight(.semibold) }
      }
      .onAppear { date = pd(it.date) ?? Date(); time = minutesToDate(it.time) }
    }
    .tint(C.fg)
  }
  func done() {
    var n = it
    n.s = n.s.trimmingCharacters(in: .whitespaces); n.tch = n.tch.trimmingCharacters(in: .whitespaces); n.r = n.r.trimmingCharacters(in: .whitespaces)
    if n.s.isEmpty { err = "Укажите предмет"; Haptic.warn(); return }
    n.date = key(date); n.time = dateToTime(time)
    guard let s = ed.session else { return }
    var items = s.items
    if let i, items.indices.contains(i) { items[i] = n } else { items.append(n) }
    ed.setSession(from: s.from, to: s.to, items: items)
    Haptic.ok(); dismiss()
  }
}

// ---------- Общее ----------
struct GeneralTab: View {
  @EnvironmentObject var store: Store
  @ObservedObject var ed: Editor
  let openAlt: () -> Void
  @State private var cards = false
  @State private var askAlt = false
  @State private var altKey = ""
  @State private var altErr: String? = nil
  @State private var visits: [(String, Int)]? = nil
  @State private var visitsFailed = false
  @AppStorage("pary-e21-hidefive", store: Shared.store) private var hideFive = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button { Haptic.tap(); cards = true } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Карточки пар").font(.b(16, 600)).foregroundColor(C.fg)
            Text("Изменить, удалить или добавить карточки").font(.b(13)).foregroundColor(C.muted)
          }
          Spacer()
          Image(systemName: "chevron.right").foregroundColor(C.muted)
        }.padding(16).glass(RoundedRectangle(cornerRadius: 20, style: .continuous))
      }.buttonStyle(Press(scale: 0.98))

      section("Текущая неделя, " + weekRange()) {
        Seg(items: [("over", "Над чертой"), ("under", "Под чертой")],
            value: Binding(get: { ed.curWeekType }, set: { ed.setWeekType($0) }))
        hint("Дальше недели чередуются сами.")
      }
      section("Первый день занятий") {
        Toggle("Задан", isOn: Binding(get: { ed.start != nil }, set: { ed.setStart($0 ? (ed.start ?? Date()) : nil) }))
          .font(.b(15)).tint(C.fg)
        if let s = ed.start {
          DatePicker("Дата", selection: Binding(get: { s }, set: { ed.setStart($0) }), displayedComponents: .date)
            .font(.b(15)).environment(\.locale, Locale(identifier: "ru_RU"))
        }
        hint("Раньше этой даты пар нет, и календарь в приложении назад дальше не листается.")
      }
      section("Последний день занятий") {
        DatePicker("Дата", selection: Binding(get: { ed.end ?? Date() }, set: { ed.setEnd($0) }), displayedComponents: .date)
          .font(.b(15)).environment(\.locale, Locale(identifier: "ru_RU"))
        hint("После этой даты пары не показываются (замены и сессия показываются), и календарь в приложении дальше не листается.")
      }
      bellsCard
      section("Посещения") {
        hint("Уникальные устройства: сколько разных телефонов открывали приложение за сутки")
        if let v = visits {
          ForEach(Array(v.enumerated()), id: \.offset) { i, r in
            HStack { Text(r.0); Spacer(); Text("\(r.1)").font(.m(15, 700)) }
              .font(.b(15)).foregroundColor(i >= 2 && i < v.count - 1 ? C.muted : C.fg)
          }
        } else { Text(visitsFailed ? "Не удалось загрузить: счётчик не отвечает" : "Загружаю").font(.b(15)).foregroundColor(C.muted) }
      }
      section("Аккаунт") {
        hint("Ключ GitHub хранится только на этом телефоне.")
        Btn(title: "Выйти", kind: .del) { ed.logout() }
      }
      Button { Haptic.tap(); altKey = ""; altErr = nil; askAlt = true } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Редактор 2").font(.b(16, 600)).foregroundColor(C.fg)
            Text(ed.altHasKey ? "Вход по второму ключу" : "Придумать второй ключ").font(.b(13)).foregroundColor(C.muted)
          }
          Spacer()
          Image(systemName: "chevron.right").foregroundColor(C.muted)
        }.padding(16).glass(RoundedRectangle(cornerRadius: 20, style: .continuous))
      }.buttonStyle(Press(scale: 0.98))
    }
    .task {
      if visits == nil && !Shot.on { if let v = await Visits.load() { visits = v } else { visitsFailed = true } }
    }
    .sheet(isPresented: $cards) { CardsSheet(ed: ed).preferredColorScheme(store.colorScheme) }
    .alert("Редактор 2", isPresented: $askAlt) {
      SecureField(ed.altHasKey ? "Второй ключ" : "Новый второй ключ", text: $altKey)
      Button("Отмена", role: .cancel) {}
      Button("Войти") {
        if let e = ed.openAlt(altKey) { ed.show(e); Haptic.warn() } else { Haptic.ok(); withAnimation { openAlt() } }
      }
    } message: {
      Text(ed.altHasKey ? "Введите второй ключ" : "Придумайте второй ключ. Его нельзя будет восстановить, только сменить, зная старый")
    }
  }

  var bellsCard: some View {
    let hide = hideFive == "1" || store.noFive
    return section("Звонки") {
      Toggle(isOn: Binding(get: { !store.noFive }, set: { store.setNoFive(!$0) })) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Пятиминутки").font(.b(15, 600))
          Text("Только на этом устройстве. Выключи, и пара будет идти без перерыва").font(.b(12)).foregroundColor(C.muted)
        }
      }.tint(C.fg)
      if !store.noFive {
        Toggle(isOn: Binding(get: { hideFive == "1" }, set: { hideFive = $0 ? "1" : "" })) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Скрывать в редакторе").font(.b(15, 600))
            Text("Только на этом устройстве. В приложении они останутся").font(.b(12)).foregroundColor(C.muted)
          }
        }.tint(C.fg)
      }
      ForEach(Array(ed.bells.enumerated()), id: \.offset) { i, b in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("\(i + 1) пара").font(.b(15, 600)).foregroundColor(C.fg)
            Spacer()
            if i == ed.bells.count - 1 && !ed.bellUsed(i) && ed.bells.count > 1 {
              Button { Haptic.tap(); withAnimation { ed.delBell() } } label: { Image(systemName: "xmark").foregroundColor(C.muted).frame(width: 32, height: 32).glass(Circle()) }
            }
          }
          timeRow(i, 0, 1)
          if !hide {
            if b.count > 2 {
              HStack {
                Text("Пятиминутка").font(.b(13)).foregroundColor(C.muted)
                Spacer()
                Button { Haptic.tap(); withAnimation { ed.delFive(i) } } label: { Image(systemName: "xmark").font(.system(size: 12)).foregroundColor(C.muted).frame(width: 28, height: 28).glass(Circle()) }
              }
              timeRow(i, 2, 3)
            } else {
              SmallBtn(title: "Пятиминутка", icon: "plus") { withAnimation { ed.addFive(i) } }
            }
          }
        }
        .padding(.top, 10)
        .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
      }
      Btn(title: "Добавить пару") { withAnimation { ed.addBell() } }
      if !hide { hint("Пятиминутка показывается в приложении ровно в указанное время. Без неё пара идёт без перерыва.") }
    }
  }
  func timeRow(_ i: Int, _ a: Int, _ b: Int) -> some View {
    let bl = ed.bells[i]
    return HStack(spacing: 8) {
      Text("с").foregroundColor(C.muted)
      DatePicker("", selection: Binding(get: { minutesToDate(bl[a]) }, set: { ed.setBell(i, a, $0) }), displayedComponents: .hourAndMinute).labelsHidden()
      Text("по").foregroundColor(C.muted)
      DatePicker("", selection: Binding(get: { minutesToDate(bl.count > b ? bl[b] : bl[a]) }, set: { ed.setBell(i, b, $0) }), displayedComponents: .hourAndMinute).labelsHidden()
      Spacer(minLength: 0)
    }
    .font(.b(15))
    .environment(\.locale, Locale(identifier: "ru_RU"))
  }
  func weekRange() -> String {
    let mon = mondayOf(Date()), sat = addDays(mon, 5)
    return "\(dnum(mon))-\(dnum(sat)) " + MONF[mnum(sat)]
  }
  func hint(_ t: String) -> some View { Text(t).font(.b(13)).foregroundColor(C.muted).fixedSize(horizontal: false, vertical: true) }
  func section<V: View>(_ title: String, @ViewBuilder _ c: () -> V) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Eyebrow(text: title)
      c()
    }
    .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(20)
  }
}

// ---------- Карточки пар ----------
struct CardRef: Identifiable { let c: ECard?; var id: String { c?.id ?? "new" } }

struct CardsSheet: View {
  @EnvironmentObject var store: Store
  @ObservedObject var ed: Editor
  @Environment(\.dismiss) private var dismiss
  @State private var q = ""
  @State private var edit: CardRef? = nil
  var body: some View {
    NavigationStack {
      let words = q.lowercased().replacingOccurrences(of: "ё", with: "е").split(separator: " ").map(String.init)
      let list = ed.allCards().filter { c in
        let hay = ([c.s, c.tch] + c.r.map { "ауд " + $0 }).joined(separator: " ").lowercased().replacingOccurrences(of: "ё", with: "е")
        return words.allSatisfy { hay.contains($0) }
      }
      List {
        ForEach(list) { c in
          Button { Haptic.tap(); edit = CardRef(c: c) } label: {
            VStack(alignment: .leading, spacing: 3) {
              Text(c.s).font(.b(16, 600)).foregroundColor(C.fg)
              if !c.tch.isEmpty { Text(c.tch).font(.b(14)).foregroundColor(C.muted) }
              if !c.r.isEmpty { Text("ауд. " + c.r.joined(separator: " · ")).font(.m(13)).foregroundColor(C.muted) }
            }.padding(.vertical, 3)
          }
        }
        if list.isEmpty { Text("Ничего не нашлось").foregroundColor(C.muted) }
      }
      .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "Предмет, преподаватель, аудитория")
      .navigationTitle("Карточки пар").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
        ToolbarItem(placement: .primaryAction) { Button { edit = CardRef(c: nil) } label: { Image(systemName: "plus") } }
      }
      .sheet(item: $edit) { r in CardForm(ed: ed, c: r.c).preferredColorScheme(store.colorScheme) }
    }
    .tint(C.fg)
  }
}

struct CardForm: View {
  @ObservedObject var ed: Editor
  let c: ECard?
  @Environment(\.dismiss) private var dismiss
  @State private var s = ""
  @State private var tch = ""
  @State private var rooms: [String] = []
  @State private var newRoom = ""
  @State private var err: String? = nil
  var used: Bool { c.map { ed.usedCard($0.id) } ?? false }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Предмет", text: $s)
          TextField("Преподаватель", text: $tch)
        } footer: {
          Text(c == nil ? "Потом её можно выбрать при замене или при добавлении пары" : used ? "Изменения применятся ко всем парам с этой карточкой" : "Карточка пока нигде не стоит")
        }
        Section("Аудитории") {
          ForEach(rooms, id: \.self) { r in Text(r).font(.m(15)) }
            .onDelete { rooms.remove(atOffsets: $0) }
          HStack {
            TextField("Например, 3-2", text: $newRoom).font(.m(15)).textInputAutocapitalization(.never).onSubmit(addRoom)
            Button("Добавить", action: addRoom).disabled(newRoom.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }
        if let err { Section { Text(err).foregroundColor(C.warn) } }
        if let c, !used {
          Section { Button("Удалить карточку", role: .destructive) { ed.deleteCard(c.id); ed.show("Карточка удалена"); Haptic.ok(); dismiss() } }
        }
      }
      .navigationTitle(c == nil ? "Новая карточка" : "Карточка пары").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Готово") {
            addRoom()
            if let e = ed.saveCard(k0: c?.id, s: s, tch: tch, rooms: rooms) { err = e; Haptic.warn(); return }
            ed.show(c == nil ? "Карточка добавлена" : "Карточка обновлена"); Haptic.ok(); dismiss()
          }.fontWeight(.semibold)
        }
      }
      .onAppear { if let c { s = c.s; tch = c.tch; rooms = c.r } }
    }
    .tint(C.fg)
  }
  func addRoom() {
    for x in splitR(newRoom) where !rooms.contains(x) { rooms.append(x) }
    newRoom = ""
  }
}
