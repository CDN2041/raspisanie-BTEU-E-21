package by.cdn2041.pary.wear

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.*
import by.cdn2041.pary.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

// ---------- Вид: тёмная тема сайта ----------
private val FG = Color(0xFFE8EBF1)
private val MUTED = Color(0xFF8B93A5)
private val SURF = Color(0xFF181C23)
private val LINE = Color(0xFF2A303A)
private val WARN = Color(0xFFFF7A70)
private val NOTE = Color(0xFFE8A94B)
private fun mono(s: Int, bold: Boolean = false) = TextStyle(fontFamily = FontFamily.Monospace, fontSize = s.sp,
  fontWeight = if (bold) FontWeight.Bold else FontWeight.Medium)
private fun sans(s: Int, w: Int = 400) = TextStyle(fontSize = s.sp, fontWeight = FontWeight(w))

// ---------- Данные: своя копия расписания, обновление с сайта ----------
class WearStore(private val ctx: Context, val shotNow: LocalDateTime?) {
  var sched by mutableStateOf<Sched?>(null); private set
  var rev by mutableIntStateOf(0); private set
  private val file = File(ctx.filesDir, "schedule.json")
  private var text: String? = null
  private var last = 0L

  init {
    val s = (if (shotNow == null && file.exists()) try { file.readText() } catch (e: Exception) { null } else null)
      ?: try { ctx.assets.open("schedule.json").bufferedReader().use { it.readText() } } catch (e: Exception) { null }
    adopt(s)
  }
  fun now(): LocalDateTime = shotNow ?: LocalDateTime.now()
  private fun adopt(s: String?): Boolean {
    val p = ctx.getSharedPreferences("pary", Context.MODE_PRIVATE)
    val sc = Sched.make(Sched.parse(s), p.getString("pary-e21-p2", null) == "1", p.getString("pary-e21-nofive", null) == "1") ?: return false
    sched = sc; text = s; rev++
    return true
  }
  suspend fun fetch() {
    if (shotNow != null || System.currentTimeMillis() - last < 300_000) return
    last = System.currentTimeMillis()
    val s = withContext(Dispatchers.IO) {
      try {
        val c = URL(SITE_URL).openConnection() as HttpURLConnection
        c.useCaches = false; c.connectTimeout = 15000; c.readTimeout = 15000
        c.setRequestProperty("Cache-Control", "no-cache")
        if (c.responseCode == 200) c.inputStream.bufferedReader().use { it.readText() } else null
      } catch (e: Exception) { null }
    } ?: return
    if (s == text) return
    if (adopt(s)) { withContext(Dispatchers.IO) { try { file.writeText(s) } catch (_: Exception) {} }; ParyComplication.refresh(ctx) }
  }
  companion object { const val SITE_URL = "https://cdn2041.github.io/raspisanie-BTEU-E-21/schedule.json" }
}

