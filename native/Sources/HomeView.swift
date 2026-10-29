import SwiftUI

// Экран «Сейчас»
struct HomeView: View {
  @EnvironmentObject var store: Store
  @EnvironmentObject var nav: Nav
  @State private var first = true

  var body: some View {
    TimelineView(.everyMinute) { ctx in
      ScrollView {
        if let sc = store.sched {
          content(sc, Shot.now ?? max(ctx.date, store.shown))
            .id(store.rev)
            .padding(.horizontal, 16).padding(.top, 8)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
      }
      .scrollIndicators(.hidden)
      .noBounce()
    }
    .syncSchedule()
    .background(C.bg.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .navigationTitle("Сейчас")
    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { first = false } }
  }

  @ViewBuilder
  func content(_ sc: Sched, _ t: Date) -> some View {
    let td = day0(t), m = nowMin(t)
    let all = sc.lessonsFor(td), list = sc.active(all), its = sc.itemsFor(td), sd = sc.studyDay(t)
    let wk: String = sc.afterEnd(td) ? "" : (sc.inSession(td) || sc.inSession(sd)) ? "сессия"
      : (td != sd ? (weekday(td) == 0 ? "с завтра " : "с понедельника ") : "") + sc.weekName(sd)
    let cur = list.first { m >= $0.a && m < $0.b }
    let next = list.first { $0.a > m }
    let prev = list.last { $0.b <= m }
    let itNext = its.first { $0.m > m }

    VStack(alignment: .leading, spacing: 16) {
      // Дата и настройки
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 2) {
          Eyebrow(text: "Сегодня" + (wk.isEmpty ? "" : " · " + wk))
          Text(DAYS_FULL[weekday(td)] + ", \(dnum(td)) " + MONF[mnum(td)]).font(.b(22, 600)).foregroundColor(C.fg)
        }
        Spacer()
        Button { Haptic.tap(); nav.settings = true } label: {
          Image(systemName: "gearshape").font(.system(size: 19, weight: .medium)).foregroundColor(C.fg).frame(width: 44, height: 44)
            .glass(Circle())
        }.buttonStyle(Press(scale: 0.92))
      }
      .rise(0, first)

      ForEach(all.filter { $0.cancel && $0.b > m }) { l in CancelNote(l: l) }

      if let cur {
        let left = leftOf(cur, m)
        StatePill(text: "Идёт \(cur.p) пара", live: true).rise(1, first)
        LessonHead(l: cur).rise(2, first)
        CountCard(big: dur(left.1), label: left.0.replacingOccurrences(of: "До", with: "до").replacingOccurrences(of: " осталось", with: "").trimmingCharacters(in: .whitespaces)) {
          PairBar(s: cur.a, e: cur.b, m: m, h1: cur.h1, h2: cur.h2, height: 8)
          Times(a: sc.pairTime(cur.p).0, b: sc.pairTime(cur.p).1)
        }.rise(3, first)
        NoteBlock(l: cur, d: td).rise(4, first)
        let rest = all.filter { $0.p > cur.p }
        if !rest.isEmpty {
          VStack(alignment: .leading, spacing: 8) { Section_(title: "Дальше сегодня"); Rows(list: rest, d: td) }.rise(5, first)
        }
      } else if let next {
        let ns = next.a, from = prev?.b
        let label = prev == nil ? "До первой пары" : sc.isBig(prev!, next) ? "Большой перерыв" : next.p - prev!.p > 1 ? "Окно" : "Перерыв"
        StatePill(text: label, live: false).rise(1, first)
        CountCard(big: dur(ns - m), label: "до \(next.p) пары") {
          if let from {
            SimpleBar(f: Double(m - from) / Double(max(1, ns - from)), height: 8)
            Times(a: fmtMin(from), b: sc.pairTime(next.p).0)
          }
        }.rise(2, first)
        Section_(title: "Следующая").rise(3, first)
        LessonHead(l: next).rise(4, first)
        NoteBlock(l: next, d: td).rise(5, first)
        let rest = all.filter { $0.p > next.p }
        if !rest.isEmpty {
          VStack(alignment: .leading, spacing: 8) { Section_(title: "Потом"); Rows(list: rest, d: td) }.rise(6, first)
        }
      } else if let itNext {
        StatePill(text: "Сегодня " + (KINDS[itNext.kind ?? "other"] ?? "").lowercased(), live: false).rise(1, first)
        CountCard(big: dur(itNext.m - m), label: "до начала") { Times(a: "Начало в " + itNext.time, b: "") }.rise(2, first)
        LessonHead(l: itNext).rise(3, first)
        NoteBlock(l: itNext, d: td).rise(4, first)
        let rest = its.filter { $0.m > itNext.m }
        if !rest.isEmpty { VStack(alignment: .leading, spacing: 8) { Section_(title: "Потом"); Rows(list: rest, d: td) }.rise(5, first) }
      } else if let lastIt = its.last {
        StatePill(text: "Сегодня " + (KINDS[lastIt.kind ?? "other"] ?? "").lowercased(), live: true).rise(1, first)
        Section_(title: "Начало было в " + lastIt.time).rise(2, first)
        LessonHead(l: lastIt).rise(3, first)
        NoteBlock(l: lastIt, d: td).rise(4, first)
      } else {
        NextDay(sc: sc, td: td, hadToday: !list.isEmpty).rise(1, first)
      }

      Button { Haptic.tap(); nav.sel = sc.studyDay(t); nav.path.append("full") } label: {
        HStack(spacing: 8) {
          Image(systemName: "calendar").font(.system(size: 17))
          Text("Всё расписание").font(.b(15, 600))
        }
        .foregroundColor(C.fg).frame(maxWidth: .infinity).padding(15)
        .glass(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(Press(scale: 0.98))
      .rise(9, first)

      VersionFooter()
    }
  }
}

// Ближайший день с парами, когда сегодня всё закончилось
struct NextDay: View {
  @EnvironmentObject var store: Store
  let sc: Sched, td: Date, hadToday: Bool
  var body: some View {
    let found: (Date, [Lesson], [Lesson])? = {
      for i in 1...120 {
        let d = addDays(td, i), ll = sc.active(sc.lessonsFor(d)), ii = sc.itemsFor(d)
        if !ll.isEmpty || !ii.isEmpty { return (d, ll, ii) }
      }
      return nil
    }()
    let done = hadToday ? "Пары на сегодня закончились" : sc.inSession(td) ? "Сегодня экзаменов нет"
      : td > sc.endAll ? "Учёба закончилась" : td > sc.last ? "Занятия закончились" : "Сегодня пар нет"
    VStack(alignment: .leading, spacing: 16) {
      Text(done).font(.d(27, 700)).foregroundColor(C.fg).fixedSize(horizontal: false, vertical: true)
      if let f = found {
        let nd = f.0, nl = f.1, ni = f.2
        if let l = nl.first {
          Section_(title: dayLabel(nd, td) + ", первая в " + sc.pairTime(l.p).0)
          ForEach(sc.lessonsFor(nd).filter { $0.cancel }) { c in CancelNote(l: c) }
          LessonHead(l: l)
          NoteBlock(l: l, d: nd)
        } else if let it = ni.first {
          let dd = daysBetween(td, nd)
          if dd > 1 { CountCard(big: "\(dd) " + plural(dd, "день", "дня", "дней"), label: "до " + (KGEN[it.kind ?? "other"] ?? "")) { EmptyView() } }
          Section_(title: dayLabel(nd, td) + ", " + (KINDS[it.kind ?? "other"] ?? "").lowercased() + " в " + it.time)
          LessonHead(l: it)
          NoteBlock(l: it, d: nd)
        }
      }
    }
  }
}
func dayLabel(_ nd: Date, _ td: Date) -> String {
  let dd = daysBetween(td, nd)
  return dd == 1 ? "Завтра" : dd == 2 ? "Послезавтра" : WHEN[weekday(nd)] + ", \(dnum(nd)) " + MONF[mnum(nd)]
}

struct StatePill: View {
  let text: String, live: Bool
  @State private var pulse = false
  var body: some View {
    HStack(spacing: 8) {
      Circle().fill(C.live).frame(width: 8, height: 8).opacity(pulse ? 0.25 : 1)
      Text(text).font(.b(13, 600)).foregroundColor(C.fg)
    }
    .padding(.leading, 10).padding(.trailing, 12).padding(.vertical, 5)
    .overlay(Capsule().strokeBorder(C.line, lineWidth: 1))
    .onAppear {
      guard live else { return }
      withAnimation(.easeInOut(duration: 0.8).repeatCount(6, autoreverses: true)) { pulse = true }
      DispatchQueue.main.asyncAfter(deadline: .now() + 4.9) { withAnimation(.easeOut(duration: 0.3)) { pulse = false } }
    }
  }
}

struct CountCard<Extra: View>: View {
  let big: String, label: String
  @ViewBuilder var extra: () -> Extra
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      FlowRow(spacing: 10) {
        Text(big).font(.m(52, 700)).tracking(-1).monospacedDigit().foregroundColor(C.fg)
        Text(label).font(.b(15)).foregroundColor(C.muted).padding(.top, 26)
      }
      extra()
    }
    .padding(18).frame(maxWidth: .infinity, alignment: .leading).card(20)
  }
}

struct SimpleBar: View {
  let f: Double
  var height: CGFloat = 4
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(C.line)
        Capsule().fill(C.live).frame(width: g.size.width * CGFloat(max(0, min(1, f))))
      }
    }
    .frame(height: height)
    .animation(.spring(response: 1, dampingFraction: 0.9), value: f)
  }
}

struct Times: View {
  let a: String, b: String
  var body: some View {
    HStack { Text(a); Spacer(); Text(b) }.font(.m(13)).foregroundColor(C.muted)
  }
}
