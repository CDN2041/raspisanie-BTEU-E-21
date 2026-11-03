@file:OptIn(ExperimentalTextApi::class)

package by.cdn2041.pary

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// ---------- Цвета: те же, что на сайте ----------
data class Pal(
  val bg: Color, val surface: Color, val fg: Color, val muted: Color, val line: Color,
  val warn: Color, val note: Color, val noteSoft: Color, val live: Color, val onLive: Color,
) {
  val liveSoft get() = live.copy(alpha = 0.26f)
  val pastSoft get() = muted.copy(alpha = 0.24f)
}
private val LightPal = Pal(Color(0xFFEDEFF3), Color(0xFFFFFFFF), Color(0xFF141821), Color(0xFF646C7E), Color(0xFFD7DBE4),
  Color(0xFFB4231B), Color(0xFFA86A12), Color(0xFFFBF0DC), Color(0xFF141821), Color(0xFFEDEFF3))
private val DarkPal = Pal(Color(0xFF050608), Color(0xFF101318), Color(0xFFE8EBF1), Color(0xFF8B93A5), Color(0xFF1F242D),
  Color(0xFFFF7A70), Color(0xFFE8A94B), Color(0xFF21180A), Color(0xFFE8EBF1), Color(0xFF050608))

val LocalPal = staticCompositionLocalOf { LightPal }
val P: Pal @Composable get() = LocalPal.current

private fun siteScheme(p: Pal, dark: Boolean): ColorScheme {
  val base = if (dark) darkColorScheme() else lightColorScheme()
  return base.copy(
    primary = p.fg, onPrimary = p.bg, primaryContainer = p.fg, onPrimaryContainer = p.bg,
    secondary = p.muted, onSecondary = p.bg, secondaryContainer = p.line, onSecondaryContainer = p.fg,
    tertiary = p.note, onTertiary = p.bg, tertiaryContainer = p.noteSoft, onTertiaryContainer = p.note,
    background = p.bg, onBackground = p.fg, surface = p.bg, onSurface = p.fg,
    surfaceVariant = p.line, onSurfaceVariant = p.muted, outline = p.muted, outlineVariant = p.line,
    surfaceContainerLowest = p.surface, surfaceContainerLow = p.surface, surfaceContainer = p.surface,
    surfaceContainerHigh = p.surface, surfaceContainerHighest = p.line, surfaceBright = p.surface, surfaceDim = p.bg,
    error = p.warn, onError = p.bg, inverseSurface = p.fg, inverseOnSurface = p.bg, scrim = Color.Black,
  )
}

@Composable
fun AppTheme(theme: String, colors: String, content: @Composable () -> Unit) {
  val dark = when (theme) { "dark" -> true; "light" -> false; else -> isSystemInDarkTheme() }
  val dyn = colors == "dynamic" && Build.VERSION.SDK_INT >= 31
  val ctx = LocalContext.current
  val scheme: ColorScheme; val pal: Pal
  if (dyn) {
    scheme = if (dark) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
    val s = if (dark) DarkPal else LightPal
    pal = Pal(scheme.surface, scheme.surfaceContainer, scheme.onSurface, scheme.onSurfaceVariant, scheme.outlineVariant,
      scheme.error, s.note, s.noteSoft, scheme.primary, scheme.onPrimary)
  } else {
    pal = if (dark) DarkPal else LightPal
    scheme = siteScheme(pal, dark)
  }
  CompositionLocalProvider(LocalPal provides pal) {
    MaterialTheme(colorScheme = scheme, typography = typo(), content = content)
  }
}

// ---------- Шрифты: Golos Text, Unbounded, JetBrains Mono ----------
private fun fam(id: Int) = FontFamily(listOf(400, 500, 600, 700).map {
  Font(id, FontWeight(it), variationSettings = FontVariation.Settings(FontVariation.weight(it)))
})
val Golos = fam(R.font.golos)
val Unbounded = fam(R.font.unbounded)
val Mono = fam(R.font.jbmono)

fun b(size: Int, w: Int = 400) = TextStyle(fontFamily = Golos, fontWeight = FontWeight(w), fontSize = size.sp)
fun d(size: Int, w: Int = 700) = TextStyle(fontFamily = Unbounded, fontWeight = FontWeight(w), fontSize = size.sp, lineHeight = (size * 1.2).sp)
fun m(size: Int, w: Int = 500) = TextStyle(fontFamily = Mono, fontWeight = FontWeight(w), fontSize = size.sp)

private fun typo(): Typography {
  val t = Typography()
  return t.copy(
    bodyLarge = t.bodyLarge.copy(fontFamily = Golos), bodyMedium = t.bodyMedium.copy(fontFamily = Golos),
    bodySmall = t.bodySmall.copy(fontFamily = Golos), labelLarge = t.labelLarge.copy(fontFamily = Golos, fontWeight = FontWeight(600)),
    labelMedium = t.labelMedium.copy(fontFamily = Golos, fontWeight = FontWeight(600)), labelSmall = t.labelSmall.copy(fontFamily = Golos),
    titleLarge = t.titleLarge.copy(fontFamily = Unbounded, fontWeight = FontWeight(500)), titleMedium = t.titleMedium.copy(fontFamily = Golos),
  )
}
