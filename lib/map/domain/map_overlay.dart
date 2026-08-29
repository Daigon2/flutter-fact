/// Was ein Feature auf die Karte legen darf: eine Überlagerung aus Punkten,
/// ihre Gruppierung und die Bilder, mit denen sie gezeichnet werden.
///
/// ## Warum das neben der Kamera steht und nicht in ihr
///
/// Die Kamera ist ein **Ereignisvertrag**: ein Feature gibt eine Absicht ab,
/// der Host entscheidet, und danach ist die Absicht verbraucht. Eine
/// Überlagerung ist das Gegenteil, sie ist **Zustand**: sie liegt auf der
/// Karte, bis jemand sie ersetzt oder entfernt. Der Unterschied ist kein
/// Geschmack, er entscheidet über das Verhalten vor der ersten Karte.
/// `MapCameraHost.submitIntent` lässt eine Absicht fallen, die zu früh kommt,
/// und meldet das; eine Überlagerung, die zu früh kommt, **bleibt liegen und
/// wird nachgeholt**, sobald die Karte steht. Wer beides über denselben Weg
/// schickt, bekommt für einen der beiden Fälle die falsche Antwort.
///
/// ## Reines Dart
///
/// Gate 6 des Prüfskripts lässt in `lib/map/domain/` nur `dart:`-Importe und
/// Dateien aus `package:fact_app/map/.../domain/...` zu. `dart:typed_data` ist
/// ein `dart:`-Import und damit erlaubt; deshalb darf [MapOverlayImage] echte
/// Bytes tragen, statt einen Dateipfad oder ein `Image` aus `dart:ui` zu
/// verlangen.
library;

import 'dart:typed_data';

import 'package:fact_app/map/domain/map_position.dart';

/// Ein einzelner Punkt einer Überlagerung.
///
/// ## Warum [styleId] und [state] Zeichenketten sind und keine Aufzählung
///
/// Bei `MapCameraFollowKind` steht die Begründung genau andersherum, und beide
/// stimmen. Dort gehört die Wertemenge dem **Host**: er führt je Sorte einen
/// eigenen Zustand, ein Tippfehler sähe wie eine neue Dauerabsicht aus, und
/// deshalb ist die Menge geschlossen. Hier gehört die Wertemenge dem
/// **Feature**: welche Stile es gibt, entscheiden die Fakt-Kategorien, und
/// `map/domain/` darf eine Fakt-Kategorie gar nicht kennen (Regel 18 und
/// Gate 6). Eine Aufzählung wäre hier die Grenzverletzung und nicht der
/// Schutz: sie zwänge `lib/map/` dazu, `hist`, `myth` und `kul` aufzuzählen.
///
/// **Der Preis ist echt und wird nicht vom Typ abgefangen.** Eine [styleId],
/// für die kein [MapOverlayImage] registriert ist, ergibt einen Symbol-Layer
/// ohne Bild, und MapLibre zeichnet dann **gar nichts, ohne Fehlermeldung**.
/// Der Schutz sitzt deshalb im Host: er meldet eine unbekannte Kennung als
/// Diagnose-Ereignis, so wie `MapHostRegistry` die verlorene Absicht meldet.
final class MapOverlayPoint {
  /// Erzeugt einen Punkt.
  const MapOverlayPoint({
    required this.id,
    required this.position,
    required this.styleId,
    required this.state,
  });

  /// Die Kennung des Punktes, eindeutig innerhalb seiner Überlagerung.
  ///
  /// **Sie landet als Top-Level-`id` des GeoJSON-Features und nicht unter
  /// `properties`.** Das ist keine Formalie: der Antipp-Rückruf von
  /// `maplibre_gl 0.26.2` liefert nur `id`, `layerId` und die Positionen, und
  /// die `properties` gar nicht. Die Verhaltensquelle legt die Fakt-Kennung
  /// nach `properties.id` (`02_Frontend/app/screen-map.jsx:1896`); wer das
  /// GeoJSON eins zu eins übernimmt, bekommt beim Antippen die Zeichenkette
  /// `"null"`, ohne Ausnahme und ohne Warnung. `promoteId` rettet das nicht,
  /// es wirkt laut eigener Doku des Pakets nur im Web.
  final String id;

