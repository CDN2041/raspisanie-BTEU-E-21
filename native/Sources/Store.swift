import Foundation
import SwiftUI
import WebKit
import WidgetKit

let SITE = URL(string: "https://cdn2041.github.io/raspisanie-BTEU-E-21/")!
let SCHED_URL = SITE.appendingPathComponent("schedule.json")

// Режим скриншотов для проверки сборки: время и экран задаются снаружи
enum Shot {
  static let env = ProcessInfo.processInfo.environment
  static let screen = env["SHOT_SCREEN"]
  static let now: Date? = parse(env["SHOT_NOW"])
  static var on: Bool { screen != nil }
  static func parse(_ s: String?) -> Date? {
    guard let s else { return nil }
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)
  }
}

@MainActor
final class Store: ObservableObject {
  enum Status: Equatable { case loading, ok, error(String, String) }
  @Published private(set) var sched: Sched?
  @Published private(set) var status: Status = .loading
  @Published private(set) var notes: [String: String] = [:] { didSet { noteDays = Set(notes.keys.map { String($0.prefix(10)) }) } }
  @Published var ui = "new"        // "new" экран «Сейчас», "old" всё расписание
  @Published var theme = "system"
  @Published private(set) var p2 = false
  @Published private(set) var noFive = false
  @Published private(set) var rev = 0 // меняется с каждой новой версией расписания

  private var noteDays: Set<String> = []
  private var raw: [String: Any]?
  private var lastFetch = Date.distantPast
  private let ud = Shared.store
  static let NKEY = "pary-notes-v1", SKEY = "pary-settings-v1"

  init() {
    moveToGroup()
    if let s = ud.string(forKey: Store.NKEY), let d = s.data(using: .utf8),
       let o = try? JSONSerialization.jsonObject(with: d) as? [String: String] { notes = o }
    if let s = ud.string(forKey: Store.SKEY), let d = s.data(using: .utf8),
       let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { applySettings(o) }
    p2 = Shared.p2
    noFive = Shared.noFive
    if Shot.on {
      theme = Shot.env["SHOT_THEME"] ?? "system"
      if let u = Bundle.main.url(forResource: "schedule", withExtension: "json") { boot(try? Data(contentsOf: u)) }
      // Для скриншотов: одна заметка к первой практике дня
      if let sc = sched, let n = Shot.now, let l = sc.lessonsFor(day0(n)).first(where: canNote) {
        notes[noteKey(day0(n), l)] = "Сдать реферат и взять методичку"
      }
    } else {
      boot(Shared.readSchedule())
    }
    noteDays = Set(notes.keys.map { String($0.prefix(10)) }) // в init наблюдатель didSet не срабатывает
  }

  // Первая сборка хранила всё в своей папке: переносим в общую, чтобы видел виджет
  private func moveToGroup() {
    guard let g = Shared.defaults, !g.bool(forKey: "moved-v1") else { return }
    let s = UserDefaults.standard
    for k in [Store.NKEY, Store.SKEY, "pary-e21-p2", "pary-e21-nofive", "migrated-v1"] where g.object(forKey: k) == nil {
      if let v = s.object(forKey: k) { g.set(v, forKey: k) }
    }
    if let d = try? Data(contentsOf: Shared.ownDir.appendingPathComponent("schedule.json")) { Shared.writeSchedule(d) }
    g.set(true, forKey: "moved-v1")
  }

  private func applySettings(_ o: [String: Any]) {
    ui = (o["ui"] as? String) == "old" ? "old" : "new"
    let t = o["theme"] as? String ?? "system"
    theme = ["dark", "light"].contains(t) ? t : "system"
  }

  var now: Date { Shot.now ?? Date() }
  var colorScheme: ColorScheme? { theme == "dark" ? .dark : theme == "light" ? .light : nil }

  @discardableResult
  private func boot(_ data: Data?) -> Bool {
    guard let o = Shared.parse(data), let s = Sched(o, p2: p2, noFive: noFive) else { return false }
    raw = o; sched = s; status = .ok; rev += 1
    return true
  }
  private func rebuild() {
    guard let o = raw, let s = Sched(o, p2: p2, noFive: noFive) else { return }
    sched = s; rev += 1
    reloadWidgets()
  }
  private func reloadWidgets() { if !Shot.on { WidgetCenter.shared.reloadAllTimelines() } }

