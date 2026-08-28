import 'package:fact_app/app/startup_failure_app.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Startabbruch muss dem Entwickler sagen, was zu tun ist.
///
/// `bootstrap()` fängt [SupabaseConfigurationError] ab und zeigt statt der App
/// diesen Bildschirm. Das ist nur dann besser als ein Absturz, wenn der
/// `--dart-define`-Befehl auch wirklich darauf steht.
void main() {
  const config = SupabaseConfig(url: '', publishableKey: '');

  Future<void> pumpFailure(WidgetTester tester) async {
    final error = SupabaseConfigurationError(config.missingRequirements);
    await tester.pumpWidget(StartupFailureApp(problem: error.toString()));
    await tester.pumpAndSettle();
  }

  testWidgets('nennt die fehlenden Werte und den --dart-define-Befehl', (
    tester,
  ) async {
    await pumpFailure(tester);

    expect(find.text('FACT konnte nicht starten'), findsOneWidget);

    final shown = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.data ?? '')
        .join('\n');

    expect(shown, contains('--dart-define'));
    expect(shown, contains(SupabaseConfig.urlVariable));
    expect(shown, contains(SupabaseConfig.publishableKeyVariable));
  });

  group('Textstil', () {
    // Am 28.08.2026 auf dem Emulator gesehen, nicht im Test: **beide** Texte
    // dieses Bildschirms trugen eine gelbe Doppellinie. Das ist Flutters
    // Notsignal für Text ohne `Material`-Vorfahren (`_errorTextStyle` in
    // `material/app.dart`). Der `home` war ein `ColoredBox`, und ein
    // `ColoredBox` setzt keinen `DefaultTextStyle`.
    //
    // Der Test prüft **keine** Ausnahme, weil es keine gibt: `takeException()`
    // bleibt leer, Flutter meldet davon nichts. Er misst die Eigenschaft, also
    // die Dekoration des wirksamen Stils. Dieselbe Lücke wie beim
    // Tutorial-Overlay, siehe die Gruppe "Textstil" in
    // `test/app/onboarding/tour_overlay_test.dart`.

    /// Der wirksame Stil jedes sichtbaren Textes, mit seinem Klartext.
    ///
    /// Zwei Quellen, weil die Seite zwei Sorten Text zeichnet. `Text` merged
    /// den `DefaultTextStyle` in seinem `build` und gibt das Ergebnis an
    /// `RichText` weiter, dort steht es am `RenderParagraph`. `SelectableText`
    /// macht denselben Merge (`selectable_text.dart:745-751`), rendert aber
    /// über `EditableText` in ein `RenderEditable` und taucht deshalb in
    /// `find.byType(RichText)` gar nicht auf. Wer nur Absätze einsammelt,
    /// übersieht ausgerechnet die technische Meldung.
    List<(String, TextStyle?)> effectiveStyles(WidgetTester tester) {
      return <(String, TextStyle?)>[
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.byType(RichText),
        ))
          (paragraph.text.toPlainText(), paragraph.text.style),
        for (final editable in tester.widgetList<EditableText>(
          find.byType(EditableText),
        ))
          (editable.controller.text, editable.style),
      ];
    }

    testWidgets('kein Text trägt eine Dekoration', (tester) async {
      await pumpFailure(tester);

      final styles = effectiveStyles(tester);
      // Ohne diese Zusicherung wäre eine leere Liste ein grüner Test.
      expect(
        styles,
        hasLength(2),
        reason: 'erwartet: Überschrift und Meldung, gemessen: $styles',
      );

      for (final (text, style) in styles) {
        final decoration = style?.decoration;
        expect(
          decoration == null || decoration == TextDecoration.none,
          isTrue,
          reason:
              'Text "$text" trägt $decoration. Fehlt ein Material-Vorfahren?',
        );
      }
    });

    testWidgets('die Farben bleiben die aus den Tokens', (tester) async {
      await pumpFailure(tester);

      // Ein `Material` bringt sein eigenes Textthema mit. Beide Stile setzen
      // ihre Farbe selbst, das darf der Merge nicht überschreiben.
      final byText = <String, TextStyle?>{
        for (final (text, style) in effectiveStyles(tester)) text: style,
      };

      expect(byText['FACT konnte nicht starten']?.color, FactColors.dark.red);
      expect(
        byText.entries
            .firstWhere((entry) => entry.key.contains('--dart-define'))
            .value
            ?.color,
        FactColors.dark.ink2,
      );
    });

    testWidgets('kein Text erbt Materials Laufweite oder Zeilenhöhe', (
      tester,
    ) async {
      // Gemessen, nicht befürchtet: nimmt man dem `Material` seinen
      // `textStyle`, erben beide Texte aus `theme.textTheme.bodyMedium` ein
      // `letterSpacing: 0.25` und ein `height` von rund 1.43. E-38 nimmt diese
      // Laufweite aus FACT-Text heraus. `FactTheme` erledigt das sonst, aber
      // diese `MaterialApp` installiert es bewusst nicht.
      await pumpFailure(tester);

      final byText = <String, TextStyle?>{
        for (final (text, style) in effectiveStyles(tester)) text: style,
      };
      final heading = byText['FACT konnte nicht starten'];

      expect(heading?.letterSpacing, isNull);
      // Die Überschrift setzt keine Zeilenhöhe; die Meldung setzt 1.5 selbst.
      expect(heading?.height, isNull);
      expect(
        byText.entries
            .firstWhere((entry) => entry.key.contains('--dart-define'))
            .value
            ?.height,
        1.5,
      );
    });
  });

  group('Fläche', () {
    testWidgets(
      'der Hintergrund ist die Token-Farbe und füllt den Bildschirm',
      (tester) async {
        await pumpFailure(tester);

        // Nicht "irgendwo liegt die Farbe", sondern: die eine Fläche, die den
        // Material-Vorfahren stellt, trägt sie und deckt alles ab. Ein
        // `Material` nur um die Spalte herum wäre beides nicht.
        final surface = find.byType(Material);
        expect(surface, findsOneWidget);
        expect(tester.widget<Material>(surface).color, FactColors.dark.bg);
        expect(
          tester.getRect(surface),
          Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio,
        );
      },
    );
  });

  group('Bedienbarkeit', () {
    testWidgets('die Meldung bleibt auswählbar', (tester) async {
      await pumpFailure(tester);

      // Aus dieser Meldung kopiert man den `--dart-define`-Befehl. Ein
      // gewöhnlicher `Text` wäre auf dem Gerät nicht markierbar, und das fällt
      // niemandem auf, bis jemand ihn abtippen muss.
      final message = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(message.data, contains('--dart-define'));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        isTrue,
        reason: 'auswählbar heißt lesen und markieren, nicht bearbeiten',
      );
    });
  });
}
