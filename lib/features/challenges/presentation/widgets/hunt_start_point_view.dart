import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/challenges/application/hunt_start_options.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Startpunkt-Picker, `HotspotPickView` in
/// `02_Frontend/app/screen-challenge.jsx:2979-3102`.
///
/// ## Er ist Schritt 3 des Assistenten und trotzdem keine eigene Route
///
/// Dieselbe Begründung wie beim Assistenten selbst: die Quelle schaltet mit
/// `setView('hotspot')` (`:4325`) einen Zustand um, keinen Bildschirm, und der
/// Zurück-Weg führt mit `setView('setup')` (`:4444`) dahin zurück, wo man
/// herkam. E-25 hat die öffentliche Routenfläche auf sieben Pfade festgelegt;
/// ein achter für einen Assistentenschritt wäre die falsche Währung.
///
/// ## Er zeigt keine Karte
///
/// Das ist an der Quelle gemessen: eine Liste mit höchstens vier
/// Radioknöpfen. Die Regel aus Schritt 12, dass ein Feature den Karten-Host
/// nie selbst mountet, wird gar nicht berührt, und am Kameravertrag fehlt
/// nichts.
///
/// ## Rechnen tut hier nichts
///
/// Die Zeilen kommen fertig als [options] herein, gerechnet von
/// `hunt_start_options.dart`. Dieses Widget ordnet ihnen nur Sprachschlüssel
/// zu und zeichnet sie. Damit sind die 600 Meter, die Schwellen 15 und 5, die
/// Sortierung und der Fußweg ohne Widget prüfbar.
///
/// ## Was die Quelle hier nicht tut
///
/// `:3040` schreibt `const defaultIdx = userPosition ? 0 : 0;`, ein Ternär,
/// dessen beide Zweige denselben Wert haben. Die Vorauswahl ist damit immer
/// die erste Zeile, und die Fallunterscheidung ist tot. Übernommen ist das
/// Verhalten (erste Zeile vorausgewählt), nicht die tote Verzweigung.
class HuntStartPointView extends ConsumerStatefulWidget {
  /// Erzeugt den Picker.
  const HuntStartPointView({
    required this.options,
    required this.onPick,
    required this.onBack,
    super.key,
  });

