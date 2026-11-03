package by.cdn2041.pary

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.LocalDate

// ---------- Мелкие элементы ----------
@Composable
fun Eyebrow(text: String, modifier: Modifier = Modifier, color: Color = P.muted) {
  Text(text.uppercase(), modifier, style = b(12, 600).copy(letterSpacing = 0.72.sp), color = color)
}

fun Modifier.card(r: Dp = 16.dp, bg: Color, border: Color, width: Dp = 1.dp) =
  clip(RoundedCornerShape(r)).background(bg).border(width, border, RoundedCornerShape(r))

fun Modifier.dashed(r: Dp, c: Color) = drawBehind {
  drawRoundRect(c, cornerRadius = CornerRadius(r.toPx()),
    style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
}

// Плавное появление блоков по очереди
fun Modifier.rise(i: Int, on: Boolean = true): Modifier = composed {
  val a = remember { Animatable(if (on) 0f else 1f) }
  LaunchedEffect(Unit) {
    if (on) { kotlinx.coroutines.delay(minOf(i, 8) * 40L); a.animateTo(1f, spring(dampingRatio = 0.86f, stiffness = 300f)) }
  }
  graphicsLayer { alpha = a.value; translationY = (1 - a.value) * 10.dp.toPx() }
}

@Composable
fun haptic(): () -> Unit { val h = LocalHapticFeedback.current; return { h.performHapticFeedback(HapticFeedbackType.TextHandleMove) } }

// Метки пары: лекция, практика, замена и т. п.
enum class TagStyle { LEC, PRAC, MIX, NEW, SUB, CANCEL, EXAM, CREDIT, PLAIN }

fun tags(l: Lesson, d: LocalDate?): List<Pair<String, TagStyle>> {
  val r = mutableListOf<Pair<String, TagStyle>>()
  l.kind?.let { k -> r.add((KINDS[k] ?: "") to (if (k == "exam") TagStyle.EXAM else if (k == "credit") TagStyle.CREDIT else TagStyle.PLAIN)); return r }
  when (l.t) { "lec" -> r.add("Лекция" to TagStyle.LEC); "prac" -> r.add("Практика" to TagStyle.PRAC); "mix" -> r.add("Лекция/Практика" to TagStyle.MIX) }
  if (l.cancel) r.add("Отменена" to TagStyle.CANCEL)
  else if (l.ed) r.add("Изменено" to TagStyle.SUB)
  else if (l.sub == "rep") r.add("Замена" to TagStyle.SUB)
  else if (l.sub == "add") r.add("Доп. пара" to TagStyle.SUB)
  if (d != null && l.from.isNotEmpty() && l.from == key(d)) pd(l.from)?.let { r.add("с ${dnum(it)} ${MON[mnum(it)]}" to TagStyle.NEW) }
  return r
}

@Composable
fun Tag(text: String, st: TagStyle) {
  val fgc = when (st) { TagStyle.PRAC, TagStyle.EXAM -> P.bg; TagStyle.CANCEL -> P.muted; else -> P.fg }
  val fill = when (st) { TagStyle.PRAC, TagStyle.EXAM -> P.fg; TagStyle.NEW -> P.liveSoft; else -> Color.Transparent }
  val sh = RoundedCornerShape(6.dp)
  var mod = Modifier.clip(sh).background(fill)
  mod = when (st) {
    TagStyle.LEC, TagStyle.CANCEL, TagStyle.PLAIN -> mod.border(1.dp, P.muted, sh)
    TagStyle.MIX, TagStyle.CREDIT -> mod.border(1.dp, P.fg, sh)
    TagStyle.SUB -> mod.dashed(6.dp, P.fg)
    else -> mod
  }
  Text(text.uppercase(), mod.padding(horizontal = 6.dp, vertical = 2.dp), style = b(11, 600).copy(letterSpacing = 0.44.sp), color = fgc)
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun Tags(list: List<Pair<String, TagStyle>>) {
  if (list.isEmpty()) return
  FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
    list.forEach { Tag(it.first, it.second) }
  }
}

// Шкала пары: если в звонках есть пятиминутка, она показывается ровно в своё время
@Composable
fun PairBar(s: Int, e: Int, m: Int, h1: Int?, h2: Int?, height: Dp = 4.dp) {
  val live = P.live; val line = P.line
  val split = h1 != null && h2 != null && h1 > s && h2 < e && h2 > h1
  val anim by animateFloatAsState(m.toFloat(), spring(stiffness = Spring.StiffnessLow), label = "bar")
  Canvas(Modifier.fillMaxWidth().height(height)) {
    val hh = size.height; val r = CornerRadius(hh / 2)
    fun seg(x: Float, w: Float, f: Float, dash: Boolean) {
      if (dash) drawRoundRect(line, Offset(x, 0f), androidx.compose.ui.geometry.Size(w, hh), r,
        style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 2.dp.toPx()))))
      else drawRoundRect(line, Offset(x, 0f), androidx.compose.ui.geometry.Size(w, hh), r)
      val fw = w * f.coerceIn(0f, 1f)
      if (fw > 0) drawRoundRect(live, Offset(x, 0f), androidx.compose.ui.geometry.Size(maxOf(fw, minOf(w, hh)), hh), r)
    }
    if (split) {
      val gap = 3.dp.toPx(); val w = size.width - gap * 2; val t = (e - s).toFloat()
      val w1 = w * (h1!! - s) / t; val w2 = w * (h2!! - h1) / t; val w3 = w * (e - h2) / t
      seg(0f, w1, (anim - s) / (h1 - s), false)
      seg(w1 + gap, w2, if (anim < h1) 0f else (anim - h1) / (h2 - h1), true)
      seg(w1 + w2 + gap * 2, w3, if (anim < h2) 0f else (anim - h2) / (e - h2), false)
    } else seg(0f, size.width, (anim - s) / maxOf(1, e - s), false)
  }
}

