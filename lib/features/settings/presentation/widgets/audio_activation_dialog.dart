import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/features/settings/presentation/notifiers/audio_mode_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Öffnet den Audio-Aktivierungsdialog.
///
/// Das ist der öffentliche Einstiegspunkt dieses Features für die
/// App-Komposition. `identity/presentation` darf `settings/presentation` nicht
/// importieren (Regel 8 der `dependency-rules.md`), deshalb ruft nicht der
/// Startbildschirm diese Funktion, sondern `SplashRoute.build` in
/// `lib/app/routing/app_routes.dart`. Regel 10 nennt genau diesen Weg: "an
/// app-level composition adapter".
///
/// ## `showDialog` und nicht eine Ebene im `Stack` des Startbildschirms
///
/// Die Quelle löst es als Ebene: `screen-auth.jsx:269` hält `showAudioDialog`
/// als Zustand des Bildschirms, die Überlagerung liegt mit `zIndex: 300` darin.
/// Ein Stack-Kind wäre also die wörtliche Übersetzung.
///
/// Trotzdem eine Route, aus drei Gründen:
///
/// 1. `architecture-overview.md:250` ist eindeutig: "Modals and full-screen
///    pages are routing decisions, not business decisions."
/// 2. Ein `DialogRoute` bringt die Fokusfalle, die Route-Semantik
///    (`scopesRoute`, `namesRoute`) und die Ansage als Dialog mit. Für einen
///    Bildschirm, dessen Inhalt sich an blinde Nutzer richtet, ist das nicht
///    Beiwerk, sondern die Hauptsache.
/// 3. Systemzurück schließt ihn ohne eine Zeile Code, siehe unten.
///
/// Das kollidiert nicht mit `docs/engineering/flutter.md:83`, das Widgets
/// "presentation-only navigation" ausdrücklich erlaubt.
///
/// ## `barrierDismissible: false`
///
/// Die Quelle hat auf der Überlagerung **keinen** `onClick`
/// (`screen-auth.jsx:240`), ein Tipp daneben tut dort also nichts. Genau das
/// bleibt so. Der Dialog hat zwei Ausgänge, beide beschriftet.
///
/// ## Systemzurück wirkt wie "Abbrechen"
///
/// Für diesen Fall gibt es keine Vorlage: die PWA läuft auf einem Bildschirm
/// ohne Zurück-Taste und behandelt ihn nicht. Gewählt wird die Bedeutung von
/// "Abbrechen", also schließen ohne zu speichern. Das ist das
/// Plattformverhalten eines Dialogs, und es ist die harmlosere Richtung: wer
/// versehentlich zurück tippt, hat nichts eingeschaltet, was er nicht wollte.
/// Umgesetzt ist das durch **Nichtstun**, `DialogRoute` kann es von sich aus.
///
/// Gibt ein `Future`, das mit dem Schließen des Dialogs erfüllt ist. Aufrufer,
/// die das nicht brauchen, klammern mit `unawaited`.
Future<void> showAudioActivationDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AudioActivationDialog.barrierColor,
    // `useSafeArea` bleibt auf `true`: die Überlagerung der Quelle liegt zwar
    // im Bildschirmrahmen, und der ist in der PWA schon um die Insets
    // eingerückt (`index.html:101-107`). Das ist derselbe Effekt.
    builder: (context) => const AudioActivationDialog(),
  );
}