  /// `padding: '24px 20px'`, `:3053`.
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 24,
  );

  /// `padding: 24` im leeren Zustand, `:3045`.
  static const EdgeInsets emptyPadding = EdgeInsets.all(24);

  /// Der Abstand vor dem Hinweistext im leeren Zustand, **zusätzlich** zu
  /// [emptyPadding].
  ///
  /// **16 und nicht 0.** `:3046` setzt am `<p>` keine eigene Schriftgröße, es
  /// erbt also die 16 Pixel des Fließtexts (`styles.css` setzt nirgends eine
  /// abweichende `font-size` auf `body` oder auf einen Vorfahren dieses
  /// Zweigs) und trägt damit den Browser-Standardrand eines Absatzes von 1em
  /// auf allen Seiten, hier also ebenfalls 16. Ein Innenabstand am
  /// Elternelement (`padding: 24`) verhindert, dass dieser Rand mit dem des
  /// Elternelements zusammenfällt: CSS-Randkollaps gilt nur zwischen
  /// **benachbarten** Rändern, und der Innenabstand liegt dazwischen. Macht
  /// zusammen 24 + 16 = 40 bis zum Text, nicht 24.
  static const double emptyTitleTopGap = 16;

  /// Der Abstand zwischen dem Hinweistext und dem Zurück-Knopf im leeren
  /// Zustand.
  ///
  /// **28 und nicht 12.** `:3047` setzt `marginTop: 12` am Knopf, aber ohne
  /// eigene `display`-Angabe: ein `<button>` ist im Browser-Standard
  /// `inline-block` und nicht `block`. Zum Vergleich setzen alle anderen
  /// Knöpfe dieser Datei (`:3065`, `:3088`, `:3096`) ausdrücklich
  /// `display: 'flex'` oder `display: 'block'`, nur dieser eine nicht; das
  /// ist an der Quelle geprüft und keine Annahme. CSS-Randkollaps gilt nur
  /// zwischen block-level Boxen im normalen Fluss, ein `inline-block` nimmt
  /// daran nie teil. Der untere Standardrand des Absatzes davor (16, siehe
  /// [emptyTitleTopGap]) und der obere Rand des Knopfes (12) addieren sich
  /// deshalb, statt dass das Maximum gilt: 16 + 12 = 28, nicht 12.
  static const double emptyBackButtonGap = 28;

  /// Abstand zwischen zwei Zeilen, `marginBottom: 10` an der Zeile, `:3070`.
  static const double optionGap = 10;

  /// Abstand von der letzten Zeile zum Startknopf.
  ///
  /// **16 und nicht 26.** Die Quelle setzt `marginBottom: 10` an der Zeile
  /// (`:3070`) und `marginTop: 16` am Knopf (`:3089`), und benachbarte
  /// senkrechte Ränder zweier Block-Boxen im normalen Fluss **fallen in CSS
  /// zusammen**: es gilt das Maximum, nicht die Summe. Derselbe Fehler steckte
  /// im alten Flutter-Port beim Bodenabstand der Reiterleiste, dort als Summe
  /// statt Maximum.
  static const double startButtonGap = 16;

  /// `marginTop: 8` am Zurück-Knopf, `:3096`. Der Startknopf hat keinen
  /// unteren Rand, hier fällt also nichts zusammen.
  static const double backButtonGap = 8;

  /// Der Zähler der Kickerzeile, `:3055`: „Schritt 3 von 3".
  static const int stepNumber = 3;

  /// Siehe [stepNumber]. Gleich der Gesamtzahl des Assistenten.
  static const int totalSteps = 3;

  /// Die Sprachschlüssel zu den sieben Dichte-Beschriftungen.
  ///
  /// Die Zuordnung steht hier und nicht in `hunt_start_options.dart`, weil
  /// Regel 15 Geschäftsregeln von Lokalisierung trennt. Öffentlich, damit
  /// `hunt_start_point_view_test.dart` nachzählen kann, dass jeder Wert von
  /// [HuntDensityLabel] einen Schlüssel hat: ein neuer Wert fiele sonst erst
  /// beim Zeichnen auf, und dann mit einem `null`-Zugriff.
  static const Map<HuntDensityLabel, String> densityTextKeys =
      <HuntDensityLabel, String>{
        HuntDensityLabel.localHigh: 'challenge.hotspot.densityLocalHigh',
        HuntDensityLabel.localMedium: 'challenge.hotspot.densityLocalMedium',
        HuntDensityLabel.localLow: 'challenge.hotspot.densityLocalLow',
        HuntDensityLabel.hotspotVeryHigh: 'challenge.hotspot.densityVeryHigh',
        HuntDensityLabel.hotspotHigh: 'challenge.hotspot.densityHigh',
        HuntDensityLabel.hotspotMedium: 'challenge.hotspot.densityMedium',
        HuntDensityLabel.hotspotUnknown: 'challenge.hotspot.density',
      };

  /// Die Zeile mit dem Index [index], für Tests.
  static Key optionKey(int index) => Key('hunt-start-option-$index');

  /// Der Radioknopf der Zeile mit dem Index [index], für Tests.
  ///
  /// Ohne eigenen Schlüssel wäre der ausgewählte Zustand nur über sein
  /// Rechteck ansprechbar, und `SizedBox.square` kommt in derselben Zeile
  /// mehrfach vor (Punkt, Mitte, äußerer Ring).
  static Key radioKey(int index) => Key('hunt-start-radio-$index');

  /// Der Startknopf, für Tests.
  static const Key startKey = Key('hunt-start-cta');

  /// Der Zurück-Knopf, für Tests. Gilt in beiden Zuständen.
  static const Key backKey = Key('hunt-start-back');

  /// Die Zeilen, höchstens vier, gerechnet von [huntStartOptions].
  ///
  /// Leer heißt: weder Nutzerposition noch Hotspot. Dann zeigt der Picker den
  /// Hinweis aus `:3046` statt der Liste.
  final List<HuntStartOption> options;

  /// Der Nutzer hat gewählt, `onPick(options[selectedIdx].point)`, `:3088`.
  ///
  /// Die Quelle ruft das an genau einer Stelle, und sie übergibt **immer**
  /// einen Punkt. Deshalb kennt `generateHuntRoute` seinen Zufallszweig für
  /// die erste Station nur aus Tests.
  final void Function(MapPosition point) onPick;

  /// Zurück in den Assistenten, `onBack`, `:3095` und `:3047`.
  final VoidCallback onBack;

  @override
  ConsumerState<HuntStartPointView> createState() => _HuntStartPointViewState();
}

