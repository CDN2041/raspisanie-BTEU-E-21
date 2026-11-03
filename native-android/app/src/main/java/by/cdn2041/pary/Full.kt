package by.cdn2041.pary

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.DateRange
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import java.time.LocalDate
import java.time.LocalDateTime

// Полное расписание: неделя сверху, дни листаются пальцем
@Composable
fun FullScreen(store: Store, nav: Nav) {
  val sc = store.sched ?: return
  val t = rememberNow(store)
  LaunchedEffect(store.rev) { nav.sel = sc.clamp(nav.sel) }
  val tap = haptic()
  key(store.rev) {
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
      Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Header(store, nav, sc, t)
        WeekNav(store, nav, sc)
        Strip(store, nav, sc, t)
      }
      val days = sc.allDays
      val idx0 = days.indexOf(nav.sel).coerceAtLeast(0)
      val ps = rememberPagerState(idx0) { days.size }
      // Выбор дня сверху листает страницы, перелистывание пальцем меняет выбранный день
      LaunchedEffect(nav.sel) {
        val i = days.indexOf(nav.sel)
        if (i >= 0 && i != ps.currentPage) {
          if (kotlin.math.abs(i - ps.currentPage) > 6) ps.scrollToPage(i) else ps.animateScrollToPage(i)
        }
      }
      LaunchedEffect(ps.settledPage) {
        val d = days.getOrNull(ps.settledPage) ?: return@LaunchedEffect
        if (d != nav.sel) { tap(); nav.sel = d }
      }
      HorizontalPager(ps, Modifier.weight(1f), beyondViewportPageCount = 1, key = { days[it].toEpochDay() }) { p ->
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(top = 4.dp)) {
          DayList(store, nav, sc, days[p], t)
          if (store.ui == "old") VersionFooter(store)
        }
      }
    }
  }
}

@Composable
private fun Header(store: Store, nav: Nav, sc: Sched, t: LocalDateTime) {
  val sel = nav.sel; val mon = mondayOf(sel)
  val n = weeksBetween(sc.studyDay(t.toLocalDate()), sel)
  val rel = when { n == 0 -> "эта неделя"; n == 1 -> "следующая неделя"; n == -1 -> "прошлая неделя"; n > 1 -> "через $n нед."; else -> "${-n} нед. назад" }
  val title = if (sc.weekInSession(mon)) "Сессия" else if (sc.weekType(sel) == "over") "Над чертой" else "Под чертой"
  val tap = haptic()
  Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
      Eyebrow(rel)
      AnimatedContent(title, transitionSpec = { (fadeIn() + slideInVertically { it / 4 }) togetherWith fadeOut() }, label = "t") {
        Text(it, style = d(28, 700), color = P.fg)
      }
    }
    FilledTonalIconButton(onClick = { tap(); nav.calendar = true }, Modifier.size(52.dp)) { Icon(Icons.Outlined.DateRange, "Календарь") }
    if (store.ui == "old") FilledTonalIconButton(onClick = { tap(); nav.settings = true }, Modifier.size(52.dp)) { Icon(Icons.Outlined.Settings, "Настройки") }
  }
}

fun shownDays(sc: Sched, mon: LocalDate) = minOf(sc.daysIn(mon), maxOf(1, daysBetween(mon, sc.endAll) + 1))
fun rangeText(mon: LocalDate, n: Int): String {
  val e = mon.plusDays((n - 1).toLong())
  return if (mnum(mon) == mnum(e)) "${dnum(mon)}–${dnum(e)} " + MONF[mnum(mon)] else "${dnum(mon)} " + MON[mnum(mon)] + " – ${dnum(e)} " + MON[mnum(e)]
}

