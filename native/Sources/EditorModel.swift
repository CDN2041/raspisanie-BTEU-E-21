import Foundation
import JavaScriptCore
import Security
import SwiftUI

// ---------- Пары и изменения, как они лежат в schedule.json ----------
struct ELesson: Hashable {
  var d = 0, p = 1, w = "all", s = "", t = "lec", tch = "", r = "", from = ""
  init() {}
  init(_ o: [String: Any]) {
    d = (o["d"] as? NSNumber)?.intValue ?? 0; p = (o["p"] as? NSNumber)?.intValue ?? 1
    w = o["w"] as? String ?? "all"; s = o["s"] as? String ?? ""; t = o["t"] as? String ?? ""
    tch = o["tch"] as? String ?? ""; r = o["r"] as? String ?? ""; from = o["from"] as? String ?? ""
  }
  var dict: [String: Any] { ["d": d, "p": p, "w": w, "s": s, "t": t, "tch": tch, "r": r, "from": from] }
}
struct EChange: Hashable {
  var p = 1, s = "", t = "", tch = "", r = "", was = "", ed = false, cancel = false
  init(p: Int) { self.p = p }
  init(_ o: [String: Any]) {
    p = (o["p"] as? NSNumber)?.intValue ?? 1; s = o["s"] as? String ?? ""; t = o["t"] as? String ?? ""
    tch = o["tch"] as? String ?? ""; r = o["r"] as? String ?? ""; was = o["was"] as? String ?? ""
    ed = (o["ed"] as? NSNumber)?.boolValue ?? false
    cancel = (o["cancel"] as? Bool) ?? (o["cancel"] as? NSNumber)?.boolValue ?? false
  }
  var dict: [String: Any] {
    cancel ? ["p": p, "cancel": true, "was": was]
      : ["p": p, "s": s, "t": t, "tch": tch, "r": r, "was": was, "ed": ed ? NSNumber(value: 1) : false]
  }
}
// Карточка пары: предмет + преподаватель, все типы и аудитории, которые у неё бывают
struct ECard: Identifiable, Hashable {
  var s: String, tch: String, t: [String] = [], r: [String] = [], main = "lec", own = false
  var id: String { s + "|" + tch }
}
let WEEKS = ["all": "Каждую", "over": "Над чертой", "under": "Под чертой"]
let TYPES = ["lec": "Лекция", "prac": "Практика", "mix": "Лекция/Практика"]
func short(_ s: String, _ tch: String) -> String { s + (tch.isEmpty ? "" : ", " + tch) }
func splitR(_ v: String) -> [String] {
  var out: [String] = []
  for y in v.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !y.isEmpty && !out.contains(y) { out.append(y) }
  return out
}

// ---------- Формат файла: те же функции, что в admin.html ----------
enum Format {
  private static let ctx: JSContext? = {
    guard let u = Bundle.main.url(forResource: "format", withExtension: "js"), let js = try? String(contentsOf: u) else { return nil }
    let c = JSContext()
    c?.evaluateScript(js)
    return c
  }()
  private static func call(_ fn: String, _ o: [String: Any]) -> String? {
    guard let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) else { return nil }
    return ctx?.objectForKeyedSubscript(fn)?.call(withArguments: [s])?.toString()
  }
  static func text(_ o: [String: Any]) -> String? { call("fmt", o) }   // готовый файл с отметкой времени
  static func body(_ o: [String: Any]) -> String { call("bodyOf", o) ?? "" } // для сравнения, без времени
  static func check(_ o: [String: Any]) -> String { call("check", o) ?? "Не получилось проверить расписание" }
}

// ---------- Ключ GitHub: в связке ключей телефона ----------
enum Keychain {
  static let service = "by.cdn2041.pary.editor"
  static func get() -> String? {
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    var r: AnyObject?
    guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return nil }
    return String(data: d, encoding: .utf8)
  }
  static func set(_ v: String?) {
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    SecItemDelete(q as CFDictionary)
    guard let v, let d = v.data(using: .utf8) else { return }
    var a = q; a[kSecValueData as String] = d; a[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(a as CFDictionary, nil)
  }
}

// ---------- GitHub ----------
enum GH {
  static let repo = "CDN2041/raspisanie-BTEU-E-21"
  static let api = URL(string: "https://api.github.com/repos/\(repo)/contents/schedule.json")!
  struct Err: LocalizedError { let text: String; var status = 0; var net = false; var errorDescription: String? { text } }

