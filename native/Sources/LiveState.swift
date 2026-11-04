import Foundation
import ActivityKit

// Эфир активности: что показывать на экране блокировки, в Dynamic Island и на часах.
// Полоски пар и таймеры идут сами по часам, поэтому эфир остаётся верным и без обновлений.
struct ParyAttributes: ActivityAttributes {
  struct Seg: Codable, Hashable { var p: Int; var a: Date; var b: Date; var room: String }
  struct ContentState: Codable, Hashable {
    var head = ""           // «3 пара · до перерыва»
    var subj = "", room = ""
    var cd = Date()         // до какого момента считает таймер
    var next = ""           // «14:40 · Правовое обеспечение · 1-22»
    var segs: [Seg] = []    // все пары дня
    var dayEnd = Date()
    var p = 0
    var live = false        // идёт пара
  }
  var day: String
}

func liveContent(_ sc: Sched, _ t: Date) -> ParyAttributes.ContentState? {
  let td = day0(t), m = nowMin(t)
  let all = sc.active(sc.lessonsFor(td))
  func at(_ x: Int) -> Date { cal.date(byAdding: .minute, value: x, to: td) ?? td }
  func line(_ l: Lesson?) -> String {
    guard let l else { return "" }
    return sc.pairTime(l.p).0 + " · " + l.s + (l.r.isEmpty ? "" : " · " + l.r)
  }
  var s = ParyAttributes.ContentState()
  if all.isEmpty {
    // Сессия: до начала экзамена или консультации
    guard let it = sc.itemsFor(td).first(where: { $0.m > m }) else { return nil }
    s.head = (KINDS[it.kind ?? "other"] ?? "") + " · до начала"
    s.subj = it.s; s.room = it.r; s.cd = at(it.m); s.dayEnd = s.cd
    return s
  }
  guard let last = all.last, m < last.b else { return nil }
  s.segs = all.map { ParyAttributes.Seg(p: $0.p, a: at($0.a), b: at($0.b), room: $0.r) }
  s.dayEnd = at(last.b)
  if let cur = all.first(where: { m >= $0.a && m < $0.b }) {
    var label = "до конца", end = cur.b
    if let h1 = cur.h1, let h2 = cur.h2, h1 > cur.a, h2 < cur.b, h2 > h1 {
      if m < h1 { label = "до перерыва"; end = h1 } else if m < h2 { label = "перерыв"; end = h2 }
    }
    s.live = true; s.p = cur.p
    s.head = "\(cur.p) пара · " + label
    s.subj = cur.s; s.room = cur.r; s.cd = at(end)
    s.next = line(all.first { $0.p > cur.p })
  } else if let nl = all.first(where: { $0.a > m }) {
    let prev = all.last { $0.b <= m }
    s.p = nl.p
    s.head = prev == nil ? "\(nl.p) пара · до начала" : "Перерыв · до \(nl.p) пары"
    s.subj = nl.s; s.room = nl.r; s.cd = at(nl.a)
    s.next = line(all.first { $0.p > nl.p })
  }
  return s
}
