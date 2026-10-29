import SwiftUI
import WebKit

extension View {
  // Системная шторка в цветах сайта
  @ViewBuilder func sheetLook(_ detents: Set<PresentationDetent>) -> some View {
    let v = self.presentationDetents(detents).presentationDragIndicator(.visible)
    if #available(iOS 16.4, *) {
      v.presentationBackground(C.surface).presentationCornerRadius(28)
    } else {
      v.background(C.surface.ignoresSafeArea())
    }
  }
}

// ---------- Настройки ----------
struct SettingsSheet: View {
  @EnvironmentObject var store: Store
  @EnvironmentObject var nav: Nav
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Настройки").font(.d(19, 500)).foregroundColor(C.fg)
      VStack(alignment: .leading, spacing: 8) {
        Eyebrow(text: "При открытии")
        Seg(items: [("new", "Экран «Сейчас»"), ("old", "Всё расписание")], value: Binding(get: { store.ui }, set: { v in
          store.ui = v; store.saveSettings()
          if v == "old" { nav.path = [] }
        }))
      }
      VStack(alignment: .leading, spacing: 8) {
        Eyebrow(text: "Тема")
        Seg(items: [("system", "Как в системе"), ("dark", "Тёмная"), ("light", "Светлая")], value: Binding(get: { store.theme }, set: { v in
          store.theme = v; store.saveSettings()
        }))
      }
      Spacer(minLength: 0)
      HStack(spacing: 10) {
        Btn(title: "Редактор") {
          dismiss()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nav.editor = true }
        }
        Btn(title: "Готово", kind: .primary) { dismiss() }
      }
    }
    .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 12)
    .sheetLook([.height(330)])
  }
}

// ---------- Заметка ----------
struct NoteSheet: View {
  @EnvironmentObject var store: Store
  @Environment(\.dismiss) private var dismiss
  let ref: NoteRef
  @State private var text = ""
  @State private var ask = false
  @FocusState private var focus: Bool
  var body: some View {
    let had = store.notes[ref.key] != nil
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text(ref.title).font(.d(19, 500)).foregroundColor(C.fg).fixedSize(horizontal: false, vertical: true)
        Text(DAYS_FULL[weekday(ref.day)] + ", \(dnum(ref.day)) " + MONF[mnum(ref.day)] + ", " + ref.label).font(.b(14)).foregroundColor(C.muted)
      }
      ZStack(alignment: .topLeading) {
        if text.isEmpty {
          Text("Например: сдать реферат, взять методичку").font(.b(16)).foregroundColor(C.muted.opacity(0.7))
            .padding(.horizontal, 17).padding(.vertical, 20).allowsHitTesting(false)
        }
        TextEditor(text: $text)
          .font(.b(16)).foregroundColor(C.fg)
          .scrollContentBackground(.hidden)
          .padding(8)
          .focused($focus)
      }
      .frame(minHeight: 140, maxHeight: .infinity)
      .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.bg))
      .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(C.line, lineWidth: 1))
      HStack(spacing: 10) {
        if had { Btn(title: "Удалить", kind: .del) { Haptic.warn(); ask = true } }
        Btn(title: "Отмена") { dismiss() }
        Btn(title: "Сохранить", kind: .primary) {
          store.setNote(ref.key, text)
          Haptic.ok()
          dismiss()
        }
      }
    }
    .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 12)
    .sheetLook([.medium, .large])
    .onAppear {
      text = store.notes[ref.key] ?? ""
      if text.isEmpty && !Shot.on { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = true } }
    }
    .alert("Удалить заметку?", isPresented: $ask) {
      Button("Отмена", role: .cancel) {}
      Button("Удалить", role: .destructive) { store.setNote(ref.key, nil); dismiss() }
    } message: { Text("Восстановить её будет нельзя.") }
  }
}

