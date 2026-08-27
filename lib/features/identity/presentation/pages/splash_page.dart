import 'dart:async';

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:fact_app/features/identity/presentation/widgets/fact_button.dart';
import 'package:fact_app/features/identity/presentation/widgets/fact_wordmark.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_backdrop.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_ghost_button.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_language_row.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pin_field.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_quote.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_stats_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Startbildschirm, `02_Frontend/app/screen-auth.jsx:265-422`.
///
/// ## Das ist kein Ladebildschirm
///
/// Es gibt hier keinen Timer, keine Mindestanzeigedauer und keinen
/// Ladeindikator. Der zeitgesteuerte Boot-Splash der PWA
/// (`index.html:222-245`, mit `MIN_MS = 1200` und `TIMEOUT_MS = 15000`) wurde am
/// 06.06.2026 in Commit `83be52f` absichtlich entfernt: das Skript beginnt mit
/// `if (!splash) return` und ist seitdem toter Code. Was "SplashScreen" heißt,
/// ist ein interaktiver Startbildschirm, der stehen bleibt, bis der Nutzer
/// tippt, und drei gleichrangige Ausgänge hat.
///
/// Dazu kommt der Kopfhörer-Knopf, der keinen Ausgang bildet, sondern einen
/// Dialog öffnet. Warum dieser Bildschirm seine Wirkung nicht selbst kennt,
/// steht bei [SplashPage.onAudioGuidePressed].
///
/// ## Eine bewusste Abweichung vom Layout der Quelle
///
/// **Überlauf.** Die PWA positioniert absolut und kann nicht überlaufen; Flutter
/// würde auf kurzen Bildschirmen einen Overflow-Fehler zeigen. Deshalb
/// `LayoutBuilder` plus `SingleChildScrollView` plus `ConstrainedBox` plus
/// `IntrinsicHeight`: auf hohen Bildschirmen wirkt der `flex: 1`-Abstandhalter
/// weiter, kurze Bildschirme scrollen. Ohne `IntrinsicHeight` wirft ein
/// `Spacer` in einem Scrollbereich, weil er dort unbegrenzt viel Platz
/// verlangt.
///
/// ## Safe Area: der ganze Bildschirm rückt ein, nicht nur der Inhalt
///
/// Belegt, nicht abgewogen. `index.html:101-107` setzt auf Mobil
/// `padding-top: env(safe-area-inset-top)` und `padding-bottom` an den `body`
/// und rechnet `#root` auf `100dvh` minus beide Insets. `ScreenFrame` ist mit
/// `height: 100%` das Kind darin (`chrome.jsx:133-136`). Der **ganze**
/// Bildschirm wird also nach unten geschoben, Verlauf und Pins eingeschlossen.
/// Eine zweite Lesart gibt es nicht.
///
/// Gerechnet auf einem iPhone 14 mit 47 dp Inset:
///
/// | Element | PWA | mit SafeArea um den Stack | nur um den Inhalt |
/// |---|---|---|---|
/// | Wortmarke | 47 + 60 + 110 = 217 | 217 | 217 |
/// | Pin 3 (`top: 70`) | 47 + 70 = 117 | 117 | 70 |
///
/// Die Wortmarke sitzt in beiden Varianten richtig, weil sie in der
/// Inhaltsspalte hängt. Die Pins wären ohne Safe Area 47 dp zu hoch. Deshalb
/// liegt die `SafeArea` um den ganzen `Stack`.
///
/// Dass `chrome.jsx:128,144,146` Statusleiste und Home-Indikator nur in der
/// Desktop-Rahmenansicht zeichnet, sagt darüber nichts: das ist die Attrappe
/// für die Vorschau am Rechner, nicht die Behandlung echter Geräte-Insets.
///
/// ## Schmale Geräte und große Systemschrift: gemessen, nicht geschätzt
///
/// Die Quelle ist auf 390 logische Pixel Breite gebaut (`chrome.jsx:135`), und
/// die Sprachauswahl hat quer wenig Luft. Ein früherer Stand dieses Kommentars
/// hielt jede Messung dazu für unbrauchbar, weil `flutter test` die Schriften
/// aus `pubspec.yaml` nicht lädt und jeden Buchstaben als Quadrat der
/// Schriftgröße zeichnet. Das war richtig und ist erledigt:
/// `test/support/app_fonts.dart` lädt sie, und die Tests dieses Bildschirms
/// benutzen den Helfer. Zum Größenvergleich: "FACT" belegt mit der
/// Ersatzschrift 256 Pixel bei Größe 64, in Nunito Black 166.
///
/// Mit echten Schriften gemessen, deutscher Text, `textScaler` bis 4.0 auf
/// 390 x 844, 360 x 640 und 320 x 480: der Bildschirm läuft **nirgends** über.
/// Dafür waren zwei Eingriffe nötig, beide begründet an ihrer Stelle:
///
/// - [FactWordmark] folgt der Textgrößen-Einstellung nicht. Ohne das lief die
///   Logo-Zeile bei Skalierung 2.0 auf 390 Pixeln um 65 Pixel über.
/// - Der Kopfhörer-Knopf in [SplashLanguageRow] ist in der Breite gedeckelt.
///   Ohne das nahm er den Sprachkarten bei 360 Pixeln und Skalierung 2.0 so
///   viel Platz, dass deren innere Zeile um 3,8 Pixel überlief.
///
/// **Was das nicht sagt:** wie es aussieht. Kein Überlauf heißt nicht lesbar.
/// Bei Skalierung 2.0 auf 320 Pixeln bricht der Untertitel der Sprachkarten
/// nach jedem Wort um. Das ist am Gerät zu beurteilen, und dafür braucht es den
/// ersten Gerätebuild, siehe `HANDOFF.md`.
class SplashPage extends ConsumerStatefulWidget {
  /// Erzeugt den Startbildschirm.
  const SplashPage({required this.onAudioGuidePressed, super.key});