class WearActivity : ComponentActivity() {
  override fun onCreate(b: Bundle?) {
    super.onCreate(b)
    val shot = try { intent.getStringExtra("shot_now")?.let { LocalDateTime.parse(it, DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")) } } catch (e: Exception) { null }
    val page = if (intent.getStringExtra("shot_page") == "day") 1 else 0
    val store = WearStore(applicationContext, shot)
    setContent { MaterialTheme { WearRoot(store, page) } }
  }
}

// Текущее время, обновляется в начале каждой минуты
@Composable
private fun rememberNow(store: WearStore): LocalDateTime {
  var t by remember { mutableStateOf(store.now()) }
  LaunchedEffect(Unit) {
    while (true) {
      t = store.now()
      val n = LocalDateTime.now()
      delay(((60 - n.second) * 1000L - n.nano / 1_000_000).coerceAtLeast(200))
    }
  }
  return t
}

@Composable
fun WearRoot(store: WearStore, page0: Int) {
  val life = LocalLifecycleOwner.current
  LaunchedEffect(Unit) { life.repeatOnLifecycle(Lifecycle.State.STARTED) { while (true) { store.fetch(); delay(300_000) } } }
  val sc = store.sched
  if (sc == null) {
    Box(Modifier.fillMaxSize().padding(20.dp), contentAlignment = Alignment.Center) {
      Text("Нет расписания.\nНужен интернет для первой загрузки", style = sans(14), color = FG, textAlign = TextAlign.Center)
    }
    return
  }
  val t = rememberNow(store)
  val ps = rememberPagerState(page0) { 2 }
  val ind = remember(ps) {
    object : PageIndicatorState {
      override val pageOffset get() = ps.currentPageOffsetFraction
      override val selectedPage get() = ps.currentPage
      override val pageCount get() = 2
    }
  }
  key(store.rev) {
    Scaffold(timeText = { TimeText() }) {
      HorizontalPager(ps, Modifier.fillMaxSize()) { p ->
        if (p == 0) NowPage(sc, t) else DayPage(sc, t)
      }
      HorizontalPageIndicator(ind, Modifier.padding(bottom = 4.dp))
    }
  }
}

@Composable
private fun Bar(f: Double, modifier: Modifier = Modifier) {
  Canvas(modifier.fillMaxWidth().height(5.dp)) {
    val r = CornerRadius(size.height / 2)
    drawRoundRect(LINE, cornerRadius = r)
    val w = size.width * f.toFloat().coerceIn(0f, 1f)
    if (w > 0) drawRoundRect(FG, size = size.copy(width = maxOf(w, size.height)), cornerRadius = r)
  }
}

// ---------- «Сейчас»: крупно свежее, ниже следующая пара ----------
@Composable
private fun NowPage(sc: Sched, t: LocalDateTime) {
  val s = widgetState(sc, t)
  val ls = rememberScalingLazyListState(initialCenterItemIndex = 0)
  Scaffold(positionIndicator = { PositionIndicator(ls) }) {
    ScalingLazyColumn(Modifier.fillMaxSize(), ls, contentPadding = PaddingValues(top = 30.dp, bottom = 40.dp, start = 14.dp, end = 14.dp), autoCentering = null,
      horizontalAlignment = Alignment.CenterHorizontally) {
      item { Text(s.date, style = mono(12), color = MUTED) }
      if (s.kind == WState.DONE) {
        item { Text(s.big, style = mono(19, true), color = FG, textAlign = TextAlign.Center) }
        nextDay(sc, t.toLocalDate())?.let { (d, l) ->
          item { Text(DAYS_FULL[weekday(d)] + ", ${dnum(d)} " + MON[mnum(d)], Modifier.padding(top = 6.dp), style = mono(12), color = MUTED) }
          item { LessonCard(sc, l, d, t) }
        }
      } else {
        item { Text(s.head, style = mono(12), color = MUTED, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        item { Text(s.big, style = mono(34, true), color = FG, maxLines = 1) }
        s.frac?.let { f -> item { Bar(f, Modifier.padding(horizontal = 10.dp, vertical = 2.dp)) } }
        item { Text(s.subj, Modifier.padding(top = 4.dp), style = sans(15, 600), color = FG, textAlign = TextAlign.Center, maxLines = 3) }
        item { Text(s.range + "  " + s.room, style = mono(13), color = MUTED) }
        s.next?.let { n ->
          item {
            Column(Modifier.padding(top = 8.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(SURF).padding(10.dp),
              horizontalAlignment = Alignment.CenterHorizontally) {
              Text("Далее · " + n.time + "  " + n.room, style = mono(12), color = MUTED)
              Text(n.subj, style = sans(13), color = FG, textAlign = TextAlign.Center, maxLines = 2)
            }
          }
        }
        if (s.next == null && s.last) item { Text("Последняя на сегодня", Modifier.padding(top = 6.dp), style = mono(12), color = MUTED) }
      }
    }
  }
}

// Первая пара ближайшего дня, где что-то есть
private fun nextDay(sc: Sched, td: LocalDate): Pair<LocalDate, Lesson>? {
  for (i in 1..14) {
    val d = td.plusDays(i.toLong())
    if (sc.afterEnd(d)) return null
    val items = sc.active(sc.lessonsFor(d)) + sc.itemsFor(d)
    items.minByOrNull { if (it.kind != null) it.m else it.a }?.let { return d to it }
  }
  return null
}

// ---------- День: все пары, листание кнопками ----------
@Composable
private fun DayPage(sc: Sched, t: LocalDateTime) {
  var day by remember { mutableStateOf(sc.clamp(t.toLocalDate())) }
  val list = sc.lessonsFor(day); val its = sc.itemsFor(day)
  val ls = rememberScalingLazyListState(initialCenterItemIndex = 0)
  fun step(by: Long): LocalDate {
    var x = day
    repeat(14) { x = x.plusDays(by); if (sc.inStrip(x)) return sc.clamp(x) }
    return day
  }
  Scaffold(positionIndicator = { PositionIndicator(ls) }) {
    ScalingLazyColumn(Modifier.fillMaxSize(), ls, contentPadding = PaddingValues(top = 30.dp, bottom = 40.dp, start = 10.dp, end = 10.dp), autoCentering = null,
      horizontalAlignment = Alignment.CenterHorizontally) {
      item {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
          CompactButton(onClick = { day = step(-1) }, colors = ButtonDefaults.secondaryButtonColors()) { Text("‹", style = sans(18, 600)) }
          Text(DSHORT[minOf(5, wd(day))] + ", ${dnum(day)} " + MON[mnum(day)], style = sans(15, 600), color = FG)
          CompactButton(onClick = { day = step(1) }, colors = ButtonDefaults.secondaryButtonColors()) { Text("›", style = sans(18, 600)) }
        }
      }
      item { Text(if (sc.inSession(day)) "сессия" else "неделя " + sc.weekName(day), style = mono(11), color = MUTED) }
      if (list.isEmpty() && its.isEmpty()) item {
        Text(if (sc.inSession(day)) "Экзаменов нет" else "Пар нет", Modifier.padding(top = 10.dp), style = sans(16, 600), color = FG)
      }
      list.forEach { l -> item(key = l.id) { LessonCard(sc, l, day, t) } }
      its.forEach { l -> item(key = l.id) { LessonCard(sc, l, day, t) } }
      if (day != sc.clamp(t.toLocalDate())) item {
        CompactChip(onClick = { day = sc.clamp(t.toLocalDate()) }, label = { Text("Сегодня") }, colors = ChipDefaults.secondaryChipColors())
      }
    }
  }
}

@Composable
private fun LessonCard(sc: Sched, l: Lesson, d: LocalDate, t: LocalDateTime) {
  val isToday = d == t.toLocalDate(); val m = nowMin(t)
  val live = isToday && !l.cancel && l.kind == null && m >= l.a && m < l.b
  val past = isToday && (if (l.kind != null) m > l.m else m >= l.b)
  val tm = sc.pairTime(l.p)
  Column(Modifier.fillMaxWidth().alpha(if (past && !live) 0.55f else 1f).clip(RoundedCornerShape(18.dp)).background(SURF)
    .then(if (live) Modifier.border(1.5.dp, FG, RoundedCornerShape(18.dp)) else Modifier).padding(horizontal = 12.dp, vertical = 9.dp),
    verticalArrangement = Arrangement.spacedBy(2.dp)) {
    Row(Modifier.fillMaxWidth()) {
      Text(if (l.kind != null) (KSHORT[l.kind!!] ?: "") + " " + l.time else "${l.p}  ${tm.first}–${tm.second}", Modifier.weight(1f),
        style = mono(12), color = MUTED, maxLines = 1)
      Text(l.r, style = mono(12), color = FG)
    }
    Text(l.s, style = sans(14, 600), color = if (l.cancel) MUTED else FG, maxLines = 3, overflow = TextOverflow.Ellipsis,
      textDecoration = if (l.cancel) TextDecoration.LineThrough else null)
    tag(l)?.let { Text(it, style = mono(11), color = if (l.cancel) WARN else if (l.sub.isEmpty() && !l.ed) MUTED else NOTE) }
    if (l.tch.isNotEmpty()) Text(l.tch, style = sans(12), color = MUTED, maxLines = 1, overflow = TextOverflow.Ellipsis)
    if (live) Bar((m - l.a).toDouble() / maxOf(1, l.b - l.a), Modifier.padding(top = 3.dp))
  }
}

private fun tag(l: Lesson): String? {
  l.kind?.let { return KINDS[it] }
  val r = mutableListOf<String>()
  when (l.t) { "lec" -> r.add("Лекция"); "prac" -> r.add("Практика"); "mix" -> r.add("Лек/Прак") }
  if (l.cancel) r.add("Отменена") else if (l.ed) r.add("Изменено") else if (l.sub == "rep") r.add("Замена") else if (l.sub == "add") r.add("Доп. пара")
  return if (r.isEmpty()) null else r.joinToString(" · ")
}
