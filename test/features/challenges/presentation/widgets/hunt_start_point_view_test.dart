import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/challenges/application/hunt_start_options.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_start_point_view.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Der Startpunkt-Picker, `HotspotPickView` in
/// `02_Frontend/app/screen-challenge.jsx:2979-3102`.
///
/// ## Der Rahmen bildet die Kette der App nach
///
/// `MaterialApp` mit `FactTheme`, darunter ein `Scaffold`, wie in
/// `challenges_page_test.dart`. Ohne beides erben die Texte Flutters
/// `_errorTextStyle` statt `theme.textTheme.bodyMedium`, und jede Maßzahl wäre
/// belegt, grün und trotzdem nicht das, was der Nutzer sieht (E-40).
///
/// ## Die Zeilen kommen fertig herein
///
/// Gerechnet wird in `hunt_start_options.dart`, geprüft in dessen eigener
/// Testdatei. Hier steht, was der Bildschirm daraus macht: welcher Text zu
/// welcher Beschriftung gehört, welche Zeile vorausgewählt ist, und welcher
/// Punkt beim Tippen herauskommt.
void main() {
  setUpAll(loadAppFonts);

  // Ein `tap()`, das danebengeht, schreibt sonst nur eine Warnung und lässt
  // den Test grün weiterlaufen.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Future<void> pump(
    WidgetTester tester, {
    required List<HuntStartOption> options,
    void Function(MapPosition point)? onPick,
    VoidCallback? onBack,
    Size size = const Size(390, 844),
    double textScale = 1,
    AppLanguage language = AppLanguage.de,
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
        ],
        child: MaterialApp(
          theme: FactTheme.light(),
          home: Scaffold(
            body: HuntStartPointView(
              options: options,
              onPick: onPick ?? (MapPosition _) {},
              onBack: onBack ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppStrings stringsOf([AppLanguage language = AppLanguage.de]) =>
      AppStrings.of(language);

  group('Kopfbereich', () {
    testWidgets('zeigt Zähler, Überschrift und Unterzeile', (
      WidgetTester tester,
    ) async {
      await pump(tester, options: _twoOptions);

      // `:3055`, in Großbuchstaben durch `textTransform` am Element (`:3054`).
      expect(find.text('SCHRITT 3 VON 3'), findsOneWidget);
      expect(
        find.text(stringsOf().text('challenge.hotspot.title')),
        findsOneWidget,
      );
      expect(
        find.text(stringsOf().text('challenge.hotspot.subtitle')),
        findsOneWidget,
      );
    });

    testWidgets('der Zähler ist auf Englisch übersetzt', (
      WidgetTester tester,
    ) async {
      await pump(tester, options: _twoOptions, language: AppLanguage.en);

      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      expect(find.text('Where do you start?'), findsOneWidget);
    });
  });

  group('Die Zeilen', () {
    testWidgets('„Hier wo ich bin" trägt die gezählte Beschriftung', (
      WidgetTester tester,
    ) async {
      await pump(tester, options: _twoOptions);

      expect(find.text('Hier wo ich bin'), findsOneWidget);
      // `:3005`, mit Haken und nicht mit Diamant.
      expect(find.text('Hohe Faktendichte ✓'), findsOneWidget);
    });

    testWidgets('ein Hotspot trägt Name, Dichte und Fußweg', (
      WidgetTester tester,
    ) async {
      await pump(tester, options: _twoOptions);

      expect(find.text('Marienplatz'), findsOneWidget);
      // `${densityToLabel(h.density)} · ~${walkMin(h.dist)} Min Fußweg`,
      // `:3034`. Das Trennzeichen steht in der Quelle außerhalb des Textes.
      expect(
        find.text('Hohe Faktendichte 💎 · ~17 Min Fußweg'),
        findsOneWidget,
      );
    });

    testWidgets('ohne Fußweg steht nur die Dichte da', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        options: <HuntStartOption>[
          const HuntStartOption(
            point: _marienplatz,
            density: HuntDensityLabel.hotspotMedium,
            hotspotName: 'Odeonsplatz',
          ),
        ],
      );

      expect(find.text('Mittlere Faktendichte ✨'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('jede Beschriftung hat einen Schlüssel und einen Text', (
      WidgetTester tester,
    ) async {
      // Ein neuer Wert von [HuntDensityLabel] fiele sonst erst beim Zeichnen
      // auf, und dann mit einem `null`-Zugriff.
      for (final HuntDensityLabel label in HuntDensityLabel.values) {
        final String? key = HuntStartPointView.densityTextKeys[label];
        expect(key, isNotNull, reason: '$label ohne Schlüssel');
        for (final AppLanguage language in AppLanguage.values) {
          // `AppStrings.text` gibt den Schlüssel selbst zurück, wenn er
          // nirgends steht. Genau das darf hier nicht passieren.
          expect(
            AppStrings.of(language).text(key!),
            isNot(key),
            reason: '$key fehlt in ${language.code}',
          );
        }
      }
    });
  });

  group('Auswahl', () {
    testWidgets('die erste Zeile ist vorausgewählt', (
      WidgetTester tester,
    ) async {
      final List<MapPosition> picked = <MapPosition>[];
      await pump(tester, options: _twoOptions, onPick: picked.add);

      await tester.tap(find.byKey(HuntStartPointView.startKey));
      await tester.pumpAndSettle();

      // `defaultIdx` ist in der Quelle immer 0, `:3040`.
      expect(picked, <MapPosition>[_userPosition]);
    });

    testWidgets('ein Tipp auf die zweite Zeile ändert das Ergebnis', (
      WidgetTester tester,
    ) async {
      final List<MapPosition> picked = <MapPosition>[];
      await pump(tester, options: _twoOptions, onPick: picked.add);

      await tester.tap(find.byKey(HuntStartPointView.optionKey(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HuntStartPointView.startKey));
      await tester.pumpAndSettle();

      expect(picked, <MapPosition>[_marienplatz]);
    });

    testWidgets(
      'eine schrumpfende Liste fängt eine ausgewählte Zeile auf, die es '
      'nicht mehr gibt',
      (WidgetTester tester) async {
        // Die Absturzsicherung aus `didUpdateWidget`: `_selected` bleibt über
        // einen Neuaufbau hinweg bestehen (Absicht, jede neue Ortung
        // sortiert die Hotspots um), aber eine **kürzere** Liste ließe
        // `options[_selected]` sonst auf einen Index zeigen, den es nicht
        // mehr gibt. Ohne die Sicherung wirft erst der Tipp auf den
        // Startknopf, der Neuaufbau selbst bleibt unauffällig.
        final List<MapPosition> picked = <MapPosition>[];
        await pump(tester, options: _fourOptions, onPick: picked.add);
        await tester.tap(find.byKey(HuntStartPointView.optionKey(3)));
        await tester.pumpAndSettle();

        // Derselbe Baum wird mit einer kürzeren Liste neu aufgebaut, kein
        // neues Mounten: `pump` reicht denselben Widgetbaum mit neuen Werten
        // durch, und `didUpdateWidget` läuft auf demselben State-Objekt.
        await pump(tester, options: _twoOptions, onPick: picked.add);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(HuntStartPointView.startKey));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(picked, <MapPosition>[_userPosition]);
      },
    );

    testWidgets('„Zurück" ruft den Rückruf und nicht den Startknopf', (
      WidgetTester tester,
    ) async {
      var backs = 0;
      final List<MapPosition> picked = <MapPosition>[];
      await pump(
        tester,
        options: _twoOptions,
        onPick: picked.add,
        onBack: () => backs++,
      );

      await tester.tap(find.byKey(HuntStartPointView.backKey));
      await tester.pumpAndSettle();

      expect(backs, 1);
      expect(picked, isEmpty);
    });
  });

  group('Ohne jede Auswahl', () {
    testWidgets('zeigt den Hinweis der Quelle und keinen Startknopf', (
      WidgetTester tester,
    ) async {
      // `options.length === 0`, `:3043-3049`.
      await pump(tester, options: const <HuntStartOption>[]);

      expect(
        find.text(stringsOf().text('challenge.hotspot.empty')),
        findsOneWidget,
      );
      expect(find.byKey(HuntStartPointView.startKey), findsNothing);
      expect(find.text('SCHRITT 3 VON 3'), findsNothing);
    });

    testWidgets('der Zurück-Knopf funktioniert auch dort', (
      WidgetTester tester,
    ) async {
      var backs = 0;
      await pump(
        tester,
        options: const <HuntStartOption>[],
        onBack: () => backs++,
      );

      await tester.tap(find.byKey(HuntStartPointView.backKey));
      await tester.pumpAndSettle();

      expect(backs, 1);
    });

    testWidgets(
      'bis zum Hinweistext liegen vierzig Pixel, nicht vierundzwanzig',
      (WidgetTester tester) async {
        // `padding: 24`, `:3045`. Der Absatz `:3046` trägt ohne eigene
        // Schriftgröße den Browser-Standardrand von 16 (1em bei geerbten 16
        // Pixeln), und der kollabiert nicht mit dem Innenabstand des
        // Elternelements: 24 + 16 = 40, siehe
        // [HuntStartPointView.emptyTitleTopGap].
        await pump(tester, options: const <HuntStartOption>[]);

        final Rect view = tester.getRect(find.byType(HuntStartPointView));
        final Rect text = tester.getRect(
          find.text(stringsOf().text('challenge.hotspot.empty')),
        );

        expect(text.top - view.top, closeTo(40, 0.01));
      },
    );

    testWidgets(
      'zwischen Hinweistext und Zurück liegen achtundzwanzig, nicht zwölf',
      (WidgetTester tester) async {
        // `marginTop: 12`, `:3047`, ohne eigene `display`-Angabe am Knopf:
        // ein `<button>` ist im Browser-Standard `inline-block`, dessen
        // Ränder nie kollabieren. Der untere Standardrand des Absatzes davor
        // (16) und der obere Rand des Knopfes (12) addieren sich deshalb:
        // 16 + 12 = 28, siehe [HuntStartPointView.emptyBackButtonGap].
        await pump(tester, options: const <HuntStartOption>[]);

        final Rect text = tester.getRect(
          find.text(stringsOf().text('challenge.hotspot.empty')),
        );
        final Rect back = tester.getRect(
          find.byKey(HuntStartPointView.backKey),
        );

        expect(back.top - text.bottom, closeTo(28, 0.01));
      },
    );
  });

  group('Was nur das Bild zeigt', () {
    // Muster 4 aus „Wie Tests hier blind werden": ein Test, der nur das
    // Rechteck des Radioknopfes misst, sieht nicht, was darin gezeichnet
    // ist. `_radio` legt für den ausgewählten Zustand drei Kreise
    // ineinander (Rand und Füllung außen rot, Mitte hell, Punkt innen rot);
    // beide inneren Kreise zu entfernen überlebte bisher jeden Test.
    //
    // Dieselbe Bauform wie in `challenges_page_test.dart`: `toImage()` in
    // `tester.runAsync`, sonst hängt es bis zur Zeitüberschreitung
    // (Muster 19).
    Future<(ByteData pixels, int width)> paintPage(WidgetTester tester) async {
      const Key boundaryKey = Key('hunt-start-paint-boundary');
      tester.view
        ..physicalSize = const Size(390 * 3, 844 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languagePreferenceStoreProvider.overrideWithValue(
              InMemoryLanguagePreferenceStore(AppLanguage.de),
            ),
          ],
          child: MaterialApp(
            theme: FactTheme.light(),
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: HuntStartPointView(
                  options: _twoOptions,
                  onPick: (MapPosition _) {},
                  onBack: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      expect(boundary.localToGlobal(Offset.zero), Offset.zero);

      late ByteData pixels;
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage();
        pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();
      });
      return (pixels, boundary.size.width.round());
    }

    ({int r, int g, int b}) pixelAt(
      ByteData pixels,
      int width,
      double x,
      double y,
    ) {
      final int index = ((y.round() * width) + x.round()) * 4;
      return (
        r: pixels.getUint8(index),
        g: pixels.getUint8(index + 1),
        b: pixels.getUint8(index + 2),
      );
    }

    testWidgets(
      'der ausgewählte Radioknopf zeichnet Rand, Mitte und Punkt getrennt',
      (WidgetTester tester) async {
        // `_radio`: außen ein 20 Pixel großer roter Kreis (Rand **und**
        // Füllung), mittig ein 16 Pixel heller Kreis (`colors.surface`),
        // mittig darin ein 10 Pixel roter Punkt. Ohne die beiden inneren
        // Kreise wäre der ganze Knopf einfarbig rot, und genau das prüft
        // dieser Test: der Punkt (Abstand 0), der helle Zwischenring
        // (Abstand ~6,5) und der äußere Rand (Abstand ~9) müssen sich in der
        // Helligkeit klar unterscheiden.
        final (ByteData pixels, int width) = await paintPage(tester);
        final Rect radio = tester.getRect(
          find.byKey(HuntStartPointView.radioKey(0)),
        );

        final ({int r, int g, int b}) mitte = pixelAt(
          pixels,
          width,
          radio.center.dx,
          radio.center.dy,
        );
        final ({int r, int g, int b}) zwischenring = pixelAt(
          pixels,
          width,
          radio.center.dx,
          radio.center.dy - 6.5,
        );
        final ({int r, int g, int b}) aussenrand = pixelAt(
          pixels,
          width,
          radio.center.dx,
          radio.top + 1,
        );

        // Rot (`0xFFE8380D`) hat wenig Grün, die helle Mitte
        // (`0xFFFFF8EE`) viel.
        expect(mitte.g, lessThan(100), reason: 'kein roter Punkt in der Mitte');
        expect(
          zwischenring.g,
          greaterThan(150),
          reason: 'kein heller Zwischenring',
        );
        expect(aussenrand.g, lessThan(100), reason: 'kein roter Außenrand');
      },
    );
  });

  group('Maße', () {
    testWidgets('zwischen Überschrift und Unterzeile liegen dreizehn Pixel', (
      WidgetTester tester,
    ) async {
      // `margin: '0 0 6px'` an der Überschrift (`:3057`) trifft auf den
      // oberen Standardrand des `<p>`, den `styles.css` nirgends zurücksetzt:
      // `1em` bei `font-size: 13`, also 13. Ränder fallen zusammen, es gilt
      // 13 und nicht 6.
      await pump(tester, options: _twoOptions);

      final Rect title = tester.getRect(
        find.text(stringsOf().text('challenge.hotspot.title')),
      );
      final Rect subtitle = tester.getRect(
        find.text(stringsOf().text('challenge.hotspot.subtitle')),
      );

      expect(subtitle.top - title.bottom, closeTo(13, 0.01));
    });

    testWidgets('zwischen zwei Zeilen liegen zehn Pixel', (
      WidgetTester tester,
    ) async {
      // `marginBottom: 10` an der Zeile, `:3070`.
      await pump(tester, options: _fourOptions);

      final Rect first = tester.getRect(
        find.byKey(HuntStartPointView.optionKey(0)),
      );
      final Rect second = tester.getRect(
        find.byKey(HuntStartPointView.optionKey(1)),
      );

      expect(second.top - first.bottom, closeTo(10, 0.01));
    });

    testWidgets('zwischen letzter Zeile und Startknopf liegen sechzehn', (
      WidgetTester tester,
    ) async {
      // **Nicht 26.** `marginBottom: 10` (`:3070`) und `marginTop: 16`
      // (`:3089`) sind benachbarte senkrechte Ränder und fallen in CSS
      // zusammen; es gilt das Maximum. Der alte Flutter-Port hat genau diesen
      // Fehler an der Reiterleiste gemacht, dort als Summe.
      await pump(tester, options: _fourOptions);

      final Rect last = tester.getRect(
        find.byKey(HuntStartPointView.optionKey(3)),
      );
      final Rect start = tester.getRect(
        find.byKey(HuntStartPointView.startKey),
      );

      expect(start.top - last.bottom, closeTo(16, 0.01));
    });

    testWidgets('zwischen Startknopf und Zurück liegen acht', (
      WidgetTester tester,
    ) async {
      // `marginTop: 8`, `:3096`. Der Startknopf hat keinen unteren Rand, hier
      // fällt also nichts zusammen.
      await pump(tester, options: _twoOptions);

      final Rect start = tester.getRect(
        find.byKey(HuntStartPointView.startKey),
      );
      final Rect back = tester.getRect(find.byKey(HuntStartPointView.backKey));

      expect(back.top - start.bottom, closeTo(8, 0.01));
    });

    // Muster 1 und 2 aus `REBUILD_STATUS.md`: ein Umbruch ist kein Überlauf,
    // und ein `Stack` beschneidet lautlos. Deshalb beides, die Ausnahme und
    // die Rechtecke der gezeichneten Absätze.
    for (final Size size in <Size>[
      const Size(390, 844),
      const Size(360, 640),
      const Size(320, 568),
    ]) {
      for (final double scale in <double>[1, 2]) {
        testWidgets(
          'auf ${size.width.toInt()} bei Schrift $scale läuft nichts über',
          (WidgetTester tester) async {
            await pump(
              tester,
              options: _fourOptions,
              size: size,
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
            _expectInsideScreen(tester, size);
          },
        );
      }
    }
  });
}

const MapPosition _userPosition = MapPosition(
  latitude: 48.1300,
  longitude: 11.5755,
);

const MapPosition _marienplatz = MapPosition(
  latitude: 48.1374,
  longitude: 11.5755,
);

/// Eine Nutzerzeile und ein Hotspot in 1000 Metern Entfernung, also 17 Minuten.
const List<HuntStartOption> _twoOptions = <HuntStartOption>[
  HuntStartOption(point: _userPosition, density: HuntDensityLabel.localHigh),
  HuntStartOption(
    point: _marienplatz,
    density: HuntDensityLabel.hotspotHigh,
    hotspotName: 'Marienplatz',
    walkingMinutes: 17,
  ),
];

/// Die volle Länge, die die Quelle zulässt: eine Nutzerzeile und drei
/// Hotspots.
const List<HuntStartOption> _fourOptions = <HuntStartOption>[
  HuntStartOption(point: _userPosition, density: HuntDensityLabel.localLow),
  HuntStartOption(
    point: _marienplatz,
    density: HuntDensityLabel.hotspotVeryHigh,
    hotspotName: 'Marienplatz',
    walkingMinutes: 3,
  ),
  HuntStartOption(
    point: _marienplatz,
    density: HuntDensityLabel.hotspotHigh,
    hotspotName: 'Viktualienmarkt',
    walkingMinutes: 5,
  ),
  HuntStartOption(
    point: _marienplatz,
    density: HuntDensityLabel.hotspotMedium,
    hotspotName: 'Englischer Garten / Chinesischer Turm',
    walkingMinutes: 21,
  ),
];

/// Kein gezeichneter Absatz ragt waagerecht aus dem Bildschirm.
///
/// Senkrecht darf er das, der Bildschirm scrollt. Waagerecht nicht: dort gibt
/// es keinen Ausweg, und genau dort schneidet ein `Stack` lautlos ab.
void _expectInsideScreen(WidgetTester tester, Size size) {
  void walk(RenderObject object) {
    if (object is RenderParagraph) {
      final Offset topLeft = object.localToGlobal(Offset.zero);
      expect(
        topLeft.dx,
        greaterThanOrEqualTo(-0.5),
        reason: 'links draußen: "${object.text.toPlainText()}"',
      );
      expect(
        topLeft.dx + object.size.width,
        lessThanOrEqualTo(size.width + 0.5),
        reason: 'rechts draußen: "${object.text.toPlainText()}"',
      );
    }
    object.visitChildren(walk);
  }

  walk(tester.renderObject(find.byType(HuntStartPointView)));
}
