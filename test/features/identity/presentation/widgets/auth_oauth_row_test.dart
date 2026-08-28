import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/identity/presentation/pages/login_page.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_oauth_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Die Zeile der beiden Fremdanmeldungen.
///
/// Gegenstand ist ausschließlich die **Höhengleichheit** der beiden Knöpfe.
/// `display: flex` steht in CSS auf `align-items: stretch`, Flutters `Row`
/// dagegen auf `center`. Der Unterschied wird erst sichtbar, wenn eine der
/// beiden Beschriftungen umbricht und die andere nicht, also bei großer
/// Systemschrift.
///
/// Warum hier gemessen wird und nicht in `login_page_test.dart`: die Zeile ist
/// ein geteilter Baustein, Anmeldung und Registrierung bauen dieselbe. Eine
/// Messung am Baustein deckt beide ab, statt sie zu verdoppeln.
///
/// **Ein `takeException()`-Test würde hier nichts sichern.** Ein Umbruch ist
/// kein Überlauf, Flutter meldet ihn nicht. Genau daran ist dieser Defekt
/// vorbeigekommen. Deshalb echte Rechtecke.
///
/// ## Woher die Höhen kommen, seit Materials Zeilenhöhe raus ist
///
/// Die Knopfhöhe ist `padding` plus Zeilenkasten, also 12 + Zeile + 12
/// (`screen-auth.jsx:536` und `:540`: `padding: '12px'`, `fontSize: 14`,
/// `fontWeight: 800`, **keine** `lineHeight`).
///
/// Bis zum 29.08.2026 maß dieser Test den Zeilenkasten mit Materials
/// `height: 1.43`, den `bodyMedium` über das `Material` des `Scaffold`
/// vererbte. Die Quelle kennt diesen Wert nicht: `styles.css` enthält
/// `line-height` kein einziges Mal, hier steht keine am Element, der Browser
/// rechnet also mit `line-height: normal`. In Flutter heißt das `height: null`,
/// und damit gelten die Metriken der Schrift.
///
/// Nunito trägt (aus `assets/fonts/Nunito-ExtraBold.ttf`, Tabellen `head`,
/// `hhea` und `OS/2`) 1011 Einheiten Oberlänge und 353 Einheiten Unterlänge auf
/// 1000 Einheiten pro Geviert, Durchschuss 0. Das sind 1.364 Geviert je Zeile.
///
/// Bei 14 Pixeln: 14.154 oben und 4.942 unten. Flutter rundet Ober- und
/// Unterlänge je Zeile einzeln auf ganze Pixel, also 14 + 5 = **19**. Bei 28
/// Pixeln (Systemschrift 2.0): 28.308 und 9.884, also 28 + 10 = **38**.
///
/// **Die Rundung selbst ist aus der Quelle nicht herleitbar.** Sie ist
/// Flutters Umgang mit den Schriftmetriken; ein Browser rundet an dieser Stelle
/// nicht. Herleitbar aus Quelle und Schriftdatei sind 19.096 und 38.192, die
/// Ganzzahl daneben ist gemessen. Deshalb stehen unten runde Werte und keine
/// Toleranzen: eine Toleranz würde genau den Unterschied verstecken, um den es
/// hier geht.
void main() {
  // Ohne echte Schriften ist jede Glyphe ein Quadrat der Schriftgröße, und die
  // Frage, ob "Mit Google" umbricht, wäre an einem Layout gemessen, das es auf
  // keinem Gerät gibt.
  setUpAll(loadAppFonts);

  /// Beide Bildschirme stellen die Zeile in eine `Column` mit
  /// `CrossAxisAlignment.stretch` innerhalb eines `SingleChildScrollView`, und
  /// legen [LoginPage.formHorizontalPadding] links und rechts an.
  ///
  /// Das Scroll-Umfeld ist **Teil des Prüfgegenstands** und keine Bequemlichkeit:
  /// dort ist die Höhe unbeschränkt, und ein `CrossAxisAlignment.stretch` ohne
  /// den `IntrinsicHeight`-Rahmen wirft genau hier.
  Future<void> pumpRow(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    tester.view
      ..physicalSize = Size(width * 3, 844 * 3)
      ..devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: FactTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: LoginPage.formHorizontalPadding,
                  ),
                  child: AuthOAuthRow(
                    appleLabel: 'Mit Apple',
                    googleLabel: 'Mit Google',
                    comingSoonHint: 'Bald verfügbar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Die beiden Knopfflächen. `Opacity` und nicht `Container`: der Deckkraft-
  /// Rahmen liegt außen und hat genau die Fläche, die der Nutzer als Knopf
  /// sieht.
  ({Rect apple, Rect google}) buttons(WidgetTester tester) {
    final found = find.descendant(
      of: find.byType(AuthOAuthRow),
      matching: find.byType(Opacity),
    );
    return (
      apple: tester.getRect(found.at(0)),
      google: tester.getRect(found.at(1)),
    );
  }

  group('AuthOAuthRow', () {
    testWidgets('bei Skalierung 2.0 auf 390 sind beide Knöpfe gleich hoch, '
        'obwohl nur "Mit Google" umbricht', (tester) async {
      // Der eigentliche Defekt. Gemessen mit `center` am 28.08.2026, damals
      // noch mit Materials Zeilenhöhe: "Mit Apple" 64 Pixel, "Mit Google" 104,
      // der schmalere Knopf schwebte mittig neben dem höheren.
      await pumpRow(tester, width: 390, textScale: 2);

      final rects = buttons(tester);
      // Erst die Vorbedingung: bricht keine der beiden Beschriftungen um, misst
      // der Test nichts. Eine Zeile ist 38 hoch (vorher 40), zwei sind 76
      // (vorher 80). Herleitung im Dateikopf.
      expect(tester.getRect(find.text('Mit Apple')).height, 38);
      expect(tester.getRect(find.text('Mit Google')).height, 76);

      expect(rects.apple.height, rects.google.height);
      // 12 + 76 + 12. Vorher 104, mit Materials 1.43 auf zwei Zeilen.
      expect(rects.apple.height, 100);
      // Und gleich hoch heißt auch: gleich oben und gleich unten. Ohne das
      // bliebe ein zentrierter Knopf gleicher Höhe unentdeckt.
      expect(rects.apple.top, rects.google.top);
      expect(rects.apple.bottom, rects.google.bottom);
    });

    testWidgets('bei Skalierung 2.0 auf 360 brechen beide um und bleiben '
        'gleich hoch', (tester) async {
      await pumpRow(tester, width: 360, textScale: 2);

      final rects = buttons(tester);
      expect(rects.apple.height, rects.google.height);
      // 12 + 2 mal 38 + 12. Vorher 104.
      expect(rects.apple.height, 100);
    });

    // Zwei eigene Tests und keine Schleife: eine Schleife meldet nur, dass
    // irgendeine Breite scheitert, und nicht welche.
    for (final width in <double>[390, 360]) {
      testWidgets('bei Skalierung 1.0 auf ${width.toInt()} ändert die '
          'Streckung nichts', (tester) async {
        // Zugesichert wird hier die **Abwesenheit** einer Nebenwirkung: bei
        // normaler Systemschrift passt jede Beschriftung in eine Zeile, und
        // beide Knöpfe sind 43 hoch, also 12 + 19 + 12. Vorher stand hier 44,
        // weil Materials `height: 1.43` den Zeilenkasten auf 20 aufblies.
        await pumpRow(tester, width: width, textScale: 1);

        final rects = buttons(tester);
        expect(rects.apple.height, 43);
        expect(rects.google.height, 43);
        expect(rects.apple.top, rects.google.top);
      });
    }

    testWidgets('die beiden Knöpfe teilen die Breite und lassen die Lücke', (
      tester,
    ) async {
      await pumpRow(tester, width: 390, textScale: 1);

      final rects = buttons(tester);
      expect(rects.apple.width, rects.google.width);
      expect(rects.google.left - rects.apple.right, AuthOAuthRow.gap);
      expect(rects.apple.left, LoginPage.formHorizontalPadding);
      expect(rects.google.right, 390 - LoginPage.formHorizontalPadding);
    });
  });
}
