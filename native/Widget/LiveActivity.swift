import ActivityKit
import WidgetKit
import SwiftUI

struct ParyLive: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ParyAttributes.self) { ctx in
      LiveCard(st: ctx.state, stale: ctx.isStale)
        .activityBackgroundTint(C.surface)
        .activitySystemActionForegroundColor(C.fg)
        .widgetURL(URL(string: "pary://now"))
    } dynamicIsland: { ctx in
      let st = ctx.state, stale = ctx.isStale
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(stale ? "Пары" : st.head, systemImage: "graduationcap.fill")
            .font(.m(13)).foregroundColor(.white).lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          LiveTimer(st: st, stale: stale).font(.m(20, 700)).foregroundColor(.white)
            .multilineTextAlignment(.trailing).frame(maxWidth: 90)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            if !stale && !st.subj.isEmpty {
              Text(st.subj + (st.room.isEmpty ? "" : " · " + st.room)).font(.b(15, 600)).foregroundColor(.white).lineLimit(1)
            }
            if !st.segs.isEmpty { LiveRoute(segs: st.segs).environment(\.colorScheme, .dark) }
          }
        }
      } compactLeading: {
        LiveCompactLeading(st: st)
      } compactTrailing: {
        LiveCompactTrailing(st: st, stale: stale)
      } minimal: {
        Image(systemName: "graduationcap.fill").foregroundColor(.white)
      }
      .widgetURL(URL(string: "pary://now"))
    }
  }
}
