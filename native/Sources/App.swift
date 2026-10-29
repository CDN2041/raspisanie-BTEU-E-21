import SwiftUI
import UIKit

struct NoteRef: Identifiable {
  let key: String, title: String, label: String, day: Date
  var id: String { key }
}

@MainActor
final class Nav: ObservableObject {
  @Published var path: [String] = []
  @Published var settings = false
  @Published var calendar = false
  @Published var editor = false
  @Published var note: NoteRef? = nil
  @Published var sel: Date = day0(Shot.now ?? Date())

  func openNote(_ d: Date, _ l: Lesson) {
    Haptic.tap()
    note = NoteRef(key: noteKey(d, l), title: l.s, label: l.kind != nil ? (KINDS[l.kind!] ?? "") + " в " + l.time : "\(l.p) пара", day: d)
  }
}

@main
struct ParyApp: App {
  @StateObject private var store = Store()
  @StateObject private var nav = Nav()
  init() { Fonts.load() }
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(store).environmentObject(nav)
    }
  }
}

struct RootView: View {
  @EnvironmentObject var store: Store
  @EnvironmentObject var nav: Nav
  @Environment(\.scenePhase) private var phase

  var body: some View {
    NavigationStack(path: $nav.path) {
      Group {
        if Shot.screen == "widgets" { WidgetGallery() }
        else if store.sched == nil { MessageView() }
        else if store.ui == "old" { FullView(root: true) }
        else { HomeView() }
      }
      .navigationDestination(for: String.self) { _ in FullView(root: false) }
    }
    .tint(C.fg)
    .preferredColorScheme(store.colorScheme)
    .sheet(isPresented: $nav.settings) {
      SettingsSheet().environmentObject(store).environmentObject(nav).preferredColorScheme(store.colorScheme).id(store.theme)
    }
    .sheet(item: $nav.note) { r in
      NoteSheet(ref: r).environmentObject(store).environmentObject(nav).preferredColorScheme(store.colorScheme).id(store.theme)
    }
    .sheet(isPresented: $nav.calendar) {
      CalendarSheet().environmentObject(store).environmentObject(nav).preferredColorScheme(store.colorScheme).id(store.theme)
    }
    .fullScreenCover(isPresented: $nav.editor, onDismiss: { Task { await store.fetch(force: true) } }) {
      EditorRoot().environmentObject(store).environmentObject(nav).preferredColorScheme(store.colorScheme)
    }
    .task {
      shotSetup()
      store.migrate()
      await store.fetch(force: true)
    }
    .onOpenURL { _ in nav.path = []; nav.note = nil; nav.settings = false; nav.calendar = false }
    .onChange(of: phase) { p in
      if p == .active { store.touch(); Task { await store.fetch() } }
    }
  }

  private func shotSetup() {
    guard let s = Shot.screen, let sc = store.sched else { return }
    nav.sel = sc.clamp(store.now)
    switch s {
    case "full": nav.path = ["full"]
    case "cal": nav.path = ["full"]; DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { nav.calendar = true }
    case "settings": DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { nav.settings = true }
    case "editor": DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { nav.editor = true }
    case "note":
      let d = day0(store.now)
      if let l = sc.lessonsFor(d).first(where: { canNote($0) }) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { nav.openNote(d, l) }
      }
    default: break
    }
  }
}

struct MessageView: View {
  @EnvironmentObject var store: Store
  var body: some View {
    VStack(spacing: 16) {
      Spacer()
      VStack(spacing: 4) {
        switch store.status {
        case .error(let t, let x):
          Text(t).font(.d(18, 500)).foregroundColor(C.fg)
          Text(x).font(.b(15)).foregroundColor(C.muted).multilineTextAlignment(.center)
        default:
          ProgressView().padding(.bottom, 8)
          Text("Получаем расписание").font(.b(15)).foregroundColor(C.muted)
        }
      }
      .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 12).card()
      if case .error = store.status {
        Button { Haptic.tap(); Task { await store.fetch(force: true) } } label: {
          Text("Повторить").font(.b(15, 600)).frame(maxWidth: .infinity).padding(14).card(14)
        }.buttonStyle(Press())
      }
      Spacer()
    }
    .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity).background(C.bg.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }
}

// Свайп назад от края экрана работает и со скрытой системной шапкой
extension UINavigationController: UIGestureRecognizerDelegate {
  override open func viewDidLoad() {
    super.viewDidLoad()
    interactivePopGestureRecognizer?.delegate = self
  }
  public func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool { viewControllers.count > 1 }
}
