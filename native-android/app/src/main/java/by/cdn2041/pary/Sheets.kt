@file:OptIn(ExperimentalMaterial3Api::class)

package by.cdn2041.pary

import android.content.Intent
import android.os.Build
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import java.time.LocalDate

class NoteRef(val key: String, val title: String, val day: LocalDate, val label: String)

// Что открыто: вкладка, выбранный день, шторки
class Nav {
  var tab by mutableIntStateOf(0)
  var sel by mutableStateOf(LocalDate.now())
  var settings by mutableStateOf(false)
  var calendar by mutableStateOf(false)
  var note by mutableStateOf<NoteRef?>(null)
  fun openNote(d: LocalDate, l: Lesson) {
    note = NoteRef(noteKey(d, l), l.s, d, if (l.kind != null) (KINDS[l.kind!!] ?: "") + " в " + l.time else "${l.p} пара")
  }
}

@Composable
fun Sheets(store: Store, nav: Nav) {
  if (nav.settings) SettingsSheet(store, nav) { nav.settings = false }
  if (nav.calendar) CalendarSheet(store, nav) { nav.calendar = false }
  nav.note?.let { NoteSheet(store, it) { nav.note = null } }
}

@Composable
private fun Seg(items: List<Pair<String, String>>, value: String, onPick: (String) -> Unit) {
  val tap = haptic()
  SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
    items.forEachIndexed { i, (k, label) ->
      SegmentedButton(selected = value == k, onClick = { tap(); onPick(k) }, shape = SegmentedButtonDefaults.itemShape(i, items.size),
        label = { Text(label, maxLines = 1) })
    }
  }
}

@Composable
fun SettingsSheet(store: Store, nav: Nav, close: () -> Unit) {
  val ctx = LocalContext.current
  ModalBottomSheet(onDismissRequest = close, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
    Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
      Text("Настройки", style = d(19, 500), color = P.fg)
      Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Eyebrow("При открытии")
        Seg(listOf("new" to "Экран «Сейчас»", "old" to "Всё расписание"), store.ui) { store.ui = it; store.saveSettings() }
      }
      Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Eyebrow("Тема")
        Seg(listOf("system" to "Как в системе", "dark" to "Тёмная", "light" to "Светлая"), store.theme) { store.theme = it; store.saveSettings() }
      }
      if (Build.VERSION.SDK_INT >= 31) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Eyebrow("Цвета")
        Seg(listOf("site" to "Как на сайте", "dynamic" to "Цвета обоев"), store.colors) { store.colors = it; store.saveSettings() }
      }
      Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
          Text("Пятиминутки", style = b(16, 500), color = P.fg)
          Text("Перерыв посреди пары на шкале", style = b(13), color = P.muted)
        }
        Switch(checked = !store.noFive, onCheckedChange = { store.setNoFiveFlag(!it) })
      }
      Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedButton(onClick = { close(); ctx.startActivity(Intent(ctx, EditorActivity::class.java)) }, Modifier.weight(1f).height(48.dp)) { Text("Редактор") }
        Button(onClick = close, Modifier.weight(1f).height(48.dp)) { Text("Готово") }
      }
    }
  }
}

@Composable
fun NoteSheet(store: Store, ref: NoteRef, close: () -> Unit) {
  val had = store.notes[ref.key] != null
  var text by remember { mutableStateOf(store.notes[ref.key] ?: "") }
  var ask by remember { mutableStateOf(false) }
  val fr = remember { FocusRequester() }
  ModalBottomSheet(onDismissRequest = close, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
    Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 16.dp).imePadding(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
      Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(ref.title, style = d(19, 500), color = P.fg)
        Text(DAYS_FULL[weekday(ref.day)] + ", ${dnum(ref.day)} " + MONF[mnum(ref.day)] + ", " + ref.label, style = b(14), color = P.muted)
      }
      OutlinedTextField(text, { text = it }, Modifier.fillMaxWidth().heightIn(min = 140.dp).focusRequester(fr),
        placeholder = { Text("Например: сдать реферат, взять методичку") }, textStyle = b(16), shape = RoundedCornerShape(16.dp))
      Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (had) TextButton(onClick = { ask = true }, Modifier.height(48.dp), colors = ButtonDefaults.textButtonColors(contentColor = P.warn)) { Text("Удалить") }
        OutlinedButton(onClick = close, Modifier.weight(1f).height(48.dp)) { Text("Отмена") }
        Button(onClick = { store.setNote(ref.key, text); close() }, Modifier.weight(1f).height(48.dp)) { Text("Сохранить") }
      }
    }
  }
  LaunchedEffect(Unit) { if (!had) try { kotlinx.coroutines.delay(300); fr.requestFocus() } catch (_: Exception) {} }
  if (ask) AlertDialog(onDismissRequest = { ask = false },
    title = { Text("Удалить заметку?") }, text = { Text("Восстановить её будет нельзя.") },
    confirmButton = { TextButton(onClick = { ask = false; store.setNote(ref.key, null); close() }) { Text("Удалить", color = P.warn) } },
    dismissButton = { TextButton(onClick = { ask = false }) { Text("Отмена") } })
}