  static func req(_ url: URL, _ token: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest {
    var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    r.httpMethod = method
    r.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
    r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    if let body { r.httpBody = try? JSONSerialization.data(withJSONObject: body) }
    return r
  }
  static func send(_ r: URLRequest) async throws -> (Data, HTTPURLResponse) {
    do {
      let (d, resp) = try await URLSession.shared.data(for: r)
      return (d, resp as! HTTPURLResponse)
    } catch { throw Err(text: "Нет связи с GitHub. Проверьте интернет и попробуйте ещё раз.", net: true) }
  }

  // Ключ проверяется при каждом входе, как на сайте: настоящий ли, есть ли доступ и право записи
  static func check(_ t: String) async throws -> String {
    guard t.range(of: #"^(ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})$"#, options: .regularExpression) != nil else {
      throw Err(text: "Это не ключ GitHub. Ключ начинается с ghp_ и состоит из латинских букв и цифр. Скопируйте его целиком.")
    }
    let (d, r) = try await send(req(URL(string: "https://api.github.com/repos/\(repo)")!, t))
    if r.statusCode == 401 { throw Err(text: "Ключ неверный или уже удалён на GitHub. Создайте новый.") }
    guard r.statusCode == 200, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
      throw Err(text: "GitHub не дал доступ к репозиторию (ошибка \(r.statusCode)). Проверьте ключ.")
    }
    let p = j["permissions"] as? [String: Any] ?? [:]
    if !((p["push"] as? Bool ?? false) || (p["admin"] as? Bool ?? false) || (p["maintain"] as? Bool ?? false)) {
      throw Err(text: "Ключ настоящий, но у этого аккаунта нет доступа к редактору: его нет в соавторах репозитория.")
    }
    if let sc = r.value(forHTTPHeaderField: "X-OAuth-Scopes"), t.hasPrefix("ghp_"),
       sc.range(of: #"(^|,\s*)(public_repo|repo)(\s*,|$)"#, options: .regularExpression) == nil {
      throw Err(text: "У ключа не отмечено право public_repo, сохранять он не сможет.")
    }
    // Право записи проверяем делом: пустой служебный объект, в историю он не попадает
    let (_, w) = try await send(req(URL(string: "https://api.github.com/repos/\(repo)/git/blobs")!, t, method: "POST", body: ["content": "", "encoding": "utf-8"]))
    if !(200..<300).contains(w.statusCode) { throw Err(text: "У ключа нет права на запись в этот репозиторий.") }
    let (ud, _) = (try? await send(req(URL(string: "https://api.github.com/user")!, t))) ?? (Data(), HTTPURLResponse())
    return ((try? JSONSerialization.jsonObject(with: ud)) as? [String: Any])?["login"] as? String ?? ""
  }

  static func load(_ t: String) async throws -> (sha: String, data: [String: Any]) {
    var c = URLComponents(url: api, resolvingAgainstBaseURL: false)!
    c.queryItems = [URLQueryItem(name: "ref", value: "main")]
    let (d, r) = try await send(req(c.url!, t))
    guard r.statusCode == 200, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let sha = j["sha"] as? String, let b64 = j["content"] as? String,
          let raw = Data(base64Encoded: b64.replacingOccurrences(of: "\n", with: "")),
          let o = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
      throw Err(text: "Не удалось загрузить расписание (ошибка \(r.statusCode)).", status: r.statusCode)
    }
    return (sha, o)
  }

  static func save(_ t: String, text: String, sha: String) async throws -> String {
    let body: [String: Any] = ["message": "Update", "content": Data(text.utf8).base64EncodedString(), "sha": sha, "branch": "main"]
    let (d, r) = try await send(req(api, t, method: "PUT", body: body))
    guard (200..<300).contains(r.statusCode) else {
      let s = r.statusCode
      throw Err(text: s == 409 || s == 422 ? "Файл успел поменяться. Обновите редактор и повторите"
                : s == 401 || s == 403 || s == 404 ? "Нет прав на запись. Проверьте ключ" : "Не сохранилось: ошибка \(s)", status: s)
    }
    return (((try? JSONSerialization.jsonObject(with: d)) as? [String: Any])?["content"] as? [String: Any])?["sha"] as? String ?? sha
  }
}

// ---------- Состояние редактора ----------
@MainActor
final class Editor: ObservableObject {
  enum Phase: Equatable { case checking, login(String?), ready, failed(String) }
  @Published var phase: Phase = .checking
  @Published var login = ""
  @Published private(set) var lessons: [ELesson] = []
  @Published private(set) var changes: [String: [EChange]] = [:]
  @Published var date: Date = Editor.firstDate()
  @Published private(set) var dirty = false
  @Published var saving = false
  @Published var toast: String? = nil

  private var raw: [String: Any] = [:]
  private var base = ""
  private var sha = ""
  private var token = ""
  var bells: [[String]] { (raw["bells"] as? [[Any]] ?? []).map { $0.map { "\($0)" } } }
  var start: Date? { (raw["start"] as? String).flatMap(pd) }
  var end: Date? { (raw["end"] as? String).flatMap(pd) }

