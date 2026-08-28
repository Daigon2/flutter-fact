import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';

/// Spannt eine Ankerverwaltung über seinen Teilbaum auf und ist zugleich deren
/// Bezugsfläche.
///
/// ## Warum ein `InheritedWidget` und kein Provider
///
/// `core` darf Riverpod importieren, aber ein Anker-Scope ist kein
/// Dependency-Injection-Fall. Er ist baumgebundener Kontext in derselben
/// Kategorie wie `Theme` und `MediaQuery`: seine Bedeutung hängt daran, **wo**
/// im Baum er hängt, denn genau dieser Ort ist die Bezugsfläche, gegen die
/// gemessen wird. Ein Provider hat keinen Ort im Widgetbaum und könnte das
/// nicht leisten.
///
/// Eine globale `static`-Registry wäre der dritte denkbare Weg und ist
/// ausgeschlossen: ADR-005 verwirft die "manual singleton registry"
/// ausdrücklich, und sie würde Anmeldungen über die Lebensdauer eines
/// Bildschirms hinaus halten. Hier stirbt die Registry mit ihrem Scope.
///
/// ## Die Bezugsfläche ist dieses Widget
///
/// Genauer: das erste `RenderBox` unterhalb des Scopes, also das Renderobjekt
/// von [child]. Der Scope selbst legt keines an, weil er sonst am Layout
/// mitreden würde, das er nur beobachten soll. Wer den Scope um etwas legt, das
/// den Bildschirm nicht ausfüllt, misst gegen dieses kleinere Rechteck; das ist
/// gewollt und der Grund, warum er in `app.dart` ganz außen sitzt.
///
/// Alle Rechtecke aus [AnchorRegistry.rectOf] sind relativ zur linken oberen
/// Ecke dieses Widgets, nicht zum Bildschirm. Das entspricht der PWA, die gegen
/// die `.app-frame` misst (`02_Frontend/app/screen-tour.jsx:247-252`), und es
/// ist der Grund, warum [AnchorRegistry.frameSize] hier herkommt.
///
/// ## Ohne Scope passiert nichts, und das ist Absicht
///
/// [maybeOf] liefert `null`, wenn kein Scope über dem Aufrufer hängt. Ein
/// `AnchorTarget` meldet sich dann nirgends an, statt zu werfen. Ein Widget mit
/// Anker muss also nicht wissen, ob gerade jemand Anker abfragt, und dieselben
/// Widget-Tests laufen mit und ohne Scope.
class AnchorScope extends StatefulWidget {
  /// [knownMissingAnchors] nennt die Kennungen, deren Fehlen heute erwartet
  /// ist. Sie wirkt nur in Debug-`assert`s, siehe [AnchorRegistry.rectOf].
  const AnchorScope({
    required this.child,
    this.knownMissingAnchors = const <AnchorId>{},
    super.key,
  });

  /// Der Teilbaum, in dem Anker gelten.
  final Widget child;

  /// Anker, die es heute bekanntermaßen noch nicht gibt.
  final Set<AnchorId> knownMissingAnchors;

  /// Die Registry des nächstgelegenen Scopes, oder `null`.
  ///
  /// Meldet den Aufrufer als abhängig an. Praktisch löst das keinen Rebuild
  /// aus, weil die Registry-Instanz für die Lebensdauer des Scopes dieselbe
  /// bleibt und [_AnchorScopeMarker.updateShouldNotify] das prüft. Die
  /// Anmeldung ist trotzdem richtig: sie stellt sicher, dass ein
  /// `AnchorTarget` beim Umhängen in einen anderen Scope ein
  /// `didChangeDependencies` bekommt.
  static AnchorRegistry? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AnchorScopeMarker>()
        ?.registry;
  }

  @override
  State<AnchorScope> createState() => _AnchorScopeState();
}

class _AnchorScopeState extends State<AnchorScope> {
  late final AnchorRegistry _registry = AnchorRegistry(
    // Absichtlich ein Rückruf und kein gemerkter Wert: das Renderobjekt gibt es
    // beim Erzeugen der Registry noch nicht, und nach einem Wechsel des
    // Renderobjekts wäre ein gemerkter Wert still falsch.
    frameOf: () {
      final render = context.findRenderObject();
      return render is RenderBox ? render : null;
    },
    knownMissingAnchors: widget.knownMissingAnchors,
  );

  @override
  void didUpdateWidget(AnchorScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Die Registry liest die Menge einmal beim Erzeugen. Eine spätere Änderung
    // am Widget käme also nicht an, und der Unterschied wäre nur in Debug
    // sichtbar, also genau dort, wo man ihn am wenigsten sucht. Deshalb laut.
    assert(
      widget.knownMissingAnchors == oldWidget.knownMissingAnchors ||
          setEquals(widget.knownMissingAnchors, oldWidget.knownMissingAnchors),
      'knownMissingAnchors darf sich zur Laufzeit nicht ändern. Die Registry '
      'übernimmt die Menge einmal beim Erzeugen des Scopes.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AnchorScopeMarker(registry: _registry, child: widget.child);
  }
}

/// Trägt die Registry durch den Baum.
///
/// Getrennt vom `StatefulWidget`, weil ein `InheritedWidget` selbst keinen
/// Zustand halten kann, die Registry aber genau so lange leben muss wie der
/// Scope und nicht so lange wie eine einzelne Widget-Instanz.
class _AnchorScopeMarker extends InheritedWidget {
  const _AnchorScopeMarker({required this.registry, required super.child});

  final AnchorRegistry registry;

  @override
  bool updateShouldNotify(_AnchorScopeMarker oldWidget) =>
      !identical(oldWidget.registry, registry);
}
