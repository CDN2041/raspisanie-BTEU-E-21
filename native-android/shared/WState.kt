package by.cdn2041.pary

import java.time.LocalDateTime

// Что показывает виджет в данную минуту: крупно свежая информация, внизу одна следующая пара
data class WNext(val time: String, val subj: String, val room: String)
data class WState(
  val kind: Int = DONE,      // LIVE, WAIT, DONE
  val head: String = "",
  val big: String = "",
  val mins: Int = 0,
  val frac: Double? = null,
  val subj: String = "", val room: String = "", val range: String = "",
  val next: WNext? = null,
  val last: Boolean = false,
  val date: String = "",
) {
  companion object { const val LIVE = 0; const val WAIT = 1; const val DONE = 2 }
}

private val WDS = listOf("вс", "пн", "вт", "ср", "чт", "пт", "сб")

fun nowMin(t: LocalDateTime) = t.hour * 60 + t.minute

fun widgetState(sc: Sched, t: LocalDateTime): WState {
  val td = t.toLocalDate(); val m = nowMin(t)
  val all = sc.active(sc.lessonsFor(td)); val its = sc.itemsFor(td)
  val date = WDS[weekday(td)] + ", ${dnum(td)} " + MONF[mnum(td)]
  fun nx(l: Lesson?) = l?.let { WNext(sc.pairTime(it.p).first, it.s, it.r) }
  fun rng(l: Lesson): String { val p = sc.pairTime(l.p); return p.first + "–" + p.second }

  all.firstOrNull { m >= it.a && m < it.b }?.let { cur ->
    var label = "до конца"; var left = cur.b - m
    val h1 = cur.h1; val h2 = cur.h2
    if (h1 != null && h2 != null && h1 > cur.a && h2 < cur.b && h2 > h1) {
      if (m < h1) { label = "до перерыва"; left = h1 - m } else if (m < h2) { label = "перерыв"; left = h2 - m }
    }
    val after = all.firstOrNull { it.p > cur.p }
    return WState(WState.LIVE, "${cur.p} пара · $label", dur(left), left,
      (m - cur.a).toDouble() / maxOf(1, cur.b - cur.a), cur.s, cur.r, rng(cur), nx(after), after == null, date)
  }
  all.firstOrNull { it.a > m }?.let { nl ->
    val prev = all.lastOrNull { it.b <= m }
    val after = all.firstOrNull { it.p > nl.p }
    return WState(WState.WAIT, if (prev == null) "${nl.p} пара · до начала" else "Перерыв · до ${nl.p} пары",
      dur(nl.a - m), nl.a - m, prev?.let { (m - it.b).toDouble() / maxOf(1, nl.a - it.b) },
      nl.s, nl.r, rng(nl), nx(after), after == null, date)
  }
  its.firstOrNull { it.m > m }?.let { it ->
    val k = KINDS[it.kind ?: "other"] ?: ""
    return WState(WState.WAIT, "$k · до начала", dur(it.m - m), it.m - m, null, it.s, it.r, it.time, null, false, date)
  }
  val big = if (all.isNotEmpty() || its.isNotEmpty()) (if (sc.inSession(td)) "Экзамены закончились" else "Пары закончились")
    else if (sc.inSession(td)) "Сегодня экзаменов нет" else "Сегодня пар нет"
  return WState(WState.DONE, big = big, date = date)
}

// Есть ли ещё сегодня что-то, ради чего виджет надо обновлять каждую минуту
fun widgetBusy(sc: Sched, t: LocalDateTime): Boolean {
  val td = t.toLocalDate(); val m = nowMin(t)
  val ends = sc.active(sc.lessonsFor(td)).map { it.b } + sc.itemsFor(td).map { it.m }
  return (ends.maxOrNull() ?: -1) > m
}
