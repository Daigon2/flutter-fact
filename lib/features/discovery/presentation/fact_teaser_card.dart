/// Die Mini-Vorschau eines Fakts, der zu weit weg ist,
/// `02_Frontend/app/screen-map.jsx:3844-3901`.
///
/// ## Sie ist das Erlebnis, nicht ein Ersatz für die Akte
///
/// Der Kommentar an der Fundstelle sagt es wörtlich: „KEIN onClick mehr. Die
/// Vorschau IST das Erlebnis fuer entfernte Fakten; der Detail-Screen darf nur
/// vor Ort geoeffnet werden, sonst kann man die Stadt vom Sofa aus
/// durchlesen." Deshalb ist hier **nichts** anklickbar außer dem Schließen.
/// Wer der Zeile mit dem Titel ein `onTap` gibt, hebt die Vor-Ort-Mechanik
/// wieder aus, und zwar an der unauffälligsten denkbaren Stelle.
///
/// ## Die Zeile ohne Ortung hat in der PWA keinen Schlüssel
///
/// `:3856-3858` schreibt beide Sprachen direkt ins JSX
/// (`lang === 'en' ? '🔒 Location unknown — too far' : '🔒 Standort unbekannt
/// — zu weit weg'`). Der Neubau nimmt beide wörtlich über die
/// Ergänzungs-Map (E-39, `map.teaser.locationUnknown`). **Das ist nicht der
/// E-28-Fall**: dort zeigt die PWA den nackten Schlüsselnamen, weil der
/// Schlüssel fehlt, hier zeigt sie fertigen Text in beiden Sprachen und führt
/// ihn nur nicht als Schlüssel.
///
/// ## Eine Abweichung: die Einblendung ohne den Sprung am Ende
///
/// `animation:'factToastIn 0.25s ease'` (`:3846`), und `factToastIn` beginnt
/// mit `translateX(-50%)` (`index.html:45`). Die Karte sitzt aber auf
/// `left:14; right:14` und **nicht** auf `left:50%`; das Keyframe stammt von
/// den mittigen Toasts. Ohne `forwards` fällt die Verschiebung am Ende der 250
/// Millisekunden weg, die Karte springt also um die halbe eigene Breite nach
/// rechts, sobald die Einblendung durch ist. Das ist ein gemessener Fehler der
/// Quelle und keine Vorlage; übernommen sind Dauer, Kurve, das Aufsteigen um
/// zehn Pixel, der Maßstab und das Aufblenden, genau wie in
/// `challenges/presentation/widgets/challenge_toast.dart`, das dieselbe
/// Entscheidung schon getroffen hat.
library;

import 'dart:ui' show ImageFilter;

import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:flutter/widgets.dart';

/// Wie die Entfernung in der Vorschau geschrieben wird, `screen-map.jsx:305`.
///
/// `m < 1000 ? Math.round(m) + ' m' : (m / 1000).toFixed(1) + ' km'`.
///
/// **Mit Leerzeichen vor der Einheit**, und das ist der Unterschied zu
/// `formatHuntPillDistance` in `challenges` (`:1098`, ohne Leerzeichen). Zwei
/// Formatierer sind hier keine Verdopplung, sondern zwei verschiedene
/// Schreibweisen derselben Quelle; sie zusammenzulegen hieße, eine von beiden
/// stillschweigend zu ändern.
///
/// Die Einheiten stehen als Literale und nicht als Übersetzungsschlüssel, aus
/// derselben Erwägung wie dort: ein Einheitenzeichen ist kein Lesetext, und
/// die Quelle übersetzt es ebenfalls nicht.
String formatFactTeaserDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Die Farben der Vorschau im hellen Zustand, `:3859-3862`.
///
/// **Nur die helle Fassung**, aus demselben Grund wie bei
/// `MapChromePalette`: `mapDark` wird in der Quelle nie `true`, siehe
/// `MapTopChrome.isDark`. Die dunklen Werte stehen dort trotzdem, weil sie
/// dort vollständig sind; hier wären sie Vorrat (ADR-002).
abstract final class FactTeaserPalette {
  /// `rgba(255,248,238,0.97)`, `:3859`.
  static const Color background = Color.fromRGBO(255, 248, 238, 0.97);

  /// `rgba(140,100,40,0.18)`, `:3860`.
  static const Color border = Color.fromRGBO(140, 100, 40, 0.18);

  /// `#1A1208`, `:3861`.
  static const Color title = Color(0xFF1A1208);

  /// `rgba(90,70,40,0.55)`, `:3862`.
  static const Color meta = Color.fromRGBO(90, 70, 40, 0.55);

  /// `0 8px 32px rgba(0,0,0,0.12)`, `:3873`.
  static const BoxShadow shadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.12),
    offset: Offset(0, 8),
    blurRadius: 32,
  );

  /// `rgba(0,0,0,0.06)`, Fläche des Schließen-Knopfes, `:3895`.
  static const Color closeBackground = Color.fromRGBO(0, 0, 0, 0.06);
}

/// Die Vorschau selbst.
///
/// Bekommt fertige Texte herein und liest keinen Provider: die Auflösung von
/// Titel, Entfernungszeile und Hinweis hängt an Sprache und Faktenliste, und
/// beides gehört dem Aufrufer. So ist diese Datei ohne Riverpod prüfbar.
class FactTeaserCard extends StatelessWidget {
  /// Erzeugt die Vorschau.
  const FactTeaserCard({
    required this.style,
    required this.title,
    required this.distanceLine,
    required this.hint,
    required this.onClose,
    super.key,
  });

  /// `bottom: 110`, `:3845`.
  static const double bottomOffset = 110;

  /// `left: 14, right: 14`, `:3845`.
  static const double horizontalInset = 14;