  func fetch(force: Bool = false) async {
    if Shot.on || (!force && Date().timeIntervalSince(lastFetch) < 60) { return }
    lastFetch = Date()
    var req = URLRequest(url: SCHED_URL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
    req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    do {
      let (data, resp) = try await URLSession.shared.data(for: req)
      guard (resp as? HTTPURLResponse)?.statusCode == 200, let o = Shared.parse(data) else {
        if sched == nil { status = .error("Ошибка в расписании", "Файл расписания повреждён. Сообщите старосте.") }
        return
      }
      // Админ только что сохранил новую версию, а сайт ещё отдаёт старую: ждём, пока он обновится
      let newU = (o["updated"] as? NSNumber)?.doubleValue ?? 0, oldU = (raw?["updated"] as? NSNumber)?.doubleValue ?? 0
      if raw != nil && oldU > newU && Date().timeIntervalSince1970 * 1000 - oldU < 15 * 60000 { return }
      if let r = raw, NSDictionary(dictionary: r).isEqual(to: o) { return }
      Shared.writeSchedule(data)
      withAnimation(.easeInOut(duration: 0.35)) { _ = boot(data) }
      reloadWidgets()
    } catch {
      if sched == nil { status = .error("Нет связи", "Расписание загрузится, когда появится интернет.") }
    }
  }

  // ---------- Заметки и настройки ----------
  func note(_ d: Date, _ l: Lesson) -> String? { canNote(l) ? notes[noteKey(d, l)] : nil }
  func dayHasNote(_ d: Date) -> Bool { noteDays.contains(key(d)) }
  func setNote(_ k: String, _ v: String?) {
    let t = v?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if t.isEmpty { notes.removeValue(forKey: k) } else { notes[k] = t }
    saveNotes()
  }
  private func saveNotes() {
    if Shot.on { return }
    if let d = try? JSONSerialization.data(withJSONObject: notes), let s = String(data: d, encoding: .utf8) { ud.set(s, forKey: Store.NKEY) }
    reloadWidgets()
  }
  func saveSettings() {
    if Shot.on { return }
    if let d = try? JSONSerialization.data(withJSONObject: ["ui": ui, "theme": theme]), let s = String(data: d, encoding: .utf8) { ud.set(s, forKey: Store.SKEY) }
  }
  func toggleP2() {
    p2.toggle()
    ud.set(p2 ? "1" : nil, forKey: "pary-e21-p2")
    rebuild()
  }
  func setNoFive(_ v: Bool) {
    guard v != noFive else { return }
    noFive = v
    ud.set(v ? "1" : nil, forKey: "pary-e21-nofive")
    rebuild()
  }

  // ---------- Перенос заметок и настроек из прошлой версии приложения ----------
  // Прошлая версия была сайтом внутри приложения и хранила всё в localStorage этого же адреса.
  private var migrator: Migrator?
  func migrate() {
    if Shot.on || ud.bool(forKey: "migrated-v1") { return }
    migrator = Migrator { [weak self] o in
      guard let self else { return }
      self.migrator = nil
      guard let o else { return }
      if let s = o["n"] as? String, let d = s.data(using: .utf8), let n = try? JSONSerialization.jsonObject(with: d) as? [String: String] {
        var m = self.notes
        for (k, v) in n where m[k] == nil { m[k] = v }
        self.notes = m
        self.saveNotes()
      }
      if self.ud.string(forKey: Store.SKEY) == nil, let s = o["s"] as? String, let d = s.data(using: .utf8),
         let st = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
        self.applySettings(st); self.saveSettings()
      }
      if (o["p2"] as? String) == "1" && !self.p2 { self.toggleP2() }
      if (o["nf"] as? String) == "1" { self.setNoFive(true) }
      self.ud.set(true, forKey: "migrated-v1")
    }
  }
}

// Открывает пустую страницу с адресом сайта и читает его localStorage
final class Migrator: NSObject, WKNavigationDelegate {
  private var web: WKWebView?
  private let done: ([String: Any]?) -> Void
  init(done: @escaping ([String: Any]?) -> Void) {
    self.done = done
    super.init()
    let c = WKWebViewConfiguration()
    c.websiteDataStore = .default()
    let w = WKWebView(frame: .zero, configuration: c)
    w.navigationDelegate = self
    web = w
    w.loadHTMLString("<html><body></body></html>", baseURL: SITE)
  }
  func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
    let js = "JSON.stringify({n:localStorage.getItem('pary-notes-v1'),s:localStorage.getItem('pary-settings-v1'),p2:localStorage.getItem('pary-e21-p2'),nf:localStorage.getItem('pary-e21-nofive')})"
    w.evaluateJavaScript(js) { [weak self] r, _ in
      var o: [String: Any]? = nil
      if let s = r as? String, let d = s.data(using: .utf8) { o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] }
      DispatchQueue.main.async { self?.finish(o) }
    }
  }
  func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { finish(nil) }
  func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { finish(nil) }
  private func finish(_ o: [String: Any]?) {
    guard web != nil else { return }
    web = nil
    done(o)
  }
}