/// Der Audio-Aktivierungsdialog, `02_Frontend/app/screen-auth.jsx:217-260`.
///
/// Erscheint **nur** auf Tippen des Kopfhörer-Knopfes des Startbildschirms
/// (`screen-auth.jsx:356`), nie von selbst.
///
/// ## Er hat keine "schon gefragt"-Merkung
///
/// `showAudioDialog` ist ein einfacher Zustand des Bildschirms
/// (`screen-auth.jsx:269`) und wird beim Schließen nur zurückgesetzt. Der
/// Dialog erscheint bei jedem Tippen erneut, auch wenn der Audio-Modus längst
/// an ist. Das ist belegtes Verhalten und wird nicht "verbessert": der Knopf
/// ist der einzige Ort auf diesem Bildschirm, an dem der Text überhaupt zu
/// lesen ist, und ein Knopf, der beim zweiten Tippen nichts tut, wäre für einen
/// Screenreader ein Blindgänger.
///
/// ## Die beiden Ausgänge
///
/// | Knopf | Wirkung in der Quelle |
/// |---|---|
/// | Abbrechen | `setShowAudioDialog(false)`, sonst nichts (`:418`) |
/// | Aktivieren | `Storage.setAudioMode(true)` und schließen (`:404-405`) |
///
/// "Abbrechen" speichert also **nichts**: es setzt den Modus nicht auf `false`
/// und merkt sich keine Ablehnung.
///
/// ## Was "Aktivieren" in der Quelle noch tut und hier nicht kann
///
/// `screen-auth.jsx:404-416` macht vier Dinge, gebaut ist nur das erste.
///
/// 1. `Storage.setAudioMode(true)` → hier über [AudioModeNotifier.enable].
/// 2. **iOS-DeviceMotion-Berechtigung anfragen** (`:407-411`). Die PWA braucht
///    das für die Schüttel-Geste zum Pausieren. In Flutter ist das eine
///    Plattform-Berechtigung samt Sensor-Paket, also eine eigene Entscheidung
///    mit Store-Folgen (Nutzungszweck im `Info.plist`). Nicht gebaut.
/// 3. `AudioPlayer.announceHelp()` nach 400 ms (`:415`), also gesprochene
///    Hilfe. Sprachausgabe ist Schritt 25 von 50, der TTS-Weg ist offene
///    Entscheidung E-15 in `REBUILD_STATUS.md`. Nicht gebaut.
/// 4. `fact_audio_help_shown` (`:413-414`). Steuert ausschließlich Punkt 3 und
///    hat ohne ihn keinen Konsumenten. Siehe `AudioModeStore`.
///
/// Die Gesten-Freigabe des Browsers (`audio-player.jsx:44-51`,
/// `window.__factAudioGestureOk`) ist eine reine Web-Beschränkung: iOS Safari
/// verwirft `speechSynthesis.speak()` ohne vorangegangene Nutzergeste
/// stillschweigend. Native Sprachausgabe kennt diese Regel nicht. Es gibt
/// dafür also nichts nachzubauen, und niemand muss danach suchen.
///
/// **Nach diesem Schritt setzt der Dialog eine Präferenz, die noch nichts
/// bewirkt.** Es gibt keine Wiedergabe, die sie liest.
///
/// ## Zwei bewusste Abweichungen im Layout, und wie weit sie tragen
///
/// Beide betreffen Fälle, die die Quelle nicht kennt, weil ein Browser sie
/// anders löst als Flutter: die Quelle kann nicht überlaufen, ein zu hoher
/// Kasten wächst dort einfach aus der Überlagerung heraus, und `#root
/// { overflow: hidden }` schneidet ab. In Flutter ist derselbe Zustand ein
/// Fehler.
///
/// - **Der Fließtext scrollt.** Er ist der mit Abstand höchste Teil des
///   Kastens, deshalb liegt er in einem `SingleChildScrollView`, während Titel
///   und Knopfzeile stehen bleiben: wer scrollen muss, soll die Knöpfe nicht
///   suchen.
/// - **Die Knopfzeile bricht um.** `Wrap` statt `Row`. Bei einer Zeile sieht
///   das identisch aus, `alignment: WrapAlignment.end` entspricht
///   `justifyContent: 'flex-end'`. Ab etwa Skalierung 1.5 rutscht "Aktivieren"
///   unter "Abbrechen", statt einen Overflow zu werfen.
///
/// ## Was damit abgesichert ist, und was nicht
///
/// **Nicht abgesichert sind Titel und Knopfzeile.** Beide schrumpfen nicht. Ab
/// einer bestimmten Textgröße überschreiten sie allein die Bildschirmhöhe, und
/// dann läuft der Kasten unten über, auch wenn der Fließtext gar nichts mehr
/// bekommt. Gemessen mit **geladenen echten Schriften** (siehe
/// `test/support/app_fonts.dart`) auf dem deutschen Text, Zahlen sind der
/// Überlauf nach unten in Pixeln:
///
/// | Fläche | 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 4.0 |
/// |---|---|---|---|---|---|---|
/// | 390 x 844 | sauber | sauber | sauber | sauber | sauber | 175 |
/// | 360 x 640 | sauber | sauber | sauber | sauber | sauber | 379 |
/// | 320 x 480 | sauber | sauber | sauber | 58 | 328 | 648 |
///
/// **Androids Systemmaximum ist 2.0**, iOS bleibt für Fließtext darunter. Der
/// erreichbare Bereich ist also auf allen drei Flächen sauber, und deshalb
/// bleibt das Verhalten wie es ist. Wer den Bereich darüber schließen will,
/// muss den Titel kürzbar machen oder den ganzen Kasten scrollen lassen, und
/// dann sind die Knöpfe nicht mehr immer sichtbar. Das ist ein Tausch, keine
/// Verbesserung, und gehört entschieden statt nebenbei gemacht.
///
/// `zIndex: 300` hat kein Gegenstück: eine Route liegt ohnehin über allem.
class AudioActivationDialog extends ConsumerWidget {
  /// Erzeugt den Dialog.
  const AudioActivationDialog({super.key});