// ---------- Выбор недели ----------
struct CalendarSheet: View {
  @EnvironmentObject var store: Store
  @EnvironmentObject var nav: Nav
  @Environment(\.dismiss) private var dismiss
  @State private var month = Date()
  @State private var dir = 0
  @State private var flash = 0

  var body: some View {
    Group {
      if let sc = store.sched {
        let lastM = monthStart(sc.endAll), firstM = sc.first.map { monthStart($0) }
        VStack(spacing: 14) {
          HStack {
            Text(MONN[mnum(month)] + " \(ynum(month))").font(.d(19, 500)).foregroundColor(C.fg)
              .id(key(month)).transition(.opacity)
            Spacer()
            HStack(spacing: 4) {
              navBtn("chevron.left", off: firstM != nil && month <= firstM!) { goMonth(sc, addMonths(month, -1)) }
              navBtn("chevron.right", off: month >= lastM) { goMonth(sc, addMonths(month, 1)) }
            }
          }
          grid(sc).id(key(month))
            .transition(.asymmetric(insertion: .offset(x: dir > 0 ? 24 : dir < 0 ? -24 : 0).combined(with: .opacity), removal: .opacity))
          HStack(spacing: 10) {
            Btn(title: "Эта неделя") {
              let sd = sc.clamp(sc.studyDay(store.now))
              withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                nav.sel = sd
                if monthStart(sd) != month { dir = sd > month ? 1 : -1; month = monthClamp(sc, sd) } else { flash += 1 }
              }
            }
            Btn(title: "Закрыть") { dismiss() }
          }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { month = monthClamp(sc, nav.sel) }
      }
    }
    .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 12)
    .sheetLook([.height(500)])
  }

  func monthClamp(_ sc: Sched, _ d: Date) -> Date {
    let n = monthStart(d), lastM = monthStart(sc.endAll)
    if n > lastM { return lastM }
    if let f = sc.first, n < monthStart(f) { return monthStart(f) }
    return n
  }
  func goMonth(_ sc: Sched, _ d: Date) {
    Haptic.tap()
    let n = monthClamp(sc, d)
    dir = n > month ? 1 : n < month ? -1 : 0
    withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { month = n }
  }
  func navBtn(_ icon: String, off: Bool, _ a: @escaping () -> Void) -> some View {
    Button(action: a) {
      Image(systemName: icon).font(.system(size: 17, weight: .semibold)).frame(width: 36, height: 36)
    }.buttonStyle(Press(scale: 0.85)).foregroundColor(C.muted).opacity(off ? 0.25 : 1).disabled(off)
  }

  func grid(_ sc: Sched) -> some View {
    let today = day0(store.now), first = monthStart(month), sm = mondayOf(nav.sel)
    let hdr = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    return VStack(spacing: 4) {
      HStack(spacing: 0) {
        ForEach(hdr, id: \.self) { Text($0).font(.b(11, 600)).foregroundColor(C.muted).frame(maxWidth: .infinity) }
        Color.clear.frame(width: 34, height: 1)
      }
      ForEach(0..<6, id: \.self) { r in
        let m = addDays(mondayOf(first), r * 7)
        HStack(spacing: 0) {
          ForEach(0..<7, id: \.self) { i in
            let d = addDays(m, i)
            dayCell(sc, d, first: first, today: today, sun: i == 6)
          }
          Button {
            let sd = sc.studyDay(store.now)
            pick(sc, mondayOf(sd) == m ? sd : sc.studyDay(m))
          } label: {
            WeekGlyph(over: sc.weekType(m) == "over").frame(width: 22, height: 22).foregroundColor(C.muted).frame(width: 34, height: 44)
          }
          .buttonStyle(Press(scale: 0.85))
          .opacity(sc.afterEnd(m) || sc.beforeStart(addDays(m, 6)) ? 0.2 : 1)
          .disabled(sc.afterEnd(m) || sc.beforeStart(addDays(m, 6)))
        }
        .background {
          if m == sm { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.bg).id(flash) .transition(.opacity) }
        }
      }
    }
  }
  func dayCell(_ sc: Sched, _ d: Date, first: Date, today: Date, sun: Bool) -> some View {
    let off = sc.afterEnd(d) || sc.beforeStart(d), other = mnum(d) != mnum(first)
    let isT = d == today, isS = d == nav.sel, hn = store.dayHasNote(d), hasX = !sc.itemsFor(d).isEmpty
    return Button { pick(sc, sc.studyDay(d)) } label: {
      Text("\(dnum(d))").font(.m(15, isT ? 700 : 500)).monospacedDigit()
        .foregroundColor(isT ? C.bg : other ? C.fg.opacity(0.3) : sun ? C.muted : C.fg)
        .frame(width: 36, height: 36)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(isT ? C.fg : .clear))
        .overlay {
          if isS && !isT { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(C.fg, lineWidth: 1.5) }
          else if hasX && !isS && !isT { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(C.muted, lineWidth: 1.5) }
        }
        .overlay(alignment: .bottom) { if hn { Circle().fill(C.note).frame(width: 4, height: 4).padding(.bottom, 3) } }
        .frame(maxWidth: .infinity).frame(height: 44)
    }
    .buttonStyle(Press(scale: 0.88))
    .opacity(off ? 0.2 : 1).disabled(off)
  }
  func pick(_ sc: Sched, _ d: Date) {
    if sc.afterEnd(d) { return }
    Haptic.tap()
    nav.sel = sc.clamp(d)
    dismiss()
  }
}

