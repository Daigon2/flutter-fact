import 'dart:async';
import 'dart:math' as math;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/application/fact_speech_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_media.dart';
import 'package:fact_app/features/facts/domain/spoken_fact_text.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/features/facts/presentation/cited_text.dart';
import 'package:fact_app/features/facts/presentation/fact_category_look.dart';
import 'package:fact_app/features/facts/presentation/fact_detail_palette.dart';
import 'package:fact_app/features/facts/presentation/fact_sources.dart';
import 'package:fact_app/features/settings/application/audio_mode_providers.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Die Fakt-Akte, `02_Frontend/app/screen-fact.jsx:64-740`
/// (`FactDetailScreen`).
///
/// ## Diese Seite hat keinen Einstieg, und das ist eine Produktregel
///
/// **Die Akte darf niemals ohne räumliche Nähe erreichbar sein.** Der Fix in
/// `screen-map.jsx:2137-2142` sagt es wörtlich: „ohne GPS NIE die
/// Fakt-Detail-Seite direkt öffnen. Sonst könnte man durch Antippen aus
/// 1000 km Entfernung einen Fakt lesen". Ein Ballon-Tipp öffnet deshalb
/// innerhalb von 150 Metern das Sammeln und außerhalb nur eine Mini-Kachel
/// (`:2129-2145`). Wer diese Seite erreichbar macht, ohne diese Bedingung
/// mitzubauen, hebelt die Vor-Ort-Mechanik der ganzen App aus. Die Bedingung
/// gehört zu Schritt 20 und 22, nicht hierher; der Kommentar an `FactRoute`
/// in `app/routing/app_routes.dart` sagt dasselbe noch einmal an der Stelle,
/// an der jemand versehentlich einen Einstieg verdrahten würde.
///
/// ## Was hier bewusst fehlt, jedes mit seinem Auslöser
///
/// * **Abspielen und Pausieren** (`:374-388`). Audio ist Schritt 25, der
///   TTS-Weg ist als E-15 offen.
/// * **Der Sammeln-Knopf** (`:666-684`) und das Belohnungs-Banner (`:418-435`).
///   Schritt 20, blockiert an E-06: der Server bucht 10 Münzen, die Quelle
///   zeigt an derselben Stelle `+50`.
/// * **Herz und Kommentare** (`:437-452`, `:517-556`). Kein Feature, kein
///   Datenvertrag, keine Entscheidung.
/// * **Damals/Heute** (`:501-515`). Schritt 24, braucht die
///   Kamera-Berechtigung (E-20).
/// * **Der Rätsel-Absprung** (`:163-168`). Phase 4.
/// * **Merken, Teilen und Link kopieren** (`:182-198`, `:311-325`). Zu keinem
///   davon gibt es eine Entscheidung.
/// * **Die Lightbox** (`:688-709`) und die Wisch-nach-unten-Geste
///   (`:255-260`). Beide hängen an der Blatt-Darstellung, die diese Route
///   nicht hat.
/// * **Die Streifentextur des Hero ohne Bild** (`:283`,
///   `repeating-linear-gradient(135deg, rgba(255,255,255,0.02) 0 16px,
///   transparent 16px 32px)`). Rein dekorativ und braucht einen eigenen
///   `CustomPainter`; wer sie nachzieht, findet die Werte hier.
/// Weggelassen und nicht leer gebaut: ein Knopf, der nichts tut, ist gegenüber
/// dem Nutzer eine Unwahrheit (E-33).
///
/// ## Die zwei Texte ohne PWA-Schlüssel
///
/// Zwei sichtbare Texte der Quelle führt die PWA nicht als i18n-Schlüssel:
/// die Zeile „Akte #" (`:367`) und die Platzhalterzeile der Quellenliste
/// (`:474`). Beide liegen als `fact.fileNumber` und `fact.sourceMissing` in
/// `app/localization/app_strings_supplement.dart`, wörtlich aus der Quelle.
/// Der Wortlaut ist dort begründet, hier stehen nur die Aufrufe.
///
/// ## Der Ort im Ordnerbaum
///
/// `lib/features/README.md:15` gibt `facts` ausdrücklich die "Akte-Ansicht".
/// Die Nutzerposition kommt trotzdem von außen herein: sie gehört
/// `discovery`, und Regel 8 der `dependency-rules.md` lässt dieses Feature
/// dessen `presentation/` nicht lesen. Der Adapter sitzt in
/// `app/routing/app_routes.dart`, wie `mapSurface` bei der Karte.
class FactPage extends ConsumerStatefulWidget {
  /// Erzeugt die Akte zu [factId].
  const FactPage({required this.factId, this.userPosition, super.key});

  /// `height: 'min(50dvh, 480px)'` am Hero, `:268`.
  static const double heroMaxHeight = 480;

  /// `minHeight: 280` am Hero, `:268`.
  static const double heroMinHeight = 280;

  /// Anteil der Bildschirmhöhe, `50dvh`, `:268`.
  static const double heroHeightFraction = 0.5;

  /// `marginTop: -40` am Inhaltsblatt, `:346`.
  static const double sheetOverlap = 40;

  /// `borderRadius: '24px 24px 0 0'` am Inhaltsblatt, `:346`.
  static const double sheetCornerRadius = 24;

  /// `padding: '8px 20px …'` am Inhaltsblatt, `:346`.
  static const EdgeInsets sheetPadding = EdgeInsets.only(
    top: 8,
    left: 20,
    right: 20,
  );

  /// Der untere Innenabstand des Inhaltsblatts, `:346`.
  ///
  /// Die Quelle wählt `isCollected ? 80 : 140`. Die 140 halten den absolut
  /// gesetzten Sammeln-Knopf frei (`bottom: 100`, `:668`), und den gibt es
  /// hier nicht. Deshalb die 80. **Wer den Knopf in Schritt 20 nachzieht, muss
  /// diese Zahl an seinen Zustand koppeln**, sonst steht er auf dem letzten
  /// Absatz.
  static const double sheetBottomPadding = 80;

  /// `top: 54` der Navigationszeile, `:302`, gezählt ab der sicheren Fläche.
  static const double navigationRowTop = 54;

  /// `left: 16` und `right: 16` der Navigationszeile, `:302`.
  static const double navigationRowInset = 16;

  /// `width/height: 40` des Zurück-Knopfes, `:304`.
  static const double backButtonSize = 40;

  /// `borderRadius: 13` des Zurück-Knopfes, `:304`.
  static const double backButtonRadius = 13;

  /// `width/height: 20` des Chevrons, `:309`.
  static const double chevronSize = 20;

  /// `height: 96` der Verdunkelung am oberen Hero-Rand, `:280`.
  static const double heroTopDimHeight = 96;

