import SwiftUI

// Полное расписание: неделя сверху, дни листаются пальцем
struct FullView: View {
  let root: Bool
  @EnvironmentObject var store: Store
  @EnvironmentObject var nav: Nav
  @Namespace private var ns

  var body: some View {
    Group {
      if let sc = store.sched {
        TimelineView(.everyMinute) { ctx in
          let t = Shot.now ?? max(ctx.date, store.shown)
          VStack(spacing: 0) {
            VStack(spacing: 16) {
              topBar
              header(sc, t)
              weekNav(sc)
              strip(sc, t)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            pager(sc, t)
          }
        }
        .onAppear { nav.sel = sc.clamp(nav.sel) }
        .onChange(of: store.rev) { _ in if let s = store.sched { nav.sel = s.clamp(nav.sel) } }
      }
    }
    .background(C.bg.ignoresSafeArea())
    // Своя верхняя строка вместо системной: системная на iOS 26 после перехода оставляла пустоту сверху
    .toolbar(.hidden, for: .navigationBar)
    .syncSchedule()
    .onChange(of: nav.sel) { _ in Haptic.pick() }
  }

  // ---------- Шапка ----------
  var topBar: some View {
    HStack {
      if !root {
        Button { Haptic.tap(); nav.path.removeLast() } label: {
          Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundColor(C.fg)
            .frame(width: 44, height: 44).glass(Circle())
        }.buttonStyle(Press(scale: 0.92))
      }
      Spacer()
      Button { Haptic.tap(); nav.settings = true } label: {
        Image(systemName: "gearshape").font(.system(size: 19, weight: .medium)).foregroundColor(C.fg)
          .frame(width: 44, height: 44).glass(Circle())
      }.buttonStyle(Press(scale: 0.92))
    }
    .padding(.top, 4)
  }

  func header(_ sc: Sched, _ t: Date) -> some View {
    let sel = nav.sel, mon = mondayOf(sel)
    let n = weeksBetween(sc.studyDay(t), sel)
    let rel = n == 0 ? "эта неделя" : n == 1 ? "следующая неделя" : n == -1 ? "прошлая неделя" : n > 1 ? "через \(n) нед." : "\(-n) нед. назад"
    let title = sc.weekInSession(mon) ? "Сессия" : sc.weekType(sel) == "over" ? "Над чертой" : "Под чертой"
    return HStack(alignment: .bottom, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Eyebrow(text: rel)
        Text(title).font(.d(28, 700)).foregroundColor(C.fg)
          .id(title).transition(.opacity.combined(with: .offset(y: 6)))
      }
      .animation(.spring(response: 0.45, dampingFraction: 0.85), value: title)
      Spacer()
      Button { Haptic.tap(); nav.calendar = true } label: {
        Image(systemName: "calendar").font(.system(size: 24)).foregroundColor(C.fg)
          .frame(width: 64, height: 52).glass(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }.buttonStyle(Press(scale: 0.95))
    }
  }

  func weekNav(_ sc: Sched) -> some View {
    let mon = mondayOf(nav.sel), nd = shownDays(sc, mon)
    let prevOff = sc.beforeStart(addDays(mon, -1)), nextOff = sc.afterEnd(addDays(mon, 7))
    return HStack(spacing: 4) {
      Button { go(sc, addDays(mon, -7)) } label: {
        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)).frame(width: 40, height: 40).glass(Circle())
      }.buttonStyle(Press(scale: 0.92)).foregroundColor(C.fg).opacity(prevOff ? 0.25 : 1).disabled(prevOff)
      Text(range(mon, nd)).font(.b(15, 600)).monospacedDigit().foregroundColor(C.fg)
        .lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity)
        .id(key(mon)).transition(.opacity)
      Button { go(sc, addDays(mon, 7)) } label: {
        Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold)).frame(width: 40, height: 40).glass(Circle())
      }.buttonStyle(Press(scale: 0.92)).foregroundColor(C.fg).opacity(nextOff ? 0.25 : 1).disabled(nextOff)
      Button {
        Haptic.tap()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { nav.sel = sc.clamp(sc.studyDay(store.now)) }
      } label: {
        Text("Сегодня").font(.b(15, 600)).foregroundColor(C.fg).padding(.horizontal, 16).frame(height: 40).glass(Capsule())
      }.buttonStyle(Press(scale: 0.95))
    }
  }
  // Листаем на первый день недели
  func go(_ sc: Sched, _ mon: Date) {
    Haptic.tap()
    withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { nav.sel = sc.clamp(mon) }
  }
  func shownDays(_ sc: Sched, _ mon: Date) -> Int { min(sc.daysIn(mon), max(1, daysBetween(mon, sc.endAll) + 1)) }
  func range(_ mon: Date, _ n: Int) -> String {
    let e = addDays(mon, n - 1)
    return mnum(mon) == mnum(e) ? "\(dnum(mon))-\(dnum(e)) " + MONF[mnum(mon)] : "\(dnum(mon)) " + MON[mnum(mon)] + " - \(dnum(e)) " + MON[mnum(e)]
  }

  // Дни недели: стеклянная полоса, зажать и вести пальцем, как панель вкладок в Apple Music
  func strip(_ sc: Sched, _ t: Date) -> some View {
    let mon = mondayOf(nav.sel), nd = shownDays(sc, mon), today = day0(t)
    let idx = max(0, min(nd - 1, daysBetween(mon, nav.sel)))
    return Lens(count: nd, index: idx, height: 58, radius: 18,
                fill: { store.dayHasNote(addDays(mon, $0)) ? C.note : C.fg },
                disabled: { sc.beforeStart(addDays(mon, $0)) },
                onPick: { i in withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { nav.sel = addDays(mon, i) } }) { i, sel in
      let d = addDays(mon, i)
      let c = sc.active(sc.lessonsFor(d)).count, its = sc.itemsFor(d)
      let lbl = c > 0 ? "\(c) п." : !its.isEmpty ? (KSHORT[its[0].kind ?? "other"] ?? "") : "·"
      let isToday = d == today, hn = store.dayHasNote(d)
      VStack(spacing: 1) {
        Text(DSHORT[i]).font(.b(12, 600)).foregroundColor(sel ? C.bg.opacity(0.75) : (hn ? C.note : (isToday ? C.fg : C.muted)))
        Text("\(dnum(d))").font(.m(17, 700)).monospacedDigit().foregroundColor(sel ? C.bg : (hn ? C.note : C.fg.opacity(isToday ? 1 : 0.8)))
          .underline(isToday && !sel)
        Text(lbl).font(.b(11)).monospacedDigit().foregroundColor(sel ? C.bg.opacity(0.75) : (hn ? C.note : C.muted))
      }
      .background { if hn && !sel { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.noteSoft).frame(width: 46, height: 56) } }
    }
    .padding(3)
    .glass(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  // ---------- Дни ----------
  func pager(_ sc: Sched, _ t: Date) -> some View {
    TabView(selection: $nav.sel) {
      ForEach(sc.allDays, id: \.self) { d in
        ScrollView {
          DayList(sc: sc, d: d, t: t)
            .padding(.horizontal, 16).padding(.top, 4)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
          if root { VersionFooter() }
        }
        .scrollIndicators(.hidden)
        .noBounce()
        .tag(d)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .id(store.rev)
  }
}

struct DayList: View {
  @EnvironmentObject var store: Store
  let sc: Sched, d: Date, t: Date
  var body: some View {
    let today = day0(t), m = nowMin(t)
    let list = sc.lessonsFor(d), its = sc.itemsFor(d)
    let cmp = d < today ? -1 : d > today ? 1 : 0
    VStack(spacing: 10) {
      if list.isEmpty && its.isEmpty {
        VStack(spacing: 4) {
          Text(sc.inSession(d) ? "Экзаменов нет" : "Пар нет").font(.d(18, 500)).foregroundColor(C.fg)
          Text(DAYS_FULL[weekday(d)] + ", \(dnum(d)) " + MONF[mnum(d)]).font(.b(15)).foregroundColor(C.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 12).card(16)
      } else {
        ForEach(Array(list.enumerated()), id: \.element.id) { i, l in
          if i > 0 {
            let p = list[i - 1]
            GapView(kind: l.p - p.p > 1 ? .window : sc.isBig(p, l) ? .big : .small, gs: p.b, ge: l.a, m: m, cmp: cmp)
          }
          LessonCard(l: l, d: d, cmp: cmp, m: m)
        }
        ForEach(its) { it in ItemCard(l: it, d: d, cmp: cmp) }
      }
    }
    .padding(.bottom, 24)
  }
}
