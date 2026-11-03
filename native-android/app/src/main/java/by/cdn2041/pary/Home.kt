package by.cdn2041.pary

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.LocalDate
import java.time.LocalDateTime

// Текущее время, обновляется в начале каждой минуты
@Composable
fun rememberNow(store: Store): LocalDateTime {
  var t by remember { mutableStateOf(store.now()) }
  LaunchedEffect(store.shown) {
    while (true) {
      t = store.now()
      val n = LocalDateTime.now()
      kotlinx.coroutines.delay(((60 - n.second) * 1000L - n.nano / 1_000_000).coerceAtLeast(200))
    }
  }
  return t
}

// Экран «Сейчас»
@Composable
fun HomeScreen(store: Store, nav: Nav) {
  val sc = store.sched ?: return
  val t = rememberNow(store)
  key(store.rev) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding()
      .padding(horizontal = 16.dp).padding(top = 8.dp).widthIn(max = 560.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
      HomeContent(store, nav, sc, t)
      VersionFooter(store)
    }
  }
}

@Composable
private fun HomeContent(store: Store, nav: Nav, sc: Sched, t: LocalDateTime) {
  val td = t.toLocalDate(); val m = nowMin(t)
  val all = sc.lessonsFor(td); val list = sc.active(all); val its = sc.itemsFor(td); val sd = sc.studyDay(td)
  val wk = if (sc.afterEnd(td)) "" else if (sc.inSession(td) || sc.inSession(sd)) "сессия"
    else (if (td != sd) (if (weekday(td) == 0) "с завтра " else "с понедельника ") else "") + sc.weekName(sd)
  val cur = list.firstOrNull { m >= it.a && m < it.b }
  val next = list.firstOrNull { it.a > m }
  val prev = list.lastOrNull { it.b <= m }
  val itNext = its.firstOrNull { it.m > m }
  val open = nav::openNote
  val tap = haptic()

  // Дата и настройки
  Row(Modifier.fillMaxWidth().rise(0), verticalAlignment = Alignment.CenterVertically) {
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
      Eyebrow("Сегодня" + (if (wk.isEmpty()) "" else " · $wk"))
      Text(DAYS_FULL[weekday(td)] + ", ${dnum(td)} " + MONF[mnum(td)], style = b(22, 600), color = P.fg)
    }
    FilledTonalIconButton(onClick = { tap(); nav.settings = true }, Modifier.size(48.dp)) {
      Icon(Icons.Outlined.Settings, "Настройки")
    }
  }

  all.filter { it.cancel && it.b > m }.forEach { CancelNote(store, it) }

  if (cur != null) {
    val left = leftOf(cur, m)
    StatePill("Идёт ${cur.p} пара", true, Modifier.rise(1))
    LessonHead(cur, Modifier.rise(2))
    CountCard(dur(left.second), left.first.replace("До", "до").replace(" осталось", "").trim(), Modifier.rise(3)) {
      PairBar(cur.a, cur.b, m, cur.h1, cur.h2, 8.dp)
      Times(sc.pairTime(cur.p).first, sc.pairTime(cur.p).second)
    }
    NoteBlock(store, cur, td, open, Modifier.rise(4))
    val rest = all.filter { it.p > cur.p }
    if (rest.isNotEmpty()) Column(Modifier.rise(5), verticalArrangement = Arrangement.spacedBy(8.dp)) { Eyebrow("Дальше сегодня"); Rows(store, rest, td) }
  } else if (next != null) {
    val label = if (prev == null) "До первой пары" else if (sc.isBig(prev, next)) "Большой перерыв" else if (next.p - prev.p > 1) "Окно" else "Перерыв"
    StatePill(label, false, Modifier.rise(1))
    CountCard(dur(next.a - m), "до ${next.p} пары", Modifier.rise(2)) {
      if (prev != null) {
        SimpleBar((m - prev.b).toDouble() / maxOf(1, next.a - prev.b), 8.dp)
        Times(fmtMin(prev.b), sc.pairTime(next.p).first)
      }
    }
    Eyebrow("Следующая", Modifier.rise(3))
    LessonHead(next, Modifier.rise(4))
    NoteBlock(store, next, td, open, Modifier.rise(5))
    val rest = all.filter { it.p > next.p }
    if (rest.isNotEmpty()) Column(Modifier.rise(6), verticalArrangement = Arrangement.spacedBy(8.dp)) { Eyebrow("Потом"); Rows(store, rest, td) }
  } else if (itNext != null) {
    StatePill("Сегодня " + (KINDS[itNext.kind ?: "other"] ?: "").lowercase(), false, Modifier.rise(1))
    CountCard(dur(itNext.m - m), "до начала", Modifier.rise(2)) { Times("Начало в " + itNext.time, "") }
    LessonHead(itNext, Modifier.rise(3))
    NoteBlock(store, itNext, td, open, Modifier.rise(4))
    val rest = its.filter { it.m > itNext.m }
    if (rest.isNotEmpty()) Column(Modifier.rise(5), verticalArrangement = Arrangement.spacedBy(8.dp)) { Eyebrow("Потом"); Rows(store, rest, td) }
  } else if (its.isNotEmpty()) {
    val lastIt = its.last()
    StatePill("Сегодня " + (KINDS[lastIt.kind ?: "other"] ?: "").lowercase(), true, Modifier.rise(1))
    Eyebrow("Начало было в " + lastIt.time, Modifier.rise(2))
    LessonHead(lastIt, Modifier.rise(3))
    NoteBlock(store, lastIt, td, open, Modifier.rise(4))
  } else {
    NextDay(store, nav, sc, td, list.isNotEmpty(), Modifier.rise(1))
  }
}

