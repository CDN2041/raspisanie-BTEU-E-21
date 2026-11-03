package by.cdn2041.pary

import org.json.JSONArray
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.roundToInt

// Пара или событие сессии в том виде, как их показывает приложение (как Model.swift)
data class Lesson(
  var d: Int = 0, var p: Int = 0, var w: String = "all",
  var s: String = "", var t: String = "", var tch: String = "", var r: String = "", var was: String = "", var from: String = "",
  var cancel: Boolean = false, var ed: Boolean = false,
  var sub: String = "",          // "rep" замена, "add" доп. пара
  var kind: String? = null,      // exam, credit, consult, other
  var time: String = "", var m: Int = 0,
  var a: Int = 0, var b: Int = 0,
  var h1: Int? = null, var h2: Int? = null,
) {
  val id: String get() = if (kind != null) "k|$time|$s" else "p|$p|$s"
}

val KINDS = mapOf("exam" to "Экзамен", "credit" to "Зачёт", "consult" to "Консультация", "other" to "Событие")
val KGEN = mapOf("exam" to "экзамена", "credit" to "зачёта", "consult" to "консультации", "other" to "события")
val KSHORT = mapOf("exam" to "экз.", "credit" to "зач.", "consult" to "конс.", "other" to "соб.")
const val FK = "Физическая культура"
val DSHORT = listOf("Пн", "Вт", "Ср", "Чт", "Пт", "Сб")
val DAYS_FULL = listOf("Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота")
val WHEN = listOf("В воскресенье", "В понедельник", "Во вторник", "В среду", "В четверг", "В пятницу", "В субботу")
val MON = listOf("янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек")
val MONF = listOf("января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря")
val MONN = listOf("Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь")

// ---------- Даты ----------
fun weekday(d: LocalDate) = d.dayOfWeek.value % 7      // 0 = воскресенье, как в JS
fun wd(d: LocalDate) = d.dayOfWeek.value - 1          // 0 = понедельник
fun mondayOf(d: LocalDate): LocalDate = d.with(DayOfWeek.MONDAY)
fun daysBetween(a: LocalDate, b: LocalDate) = ChronoUnit.DAYS.between(a, b).toInt()
fun weeksBetween(a: LocalDate, b: LocalDate) = (daysBetween(mondayOf(a), mondayOf(b)) / 7.0).roundToInt()
fun key(d: LocalDate) = d.toString()
fun pd(s: String?): LocalDate? = try { if (isDateKey(s)) LocalDate.parse(s) else null } catch (e: Exception) { null }
fun dnum(d: LocalDate) = d.dayOfMonth
fun mnum(d: LocalDate) = d.monthValue - 1
fun monthStart(d: LocalDate): LocalDate = d.withDayOfMonth(1)
fun toMin(t: String): Int {
  val a = t.split(":").mapNotNull { it.trim().toIntOrNull() }
  return if (a.size == 2) a[0] * 60 + a[1] else 0
}
fun fmtMin(x: Int) = "${x / 60}:" + "%02d".format(x % 60)
fun dur(m: Int): String {
  val h = m / 60; val mm = m % 60
  return if (h > 0) "$h ч" + (if (mm > 0) " $mm мин" else "") else "$mm мин"
}
fun plural(n: Int, a: String, b: String, c: String): String {
  val x = n % 100; val y = n % 10
  return if (x in 11..19) c else if (y == 1) a else if (y in 2..4) b else c
}
fun isDateKey(s: String?) = s != null && Regex("^\\d{4}-\\d\\d-\\d\\d$").matches(s)

private fun truthy(v: Any?) = v == true || (v is Number && v.toInt() != 0)

class Sched private constructor(x0: JSONObject, p2: Boolean, private val noFive: Boolean) {
  val anchor: LocalDate = pd(x0.getString("anchor"))!!
  val anchorT = if (x0.optString("anchorType") == "over") "over" else "under"
  val last: LocalDate = pd(x0.getString("end"))!!
  val first: LocalDate? = pd(x0.optString("start", ""))
  var endAll: LocalDate = last
  val pairs: List<List<String>>          // с единицы: pairs[1] это первая пара
  val byDay = List(6) { mutableListOf<Lesson>() }
  val changes = HashMap<String, List<JSONObject>>()
  var sessFrom: LocalDate? = null; var sessTo: LocalDate? = null
  val sessBy = HashMap<String, List<Lesson>>()
  private val cache = HashMap<String, List<Lesson>>()
  private val busyCache = HashMap<LocalDate, Boolean>()

