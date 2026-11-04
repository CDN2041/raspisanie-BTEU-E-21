import SwiftUI

// Вид эфира: общий для приложения (предпросмотр) и виджета (настоящий эфир)
typealias LiveState = ParyAttributes.ContentState

private func safe(_ a: Date, _ b: Date) -> ClosedRange<Date> { min(a, b)...max(a, b) }
func hhmm(_ d: Date) -> String { fmtMin(nowMin(d)) }

struct LiveTimer: View {
  let st: LiveState
  let stale: Bool
  var body: some View {
    // Устарел: событие, до которого считали, уже прошло. Тогда честно считаем до конца пар.
    let end = stale ? st.dayEnd : st.cd
    Text(timerInterval: safe(Date(), end), countsDown: true).monospacedDigit()
  }
}

struct LiveRoute: View {
  let segs: [ParyAttributes.Seg]
  var labels = true
  var body: some View {
    HStack(alignment: .top, spacing: 4) {
      ForEach(segs, id: \.self) { s in
        VStack(alignment: .leading, spacing: 3) {
          ProgressView(timerInterval: safe(s.a, s.b), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
            .progressViewStyle(.linear).tint(C.fg)
          if labels {
            Text("\(s.p)" + (s.room.isEmpty ? "" : " · " + s.room)).font(.m(10)).foregroundColor(C.muted).lineLimit(1).minimumScaleFactor(0.7)
          }
        }
      }
    }
  }
}

struct LiveCard: View {
  let st: LiveState
  var stale = false
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        Image(systemName: "graduationcap.fill").font(.system(size: 21, weight: .semibold)).foregroundColor(C.fg)
          .frame(width: 46, height: 46)
          .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(C.fg, lineWidth: 2))
        VStack(alignment: .leading, spacing: 1) {
          LiveTimer(st: st, stale: stale).font(.m(30, 700)).foregroundColor(C.fg)
          Text(stale ? "до конца пар" : st.head + (st.room.isEmpty ? "" : " · " + st.room))
            .font(.m(12)).foregroundColor(C.muted).lineLimit(1)
        }
        Spacer(minLength: 0)
      }
      if !stale && !st.subj.isEmpty {
        Text(st.subj).font(.b(15, 600)).foregroundColor(C.fg).lineLimit(1)
      }
      if !st.segs.isEmpty { LiveRoute(segs: st.segs).padding(.top, 2) }
      Text(!stale && !st.next.isEmpty ? "Далее · " + st.next : "Конец в " + hhmm(st.dayEnd))
        .font(.m(11)).foregroundColor(C.muted).lineLimit(1)
    }
    .padding(16)
  }
}

// Части Dynamic Island
struct LiveCompactLeading: View {
  let st: LiveState
  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: "graduationcap.fill").font(.system(size: 13, weight: .semibold))
      if st.p > 0 { Text("\(st.p)").font(.m(14, 700)) }
    }.foregroundColor(.white)
  }
}
struct LiveCompactTrailing: View {
  let st: LiveState
  var stale = false
  var body: some View {
    LiveTimer(st: st, stale: stale).font(.m(14, 700)).foregroundColor(.white)
      .multilineTextAlignment(.trailing).frame(maxWidth: 56)
  }
}