@Composable
fun CalendarSheet(store: Store, nav: Nav, close: () -> Unit) {
  val sc = store.sched ?: return
  val lastM = monthStart(sc.endAll); val firstM = sc.first?.let { monthStart(it) }
  fun clampM(d: LocalDate): LocalDate { val n = monthStart(d); return if (n > lastM) lastM else if (firstM != null && n < firstM) firstM else n }
  var month by remember { mutableStateOf(clampM(nav.sel)) }
  var dir by remember { mutableIntStateOf(0) }
  val tap = haptic()
  fun go(d: LocalDate) { tap(); val n = clampM(d); dir = n.compareTo(month).coerceIn(-1, 1); month = n }
  fun pick(d: LocalDate) { if (sc.afterEnd(d)) return; tap(); nav.sel = sc.clamp(d); close() }
  ModalBottomSheet(onDismissRequest = close, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
    Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
      Row(verticalAlignment = Alignment.CenterVertically) {
        Text(MONN[mnum(month)] + " ${month.year}", Modifier.weight(1f), style = d(19, 500), color = P.fg)
        IconButton(onClick = { go(month.minusMonths(1)) }, enabled = firstM == null || month > firstM) {
          Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Прошлый месяц")
        }
        IconButton(onClick = { go(month.plusMonths(1)) }, enabled = month < lastM) {
          Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Следующий месяц")
        }
      }
      AnimatedContent(month, transitionSpec = { (fadeIn() + slideInHorizontally { dir * it / 12 }) togetherWith fadeOut() }, label = "m") { mo ->
        Grid(store, nav, sc, mo, ::pick)
      }
      Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedButton(onClick = {
          val sd = sc.clamp(sc.studyDay(store.now().toLocalDate())); nav.sel = sd
          if (monthStart(sd) != month) go(sd) else tap()
        }, Modifier.weight(1f).height(48.dp)) { Text("Эта неделя") }
        Button(onClick = close, Modifier.weight(1f).height(48.dp)) { Text("Закрыть") }
      }
    }
  }
}

@Composable
private fun Grid(store: Store, nav: Nav, sc: Sched, month: LocalDate, pick: (LocalDate) -> Unit) {
  val today = store.now().toLocalDate(); val sm = mondayOf(nav.sel)
  Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
    Row {
      listOf("Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс").forEach { Text(it, Modifier.weight(1f), style = b(11, 600), color = P.muted, textAlign = TextAlign.Center) }
      Spacer(Modifier.width(36.dp))
    }
    for (r in 0 until 6) {
      val m = mondayOf(month).plusWeeks(r.toLong())
      Row(Modifier.clip(RoundedCornerShape(12.dp)).background(if (m == sm) MaterialTheme.colorScheme.surfaceContainerHighest else androidx.compose.ui.graphics.Color.Transparent),
        verticalAlignment = Alignment.CenterVertically) {
        for (i in 0 until 7) {
          val d = m.plusDays(i.toLong())
          val off = sc.afterEnd(d) || sc.beforeStart(d); val other = d.monthValue != month.monthValue
          val isT = d == today; val isS = d == nav.sel; val hn = store.dayHasNote(d); val hasX = sc.itemsFor(d).isNotEmpty()
          Box(Modifier.weight(1f).height(44.dp).alpha(if (off) 0.2f else 1f).clickable(enabled = !off) { pick(sc.studyDay(d)) },
            contentAlignment = Alignment.Center) {
            Box(Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(if (isT) P.live else androidx.compose.ui.graphics.Color.Transparent)
              .then(if (isS && !isT) Modifier.border(1.5.dp, P.fg, RoundedCornerShape(10.dp))
                else if (hasX && !isS && !isT) Modifier.border(1.5.dp, P.muted, RoundedCornerShape(10.dp)) else Modifier),
              contentAlignment = Alignment.Center) {
              Text("${dnum(d)}", style = m(15, if (isT) 700 else 500),
                color = if (isT) P.onLive else if (other) P.fg.copy(alpha = 0.3f) else if (i == 6) P.muted else P.fg)
              if (hn) Box(Modifier.align(Alignment.BottomCenter).padding(bottom = 3.dp).size(4.dp).clip(CircleShape).background(P.note))
            }
          }
        }
        val offW = sc.afterEnd(m) || sc.beforeStart(m.plusDays(6))
        Box(Modifier.width(36.dp).height(44.dp).alpha(if (offW) 0.2f else 1f).clickable(enabled = !offW) {
          val sd = sc.studyDay(today); pick(if (mondayOf(sd) == m) sd else sc.studyDay(m))
        }, contentAlignment = Alignment.Center) {
          WeekGlyph(sc.weekType(m) == "over", P.muted, Modifier.size(22.dp))
        }
      }
    }
  }
}