  /// `background: 'rgba(0,0,0,0.55)'` der Überlagerung.
  ///
  /// Nicht der Standardwert `Colors.black54`, der ist 0.54.
  static const Color barrierColor = Color.fromRGBO(0, 0, 0, 0.55);

  /// `padding: 20` der Überlagerung, also der Mindestabstand des Kastens zum
  /// Bildschirmrand.
  static const EdgeInsets overlayPadding = EdgeInsets.all(20);

  /// `maxWidth: 360` des Kastens.
  static const double boxMaxWidth = 360;

  /// `padding: 24` des Kastens.
  static const EdgeInsets boxPadding = EdgeInsets.all(24);

  /// `borderRadius: 18` des Kastens.
  static const double cornerRadius = 18;

  /// `background: '#fff'` des Kastens.
  static const Color boxColor = Color(0xFFFFFFFF);

  /// `boxShadow: '0 20px 60px rgba(0,0,0,0.4)'`.
  ///
  /// Der Radius wird unverändert als `blurRadius` übernommen. Flutter rechnet
  /// ihn intern mit einer anderen Konstante in ein Sigma um als CSS; ohne
  /// Referenzscreenshot wäre jede Feinjustierung geraten. Genauso gelöst wie
  /// in `lib/app/shell/floating_tab_bar.dart:243`.
  static const BoxShadow boxShadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.4),
    offset: Offset(0, 20),
    blurRadius: 60,
  );

  /// `marginBottom: 12` unter dem Titel.
  static const double titleGap = 12;

  /// `marginBottom: 20` unter dem Fließtext.
  static const double bodyGap = 20;

  /// `gap: 10` zwischen den Knöpfen.
  static const double buttonGap = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return Padding(
      padding: overlayPadding,
      // `display: flex; align-items: center; justify-content: center`.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: boxMaxWidth),
          child: Semantics(
            // `role="dialog" aria-modal="true"
            // aria-labelledby="audio-dialog-title"`. Der Titel benennt die
            // Route, wie es `Dialog` aus Material intern auch tut.
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: strings.text('audio.dialog.title'),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
                boxShadow: <BoxShadow>[boxShadow],
              ),
              // Ohne `Material`-Vorfahren malt Flutter unter **jeden** Text
              // die gelbe Doppellinie, mit der es fehlenden Textstil meldet.
              // Der Dialog ist eine Route und liegt im Overlay des Navigators;
              // das `Scaffold` des Startbildschirms steht daneben und nützt
              // ihm nichts, und `DialogRoute` bringt selbst keines mit
              // (`material/dialog.dart:1837-1851`). Das täten `Dialog` und
              // `AlertDialog`, und dieser Kasten ist keines von beiden, weil
              // sein Aussehen aus `screen-auth.jsx` kommt. Dieselbe Falle wie
              // im `OnboardingHost` und in `app/startup_failure_app.dart`.
              //
              // `transparency`: die Fläche malt der `DecoratedBox` darüber
              // samt Radius und Schatten, ein `canvas` wäre sie doppelt.
              //
              // Der Basisstil ausdrücklich und nicht Materials Vorgabe.
              // Gesetzt ist genau das, was `screen-auth.jsx:226` am Kasten
              // stehen hat: `fontFamily: 'Nunito, sans-serif'`, sonst nichts.
              // Größe, Gewicht und Farbe setzt jeder Text selbst.
              //
              // Bis zum 29.08.2026 war das zugleich die einzige Sperre gegen
              // die Zeilenhöhe aus `theme.textTheme.bodyMedium`, die die
              // Quelle nicht kennt. Die sitzt jetzt app-weit in
              // `FactTheme._withoutTrackingAndLineHeight`; hier bleibt der
              // Familienwert stehen, weil er aus der Quelle kommt.
              child: Material(
                type: MaterialType.transparency,
                textStyle: const TextStyle(fontFamily: FactFont.display),
                child: Padding(
                  padding: boxPadding,
                  child: Column(
                    // Der Kasten ist so hoch wie sein Inhalt, `Center` gibt ihm
                    // lose Zusicherungen.
                    mainAxisSize: MainAxisSize.min,
                    // `stretch` zwingt den Kasten auf die eingehende Breite, also
                    // auf `min(Bildschirm - 40, 360)`. In CSS ist er `width: auto`,
                    // also `fit-content` bis `max-width: 360`, und würde bei
                    // kurzem Inhalt schmaler. Beim mehrzeiligen Fließtext dieses
                    // Dialogs greift in beiden Welten die Deckelung, der
                    // Unterschied ist heute also nicht zu sehen. Wer den Kasten
                    // je mit kurzem Text zeigt, sieht ihn.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _title(strings),
                      const SizedBox(height: titleGap),
                      // `Flexible` und nicht `Expanded`: bei kurzem Text soll der
                      // Kasten nicht auf die volle Höhe wachsen.
                      Flexible(
                        child: SingleChildScrollView(child: _body(strings)),
                      ),
                      const SizedBox(height: bodyGap),
                      _buttons(context, ref, strings),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `fontSize: 20, fontWeight: 900, color: '#1a1a1a'`.
  ///
  /// Die Familie steht am Kasten: `fontFamily: 'Nunito, sans-serif'`, also
  /// [FactTypography.emphasis].
  Widget _title(AppStrings strings) {
    return Text(
      strings.text('audio.dialog.title'),
      style: FactTypography.emphasis.copyWith(
        fontSize: 20,
        color: const Color(0xFF1A1A1A),
      ),
    );
  }

  /// `fontSize: 14, lineHeight: 1.5, color: '#333', whiteSpace: 'pre-wrap'`.
  ///
  /// ## Warum Nunito 600 und nicht 400
  ///
  /// Der Kasten setzt Nunito, der Fließtext setzt kein Gewicht und bleibt damit
  /// bei 400, dem Initialwert von `font-weight`. (`styles.css:113-119` setzt am
  /// `body` nur die Familie, kein Gewicht.) Nunito **400 gibt es in der PWA
  /// nicht**: `styles.css:3` lädt `Nunito:wght@600;700;800;900`. Nach dem
  /// Font-Matching von CSS sucht ein Browser bei gewünschten 400 zuerst 500,
  /// dann kleinere Gewichte, dann größere; hier bleibt als erster Treffer 600.
  /// Der Nutzer sieht also Nunito SemiBold, und genau das steht hier.
  ///
  /// Dasselbe Gewicht ist aus demselben Grund als Schriftdatei im Projekt
  /// (`pubspec.yaml`, Kommentar zu `Nunito-SemiBold.ttf`). Ein
  /// `fontWeight: w400` hätte sich auf Flutters Nächster-Nachbar-Suche
  /// verlassen, die zufällig zum selben Ergebnis kommt. Zufall ist kein Wert.
  ///
  /// `whiteSpace: 'pre-wrap'` braucht keine Umsetzung: `Text` behält `\n` und
  /// bricht lange Zeilen um. Der Text hat zwei `\n\n`, die drei Absätze müssen
  /// erhalten bleiben.
  Widget _body(AppStrings strings) {
    return Text(
      strings.text('audio.dialog.body'),
      // Gewicht 600 hat in `FactTypography` keine eigene Rolle, weil
      // `styles.css` dafür keine Klasse führt. Abgeleitet aus `heading`
      // (Nunito 800), genauso wie in `lib/app/shell/floating_tab_bar.dart:193`.
      style: FactTypography.heading.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.5,
        color: const Color(0xFF333333),
      ),
    );
  }

  /// Die Knopfzeile, `justifyContent: 'flex-end'` mit `gap: 10`.
  ///
  /// Reihenfolge wie in der Quelle: Abbrechen links, Aktivieren rechts
  /// (`screen-auth.jsx:254-255`).
  ///
  /// ## Hier stünde der Lautstärke-Hinweis, und er entfällt
  ///
  /// `screen-auth.jsx:246-252` rendert zwischen Fließtext und Knopfzeile einen
  /// gelben Hinweiskasten: `fontFamily: 'DM Sans', fontSize: 13,
  /// lineHeight: 1.4, background: 'rgba(245,197,24,0.15)', border: '1px solid
  /// rgba(245,197,24,0.45)', borderRadius: 10, padding: '10px 12px',
  /// marginBottom: 18, color: '#1a1a1a'`, Inhalt `🔊 ` plus
  /// `t('audio.dialog.volumeHint')`.
  ///
  /// **Diesen Schlüssel gibt es nicht.** Im ganzen App-Ordner der PWA ist die
  /// Verwendungsstelle der einzige Treffer, `audio-strings.jsx` kennt ihn
  /// weder auf Deutsch noch auf Englisch. `window.t` fällt auf den
  /// Schlüsselnamen zurück, die PWA zeigt dem Nutzer also wörtlich
  /// `🔊 audio.dialog.volumeHint`. Das ist ein Fehler der Quelle, kein Text.
  ///
  /// Nicht nachgebaut, und keine der beiden Notlösungen genommen: einen Text
  /// zu erfinden geht nicht, weil die Sprachdateien aus der PWA generiert
  /// werden und ein handgeschriebener Schlüssel beim nächsten Lauf von
  /// `tool/generate_i18n.dart` verschwindet, was `--check` rot macht. Einen
  /// rohen Schlüsselnamen anzuzeigen wäre die Übernahme des Fehlers.
  ///
  /// Zum Nachrüsten fehlt genau eine Sache: der fachlich festgelegte Text in
  /// der PWA. Danach ist es dieser Kasten mit den Maßen oben.
  Widget _buttons(BuildContext context, WidgetRef ref, AppStrings strings) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: buttonGap,
      runSpacing: buttonGap,
      children: <Widget>[
        _DialogButton(
          label: strings.text('audio.dialog.cancel'),
          // `background: '#eee', color: '#333', fontWeight: 700`.
          background: const Color(0xFFEEEEEE),
          foreground: const Color(0xFF333333),
          fontWeight: FontWeight.w700,
          onPressed: () => _cancel(context),
        ),
        _DialogButton(
          label: strings.text('audio.dialog.activate'),
          // `background: '#E8380D', color: '#fff', fontWeight: 900`. Literal
          // und nicht `FactColors.red`, obwohl der Wert derselbe ist: die
          // Quelle schreibt ihn hier direkt hin, der Kasten ist weiß und
          // themenunabhängig. Ein Token würde ihn im dunklen Theme mitziehen.
          background: const Color(0xFFE8380D),
          foreground: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w900,
          onPressed: () => _activate(context, ref),
        ),
      ],
    );
  }

  /// "Abbrechen": nur schließen.
  ///
  /// Speichert nichts. Setzt den Audio-Modus **nicht** auf `false` und merkt
  /// sich keine Ablehnung. Das ist wichtiger, als es aussieht: wer den Modus
  /// schon an hat und hier abbricht, muss ihn danach noch an haben.
  void _cancel(BuildContext context) => context.pop();

  /// "Aktivieren": Präferenz setzen und schließen.
  void _activate(BuildContext context, WidgetRef ref) {
    // Der Zustand steht sofort, gespeichert wird im Hintergrund. Das Schließen
    // hängt nicht am Schreibvorgang, deshalb ist das Loslassen hier richtig.
    //
    // `reportDetached` und nicht `unawaited`: ENG-FLUTTER §7 verlangt für
    // abgekoppelte Arbeit einen ausdrücklichen Helfer **und** eine
    // Fehlermeldung. Sobald echte Persistenz kommt, ist genau das der
    // Unterschied zwischen "Einstellung nach dem Neustart weg, niemand weiß
    // warum" und einer Meldung mit Stapelspur.
    reportDetached(
      ref.read(audioModeProvider.notifier).enable(),
      origin: 'settings.audio_mode.enable',
    );
    // `context.pop()` und nicht `Navigator.pop`: ADR-004, und
    // `tool/check_architecture.dart` meldet jeden `Navigator.`-Aufruf außerhalb
    // von `lib/app/routing/`.
    context.pop();
  }
}