  /// Wo der Punkt liegt.
  final MapPosition position;

  /// Welches Bild den Punkt zeichnet.
  ///
  /// Muss zu einer [MapOverlayImage.styleId] passen, die beim Host registriert
  /// ist, sonst zeichnet MapLibre nichts. Siehe Klassenkommentar.
  final String styleId;

  /// Was das Feature über den Punkt sagt, jenseits seines Bildes.
  ///
  /// Getrennt von [styleId], weil die beiden zwei verschiedene Fragen
  /// beantworten: [styleId] sagt, **welches Bild** gezeichnet wird, [state]
  /// sagt, **was der Punkt ist**. Heute leitet das Feature das eine aus dem
  /// anderen ab, und trotzdem sind es zwei Felder: der Zustand steht als
  /// Eigenschaft im GeoJSON und ist damit für einen späteren Layer filterbar,
  /// ohne dass dieser Vertrag sich ändern muss.
  final String state;

  @override
  bool operator ==(Object other) =>
      other is MapOverlayPoint &&
      other.id == id &&
      other.position == position &&
      other.styleId == styleId &&
      other.state == state;

  @override
  int get hashCode => Object.hash(id, position, styleId, state);

  /// Ohne die Zahlen der Position, siehe `MapPosition.toString()`.
  @override
  String toString() =>
      'MapOverlayPoint($id, style: $styleId, state: $state, '
      'position: $position)';
}

/// Ob und wie eng benachbarte Punkte zu einer **Gruppe** zusammengefasst
/// werden.
///
/// Heißt bewusst nicht „Cluster": das ist das Wort des Karten-SDK, und
/// `map/domain/` trägt keine Vendor-Sprache. Entschieden am 29.08.2026.
final class MapOverlayGrouping {
  /// Erzeugt eine Gruppierung.
  const MapOverlayGrouping({
    required this.maxZoom,
    required this.radiusInScreenPixels,
  });

  /// Bis **einschließlich** dieser Zoomstufe wird gruppiert.
  ///
  /// **Der Name führt in die Irre, deshalb steht die Bedeutung hier.** `15`
  /// heißt „bis einschließlich 15 wird gruppiert, ab 16 liegen die Punkte
  /// einzeln". Wer `15` als „ab 15 einzeln" liest, verschiebt die Grenze um
  /// eine ganze Zoomstufe, und niemand sieht einen Fehler, nur ein anderes
  /// Bild. Die Verhaltensquelle setzt `clusterMaxZoom: 15`
  /// (`02_Frontend/app/screen-map.jsx:1911`).
  ///
  /// **Unten kommen nur ganze Zoomstufen an, und das steht sonst nirgends.**
  /// Der Typ ist [double], weil MapLibre überall sonst mit gebrochenen
  /// Zoomstufen rechnet. Diese eine Zahl landet auf Android aber in
  /// `Convert.toInt`, also `((Number) o).intValue()`
  /// (`SourcePropertyConverter.java:89`, `Convert.java:101-103`), und das
  /// schneidet ab statt zu runden: aus `15.7` wird `15`, ohne Fehler und ohne
  /// Warnung. Ein gebrochener Wert liefert damit eine Grenze, die bis zu einer
  /// ganzen Zoomstufe früher greift als geschrieben.
  final double maxZoom;

  /// Der Gruppierungsradius, **in Bildschirmpixeln**.
  ///
  /// **Das ist die einzige Bildschirmeinheit im ganzen Kartenvertrag**, und
  /// deshalb steht sie im Feldnamen. Alles andere hier ist Grad, Meter oder
  /// Zoomstufe. Wer hier Meter einträgt, bekommt Gruppen in falscher Größe,
  /// ohne dass etwas bricht: 70 Meter wären auf Zoom 15 rund ein Zehntel des
  /// gemeinten Radius, die Karte zeigt einfach viel mehr Gruppen als gedacht.
  ///
  /// Die Quelle setzt `clusterRadius: 70` (`screen-map.jsx:1912`).
  final double radiusInScreenPixels;

