import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/routing/app_router.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:fact_app/features/identity/presentation/pages/splash_page.dart';
import 'package:fact_app/features/settings/application/audio_mode_providers.dart';
import 'package:fact_app/features/settings/domain/audio_mode_store.dart';
import 'package:fact_app/features/settings/presentation/widgets/audio_activation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Der Audio-Aktivierungsdialog, ausgelöst vom Kopfhörer-Knopf des
/// Startbildschirms.
///
/// Gepumpt wird die ganze `FactApp` und nicht nur der Dialog: er ist eine
/// Route, und der Weg dorthin führt über die App-Komposition in
/// `app_routes.dart`. Ein isolierter `pumpWidget(AudioActivationDialog())`
/// würde genau die Verdrahtung überspringen, die dieser Schritt herstellt.
///
/// "Bewegung reduzieren" ist Vorbedingung, nicht Gegenstand: die Pins des
/// Startbildschirms animieren endlos, `pumpAndSettle` käme sonst nie zurück.
void main() {
  // Echte Schriften, sonst messen alle Maßprüfungen unten ein Layout, das es
  // auf keinem Gerät gibt: `flutter test` zeichnet ohne diesen Aufruf jede
  // Glyphe als Quadrat, und die Knopfzeile bricht dann schon bei Skalierung 1.0
  // um. Siehe `test/support/app_fonts.dart`. Muss in `setUpAll` stehen.
  setUpAll(loadAppFonts);

  late InMemoryAudioModeStore audioMode;

  final de = AppStrings.of(AppLanguage.de);
  final en = AppStrings.of(AppLanguage.en);

  setUp(() {
    audioMode = InMemoryAudioModeStore();
  });

  /// Der Bildschirm ist mit 390 x 844 gebaut, dem Rahmenmaß der PWA
  /// (`chrome.jsx:135-136`).
  void useDeviceSurface(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Schaltet "Bewegung reduzieren" ein.
  ///
  /// Über den `PlatformDispatcher` und **nicht** über eine `MediaQuery` um
  /// `FactApp`: eine eigene `MediaQuery` sitzt unter dem `View`, das
  /// `pumpWidget` einzieht, und verdeckt damit die echte samt `size` und
  /// `padding`. Ausführlich begründet in
  /// `test/features/identity/presentation/pages/splash_page_test.dart`.
  void useReducedMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Stellt die Systemschriftgröße ein, wie der Nutzer es täte.
  ///
  /// Über den `PlatformDispatcher`, aus demselben Grund wie
  /// [useReducedMotion]: eine eigene `MediaQuery` um `FactApp` würde die vom
  /// `View` angelegte verdecken.
  void useTextScale(WidgetTester tester, double scale) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Widget app({required AppLanguage language}) {
    return ProviderScope(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(language),
        ),
        firstLaunchStoreProvider.overrideWithValue(InMemoryFirstLaunchStore()),
        audioModeStoreProvider.overrideWithValue(audioMode),
      ],
      child: const FactApp(),
    );
  }

  Future<void> pumpSplash(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.de,
  }) async {
    useDeviceSurface(tester);
    useReducedMotion(tester);
    await tester.pumpWidget(app(language: language));
    await tester.pumpAndSettle();
  }

  /// Tippt auf den Kopfhörer-Knopf.
  ///
  /// Gesucht wird das Emoji und nicht die Beschriftung: `🎧` steht als eigener
  /// `Text` im Knopf (`screen-auth.jsx:368`) und ist damit sprachunabhängig.
  /// Der Titel des Dialogs enthält dasselbe Zeichen, aber in einem längeren
  /// Text, und `find.text` vergleicht vollständig.
  Future<void> tapAudioGuide(WidgetTester tester) async {
    final headphones = find.text('🎧');
    await tester.ensureVisible(headphones);
    await tester.pumpAndSettle();
    await tester.tap(headphones);
    await tester.pumpAndSettle();
  }

  Future<void> tapDialogButton(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SplashPage)));

  Finder dialog() => find.byType(AudioActivationDialog);

  /// Der Lautstärke-Hinweis, gesucht über seinen **vollständigen** Inhalt.
  ///
  /// Das `🔊` steht in der Quelle vor dem Aufruf und nicht im übersetzten Text
  /// (`screen-auth.jsx:251`). Wer nur den Schlüsselwert sucht, findet den
  /// Absatz nicht, und wer nur das Zeichen sucht, findet auch einen, in dem
  /// die Übersetzung fehlt.
  Finder volumeHint([AppLanguage language = AppLanguage.de]) => find.text(
    '🔊 ${AppStrings.of(language).text('audio.dialog.volumeHint')}',
  );

  /// Der **Kasten** um den Hinweis, nicht sein Text.
  ///
  /// Für Abstände ist das der Unterschied zwischen richtig und zehn Pixel
  /// daneben: der Kasten trägt `padding: '10px 12px'`, der Text beginnt also
  /// zehn Pixel unter seiner Oberkante. Gemessen und nicht überlegt, der Test
  /// lief zuerst auf 30 statt auf 20.
  Finder volumeHintBox() => find
      .ancestor(of: volumeHint(), matching: find.byType(DecoratedBox))
      .first;

  group('Öffnen', () {
    testWidgets('der Dialog erscheint nicht von selbst', (tester) async {
      // `screen-auth.jsx:269` startet `showAudioDialog` auf `false`. Es gibt
      // keinen Timer und keine Bedingung, die ihn ungefragt zeigt.
      await pumpSplash(tester);

      expect(dialog(), findsNothing);
    });

    testWidgets('ein Tipp auf den Kopfhörer-Knopf zeigt alle vier Texte', (
      tester,
    ) async {
      await pumpSplash(tester);

      await tapAudioGuide(tester);

      expect(dialog(), findsOneWidget);
      for (final key in <String>[
        'audio.dialog.title',
        'audio.dialog.body',
        'audio.dialog.activate',
        'audio.dialog.cancel',
      ]) {
        expect(find.text(de.text(key)), findsOneWidget, reason: key);
      }
    });

    testWidgets('der Fließtext behält seine drei Absätze', (tester) async {
      // `whiteSpace: 'pre-wrap'` in der Quelle. Der Text trägt zwei `\n\n`;
      // gingen sie verloren, klebten drei Absätze aneinander, und der Hinweis
      // auf den Screenreader wäre Teil des vorigen Satzes.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final rendered = tester
          .widget<Text>(find.text(de.text('audio.dialog.body')))
          .data!;

      expect(rendered, contains('\n\n'));
      expect(rendered.split('\n\n'), hasLength(3));
      expect(rendered.split('\n\n')[1], startsWith('Hinweis:'));
    });

    testWidgets('der Startbildschirm bleibt hinter dem Dialog stehen', (
      tester,
    ) async {
      // Der Dialog ist eine Route über dem Bildschirm, kein Ersatz für ihn.
      // Nach dem Schließen soll derselbe Bildschirm dastehen, ohne neu
      // aufgebaut zu werden.
      await pumpSplash(tester);
      final before = tester.state<State<StatefulWidget>>(
        find.byType(SplashPage),
      );

      await tapAudioGuide(tester);

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.text('Ohne Konto erkunden'), findsOneWidget);
      expect(
        tester.state<State<StatefulWidget>>(find.byType(SplashPage)),
        same(before),
      );
    });

    testWidgets('der Dialog löst keine Umleitung aus', (tester) async {
      // Die Weiche in `route_guards.dart` kennt nur `/splash`, `/login`,
      // `/signup` und `/map`. Eine Route ohne Pfad darf sie nicht auf den
      // Plan rufen: `matchedLocation` bleibt der Startbildschirm.
      await pumpSplash(tester);

      await tapAudioGuide(tester);

      expect(
        containerOf(tester).read(appRouterProvider).state.matchedLocation,
        const SplashRoute().location,
      );
      expect(find.byType(SplashPage), findsOneWidget);
    });
  });

  group('Sprache', () {
    testWidgets('ein Sprachwechsel auf Englisch tauscht alle vier Texte aus', (
      tester,
    ) async {
      await pumpSplash(tester, language: AppLanguage.en);

      await tapAudioGuide(tester);

      for (final key in <String>[
        'audio.dialog.title',
        'audio.dialog.body',
        'audio.dialog.activate',
        'audio.dialog.cancel',
      ]) {
        expect(find.text(en.text(key)), findsOneWidget, reason: key);
        // Beide Richtungen: sonst wäre der Test auch mit einem Dialog grün,
        // der beide Sprachen gleichzeitig zeigt.
        expect(find.text(de.text(key)), findsNothing, reason: key);
      }
    });
  });

  group('Aktivieren', () {
    testWidgets('setzt die Präferenz und schließt', (tester) async {
      await pumpSplash(tester);
      await tapAudioGuide(tester);
      expect(audioMode.isEnabled(), isFalse);

      await tapDialogButton(tester, de.text('audio.dialog.activate'));

      expect(dialog(), findsNothing);
      expect(audioMode.isEnabled(), isTrue);
      expect(containerOf(tester).read(audioModeProvider), isTrue);
    });
  });

  group('Abbrechen', () {
    testWidgets('schließt und speichert nichts', (tester) async {
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      await tapDialogButton(tester, de.text('audio.dialog.cancel'));

      expect(dialog(), findsNothing);
      expect(audioMode.isEnabled(), isFalse);
      expect(containerOf(tester).read(audioModeProvider), isFalse);
    });

    testWidgets('lässt eine bereits gesetzte Präferenz stehen', (tester) async {
      // Der wichtigere der beiden Fälle. "Abbrechen" heißt in der Quelle
      // ausschließlich `setShowAudioDialog(false)` (`screen-auth.jsx:418`).
      // Ein `setAudioMode(false)` an dieser Stelle würde einem Nutzer, der den
      // Modus schon an hat und nur nachlesen wollte, den Modus abschalten.
      audioMode = InMemoryAudioModeStore(enabled: true);
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      await tapDialogButton(tester, de.text('audio.dialog.cancel'));

      expect(dialog(), findsNothing);
      expect(audioMode.isEnabled(), isTrue);
      expect(containerOf(tester).read(audioModeProvider), isTrue);
    });
  });

  group('Keine "schon gefragt"-Merkung', () {
    testWidgets('der Dialog erscheint beim zweiten Tippen erneut', (
      tester,
    ) async {
      // Belegtes Verhalten der Quelle: `showAudioDialog` ist ein einfacher
      // Zustand ohne Gedächtnis. Wer hier eine Merkung einbaut, weicht ohne
      // Grund ab.
      audioMode = InMemoryAudioModeStore(enabled: true);
      await pumpSplash(tester);

      await tapAudioGuide(tester);
      await tapDialogButton(tester, de.text('audio.dialog.activate'));
      expect(dialog(), findsNothing);

      await tapAudioGuide(tester);

      expect(dialog(), findsOneWidget);
      expect(find.text(de.text('audio.dialog.title')), findsOneWidget);
    });
  });

  group('Schließen ohne Knopf', () {
    testWidgets('ein Tipp auf den abgedunkelten Hintergrund schließt nicht', (
      tester,
    ) async {
      // `barrierDismissible: false`. Die Überlagerung der Quelle hat keinen
      // `onClick` (`screen-auth.jsx:240`).
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(dialog(), findsOneWidget);
      expect(audioMode.isEnabled(), isFalse);
    });

    testWidgets('Systemzurück schließt wie "Abbrechen"', (tester) async {
      // Für diesen Fall gibt es keine Vorlage, die PWA kennt keine
      // Zurück-Taste. Gewählt ist die Bedeutung von "Abbrechen": schließen,
      // ohne zu speichern.
      audioMode = InMemoryAudioModeStore(enabled: true);
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(dialog(), findsNothing);
      expect(find.byType(SplashPage), findsOneWidget);
      expect(audioMode.isEnabled(), isTrue);
    });
  });

  group('Barrierefreiheit', () {
    testWidgets('der Dialog benennt seine Route mit dem Titel', (tester) async {
      // `role="dialog" aria-modal="true"
      // aria-labelledby="audio-dialog-title"` der Quelle. Ohne
      // `scopesRoute`/`namesRoute` sagt ein Screenreader beim Öffnen nichts an.
      // Freigabe am Ende des Rumpfes und nicht per `addTearDown`:
      // `flutter_test` prüft offene Handles noch **vor** den Teardowns.
      final handle = tester.ensureSemantics();
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      // Nicht `getSemantics(find.byType(AudioActivationDialog))`: dieses
      // Widget hat kein eigenes RenderObject, die Suche landet dann beim
      // umschließenden Knoten der Route und meldet ein leeres Label. Gemessen,
      // nicht vermutet. Gesucht wird deshalb die `Semantics`-Annotation selbst,
      // und die ist der erste Treffer im Dialog.
      final node = tester.getSemantics(
        find.descendant(of: dialog(), matching: find.byType(Semantics)).first,
      );
      expect(node.label, de.text('audio.dialog.title'));
      expect(node.flagsCollection.scopesRoute, isTrue);
      expect(node.flagsCollection.namesRoute, isTrue);

      handle.dispose();
    });
  });

  group('Maße und Farben der Quelle', () {
    /// Der weiße Kasten. Sein `DecoratedBox` ist der erste im Dialog.
    Finder boxOf() => find
        .descendant(of: dialog(), matching: find.byType(DecoratedBox))
        .first;

    /// Der `DecoratedBox` eines Knopfes, gefunden über seine Beschriftung.
    Finder buttonOf(String label) => find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first;

    BoxDecoration decorationOf(WidgetTester tester, Finder finder) =>
        tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

    testWidgets('der Kasten wird nicht breiter als 360 und hält 20 Rand', (
      tester,
    ) async {
      // `maxWidth: 360` am Kasten, `padding: 20` an der Überlagerung. Bei 390
      // Bildschirmbreite greift der Rand, nicht die Höchstbreite: 390 - 40 =
      // 350. Nagelt beide Werte geometrisch fest statt als Zahlenvergleich.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final box = tester.getRect(boxOf());
      expect(box.width, 390 - 2 * AudioActivationDialog.overlayPadding.left);
      expect(box.width, lessThanOrEqualTo(AudioActivationDialog.boxMaxWidth));
      // Alle vier Kanten, nicht nur die gemessene: ein
      // `EdgeInsets.symmetric(vertical: 20)` hätte die Breitenprüfung oben
      // ebenfalls rot gemacht, ein `EdgeInsets.only(left: 20, right: 20)` nicht.
      expect(AudioActivationDialog.overlayPadding, const EdgeInsets.all(20));
      expect(AudioActivationDialog.boxMaxWidth, 360);
    });

    testWidgets('der Kasten hält innen 24 Pixel Abstand', (tester) async {
      // `padding: 24`, geometrisch gemessen. Vorher ließ sich `boxPadding` auf
      // 2 setzen, ohne dass ein Gate anschlug.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final box = tester.getRect(boxOf());
      final title = tester.getRect(find.text(de.text('audio.dialog.title')));

      expect(title.left - box.left, AudioActivationDialog.boxPadding.left);
      expect(title.top - box.top, AudioActivationDialog.boxPadding.top);
      expect(box.right - title.right, AudioActivationDialog.boxPadding.right);
      expect(AudioActivationDialog.boxPadding, const EdgeInsets.all(24));
    });

    testWidgets('Ecken, Farbe und Schatten des Kastens', (tester) async {
      // `borderRadius: 18`, `background: '#fff'`,
      // `boxShadow: '0 20px 60px rgba(0,0,0,0.4)'`.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final decoration = decorationOf(tester, boxOf());

      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(18)),
      );
      expect(decoration.color, const Color(0xFFFFFFFF));
      expect(decoration.boxShadow, hasLength(1));
      expect(decoration.boxShadow!.single.offset, const Offset(0, 20));
      expect(decoration.boxShadow!.single.blurRadius, 60);
      expect(decoration.boxShadow!.single.color.a, closeTo(0.4, 0.002));
      expect(AudioActivationDialog.cornerRadius, 18);
    });

    testWidgets('die Abstände zwischen Titel, Text, Hinweis und Knöpfen', (
      tester,
    ) async {
      // `marginBottom: 12` unter dem Titel, `marginBottom: 20` unter dem
      // Fließtext, `marginBottom: 18` unter dem Hinweiskasten. Die letzten
      // beiden sind **nicht** dieselbe Zahl, und beide werden einzeln geprüft:
      // zwei fast gleiche Werte sind genau die Sorte, die beim Aufräumen
      // zusammengelegt wird.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final title = tester.getRect(find.text(de.text('audio.dialog.title')));
      final scroller = tester.getRect(
        find.descendant(
          of: dialog(),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final hint = tester.getRect(volumeHintBox());
      final buttons = tester.getRect(
        find.descendant(of: dialog(), matching: find.byType(Wrap)),
      );

      expect(scroller.top - title.bottom, AudioActivationDialog.titleGap);
      expect(hint.top - scroller.bottom, AudioActivationDialog.bodyGap);
      expect(buttons.top - hint.bottom, AudioActivationDialog.hintGap);
      expect(AudioActivationDialog.titleGap, 12);
      expect(AudioActivationDialog.bodyGap, 20);
      expect(AudioActivationDialog.hintGap, 18);
    });

    testWidgets('der Lautstärke-Hinweis steht da, und nicht sein Schlüssel', (
      tester,
    ) async {
      // E-28, und bis zum 02.09.2026 stand hier nichts. Die laufende PWA zeigt
      // an dieser Stelle wörtlich `🔊 audio.dialog.volumeHint`, weil der
      // Schlüssel in keinem ihrer beiden Wörterbücher steht und `window.t` bei
      // einem fehlenden Schlüssel den Namen zurückgibt. Der Wortlaut ist am
      // 02.09.2026 freigegeben worden, die technische Sperre war mit E-39
      // ohnehin weg.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      expect(volumeHint(), findsOneWidget);

      // Die Gegenprobe zu E-28 selbst. Ohne sie wäre dieser Test auch grün,
      // wenn hier der Rohschlüssel erschiene, also genau der Fehler der
      // Quelle.
      expect(find.textContaining('audio.dialog.volumeHint'), findsNothing);
    });

    testWidgets('englischsprachige Nutzer sehen den Hinweis auf Englisch', (
      tester,
    ) async {
      // Der Grundsatz vom 02.09.2026: hartcodiertes Deutsch ist ein Defekt der
      // Quelle und keine Parität. Dieser Schlüssel ist der erste in der
      // Ergänzung mit **zwei verschiedenen** Werten. Ohne diesen Test fiele es
      // nicht auf, wenn jemand den deutschen Satz doppelt einträgt, so wie es
      // die Blöcke `challenge.huntPill.*` und Verwandte noch tun.
      await pumpSplash(tester, language: AppLanguage.en);
      await tapAudioGuide(tester);

      expect(volumeHint(AppLanguage.en), findsOneWidget);
      expect(
        en.text('audio.dialog.volumeHint'),
        isNot(de.text('audio.dialog.volumeHint')),
      );
    });

    testWidgets('Maße und Farben des Hinweiskastens', (tester) async {
      // `background: 'rgba(245,197,24,0.15)'`, `border: '1px solid
      // rgba(245,197,24,0.45)'`, `borderRadius: 10`, `padding: '10px 12px'`,
      // `screen-auth.jsx:246-252`. `#F5C518` trägt denselben Wert wie
      // `FactColors.gold` in beiden Themes.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final box = tester.widget<DecoratedBox>(volumeHintBox());
      final decoration = box.decoration as BoxDecoration;

      expect(decoration.color, AudioActivationDialog.hintBackground);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AudioActivationDialog.hintCornerRadius),
      );
      expect(decoration.border!.top.color, AudioActivationDialog.hintBorder);

      // Die Deckkraft aus der Quelle **nachgerechnet** und nicht abgeschrieben:
      // ein Vergleich der Konstante mit sich selbst prüft nichts.
      expect(AudioActivationDialog.hintBackground.a * 255, closeTo(38, 1));
      expect(AudioActivationDialog.hintBorder.a * 255, closeTo(115, 1));
      expect(AudioActivationDialog.hintCornerRadius, 10);
      expect(
        AudioActivationDialog.hintPadding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
    });

    testWidgets('Schrift des Titels und des Fließtextes', (tester) async {
      // Titel `fontSize: 20, fontWeight: 900, color: '#1a1a1a'`, Fließtext
      // `fontSize: 14, lineHeight: 1.5, color: '#333'` in Nunito 600. Warum
      // 600 und nicht 400, steht in `AudioActivationDialog`.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final title = tester
          .widget<Text>(find.text(de.text('audio.dialog.title')))
          .style!;
      expect(title.fontFamily, 'Nunito');
      expect(title.fontWeight, FontWeight.w900);
      expect(title.fontSize, 20);
      expect(title.color, const Color(0xFF1A1A1A));

      final body = tester
          .widget<Text>(find.text(de.text('audio.dialog.body')))
          .style!;
      expect(body.fontFamily, 'Nunito');
      expect(body.fontWeight, FontWeight.w600);
      expect(body.fontSize, 14);
      expect(body.height, 1.5);
      expect(body.color, const Color(0xFF333333));
    });

    testWidgets('Farben, Gewichte und Ecken der beiden Knöpfe', (tester) async {
      // Abbrechen `#eee` auf `#333` bei Gewicht 700, Aktivieren `#E8380D` auf
      // `#fff` bei 900, beide `borderRadius: 10`.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final cancelLabel = de.text('audio.dialog.cancel');
      final activateLabel = de.text('audio.dialog.activate');

      final cancel = decorationOf(tester, buttonOf(cancelLabel));
      expect(cancel.color, const Color(0xFFEEEEEE));
      expect(cancel.borderRadius, const BorderRadius.all(Radius.circular(10)));

      final activate = decorationOf(tester, buttonOf(activateLabel));
      expect(activate.color, const Color(0xFFE8380D));
      expect(
        activate.borderRadius,
        const BorderRadius.all(Radius.circular(10)),
      );

      final cancelStyle = tester.widget<Text>(find.text(cancelLabel)).style!;
      expect(cancelStyle.color, const Color(0xFF333333));
      expect(cancelStyle.fontWeight, FontWeight.w700);
      expect(cancelStyle.fontFamily, 'Nunito');

      final activateStyle = tester
          .widget<Text>(find.text(activateLabel))
          .style!;
      expect(activateStyle.color, const Color(0xFFFFFFFF));
      expect(activateStyle.fontWeight, FontWeight.w900);
      expect(activateStyle.fontFamily, 'Nunito');
    });

    testWidgets('Abbrechen steht links, Aktivieren rechts, mit 10 Abstand', (
      tester,
    ) async {
      // `screen-auth.jsx:254-255` in dieser Reihenfolge, `gap: 10`,
      // `justifyContent: 'flex-end'`. Für einen Screenreader-Nutzer ist die
      // Reihenfolge das erste unter dem Finger, sie ist deshalb
      // Paritätsanforderung und nicht Geschmack.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final cancel = tester.getRect(buttonOf(de.text('audio.dialog.cancel')));
      final activate = tester.getRect(
        buttonOf(de.text('audio.dialog.activate')),
      );
      final box = tester.getRect(boxOf());

      expect(cancel.right, lessThan(activate.left), reason: 'Reihenfolge');
      expect(cancel.top, activate.top, reason: 'eine Zeile');
      expect(activate.left - cancel.right, AudioActivationDialog.buttonGap);
      expect(AudioActivationDialog.buttonGap, 10);
      // `flex-end`: der rechte Knopf schließt mit dem Innenrand ab.
      expect(
        box.right - activate.right,
        AudioActivationDialog.boxPadding.right,
      );
    });

    testWidgets('Innenabstand der Knöpfe: 10 hoch, 18 breit', (tester) async {
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final label = tester.getRect(find.text(de.text('audio.dialog.cancel')));
      final button = tester.getRect(buttonOf(de.text('audio.dialog.cancel')));

      expect(label.left - button.left, 18);
      expect(button.right - label.right, 18);
      expect(label.top - button.top, 10);
    });

    testWidgets('der abgedunkelte Hintergrund hat 55 Prozent Deckkraft', (
      tester,
    ) async {
      // Nicht der Flutter-Standard `Colors.black54`. Der Unterschied ist
      // optisch winzig und deshalb genau die Art Wert, die beim Aufräumen
      // verschwindet.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, AudioActivationDialog.barrierColor);
      expect(barrier.dismissible, isFalse);
      expect(AudioActivationDialog.barrierColor.a, closeTo(0.55, 0.002));
    });
  });

  group('Große Systemschrift', () {
    testWidgets('der Fließtext scrollt, statt den Kasten zu sprengen', (
      tester,
    ) async {
      // Die erste der beiden bewussten Abweichungen vom Layout der Quelle.
      // Geprüft wird beides: kein Overflow-Fehler **und** dass tatsächlich
      // Scrollweg entstanden ist. Ohne den zweiten Teil wäre der Test auch mit
      // einem Scroller grün, der nie greift.
      useDeviceSurface(tester);
      useReducedMotion(tester);
      useTextScale(tester, 2.0);
      await tester.pumpWidget(app(language: AppLanguage.de));
      await tester.pumpAndSettle();
      await tapAudioGuide(tester);

      final scroller = find.descendant(
        of: dialog(),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroller, findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(of: scroller, matching: find.byType(Scrollable)),
            )
            .position
            .maxScrollExtent,
        greaterThan(0),
        reason: 'bei doppelter Schrift muss es Scrollweg geben',
      );
    });

    testWidgets('die Knopfzeile bricht um, statt überzulaufen', (tester) async {
      // Die zweite Abweichung, und die Zusicherung für `Wrap` statt `Row`. Mit
      // echten Schriften passen beide Knöpfe bei Skalierung 1.0
      // nebeneinander; ein `Row` fällt deshalb erst hier auf.
      useDeviceSurface(tester);
      useReducedMotion(tester);
      useTextScale(tester, 2.0);
      await tester.pumpWidget(app(language: AppLanguage.de));
      await tester.pumpAndSettle();
      await tapAudioGuide(tester);

      Rect buttonRect(String label) => tester.getRect(
        find
            .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
            .first,
      );
      final cancel = buttonRect(de.text('audio.dialog.cancel'));
      final activate = buttonRect(de.text('audio.dialog.activate'));

      expect(
        activate.top,
        greaterThanOrEqualTo(cancel.bottom),
        reason: 'zweite Zeile statt Overflow',
      );
      // Beide Knöpfe schließen rechts ab, `alignment: WrapAlignment.end` gilt
      // je Zeile. Verglichen werden die Knöpfe und nicht die Beschriftungen:
      // deren linke Kanten unterscheiden sich um die Textbreite.
      expect(activate.right, closeTo(cancel.right, 0.01));
    });

    testWidgets('bei zweifacher Schrift läuft der Dialog nirgends über', (
      tester,
    ) async {
      // Androids Systemmaximum, auf den beiden Flächen aus der Tabelle im
      // Klassenkommentar von `AudioActivationDialog`. Ein Overflow würde hier
      // als `FlutterError` auflaufen und den Test rot machen.
      for (final size in <Size>[const Size(390, 844), const Size(360, 640)]) {
        tester.view
          ..physicalSize = size * 3
          ..devicePixelRatio = 3;
        useReducedMotion(tester);
        useTextScale(tester, 2.0);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(language: AppLanguage.de));
        await tester.pumpAndSettle();
        await tapAudioGuide(tester);

        expect(dialog(), findsOneWidget, reason: '$size');
        await tester.tap(find.text(de.text('audio.dialog.cancel')));
        await tester.pumpAndSettle();
      }
    });
  });

  group('Textstil', () {
    testWidgets('kein Text des Dialogs trägt eine Dekoration', (tester) async {
      // Dieselbe Falle wie beim Tutorial-Overlay und beim Startabbruch: ohne
      // `Material`-Vorfahren malt Flutter unter jeden Text die gelbe
      // Doppellinie seines `_errorTextStyle` (`material/app.dart:45`). Der
      // Dialog liegt als eigene Route im Overlay des Navigators, das
      // `Scaffold` des Startbildschirms daneben nützt ihm nichts, und
      // `DialogRoute` bringt von sich aus **kein** `Material` mit
      // (`material/dialog.dart:1837-1851`): das tun sonst die Widgets `Dialog`
      // und `AlertDialog`, und dieser Kasten ist keines von beiden, weil sein
      // Aussehen aus `screen-auth.jsx` kommt.
      //
      // Der Test prüft keine Ausnahme, weil es keine gibt. Er misst die
      // Dekoration des wirksamen Stils.
      await pumpSplash(tester);
      await tapAudioGuide(tester);

      final paragraphs = tester
          .renderObjectList<RenderParagraph>(
            find.descendant(of: dialog(), matching: find.byType(RichText)),
          )
          .toList();
      // Titel, Fließtext und zwei Knöpfe.
      // Vier bis zum 02.09.2026, seither fünf: der Lautstärke-Hinweis ist
      // dazugekommen (E-28). Diese Wache hat den Zuwachs gemeldet, statt ihn
      // durchzulassen, und genau dafür steht sie hier.
      expect(paragraphs, hasLength(5), reason: 'nichts oder zu wenig gemessen');

      for (final paragraph in paragraphs) {
        final decoration = paragraph.text.style?.decoration;
        expect(
          decoration == null || decoration == TextDecoration.none,
          isTrue,
          reason:
              'Text "${paragraph.text.toPlainText()}" trägt $decoration. '
              'Fehlt ein Material-Vorfahren?',
        );
      }
    });
  });
}
