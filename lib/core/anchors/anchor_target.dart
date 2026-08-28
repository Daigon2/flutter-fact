import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:flutter/widgets.dart';

/// Meldet sein [child] unter [anchorId] beim umgebenden `AnchorScope` an.
///
/// Pendant zu `data-tour-anchor="..."` im DOM der PWA
/// (`02_Frontend/app/chrome.jsx:88`). Das Widget zeichnet nichts, ändert nichts
/// am Layout und kostet keinen Renderknoten: es reicht [child] unverändert
/// durch. Das gemessene Rechteck ist deshalb das von [child].
///
/// Ohne `AnchorScope` darüber passiert nichts. Kein Wurf, keine Meldung: ein
/// Widget mit Anker muss nicht wissen, ob gerade jemand Anker abfragt.
class AnchorTarget extends StatefulWidget {
  /// Erzeugt eine Ankermeldung für [child].
  const AnchorTarget({required this.anchorId, required this.child, super.key});

  /// Unter dieser Kennung ist [child] auffindbar.
  final AnchorId anchorId;

  /// Das Widget, dessen Rechteck gemeldet wird.
  final Widget child;

  @override
  State<AnchorTarget> createState() => _AnchorTargetState();
}

class _AnchorTargetState extends State<AnchorTarget> {
  /// Die Registry, bei der diese Anmeldung liegt.
  ///
  /// **Gemerkt und nicht in `dispose` nachgeschlagen.** Nach dem Ausbau aus dem
  /// Baum ist `dependOnInheritedWidgetOfExactType` nicht mehr erlaubt, ein
  /// `AnchorScope.maybeOf(context)` in `dispose` würde also entweder werfen
  /// oder, schlimmer, still `null` liefern und die Anmeldung stehen lassen.
  /// Genau daraus entsteht ein Leck: die Registry hielte den Kontext eines
  /// toten Elements bis zum Ende des Scopes fest.
  AnchorRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = AnchorScope.maybeOf(context);
    if (identical(registry, _registry)) {
      // Derselbe Scope wie bisher. Erneut anzumelden wäre harmlos, aber es
      // würde beim Umhängen die Reihenfolge verschleiern.
      return;
    }
    _registry?.unregister(widget.anchorId, context);
    _registry = registry;
    _registry?.register(widget.anchorId, context);
  }

  @override
  void didUpdateWidget(AnchorTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorId == widget.anchorId) {
      return;
    }
    // Erst abmelden, dann anmelden: umgekehrt würde das Abmelden der alten
    // Kennung die gerade gesetzte neue nicht treffen, aber die Reihenfolge
    // wäre nur zufällig richtig.
    _registry?.unregister(oldWidget.anchorId, context);
    _registry?.register(widget.anchorId, context);
  }

  @override
  void dispose() {
    // `context` ist hier noch gültig: `StatefulElement.unmount` setzt
    // `state._element` erst **nach** `state.dispose()` auf null. Benutzt wird
    // er ohnehin nur als Pfand, nicht für eine Suche im Baum.
    _registry?.unregister(widget.anchorId, context);
    _registry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