/// Einer der beiden Knöpfe des Dialogs, `screen-auth.jsx:231-239`.
///
/// ## Schriftfamilie und Schriftgröße stehen nicht in der Quelle
///
/// Beide Knöpfe setzen nur ein Gewicht. Ein `<button>` erbt `font-family` und
/// `font-size` aber **nicht**, und `styles.css` hat keine Regel, die das
/// nachholt: der `*`-Block (`:107-111`) setzt nur `box-sizing`,
/// `font-smoothing` und `tap-highlight-color`, und die einzige `button`-Regel
/// im Stylesheet ist `.tab-pill button` (`:197`). Diese zwei Knöpfe rendern in
/// der PWA also in der Standardschrift des Browsers, während jeder andere Knopf
/// der App Nunito ausdrücklich setzt (`.btn` in `:139`, `.btn-game` in `:159`,
/// `.tab-pill button` in `:200`, `.chip` in `:224`).
///
/// Das ist erkennbar unbeabsichtigt. Übernommen wird deshalb die Absicht, nicht
/// die Standardschrift des Browsers: Nunito, wie der Kasten sie vorgibt, in
/// [fontSize] 14 wie der Fließtext. Zum Vergleich, falls das jemand anders
/// entscheidet: Chromium setzt für `<button>` `font: 400 13.333px Arial`.
///
/// **Ein sichtbarer Unterschied kommt dadurch dazu:** Arial hat kein Gewicht
/// 900. Die 700 des Abbrechen-Knopfes und die 900 des Aktivieren-Knopfes
/// landen dort beide auf Arial Bold, die zwei Knöpfe sehen in der PWA also
/// gleich fett aus. Nunito hat beide Schnitte, hier ist der Kontrast damit
/// tatsächlich zu sehen. Ich halte das für richtig, weil die Quelle die zwei
/// Gewichte ausdrücklich unterscheidet und die Hierarchie der beiden Knöpfe
/// genau so gemeint ist. Es ist aber eine Abweichung vom sichtbaren Zustand
/// der PWA und keine Übernahme.
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.fontWeight,
    required this.onPressed,
  });

  /// `padding: '10px 18px'`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 10,
  );

  /// `borderRadius: 10`.
  static const double cornerRadius = 10;

  /// Siehe Klassenkommentar: in der Quelle nicht gesetzt.
  static const double fontSize = 14;

  final String label;
  final Color background;
  final Color foreground;
  final FontWeight fontWeight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
        // Die Quelle hat keinen Druck-, Hover- oder Ripple-Zustand, nur
        // `cursor: pointer`. Deshalb kein `InkWell`: eine Wasserwelle wäre eine
        // erfundene Rückmeldung.
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(Radius.circular(cornerRadius)),
          ),
          child: Padding(
            padding: padding,
            child: Text(
              label,
              // `emphasis` ist Nunito 900, das Gewicht des Aktivieren-Knopfes.
              // Abbrechen überschreibt auf 700; auch dafür führt `styles.css`
              // keine Klasse.
              style: FactTypography.emphasis.copyWith(
                fontWeight: fontWeight,
                fontSize: fontSize,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