// ---------- Редактор: та же страница сайта, внутри приложения ----------
struct EditorView: View {
  @EnvironmentObject var store: Store
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    EditorWeb(onClose: { nf in
      if let nf { store.setNoFive(nf) }
      dismiss()
    })
    .ignoresSafeArea()
    .background(C.bg.ignoresSafeArea())
  }
}

struct EditorWeb: UIViewRepresentable {
  let onClose: (Bool?) -> Void
  func makeCoordinator() -> Co { Co(onClose) }
  func makeUIView(context: Context) -> WKWebView {
    let c = WKWebViewConfiguration()
    c.websiteDataStore = .default()
    let w = WKWebView(frame: .zero, configuration: c)
    w.isOpaque = false
    w.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x050608) : UIColor(hex: 0xEDEFF3) }
    w.scrollView.contentInsetAdjustmentBehavior = .never
    w.allowsLinkPreview = false
    w.navigationDelegate = context.coordinator
    w.load(URLRequest(url: SITE.appendingPathComponent("admin.html")))
    return w
  }
  func updateUIView(_ v: WKWebView, context: Context) {}

  final class Co: NSObject, WKNavigationDelegate {
    let onClose: (Bool?) -> Void
    init(_ c: @escaping (Bool?) -> Void) { onClose = c }
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler h: @escaping (WKNavigationActionPolicy) -> Void) {
      guard let u = a.request.url else { return h(.allow) }
      let s = u.absoluteString
      // «К расписанию» в редакторе: закрываем его и возвращаемся в приложение
      if s.hasPrefix(SITE.absoluteString) && !s.contains("admin.html") && a.navigationType == .linkActivated || s == SITE.absoluteString || s.hasSuffix("/index.html") {
        h(.cancel)
        w.evaluateJavaScript("localStorage.getItem('pary-e21-nofive')") { r, _ in
          DispatchQueue.main.async { self.onClose((r as? String) == "1") }
        }
        return
      }
      if !s.hasPrefix(SITE.absoluteString) && a.navigationType == .linkActivated {
        UIApplication.shared.open(u); return h(.cancel)
      }
      h(.allow)
    }
    // Без интернета редактор не открыть: возвращаемся в приложение
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) {
      DispatchQueue.main.async { self.onClose(nil) }
    }
  }
}
