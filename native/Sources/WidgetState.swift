import Foundation

// Что показывает виджет в данную минуту: крупно свежая информация, внизу одна следующая пара
struct WNext: Hashable { let time: String, subj: String, room: String }
struct WState: Hashable {
  enum Kind: Hashable { case live, wait, done }
  var kind: Kind = .done
  var head = ""         // «3 пара · до перерыва»
  var big = ""          // «20 мин» или «Пары закончились»
  var mins = 0          // минуты для кружка на экране блокировки
  var frac: Double? = nil
  var subj = "", room = "", range = ""
  var next: WNext? = nil
  var last = false      // идёт последняя пара дня
  var date = ""         // «чт, 29 октября»
  var inline = ""       // строка над часами

  static let placeholder = WState(kind: .live, head: "3 пара · до перерыва", big: "20 мин", mins: 20, frac: 0.3,
                                  subj: "Кадровое делопроизводство", room: "1-13", range: "12:55–14:30",
                                  next: WNext(time: "14:40", subj: "Правовое обеспечение бизнеса", room: "1-22"),
                                  date: "чт, 29 октября", inline: "3 пара · 20 мин · 1-13")
}

private let WDS = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]

func widgetState(_ sc: Sched, _ t: Date) -> WState {
  let td = day0(t), m = nowMin(t)
  let all = sc.active(sc.lessonsFor(td)), its = sc.itemsFor(td)
  var st = WState()
  st.date = WDS[weekday(td)] + ", \(dnum(td)) " + MONF[mnum(td)]
  func nx(_ l: Lesson?) -> WNext? { l.map { WNext(time: sc.pairTime($0.p).0, subj: $0.s, room: $0.r) } }
  func rng(_ l: Lesson) -> String { let p = sc.pairTime(l.p); return p.0 + "–" + p.1 }

  if let cur = all.first(where: { m >= $0.a && m < $0.b }) {
    var label = "до конца", left = cur.b - m
    if let h1 = cur.h1, let h2 = cur.h2, h1 > cur.a, h2 < cur.b, h2 > h1 {
      if m < h1 { label = "до перерыва"; left = h1 - m } else if m < h2 { label = "перерыв"; left = h2 - m }
    }
    let after = all.first { $0.p > cur.p }
    st.kind = .live
    st.head = "\(cur.p) пара · " + label
    st.big = dur(left); st.mins = left
    st.frac = Double(m - cur.a) / Double(max(1, cur.b - cur.a))
    st.subj = cur.s; st.room = cur.r; st.range = rng(cur)
    st.next = nx(after); st.last = after == nil
    st.inline = "\(cur.p) пара · " + dur(left) + (cur.r.isEmpty ? "" : " · " + cur.r)
    return st
  }
  if let nl = all.first(where: { $0.a > m }) {
    let prev = all.last { $0.b <= m }
    let after = all.first { $0.p > nl.p }
    st.kind = .wait
    st.head = prev == nil ? "\(nl.p) пара · до начала" : "Перерыв · до \(nl.p) пары"
    st.big = dur(nl.a - m); st.mins = nl.a - m
    if let prev { st.frac = Double(m - prev.b) / Double(max(1, nl.a - prev.b)) }
    st.subj = nl.s; st.room = nl.r; st.range = rng(nl)
    st.next = nx(after); st.last = after == nil
    st.inline = "\(nl.p) пара через " + dur(nl.a - m) + (nl.r.isEmpty ? "" : " · " + nl.r)
    return st
  }
  if let it = its.first(where: { $0.m > m }) {
    let k = KINDS[it.kind ?? "other"] ?? ""
    st.kind = .wait
    st.head = k + " · до начала"
    st.big = dur(it.m - m); st.mins = it.m - m
    st.subj = it.s; st.room = it.r; st.range = it.time
    st.inline = k + " через " + dur(it.m - m)
    return st
  }
  st.kind = .done
  st.big = !all.isEmpty || !its.isEmpty ? (sc.inSession(td) ? "Экзамены закончились" : "Пары закончились")
    : sc.inSession(td) ? "Сегодня экзаменов нет" : "Сегодня пар нет"
  return st
}

// Минуты, в которые виджет должен показать новое: каждая минута, пока сегодня есть пары
func widgetTimes(_ sc: Sched, from t: Date, hours: Int = 3) -> [Date] {
  let td = day0(t)
  let all = sc.active(sc.lessonsFor(td))
  let ends = all.map { $0.b } + sc.itemsFor(td).map { $0.m }
  let base = cal.date(from: cal.dateComponents([.year, .month, .day, .hour, .minute], from: t)) ?? t
  guard let lastEnd = ends.max(), nowMin(t) < lastEnd else { return [t] }
  let stop = min(lastEnd - nowMin(t), hours * 60)
  return [t] + (1...max(1, stop)).map { cal.date(byAdding: .minute, value: $0, to: base)! }
}