  /// `height: 140` der Aufblendung am unteren Hero-Rand, `:284`.
  static const double heroBottomFadeHeight = 140;

  /// `bottom: 72` der Bildunterschrift, `:286`.
  static const double heroCaptionBottom = 72;

  /// `bottom: 74` der Urheberangabe, `:294`.
  static const double heroAttributionBottom = 74;

  /// `right: 80` der Bildunterschrift, sobald ein Bild da ist, `:286`.
  static const double heroCaptionRightWithImage = 80;

  /// `left: 16` der Bildunterschrift, `:286`.
  static const double heroCaptionInset = 16;

  /// Wie lange der Sprung zur Quellenliste dauert.
  ///
  /// Die Quelle sagt nur `behavior: 'smooth'` (`:32`) und überlässt Dauer und
  /// Kurve dem Browser. 300 ms sind Flutters eigener Standardwert für dieselbe
  /// Geste und die einzige Zahl hier, die nicht aus der Quelle stammt.
  static const Duration sourceJumpDuration = Duration(milliseconds: 300);

  /// Der Anker der Quellenliste, in der Quelle `id="fact-sources"` (`:478`).
  @visibleForTesting
  static const Key sourcesKey = Key('fact-sources');

  /// Der Zurück-Knopf.
  @visibleForTesting
  static const Key backButtonKey = Key('fact-back');

  /// Die Hero-Fläche.
  @visibleForTesting
  static const Key heroKey = Key('fact-hero');

  /// Das Medienbild im Hero.
  @visibleForTesting
  static const Key heroImageKey = Key('fact-hero-image');

  /// Das Inhaltsblatt unter dem Hero.
  @visibleForTesting
  static const Key sheetKey = Key('fact-sheet');

  /// Die Absätze des Fakttexts samt Zitat-Hochziffern.
  ///
  /// Gibt es, damit ein Test die Hochziffer im Text von der gleichnamigen
  /// Zeilennummer in der Quellenliste unterscheiden kann: beide zeigen
  /// buchstäblich `[1]`. Ein Schlüssel an der Hochziffer selbst ginge nicht,
  /// zwei Referenzen auf dieselbe Quelle im selben Absatz wären dann zwei
  /// Geschwister mit demselben Schlüssel.
  @visibleForTesting
  static const Key bodyKey = Key('fact-body');

  /// Der Kopfhörer-Knopf neben dem Titel, `screen-fact.jsx:373-388`.
  ///
  /// Ein Schlüssel und nicht die Suche über das Emoji: das `⏸` wechselt mit
  /// dem Zustand, und ein Test, der über den Text sucht, prüfte dann die
  /// Beschriftung statt den Knopf.
  static const Key headphoneKey = Key('fact-headphone');

  /// Welcher Fakt angezeigt wird.
  final FactId factId;

  /// Wo der Nutzer steht, oder `null`, solange es keine Ortung gibt.
  ///
  /// Hereingereicht statt selbst gelesen, siehe den Klassenkommentar.
  final DevicePosition? userPosition;

  @override
  ConsumerState<FactPage> createState() => _FactPageState();
}

class _FactPageState extends ConsumerState<FactPage> {
  /// `React.useState(false)`, `:76`. Beim Öffnen ist der Text eingeklappt.
  bool _showMore = false;

  final GlobalKey _sourcesAnchor = GlobalKey();

  /// Für welchen Fakt und welche Sprache schon von selbst vorgelesen wurde.
  ///
  /// Das Gegenstück zur Abhängigkeitsliste `[fact && fact.id, lang]` der
  /// Quelle (`screen-fact.jsx:123`). Ohne das Merken läse die Seite bei jeder
  /// Meldung des Fakt-Providers erneut vor, und Riverpod meldet ihn beim
  /// Wiederholen eines Fehlschlags bis zu zehnmal.
  String? _autoSpokenFor;

  /// Das Abonnement auf den Fakt dieser Seite.
  ///
  /// **Gehalten, damit es beim Wechsel der Kennung geschlossen werden kann.**
  /// `listenManual` räumt sich beim Entsorgen des Widgets selbst auf, aber
  /// nicht dazwischen: `didUpdateWidget` legte hier bei jedem Wechsel ein
  /// weiteres an, und nach drei Fakten hingen drei Abonnements am selben
  /// Zustandsobjekt. Aufgefallen beim Nachsehen, warum eine Mutation
  /// überlebt hat.
  ProviderSubscription<AsyncValue<Fact?>>? _factSubscription;

  @override
  void initState() {
    super.initState();
    // **`listenManual` mit `fireImmediately` und nicht `ref.listen` im
    // `build`**, dieselbe Begründung wie in `map_page.dart` und
    // `fact_collect_overlay.dart`: `ref.listen` kennt den Schalter in
    // `flutter_riverpod 3.4.2` nicht und meldet nur Änderungen. Diese Seite
    // wird beim zweiten Besuch desselben Fakts mit einem längst geladenen
    // Provider gebaut, und dann käme nie eine Ausgabe.
    _listenToFact();
    // Die Sprache ist die zweite Abhängigkeit der Quelle. Ein Wechsel während
    // der geöffneten Akte liest neu vor, weil der Text ein anderer ist.
    ref.listenManual(
      appLanguageProvider,
      (AppLanguage? previous, AppLanguage next) => _maybeSpeakOnOpen(),
    );
  }

  @override
  void didUpdateWidget(FactPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `React.useEffect(..., [factId])` in `:90-100` setzt `showMore` beim
    // Wechsel des Fakts zurück. Denselben Fall gibt es hier, wenn go_router
    // dieselbe Seite mit einer anderen Kennung neu baut.
    if (oldWidget.factId != widget.factId) {
      _showMore = false;
      // Sonst gilt der Vermerk des vorigen Fakts weiter, und der neue würde
      // nicht vorgelesen. Derselbe Fall, den `didUpdateWidget` für
      // `_showMore` schon abfängt: go_router baut dieselbe Seite mit einer
      // anderen Kennung neu.
      _autoSpokenFor = null;
      _listenToFact();
    }
  }

  @override
  void dispose() {
    _factSubscription?.close();
    _factSubscription = null;
    super.dispose();
  }

  /// Meldet sich am Fakt dieser Seite an und schließt eine alte Anmeldung.
  ///
  /// Das Abonnement hängt am Familienargument `widget.factId`; bei einem
  /// Wechsel der Kennung muss es ein neues sein, und das alte gehört zu.
  void _listenToFact() {
    _factSubscription?.close();
    _factSubscription = ref.listenManual(
      factByIdProvider(widget.factId),
      (AsyncValue<Fact?>? previous, AsyncValue<Fact?> next) =>
          _maybeSpeakOnOpen(),
      fireImmediately: true,
    );
  }

