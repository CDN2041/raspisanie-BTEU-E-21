import Foundation

// Пара или событие сессии в том виде, как их показывает приложение
struct Lesson: Identifiable, Hashable {
  var d = 0, p = 0
  var w = "all"
  var s = "", t = "", tch = "", r = "", was = "", from = ""
  var cancel = false, ed = false
  var sub = ""            // "rep" замена, "add" доп. пара
  var kind: String? = nil // событие сессии: exam, credit, consult, other
  var time = ""           // начало события сессии
  var m = 0               // начало события сессии в минутах
  var a = 0, b = 0        // начало и конец пары в минутах
  var h1: Int? = nil, h2: Int? = nil // пятиминутка

  var id: String { kind != nil ? "k|\(time)|\(s)" : "p|\(p)|\(s)" }
}

let KINDS = ["exam": "Экзамен", "credit": "Зачёт", "consult": "Консультация", "other": "Событие"]
let KGEN = ["exam": "экзамена", "credit": "зачёта", "consult": "консультации", "other": "события"]
let KSHORT = ["exam": "экз.", "credit": "зач.", "consult": "конс.", "other": "соб."]
let FK = "Физическая культура"
let DSHORT = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
let DAYS_FULL = ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
let WHEN = ["В воскресенье", "В понедельник", "Во вторник", "В среду", "В четверг", "В пятницу", "В субботу"]
let MON = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
let MONF = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
let MONN = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]

// ---------- Даты ----------
let cal: Calendar = {
  var c = Calendar(identifier: .gregorian)
  c.timeZone = .current
  return c
}()
func day0(_ d: Date) -> Date { cal.startOfDay(for: d) }
func addDays(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: day0(d))! }
func weekday(_ d: Date) -> Int { cal.component(.weekday, from: d) - 1 } // 0 = воскресенье, как в JS
func wd(_ d: Date) -> Int { (weekday(d) + 6) % 7 }                     // 0 = понедельник
func mondayOf(_ d: Date) -> Date { addDays(d, -wd(d)) }
func daysBetween(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: day0(a), to: day0(b)).day ?? 0 }
func weeksBetween(_ a: Date, _ b: Date) -> Int { Int((Double(daysBetween(mondayOf(a), mondayOf(b))) / 7).rounded()) }
func key(_ d: Date) -> String {
  let c = cal.dateComponents([.year, .month, .day], from: d)
  return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}
