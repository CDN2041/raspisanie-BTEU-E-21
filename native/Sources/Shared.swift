import Foundation

// Общая папка приложения и виджета (App Group).
// При подписи через Sideloadly группа может получить другое имя, поэтому настоящее имя читаем из своей подписи.
enum Shared {
  static let fallbackID = "group.by.cdn2041.pary"
  static let groupID: String = {
    guard let u = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let d = try? Data(contentsOf: u), let s = String(data: d, encoding: .isoLatin1),
          let a = s.range(of: "<?xml"), let b = s.range(of: "</plist>"),
          let x = String(s[a.lowerBound..<b.upperBound]).data(using: .isoLatin1),
          let p = try? PropertyListSerialization.propertyList(from: x, format: nil) as? [String: Any],
          let e = p["Entitlements"] as? [String: Any],
          let g = (e["com.apple.security.application-groups"] as? [String])?.first else { return fallbackID }
    return g
  }()
  static let dir: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
  static let defaults: UserDefaults? = dir != nil ? UserDefaults(suiteName: groupID) : nil
  static var available: Bool { dir != nil }

  // Своя папка: если общей нет, у приложения и виджета будет по копии расписания
  static let ownDir: URL = {
    let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
  }()
  static var scheduleURL: URL { (dir ?? ownDir).appendingPathComponent("schedule.json") }

  static func readSchedule() -> Data? {
    if let d = try? Data(contentsOf: scheduleURL) { return d }
    if let d = try? Data(contentsOf: ownDir.appendingPathComponent("schedule.json")) { return d }
    if let u = Bundle.main.url(forResource: "schedule", withExtension: "json") { return try? Data(contentsOf: u) }
    return nil
  }
  static func writeSchedule(_ d: Data) {
    try? d.write(to: scheduleURL, options: .atomic)
    if dir != nil { try? d.write(to: ownDir.appendingPathComponent("schedule.json"), options: .atomic) }
  }

  // Флаги и заметки: в общей папке, если она есть
  static var store: UserDefaults { defaults ?? .standard }
  static var p2: Bool { store.string(forKey: "pary-e21-p2") == "1" }
  static var noFive: Bool { store.string(forKey: "pary-e21-nofive") == "1" }
  static func notes() -> [String: String] {
    guard let s = store.string(forKey: "pary-notes-v1"), let d = s.data(using: .utf8),
          let o = try? JSONSerialization.jsonObject(with: d) as? [String: String] else { return [:] }
    return o
  }

  static func parse(_ data: Data?) -> [String: Any]? {
    guard let data, let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], Sched.valid(o) else { return nil }
    return o
  }
}