@Composable
fun SimpleBar(f: Double, height: Dp = 4.dp) {
  val live = P.live; val line = P.line
  val a by animateFloatAsState(f.toFloat().coerceIn(0f, 1f), spring(stiffness = Spring.StiffnessLow), label = "sb")
  Canvas(Modifier.fillMaxWidth().height(height)) {
    val r = CornerRadius(size.height / 2)
    drawRoundRect(line, cornerRadius = r)
    if (a > 0) drawRoundRect(live, size = size.copy(width = maxOf(size.width * a, size.height)), cornerRadius = r)
  }
}

@Composable
fun DashLine(modifier: Modifier = Modifier) {
  val c = P.line
  Canvas(modifier.height(10.dp)) {
    drawLine(c, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 1.dp.toPx(),
      pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx())))
  }
}

// Значок недели: черта и точка над или под ней
@Composable
fun WeekGlyph(over: Boolean, color: Color, modifier: Modifier = Modifier) {
  Canvas(modifier) {
    val w = size.width; val h = size.height
    drawLine(color, Offset(w * 0.12f, h / 2), Offset(w * 0.88f, h / 2), 2.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
    drawCircle(color, w * 0.133f, Offset(w / 2, if (over) h * 0.25f else h * 0.75f))
  }
}

// ---------- Пара на экране «Сейчас» ----------
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LessonHead(l: Lesson, modifier: Modifier = Modifier) {
  Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
    Tags(tags(l, null))
    val long = l.s.split(" ").any { it.length > 13 }
    Text(l.s, style = d(if (long) 22 else 27, 700), color = P.fg)
    if (l.tch.isNotEmpty() || l.r.isNotEmpty()) FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
      if (l.tch.isNotEmpty()) Text(l.tch, style = b(15), color = P.muted)
      if (l.r.isNotEmpty()) Text("ауд. " + l.r, style = b(15), color = P.fg)
    }
    if (l.was.isNotEmpty()) Text("Вместо: " + l.was, style = b(13), color = P.muted)
  }
}

// Кнопка заметки под парой
@Composable
fun NoteBlock(store: Store, l: Lesson, d: LocalDate, open: (LocalDate, Lesson) -> Unit, modifier: Modifier = Modifier) {
  if (!canNote(l)) return
  val t = store.note(d, l)
  val tap = haptic()
  Row(modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).dashed(16.dp, if (t != null) P.note else P.line)
    .clickable { tap(); open(d, l) }.padding(14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
    Icon(Icons.Outlined.Edit, null, Modifier.size(18.dp).padding(top = 2.dp), tint = if (t != null) P.note else P.muted)
    Text(t ?: "Добавить заметку", style = b(15), color = if (t != null) P.fg else P.muted)
  }
}

// Короткий список пар: время, предмет, аудитория
@Composable
fun Rows(store: Store, list: List<Lesson>, d: LocalDate) {
  Column {
    list.forEachIndexed { i, l ->
      Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(if (l.kind != null) l.time else store.sched?.pairTime(l.p)?.first ?: "", Modifier.width(64.dp), style = m(14, 700), color = P.fg)
        Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
          Text(l.s, Modifier.weight(1f, false), style = b(15, 500), maxLines = 1, overflow = TextOverflow.Ellipsis,
            color = if (l.cancel) P.muted else P.fg, textDecoration = if (l.cancel) TextDecoration.LineThrough else null)
          if (store.note(d, l) != null) Box(Modifier.padding(start = 6.dp).size(6.dp).clip(CircleShape).background(P.note))
        }
        Text(if (l.cancel) "отменена" else l.r, Modifier.padding(start = 12.dp), style = m(13), color = P.muted)
      }
      if (i < list.size - 1) HorizontalDivider(color = P.line)
    }
  }
}

@Composable
fun CancelNote(store: Store, l: Lesson) {
  Row(Modifier.fillMaxWidth().dashed(14.dp, P.line).padding(horizontal = 14.dp, vertical = 10.dp),
    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
    Icon(Icons.Filled.Close, null, Modifier.size(16.dp), tint = P.muted)
    Text(buildAnnotatedString {
      append("Отменена ${l.p} пара, ${store.sched?.pairTime(l.p)?.first ?: ""}: ")
      withStyle(SpanStyle(textDecoration = TextDecoration.LineThrough)) { append(l.s) }
    }, style = b(14), color = P.muted)
  }
}

// Номер версии внизу: 20 быстрых нажатий включают режим «телефон 2»
@Composable
fun VersionFooter(store: Store) {
  val ctx = androidx.compose.ui.platform.LocalContext.current
  val v = remember { try { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName ?: "" } catch (e: Exception) { "" } }
  var n by remember { mutableIntStateOf(0) }
  var last by remember { mutableLongStateOf(0L) }
  var flash by remember { mutableStateOf<String?>(null) }
  val h = LocalHapticFeedback.current
  LaunchedEffect(flash) { if (flash != null) { kotlinx.coroutines.delay(900); flash = null } }
  Text(flash ?: "v $v", Modifier.fillMaxWidth().clickable(interactionSource = null, indication = null) {
    val now = System.currentTimeMillis()
    if (now - last > 1500) n = 0
    last = now; n++
    if (n >= 20) { n = 0; val was = store.p2; store.toggleP2(); h.performHapticFeedback(HapticFeedbackType.LongPress); flash = if (was) "·" else "··" }
  }.padding(top = 24.dp, bottom = 8.dp), style = b(12), color = P.muted, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
}
