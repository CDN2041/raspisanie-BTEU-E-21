import SwiftUI

// Режим скриншотов: виджеты в разное время дня, чтобы проверить их без экрана «Домой»
struct WidgetGallery: View {
  @EnvironmentObject var store: Store
  let times = ["2026-10-29 13:20", "2026-10-29 14:32", "2026-10-29 15:50", "2026-10-29 17:30", "2026-11-01 12:00"]
  var body: some View {
    ScrollView {
      if let sc = store.sched {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(times, id: \.self) { s in
            let t = Shot.parse(s) ?? Date(), st = widgetState(sc, t)
            Text(s).font(.m(11)).foregroundColor(.gray)
            HStack(alignment: .top, spacing: 12) {
              tile(WSmall(st: st), w: 158)
              VStack(alignment: .leading, spacing: 8) {
                lock(WRect(st: st), w: 172, h: 64)
                HStack(spacing: 8) { lock(WCirc(st: st), w: 64, h: 64); Text(st.inline).font(.m(11)).foregroundColor(.white).lineLimit(2) }
              }
            }
            if s == times.first || s == times.last { tile(WMedium(st: st), w: 338) }
          }
        }.padding(16)
      }
    }
    .background(Color(white: 0.11).ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }
  func tile<V: View>(_ v: V, w: CGFloat) -> some View {
    v.padding(14).frame(width: w, height: 158).background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(C.surface))
  }
  func lock<V: View>(_ v: V, w: CGFloat, h: CGFloat) -> some View {
    v.foregroundColor(.white).environment(\.colorScheme, .dark).padding(6).frame(width: w, height: h)
      .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.16, green: 0.23, blue: 0.33)))
  }
}

// Режим скриншотов: эфир активности в разное время
struct LiveGallery: View {
  @EnvironmentObject var store: Store
  let times = ["2026-10-29 08:40", "2026-10-29 13:20", "2026-10-29 14:32", "2026-10-29 16:20"]
  var body: some View {
    ScrollView {
      if let sc = store.sched {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(times, id: \.self) { s in
            let t = Shot.parse(s) ?? Date()
            if let st = liveContent(sc, t) {
              Text(s).font(.m(11)).foregroundColor(.gray)
              LiveCard(st: st).background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(C.surface))
              HStack {
                LiveCompactLeading(st: st)
                Spacer()
                LiveCompactTrailing(st: st)
              }
              .padding(.horizontal, 14).frame(width: 250, height: 36).background(Capsule().fill(.black)).frame(maxWidth: .infinity)
            }
          }
          if let st = liveContent(sc, Shot.parse("2026-10-29 13:20") ?? Date()) {
            Text("устаревший").font(.m(11)).foregroundColor(.gray)
            LiveCard(st: st, stale: true).background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(C.surface))
          }
        }.padding(16)
      }
    }
    .background(Color(white: 0.3).ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }
}
