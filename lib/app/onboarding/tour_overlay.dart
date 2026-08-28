import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/onboarding/tour_steps.dart';
import 'package:fact_app/app/onboarding/widgets/tour_arrow.dart';
import 'package:fact_app/app/onboarding/widgets/tour_arrow_geometry.dart';
import 'package:fact_app/app/onboarding/widgets/tour_bubble.dart';
import 'package:fact_app/app/onboarding/widgets/tour_chrome.dart';
import 'package:fact_app/app/onboarding/widgets/tour_hero_view.dart';
import 'package:fact_app/app/onboarding/widgets/tour_highlight.dart';
import 'package:fact_app/app/onboarding/widgets/tour_palette.dart';
import 'package:fact_app/app/shell/shell_anchors.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Das Tutorial-Overlay, `02_Frontend/app/screen-tour.jsx:136-511`.
///
/// Es liegt über der laufenden App, verdunkelt sie und zeigt neun Schritte.
/// Ein Tipp irgendwohin schaltet weiter, "Überspringen" beendet sofort. Beide
/// Ausgänge melden über [onFinished] dasselbe: das Tutorial ist erledigt.
///
/// ## Der Tipp-Bereich ist der Elternteil und kein Geschwisterkind
///
/// In der Quelle ist das klickbare `div` der **Vater** von Blase, Pfeil und
/// Ring (`screen-tour.jsx:437` und `:452-506`), ein Klick auf die Blase blubbert
/// also nach oben und schaltet weiter. In Flutter ist das keine Kleinigkeit:
/// `RenderStack` hört beim ersten getroffenen Kind auf, ein Tipp auf einen Text
/// erreicht ein daruntergelegtes Geschwisterkind also **nicht**. Der
/// `GestureDetector` sitzt deshalb um den ganzen `Stack` und nicht als unterste
/// Ebene darin. "Überspringen" gewinnt trotzdem, weil von zwei geschachtelten
/// Tipp-Erkennern der innere die Gestenarena gewinnt.
///
/// ## Wann gemessen wird
///
/// Nicht einmal beim Aufbau. Die Quelle misst in einem `requestAnimationFrame`
/// und erneut bei jedem `resize` (`screen-tour.jsx:180-264`); ein Nachbau, der
/// nur in `initState` misst, sitzt nach einer Drehung oder bei offener Tastatur
/// falsch. Gemessen wird hier nach jedem Frame, in dem sich etwas geändert hat,
/// das die Lage beeinflussen kann:
///
/// - beim ersten `didChangeDependencies`, also vor dem ersten sichtbaren Frame;
/// - bei jedem Schrittwechsel, weil dann ein anderer Anker gefragt ist;
/// - bei jeder Änderung der `MediaQuery`, also bei Drehung, Fenstergröße,
///   Tastatur und Systemschriftgröße. Damit diese Abhängigkeit wirklich
///   besteht, liest [build] `MediaQuery.sizeOf` **immer**, auch wenn der Wert
///   gar nicht gebraucht wird. Ohne das gäbe es nach dem ersten erfolgreichen
///   Messen keine Abhängigkeit mehr und keine Benachrichtigung.
///
/// Gemessen wird jeweils in einem `addPostFrameCallback`, weil die neuen
/// Rechtecke erst nach dem Layout feststehen.
///
/// **Was das nicht abdeckt:** ein Anker, der später auftaucht, ohne dass dieses
/// Widget neu baut. Der Fall entsteht ab Phase 2, wenn die Karte ihre Marker
/// nachlädt. Die Quelle hat dieselbe Lücke, sie misst ebenfalls nur bei
/// Schrittwechsel und `resize`.
class TourOverlay extends ConsumerStatefulWidget {
  /// [onFinished] wird genau einmal gerufen, wenn der Nutzer durch ist oder
  /// überspringt.
  const TourOverlay({required this.onFinished, super.key});

  /// Das Tutorial ist erledigt.
  final VoidCallback onFinished;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay> {
  /// Der laufende Schritt, ab 0 gezählt, wie `step` in der Quelle.
  int _index = 0;

  /// Das zuletzt gemessene Rechteck des Ziels, oder `null`.
  ///
  /// `null` heißt **degradieren**, nicht überspringen: Blase, Schrittanzeige,
  /// Punktreihe und "Überspringen" bleiben, nur Pfeil und Ring fehlen
  /// (`screen-tour.jsx:254`, `:447`, `:450`).
  Rect? _targetRect;

  /// Die zuletzt gemessene Bezugsfläche.
  Size? _frameSize;

  /// Das zuletzt gemessene Rechteck der unteren Shell-Leiste, oder `null`,
  /// solange noch nichts gemessen ist.
  ///
  /// Aus ihm kommt der einzige Wert, den das untere Chrome braucht: die
  /// Oberkante der Leiste. Warum gemessen und nicht gerechnet, steht bei
  /// [TourBottomChrome].
  Rect? _bottomBarRect;

  AnchorRegistry? _registry;
  bool _measureScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gemerkt statt in jedem Messlauf nachgeschlagen: ein
    // `dependOnInheritedWidgetOfExactType` außerhalb von `build` und
    // `didChangeDependencies` ist kein vorgesehener Weg.
    _registry = AnchorScope.maybeOf(context);
    _scheduleMeasure();
  }