class _HuntStartPointViewState extends ConsumerState<HuntStartPointView> {
  /// `const [selectedIdx, setSelectedIdx] = React.useState(defaultIdx)`,
  /// `:3041`. `defaultIdx` ist immer 0, siehe Klassenkopf.
  int _selected = 0;

  @override
  void didUpdateWidget(HuntStartPointView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Die Zeilen ändern sich, während der Picker offen ist: jede neue Ortung
    // sortiert die Hotspots um. Die Quelle hält `selectedIdx` dabei fest und
    // wählt damit unter Umständen einen anderen Hotspot aus als vorher; das
    // ist Parität. Was sie nicht kann und hier auffiele: eine Liste, die
    // **kürzer** wird, ließe `options[selectedIdx]` auf `undefined` laufen.
    // Deshalb hier die einzige Abweichung, und sie ist eine Absturzsicherung.
    if (_selected >= widget.options.length) {
      _selected = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.options.isEmpty) {
      return _empty(strings, colors);
    }

    return SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: HuntStartPointView.contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // `fontSize: 11, fontWeight: 700, letterSpacing: 1.5`,
              // `textTransform: 'uppercase'`, Farbe `var(--stamp)`, `:3054`.
              Text(
                strings
                    .text(
                      'challenge.hotspot.stepCounter',
                      params: <String, String>{
                        'step': '${HuntStartPointView.stepNumber}',
                        'total': '${HuntStartPointView.totalSteps}',
                      },
                    )
                    .toUpperCase(),
                style: FactTypography.bodyText.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: colors.red,
                ),
              ),
              // `marginBottom: 4` an der Kickerzeile, `:3054`.
              const SizedBox(height: 4),
              Text(
                strings.text('challenge.hotspot.title'),
                style: FactTypography.emphasis.copyWith(
                  fontSize: 26,
                  // `letter-spacing: -0.01em`, `:3057`. **Nicht**
                  // [FactTypography.displayTracking], das rechnet mit -0.02em.
                  letterSpacing: 26 * -0.01,
                  color: colors.ink,
                ),
              ),
              // `margin: '0 0 6px'` an der Überschrift (`:3057`) trifft auf
              // den oberen Standardrand des `<p>`, den `styles.css` nirgends
              // zurücksetzt: `1em` bei `font-size: 13`, also 13. Ränder fallen
              // zusammen, es gilt 13.
              const SizedBox(height: 13),
              Text(
                strings.text('challenge.hotspot.subtitle'),
                style: FactTypography.bodyText.copyWith(
                  fontSize: 13,
                  color: _inkSoft(isDark),
                ),
              ),
              // `marginBottom: 20` am Absatz, `:3058`.
              const SizedBox(height: 20),
              for (int i = 0; i < widget.options.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: HuntStartPointView.optionGap),
                _option(i, strings, colors, isDark),
              ],
              const SizedBox(height: HuntStartPointView.startButtonGap),
              _startButton(strings, colors),
              const SizedBox(height: HuntStartPointView.backButtonGap),
              _backButton(strings, isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// `options.length === 0`, `:3043-3049`.
  Widget _empty(AppStrings strings, FactColors colors) {
    return SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: HuntStartPointView.emptyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Siehe [HuntStartPointView.emptyTitleTopGap]: der geerbte
              // obere Rand des Absatzes kollabiert nicht mit dem
              // Innenabstand des Elternelements.
              const SizedBox(height: HuntStartPointView.emptyTitleTopGap),
              Text(
                strings.text('challenge.hotspot.empty'),
                style: FactTypography.bodyText.copyWith(color: colors.ink),
              ),
              // Siehe [HuntStartPointView.emptyBackButtonGap]: der geerbte
              // untere Rand des Absatzes und `marginTop: 12` am Knopf
              // addieren sich, statt zu kollabieren.
              const SizedBox(height: HuntStartPointView.emptyBackButtonGap),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  key: HuntStartPointView.backKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onBack,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.red,
                      // `borderRadius: 12`, `:3047`.
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Padding(
                      // `padding: '10px 18px'`, `:3047`.
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Text(
                        strings.text('common.back'),
                        style: FactTypography.bodyText.copyWith(
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Eine Zeile der Auswahl, `:3065-3084`.
  Widget _option(
    int index,
    AppStrings strings,
    FactColors colors,
    bool isDark,
  ) {
    final HuntStartOption option = widget.options[index];
    final bool selected = _selected == index;

    return GestureDetector(
      key: HuntStartPointView.optionKey(index),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = index),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // `rgba(232,56,13,0.10)` gegen `cardBg`, `:3068`. Der ausgewählte
          // Ton ist `--stamp` mit 10 Prozent und steht als Literal in der
          // Quelle; [FactColors.redSoft] trägt 0.12 und wäre der falsche Wert.
          color: selected
              ? const Color.fromRGBO(232, 56, 13, 0.10)
              : _cardBackground(isDark),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          // `1.5px solid ${selected ? stamp : 'transparent'}`, `:3069`. Der
          // durchsichtige Rahmen bleibt stehen, sonst hüpfte die Zeile beim
          // Auswählen um drei Pixel.
          border: Border.all(
            color: selected ? colors.red : const Color(0x00000000),
            width: 1.5,
          ),
        ),
        child: Padding(
          // `padding: '14px 16px'`, `:3067`.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            // `alignItems: 'flex-start'`, `:3066`.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // `marginTop: 2` am Punkt, `:3078`.
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: KeyedSubtree(
                  key: HuntStartPointView.radioKey(index),
                  child: _radio(selected, colors, isDark),
                ),
              ),
              // `gap: 12`, `:3066`.
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      option.isCurrentLocation
                          ? strings.text('challenge.hotspot.here')
                          : option.hotspotName!,
                      // `fontWeight: 700` ohne eigene Schriftfamilie, erbt
                      // also DM Sans aus `body` (`styles.css:116`), `:3081`.
                      style: FactTypography.bodyText.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    // `marginBottom: 2` am Titel, `:3081`.
                    const SizedBox(height: 2),
                    Text(
                      _hintOf(option, strings),
                      // `fontSize: 12`, `:3082`.
                      style: FactTypography.bodyText.copyWith(
                        fontSize: 12,
                        color: _inkSoft(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Die zweite Zeile einer Option, `:3026` und `:3034`.
  ///
  /// Das Trennzeichen ` · ` steht in der Quelle im Template-String und nicht
  /// im übersetzbaren Teil; deshalb steht es hier und nicht im Sprachwert.
  String _hintOf(HuntStartOption option, AppStrings strings) {
    final String density = strings.text(
      HuntStartPointView.densityTextKeys[option.density]!,
    );
    final int? minutes = option.walkingMinutes;
    if (minutes == null) {
      return density;
    }
    final String walk = strings.text(
      'challenge.hotspot.walkMinutes',
      params: <String, String>{'minutes': '$minutes'},
    );
    return '$density · $walk';
  }

  /// Der Radioknopf, `:3073-3079`.
  ///
  /// Der ausgewählte Zustand ist in der Quelle aus drei Schichten gebaut: ein
  /// zwei Pixel breiter Rahmen in `--stamp`, eine Füllung in `--stamp` und
  /// darüber ein `inset`-Schatten von drei Pixeln in der Flächenfarbe. Übrig
  /// bleibt ein Punkt von zehn Pixeln. `BoxShadow` kann kein `inset`, deshalb
  /// stehen hier drei ineinandergelegte Kreise mit denselben Maßen.
  ///
  /// `#1C1712` und `#FFF8EE` sind [FactColors.surface] in beiden Themes,
  /// nachgeschlagen und nicht geraten; als Literal stünden hier zwei Zahlen,
  /// die bei einer Themenänderung stehen blieben.
  Widget _radio(bool selected, FactColors colors, bool isDark) {
    return SizedBox.square(
      dimension: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? colors.red : const Color(0x00000000),
          border: Border.all(
            color: selected ? colors.red : _inkSoft(isDark),
            width: 2,
          ),
        ),
        child: selected
            ? Center(
                child: SizedBox.square(
                  dimension: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface,
                    ),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.red,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// „Hunt starten →", `:3088-3093`.
  ///
  /// **Nicht [PrimaryButton]**, obwohl der rot und breit ist: die Quelle
  /// benutzt hier nicht `className="btn"`, sondern einen eigenen Stil mit
  /// Radius 14 statt 16, Schriftgewicht 700 statt 900, einem einzigen
  /// Schatten `0 3px 0` statt zweien und ohne Drück-Animation. Wer den
  /// gemeinsamen Knopf einsetzt, zeigt einen anderen Knopf, als die PWA zeigt.
  Widget _startButton(AppStrings strings, FactColors colors) {
    return GestureDetector(
      key: HuntStartPointView.startKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onPick(widget.options[_selected].point),
      child: Semantics(
        button: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.red,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            boxShadow: <BoxShadow>[
              // `0 3px 0 #A82508`, `:3092`. Das ist [FactColors.redDark],
              // nachgeschlagen: beide Themes tragen `0xFFA82508`.
              BoxShadow(color: colors.redDark, offset: const Offset(0, 3)),
            ],
          ),
          child: Padding(
            // `padding: 14`, also auf allen Seiten, `:3089`.
            padding: const EdgeInsets.all(14),
            child: Text(
              strings.text('challenge.hotspot.startCta'),
              textAlign: TextAlign.center,
              // `fontFamily: 'Nunito', fontWeight: 700`, `:3091`. `.h` ist
              // 800 und `.d` ist 900, deshalb hier ausdrücklich 700.
              style: FactTypography.heading.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// „Zurück", `:3095-3099`.
  ///
  /// `common.back` aus den erzeugten Tabellen, nicht ein neuer Schlüssel: der
  /// Wert ist dort „Zurück" und „Back", also genau der Text der Quelle.
  Widget _backButton(AppStrings strings, bool isDark) {
    return GestureDetector(
      key: HuntStartPointView.backKey,
      behavior: HitTestBehavior.opaque,
      onTap: widget.onBack,
      child: Semantics(
        button: true,
        child: Padding(
          // `padding: 10`, `:3096`.
          padding: const EdgeInsets.all(10),
          child: Text(
            strings.text('common.back'),
            textAlign: TextAlign.center,
            style: FactTypography.bodyText.copyWith(
              fontSize: 13,
              color: _inkSoft(isDark),
            ),
          ),
        ),
      ),
    );
  }

  /// `inkSoft`, `:2982`. Literal in der Quelle und kein Token.
  Color _inkSoft(bool isDark) => isDark
      ? const Color.fromRGBO(255, 255, 255, 0.55)
      : const Color.fromRGBO(0, 0, 0, 0.55);

  /// `cardBg`, `:2983`. Ebenfalls Literal.
  Color _cardBackground(bool isDark) => isDark
      ? const Color.fromRGBO(255, 255, 255, 0.05)
      : const Color.fromRGBO(0, 0, 0, 0.04);
}
