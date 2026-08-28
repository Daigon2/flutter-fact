import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:flutter/widgets.dart';

/// Verzeichnis der angemeldeten Anker eines Teilbaums.
///
/// Eine Registry gehört genau einem `AnchorScope` und stirbt mit ihm. Es gibt
/// bewusst **keine** globale `static`-Instanz: ADR-005 verwirft die "manual
/// singleton registry" ausdrücklich, und eine solche würde Anmeldungen über die
/// Lebensdauer eines Bildschirms hinaus halten.
///
/// ## Das Rechteck entsteht beim Abfragen
///
/// Gespeichert wird nur der [BuildContext] des angemeldeten Widgets, nicht
/// seine Lage. Ein bei der Anmeldung gemerktes Rechteck wäre schon beim ersten
/// Bildlauf, Tastaturwechsel oder Drehen falsch, und niemand würde es merken.
/// Die Quelle rechnet aus demselben Grund in einem Effekt bei jedem Schritt und
/// bei jedem `resize` neu (`02_Frontend/app/screen-tour.jsx:180-262`).
///
/// ## Bezugsfläche ist der Scope, nicht der Bildschirm
///
/// [rectOf] liefert Koordinaten relativ zur Bezugsfläche aus `frameOf`. Die PWA
/// zieht `frect.left` und `frect.top` der `.app-frame` von jeder gemessenen
/// Position ab (`screen-tour.jsx:247-252`) und legt Pfeil und Ring innerhalb
/// dieses Rahmens ab. Bildschirmkoordinaten wären dort falsch, sobald der
/// Rahmen nicht in der Ecke sitzt, und hier genauso.
class AnchorRegistry {
  /// `frameOf` liefert die Bezugsfläche, auf die [rectOf] rechnet, oder `null`,
  /// solange es sie noch nicht gibt.
  ///
  /// [knownMissingAnchors] listet Kennungen, deren Fehlen **erwartet** ist. Die
  /// Menge wirkt ausschließlich in `assert`s, siehe [rectOf].
  AnchorRegistry({
    required RenderBox? Function() frameOf,
    Set<AnchorId> knownMissingAnchors = const <AnchorId>{},
  }) : _frameOf = frameOf,
       _knownMissingAnchors = knownMissingAnchors;

  final RenderBox? Function() _frameOf;
  final Set<AnchorId> _knownMissingAnchors;

  /// Kennung auf den Kontext des anmeldenden Widgets.
  ///
  /// Der Kontext ist gleichzeitig das Pfand beim Abmelden, siehe [unregister].
  final Map<AnchorId, BuildContext> _targets = <AnchorId, BuildContext>{};

  /// Größe der Bezugsfläche, oder `null`, solange sie nicht ausgelegt ist.
  ///
  /// Pendant zu `frameSize` in `screen-tour.jsx:185-186`. Wer eine Blase mittig
  /// über dem Rahmen platzieren will, braucht die Rahmengröße und nicht die
  /// Bildschirmgröße.
  Size? get frameSize {
    final frame = _frameOf();
    if (frame == null || !frame.attached || !frame.hasSize) {
      return null;
    }
    return frame.size;
  }

  /// Die derzeit angemeldeten Kennungen. Nur für Tests.
  ///
  /// Es gibt sie, weil "die Registry hält nach dem Abmelden keine Referenz
  /// mehr" sonst nicht prüfbar wäre: [rectOf] liefert auch dann `null`, wenn
  /// eine tote Anmeldung noch im Verzeichnis läge.
  @visibleForTesting
  Set<AnchorId> get debugRegisteredIds => _targets.keys.toSet();

  /// Meldet [context] unter [id] an.
  ///
  /// ## Doppelte Anmeldung: der letzte gewinnt, in Debug mit `assert`
  ///
  /// Bewusst entschieden, nicht dem Zufall überlassen:
  ///
  /// - **Werfen** wäre falsch. Ein Anker ist Verzierung. Eine App wegen eines
  ///   Leuchtrings abstürzen zu lassen, ist der teurere Fehler.
  /// - **Still den letzten gewinnen lassen** wäre auch falsch: heute besitzt
  ///   jede Kennung genau ein Widget, eine zweite Anmeldung ist also ein
  ///   Versehen, und ein Versehen soll laut sein.
  /// - Deshalb beides. `assert` in Debug, und im Release gewinnt der zuletzt
  ///   Angemeldete. Der Grund für "der letzte" und nicht "der erste" ist der
  ///   Wechsel zweier Bildschirme, die kurzzeitig beide im Baum hängen: in
  ///   dieser Lage ist der neuere der sichtbare.
  ///
  /// Wenn später ein Fall auftaucht, in dem zwei Widgets legitim dieselbe
  /// Kennung tragen, ist dieser `assert` die Stelle, an der das entschieden
  /// wird. Ohne ihn würde es niemand bemerken.
  ///
  /// Eine wiederholte Anmeldung **desselben** Kontexts ist kein Verstoß. Sie
  /// entsteht regulär, wenn `didChangeDependencies` erneut läuft.
  void register(AnchorId id, BuildContext context) {
    final previous = _targets[id];
    // Die Zuweisung steht **vor** dem `assert`, und das ist Absicht: ein
    // `assert`, der nebenbei eine Zuweisung verhindert, macht den Release-Bau
    // zu einem anderen Programm als den Debug-Bau. So tun beide dasselbe, und
    // der `assert` meldet nur.
    _targets[id] = context;
    assert(
      previous == null || identical(previous, context),
      'Der Anker "${id.value}" ist bereits angemeldet. Eine Kennung gehört '
      'genau einem Widget. Die spätere Anmeldung gewinnt, die frühere ist '
      'überschrieben.',
    );
  }