  /// Meldet einen Messlauf für nach dem laufenden Frame an.
  ///
  /// Mehrfache Anmeldungen im selben Frame fallen zusammen. Ohne diese Sperre
  /// würde jeder Auslöser einen eigenen Rückruf anlegen, und ein Messlauf, der
  /// `setState` ruft, würde die nächsten gleich mit auslösen.
  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }
      _measure();
    });
  }

  void _measure() {
    final registry = _registry;
    final step = TourSteps.all[_index];
    final rect = registry == null || step is! TourAnchoredStep
        ? null
        : registry.rectOf(step.anchorId);
    final frame = registry?.frameSize;
    // Die untere Shell-Leiste ist kein Ziel eines Schritts, sondern die
    // Messstelle für das Chrome darüber. Sie wird bei jedem Lauf mitgemessen,
    // weil sie mit der Systemschriftgröße wächst.
    final bottomBar = registry?.rectOf(ShellAnchors.bottomBar);
    if (rect == _targetRect &&
        frame == _frameSize &&
        bottomBar == _bottomBarRect) {
      // Ohne diesen Vergleich liefe jeder Messlauf in ein `setState`, das den
      // nächsten Frame anfordert, und die Suite käme aus `pumpAndSettle` nie
      // zurück.
      return;
    }
    setState(() {
      _targetRect = rect;
      _frameSize = frame;
      _bottomBarRect = bottomBar;
    });
  }

  /// Ein Tipp irgendwohin, `screen-tour.jsx:263-270`.
  void _next() {
    if (_index >= TourSteps.count - 1) {
      widget.onFinished();
      return;
    }
    setState(() {
      _index++;
      // Das Rechteck des vorigen Schritts wird sofort ungültig. Es stehen zu
      // lassen hieße, für einen Frame auf das falsche Ziel zu zeigen.
      _targetRect = null;
    });
    _scheduleMeasure();
  }

  /// "Überspringen", `screen-tour.jsx:272-275`. Dieselbe Wirkung wie das Ende
  /// des letzten Schritts.
  void _skip() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    // Absichtlich immer gelesen und nicht erst hinter dem `??`: der Aufruf
    // stellt die Abhängigkeit zur `MediaQuery` her, und die ist der Auslöser
    // für ein erneutes Messen bei Drehung, Tastatur oder Fenstergröße.
    final fallbackSize = MediaQuery.sizeOf(context);
    final frameSize = _frameSize ?? fallbackSize;
    final strings = ref.watch(appStringsProvider);
    final step = TourSteps.all[_index];
    // Der Abstand der Leistenoberkante vom unteren Bildschirmrand. Ohne
    // Messung der Ersatzwert, siehe `TourBottomChrome.fallbackBarInset`.
    final barRect = _bottomBarRect;
    final barInset = barRect == null
        ? TourBottomChrome.fallbackBarInset(context)
        : frameSize.height - barRect.top;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(
            color: step is TourHeroStep
                ? TourPalette.heroScrim
                : TourPalette.stepScrim,
          ),
          ...switch (step) {
            final TourHeroStep hero => <Widget>[
              TourHeroView(
                title: strings.text(hero.titleKey),
                body: strings.text(hero.bodyKey),
                meta: strings.text(hero.metaKey),
              ),
            ],
            final TourAnchoredStep anchored => _anchoredLayers(
              step: anchored,
              strings: strings,
              frameSize: frameSize,
              bottomReserve: TourBottomChrome.bubbleReserve(context, barInset),
            ),
          },
          TourSkipButton(label: strings.text('tour.skip'), onSkip: _skip),
          TourTapHint(
            label: strings.text('tour.tapHint'),
            bottom: TourBottomChrome.tapHintBottom(barInset),
          ),
          TourStepDots(
            count: TourSteps.count,
            current: _index,
            bottom: TourBottomChrome.dotsBottom(barInset),
          ),
        ],
      ),
    );
  }

  /// Ring, Pfeil und Blase eines regulären Schritts, in der Reihenfolge der
  /// `zIndex`-Werte der Quelle: Ring 8, Pfeil 9, Blase 10
  /// (`screen-tour.jsx:87`, `:44` und `:475`).
  List<Widget> _anchoredLayers({
    required TourAnchoredStep step,
    required AppStrings strings,
    required Size frameSize,
    required double bottomReserve,
  }) {
    final rect = _targetRect;
    final geometry = TourArrowGeometry.forTarget(
      target: rect,
      bubbleTop: step.bubbleTop,
      frameWidth: frameSize.width,
      curve: step.curve,
    );

    return <Widget>[
      // Die Schlüssel bilden `key={'h-' + step}` und `key={'a-' + step}` ab
      // (`screen-tour.jsx:449` und `:453`). Sie erzwingen einen Neuaufbau beim
      // Schrittwechsel, damit die Pulsation nicht mitten in der Welle
      // weiterläuft.
      if (rect != null)
        TourHighlight(key: ValueKey<String>('ring-${step.number}'), rect: rect),
      if (geometry != null)
        TourArrow(
          key: ValueKey<String>('arrow-${step.number}'),
          geometry: geometry,
        ),
      TourBubble(
        top: step.bubbleTop,
        bottomReserve: bottomReserve,
        counter: strings.text(
          'tour.stepCounter',
          params: <String, String>{
            'step': '${step.number}',
            'total': '${TourSteps.count}',
          },
        ),
        title: strings.text(step.titleKey),
        body: strings.text(step.bodyKey),
      ),
    ];
  }
}
