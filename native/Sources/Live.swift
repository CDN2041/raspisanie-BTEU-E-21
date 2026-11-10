import ActivityKit
import BackgroundTasks
import Foundation

// Эфир активности: запуск, обновление на границах пар, завершение после последней пары.
// Сервера с пушами нет, поэтому обновляет само приложение: при открытии и в фоне, когда iOS даёт время.
@MainActor
enum Live {
  static let bgID = "by.cdn2041.pary.live"
  static var auto: Bool {
    get { Shared.store.object(forKey: "pary-e21-live") as? Bool ?? true }
    set { Shared.store.set(newValue, forKey: "pary-e21-live") }
  }
  static var allowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

  enum Result { case shown, noPairs, off }

  // force: показать снова, даже если сегодня эфир уже смахнули
  @discardableResult
  static func sync(_ sc: Sched?, force: Bool = false) async -> Result {
    guard !Shot.on, let sc else { return .off }
    let now = Date(), dk = key(day0(now))
    let alive = Activity<ParyAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
    guard let st = liveContent(sc, now) else {
      for a in alive { await a.end(nil, dismissalPolicy: .immediate) }
      return .noPairs
    }
    let content = ActivityContent(state: st, staleDate: st.cd)
    if let a = alive.first(where: { $0.attributes.day == dk }) {
      await a.update(content)
      for o in alive where o.id != a.id { await o.end(nil, dismissalPolicy: .immediate) }
      schedule(st.cd)
      return .shown
    }
    for o in alive { await o.end(nil, dismissalPolicy: .immediate) }
    // Сам эфир включается раз в день; если его смахнули, вернуть можно кнопкой в настройках
    guard force || (auto && Shared.store.string(forKey: "live-day") != dk) else { return .off }
    guard allowed else { return .off }
    do {
      _ = try Activity.request(attributes: ParyAttributes(day: dk), content: content, pushType: nil)
      Shared.store.set(dk, forKey: "live-day")
      schedule(st.cd)
      return .shown
    } catch { return .off }
  }

  static func stop() async {
    for a in Activity<ParyAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
  }

  // Фоновое обновление на следующей границе: начало, перерыв или конец пары
  static func register() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: bgID, using: nil) { task in
      let job = Task { @MainActor in
        let sc = Shared.parse(Shared.readSchedule()).flatMap { Sched($0, p2: Shared.p2, noFive: Shared.noFive) }
        await sync(sc)
        task.setTaskCompleted(success: true)
      }
      task.expirationHandler = { job.cancel() }
    }
  }
  static func schedule(_ at: Date) {
    let r = BGAppRefreshTaskRequest(identifier: bgID)
    r.earliestBeginDate = at.addingTimeInterval(1)
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: bgID)
    try? BGTaskScheduler.shared.submit(r)
  }
}