  init {
    val bells = x0.optJSONArray("bells") ?: JSONArray()
    pairs = listOf(emptyList<String>()) + (0 until bells.length()).map { i ->
      val b = bells.optJSONArray(i) ?: JSONArray()
      (0 until b.length()).map { b.opt(it)?.toString() ?: "" }
    }
    var lessons = x0.optJSONArray("lessons") ?: JSONArray()
    var ch = x0.optJSONObject("changes")
    val alt = x0.optJSONObject("alt")
    if (p2 && alt?.optJSONArray("lessons") != null) {
      lessons = alt.getJSONArray("lessons"); ch = alt.optJSONObject("changes") ?: JSONObject()
    }
    for (i in 0 until lessons.length()) {
      val o = lessons.optJSONObject(i) ?: continue
      val l = fill(lesson(o)) ?: continue
      if (l.d in 0..5) byDay[l.d].add(l)
    }
    byDay.forEach { it.sortBy { l -> l.p } }
    ch?.keys()?.forEach { k ->
      val arr = ch.optJSONArray(k) ?: return@forEach
      changes[k] = (0 until arr.length()).mapNotNull { arr.optJSONObject(it) }
    }
    val s = x0.optJSONObject("session")
    val f = pd(s?.optString("from")); val t = pd(s?.optString("to"))
    if (s != null && f != null && t != null) {
      val by = HashMap<String, MutableList<Lesson>>()
      val items = s.optJSONArray("items") ?: JSONArray()
      for (i in 0 until items.length()) {
        val it = items.optJSONObject(i) ?: continue
        val dk = it.optString("date")
        if (!isDateKey(dk)) continue
        val l = lesson(it)
        l.time = it.optString("time").ifEmpty { "9:00" }
        l.m = toMin(l.time)
        val k = it.optString("kind", "other")
        l.kind = if (KINDS.containsKey(k)) k else "other"
        by.getOrPut(dk) { mutableListOf() }.add(l)
      }
      by.forEach { (k, v) -> sessBy[k] = v.sortedBy { it.m } }
      sessFrom = f; sessTo = t
      if (t > endAll) endAll = t
    }
  }

  private fun fill(l: Lesson): Lesson? {
    if (l.p < 1 || l.p >= pairs.size || pairs[l.p].size < 2) return null
    val b = pairs[l.p]
    l.a = toMin(b[0]); l.b = toMin(b[1])
    if (!noFive && b.size >= 4 && b[2].isNotEmpty() && b[3].isNotEmpty()) { l.h1 = toMin(b[2]); l.h2 = toMin(b[3]) }
    return l
  }

  companion object {
    fun valid(x: JSONObject?): Boolean = x != null && isDateKey(x.optString("anchor")) && isDateKey(x.optString("end")) &&
      (x.optJSONArray("bells")?.length() ?: 0) > 0 && x.optJSONArray("lessons") != null
    fun make(x: JSONObject?, p2: Boolean, noFive: Boolean): Sched? =
      if (!valid(x)) null else try { Sched(x!!, p2, noFive) } catch (e: Exception) { null }
    fun parse(s: String?): JSONObject? = try { s?.let { JSONObject(it) }?.takeIf { valid(it) } } catch (e: Exception) { null }
    fun lesson(o: JSONObject) = Lesson(
      d = o.optInt("d", 0), p = o.optInt("p", 0), w = o.optString("w", "all"),
      s = o.optString("s", ""), t = o.optString("t", ""), tch = o.optString("tch", ""), r = o.optString("r", ""),
      was = o.optString("was", ""), from = o.optString("from", ""),
      cancel = truthy(o.opt("cancel")), ed = truthy(o.opt("ed")),
    )
  }

  fun weekType(d: LocalDate): String {
    val even = ((weeksBetween(anchor, d) % 2) + 2) % 2 == 0
    return if (even) anchorT else if (anchorT == "under") "over" else "under"
  }
  fun weekName(d: LocalDate) = if (weekType(d) == "over") "над чертой" else "под чертой"
  fun beforeStart(d: LocalDate) = first != null && d < first
  fun afterEnd(d: LocalDate) = d > endAll

