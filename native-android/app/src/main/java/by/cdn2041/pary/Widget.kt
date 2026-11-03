package by.cdn2041.pary

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.ZoneId

// Виджет «Сейчас»: весь текст моноширинным шрифтом, как время; цвета Material You
class NowWidget : GlanceAppWidget() {
  override val sizeMode = SizeMode.Responsive(setOf(DpSize(110.dp, 110.dp), DpSize(250.dp, 110.dp)))
  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent {
      val sc = Disk.load(context)
      val st = sc?.let { widgetState(it, LocalDateTime.now()) }
      GlanceTheme { Body(st) }
    }
  }
}

@Composable
private fun ts(size: Int, bold: Boolean = false, muted: Boolean = false): TextStyle =
  TextStyle(fontFamily = FontFamily.Monospace, fontSize = size.sp, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
    color = if (muted) GlanceTheme.colors.onSurfaceVariant else GlanceTheme.colors.onSurface)

@Composable
private fun Body(st: WState?) {
  val wide = LocalSize.current.width >= 250.dp
  Box(GlanceModifier.fillMaxSize().background(GlanceTheme.colors.widgetBackground).cornerRadius(24.dp).padding(14.dp)
    .clickable(actionStartActivity<MainActivity>())) {
    if (st == null) Text("Пары Е-21", style = ts(14, true))
    else if (st.kind == WState.DONE) Column(GlanceModifier.fillMaxSize()) {
      Text(st.big, style = ts(if (wide) 20 else 17, true))
      Spacer(GlanceModifier.height(6.dp))
      Text(st.date, style = ts(11, muted = true))
    } else if (wide) Row(GlanceModifier.fillMaxSize()) {
      Column(GlanceModifier.defaultWeight().fillMaxHeight()) { Main(st) }
      Spacer(GlanceModifier.width(14.dp))
      Column(GlanceModifier.defaultWeight().fillMaxHeight()) { Next(st, true) }
    } else Column(GlanceModifier.fillMaxSize()) {
      Main(st)
      Spacer(GlanceModifier.defaultWeight())
      Next(st, false)
    }
  }
}

@Composable
private fun Main(st: WState) {
  Text(st.head, style = ts(11, muted = true), maxLines = 1)
  Text(st.big, style = ts(28, true), maxLines = 1)
  st.frac?.let {
    Spacer(GlanceModifier.height(6.dp))
    LinearProgressIndicator(it.toFloat().coerceIn(0f, 1f), GlanceModifier.fillMaxWidth().height(5.dp),
      color = GlanceTheme.colors.primary, backgroundColor = GlanceTheme.colors.secondaryContainer)
  }
  Spacer(GlanceModifier.height(6.dp))
  Row(GlanceModifier.fillMaxWidth()) {
    Text(st.subj, GlanceModifier.defaultWeight(), style = ts(11, muted = true), maxLines = 1)
    Text(" " + st.room, style = ts(11))
  }
}

@Composable
private fun Next(st: WState, wide: Boolean) {
  val n = st.next
  if (n != null) Column(GlanceModifier.fillMaxWidth()) {
    if (wide) { Text("Далее", style = ts(11, muted = true)) ; Spacer(GlanceModifier.height(4.dp)) }
    Row(GlanceModifier.fillMaxWidth()) {
      Text(n.time, GlanceModifier.defaultWeight(), style = ts(11, muted = true))
      Text(n.room, style = ts(11))
    }
    Text(n.subj, style = ts(11), maxLines = if (wide) 3 else 1)
  } else if (st.last) Text("Последняя на сегодня", style = ts(11, muted = true), maxLines = 1)
}

class NowWidgetReceiver : GlanceAppWidgetReceiver() {
  override val glanceAppWidget: GlanceAppWidget = NowWidget()
  override fun onUpdate(context: Context, m: AppWidgetManager, ids: IntArray) {
    super.onUpdate(context, m, ids)
    Widgets.tick(context, refresh = true)
  }
  override fun onEnabled(context: Context) { super.onEnabled(context); Widgets.tick(context, refresh = true) }
}

class TickReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val p = goAsync()
    Widgets.scope.launch { try { Widgets.run(context, true) } finally { p.finish() } }
  }
}

object Widgets {
  val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

  // Перерисовать виджеты сейчас (после изменений в приложении)
  fun update(ctx: Context) { scope.launch { Widgets.run(ctx.applicationContext, false) } }
  fun tick(ctx: Context, refresh: Boolean) { scope.launch { Widgets.run(ctx.applicationContext, refresh) } }

  suspend fun run(ctx: Context, refresh: Boolean) {
    if (refresh) {
      // Свежее расписание с сайта, не чаще раза в полчаса
      val p = Disk.prefs(ctx); val last = p.getLong("widget-fetch", 0)
      if (System.currentTimeMillis() - last > 1_800_000) {
        Disk.download()?.let { if (Sched.parse(it) != null) { Disk.write(ctx, it); p.edit().putLong("widget-fetch", System.currentTimeMillis()).apply() } }
      }
    }
    val ids = try { androidx.glance.appwidget.GlanceAppWidgetManager(ctx).getGlanceIds(NowWidget::class.java) } catch (_: Exception) { emptyList() }
    if (ids.isEmpty()) return
    try { NowWidget().updateAll(ctx) } catch (_: Exception) {}
    schedule(ctx)
  }

  // Следующее обновление: в начале следующей минуты, пока сегодня идут пары, иначе через 30 минут.
  // Будильник не будит телефон: сработает, когда экран включат.
  private fun schedule(ctx: Context) {
    val now = LocalDateTime.now()
    val sc = Disk.load(ctx)
    val next = if (sc != null && widgetBusy(sc, now)) now.withSecond(0).withNano(0).plusMinutes(1)
      else minOf(now.plusMinutes(30), now.toLocalDate().plusDays(1).atStartOfDay().plusMinutes(1))
    val at = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
    val pi = PendingIntent.getBroadcast(ctx, 1, Intent(ctx, TickReceiver::class.java),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val am = ctx.getSystemService(AlarmManager::class.java)
    am.setWindow(AlarmManager.RTC, at, 5_000, pi)
  }
}