  @override
  bool operator ==(Object other) =>
      other is MapOverlayGrouping &&
      other.maxZoom == maxZoom &&
      other.radiusInScreenPixels == radiusInScreenPixels;

  @override
  int get hashCode => Object.hash(maxZoom, radiusInScreenPixels);

  @override
  String toString() =>
      'MapOverlayGrouping(maxZoom: $maxZoom, '
      'radiusInScreenPixels: $radiusInScreenPixels)';
}

/// Eine Lage von Punkten, die ein Feature auf die Karte legt.
///
/// Eine Überlagerung ist **ganz oder gar nicht**: wer einen Punkt ändern will,
/// schickt die vollständige Liste erneut. Das ist heute die einzige Form, und
/// sie ist bewusst so schmal. `maplibre_gl 0.26.2` kann mit
/// `setGeoJsonFeature` auch ein einzelnes Feature ersetzen
/// (`lib/src/controller.dart:487`); das nachzurüsten ist eine **additive**
/// Ergänzung dieses Vertrags und keine Änderung, deshalb steht sie hier nicht
/// auf Vorrat.
///
/// **Wer das später einbaut, muss vorher eines nachmessen, und die erste
/// Fassung dieses Absatzes hat dabei zu viel behauptet:** auf Android arbeitet
/// `setGeoJsonFeature` gegen die Karte `addedFeaturesByLayer`
/// (`MapLibreMapController.java:484-513`, der Zugriff steht in `:492`).
/// Gefüllt wird sie an **zwei** Stellen und nicht an einer: von
/// `addGeoJsonSource` (`:450`) und von `setGeoJsonSource` (`:477`). Eine
/// Quelle, die wie hier über `addSource` entsteht, steht darin deshalb nur
/// **vor dem ersten `setGeoJsonSource`** nicht drin, und nur so lange tut der
/// Aufruf still nichts. Danach steht der Eintrag, denn der Host ruft
/// `setGeoJsonSource` bei jeder Aktualisierung.
///
/// Wer ein einzelnes Feature ersetzen will, braucht diese Reihenfolge also
/// ausdrücklich: erst einmal vollständig befüllen, dann einzeln tauschen. Der
/// Weg über `addGeoJsonSource` wäre der, der von Anfang an einen Eintrag
/// anlegt, und zugleich der, der nicht gruppieren kann; beides zusammen ist
/// mit diesem Paketstand nicht zu haben.
final class MapOverlay {
  /// Erzeugt eine Überlagerung.
  const MapOverlay({
    required this.id,
    required this.points,
    this.grouping,
    this.minZoom,
    this.maxZoom,
  });

  /// Die Kennung dieser Überlagerung, eindeutig über alle Features hinweg.
  ///
  /// Der Host schlüsselt seine Quellen und Layer daran. Zwei Features, die
  /// dieselbe Kennung benutzen, überschreiben sich gegenseitig.
  final String id;

  /// Die Punkte dieser Überlagerung, in der Reihenfolge des Features.
  final List<MapOverlayPoint> points;

  /// Wie die Punkte gruppiert werden, oder `null` für „nicht gruppieren".
  final MapOverlayGrouping? grouping;

  /// Ab welcher Zoomstufe die Überlagerung sichtbar ist, `null` heißt „immer".
  ///
  /// Einschließlich, wie `minzoom` im Karten-SDK.
  final double? minZoom;

  /// Bis zu welcher Zoomstufe die Überlagerung sichtbar ist, `null` heißt
  /// „immer".
  ///
  /// Ausschließlich, wie `maxzoom` im Karten-SDK. **Nicht zu verwechseln mit
  /// [MapOverlayGrouping.maxZoom]:** das eine blendet die ganze Überlagerung
  /// aus, das andere hört nur mit dem Gruppieren auf.
  final double? maxZoom;