  // Пары дня: постоянное расписание + замены и отмены на эту дату. Отменённые остаются с пометкой.
  fun lessonsFor(d: LocalDate): List<Lesson> = cache.getOrPut(key(d)) { buildDay(d, key(d)) }
  private fun buildDay(d: LocalDate, k: String): List<Lesson> {
    var list: List<Lesson> = emptyList()
    val w = wd(d)
    if (w < 6 && d <= last && !beforeStart(d)) {
      val wt = weekType(d)
      list = byDay[w].filter { (it.w == "all" || it.w == wt) && (it.from.isEmpty() || k >= it.from) }.map { it.copy() }
    }
    val ch = changes[k] ?: return list
    val by = sortedMapOf<Int, Lesson>()
    list.forEach { by[it.p] = it }
    for (o in ch) {
      val c = fill(lesson(o)) ?: continue
      val base = by[c.p]
      if (c.cancel) { if (base != null) by[c.p] = base.copy(cancel = true); continue }
      if (c.ed && base != null) { by[c.p] = base.copy(s = c.s, t = c.t, tch = c.tch, r = c.r, ed = true); continue }
      c.sub = if (base != null) "rep" else "add"
      if (c.was.isEmpty() && base != null) c.was = base.s + (if (base.tch.isEmpty()) "" else ", " + base.tch)
      by[c.p] = c
    }
    return by.values.toList()
  }
  fun active(l: List<Lesson>) = l.filter { !it.cancel }
  fun itemsFor(d: LocalDate): List<Lesson> = sessBy[key(d)] ?: emptyList()
  fun inSession(d: LocalDate): Boolean { val f = sessFrom ?: return false; return d >= f && d <= sessTo!! }
  fun satBusy(mon: LocalDate): Boolean = busyCache.getOrPut(mon) {
    val s = mon.plusDays(5); lessonsFor(s).isNotEmpty() || itemsFor(s).isNotEmpty()
  }
  fun daysIn(mon: LocalDate) = if (satBusy(mon)) 6 else 5
  fun inStrip(d: LocalDate): Boolean { val w = wd(d); return w < 5 || (w == 5 && satBusy(mondayOf(d))) }
  fun studyDay(d: LocalDate): LocalDate { var x = d; var i = 0; while (!inStrip(x) && i < 14) { x = x.plusDays(1); i++ }; return x }
  fun firstDay() = studyDay(first ?: mondayOf(anchor).minusWeeks(20))
  fun lastDay(): LocalDate { var d = endAll; var i = 0; while (!inStrip(d) && i < 14) { d = d.minusDays(1); i++ }; return d }
  fun weekInSession(mon: LocalDate) = (0..5).any { inSession(mon.plusDays(it.toLong())) }
  fun clamp(d: LocalDate): LocalDate {
    var s = d
    if (!inStrip(s)) s = if (weekday(s) == 6) s.minusDays(1) else studyDay(s)
    if (afterEnd(s)) s = lastDay()
    if (beforeStart(s)) s = firstDay()
    return s
  }
  // Все учебные дни подряд: по ним листается полное расписание
  val allDays: List<LocalDate> by lazy {
    val r = mutableListOf<LocalDate>()
    var d = firstDay(); val e = lastDay(); var n = 0
    while (d <= e && n < 800) { if (inStrip(d)) r.add(d); d = d.plusDays(1); n++ }
    r
  }
  fun isBig(a: Lesson, b: Lesson) = b.p - a.p == 1 && b.a - a.b >= 25
  fun pairTime(p: Int): Pair<String, String> =
    if (p >= 1 && p < pairs.size && pairs[p].size >= 2) pairs[p][0] to pairs[p][1] else "" to ""
}

// Заметки: к практикам (кроме физкультуры) и к экзаменам, зачётам, консультациям
fun canNote(l: Lesson) = !l.cancel && (l.kind != null || ((l.t == "prac" || l.t == "mix") && l.s != FK))
fun noteKey(d: LocalDate, l: Lesson) = key(d) + "|" + (if (l.kind != null) l.time else l.p.toString()) + "|" + l.s

// Время до перерыва или до конца пары
fun leftOf(l: Lesson, m: Int): Pair<String, Int> {
  val h1 = l.h1; val h2 = l.h2
  if (h1 != null && h2 != null && h1 > l.a && h2 < l.b && h2 > h1) {
    if (m < h1) return "До перерыва " to h1 - m
    if (m < h2) return "До конца перерыва " to h2 - m
  }
  return "До конца пары осталось " to l.b - m
}