  static func firstDate() -> Date { var d = day0(Date()); if weekday(d) == 0 { d = addDays(d, 1) }; return d }

  func open(store: Store) async {
    if Shot.on { // для скриншотов: расписание из сборки, без ключа и сети
      if let o = Shared.parse(Shared.readSchedule()) { setData(o) }
      login = "CDN2041"; date = day0(Shot.now ?? Date()); phase = .ready
      return
    }
    phase = .checking
    var t = Keychain.get()
    if t == nil { t = await WebToken.read(); if let t { Keychain.set(t) } } // ключ из прежнего веб-редактора
    guard let t else { phase = .login(nil); return }
    await enter(t)
  }
  func enter(_ t: String) async {
    phase = .checking
    do {
      login = try await GH.check(t)
      token = t; Keychain.set(t)
      let r = try await GH.load(t)
      sha = r.sha
      setData(r.data)
      phase = .ready
    } catch let e as GH.Err {
      if e.net { phase = .failed(e.text) } else { Keychain.set(nil); phase = .login(e.text) }
    } catch { phase = .failed(error.localizedDescription) }
  }
  func logout() { Keychain.set(nil); token = ""; phase = .login(nil) }

  private func setData(_ o: [String: Any]) {
    raw = o
    lessons = (o["lessons"] as? [[String: Any]] ?? []).map(ELesson.init)
    var ch: [String: [EChange]] = [:]
    for (k, v) in o["changes"] as? [String: Any] ?? [:] { if let a = v as? [[String: Any]] { ch[k] = a.map(EChange.init) } }
    changes = ch
    base = Format.body(current)
    dirty = false
  }
  private var current: [String: Any] {
    var o = raw
    o["lessons"] = lessons.map { $0.dict }
    var ch: [String: Any] = [:]
    for (k, v) in changes where !v.isEmpty { ch[k] = v.map { $0.dict } }
    o["changes"] = ch
    return o
  }
  private func touched() { dirty = Format.body(current) != base }
  func undo() { setData(raw) ; Haptic.tap() }