  /// `borderRadius: 22`, `:3870`.
  static const double cornerRadius = 22;

  /// `backdropFilter: 'blur(20px)'`, `:3869`.
  static const double blurSigma = 20;

  /// `gap: 12`, `:3867`.
  static const double gap = 12;

  /// Maße der Kategorie-Blase, `width:48, height:48`, `:3877`.
  static const double bubbleSize = 48;

  /// `borderRadius: 14` der Blase, `:3877`.
  static const double bubbleRadius = 14;

  /// Maße des Schließen-Knopfes, `width:32, height:32`, `:3894`.
  static const double closeSize = 32;

  /// `borderRadius: 10` des Knopfes, `:3894`.
  static const double closeRadius = 10;

  /// Dauer der Einblendung, `factToastIn 0.25s`, `:3846`.
  static const Duration fadeIn = Duration(milliseconds: 250);

  /// Farbe und Zeichen der Kategorie, für die Blase links.
  final FactCategoryStyle style;

  /// Der Titel des Fakts, `factField(teaserFact, 'titel', lang)`, `:3888`.
  final String title;

  /// Die Zeile darüber, entweder `🔒 320 m entfernt` oder die Zeile ohne
  /// Ortung. Fertig zusammengesetzt, siehe Klassenkommentar.
  final String distanceLine;

  /// Die Zeile darunter, `t('map.walkToCollect', lang)`, `:3891`.
  final String hint;

  /// Das `×` rechts, `:3894`.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = const BorderRadius.all(
      Radius.circular(cornerRadius),
    );
    Widget card = Container(
      // `padding: '12px 14px 12px 12px'`, `:3871`.
      padding: const EdgeInsets.only(left: 12, top: 12, right: 14, bottom: 12),
      decoration: BoxDecoration(
        color: FactTeaserPalette.background,
        borderRadius: radius,
        border: Border.all(color: FactTeaserPalette.border),
      ),
      child: Row(
        // `alignItems: 'center'`, `:3867`.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _bubble(),
          const SizedBox(width: gap),
          // `flex: 1, minWidth: 0`, `:3886`.
          Expanded(child: _text()),
          const SizedBox(width: gap),
          _close(),
        ],
      ),
    );
    card = ClipRRect(
      borderRadius: radius,
      // Sigma gleich dem CSS-Wert, siehe die Begründung in
      // `map_top_chrome/map_chrome_surface.dart`.
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: card,
      ),
    );
    // Der Schatten außerhalb des Clips, sonst schneidet ihn derselbe Clip
    // weg. Dieselbe Reihenfolge wie in `_Blurred`.
    card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const <BoxShadow>[FactTeaserPalette.shadow],
      ),
      child: card,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: fadeIn,
      // `ease`, nicht `ease-out`: `:3846` gegen `:4417` in der Quelle.
      curve: Curves.ease,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
      ),
      child: card,
    );
  }

  /// Die Kategorie-Blase links, `:3876-3880`.
  Widget _bubble() => Container(
    width: bubbleSize,
    height: bubbleSize,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      // `${c.color}22`, also die Kategoriefarbe mit Alpha 0x22.
      color: style.color.withAlpha(0x22),
      borderRadius: const BorderRadius.all(Radius.circular(bubbleRadius)),
      // `1.5px solid ${c.color}55`.
      border: Border.all(color: style.color.withAlpha(0x55), width: 1.5),
    ),
    // `fontSize: 22`, `:3879`.
    child: Text(style.emoji, style: const TextStyle(fontSize: 22)),
  );

  /// Die drei Zeilen in der Mitte, `:3886-3893`.
  Widget _text() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        // `textTransform: 'uppercase'`, `:3887`. Wie überall im Neubau am
        // Widget und nicht im Wörterbuch.
        distanceLine.toUpperCase(),
        maxLines: 1,
        // `fontFamily:'JetBrains Mono', fontSize:9, fontWeight:600,
        // letterSpacing:0.2`, `:3887`.
        style: FactTypography.mono.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: FactTeaserPalette.meta,
        ),
      ),
      // `marginBottom: 2` der Zeile darüber, `:3887`.
      const SizedBox(height: 2),
      Text(
        title,
        // `whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'`,
        // `:3890`.
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        // `fontFamily:'Nunito', fontWeight:900, fontSize:15,
        // lineHeight:1.2`, `:3890`.
        style: FactTypography.emphasis.copyWith(
          fontSize: 15,
          height: 1.2,
          color: FactTeaserPalette.title,
        ),
      ),
      // `marginTop: 2` der Zeile darunter, `:3891`.
      const SizedBox(height: 2),
      Text(
        hint,
        // `fontFamily:'DM Sans', fontSize:11`, `:3891`.
        style: FactTypography.bodyText.copyWith(
          fontSize: 11,
          color: FactTeaserPalette.meta,
        ),
      ),
    ],
  );

  /// Der Schließen-Knopf, `:3894-3899`.
  ///
  /// **`HitTestBehavior.opaque`**, und das ist eine bezahlte Lehre aus der
  /// Jagd-Pille: ohne sie reagiert der Knopf nur auf das `×` selbst und nicht
  /// auf die 32 Pixel Fläche daneben, obwohl in der Quelle das ganze `div`
  /// klickbar ist.
  Widget _close() => GestureDetector(
    onTap: onClose,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: closeSize,
      height: closeSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: FactTeaserPalette.closeBackground,
        borderRadius: BorderRadius.all(Radius.circular(closeRadius)),
      ),
      child: Text(
        '×',
        // `fontSize: 16`, `:3898`.
        style: FactTypography.bodyText.copyWith(
          fontSize: 16,
          color: FactTeaserPalette.meta,
        ),
      ),
    ),
  );
}
