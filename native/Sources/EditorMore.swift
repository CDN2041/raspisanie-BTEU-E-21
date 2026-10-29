import Foundation
import CryptoKit
import SwiftUI

// Сессия: экзамены, зачёты, консультации
struct EItem: Hashable {
  var date = "", time = "9:00", kind = "exam", s = "", tch = "", r = ""
  init() {}
  init(_ o: [String: Any]) {
    date = o["date"] as? String ?? ""; time = o["time"] as? String ?? "9:00"; kind = o["kind"] as? String ?? "exam"
    s = o["s"] as? String ?? ""; tch = o["tch"] as? String ?? ""; r = o["r"] as? String ?? ""
  }
  var dict: [String: Any] { ["date": date, "time": time, "kind": kind, "s": s, "tch": tch, "r": r] }
}
let EKINDS: [(String, String)] = [("exam", "Экзамен"), ("credit", "Зачёт"), ("consult", "Консультация"), ("other", "Другое")]

func minutesToDate(_ t: String) -> Date { cal.date(byAdding: .minute, value: toMin(t), to: day0(Date()))! }
func dateToTime(_ d: Date) -> String { fmtMin(cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d)) }

extension Editor {
  // ---------- Общее ----------
  var curWeekType: String { weekType(mondayOf(Date())) }
  func setWeekType(_ t: String) { raw["anchor"] = key(mondayOf(Date())); raw["anchorType"] = t; touched() }
  func setStart(_ d: Date?) { raw["start"] = d.map(key) ?? ""; touched() }
  func setEnd(_ d: Date) { raw["end"] = key(d); touched() }

  var bellsRaw: [[String]] { bells }
  func setBells(_ b: [[String]]) { raw["bells"] = b; touched() }
  func setBell(_ i: Int, _ e: Int, _ d: Date) {
    var b = bells; guard b.indices.contains(i), b[i].indices.contains(e) else { return }
    b[i][e] = dateToTime(d); setBells(b)
  }
  func addBell() {
    var b = bells; guard let lb = b.last, lb.count >= 2 else { return }
    let st = toMin(lb[1]) + 10, ln = toMin(lb[1]) - toMin(lb[0])
    b.append([fmtMin(st), fmtMin(st + ln)]); setBells(b)
  }
  func delBell() { var b = bells; if b.count > 1 { b.removeLast(); setBells(b) } }
  func addFive(_ i: Int) {
    var b = bells; guard b.indices.contains(i) else { return }
    let s0 = toMin(b[i][0]), m0 = s0 + (toMin(b[i][1]) - s0 - 5) / 2
    b[i] = [b[i][0], b[i][1], fmtMin(m0), fmtMin(m0 + 5)]; setBells(b)
  }
  func delFive(_ i: Int) { var b = bells; guard b.indices.contains(i) else { return }; b[i] = Array(b[i].prefix(2)); setBells(b) }
  func bellUsed(_ i: Int) -> Bool { lessons.contains { $0.p == i + 1 } }

  // ---------- Сессия ----------
  var session: (from: String, to: String, items: [EItem])? {
    guard let s = raw["session"] as? [String: Any] else { return nil }
    return (s["from"] as? String ?? "", s["to"] as? String ?? "", (s["items"] as? [[String: Any]] ?? []).map(EItem.init))
  }
  func setSession(from: String, to: String, items: [EItem]) {
    raw["session"] = ["from": from, "to": to, "items": items.map { $0.dict }]; touched()
  }
  func deleteSession() { raw["session"] = NSNull(); touched() }

