import Foundation
import SwiftUI
import WebKit

let SITE = URL(string: "https://cdn2041.github.io/raspisanie-BTEU-E-21/")!
let SCHED_URL = URL(string: "https://cdn2041.github.io/raspisanie-BTEU-E-21/schedule.json")!

// Режим скриншотов для проверки сборки: время и экран задаются снаружи
enum Shot {
  static let env = ProcessInfo.processInfo.environment
  static let screen = env["SHOT_SCREEN"]
  static let now: Date? = {
    guard let s = env["SHOT_NOW"] else { return nil }
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)
  }()
  static var on: Bool { screen != nil }
}

@MainActor
final class Store: ObservableObject {
  enum Status: Equatable { case loading, ok, error(String, String) }
  @Published var sched: Sched?
  @Published var status: Status = .loading
  @Published var notes: [String: String] = [:]
  @Published var ui = "new"        // "new" экран «Сейчас», "old" всё расписание
  @Published var theme = "system"
  @Published var p2 = false
  @Published var noFive = false
  @Published var rev = 0           // меняется при каждой новой версии расписания

  private var raw: [String: Any]?
  private let ud = UserDefaults.standard
  private var lastFetch = Date.distantPast
  private let cacheURL: URL = {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("schedule.json")
  }()

  static let NKEY = "pary-notes-v1", SKEY = "pary-settings-v1"

  init() {
    if let s = ud.string(forKey: Store.NKEY), let d = s.data(using: .utf8),
       let o = try? JSONSerialization.jsonObject(with: d) as? [String: String] { notes = o }
    if let s = ud.string(forKey: Store.SKEY), let d = s.data(using: .utf8),
       let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
      ui = (o["ui"] as? String) == "old" ? "old" : "new"
      let t = o["theme"] as? String ?? "system"
      theme = ["dark", "light"].contains(t) ? t : "system"
    }
    p2 = ud.string(forKey: "pary-e21-p2") == "1"
    noFive = ud.string(forKey: "pary-e21-nofive") == "1"
    if Shot.on { theme = Shot.env["SHOT_THEME"] ?? "system" }
    // Сначала то, что уже есть: прошлая загрузка или копия из сборки
    if !Shot.on, let d = try? Data(contentsOf: cacheURL), boot(d) {}
    else if let u = Bundle.main.url(forResource: "schedule", withExtension: "json"), let d = try? Data(contentsOf: u), boot(d) {}
    // Для скриншотов: одна заметка к первой практике дня
    if Shot.on, let sc = sched {
      let d = day0(now)
      if let l = sc.lessonsFor(d).first(where: { canNote($0) }) { notes[noteKey(d, l)] = "Сдать реферат и взять методичку" }
    }
  }

  var now: Date { Shot.now ?? Date() }
  var colorScheme: ColorScheme? { theme == "dark" ? .dark : theme == "light" ? .light : nil }

  @discardableResult
  private func boot(_ data: Data) -> Bool {
    guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], Sched.valid(o),
          let s = Sched(o, p2: p2, noFive: noFive) else { return false }
    raw = o
    sched = s
    status = .ok
    rev += 1
    return true
  }
  func rebuild() {
    guard let o = raw, let s = Sched(o, p2: p2, noFive: noFive) else { return }
    sched = s
    rev += 1
  }

  func fetch(force: Bool = false) async {
    if Shot.on { return }
    if !force && Date().timeIntervalSince(lastFetch) < 60 { return }
    lastFetch = Date()
    var req = URLRequest(url: SCHED_URL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
    req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    do {
      let (data, resp) = try await URLSession.shared.data(for: req)
      guard (resp as? HTTPURLResponse)?.statusCode == 200,
            let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], Sched.valid(o) else {
        if sched == nil { status = .error("Ошибка в расписании", "Файл расписания повреждён. Сообщите старосте.") }
        return
      }
      // Админ только что сохранил новую версию, а сайт ещё отдаёт старую: ждём, пока он обновится
      let newU = (o["updated"] as? NSNumber)?.doubleValue ?? 0
      let oldU = (raw?["updated"] as? NSNumber)?.doubleValue ?? 0
      if raw != nil && oldU > newU && Date().timeIntervalSince1970 * 1000 - oldU < 15 * 60000 { return }
      if let r = raw, NSDictionary(dictionary: r).isEqual(to: o) { return }
      try? data.write(to: cacheURL, options: .atomic)
      withAnimation(.easeInOut(duration: 0.35)) { _ = boot(data) }
    } catch {
      if sched == nil { status = .error("Нет связи", "Расписание загрузится, когда появится интернет.") }
    }
  }

  // ---------- Заметки и настройки ----------
  func note(_ d: Date, _ l: Lesson) -> String? { canNote(l) ? notes[noteKey(d, l)] : nil }
  func dayHasNote(_ d: Date) -> Bool { let k = key(d); return notes.keys.contains { $0.hasPrefix(k) } }
  func setNote(_ k: String, _ v: String?) {
    let t = v?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if t.isEmpty { notes.removeValue(forKey: k) } else { notes[k] = t }
    saveNotes()
  }
  private func saveNotes() {
    if Shot.on { return }
    if let d = try? JSONSerialization.data(withJSONObject: notes), let s = String(data: d, encoding: .utf8) { ud.set(s, forKey: Store.NKEY) }
  }
  func saveSettings() {
    if Shot.on { return }
    let o = ["ui": ui, "theme": theme]
    if let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) { ud.set(s, forKey: Store.SKEY) }
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
      if let s = o["n"] as? String, let d = s.data(using: .utf8),
         let n = try? JSONSerialization.jsonObject(with: d) as? [String: String] {
        for (k, v) in n where self.notes[k] == nil { self.notes[k] = v }
        self.saveNotes()
      }
      if let s = o["s"] as? String, let d = s.data(using: .utf8),
         let st = try? JSONSerialization.jsonObject(with: d) as? [String: Any], self.ud.string(forKey: Store.SKEY) == nil {
        self.ui = (st["ui"] as? String) == "old" ? "old" : "new"
        let t = st["theme"] as? String ?? "system"
        self.theme = ["dark", "light"].contains(t) ? t : "system"
        self.saveSettings()
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
