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
      // Der eigentliche Defekt. Gemessen mit `center`: "Mit Apple" 64 Pixel,
      // "Mit Google" 104, der schmalere Knopf schwebte mittig neben dem
      // höheren.
      await pumpRow(tester, width: 390, textScale: 2);

      final rects = buttons(tester);
      // Erst die Vorbedingung: bricht keine der beiden Beschriftungen um, misst
      // der Test nichts. Eine Zeile ist 40 hoch, zwei sind 80.
      expect(tester.getRect(find.text('Mit Apple')).height, 40);
      expect(tester.getRect(find.text('Mit Google')).height, 80);

      expect(rects.apple.height, rects.google.height);
      expect(rects.apple.height, 104);
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
      expect(rects.apple.height, 104);
    });

    // Zwei eigene Tests und keine Schleife: eine Schleife meldet nur, dass
    // irgendeine Breite scheitert, und nicht welche.
    for (final width in <double>[390, 360]) {
      testWidgets('bei Skalierung 1.0 auf ${width.toInt()} ändert die '
          'Streckung nichts', (tester) async {
        // Zugesichert wird hier die **Abwesenheit** einer Nebenwirkung: bei
        // normaler Systemschrift passt jede Beschriftung in eine Zeile, und
        // beide Knöpfe sind 44 hoch, also 12 + 20 + 12 wie vor der Korrektur.
        await pumpRow(tester, width: width, textScale: 1);

        final rects = buttons(tester);
        expect(rects.apple.height, 44);
        expect(rects.google.height, 44);
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