  /// Liest den Fakt beim Öffnen von selbst vor, wenn der Audio-Modus an ist.
  ///
  /// `screen-fact.jsx:119-123`. Drei Bedingungen der Quelle sind übernommen
  /// (Modus an, Fakt geladen, und nicht zweimal für dasselbe), **eine
  /// bewusst nicht.**
  ///
  /// ## Die iOS-Gestensperre der Quelle wird nicht nachgebaut
  ///
  /// Dort steht davor `if (!window.__factAudioGestureOk) return;`, mit einem
  /// eigenen Kommentar als Begründung: „speechSynthesis.speak() ohne
  /// vorherige User-Geste wird auf iOS Safari stillschweigend verworfen".
  /// Deshalb hängt `audio-player.jsx:41-50` zwei globale Lauscher auf
  /// `touchend` und `click`, nur um zu wissen, ob überhaupt gesprochen werden
  /// darf.
  ///
  /// **Das ist eine Regel des Browsers und keine der Plattform.**
  /// `AVSpeechSynthesizer` auf iOS und `TextToSpeech` auf Android verlangen
  /// keine Geste. Die Sperre nachzubauen hieße, das Vorlesen beim ersten
  /// Öffnen ohne Grund ausfallen zu lassen, und genau dieses erste Öffnen ist
  /// der Fall, für den der Audio-Modus gebaut ist: wer ihn einschaltet, hat
  /// die Geste längst gemacht.
  /// ## Warum das erst nach dem Bild passiert, und das ist gemessen
  ///
  /// Riverpod verbietet, einen Provider im Lebenszyklus eines Widgets zu
  /// ändern, und nennt `initState` in seiner Fehlermeldung ausdrücklich:
  /// „Tried to modify a provider while the widget tree was building." Genau
  /// dort landet der erste Aufruf, weil `fireImmediately` den Hörer synchron
  /// in `initState` ruft. Der erste Testlauf ist daran gescheitert, und zwar
  /// **sichtbar**: der Fehler ging in die abgekoppelte Arbeit und der Vortrag
  /// blieb aus.
  ///
  /// Der Umweg über das nächste Bild löst beides: er liegt außerhalb jeder
  /// Bauphase, und er ist derselbe Weg für den späteren Fall, in dem der Fakt
  /// erst aus dem Netz eintrifft. **Ein Bild kommt dann verlässlich**, weil
  /// diese Seite `factByIdProvider` selbst beobachtet und die Ankunft einen
  /// Neuaufbau auslöst.
  ///
  /// Zwei Anfragen im selben Bild sind harmlos: die Rückrufe laufen der Reihe
  /// nach, der erste setzt den Vermerk, der zweite sieht ihn.
  void _maybeSpeakOnOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakOnOpenNow());
  }

  void _speakOnOpenNow() {
    if (!mounted) {
      return;
    }
    if (!ref.read(audioModeProvider)) {
      return;
    }
    final Fact? fact = ref.read(factByIdProvider(widget.factId)).value;
    if (fact == null) {
      return;
    }
    final AppLanguage language = ref.read(appLanguageProvider);
    final String key = '${fact.id.value}|${language.code}';
    if (_autoSpokenFor == key) {
      return;
    }
    _autoSpokenFor = key;
    _speak(fact, language);
  }

  /// Schickt die Vorlesefassung an den Sprachdienst.
  ///
  /// Der Text kommt aus `spokenFactText` und nicht aus den Widgets: die
  /// gleiche Sprachfassung wie auf dem Bildschirm, aber ohne die
  /// Zitat-Hochziffern, siehe die Begründung dort.
  void _speak(Fact fact, AppLanguage language) {
    final FactText content = fact.contentFor(
      language.code,
      fallbackLanguageCode: AppLanguage.fallback.code,
    );
    reportDetached(
      ref
          .read(factSpeechProvider.notifier)
          .speak(
            factId: fact.id,
            text: spokenFactText(content),
            languageTag: speechLanguageTagFor(language.code),
          ),
      origin: 'facts.speech.speak',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final FactDetailPalette palette = FactDetailPalette.of(
      Theme.of(context).brightness,
    );
    final AsyncValue<Fact?> state = ref.watch(factByIdProvider(widget.factId));
    final Fact? fact = state.value;

    if (fact != null) {
      return _detail(context, fact, strings, language, palette);
    }
    if (state.isLoading) {
      return _loading(palette);
    }
    return _notFound(strings, palette);
  }

  /// Kein Gegenstück in der Quelle: dort liegen die Fakten synchron in
  /// `window.FACTS`. Ohne Text, weil es dafür keinen Schlüssel gibt und ein
  /// erfundener nichts erklärt, was der Kreis nicht schon sagt.
  Widget _loading(FactDetailPalette palette) => ColoredBox(
    color: palette.background,
    child: const Center(child: CircularProgressIndicator()),
  );

  /// `screen-fact.jsx:125-127`: `padding: 40`, Farbe `--ink`, sonst nichts.
  ///
  /// **Auch der Fehlschlag landet hier**, und das ist Parität und keine
  /// Bequemlichkeit: scheitert in der PWA das Laden, fängt `app.jsx:227` den
  /// Fehler ab, `window.FACTS` bleibt ohne den Datensatz, und `facts.find`
  /// liefert `undefined`. Die Quelle zeigt in beiden Fällen denselben Satz.
  ///
  /// Ohne Zurück-Knopf, wie in der Quelle. Der Nutzer sitzt trotzdem nicht
  /// fest: diese Route liegt im Karten-Zweig der Shell, die Tab-Leiste steht
  /// darüber.
  ///
  /// **Nach einem Fehlschlag wechselt der Bildschirm rund eine halbe Minute
  /// lang zwischen dieser Meldung und dem Ladekreis.** Riverpod wiederholt
  /// einen gescheiterten `FutureProvider` zehnmal mit wachsender Pause, und
  /// jeder Versuch setzt den Zustand kurz auf `AsyncLoading`. Das ist keine
  /// Unruhe um ihrer selbst willen, sondern die sichtbare Seite des
  /// Wiederholens; wer es abstellen will, muss `retry` am Provider ändern und
  /// nicht hier.
  Widget _notFound(AppStrings strings, FactDetailPalette palette) => ColoredBox(
    color: palette.background,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          strings.text('fact.notFound'),
          style: FactTypography.bodyText.copyWith(color: palette.ink),
        ),
      ),
    ),
  );

  Widget _detail(
    BuildContext context,
    Fact fact,
    AppStrings strings,
    AppLanguage language,
    FactDetailPalette palette,
  ) {
    final FactText content = fact.contentFor(
      language.code,
      fallbackLanguageCode: AppLanguage.fallback.code,
    );
    final FactCategoryLook look = factCategoryLookOf(fact.canonicalCategory);
    // `:457` und `:472-475`: die Liste wird bis zur höchsten Hochziffer aller
    // vier Textfelder mit Platzhaltern aufgefüllt, damit jedes `[n]` eine
    // Zeile findet. Gezählt wird über alle vier, auch über die noch
    // eingeklappten; die Quelle prüft dabei weder `showMore` noch
    // `isRealProse`.
    final List<FactSource> sources = factSourcesOf(
      content.source,
      highestReference: highestSourceReference(<String?>[
        content.body,
        content.bodyExtra,
        content.bodyBackground,
        content.bodyToday,
      ]),
      missingLabel: strings.text('fact.sourceMissing'),
    );
    // `min(50dvh, 480px)` mit `minHeight: 280`. Bezug ist die ganze
    // Bildschirmhöhe und nicht die Fläche innerhalb der sicheren Kanten:
    // `dvh` zählt in CSS den Viewport.
    final double heroHeight = math.max(
      math.min(
        MediaQuery.sizeOf(context).height * FactPage.heroHeightFraction,
        FactPage.heroMaxHeight,
      ),
      FactPage.heroMinHeight,
    );

    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        // Nur oben. Die Quelle zählt `top: 54` ab der Oberkante der
        // `.app-frame`, und die liegt unterhalb der Notch
        // (`index.html:101-107`, `padding-top: env(safe-area-inset-top)`).
        // Unten holt sich das Inhaltsblatt den Freiraum der Tab-Leiste selbst.
        bottom: false,
        child: SingleChildScrollView(
          child: Stack(
            children: <Widget>[
              // Der Hero liegt hinten und in voller Höhe, das Blatt darüber
              // beginnt 40 Pixel höher: `marginTop: -40` (`:346`). In einer
              // `Column` ginge das nicht, ein negativer Abstand ist dort
              // verboten.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _hero(
                  context,
                  fact,
                  content,
                  look,
                  palette,
                  strings,
                  heroHeight,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: heroHeight - FactPage.sheetOverlap),
                  _sheet(
                    context,
                    fact,
                    content,
                    look,
                    palette,
                    strings,
                    language,
                    sources,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────

  Widget _hero(
    BuildContext context,
    Fact fact,
    FactText content,
    FactCategoryLook look,
    FactDetailPalette palette,
    AppStrings strings,
    double height,
  ) {
    final FactMedia? media = fact.media;
    final String? imageUrl = media?.previewUrl;
    final Size box = Size(MediaQuery.sizeOf(context).width, height);
    // `linear-gradient(160deg, hero[0] 0%, hero[1] 100%)`, `:269`.
    final ({Alignment begin, Alignment end}) heroGradient =
        cssLinearGradientEnds(angleDegrees: 160, box: box);
    // `linear-gradient(135deg, ${cat.color}22 0%, transparent 50%)`, `:282`.
    final ({Alignment begin, Alignment end}) tintGradient =
        cssLinearGradientEnds(angleDegrees: 135, box: box);

    return SizedBox(
      key: FactPage.heroKey,
      height: height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: heroGradient.begin,
                  end: heroGradient.end,
                  colors: _heroColors(fact),
                ),
              ),
            ),
            if (imageUrl != null)
              Image.network(
                imageUrl,
                key: FactPage.heroImageKey,
                fit: BoxFit.cover,
                // `objectPosition: 'center 25%'`, `:276`. In Alignment-Einheiten
                // ist 25 Prozent von oben `2 * 0.25 - 1 = -0.5`.
                alignment: const Alignment(0, -0.5),
                // Ohne diesen Zweig wirft `Image` im Debug-Build bei jedem
                // Ladefehler, und in `flutter test` scheitert **jede**
                // Netzanfrage. Die Quelle zeigt bei einem kaputten Bild den
                // Verlauf darunter, also tut es das hier auch.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            // `linear-gradient(rgba(0,0,0,0.35), transparent)`, `:280-281`.
            // Ohne Winkel heißt in CSS `to bottom`.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: FactPage.heroTopDimHeight,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x59000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: tintGradient.begin,
                  end: tintGradient.end,
                  // `${cat.color}22` ist die Kategoriefarbe mit Alpha 0x22.
                  colors: <Color>[
                    look.color.withAlpha(0x22),
                    const Color(0x00000000),
                  ],
                  stops: const <double>[0, 0.5],
                ),
              ),
            ),
            // `linear-gradient(transparent, ${bg})`, `:284`.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: FactPage.heroBottomFadeHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      palette.background.withAlpha(0),
                      palette.background,
                    ],
                  ),
                ),
              ),
            ),
            _heroCaption(content, media, strings, imageUrl != null),
            if (media?.sourceUrl != null) _heroAttribution(media!),
            _navigationRow(context),
          ],
        ),
      ),
    );
  }

  /// `hero: text[] default array['#2C3E50','#4A6741']` in der Datenbank, in der
  /// Quelle `fact.hero?.[0] || '#2A1A30'` und `fact.hero?.[1] || '#1C1408'`
  /// (`:269`).
  ///
  /// Der Mapper lässt nur Hex-Werte durch und setzt sonst `Fact.defaultHeroColors`,
  /// die Liste hat hier also im Regelfall genau zwei Einträge. Der Notnagel
  /// deckt einen dritten Fall ab, den die Quelle nicht kennt: eine Liste mit
  /// einem einzigen Wert ergäbe in Flutter einen `LinearGradient` mit einer
  /// Farbe, und der wirft.
  List<Color> _heroColors(Fact fact) {
    final List<Color> parsed = <Color>[
      for (final String value in fact.heroColors)
        if (_hexColor(value) case final Color color) color,
    ];
    if (parsed.length >= 2) {
      return parsed;
    }
    return <Color>[
      for (final String value in Fact.defaultHeroColors) _hexColor(value)!,
    ];
  }

  Widget _heroCaption(
    FactText content,
    FactMedia? media,
    AppStrings strings,
    bool hasImage,
  ) {
    // `:287-290`: liegt eine Bildbeschreibung vor, steht sie in Klammern und
    // bei mehr als 60 Zeichen mit Auslassungszeichen. Sonst Ort und
    // Bildunterschrift des Fakts, ersatzweise "Historisches Foto".
    final String? mediaCaption = media?.caption;
    final String text;
    if (mediaCaption != null && mediaCaption.isNotEmpty) {
      final String clipped = mediaCaption.length > 60
          ? '${mediaCaption.substring(0, 60)}…'
          : mediaCaption;
      text = '[ $clipped ]';
    } else {
      final String place = content.place ?? '';
      final String caption =
          content.caption ?? strings.text('fact.historicalPhoto');
      text = '[ $place · $caption ]';
    }

    return Positioned(
      bottom: FactPage.heroCaptionBottom,
      left: FactPage.heroCaptionInset,
      right: hasImage
          ? FactPage.heroCaptionRightWithImage
          : FactPage.heroCaptionInset,
      child: Text(
        // `textTransform: 'uppercase'`, `:286`.
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FactTypography.mono.copyWith(
          fontSize: 9,
          // `rgba(255,255,255,0.4)`, 0.4 * 255 = 102.
          color: const Color(0x66FFFFFF),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// `© {attribution|Wikimedia}`, `:292-299`.
  ///
  /// In der Quelle ein `<a>` auf `hint_media.source_url`. Ohne `url_launcher`
  /// lässt sich die Seite nicht öffnen, und ein Link, der nichts tut, wäre
  /// schlechter als die reine Angabe. Die Urheberangabe selbst bleibt, sie ist
  /// eine Lizenzpflicht und keine Zierde.
  Widget _heroAttribution(FactMedia media) {
    final String attribution = media.attribution ?? 'Wikimedia';
    final String clipped = attribution.length > 20
        ? attribution.substring(0, 20)
        : attribution;
    return Positioned(
      bottom: FactPage.heroAttributionBottom,
      right: FactPage.heroCaptionInset,
      child: ConstrainedBox(
        // `maxWidth: 72`, `:295`.
        constraints: const BoxConstraints(maxWidth: 72),
        child: Text(
          '© $clipped',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FactTypography.mono.copyWith(
            fontSize: 8,
            // `rgba(255,255,255,0.28)`, 0.28 * 255 = 71.4.
            color: const Color(0x47FFFFFF),
          ),
        ),
      ),
    );
  }

  /// `:302-326`, ohne die beiden rechten Knöpfe.
  Widget _navigationRow(BuildContext context) {
    return Positioned(
      top: FactPage.navigationRowTop,
      left: FactPage.navigationRowInset,
      right: FactPage.navigationRowInset,
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          key: FactPage.backButtonKey,
          // `context.pop()` und nicht `Navigator.pop`: ADR-004, Navigation
          // läuft über go_router.
          onTap: context.pop,
          child: Container(
            width: FactPage.backButtonSize,
            height: FactPage.backButtonSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // `rgba(255,255,255,0.1)`, `:305`. 0.1 * 255 = 25.5.
              color: const Color(0x1AFFFFFF),
              borderRadius: const BorderRadius.all(
                Radius.circular(FactPage.backButtonRadius),
              ),
              // `1px solid rgba(255,255,255,0.15)`, `:306`. 0.15 * 255 = 38.25.
              border: Border.fromBorderSide(
                BorderSide(color: const Color(0x26FFFFFF)),
              ),
            ),
            // Der Pfad kommt unverändert aus `:309`. Warum SVG und kein
            // `CustomPainter`: die Pfaddaten sind die Verhaltensquelle,
            // dieselbe Begründung wie in `AuthHeader`.
            //
            // Ohne Ansagetext, ebenfalls wie dort: die Quelle ist ein `<div>`
            // ohne `aria-label`, und einen Text zu erfinden bräuchte einen
            // i18n-Schlüssel.
            child: SvgPicture.string(
              '<svg width="20" height="20" viewBox="0 0 24 24" fill="none">'
              '<path d="M15 6l-6 6 6 6" stroke="#fff" stroke-width="2" '
              'stroke-linecap="round"/></svg>',
              width: FactPage.chevronSize,
              height: FactPage.chevronSize,
            ),
          ),
        ),
      ),
    );
  }

  // ── Inhaltsblatt ───────────────────────────────────────────────────────

  Widget _sheet(
    BuildContext context,
    Fact fact,
    FactText content,
    FactCategoryLook look,
    FactDetailPalette palette,
    AppStrings strings,
    AppLanguage language,
    List<FactSource> sources,
  ) {
    return DecoratedBox(
      key: FactPage.sheetKey,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FactPage.sheetCornerRadius),
        ),
      ),
      child: Padding(
        padding: FactPage.sheetPadding.copyWith(
          // Die Tab-Leiste schwebt über dem Inhalt; `Scaffold.extendBody`
          // meldet ihre Höhe als unteres `MediaQuery`-Padding
          // (`app/shell/app_shell.dart`). Ein eigenes `padding` hebelt das
          // aus, wenn es die Zahl nicht dazurechnet.
          bottom:
              FactPage.sheetBottomPadding +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _pullHandle(palette),
            _categoryRow(fact, content, look, palette, strings),
            const SizedBox(height: 12),
            _title(fact, content, palette, strings, language),
            const SizedBox(height: 12),
            _pills(fact, content, palette, strings),
            const SizedBox(height: 16),
            Column(
              key: FactPage.bodyKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _body(content, look, palette, strings, sources.length),
            ),
            if (sources.isNotEmpty)
              _sourcesCard(sources, palette, strings)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  /// `:348-350`: 36 mal 4, Radius 2, `padding: '12px 0 8px'`.
  Widget _pullHandle(FactDetailPalette palette) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          // `rgba(0,0,0,0.12)` hell, `rgba(255,255,255,0.15)` dunkel, `:349`.
          color: palette == FactDetailPalette.light
              ? const Color(0x1F000000)
              : const Color(0x26FFFFFF),
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    ),
  );

  /// `:353-369`.
  Widget _categoryRow(
    Fact fact,
    FactText content,
    FactCategoryLook look,
    FactDetailPalette palette,
    AppStrings strings,
  ) {
    final String place = content.place ?? '';
    return Row(
      children: <Widget>[
        // Der Chip ist das einzige starre Kind der Zeile, und das ist
        // gemessen und nicht geraten: er ist bei doppelter Systemschrift auf
        // einem 360er Gerät 171,4 Pixel breit und passt damit in den
        // Satzspiegel von 320. Gäbe man ihm auch einen Flex-Anteil, teilte er
        // sich den freien Platz mit Nummer und Ort, und der Kategoriename
        // bekäme ein Auslassungszeichen, obwohl er Platz hätte. Der
        // Skalierungstest sichert die Messung zu.
        _categoryChip(look, strings),
        // `gap: 8` an der Zeile, `:353`.
        const SizedBox(width: 8),
        _fileNumber(fact, palette, strings),
        if (place.isNotEmpty) ...<Widget>[
          const SizedBox(width: 8),
          // `marginLeft: 'auto'`, `:368`: der Ort wird an den rechten Rand
          // geschoben und schrumpft, wenn der Platz knapp wird. Zum
          // Flex-Verhältnis 2 zu 1 siehe `_fileNumber`.
          Expanded(
            flex: 2,
            child: Text(
              place,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FactTypography.mono.copyWith(
                fontSize: 9,
                color: palette.ink3,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Die Aktennummer, `:367`: `Akte #{fact.nr || fact.id}`.
  ///
  /// `fact.nr` ist die redaktionelle Nummer mit Stadt-Präfix (`MUC_004`), und
  /// sie ist nullbar. Der Notnagel der Quelle, `|| fact.id`, ist übernommen
  /// und nicht durch ein Weglassen der Zeile ersetzt: `fact.id` ist in beiden
  /// Programmen dieselbe Zahl aus `facts.id`, die Zeile steht also in der PWA
  /// immer da und trägt immer eine Nummer.
  ///
  /// ## Warum die Zeile `Expanded` ist und nicht starr
  ///
  /// **Starr läuft sie über.** Gemessen mit den echten Schriften: der
  /// Kategorie-Chip ist bei doppelter Systemschrift 171,4 Pixel breit,
  /// „Akte #MUC_004" 141,7, dazu zwei Abstände von 8. Zusammen 329,1 Pixel
  /// in einem Satzspiegel von 320 auf einem 360er Gerät, also 9,1 Pixel
  /// Überlauf, und der `Expanded` des Orts kann ihn nicht mehr abfangen,
  /// weil er schon bei null steht. In CSS schrumpfen die Flex-Kinder von
  /// selbst (`flex-shrink` steht auf 1), in Flutter muss man es
  /// hinschreiben.
  ///
  /// **`Flexible` statt `Expanded` bricht dafür den rechten Rand.** Ein
  /// lose gefülltes Flex-Kind bekommt seinen Anteil trotzdem zugeteilt und
  /// gibt den ungenutzten Teil nicht zurück; die Zeile bliebe kürzer als
  /// ihre Spur, und der Ort stünde nicht mehr am Satzspiegel. Mit zwei
  /// festen Kindern geht die Zeile genau auf: die Nummer steht links in
  /// ihrem Kasten, der Ort rechts in seinem, und der freie Platz liegt
  /// dazwischen. Das ist genau das Bild, das `marginLeft: 'auto'` in `:368`
  /// erzeugt.
  ///
  /// **Das Verhältnis 1 zu 2 ist die Nachbildung von `flex-shrink: 1`.**
  /// CSS kürzt jedes Kind im Verhältnis seiner Inhaltsbreite. Gemessen sind
  /// das 71,5 Pixel für „Akte #MUC_004" gegen 135,0 für den längsten Ort im
  /// Prüfbestand, also rund eins zu zwei. Bei 390 Pixeln und Skalierung 1
  /// reicht die Aufteilung für beide vollständig (75,8 gegen 71,5 und 151,5
  /// gegen 135,0); erst darunter kürzt sie, und dann beide zugleich.
  Widget _fileNumber(Fact fact, FactDetailPalette palette, AppStrings strings) {
    return Expanded(
      child: Text(
        strings.text(
          'fact.fileNumber',
          params: <String, String>{'nr': fact.number ?? '${fact.id.value}'},
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FactTypography.mono.copyWith(
          fontSize: 9,
          color: palette.ink3,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  /// `:354-366`.
  Widget _categoryChip(FactCategoryLook look, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
      decoration: BoxDecoration(
        // `${cat.color}18` und `1px solid ${cat.color}44`, `:357`.
        color: look.color.withAlpha(0x18),
        border: Border.fromBorderSide(
          BorderSide(color: look.color.withAlpha(0x44)),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _categoryGlyph(look),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              // `t('cat.' + catKey, lang)`, `:365`.
              strings.text('cat.${look.key}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FactTypography.heading.copyWith(
                fontSize: 12,
                color: look.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `:359-364`: 20 mal 20, Radius 6, Verlauf `145deg`, harter Schatten
  /// `0 2px 0 ${cat.dk}`, Zeichen in Größe 11.
  Widget _categoryGlyph(FactCategoryLook look) {
    const Size box = Size.square(20);
    final ({Alignment begin, Alignment end}) gradient = cssLinearGradientEnds(
      angleDegrees: 145,
      box: box,
    );
    return MediaQuery.withNoTextScaling(
      // Die Kachel hat eine feste Kantenlänge; ein mitwachsendes Zeichen
      // sprengte sie. Dieselbe Regel wie bei `AuthWordmarkSmall`.
      child: Container(
        width: box.width,
        height: box.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: gradient.begin,
            end: gradient.end,
            colors: <Color>[look.color.withAlpha(0xcc), look.color],
          ),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          boxShadow: <BoxShadow>[
            BoxShadow(color: look.darkColor, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          look.emoji,
          style: const TextStyle(fontSize: 11, height: 1),
        ),
      ),
    );
  }

  /// `:372-389`, Titel und Kopfhörer-Knopf in einer Zeile.
  ///
  /// `alignItems: 'flex-start'` der Quelle, also der Knopf oben am ersten
  /// Zeilenumbruch und nicht in der Mitte eines dreizeiligen Titels.
  Widget _title(
    Fact fact,
    FactText content,
    FactDetailPalette palette,
    AppStrings strings,
    AppLanguage language,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Text(
          content.title ?? '',
          style: FactTypography.emphasis.copyWith(
            fontSize: 24,
            height: 1.2,
            color: palette.ink,
          ),
        ),
      ),
      const SizedBox(width: 8),
      _headphoneButton(fact, content, palette, strings, language),
    ],
  );

  /// Der Kopfhörer-Knopf, `:373-388`.
  ///
  /// ## Drei Zweige, und der Vergleich läuft über die Kennung
  ///
  /// Anhalten, fortsetzen oder von vorn, genau wie in `:376-378`. **Die
  /// Quelle vergleicht dabei den Titel** (`audioState.fact.titel ===
  /// fact.titel`, `:136`), und das ist ein Defekt mit zwei Gesichtern: zwei
  /// Fakten mit gleichem Titel gelten als derselbe, und die drei
  /// Ansage-Aufrufe der Quelle schieben Attrappen mit **leerem** Titel in den
  /// Zustand, die dann zu jedem titellosen Fakt passen. Hier vergleicht
  /// `FactSpeechStatus` die `FactId`.
  Widget _headphoneButton(
    Fact fact,
    FactText content,
    FactDetailPalette palette,
    AppStrings strings,
    AppLanguage language,
  ) {
    final FactSpeechStatus speech = ref.watch(factSpeechProvider);
    final bool showPause = speech.isSpeaking(fact.id);
    return IconButton(
      key: FactPage.headphoneKey,
      onPressed: () {
        final FactSpeechNotifier notifier = ref.read(
          factSpeechProvider.notifier,
        );
        if (showPause) {
          reportDetached(notifier.pause(), origin: 'facts.speech.pause');
          return;
        }
        if (speech.isPaused(fact.id)) {
          reportDetached(notifier.resume(), origin: 'facts.speech.resume');
          return;
        }
        _speak(fact, language);
      },
      // Die Beschriftung folgt dem Zweig, wie das `aria-label` in `:380`.
      tooltip: strings.text(
        showPause ? 'audio.miniplayer.pause' : 'audio.miniplayer.play',
      ),
      icon: Text(
        // `⏸` und `🎧`, `:387`. Emoji und kein `Icons`-Symbol: die Quelle
        // zeichnet den Knopf so, und ein Materialsymbol daneben wäre der
        // einzige nicht gezeichnete Knopf dieses Bildschirms.
        showPause ? '⏸' : '🎧',
        // `var(--stamp, #B83A2E)`, `:384`. Die Palette führt denselben
        // Wert schon als `citation`, mit derselben Herkunft (`var(--stamp)`
        // an der Zitat-Hochziffer). Ein zweites Feld mit demselben Wert wäre
        // eine zweite Wahrheit über dieselbe Farbe.
        style: const TextStyle(fontSize: 22, color: FactDetailPalette.citation),
      ),
    );
  }

  /// `:392-404`, die beiden Pillen unter dem Titel.
  Widget _pills(
    Fact fact,
    FactText content,
    FactDetailPalette palette,
    AppStrings strings,
  ) {
    final String place = content.place ?? '';
    final double? distance = _distanceInMeters(fact.coordinates);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        // `factField(fact, 'ort', lang) || 'Passau'`, `:394`. Der Ersatzwert
        // ist **nicht** übernommen: eine fest verdrahtete Stadt widerspricht
        // der Mehrstädtigkeit, und "Passau" ist in diesem Bestand ohnehin
        // keine Stadt. Ohne Ort entfällt die Pille.
        if (place.isNotEmpty) _pill('📍', place, palette),
        if (distance != null)
          // `Math.round(distM) + 'm'` plus `t('fact.away')`, `:152` und `:395`.
          _pill(
            '📏',
            '${distance.round()}m ${strings.text('fact.away')}',
            palette,
          )
        else
          // Ohne Ortung sagt `:395` wörtlich "null entfernt", weil `distLabel`
          // dann `null` ist und JavaScript es in den String schreibt. Das ist
          // ein Fehler der Quelle derselben Art wie das "NaNm", das sie in
          // `:140-142` selbst behoben hat. Statt ihn nachzubauen steht hier
          // der Text, den die Quelle an derselben Bedingung selbst wählt:
          // `distLabel == null ? t('fact.gpsRequired') : …` (`:678-680`). Das
          // Schloss-Zeichen steckt bereits im Text, deshalb ohne Lineal davor.
          _pill(null, strings.text('fact.gpsRequired'), palette),
      ],
    );
  }

  Widget _pill(String? icon, String text, FactDetailPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.fromBorderSide(BorderSide(color: palette.border)),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Text(icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: FactTypography.bodyText.copyWith(
                fontSize: 11,
                color: palette.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wie weit der Nutzer von [coordinates] entfernt ist, `:143-151`.
  ///
  /// `null` heißt: es fehlt die Ortung oder die Koordinate des Fakts. Die
  /// Quelle prüft beides einzeln, weil ohne die Prüfung `NaNm` in der Pille
  /// stand (`:140-142`).
  ///
  /// Gerechnet wird mit `MapPosition.distanceInMetersTo`, also der Haversine
  /// aus `map/domain`. Dass die Nutzerposition dafür kurz in die Kartensprache
  /// übersetzt wird, ist derselbe Weg wie in `discovery`; sie verlässt diese
  /// Methode nicht, der Karten-Host bekommt sie nie zu sehen (E-07).
  double? _distanceInMeters(FactCoordinates? coordinates) {
    final DevicePosition? fix = widget.userPosition;
    if (fix == null || coordinates == null) {
      return null;
    }
    final MapPosition user = MapPosition(
      latitude: fix.latitude,
      longitude: fix.longitude,
    );
    return user.distanceInMetersTo(
      MapPosition(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      ),
    );
  }

  /// `:407-415`: der erste Absatz, dann entweder der Aufklapp-Knopf oder die
  /// drei weiteren Absätze.
  List<Widget> _body(
    FactText content,
    FactCategoryLook look,
    FactDetailPalette palette,
    AppStrings strings,
    int sourceCount,
  ) {
    final List<Widget> widgets = <Widget>[
      _paragraph(content.body, palette, sourceCount),
    ];
    if (!isRealProse(content.bodyExtra)) {
      return widgets;
    }
    if (!_showMore) {
      widgets.add(_showMoreButton(look, strings));
      return widgets;
    }
    widgets.add(_paragraph(content.bodyExtra, palette, sourceCount));
    if (isRealProse(content.bodyBackground)) {
      widgets.add(_paragraph(content.bodyBackground, palette, sourceCount));
    }
    if (isRealProse(content.bodyToday)) {
      widgets.add(_paragraph(content.bodyToday, palette, sourceCount));
    }
    return widgets;
  }

  /// Ein Absatz mit Zitat-Hochziffern, `:407`.
  ///
  /// `hyphens: 'auto'` aus der Quelle hat in Flutter kein Gegenstück, es gibt
  /// keine Silbentrennung. Im Blocksatz stehen deshalb an langen Wörtern
  /// größere Lücken als im Browser.
  Widget _paragraph(String? text, FactDetailPalette palette, int sourceCount) {
    final TextStyle bodyStyle = FactTypography.bodyText.copyWith(
      fontSize: 15,
      height: 1.65,
      color: palette.ink2,
    );
    return Padding(
      // `margin: '0 0 10px'`, `:407`.
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            for (final CitedSegment segment in parseCitedText(text))
              switch (segment) {
                CitedRun(:final String text) => TextSpan(text: text),
                CitedReference() => _citationSpan(segment, sourceCount),
              },
          ],
        ),
        style: bodyStyle,
        textAlign: TextAlign.justify,
      ),
    );
  }

  /// Die Hochziffer, `:12-15` und `:26-35`.
  ///
  /// Ein `WidgetSpan` und kein `TextSpan`: `<sup>` hebt die Grundlinie, und
  /// das ist in Flutter nur über die Platzierung eines Kindes zu haben.
  /// `PlaceholderAlignment.top` setzt die Oberkante der Ziffer auf die
  /// Oberkante der Zeile, was optisch dem `<sup>` entspricht.
  ///
  /// **Seit der Auffüllung ist eine Ziffer aus dem Fakttext immer ein Ziel**,
  /// und das ist eine bewusst geänderte Zusicherung. Vorher fehlte der Text
  /// für die Platzhalterzeilen, ein `[5]` neben zwei Quellen zeigte ins Leere
  /// und war deshalb nicht antippbar. Jetzt füllt `factSourcesOf` bis zur
  /// höchsten Referenz auf (`:472-475`), die fünfte Zeile gibt es, und der
  /// Tipp springt auf sie.
  ///
  /// Die Prüfung auf [sourceCount] steht trotzdem noch hier, und **ihr
  /// Nein-Zweig ist im heutigen Bestand nicht mehr erreichbar**: gezählt wird
  /// über genau die vier Textfelder, aus denen auch die Absätze kommen. Das
  /// ist als Aussage ehrlicher, als die Prüfung als scharf auszugeben. Sie
  /// bleibt, weil sie genau dann wieder greift, wenn die beiden Listen
  /// auseinanderlaufen: ein fünfter Absatz aus einem anderen Feld, oder eine
  /// Auffüllung, die enger zählt als die Absatzliste. Dann zeigte die Ziffer
  /// wieder auf eine Zeile, die es nicht gibt, und dorthin zu springen wäre
  /// schlechter als sie nicht anzufassen.
  InlineSpan _citationSpan(CitedReference reference, int sourceCount) {
    final Widget label = Padding(
      // `marginLeft: 1`, `:14`.
      padding: const EdgeInsets.only(left: 1),
      child: Text(
        reference.label,
        style: FactTypography.mono.copyWith(
          fontSize: 10,
          // `fontWeight: 800`. JetBrains Mono liegt im Projekt bis 600 vor,
          // die Engine wählt den nächsten Schnitt.
          fontWeight: FontWeight.w800,
          color: FactDetailPalette.citation,
          height: 1,
        ),
      ),
    );
    return WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: reference.sourceIndex < sourceCount
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _jumpToSources,
              child: label,
            )
          : label,
    );
  }

  /// `:29-33`: `scrollIntoView({ behavior: 'smooth', block: 'center' })` auf
  /// `#fact-sources`.
  ///
  /// `alignment: 0.5` ist `block: 'center'`. Das `scrollMarginTop: 80` aus
  /// `:478` ist **nicht** nachgebaut: es vergrößert in CSS den Scroll-Kasten
  /// des Ziels nach oben, mit `block: 'center'` landet die Liste dadurch 40
  /// Pixel unterhalb der Mitte. Flutters `ensureVisible` kennt keinen
  /// Scroll-Rand, und die 40 Pixel von Hand nachzurechnen hieße, eine
  /// CSS-Feinheit zu simulieren, die hier keinen Zweck erfüllt: die Quelle
  /// setzt sie für eine klebende Kopfzeile, und diese Seite hat keine.
  void _jumpToSources() {
    final BuildContext? target = _sourcesAnchor.currentContext;
    if (target == null) {
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: FactPage.sourceJumpDuration,
        curve: Curves.easeInOut,
      ),
    );
  }

  /// `:414`.
  Widget _showMoreButton(FactCategoryLook look, AppStrings strings) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showMore = true),
      child: Padding(
        // `padding: '0 0 16px'`, `:414`.
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          strings.text('fact.showMore'),
          style: FactTypography.heading.copyWith(
            fontSize: 13,
            color: look.color,
          ),
        ),
      ),
    );
  }

  /// `:477-498`.
  Widget _sourcesCard(
    List<FactSource> sources,
    FactDetailPalette palette,
    AppStrings strings,
  ) {
    return Container(
      key: FactPage.sourcesKey,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.fromBorderSide(BorderSide(color: palette.border)),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        key: _sourcesAnchor,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // `textTransform: 'uppercase'`, `:479`.
            strings.text('fact.sources').toUpperCase(),
            style: FactTypography.mono.copyWith(
              fontSize: 9,
              color: palette.ink3,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          for (final (int index, FactSource source) in sources.indexed) ...[
            if (index > 0) const SizedBox(height: 5),
            _sourceRow(index, source, palette),
          ],
        ],
      ),
    );
  }

  /// `:482-494`, ohne die Verlinkung. Begründung in `fact_sources.dart`.
  Widget _sourceRow(int index, FactSource source, FactDetailPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        ConstrainedBox(
          // `width: 18, flexShrink: 0`, `:483`. Als Mindestbreite und nicht
          // als feste: bei doppelter Systemschrift passt "[10]" sonst nicht
          // mehr hinein, und CSS hätte an dieser Stelle dasselbe Problem, nur
          // ohne mitwachsende Schrift.
          constraints: const BoxConstraints(minWidth: 18),
          child: Text(
            '[${index + 1}]',
            style: FactTypography.mono.copyWith(
              fontSize: 9,
              color: palette.ink3,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            source.name,
            style: FactTypography.bodyText.copyWith(
              fontSize: 13,
              height: 1.4,
              // `q.url ? cat.color : (q.missing ? ink3 : ink2)`, `:486` und
              // `:490`. Ohne Verlinkung bleiben die beiden hinteren Fälle.
              color: source.missing ? palette.ink3 : palette.ink2,
              // `fontStyle: q.missing ? 'italic' : 'normal'`, `:490`.
              //
              // **Nicht gemessen, ob daraus auf dem Schirm eine Schräge
              // wird:** `pubspec.yaml` führt für DM Sans nur Regular, Medium
              // und SemiBold, keinen kursiven Schnitt, und ob die Engine
              // für eine eigene Schriftfamilie eine Kursive nachbildet, ist
              // hier nicht nachgeprüft. Die Zeile steht trotzdem, weil sie
              // der Quelle entspricht und mit einem kursiven Schnitt sofort
              // wirkt. Tragendes Unterscheidungsmerkmal ist die blassere
              // Farbe eine Zeile darüber, und die ist gemessen.
              fontStyle: source.missing ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}

/// `#RRGGBB` in eine Farbe, oder `null`.
///
/// Der Mapper lässt in `Fact.heroColors` nur Hex-Werte durch, dieser Weg ist
/// also der Normalfall und keine Rettung.
Color? _hexColor(String value) {
  if (value.length != 7 || !value.startsWith('#')) {
    return null;
  }
  final int? rgb = int.tryParse(value.substring(1), radix: 16);
  if (rgb == null) {
    return null;
  }
  return Color(0xFF000000 | rgb);
}