  /// Meldet [id] ab, aber nur, wenn [context] tatsächlich der angemeldete
  /// Kontext ist.
  ///
  /// Die Pfandprüfung ist der Grund, warum ein Bildschirmwechsel keine gültige
  /// Anmeldung wegräumt: hängen A und B kurzzeitig beide im Baum und tragen
  /// dieselbe Kennung, dann löscht das spätere `dispose` von A nicht die
  /// Anmeldung von B.
  ///
  /// Gibt zurück, ob etwas entfernt wurde.
  bool unregister(AnchorId id, BuildContext context) {
    if (!identical(_targets[id], context)) {
      return false;
    }
    _targets.remove(id);
    return true;
  }

  /// Das Rechteck von [id], relativ zur Bezugsfläche, oder `null`.
  ///
  /// `null` bedeutet: **den Schritt ohne Pfeil und ohne Ring weiterzeichnen**,
  /// nicht überspringen. Die Quelle macht genau das, sie setzt `targetRect` auf
  /// `null` (`screen-tour.jsx:254`) und rendert die Blase trotzdem.
  ///
  /// Es gibt drei Wege zu `null`, und sie bedeuten Verschiedenes:
  ///
  /// 1. **Nichts angemeldet.** Entweder ist der Anker noch nicht gebaut, oder
  ///    die Kennung ist vertippt. Beide sehen gleich aus, deshalb der `assert`
  ///    unten.
  /// 2. **Angemeldet, aber nicht ausgelegt.** Kein Renderobjekt, keine Größe,
  ///    nicht am Baum.
  /// 3. **Angemeldet, ausgelegt, aber unsichtbar.** Der teuerste Fall, siehe
  ///    unten.
  ///
  /// ## Warum der Sichtbarkeitslauf sein muss
  ///
  /// `StatefulShellRoute` hält alle Zweige über einen `IndexedStack` am Leben
  /// und legt jeden inaktiven zusätzlich in ein `Offstage`
  /// (`go_router/lib/src/route.dart:1611-1635`).
  /// `RenderOffstage.performLayout` legt sein Kind trotzdem aus
  /// (`rendering/proxy_box.dart:3919-3925`), und `getTransformTo` ignoriert
  /// `paintsChild` ausdrücklich (`rendering/object.dart:3660-3662`). Ohne
  /// Gegenmaßnahme liefert ein Anker in einem **inaktiven** Tab also ein
  /// vollständig plausibles Rechteck, und der Pfeil zeigt auf nichts. Kein
  /// Absturz, kein `null`, nur ein falsches Bild.
  ///
  /// Gemessen und bestätigt: im inaktiven Zweig kommt dasselbe Rechteck heraus
  /// wie im aktiven, und der einzige Unterschied auf dem Weg nach oben ist ein
  /// `RenderOffstage`, das `paintsChild == false` meldet.
  ///
  /// Deshalb läuft [rectOf] vom Anker bis zur Bezugsfläche hoch und gibt `null`
  /// zurück, sobald ein Elternteil sein Kind nicht zeichnet. Das SDK macht
  /// denselben Lauf an derselben Stelle (`material/material.dart:735`
  /// und `:744`).
  ///
  /// **Nicht darauf verlassen, dass `IndexedStack` allein das meldet.** Sein
  /// Widget legt jedes Kind in ein `Visibility` (`widgets/basic.dart:4886`),
  /// und `_RenderVisibility` (`widgets/visibility.dart:591`) überschreibt
  /// `paintsChild` **nicht**. Erkennbar ist der inaktive Zweig hier nur, weil
  /// go_router zusätzlich ein eigenes `Offstage` darum legt.
  Rect? rectOf(AnchorId id) {
    final target = _targets[id];
    // Ein fehlender Anker degradiert lautlos, und genau das ist gefährlich:
    // ein vertippter Bezeichner sieht aus wie ein noch nicht gebauter. Die
    // Menge der bekannt fehlenden Anker trennt die beiden Fälle. In Debug
    // schlägt alles an, was nicht darin steht.
    assert(
      target != null || _knownMissingAnchors.contains(id),
      'Der Anker "${id.value}" ist nicht angemeldet und steht auch nicht in '
      'der Liste der bekannt fehlenden Anker dieses Scopes. Entweder ist die '
      'Kennung vertippt, oder das Widget fehlt und der Anker gehört in die '
      'Liste.',
    );
    if (target == null) {
      return null;
    }

    final frame = _frameOf();
    if (frame == null || !frame.attached || !frame.hasSize) {
      return null;
    }

    final render = target.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }

    if (!_isPaintedWithin(render, frame)) {
      return null;
    }

    return MatrixUtils.transformRect(
      render.getTransformTo(frame),
      Offset.zero & render.size,
    );
  }

  /// Läuft von [node] bis [frame] hoch und meldet, ob jeder Schritt gezeichnet
  /// wird.
  ///
  /// `false` auch dann, wenn [frame] gar nicht auf dem Weg liegt: dann sind
  /// beide nicht im selben Renderbaum, und `getTransformTo` wäre laut seiner
  /// eigenen Dokumentation undefiniert.
  static bool _isPaintedWithin(RenderObject node, RenderObject frame) {
    var child = node;
    while (!identical(child, frame)) {
      final parent = child.parent;
      if (parent == null) {
        return false;
      }
      if (!parent.paintsChild(child)) {
        return false;
      }
      child = parent;
    }
    return true;
  }
}