// Ближайший день с парами, когда сегодня всё закончилось
@Composable
fun NextDay(store: Store, nav: Nav, sc: Sched, td: LocalDate, hadToday: Boolean, modifier: Modifier) {
  val found = remember(td, store.rev) {
    (1..120).asSequence().map { td.plusDays(it.toLong()) }.firstOrNull { sc.active(sc.lessonsFor(it)).isNotEmpty() || sc.itemsFor(it).isNotEmpty() }
  }
  val done = if (hadToday) "Пары на сегодня закончились" else if (sc.inSession(td)) "Сегодня экзаменов нет"
    else if (td > sc.endAll) "Учёба закончилась" else if (td > sc.last) "Занятия закончились" else "Сегодня пар нет"
  Column(modifier, verticalArrangement = Arrangement.spacedBy(16.dp)) {
    Text(done, style = d(27, 700), color = P.fg)
    if (found != null) {
      val nl = sc.active(sc.lessonsFor(found)); val ni = sc.itemsFor(found)
      val l = nl.firstOrNull()
      if (l != null) {
        Eyebrow(dayLabel(found, td) + ", первая в " + sc.pairTime(l.p).first)
        sc.lessonsFor(found).filter { it.cancel }.forEach { CancelNote(store, it) }
        LessonHead(l)
        NoteBlock(store, l, found, nav::openNote)
      } else ni.firstOrNull()?.let { it ->
        val dd = daysBetween(td, found)
        if (dd > 1) CountCard("$dd " + plural(dd, "день", "дня", "дней"), "до " + (KGEN[it.kind ?: "other"] ?: "")) {}
        Eyebrow(dayLabel(found, td) + ", " + (KINDS[it.kind ?: "other"] ?: "").lowercase() + " в " + it.time)
        LessonHead(it)
        NoteBlock(store, it, found, nav::openNote)
      }
    }
  }
}

fun dayLabel(nd: LocalDate, td: LocalDate): String {
  val dd = daysBetween(td, nd)
  return if (dd == 1) "Завтра" else if (dd == 2) "Послезавтра" else WHEN[weekday(nd)] + ", ${dnum(nd)} " + MONF[mnum(nd)]
}

@Composable
fun StatePill(text: String, live: Boolean, modifier: Modifier = Modifier) {
  val a = if (live) rememberInfiniteTransition(label = "p").animateFloat(1f, 0.25f,
    infiniteRepeatable(tween(800), RepeatMode.Reverse), label = "pa").value else 1f
  Row(modifier.border(1.dp, P.line, CircleShape).padding(start = 10.dp, end = 12.dp, top = 5.dp, bottom = 5.dp),
    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
    Box(Modifier.size(8.dp).alpha(a).clip(CircleShape).background(P.live))
    Text(text, style = b(13, 600), color = P.fg)
  }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CountCard(big: String, label: String, modifier: Modifier = Modifier, extra: @Composable ColumnScope.() -> Unit) {
  ElevatedCard(modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp),
    colors = CardDefaults.elevatedCardColors(containerColor = P.surface)) {
    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
      FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.Bottom) {
        Text(big, style = m(52, 700).copy(letterSpacing = (-1).sp), color = P.fg)
        Text(label, Modifier.align(Alignment.Bottom).padding(bottom = 10.dp), style = b(15), color = P.muted)
      }
      extra()
    }
  }
}

@Composable
fun Times(a: String, b2: String) {
  Row(Modifier.fillMaxWidth()) {
    Text(a, style = m(13), color = P.muted); Spacer(Modifier.weight(1f)); Text(b2, style = m(13), color = P.muted)
  }
}