  // ---------- Карточки ----------
  var ownCards: [[String: Any]] { raw["cards"] as? [[String: Any]] ?? [] }
  func usedCard(_ k0: String) -> Bool {
    let today = key(Date())
    if lessons.contains(where: { $0.s + "|" + $0.tch == k0 }) { return true }
    return changes.contains { $0.key >= today && $0.value.contains { !$0.cancel && $0.s + "|" + $0.tch == k0 } }
  }
  // nil если всё хорошо, иначе текст ошибки. Переименование доходит до всех пар с этой карточкой
  func saveCard(k0: String?, s: String, tch: String, rooms: [String]) -> String? {
    let s = s.trimmingCharacters(in: .whitespaces), tch = tch.trimmingCharacters(in: .whitespaces)
    if s.isEmpty { return "Укажите предмет" }
    let nk = s + "|" + tch
    if nk != k0 && allCards().contains(where: { $0.id == nk }) { return "Карточка с таким предметом и преподавателем уже есть" }
    var cards = ownCards.filter { (($0["s"] as? String ?? "") + "|" + ($0["tch"] as? String ?? "")) != k0 }
    if let k0 {
      let today = key(Date())
      for i in lessons.indices where lessons[i].s + "|" + lessons[i].tch == k0 { lessons[i].s = s; lessons[i].tch = tch }
      for (d, arr) in changes where d >= today {
        changes[d] = arr.map { c in var c = c; if !c.cancel && c.s + "|" + c.tch == k0 { c.s = s; c.tch = tch }; return c }
      }
    }
    cards.append(["s": s, "tch": tch, "r": rooms])
    raw["cards"] = cards; touched()
    return nil
  }
  func deleteCard(_ k0: String) {
    raw["cards"] = ownCards.filter { (($0["s"] as? String ?? "") + "|" + ($0["tch"] as? String ?? "")) != k0 }; touched()
  }
  func roomSuggestions() -> [String] {
    var all = Set<String>()
    for l in lessons { splitR(l.r).forEach { all.insert($0) } }
    return all.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  // ---------- Редактор 2 ----------
  static func altHash(_ k: String) -> String {
    SHA256.hash(data: Data(("pary-e21-alt|" + k).utf8)).map { String(format: "%02x", $0) }.joined()
  }
  var altHasKey: Bool { ((raw["alt"] as? [String: Any])?["h"] as? String)?.isEmpty == false }
  // nil если вошли, иначе текст ошибки
  func openAlt(_ k: String) -> String? {
    if k.isEmpty { return "Введите ключ" }
    var alt = raw["alt"] as? [String: Any] ?? [:]
    if altHasKey { if Editor.altHash(k) != alt["h"] as? String { return "Ключ не подходит" } }
    else {
      if k.count < 4 { return "Минимум 4 символа" }
      alt["h"] = Editor.altHash(k)
      show("Ключ задан. Не забудьте сохранить")
    }
    // Первый вход: копия общего расписания
    if alt["lessons"] == nil {
      alt["lessons"] = lessons.map { $0.dict }
      var ch: [String: Any] = [:]
      for (k, v) in changes where !v.isEmpty { ch[k] = v.map { $0.dict } }
      alt["changes"] = ch
    }
    raw["alt"] = alt
    swapAlt()
    touched()
    return nil
  }
  func closeAlt() { if altOpen { swapAlt() } }
  func altReset() {
    guard altOpen else { return }
    swapAlt() // вернуть общее на место
    var alt = raw["alt"] as? [String: Any] ?? [:]
    alt["lessons"] = lessons.map { $0.dict }
    var ch: [String: Any] = [:]
    for (k, v) in changes where !v.isEmpty { ch[k] = v.map { $0.dict } }
    alt["changes"] = ch
    raw["alt"] = alt
    swapAlt()
    touched()
    show("Скопировано общее расписание")
  }
}

// Счётчик посещений (Abacus)
enum Visits {
  static let base = "https://abacus.jasoncameron.dev/get/cdn2041-raspisanie-bteu-e21/"
  static func load() async -> [(String, Int)]? {
    let t = day0(Date())
    var names = ["devices"]
    for i in 0..<7 { names.append("d-" + key(addDays(t, -i))) }
    var vals: [Int] = []
    for n in names {
      guard let u = URL(string: base + n) else { return nil }
      var r = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
      r.httpMethod = "GET"
      guard let res = try? await URLSession.shared.data(for: r), let h = res.1 as? HTTPURLResponse else { return nil }
      let d = res.0
      if h.statusCode == 404 { vals.append(0); continue }
      guard h.statusCode == 200, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
      vals.append((j["value"] as? NSNumber)?.intValue ?? 0)
    }
    var out: [(String, Int)] = [("Сегодня", vals[1]), ("Вчера", vals[2])]
    for k in 3..<8 { let d = addDays(t, -(k - 1)); out.append((DSHORT[min(5, wd(d))] + ", \(dnum(d)) " + MONF[mnum(d)], vals[k])) }
    out.append(("Всего устройств", vals[0]))
    return out
  }
}