func pd(_ s: String) -> Date? {
  let a = s.split(separator: "-").compactMap { Int($0) }
  guard a.count == 3 else { return nil }
  return cal.date(from: DateComponents(year: a[0], month: a[1], day: a[2]))
}
func dnum(_ d: Date) -> Int { cal.component(.day, from: d) }
func mnum(_ d: Date) -> Int { cal.component(.month, from: d) - 1 }
func ynum(_ d: Date) -> Int { cal.component(.year, from: d) }
func monthStart(_ d: Date) -> Date { cal.date(from: DateComponents(year: ynum(d), month: mnum(d) + 1, day: 1))! }
func addMonths(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .month, value: n, to: monthStart(d))! }
func toMin(_ t: String) -> Int {
  let a = t.split(separator: ":").compactMap { Int($0) }
  return a.count == 2 ? a[0] * 60 + a[1] : 0
}
func fmtMin(_ x: Int) -> String { "\(x / 60):" + String(format: "%02d", x % 60) }
func dur(_ m: Int) -> String {
  let h = m / 60, mm = m % 60
  return h > 0 ? "\(h) ч" + (mm > 0 ? " \(mm) мин" : "") : "\(mm) мин"
}
func plural(_ n: Int, _ a: String, _ b: String, _ c: String) -> String {
  let x = n % 100, y = n % 10
  return x > 10 && x < 20 ? c : y == 1 ? a : y >= 2 && y <= 4 ? b : c
}
func nowMin(_ t: Date) -> Int { cal.component(.hour, from: t) * 60 + cal.component(.minute, from: t) }
func isDateKey(_ s: String?) -> Bool { s?.range(of: #"^\d{4}-\d\d-\d\d$"#, options: .regularExpression) != nil }

// ---------- Расписание ----------
final class Sched {
  let anchor: Date, anchorT: String, last: Date
  let first: Date?
  var endAll: Date
  let pairs: [[String]]          // с единицы: pairs[1] это первая пара
  var byDay: [[Lesson]] = Array(repeating: [], count: 6)
  var changes: [String: [[String: Any]]] = [:]
  var session: (from: Date, to: Date, byDay: [String: [Lesson]])? = nil
  private var cache: [String: [Lesson]] = [:]
  private var busyCache: [Date: Bool] = [:]

  static func valid(_ x: [String: Any]?) -> Bool {
    guard let x else { return false }
    return isDateKey(x["anchor"] as? String) && isDateKey(x["end"] as? String)
      && ((x["bells"] as? [Any])?.isEmpty == false) && (x["lessons"] is [Any])
  }

  init?(_ x0: [String: Any], p2: Bool, noFive: Bool) {
    guard Sched.valid(x0), let an = pd(x0["anchor"] as! String), let la = pd(x0["end"] as! String) else { return nil }
    var x = x0
    anchor = an
    anchorT = (x["anchorType"] as? String) == "over" ? "over" : "under"
    last = la
    endAll = la
    first = isDateKey(x["start"] as? String) ? pd(x["start"] as! String) : nil
    let bells = (x["bells"] as? [[Any]] ?? []).map { $0.map { "\($0)" } }
    let ps: [[String]] = [[]] + bells
    pairs = ps
    if p2, let alt = x["alt"] as? [String: Any], let al = alt["lessons"] as? [Any] {
      x["lessons"] = al
      x["changes"] = alt["changes"] ?? [:]
    }
    let fillFn: (Lesson) -> Lesson? = { l0 in
      var l = l0
      guard l.p >= 1, l.p < ps.count, ps[l.p].count >= 2 else { return nil }
      let b = ps[l.p]
      l.a = toMin(b[0]); l.b = toMin(b[1])
      if !noFive, b.count >= 4, !b[2].isEmpty, !b[3].isEmpty { l.h1 = toMin(b[2]); l.h2 = toMin(b[3]) }
      return l
    }
    self.fillFn = fillFn
    for case let o as [String: Any] in (x["lessons"] as? [Any] ?? []) {
      let l0 = Sched.lesson(o)
      if l0.d >= 0 && l0.d < 6, let l = fillFn(l0) { byDay[l.d].append(l) }
    }
    for i in 0..<6 { byDay[i].sort { $0.p < $1.p } }
    if let ch = x["changes"] as? [String: Any] {
      for (k, v) in ch { if let arr = v as? [[String: Any]] { changes[k] = arr } }
    }
    if let s = x["session"] as? [String: Any], isDateKey(s["from"] as? String), isDateKey(s["to"] as? String),
       let f = pd(s["from"] as! String), let t = pd(s["to"] as! String) {
      var by: [String: [Lesson]] = [:]
      for case let it as [String: Any] in (s["items"] as? [Any] ?? []) {
        guard let dk = it["date"] as? String, isDateKey(dk) else { continue }
        var l = Sched.lesson(it)
        l.time = (it["time"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "9:00"
        l.m = toMin(l.time)
        let k = it["kind"] as? String ?? "other"
        l.kind = KINDS[k] != nil ? k : "other"
        by[dk, default: []].append(l)
      }
      for k in by.keys { by[k]!.sort { $0.m < $1.m } }
      session = (f, t, by)
      if t > endAll { endAll = t }
    }
  }
  private let fillFn: (Lesson) -> Lesson?

  static func lesson(_ o: [String: Any]) -> Lesson {
    var l = Lesson()
    l.d = (o["d"] as? NSNumber)?.intValue ?? 0
    l.p = (o["p"] as? NSNumber)?.intValue ?? 0
    l.w = o["w"] as? String ?? "all"
    l.s = o["s"] as? String ?? ""
    l.t = o["t"] as? String ?? ""
    l.tch = o["tch"] as? String ?? ""
    l.r = o["r"] as? String ?? ""
    l.was = o["was"] as? String ?? ""
    l.from = o["from"] as? String ?? ""
    l.cancel = (o["cancel"] as? Bool) ?? ((o["cancel"] as? NSNumber)?.boolValue ?? false)
    l.ed = (o["ed"] as? NSNumber)?.boolValue ?? false
    return l
  }

  func weekType(_ d: Date) -> String {
    let even = ((weeksBetween(anchor, d) % 2) + 2) % 2 == 0
    return even ? anchorT : (anchorT == "under" ? "over" : "under")
  }
  func weekName(_ d: Date) -> String { weekType(d) == "over" ? "над чертой" : "под чертой" }
  func beforeStart(_ d: Date) -> Bool { first != nil && day0(d) < first! }
  func afterEnd(_ d: Date) -> Bool { day0(d) > endAll }

  // Пары дня: постоянное расписание + замены и отмены на эту дату. Отменённые остаются с пометкой.
  func lessonsFor(_ d: Date) -> [Lesson] {
    let k = key(d)
    if let c = cache[k] { return c }
    let r = buildDay(d, k)
    cache[k] = r
    return r
  }
  private func buildDay(_ d: Date, _ k: String) -> [Lesson] {
    var list: [Lesson] = []
    let w = wd(d)
    if w < 6 && day0(d) <= last && !beforeStart(d) {
      let wt = weekType(d)
      list = byDay[w].filter { ($0.w == "all" || $0.w == wt) && ($0.from.isEmpty || k >= $0.from) }
    }
    guard let ch = changes[k] else { return list }
    var by: [Int: Lesson] = [:]
    for l in list { by[l.p] = l }
    for o in ch {
      var c = Sched.lesson(o)
      guard let filled = fillFn(c) else { continue }
      c = filled
      let base = by[c.p]
      if c.cancel { if var b = base { b.cancel = true; by[c.p] = b }; continue }
      if c.ed, var b = base { b.s = c.s; b.t = c.t; b.tch = c.tch; b.r = c.r; b.ed = true; by[c.p] = b; continue }
      c.sub = base != nil ? "rep" : "add"
      if c.was.isEmpty, let b = base { c.was = b.s + (b.tch.isEmpty ? "" : ", " + b.tch) }
      by[c.p] = c
    }
    return by.keys.sorted().map { by[$0]! }
  }
  func active(_ l: [Lesson]) -> [Lesson] { l.filter { !$0.cancel } }
  func itemsFor(_ d: Date) -> [Lesson] { session?.byDay[key(d)] ?? [] }
  func inSession(_ d: Date) -> Bool {
    guard let s = session else { return false }
    return day0(d) >= s.from && day0(d) <= s.to
  }
  // Суббота показывается, только если на неё что-то стоит
  func satBusy(_ mon: Date) -> Bool {
    if let b = busyCache[mon] { return b }
    let s = addDays(mon, 5)
    let b = !lessonsFor(s).isEmpty || !itemsFor(s).isEmpty
    busyCache[mon] = b
    return b
  }
  func daysIn(_ mon: Date) -> Int { satBusy(mon) ? 6 : 5 }
  func inStrip(_ d: Date) -> Bool { let w = wd(d); return w < 5 || (w == 5 && satBusy(mondayOf(d))) }
  func studyDay(_ d: Date) -> Date { var x = day0(d); var i = 0; while !inStrip(x) && i < 14 { x = addDays(x, 1); i += 1 }; return x }
  func firstDay() -> Date { studyDay(first ?? addDays(mondayOf(anchor), -7 * 20)) }
  func lastDay() -> Date { var d = day0(endAll); var i = 0; while !inStrip(d) && i < 14 { d = addDays(d, -1); i += 1 }; return d }
  func weekInSession(_ mon: Date) -> Bool { (0..<6).contains { inSession(addDays(mon, $0)) } }
  func clamp(_ d: Date) -> Date {
    var s = day0(d)
    if !inStrip(s) { s = weekday(s) == 6 ? addDays(s, -1) : studyDay(s) }
    if afterEnd(s) { s = lastDay() }
    if beforeStart(s) { s = firstDay() }
    return s
  }
  // Все учебные дни подряд: по ним листается полное расписание
  lazy var allDays: [Date] = {
    var r: [Date] = []
    var d = firstDay()
    let e = lastDay()
    var guardN = 0
    while d <= e && guardN < 800 { if inStrip(d) { r.append(d) }; d = addDays(d, 1); guardN += 1 }
    return r
  }()
  func isBig(_ a: Lesson, _ b: Lesson) -> Bool { b.p - a.p == 1 && b.a - a.b >= 25 }
  func pairTime(_ p: Int) -> (String, String) {
    guard p >= 1 && p < pairs.count && pairs[p].count >= 2 else { return ("", "") }
    return (pairs[p][0], pairs[p][1])
  }
}

// Заметки: к практикам (кроме физкультуры) и к экзаменам, зачётам, консультациям
func canNote(_ l: Lesson) -> Bool { !l.cancel && (l.kind != nil || ((l.t == "prac" || l.t == "mix") && l.s != FK)) }
func noteKey(_ d: Date, _ l: Lesson) -> String { key(d) + "|" + (l.kind != nil ? l.time : String(l.p)) + "|" + l.s }