  @override
  bool operator ==(Object other) =>
      other is MapOverlay &&
      other.id == id &&
      _listsEqual(other.points, points) &&
      other.grouping == grouping &&
      other.minZoom == minZoom &&
      other.maxZoom == maxZoom;

  @override
  int get hashCode =>
      Object.hash(id, Object.hashAll(points), grouping, minZoom, maxZoom);

  /// Ohne die Punkte, nur ihre Anzahl.
  ///
  /// `docs/engineering/security.md` §6 verbietet genaue Koordinaten im Log.
  /// Fakt-Koordinaten sind zwar öffentlich, aber eine Überlagerung kann auch
  /// die Nutzerposition tragen, und 600 Zeilen Punkte sind ohnehin nur Lärm.
  @override
  String toString() =>
      'MapOverlay($id, ${points.length} Punkte, grouping: $grouping, '
      'minZoom: $minZoom, maxZoom: $maxZoom)';
}

/// Ein fertig gezeichnetes Bild, mit dem Punkte gezeichnet werden.
///
/// ## Warum hier Bytes stehen und keine Zeichenanweisung
///
/// Gezeichnet wird dort, wo die Kategorien bekannt sind, also im Feature.
/// Bekäme der Host stattdessen Farben, Maße und ein Emoji, müsste `lib/map/`
/// wissen, was eine Fakt-Kategorie ist, und genau diese Grenze schützt
/// Regel 18. Der Host bekommt fertige Bytes und registriert sie.
final class MapOverlayImage {
  /// Erzeugt ein Bild.
  const MapOverlayImage({
    required this.styleId,
    required this.bytes,
    required this.pixelRatio,
  });

  /// Unter welcher Kennung das Bild registriert wird.
  ///
  /// Ein [MapOverlayPoint] mit derselben [MapOverlayPoint.styleId] wird damit
  /// gezeichnet.
  final String styleId;

  /// Das Bild, als PNG-Bytes.
  ///
  /// PNG und nicht roh: `MapLibreMapController.addImage` reicht die Bytes an
  /// die Plattform durch, und beide Seiten dekodieren sie als Bilddatei
  /// (`maplibre_gl 0.26.2`, `lib/src/controller.dart:1686`, dessen Beispiel
  /// `rootBundle.load` einer PNG-Datei zeigt).
  final Uint8List bytes;

  /// Wie viele Bildpunkte auf einen logischen Punkt kommen.
  ///
  /// Ein Bild für einen 3x-Bildschirm ist dreifach aufgelöst. Wer das ignoriert
  /// und immer 1 liefert, bekommt matschige Ballons; wer es umgekehrt vergisst
  /// zu melden, bekommt dreifach zu große.
  final double pixelRatio;

  @override
  bool operator ==(Object other) =>
      other is MapOverlayImage &&
      other.styleId == styleId &&
      other.pixelRatio == pixelRatio &&
      _bytesEqual(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(styleId, pixelRatio, bytes.length);

  /// Ohne die Bytes, nur ihre Anzahl.
  @override
  String toString() =>
      'MapOverlayImage($styleId, ${bytes.length} Bytes, '
      'pixelRatio: $pixelRatio)';
}

/// Elementweiser Vergleich zweier Listen.
///
/// Steht als private Funktion in dieser Datei und nicht in einer geteilten:
/// `features/facts/domain/structural_equality.dart` leistet dasselbe, ist aber
/// aus `lib/map/domain/` unerreichbar (Gate 6). Dieselbe Sperre, die
/// [MapPosition] neben `FactCoordinates` stellt.
bool _listsEqual<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// Elementweiser Vergleich zweier Bytefolgen.
///
/// `Uint8List` erbt sein `==` von `Object`, zwei Kopien derselben Bytes sind
/// also verschieden. Ohne diesen Vergleich wäre `MapOverlayImage.==`
/// Identität mit zusätzlichen Schritten.
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
