import SwiftUI

// Виджеты: весь текст моноширинным шрифтом, как время
struct WBar: View {
  let f: Double
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(C.line)
        Capsule().fill(C.fg).frame(width: g.size.width * CGFloat(max(0, min(1, f))))
      }
    }.frame(height: 5)
  }
}

struct WDone: View {
  let st: WState
  var size: CGFloat = 19
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(st.big).font(.m(size, 700)).foregroundColor(C.fg).fixedSize(horizontal: false, vertical: true)
      Text(st.date).font(.m(11)).foregroundColor(C.muted)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

struct WSmall: View {
  let st: WState
  var body: some View {
    if st.kind == .done { WDone(st: st) } else {
      VStack(alignment: .leading, spacing: 0) {
        Text(st.head).font(.m(11)).foregroundColor(C.muted).lineLimit(1).minimumScaleFactor(0.8)
        Text(st.big).font(.m(32, 700)).foregroundColor(C.fg).lineLimit(1).minimumScaleFactor(0.5).padding(.top, 4)
        if let f = st.frac { WBar(f: f).padding(.top, 8) }
        HStack(spacing: 6) {
          Text(st.subj).foregroundColor(C.muted).lineLimit(1)
          Spacer(minLength: 0)
          Text(st.room).foregroundColor(C.fg)
        }.font(.m(11)).padding(.top, 6)
        Spacer(minLength: 4)
        bottom
      }
    }
  }
  @ViewBuilder var bottom: some View {
    if let n = st.next {
      VStack(alignment: .leading, spacing: 2) {
        HStack { Text(n.time).foregroundColor(C.muted); Spacer(); Text(n.room).foregroundColor(C.fg) }
        Text(n.subj).foregroundColor(C.fg).lineLimit(1)
      }
      .font(.m(11)).padding(.top, 7)
      .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
    } else if st.last {
      Text("Последняя на сегодня").font(.m(11)).foregroundColor(C.muted).lineLimit(1).minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 7)
        .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
    }
  }
}

struct WMedium: View {
  let st: WState
  var body: some View {
    if st.kind == .done { WDone(st: st, size: 22) } else {
      VStack(alignment: .leading, spacing: 8) {
        HStack { Text(st.head).lineLimit(1); Spacer(); Text(st.range) }.font(.m(11)).foregroundColor(C.muted)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text(st.big).font(.m(32, 700)).foregroundColor(C.fg).lineLimit(1).fixedSize()
          Text(st.subj).font(.m(12)).foregroundColor(C.fg).lineLimit(1)
          Spacer(minLength: 0)
          Text(st.room).font(.m(12)).foregroundColor(C.fg)
        }
        if let f = st.frac { WBar(f: f) }
        Spacer(minLength: 0)
        if let n = st.next {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(n.time).foregroundColor(C.muted).frame(width: 44, alignment: .leading)
            Text(n.subj).foregroundColor(C.fg).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(n.room).foregroundColor(C.fg).frame(width: 44, alignment: .trailing)
          }
          .font(.m(12)).padding(.top, 8)
          .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
        } else if st.last {
          Text("Последняя на сегодня").font(.m(12)).foregroundColor(C.muted)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
        }
      }
    }
  }
}

// ---------- Экран блокировки ----------
struct WRect: View {
  let st: WState
  var body: some View {
    if st.kind != .done {
      VStack(alignment: .leading, spacing: 1) {
        Text(st.head.components(separatedBy: " · ").first.map { $0 + " · " + st.big } ?? st.big).font(.m(13, 700)).lineLimit(1)
        Text(st.subj + (st.room.isEmpty ? "" : " · " + st.room)).font(.m(12)).lineLimit(1)
        if let n = st.next { Text(n.time + " " + n.subj).font(.m(12)).lineLimit(1).opacity(0.75) }
        else if st.last { Text("Последняя на сегодня").font(.m(12)).opacity(0.75) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct WCirc: View {
  let st: WState
  var body: some View {
    if st.kind != .done {
      Gauge(value: st.frac ?? 0) {
        Text("мин")
      } currentValueLabel: {
        Text(st.mins >= 100 ? "\(st.mins / 60)ч" : "\(st.mins)").font(.m(15, 700))
      }
      .gaugeStyle(.accessoryCircular)
    }
  }
}

struct WInline: View {
  let st: WState
  var body: some View { Text(st.kind == .done ? "" : st.inline) }
}