  /// Dauer der Eintritts-Animation, `.screen-transition { animation: slideUp
  /// 0.22s ease }` (`index.html:110-112`, angewendet in `app.jsx:1051`).
  static const Duration entryDuration = Duration(milliseconds: 220);

  /// Startversatz der Eintritts-Animation, `translateY(24px)`.
  ///
  /// **Nicht** der Wert aus `styles.css:251`. `slideUp` ist zweimal definiert;
  /// der Inline-Block in `index.html:25` steht nach dem Stylesheet und gewinnt
  /// bei gleichnamigen `@keyframes`. Dort sind es 24 Pixel plus Deckkraft, in
  /// `styles.css` wären es 100 Prozent Höhe ohne Deckkraft. Wer nur das
  /// Stylesheet liest, baut das Falsche.
  static const double entryOffset = 24;

  /// `padding: '60px 22px 40px'` der Inhaltsspalte.
  static const EdgeInsets contentPadding = EdgeInsets.only(
    top: 60,
    left: 22,
    right: 22,
    bottom: 40,
  );

  /// `marginTop: 110` über der Wortmarke.
  static const double wordmarkTopInset = 110;

  /// Was rings um den Bildschirm und hinter ihm liegt: `#0f0d0a`.
  ///
  /// Das ist der `body`-Hintergrund der PWA auf Mobil (`index.html:101-103`).
  /// Er ist an genau zwei Stellen zu sehen, und beide sind dieselbe Fläche:
  ///
  /// - in den Streifen über und unter der Safe Area, weil das Inset ein
  ///   `padding` des `body` ist und der `body` seinen Hintergrund unter das
  ///   Padding legt;
  /// - während der Eintritts-Animation, also in den 24 Pixeln, die der
  ///   einfahrende Bildschirm freilässt, und unter der Deckkraftblende.
  ///   `.screen-transition` umschließt in `app.jsx:1050-1052` den ganzen
  ///   `SplashScreen` **samt** `ScreenFrame`; es bewegt sich also alles
  ///   gemeinsam, und dahinter liegt `#root` ohne eigenen Hintergrund
  ///   (`index.html:64-70`), damit der `body`.
  ///
  /// Bewusst **nicht** `tok.bg` aus `useAuthTokens` (`screen-auth.jsx:11`).
  /// Diese Farbe ist auf diesem Bildschirm überhaupt nicht sichtbar: der
  /// vierschichtige Verlauf liegt mit `position: absolute; inset: 0` darüber
  /// (`screen-auth.jsx:274-277`) und deckt sie vollständig ab. Ein früherer
  /// Stand hatte hier `#13100E`, also `tok.bg` des **dunklen** Themes, während
  /// `app.dart` bewusst hell startet (`storage.jsx:117`). Das war zweifach
  /// falsch: falsches Theme und falsches Element.
  static const Color surface = Color(0xFF0F0D0A);