@Composable
private fun WeekNav(store: Store, nav: Nav, sc: Sched) {
  val mon = mondayOf(nav.sel); val nd = shownDays(sc, mon)
  val prevOff = sc.beforeStart(mon.minusDays(1)); val nextOff = sc.afterEnd(mon.plusDays(7))
  val tap = haptic()
  Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
    IconButton(onClick = { tap(); nav.sel = sc.clamp(mon.minusDays(7)) }, enabled = !prevOff) {
      Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Прошлая неделя")
    }
    AnimatedContent(rangeText(mon, nd), Modifier.weight(1f), transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "r") {
      Text(it, Modifier.fillMaxWidth(), style = b(15, 600), color = P.fg, textAlign = TextAlign.Center, maxLines = 1)
    }
    IconButton(onClick = { tap(); nav.sel = sc.clamp(mon.plusDays(7)) }, enabled = !nextOff) {
      Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Следующая неделя")
    }
    FilledTonalButton(onClick = { tap(); nav.sel = sc.clamp(sc.studyDay(store.now().toLocalDate())) }) { Text("Сегодня") }
  }
}

// Дни недели: нажать или зажать и вести пальцем
@Composable
private fun Strip(store: Store, nav: Nav, sc: Sched, t: LocalDateTime) {
  val mon = mondayOf(nav.sel); val nd = shownDays(sc, mon); val today = t.toLocalDate()
  val idx = daysBetween(mon, nav.sel).coerceIn(0, nd - 1)
  var w by remember { mutableIntStateOf(1) }
  var drag by remember { mutableStateOf<Int?>(null) }
  val tap = haptic()
  val shown = drag ?: idx
  val cellW = w.toFloat() / nd
  val x by animateDpAsState(with(androidx.compose.ui.platform.LocalDensity.current) { (cellW * shown).toDp() },
    spring(dampingRatio = 0.8f, stiffness = 500f), label = "x")
  val density = androidx.compose.ui.platform.LocalDensity.current
  fun at(px: Float) = (px / cellW).toInt().coerceIn(0, nd - 1)
  fun ok(i: Int) = !sc.beforeStart(mon.plusDays(i.toLong()))
  Box(Modifier.fillMaxWidth().height(64.dp).clip(RoundedCornerShape(22.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh)
    .border(1.dp, P.line, RoundedCornerShape(22.dp)).padding(3.dp)
    .onSizeChanged { w = it.width }
    .pointerInput(nd, mon) {
      detectTapGestures { o -> val i = at(o.x); if (ok(i)) { tap(); nav.sel = mon.plusDays(i.toLong()) } }
    }
    .pointerInput(nd, mon) {
      detectDragGesturesAfterLongPress(
        onDragStart = { o -> drag = at(o.x); tap() },
        onDrag = { c, _ -> val i = at(c.position.x); if (i != drag && ok(i)) { drag = i; tap() } },
        onDragEnd = { drag?.let { nav.sel = mon.plusDays(it.toLong()) }; drag = null },
        onDragCancel = { drag = null },
      )
    }) {
    // Выделение выбранного дня; при перетаскивании чуть крупнее, как линза
    val lift by animateDpAsState(if (drag != null) 3.dp else 0.dp, label = "l")
    Box(Modifier.offset(x = x - lift).padding(vertical = 0.dp)
      .width(with(density) { cellW.toDp() } + lift * 2).fillMaxHeight()
      .clip(RoundedCornerShape(19.dp)).background(if (store.dayHasNote(mon.plusDays(shown.toLong()))) P.note else P.live))
    Row(Modifier.fillMaxSize()) {
      for (i in 0 until nd) {
        val dd = mon.plusDays(i.toLong())
        val c = sc.active(sc.lessonsFor(dd)).size; val its = sc.itemsFor(dd)
        val lbl = if (c > 0) "$c п." else if (its.isNotEmpty()) KSHORT[its[0].kind ?: "other"] ?: "" else "·"
        val sel = i == shown; val isT = dd == today; val hn = store.dayHasNote(dd)
        val on = P.onLive
        Column(Modifier.weight(1f).fillMaxHeight().alpha(if (ok(i)) 1f else 0.3f).then(
          if (hn && !sel) Modifier.padding(2.dp).clip(RoundedCornerShape(17.dp)).background(P.noteSoft) else Modifier),
          horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
          Text(DSHORT[i], style = b(12, 600), color = if (sel) on.copy(alpha = 0.75f) else if (hn) P.note else if (isT) P.fg else P.muted)
          Text("${dnum(dd)}", style = m(17, 700), color = if (sel) on else if (hn) P.note else P.fg.copy(alpha = if (isT) 1f else 0.8f),
            textDecoration = if (isT && !sel) TextDecoration.Underline else null)
          Text(lbl, style = b(11), color = if (sel) on.copy(alpha = 0.75f) else if (hn) P.note else P.muted)
        }
      }
    }
  }
}

// ---------- День ----------
@Composable
fun DayList(store: Store, nav: Nav, sc: Sched, d: LocalDate, t: LocalDateTime) {
  val today = t.toLocalDate(); val m = nowMin(t)
  val list = sc.lessonsFor(d); val its = sc.itemsFor(d)
  val cmp = d.compareTo(today).coerceIn(-1, 1)
  Column(Modifier.fillMaxWidth().padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
    if (list.isEmpty() && its.isEmpty()) {
      Column(Modifier.fillMaxWidth().card(16.dp, P.surface, P.line).padding(vertical = 40.dp, horizontal = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(if (sc.inSession(d)) "Экзаменов нет" else "Пар нет", style = d(18, 500), color = P.fg)
        Text(DAYS_FULL[weekday(d)] + ", ${dnum(d)} " + MONF[mnum(d)], style = b(15), color = P.muted)
      }
    } else {
      list.forEachIndexed { i, l ->
        if (i > 0) {
          val p = list[i - 1]
          GapView(if (l.p - p.p > 1) 2 else if (sc.isBig(p, l)) 1 else 0, p.b, l.a, m, cmp)
        }
        LessonCard(store, nav, l, d, cmp, m)
      }
      its.forEach { ItemCard(store, nav, it, d, cmp) }
    }
  }
}

@Composable
fun LessonCard(store: Store, nav: Nav, l: Lesson, d: LocalDate, cmp: Int, m: Int) {
  val isNow = !l.cancel && cmp == 0 && m >= l.a && m < l.b
  val isPast = cmp < 0 || (cmp == 0 && m >= l.b)
  val nt = store.note(d, l)
  val tm = store.sched?.pairTime(l.p) ?: ("" to "")
  Box(Modifier.alpha(if (l.cancel) 0.55f else if (isPast && nt == null) 0.45f else 1f)) {
    Row(Modifier.fillMaxWidth().card(16.dp, P.surface, if (isNow) P.live else P.line, if (isNow) 2.dp else 1.dp)
      .padding(14.dp).padding(end = if (canNote(l)) 26.dp else 0.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
      Column(Modifier.width(62.dp)) {
        Text("${l.p} ПАРА", Modifier.padding(bottom = 2.dp), style = b(11, 600), color = P.muted)
        Text(tm.first, style = m(17, 700), color = P.fg)
        Text(tm.second, style = m(13), color = P.muted)
      }
      CardBody(l, d, nt) {
        if (isNow) {
          val left = leftOf(l, m)
          Spacer(Modifier.height(6.dp))
          PairBar(l.a, l.b, m, l.h1, l.h2)
          Text(left.first + dur(left.second), style = b(12, 600), color = P.live)
        }
      }
    }
    if (canNote(l)) Pen(nt != null, Modifier.align(Alignment.TopEnd)) { nav.openNote(d, l) }
  }
}

@Composable
fun Pen(has: Boolean, modifier: Modifier, onClick: () -> Unit) {
  val tap = haptic()
  IconButton(onClick = { tap(); onClick() }, modifier.padding(4.dp)) {
    Icon(Icons.Outlined.Edit, "Заметка", tint = if (has) P.note else P.muted)
  }
}

@Composable
fun RowScope.CardBody(l: Lesson, d: LocalDate, note: String?, extra: @Composable ColumnScope.() -> Unit) {
  Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
    Tags(tags(l, d))
    Text(l.s, style = b(16, 600), color = P.fg, textDecoration = if (l.cancel) TextDecoration.LineThrough else null)
    if (l.tch.isNotEmpty()) Text(l.tch, style = b(14), color = P.muted)
    if (l.was.isNotEmpty()) Text("Вместо: " + l.was, style = b(12), color = P.muted)
    if (l.r.isNotEmpty()) Row(verticalAlignment = Alignment.Bottom) {
      Text("ауд. ", style = b(12), color = P.muted); Text(l.r, style = m(13), color = P.fg)
    }
    extra()
    if (note != null) {
      DashLine(Modifier.fillMaxWidth().padding(top = 2.dp))
      Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(Icons.Outlined.Edit, null, Modifier.size(14.dp), tint = P.note)
        Text(note.lines().first(), style = b(13), color = P.note, maxLines = 1)
      }
    }
  }
}

// Событие сессии в полном расписании
@Composable
fun ItemCard(store: Store, nav: Nav, l: Lesson, d: LocalDate, cmp: Int) {
  val nt = store.note(d, l)
  Box(Modifier.alpha(if (cmp < 0 && nt == null) 0.45f else 1f)) {
    Row(Modifier.fillMaxWidth().card(16.dp, P.surface, P.line).padding(14.dp).padding(end = 26.dp),
      horizontalArrangement = Arrangement.spacedBy(12.dp)) {
      Column(Modifier.width(62.dp)) {
        Text("НАЧАЛО", Modifier.padding(bottom = 2.dp), style = b(11, 600), color = P.muted)
        Text(l.time, style = m(17, 700), color = P.fg)
      }
      CardBody(l, d, nt) {}
    }
    Pen(nt != null, Modifier.align(Alignment.TopEnd)) { nav.openNote(d, l) }
  }
}

// Перерывы между парами: 0 обычный, 1 большой, 2 окно
@Composable
fun GapView(kind: Int, gs: Int, ge: Int, m: Int, cmp: Int) {
  val on = cmp == 0 && m >= gs && m < ge
  val fill = if (cmp < 0) 1f else if (cmp > 0) 0f else ((m - gs).toFloat() / maxOf(1, ge - gs)).coerceIn(0f, 1f)
  val col = if (on) P.live else P.muted
  val soft = if (on) P.liveSoft else P.pastSoft
  val line = if (on) P.live else P.line
  fun Modifier.box(r: Dp) = drawBehind {
    drawRoundRect(soft, size = size.copy(width = size.width * fill), cornerRadius = CornerRadius(r.toPx()))
    drawRoundRect(line, cornerRadius = CornerRadius(r.toPx()), style = Stroke(1.dp.toPx(),
      pathEffect = if (on) null else PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
  }
  when (kind) {
    0 -> Row(Modifier.fillMaxWidth().box(10.dp).padding(horizontal = 14.dp, vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
      Text(dur(ge - gs), Modifier.width(62.dp), style = m(12), color = col)
      Text(if (on) "Перерыв, ещё " + dur(ge - m) else "Перерыв", style = b(12, if (on) 600 else 400), color = col)
    }
    1 -> Row(Modifier.fillMaxWidth().box(16.dp).padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
      Column(Modifier.weight(1f)) {
        Text("Большой перерыв", style = b(15, 600), color = col)
        Text(fmtMin(gs) + " – " + fmtMin(ge), style = m(12), color = col.copy(alpha = 0.8f))
      }
      Text(if (on) "ещё " + dur(ge - m) else dur(ge - gs), style = b(13, 600), color = col)
    }
    else -> Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
      DashLine(Modifier.weight(1f))
      Text("Окно " + dur(ge - gs) + (if (on) ", ещё " + dur(ge - m) else ""), style = b(13, if (on) 600 else 400), color = col)
      DashLine(Modifier.weight(1f))
    }
  }
}
