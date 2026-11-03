package by.cdn2041.pary

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.json.JSONTokener
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

const val SITE = "https://cdn2041.github.io/raspisanie-BTEU-E-21/"

// Скриншоты из эмулятора: время, экран и тема приходят в интенте
object Shot {
  var now: LocalDateTime? = null
  var screen: String? = null
  var theme: String? = null
  val on get() = screen != null
  fun parse(s: String?): LocalDateTime? = try {
    s?.let { LocalDateTime.parse(it, DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")) }
  } catch (e: Exception) { null }
}

// Расписание на диске: общее для приложения и виджета
object Disk {
  fun file(ctx: Context) = File(ctx.filesDir, "schedule.json")
  fun read(ctx: Context): String? {
    val f = file(ctx)
    if (f.exists()) try { return f.readText() } catch (_: Exception) {}
    return try { ctx.assets.open("schedule.json").bufferedReader().use { it.readText() } } catch (e: Exception) { null }
  }
  fun write(ctx: Context, s: String) {
    val tmp = File(ctx.filesDir, "schedule.json.tmp")
    tmp.writeText(s); tmp.renameTo(file(ctx))
  }
  fun prefs(ctx: Context) = ctx.getSharedPreferences("pary", Context.MODE_PRIVATE)
  fun load(ctx: Context): Sched? {
    val p = prefs(ctx)
    return Sched.make(Sched.parse(read(ctx)), p.getString("pary-e21-p2", null) == "1", p.getString("pary-e21-nofive", null) == "1")
  }

  // Скачать свежее расписание; null, если не получилось
  suspend fun download(): String? = withContext(Dispatchers.IO) {
    try {
      val c = URL(SITE + "schedule.json").openConnection() as HttpURLConnection
      c.useCaches = false; c.connectTimeout = 10000; c.readTimeout = 10000
      c.setRequestProperty("Cache-Control", "no-cache")
      if (c.responseCode != 200) null else c.inputStream.bufferedReader().use { it.readText() }
    } catch (e: Exception) { null }
  }
}

class Store(private val ctx: Context) {
  var sched by mutableStateOf<Sched?>(null); private set
  var status by mutableStateOf("loading"); private set   // loading, ok, error
  var errTitle = ""; var errText = ""
  val notes = mutableStateMapOf<String, String>()
  var ui by mutableStateOf("new")            // new: экран «Сейчас», old: всё расписание
  var theme by mutableStateOf("system")
  var colors by mutableStateOf("site")       // site: цвета сайта, dynamic: Material You
  var p2 by mutableStateOf(false); private set
  var noFive by mutableStateOf(false); private set
  var rev by mutableIntStateOf(0); private set
  var shown by mutableStateOf(LocalDateTime.now()); private set
  private var raw: JSONObject? = null
  private var rawText: String? = null
  private var lastFetch = 0L
  private val ud = Disk.prefs(ctx)

  init {
    ud.getString(NKEY, null)?.let { s -> try { val o = JSONObject(s); o.keys().forEach { notes[it] = o.getString(it) } } catch (_: Exception) {} }
    ud.getString(SKEY, null)?.let { s -> try { applySettings(JSONObject(s)) } catch (_: Exception) {} }
    colors = ud.getString("pary-e21-colors", null) ?: "site"
    p2 = ud.getString("pary-e21-p2", null) == "1"
    noFive = ud.getString("pary-e21-nofive", null) == "1"
    if (Shot.on) {
      theme = Shot.theme ?: "system"
      boot(try { ctx.assets.open("schedule.json").bufferedReader().use { it.readText() } } catch (e: Exception) { null })
      val sc = sched; val n = Shot.now
      if (sc != null && n != null) sc.lessonsFor(n.toLocalDate()).firstOrNull { canNote(it) }?.let {
        notes[noteKey(n.toLocalDate(), it)] = "Сдать реферат и взять методичку"
      }
    } else boot(Disk.read(ctx))
  }

  fun touch() { shown = LocalDateTime.now() }
  fun now(): LocalDateTime = Shot.now ?: maxOf(LocalDateTime.now(), shown)

  private fun applySettings(o: JSONObject) {
    ui = if (o.optString("ui") == "old") "old" else "new"
    val t = o.optString("theme", "system")
    theme = if (t == "dark" || t == "light") t else "system"
  }

  private fun boot(text: String?): Boolean {
    val o = Sched.parse(text) ?: return false
    val s = Sched.make(o, p2, noFive) ?: return false
    raw = o; rawText = text; sched = s; status = "ok"; rev++
    return true
  }
  private fun rebuild() {
    val s = Sched.make(raw, p2, noFive) ?: return
    sched = s; rev++
    Widgets.update(ctx)
  }

  // Свежее расписание с сайта: не чаще раза в минуту
  suspend fun fetch(force: Boolean = false) {
    if (Shot.on || (!force && System.currentTimeMillis() - lastFetch < 60_000)) return
    lastFetch = System.currentTimeMillis()
    val text = Disk.download()
    if (text == null) {
      if (sched == null) { errTitle = "Нет связи"; errText = "Расписание загрузится, когда появится интернет."; status = "error" }
      return
    }
    val o = Sched.parse(text)
    if (o == null) {
      if (sched == null) { errTitle = "Ошибка в расписании"; errText = "Файл расписания повреждён. Сообщите старосте."; status = "error" }
      return
    }
    val newU = o.optDouble("updated", 0.0); val oldU = raw?.optDouble("updated", 0.0) ?: 0.0
    if (raw != null && oldU > newU && System.currentTimeMillis() - oldU < 15 * 60000) return
    if (text == rawText) return
    withContext(Dispatchers.IO) { Disk.write(ctx, text) }
    boot(text)
    Widgets.update(ctx)
  }

  fun note(d: LocalDate, l: Lesson): String? = if (canNote(l)) notes[noteKey(d, l)] else null
  fun dayHasNote(d: LocalDate): Boolean { val k = key(d); return notes.keys.any { it.startsWith(k) } }
  fun setNote(k: String, v: String?) {
    val t = v?.trim() ?: ""
    if (t.isEmpty()) notes.remove(k) else notes[k] = t
    saveNotes()
  }
  private fun saveNotes() {
    if (Shot.on) return
    ud.edit().putString(NKEY, JSONObject(notes.toMap() as Map<*, *>).toString()).apply()
  }
  fun saveSettings() {
    if (Shot.on) return
    ud.edit().putString(SKEY, JSONObject().put("ui", ui).put("theme", theme).toString())
      .putString("pary-e21-colors", colors).apply()
  }
  fun toggleP2() {
    p2 = !p2
    ud.edit().apply { if (p2) putString("pary-e21-p2", "1") else remove("pary-e21-p2") }.apply()
    rebuild()
  }
  fun setNoFiveFlag(v: Boolean) {
    if (v == noFive) return
    noFive = v
    ud.edit().apply { if (v) putString("pary-e21-nofive", "1") else remove("pary-e21-nofive") }.apply()
    rebuild()
  }

  // Перенос заметок и настроек из старой версии-сайта: они лежат в localStorage её WebView
  @SuppressLint("SetJavaScriptEnabled")
  fun migrate(done: () -> Unit = {}) {
    if (Shot.on || ud.getBoolean("migrated-v1", false)) return
    val w = WebView(ctx)
    w.settings.javaScriptEnabled = true
    w.settings.domStorageEnabled = true
    w.webViewClient = object : WebViewClient() {
      var fired = false
      override fun onPageFinished(view: WebView, url: String?) {
        if (fired) return
        fired = true
        view.evaluateJavascript("JSON.stringify({n:localStorage.getItem('pary-notes-v1'),s:localStorage.getItem('pary-settings-v1'),p2:localStorage.getItem('pary-e21-p2'),nf:localStorage.getItem('pary-e21-nofive')})") { r ->
          try {
            val o = JSONObject(JSONTokener(r).nextValue() as String)
            o.optString("n").takeIf { it.isNotEmpty() && it != "null" }?.let { s ->
              val n = JSONObject(s); n.keys().forEach { k -> if (!notes.containsKey(k)) notes[k] = n.getString(k) }
              saveNotes()
            }
            if (ud.getString(SKEY, null) == null) o.optString("s").takeIf { it.isNotEmpty() && it != "null" }?.let {
              applySettings(JSONObject(it)); saveSettings()
            }
            if (o.optString("p2") == "1" && !p2) toggleP2()
            if (o.optString("nf") == "1") setNoFiveFlag(true)
          } catch (_: Exception) {}
          ud.edit().putBoolean("migrated-v1", true).apply()
          view.destroy()
          done()
        }
      }
    }
    w.loadDataWithBaseURL(SITE, "<html><body></body></html>", "text/html", "utf-8", null)
  }

  companion object { const val NKEY = "pary-notes-v1"; const val SKEY = "pary-settings-v1" }
}
