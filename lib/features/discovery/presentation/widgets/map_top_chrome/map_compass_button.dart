part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Der Kompass-Knopf, `screen-map.jsx:3152-3199`. Trägt den Anker `compass`.
@visibleForTesting
class MapCompassButton extends StatelessWidget {
  /// Erzeugt den Kompass-Knopf.
  const MapCompassButton({
    required this.palette,
    required this.bearingDegrees,
    required this.isDead,
    required this.tooltip,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Blickrichtung der Karte in Grad; die Nadel dreht dagegen.
  final double bearingDegrees;

  /// Ob der Gerätekompass stumm ist.
  final bool isDead;

  /// Beschriftung für die Sprachausgabe, `title` in der Quelle (`:3189`).
  final String tooltip;

  /// Kurzer Tipp.
  final VoidCallback? onTap;

  /// Langer Druck.
  final VoidCallback? onLongPress;

  /// Die beiden Erkenner, und warum es sie einzeln gibt.
  ///
  /// `GestureDetector` täte dasselbe, ließe aber die Dauer des langen Drucks
  /// nicht einstellen: sie steckt fest auf `kLongPressTimeout`, also 500
  /// Millisekunden. Die Quelle wartet **700**
  /// (`screen-map.jsx:3173`, der `setTimeout` im `onPointerDown`), und alles
  /// davor ist dort ein kurzer Druck. Siehe
  /// [MapTopChrome.compassLongPressDuration].
  ///
  /// **Ein Erkenner entsteht nur, wenn es für ihn einen Rückruf gibt**, genau
  /// wie `GestureDetector` es hält. Was das kostet, steht nicht in der
  /// Gestenarena, sondern in der Sprachausgabe.
  ///
  /// **Die frühere Begründung hier war falsch, und sie ist nachgemessen
  /// worden.** Sie lautete, ein Erkenner ohne Rückruf nähme „trotzdem an der
  /// Gestenarena teil und könnte einen Tipp verschlucken, der jemand anderem
  /// gehört". Das tut er nicht: `TapGestureRecognizer.isPointerAllowed`
  /// (`flutter/lib/src/gestures/tap.dart:692-701`) lehnt jeden Zeiger ab,
  /// solange alle primären Rückrufe `null` sind, und der lange Druck hält es
  /// genauso. An einer Wegwerf-Probe nachgestellt: ein Tipp auf den Kompass
  /// ohne Rückrufe erreichte den umschließenden `GestureDetector`, mit und
  /// ohne die beiden Bedingungen unten.
  ///
  /// **Der Preis, den es wirklich gibt, ist die Semantik.**
  /// `RawGestureDetector` leitet seine Semantik-Aktionen aus den vorhandenen
  /// Erkennern ab und nicht aus deren Rückrufen
  /// (`flutter/lib/src/widgets/gesture_detector.dart:1711-1727`,
  /// `_DefaultSemanticsGestureDelegate`). Ohne die Bedingungen trüge der Knopf
  /// `SemanticsAction.tap` und `SemanticsAction.longPress`, obwohl beide ins
  /// Leere laufen: eine Sprachausgabe böte eine Bedienung an, die nichts tut.
  /// Gemessen, und seither zugesichert in `map_top_chrome_test.dart`.
  Map<Type, GestureRecognizerFactory> _gestures() {
    return <Type, GestureRecognizerFactory>{
      if (onTap != null)
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (recognizer) => recognizer.onTap = onTap,
            ),
      if (onLongPress != null)
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: MapTopChrome.compassLongPressDuration,
              ),
              (recognizer) => recognizer.onLongPress = onLongPress,
            ),
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget needle = Transform.rotate(
      // `rotate(${-map.getBearing()}deg)`, `:1792`.
      angle: -bearingDegrees * math.pi / 180,
      child: Text(
        // Ein Piktogramm, kein Text: die Quelle schreibt es hart (`:3192`) und
        // führt dafür keinen Schlüssel.
        '🧭',
        // `fontSize: 20` aus `btnStyle` (`:3031`), `lineHeight: 1` (`:3192`).
        style: const TextStyle(fontSize: 20, height: 1),
        // Feste 44er Kachel: eine mitwachsende Nadel würde beschnitten.
        textScaler: TextScaler.noScaling,
      ),
    );
    if (isDead) {
      // `filter: grayscale(1)`, `:3192`. Die Koeffizienten sind die der
      // CSS-Filter-Spezifikation (Rec. 709).
      needle = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
        child: needle,
      );
    }

    return AnchorTarget(
      anchorId: DiscoveryAnchors.compass,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Opacity(
          // `opacity: compassDead ? 0.55 : 1`, `:3190`.
          opacity: isDead ? 0.55 : 1,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: _gestures(),
            child: _Blurred(
              // 44x44, `borderRadius: 14`, `btnStyle` in `:3027`.
              radius: 14,
              sigma: _blurStrong,
              background: palette.background,
              border: palette.border,
              size: const Size.square(MapTopChrome.compassSize),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  needle,
                  if (isDead)
                    Positioned(
                      // `top: 3, right: 5`, 8x8, `:3195`.
                      top: 3,
                      right: 5,
                      child: MapNotificationDot(
                        size: 8,
                        // `boxShadow: '0 0 0 2px ' + pill.bg`, `:3197`.
                        ringWidth: 2,
                        ringColor: palette.background,
                      ),
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