  /// Was der Kopfhörer-Knopf auslöst.
  ///
  /// ## Warum der Knopf seine Wirkung nicht selbst kennt
  ///
  /// Der Bildschirm gehört `identity`, die Audio-Präferenz gehört `settings`
  /// (`lib/features/README.md:22`). Regel 8 der `dependency-rules.md` verbietet
  /// einem Feature, das `presentation`-Verzeichnis eines anderen zu
  /// importieren: `identity/presentation` darf `settings/presentation` also
  /// nicht kennen, und der Dialog liegt dort.
  ///
  /// Regel 10 nennt den erlaubten Weg, "an app-level composition adapter", und
  /// die Tabelle in derselben Datei erlaubt der App-Komposition "all public
  /// feature entry points". Genau das passiert:
  /// `SplashRoute.build` in `lib/app/routing/app_routes.dart` setzt hier
  /// `showAudioActivationDialog` ein. Die Kopplung sitzt damit an der einen
  /// Stelle, die beide Features kennen darf.
  ///
  /// **Das ist keine überflüssige Indirektion, und sie darf nicht
  /// zusammengezogen werden.** Wer die Öffnen-Funktion direkt hier aufruft,
  /// bricht Regel 8, und `tool/check_architecture.dart` meldet es. Der Knopf
  /// selbst und seine Beschriftung bleiben Sache dieses Bildschirms, nur seine
  /// Wirkung kommt von außen.
  final VoidCallback onAudioGuidePressed;

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    duration: SplashPage.entryDuration,
    vsync: this,
  );
  bool? _animationsDisabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nicht in `initState`: `MediaQuery` darf erst hier gelesen werden, und die
    // Systemeinstellung kann sich zur Laufzeit ändern.
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled == _animationsDisabled) {
      return;
    }
    _animationsDisabled = disabled;
    if (disabled) {
      // Statisch im Endzustand: sichtbar, ohne Versatz.
      _entry
        ..stop()
        ..value = 1;
    } else {
      // `forward()` liefert ein `TickerFuture`, das erst am Ende der Animation
      // erfüllt wird. Hier interessiert das Ende nicht.
      //
      // Bewusst `unawaited` und **nicht** `reportDetached`: ein
      // `TickerFuture` scheitert mit `TickerCanceled`, wenn das Widget
      // mitten in der Animation entsorgt wird. Das ist der Normalfall beim
      // Wegnavigieren, keine Störung, und würde als gemeldeter Fehler jeden
      // Test rot machen, der den Startbildschirm früh verlässt.
      unawaited(_entry.forward());
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  /// Der Gast-Ausgang, `onNav('map')` in der Quelle.
  ///
  /// ## Bewusste Abweichung von der PWA
  ///
  /// Die PWA setzt `fact_has_launched` in **jeder** Navigation
  /// (`app.jsx:476-477`), also auch beim Tippen auf "Jetzt registrieren". Wer
  /// die Registrierung abbricht und die App neu startet, sieht den
  /// Startbildschirm damit nie wieder. Der Kommentar in `app.jsx:525-527` zeigt,
  /// dass um diese Eigenheit herumgepatcht wurde, statt sie zu beheben.
  ///
  /// Hier wird die Merkung nur auf diesem Weg gesetzt. Anmeldung und
  /// Registrierung setzen sie bei **erfolgreichem** Abschluss, das ist Schritt 9
  /// und 10.
  void _exploreWithoutAccount() {
    // Der Zustand steht sofort, gespeichert wird im Hintergrund. Die Navigation
    // hängt nicht am Schreibvorgang, deshalb ist das Loslassen hier richtig.
    // `reportDetached` statt `unawaited`, weil ENG-FLUTTER §7 zum Helfer auch
    // eine Fehlermeldung verlangt: ein stillschweigend gescheitertes Speichern
    // führt dazu, dass der Startbildschirm nach dem Neustart wieder erscheint,
    // ohne dass irgendwo eine Spur davon liegt.
    reportDetached(
      ref.read(firstLaunchProvider.notifier).markLaunched(),
      origin: 'identity.first_launch.mark',
    );
    // Die Weiche in `route_guards.dart` würde nach dem Setzen der Merkung von
    // selbst hierher schicken. Der Aufruf steht trotzdem hier, weil dieser
    // Bildschirm sein Ziel benennen soll, statt sich auf eine Nebenwirkung zu
    // verlassen.
    const MapRoute().go(context);
  }

  /// `push` und nicht `go`: der Zurück-Pfeil der Anmeldung führt in der Quelle
  /// auf den Startbildschirm (`screen-auth.jsx:486` ruft `onNav('onboarding')`).
  /// Mit `push` erledigt das der Systemzurück-Weg von selbst.
  ///
  /// `unawaited` und nicht `reportDetached`: das `Future` von `push` liefert
  /// den Rückgabewert der geschlossenen Route, es trägt keinen
  /// Schreibvorgang, der scheitern könnte.
  void _openLogin() => unawaited(const LoginRoute().push<void>(context));

  /// Wie [_openLogin], für die Registrierung.
  void _openSignup() => unawaited(const SignupRoute().push<void>(context));

  void _selectLanguage(AppLanguage language) {
    // Wie bei der Erstlauf-Merkung: die Oberfläche schaltet sofort um, das
    // Speichern läuft hinterher und meldet sich, wenn es scheitert.
    reportDetached(
      ref.read(appLanguageProvider.notifier).select(language),
      origin: 'app.language.select',
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dunkler Untergrund verlangt helle Symbole. `chrome.jsx:130` rechnet den
      // `tone` der Statusleiste genauso: dunkles Theme, also `'light'`. Auf
      // Mobil zeichnet die PWA keine Statusleiste und kann das nicht selbst
      // zeigen, die Absicht steht aber im Code.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: SplashPage.surface,
        body: _EntryTransition(
          progress: _entry,
          // Die `SafeArea` umschließt den ganzen Stapel, weil das Inset in der
          // Quelle ein `padding` des `body` ist und damit auch Verlauf und Pins
          // verschiebt. Siehe die Rechnung im Klassenkommentar.
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const SplashBackdrop(),
                const SplashPinField(),
                _content(strings, language),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(AppStrings strings, AppLanguage language) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: SplashPage.contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: SplashPage.wordmarkTopInset),
                  const FactWordmark(),
                  const SizedBox(height: 22),
                  const SplashQuote(),
                  const SizedBox(height: 32),
                  SplashStatsStrip(strings: strings),
                  // `<div style={{ flex: 1 }}/>`.
                  const Spacer(),
                  SplashLanguageRow(
                    strings: strings,
                    activeLanguage: language,
                    onLanguageSelected: _selectLanguage,
                    onAudioGuidePressed: widget.onAudioGuidePressed,
                  ),
                  const SizedBox(height: 14),
                  FactButton(
                    label: strings.text('splash.createAccountCta'),
                    onPressed: _openSignup,
                    // `padding: '16px', fontSize: 18, letterSpacing: 0.02`
                    // überschreiben die Maße von `.btn`.
                    padding: const EdgeInsets.all(16),
                    fontSize: 18,
                    letterSpacing: 0.02,
                  ),
                  const SizedBox(height: 10),
                  SplashGhostButton.secondary(
                    label: strings.text('auth.signIn'),
                    onPressed: _openLogin,
                  ),
                  const SizedBox(height: 14),
                  SplashGhostButton.tertiary(
                    label: strings.text('splash.exploreWithoutAccount'),
                    onPressed: _exploreWithoutAccount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `@keyframes slideUp { from { translateY(24px); opacity: 0 } to
/// { translateY(0); opacity: 1 } }` über 220 Millisekunden.
///
/// `Curves.ease` ist genau die CSS-Zeitfunktion `ease`, also
/// `cubic-bezier(0.25, 0.1, 0.25, 1)`.
///
/// Kein `SlideTransition`: dessen Versatz zählt in Anteilen der eigenen Größe,
/// die Quelle verschiebt aber um absolute 24 Pixel.
class _EntryTransition extends StatelessWidget {
  const _EntryTransition({required this.progress, required this.child});

  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final t = Curves.ease.transform(progress.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, SplashPage.entryOffset * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
