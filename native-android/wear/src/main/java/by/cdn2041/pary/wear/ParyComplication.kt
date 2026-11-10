package by.cdn2041.pary.wear

import android.content.ComponentName
import android.content.Context
import android.graphics.drawable.Icon
import androidx.wear.watchface.complications.data.*
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import androidx.wear.watchface.complications.datasource.ComplicationDataTimeline
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingTimelineComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.TimeInterval
import androidx.wear.watchface.complications.datasource.TimelineEntry
import by.cdn2041.pary.*
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.TimeUnit

// Отрезок дня: до пары, пара, перерыв посреди пары. Таймер на циферблате считает до его конца сам.
private class Phase(val start: Instant, val end: Instant, val p: Int, val label: String, val subj: String, val room: String)

private fun at(d: LocalDate, min: Int): Instant = d.atStartOfDay(ZoneId.systemDefault()).plusMinutes(min.toLong()).toInstant()

private fun phases(sc: Sched, d: LocalDate): List<Phase> {
  val all = sc.active(sc.lessonsFor(d))
  val r = mutableListOf<Phase>()
  var from = 0
  for (l in all) {
    if (l.a > from) r.add(Phase(at(d, from), at(d, l.a), l.p, "до ${l.p} пары", l.s, l.r))
    val h1 = l.h1; val h2 = l.h2
    if (h1 != null && h2 != null && h1 > l.a && h2 < l.b && h2 > h1) {
      r.add(Phase(at(d, l.a), at(d, h1), l.p, "до перерыва", l.s, l.r))
      r.add(Phase(at(d, h1), at(d, h2), l.p, "перерыв", l.s, l.r))
      r.add(Phase(at(d, h2), at(d, l.b), l.p, "до конца", l.s, l.r))
    } else r.add(Phase(at(d, l.a), at(d, l.b), l.p, "до конца", l.s, l.r))
    from = l.b
  }
  // Сессия: до начала экзамена или консультации
  sc.itemsFor(d).forEach { it ->
    if (it.m > from) r.add(Phase(at(d, from), at(d, it.m), 0, "до начала", (KINDS[it.kind ?: "other"] ?: "") + " · " + it.s, it.r))
  }
  return r
}

private fun icon(ctx: Context) = MonochromaticImage.Builder(Icon.createWithResource(ctx, R.drawable.ic_cap)).build()
private fun plain(s: String) = PlainComplicationText.Builder(s).build()

private fun phaseData(ctx: Context, type: ComplicationType, ph: Phase): ComplicationData? {
  fun timer(fmt: String?) = TimeDifferenceComplicationText.Builder(TimeDifferenceStyle.SHORT_DUAL_UNIT, CountDownTimeReference(ph.end))
    .setMinimumTimeUnit(TimeUnit.MINUTES).apply { if (fmt != null) setText(fmt) }.build()
  val desc = plain("${ph.label}, ${ph.subj}, ${ph.room}")
  return when (type) {
    ComplicationType.SHORT_TEXT -> ShortTextComplicationData.Builder(timer(null), desc)
      .setTitle(plain(ph.room.ifEmpty { if (ph.p > 0) "${ph.p} п." else "" })).setMonochromaticImage(icon(ctx)).build()
    ComplicationType.LONG_TEXT -> LongTextComplicationData.Builder(timer(ph.label + " ^1" + (if (ph.room.isEmpty()) "" else " · " + ph.room)), desc)
      .setTitle(plain((if (ph.p > 0) "${ph.p} пара · " else "") + ph.subj)).setMonochromaticImage(icon(ctx)).build()
    else -> null
  }
}

// Когда сегодня всё закончилось: первая пара ближайшего дня
private fun restData(ctx: Context, type: ComplicationType, sc: Sched?, today: LocalDate): ComplicationData? {
  var day: LocalDate? = null; var l: Lesson? = null
  if (sc != null) for (i in 1..14) {
    val d = today.plusDays(i.toLong())
    val x = (sc.active(sc.lessonsFor(d)) + sc.itemsFor(d)).minByOrNull { if (it.kind != null) it.m else it.a }
    if (x != null) { day = d; l = x; break }
  }
  val time = l?.let { if (it.kind != null) it.time else sc!!.pairTime(it.p).first } ?: ""
  val dl = day?.let { if (daysBetween(today, it) == 1) "завтра" else DSHORT[minOf(5, wd(it))].lowercase() } ?: ""
  val desc = plain(if (l == null) "Пар нет" else "$dl в $time, ${l.s}")
  return when (type) {
    ComplicationType.SHORT_TEXT -> ShortTextComplicationData.Builder(plain(time.ifEmpty { "—" }), desc)
      .setTitle(plain(dl)).setMonochromaticImage(icon(ctx)).build()
    ComplicationType.LONG_TEXT -> LongTextComplicationData.Builder(plain(if (l == null) "Пар нет" else "$dl в $time" + (if (l.r.isEmpty()) "" else " · " + l.r)), desc)
      .setTitle(plain(l?.s ?: "Пары Е-21")).setMonochromaticImage(icon(ctx)).build()
    else -> null
  }
}

class ParyComplication : SuspendingTimelineComplicationDataSourceService() {
  override fun getPreviewData(type: ComplicationType): ComplicationData? {
    val now = Instant.now()
    return phaseData(this, type, Phase(now, now.plusSeconds(28 * 60), 2, "до конца", "Кадровое делопроизводство", "1-13"))
  }

  override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationDataTimeline? {
    val ctx = applicationContext
    val type = request.complicationType
    freshen(ctx)
    val sc = loadSched(ctx)
    val today = LocalDate.now()
    val now = Instant.now()
    val def = restData(ctx, type, sc, today) ?: return null
    val entries = if (sc == null) emptyList() else phases(sc, today).filter { it.end > now }.mapNotNull { ph ->
      phaseData(ctx, type, ph)?.let { TimelineEntry(TimeInterval(ph.start, ph.end), it) }
    }
    return ComplicationDataTimeline(def, entries)
  }

  companion object {
    fun loadSched(ctx: Context): Sched? {
      val f = File(ctx.filesDir, "schedule.json")
      val s = (if (f.exists()) try { f.readText() } catch (e: Exception) { null } else null)
        ?: try { ctx.assets.open("schedule.json").bufferedReader().use { it.readText() } } catch (e: Exception) { null }
      val p = ctx.getSharedPreferences("pary", Context.MODE_PRIVATE)
      return Sched.make(Sched.parse(s), p.getString("pary-e21-p2", null) == "1", p.getString("pary-e21-nofive", null) == "1")
    }
    // Свежее расписание с сайта, если копия на часах старше часа
    suspend fun freshen(ctx: Context) {
      val f = File(ctx.filesDir, "schedule.json")
      if (f.exists() && System.currentTimeMillis() - f.lastModified() < 3_600_000) return
      val s = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
        try {
          val c = java.net.URL(WearStore.SITE_URL).openConnection() as java.net.HttpURLConnection
          c.useCaches = false; c.connectTimeout = 10000; c.readTimeout = 10000
          if (c.responseCode == 200) c.inputStream.bufferedReader().use { it.readText() } else null
        } catch (e: Exception) { null }
      } ?: return
      if (Sched.parse(s) != null) try { f.writeText(s) } catch (_: Exception) {}
    }
    // Обновить усложнения на циферблате после нового расписания
    fun refresh(ctx: Context) {
      try {
        ComplicationDataSourceUpdateRequester.create(ctx, ComponentName(ctx, ParyComplication::class.java)).requestUpdateAll()
      } catch (_: Exception) {}
    }
  }
}
