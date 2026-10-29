import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
  let date: Date
  let st: WState
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry { Entry(date: Date(), st: .placeholder) }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    if context.isPreview { return completion(placeholder(in: context)) }
    let now = Date()
    completion(Entry(date: now, st: load().map { widgetState($0, now) } ?? .placeholder))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    Task {
      await refresh()
      let now = Date()
      guard let sc = load() else {
        return completion(Timeline(entries: [Entry(date: now, st: .placeholder)], policy: .after(now.addingTimeInterval(1800))))
      }
      let times = widgetTimes(sc, from: now)
      let entries = times.map { Entry(date: $0, st: widgetState(sc, $0)) }
      // Пары кончились: следующее обновление в полночь, иначе после последней минуты
      let midnight = addDays(now, 1)
      let next = times.count > 1 ? min(times.last!.addingTimeInterval(60), midnight) : min(midnight, now.addingTimeInterval(3 * 3600))
      completion(Timeline(entries: entries, policy: .after(next)))
    }
  }

  private func load() -> Sched? {
    guard let o = Shared.parse(Shared.readSchedule()) else { return nil }
    return Sched(o, p2: Shared.p2, noFive: Shared.noFive)
  }

  // Свежее расписание с сайта, не чаще раза в полчаса
  private func refresh() async {
    let k = "widget-fetch"
    if Date().timeIntervalSince1970 - Shared.store.double(forKey: k) < 1800 { return }
    var req = URLRequest(url: URL(string: "https://cdn2041.github.io/raspisanie-BTEU-E-21/schedule.json")!,
                         cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
    req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    guard let res = try? await URLSession.shared.data(for: req), (res.1 as? HTTPURLResponse)?.statusCode == 200,
          Shared.parse(res.0) != nil else { return }
    Shared.writeSchedule(res.0)
    Shared.store.set(Date().timeIntervalSince1970, forKey: k)
  }
}

extension View {
  @ViewBuilder func widgetBG(_ accessory: Bool = false) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) { accessory ? Color.clear : C.surface }
    } else {
      if accessory { self } else { padding(14).frame(maxWidth: .infinity, maxHeight: .infinity).background(C.surface) }
    }
  }
}

struct NowView: View {
  @Environment(\.widgetFamily) private var family
  let e: Entry
  var body: some View {
    Group {
      switch family {
      case .systemMedium: WMedium(st: e.st)
      case .accessoryRectangular: WRect(st: e.st)
      case .accessoryCircular: WCirc(st: e.st)
      case .accessoryInline: WInline(st: e.st)
      default: WSmall(st: e.st)
      }
    }
    .widgetBG([.accessoryRectangular, .accessoryCircular, .accessoryInline].contains(family))
    .widgetURL(URL(string: "pary://now"))
  }
}

struct NowWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "now", provider: Provider()) { NowView(e: $0) }
      .configurationDisplayName("Сейчас")
      .description("Текущая пара, сколько осталось и следующая пара.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct LockWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "lock", provider: Provider()) { NowView(e: $0) }
      .configurationDisplayName("Пара")
      .description("Пара и минуты до конца на экране блокировки.")
      .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}

@main
struct ParyWidgets: WidgetBundle {
  init() { Fonts.load() }
  var body: some Widget {
    NowWidget()
    LockWidget()
  }
}
