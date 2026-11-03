package by.cdn2041.pary

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DateRange
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
  override fun onCreate(b: Bundle?) {
    super.onCreate(b)
    intent.getStringExtra("shot_screen")?.let { Shot.screen = it }
    Shot.now = Shot.parse(intent.getStringExtra("shot_now"))
    Shot.theme = intent.getStringExtra("shot_theme")
    val store = App.store(this)
    store.migrate()
    setContent {
      val dark = when (store.theme) { "dark" -> true; "light" -> false; else -> isSystemInDarkTheme() }
      LaunchedEffect(dark) {
        val st = if (dark) SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
          else SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT)
        enableEdgeToEdge(st, st)
      }
      AppTheme(store.theme, store.colors) { Root(store) }
    }
  }
}

// Одно хранилище на процесс: его же видит виджет
object App {
  private var s: Store? = null
  fun store(a: android.content.Context): Store = s ?: Store(a.applicationContext).also { s = it }
}

@Composable
fun Root(store: Store) {
  val nav = remember { Nav() }
  val life = LocalLifecycleOwner.current
  // Пока приложение на экране: проверяем расписание сразу и потом раз в пять минут
  LaunchedEffect(Unit) {
    life.repeatOnLifecycle(Lifecycle.State.STARTED) {
      store.touch()
      while (true) { store.fetch(); delay(300_000) }
    }
  }
  LaunchedEffect(store.sched != null) {
    val sc = store.sched ?: return@LaunchedEffect
    nav.sel = sc.clamp(sc.studyDay(store.now().toLocalDate()))
    if (store.ui == "old") nav.tab = 1
    when (Shot.screen) {
      "full", "calendar" -> nav.tab = 1
      "home", "settings", "note" -> nav.tab = 0
    }
    when (Shot.screen) {
      "settings" -> nav.settings = true
      "calendar" -> nav.calendar = true
      "note" -> {
        val t = store.now(); val l = sc.lessonsFor(t.toLocalDate()).firstOrNull { canNote(it) }
        if (l != null) nav.openNote(t.toLocalDate(), l)
      }
    }
  }
  Surface(Modifier.fillMaxSize(), color = P.bg) {
    when {
      store.sched != null -> Scaffold(containerColor = P.bg, contentWindowInsets = WindowInsets(0),
        bottomBar = { BottomBar(nav) }) { pad ->
        Box(Modifier.padding(pad)) {
          AnimatedContent(nav.tab, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "tab") {
            if (it == 0) HomeScreen(store, nav) else FullScreen(store, nav)
          }
        }
        BackHandler(nav.tab == 1 && store.ui == "new") { nav.tab = 0 }
        Sheets(store, nav)
      }
      store.status == "error" -> Column(Modifier.fillMaxSize().padding(32.dp), verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally) {
        Text(store.errTitle, style = d(20, 600), color = P.fg, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text(store.errText, style = b(15), color = P.muted, textAlign = TextAlign.Center)
      }
      else -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
    }
  }
}

@Composable
private fun BottomBar(nav: Nav) {
  val tap = haptic()
  NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainer) {
    NavigationBarItem(nav.tab == 0, { if (nav.tab != 0) tap(); nav.tab = 0 }, { Icon(Icons.Outlined.Home, null) }, label = { Text("Сейчас") })
    NavigationBarItem(nav.tab == 1, { if (nav.tab != 1) tap(); nav.tab = 1 }, { Icon(Icons.Outlined.DateRange, null) }, label = { Text("Расписание") })
  }
}

// Редактор: та же страница сайта внутри приложения
class EditorActivity : ComponentActivity() {
  private var web: WebView? = null
  @SuppressLint("SetJavaScriptEnabled")
  override fun onCreate(b: Bundle?) {
    super.onCreate(b)
    enableEdgeToEdge()
    val store = App.store(this)
    setContent {
      AppTheme(store.theme, store.colors) {
        Surface(Modifier.fillMaxSize(), color = P.bg) {
          AndroidView({ c ->
            WebView(c).apply {
              settings.javaScriptEnabled = true
              settings.domStorageEnabled = true
              settings.setSupportZoom(false)
              overScrollMode = WebView.OVER_SCROLL_NEVER
              webViewClient = WebViewClient()
              setBackgroundColor(android.graphics.Color.TRANSPARENT)
              loadUrl(SITE + "admin.html")
              web = this
            }
          }, Modifier.fillMaxSize().systemBarsPadding().imePadding())
        }
      }
    }
  }
  @Deprecated("Deprecated in Java")
  override fun onBackPressed() { val w = web; if (w != null && w.canGoBack()) w.goBack() else super.onBackPressed() }
  override fun onStop() {
    super.onStop()
    // Изменения из редактора сразу подтягиваем в приложение
    kotlinx.coroutines.MainScope().launchFetch(App.store(this))
  }
}

private fun kotlinx.coroutines.CoroutineScope.launchFetch(s: Store) { launch { s.fetch(force = true) } }