  func save(store: Store) async {
    let err = Format.check(current)
    if !err.isEmpty { show(err); Haptic.warn(); return }
    guard let text = Format.text(current) else { show("Не получилось собрать файл"); return }
    saving = true
    defer { saving = false }
    do {
      sha = try await GH.save(token, text: text, sha: sha)
      if let o = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] { setData(o) }
      store.adopt(Data(text.utf8)) // у самого старосты приложение обновится сразу
      Haptic.ok()
      show("Сохранено. У всех обновится через 1-2 минуты")
    } catch {
      Haptic.warn()
      show(error.localizedDescription)
    }
  }
  func show(_ t: String) {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { toast = t }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
      if self?.toast == t { withAnimation(.easeOut(duration: 0.3)) { self?.toast = nil } }
    }
  }

  // ---------- Расчёт недели ----------
  func weekType(_ d: Date) -> String {
    let an = (raw["anchor"] as? String).flatMap(pd) ?? d
    let a = (raw["anchorType"] as? String) == "over" ? "over" : "under"
    let even = ((weeksBetween(an, d) % 2) + 2) % 2 == 0
    return even ? a : (a == "under" ? "over" : "under")
  }
  // Постоянное расписание на дату, без замен
  func baseFor(_ d: Date) -> [Int: ELesson] {
    let w = wd(d)
    if w > 5 || (end.map { day0(d) > $0 } ?? false) || (start.map { day0(d) < $0 } ?? false) { return [:] }
    let wt = weekType(d), k = key(d)
    var by: [Int: ELesson] = [:]
    for l in lessons where l.d == w && (l.w == "all" || l.w == wt) && (l.from.isEmpty || k >= l.from) { by[l.p] = l }
    return by
  }
  func changeOf(_ k: String, _ p: Int) -> EChange? { changes[k]?.first { $0.p == p } }
  func setChange(_ k: String, _ p: Int, _ c: EChange?) {
    var a = (changes[k] ?? []).filter { $0.p != p }
    if let c { a.append(c) }
    a.sort { $0.p < $1.p }
    changes[k] = a.isEmpty ? nil : a
    touched()
  }
  func edDiff(_ b: ELesson, _ c: EChange) -> String {
    var o: [String] = []
    if b.s != c.s { o.append(b.s) }
    if b.t != c.t { o.append(b.t == "lec" ? "лекция" : b.t == "prac" ? "практика" : "лекция/практика") }
    if b.tch != c.tch { o.append(b.tch.isEmpty ? "без преподавателя" : b.tch) }
    if b.r != c.r { o.append(b.r.isEmpty ? "без аудитории" : "ауд. " + b.r) }
    return o.joined(separator: ", ")
  }
  func indices(day w: Int, p: Int) -> [Int] { lessons.indices.filter { lessons[$0].d == w && lessons[$0].p == p } }

  // ---------- Действия ----------
  func cancel(_ k: String, _ p: Int) {
    var c = EChange(p: p); c.cancel = true
    if let b = baseFor(pd(k)!)[p] { c.was = short(b.s, b.tch) }
    setChange(k, p, c); show("Пара отменена на этот день")
  }
  func restore(_ k: String, _ p: Int) { setChange(k, p, nil) }
  func deleteForever(_ i: Int) {
    guard lessons.indices.contains(i) else { return }
    let l = lessons.remove(at: i)
    touched(); show("Пара «\(l.s)» удалена из расписания")
  }
  // Разовая правка: меняется только эта дата
  func once(_ k: String, _ p: Int, _ v: ELesson) {
    let bo = baseFor(pd(k)!)[p], co = changeOf(k, p)
    var n = EChange(p: p); n.s = v.s; n.t = v.t; n.tch = v.tch; n.r = v.r
    if let co, !co.cancel, !co.ed { n.was = co.was; setChange(k, p, n); show("Замена изменена"); return }
    guard let bo else { return }
    if edDiff(bo, n).isEmpty { setChange(k, p, nil); show("Как по расписанию"); return }
    n.ed = true; setChange(k, p, n); show("Изменено только на этот день")
  }
  func substitute(_ k: String, _ p: Int, _ v: ELesson) {
    let bs = baseFor(pd(k)!)[p]
    var n = EChange(p: p); n.s = v.s; n.t = v.t; n.tch = v.tch; n.r = v.r; n.was = bs.map { short($0.s, $0.tch) } ?? ""
    setChange(k, p, n); show(bs != nil ? "Замена поставлена" : "Пара добавлена на этот день")
  }
  // Постоянная пара: nil если всё хорошо, иначе текст ошибки
  func saveLesson(_ i: Int?, _ n: ELesson) -> String? {
    if n.s.trimmingCharacters(in: .whitespaces).isEmpty { return "Укажите предмет" }
    for (j, o) in lessons.enumerated() where j != i && o.d == n.d && o.p == n.p && (o.w == n.w || o.w == "all" || n.w == "all") {
      return "В это время уже стоит " + o.s + (o.w != "all" ? " (" + (WEEKS[o.w] ?? "").lowercased() + ")" : "")
    }
    if let i { lessons[i] = n } else { lessons.append(n) }
    date = addDays(mondayOf(date), n.d)
    touched()
    return nil
  }
  func clearPast() {
    let today = key(Date())
    for k in changes.keys where k < today { changes[k] = nil }
    touched()
  }

  // Все карточки: из справочника и из постоянного расписания, без повторов
  func allCards() -> [ECard] {
    var by: [String: Int] = [:], out: [ECard] = []
    func take(_ s: String, _ tch: String, _ t: String, _ r: String, own: Bool) {
      let k = s + "|" + tch
      if by[k] == nil { by[k] = out.count; out.append(ECard(s: s, tch: tch, own: own)) }
      let i = by[k]!
      if !t.isEmpty && !out[i].t.contains(t) { out[i].t.append(t) }
      if own || !out[i].own { for x in splitR(r) where !out[i].r.contains(x) { out[i].r.append(x) } }
    }
    for case let c as [String: Any] in raw["cards"] as? [Any] ?? [] {
      let r = (c["r"] as? [String])?.joined(separator: ",") ?? (c["r"] as? String ?? "")
      take(c["s"] as? String ?? "", c["tch"] as? String ?? "", "", r, own: true)
    }
    var cnt: [String: [String: Int]] = [:]
    for l in lessons { take(l.s, l.tch, l.t, l.r, own: false); cnt[l.s + "|" + l.tch, default: [:]][l.t, default: 0] += 1 }
    for i in out.indices {
      let m = cnt[out[i].id] ?? [:]
      out[i].main = m.max { $0.value < $1.value }?.key ?? out[i].t.first ?? "mix"
      out[i].r.sort { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    return out.sorted { ($0.s, $0.tch) < ($1.s, $1.tch) }
  }
  func suggestions(_ f: (ELesson) -> String) -> [String] { Array(Set(lessons.map(f).filter { !$0.isEmpty })).sorted() }
}

// Ключ, который уже вводили в веб-редакторе внутри приложения
enum WebToken {
  @MainActor static func read() async -> String? {
    await withCheckedContinuation { c in
      var m: Migrator?
      m = Migrator(js: "localStorage.getItem('pary-e21-admin-token')") { r in
        c.resume(returning: (r as? String).flatMap { $0.isEmpty ? nil : $0 })
        m = nil
      }
      _ = m
    }
  }
}
