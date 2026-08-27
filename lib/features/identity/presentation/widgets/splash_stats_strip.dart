import 'dart:ui' as ui;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Der Kennzahlen-Streifen des Startbildschirms, `screen-auth.jsx:315-327`.
///
/// Die beiden Zahlen sind in der Quelle **hartcodiert** und werden hier
/// hartcodiert übernommen. Sie kommen nicht aus der Datenbank: `950+` ist eine
/// gerundete Angabe, `4` die Zahl der freigeschalteten Städte. Sobald echte
/// Zahlen erwünscht sind, ist das eine Produktentscheidung samt Abfrage und
/// Ladezustand, nicht eine stille Änderung an diesem Widget.
///
/// Die Beschriftungen kommen aus `splash.statsFacts` und `splash.statsCities`
/// und werden per `text-transform: uppercase` großgeschrieben. Wie beim
/// Untertitel der Wortmarke steht die Umwandlung im Code, damit die
/// Sprachdateien den Text so tragen wie die PWA.
class SplashStatsStrip extends StatelessWidget {
  /// Erzeugt den Streifen. [strings] liefert die beiden Beschriftungen.
  const SplashStatsStrip({required this.strings, super.key});

  /// Anzahl der Fakten, `val: '950+'`.
  static const String factsValue = '950+';

  /// Anzahl der Städte, `val: '4'`.
  static const String citiesValue = '4';

  /// Texte der aktiven Sprache.
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: BackdropFilter(
        // `backdropFilter: 'blur(12px)'`: der CSS-Parameter ist die
        // Standardabweichung der Gaußfunktion und geht damit unverändert als
        // Sigma weiter.
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        // `Container` und nicht `DecoratedBox` plus `Padding`: nur `Container`
        // schlägt die Rahmenstärke als zusätzlichen Innenabstand auf, und CSS
        // rechnet hier mit `box-sizing: border-box`.
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromRGBO(0, 0, 0, 0.35),
            borderRadius: BorderRadius.all(Radius.circular(18)),
            border: Border.fromBorderSide(
              BorderSide(color: Color.fromRGBO(255, 255, 255, 0.08)),
            ),
          ),
          // `padding: '12px 8px'`.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          // `IntrinsicHeight`, damit der Trenner die volle Höhe bekommt: CSS
          // streckt Flex-Kinder standardmäßig, Flutters `Row` zentriert sie.
          // `CrossAxisAlignment.stretch` allein genügt nicht, es braucht eine
          // begrenzte Höhe, und die hat die Zeile in einer Spalte nicht.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // `gap: 8` gilt in CSS zwischen **allen** Kindern, also auch
              // zwischen Zelle und Trenner.
              spacing: 8,
              children: <Widget>[
                _cell(factsValue, strings.text('splash.statsFacts')),
                const SizedBox(
                  width: 1,
                  child: ColoredBox(color: Color.fromRGBO(255, 255, 255, 0.1)),
                ),
                _cell(citiesValue, strings.text('splash.statsCities')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.center,
            style: FactTypography.emphasis.copyWith(
              fontSize: 20,
              height: 1,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: FactTypography.mono.copyWith(
              fontSize: 8,
              color: const Color.fromRGBO(255, 255, 255, 0.45),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
