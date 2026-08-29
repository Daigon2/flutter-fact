import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Bildfabrik der Ballons.
///
/// **Gemessen wird das fertige Bild, nicht der Zeichenweg.** Ein Test, der
/// prüft, dass `drawCircle` aufgerufen wurde, ist grün, wenn der Kreis
/// außerhalb des Bildes liegt. Hier wird das PNG deshalb wieder dekodiert:
/// seine Maße kommen aus dem Bild selbst, und die Kategoriefarbe wird an einem
/// Bildpunkt abgelesen.
void main() {
  // `Picture.toImage` braucht die Bindung. Ohne sie scheitert schon der erste
  // Aufruf, und zwar mit einer Meldung über das Fenster und nicht über das
  // Bild.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Dekodiert die Bytes eines [MapOverlayImage] wieder zu einem Bild.
  Future<ui.Image> decode(MapOverlayImage image) async {
    final ui.Codec codec = await ui.instantiateImageCodec(image.bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// Liest die Farbe eines Bildpunktes.
  Future<Color> pixelAt(ui.Image image, int x, int y) async {
    final ByteData? data = await image.toByteData();
    expect(data, isNotNull);
    final int offset = (y * image.width + x) * 4;
    return Color.fromARGB(
      data!.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  }

  test('die Maße folgen coinMakeEl', () {
    // Kopf 28, Stiel 50, Bodenschatten 7, dazu 12 Pixel Rand für den weichen
    // Schlagschatten (`screen-map.jsx:1845-1867`). Die Rechnung steht hier
    // ausgeschrieben, damit eine geänderte Konstante nicht nur die Formel
    // mitverschiebt.
    expect(factBalloonWidth, 28 + 12 + 12);
    expect(factBalloonHeight, 12 + 28 + 50 + 7);
  });

  test('bei Bildverhältnis 1 hat das Bild seine logische Größe', () async {
    final MapOverlayImage image = await buildFactBalloonImage(
      factCategoryStylesByKey['hist']!,
      pixelRatio: 1,
    );
    final ui.Image decoded = await decode(image);
    addTearDown(decoded.dispose);

    expect(decoded.width, 52);
    expect(decoded.height, 97);
    expect(image.pixelRatio, 1);
  });

  test('bei Bildverhältnis 3 ist es dreifach aufgelöst', () async {
    // Ohne das sind die Ballons auf einem heutigen Telefon matschig. Und das
    // gemeldete Verhältnis gehört dazu: fehlt es, zeichnet MapLibre das Bild
    // dreifach zu groß.
    final MapOverlayImage image = await buildFactBalloonImage(
      factCategoryStylesByKey['hist']!,
      pixelRatio: 3,
    );
    final ui.Image decoded = await decode(image);
    addTearDown(decoded.dispose);

    expect(decoded.width, 156);
    expect(decoded.height, 291);
    expect(image.pixelRatio, 3);
  });

  test('bei Bildverhältnis 3 wächst auch der Inhalt mit', () async {
    // **Die Maße oben messen das Rechteck, nicht die Zeichnung.** Ein
    // `canvas.scale(1)` statt `canvas.scale(pixelRatio)` liefert weiterhin
    // eine 156 mal 291 große Fläche, malt den Ballon aber in einfacher Größe
    // in die linke obere Ecke. Auf dem Gerät wäre das ein Ballon auf einem
    // Drittel seiner Größe, unten rechts von durchsichtiger Fläche umgeben.
    //
    // Gemessen wird deshalb die dreifach gerechnete Stelle der Kopffüllung:
    // (26, 16) mal drei. Ohne Skalierung liegt (78, 48) außerhalb des
    // gezeichneten Ballons und ist durchsichtig.
    final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
    final MapOverlayImage image = await buildFactBalloonImage(
      style,
      pixelRatio: 3,
    );
    final ui.Image decoded = await decode(image);
    addTearDown(decoded.dispose);

    expect(await pixelAt(decoded, 26 * 3, 16 * 3), style.color);
  });

  test('der Kopf trägt die Kategoriefarbe', () async {
    // Abgelesen an einem Punkt, der sicher innerhalb der Füllung liegt: zehn
    // Pixel über der Kopfmitte, also innerhalb des Radius von 14 und oberhalb
    // des Emoji-Kastens, der bei 18,5 beginnt. Ohne diese Prüfung wäre „das
    // Bild hat die richtige Größe" auch für ein leeres Bild grün.
    final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
    final MapOverlayImage image = await buildFactBalloonImage(
      style,
      pixelRatio: 1,
    );
    final ui.Image decoded = await decode(image);
    addTearDown(decoded.dispose);

    expect(await pixelAt(decoded, 26, 16), style.color);
  });

  test('der Rand oben ist durchsichtig', () async {
    // Die Gegenprobe zum Farbtest: läge der Kopf am oberen Bildrand, wäre die
    // Farbprobe oben ebenfalls grün.
    final MapOverlayImage image = await buildFactBalloonImage(
      factCategoryStylesByKey['nat']!,
      pixelRatio: 1,
    );
    final ui.Image decoded = await decode(image);
    addTearDown(decoded.dispose);

    expect((await pixelAt(decoded, 0, 0)).a, 0);
  });

  test('der Stiel hängt unter dem Kopf und trägt die Kategoriefarbe', () async {
    // Der Kopf allein ist nicht der Ballon. Geprüft wird ein Punkt in der
    // Mitte des Stiels: er beginnt bei y = 40 (12 Rand plus 28 Kopf) und ist
    // 50 Pixel hoch, bei y = 45 liegt er also sicher darin. Der Verlauf geht
    // von Deckkraft 0xCC nach 0x11 (`screen-map.jsx:1862`), oben ist er
    // deshalb noch kräftig.
    final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
    final MapOverlayImage image = await buildFactBalloonImage(
      style,
      pixelRatio: 1,
    );
    final ui.Image decoded = await decode(image);
    addTearDown(decoded.dispose);

    final Color stem = await pixelAt(decoded, 26, 45);
    expect(stem.a, greaterThan(0.5), reason: 'der Stiel ist da');
    // **Und er ist der Stiel und nicht der Schlagschatten des Kopfes.** Der
    // ist schwarz, dort wären alle drei Kanäle gleich; hier muss die
    // Kategoriefarbe durchkommen.
    expect(stem.g, greaterThan(stem.r));
    expect(stem.g, greaterThan(stem.b));
  });

  test(
    'der Bodenschatten liegt unter dem Stiel und nicht über dem Kopf',
    () async {
      // **Diese Prüfung fehlte, und ihr Fehlen war teuer:** ein Bodenschatten am
      // falschen Ende blieb grün, weil die Bildmaße gleich bleiben. Sichtbar
      // wäre er als Fleck über dem Kopf statt als Auflagefläche.
      //
      // Er sitzt in den untersten sieben Pixeln des Bildes, seine Mitte liegt
      // also bei y = 93,5 (12 + 28 + 50 + 3,5).
      final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
      final MapOverlayImage image = await buildFactBalloonImage(
        style,
        pixelRatio: 1,
      );
      final ui.Image decoded = await decode(image);
      addTearDown(decoded.dispose);

      final Color shadow = await pixelAt(decoded, 26, 93);
      expect(shadow.a, greaterThan(0.15), reason: 'am Boden liegt etwas');
      expect(shadow.g, greaterThan(shadow.r));
      // Zwischen Stielende (y = 90) und Schatten ist die Fläche frei: der
      // Schatten reicht nicht bis in den Stiel hinauf.
      expect((await pixelAt(decoded, 26, 90)).a, 0);
    },
  );

  test('der Kopf trägt seinen hellen Rahmen', () async {
    // `border: 2px solid rgba(255,255,255,0.3)` innen liegend
    // (`screen-map.jsx:1854`), die Strichmitte also bei Radius 13. Ohne den
    // Rahmen wirkt der Ballon flach, und `strokeWidth = 0` wäre in Flutter
    // nicht „kein Strich", sondern ein Haarstrich an anderer Stelle: genau der
    // Fehler, den ein Test auf die Bildmaße nie sieht.
    final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
    final MapOverlayImage image = await buildFactBalloonImage(
      style,
      pixelRatio: 1,
    );
    final ui.Image decoded = await decode(image);
    addTearDown(decoded.dispose);

    // (26, 13) liegt 13 Pixel über der Kopfmitte, also mitten im Ring;
    // (26, 16) liegt zehn Pixel darüber, also in der reinen Füllung.
    final Color rim = await pixelAt(decoded, 26, 13);
    final Color fill = await pixelAt(decoded, 26, 16);
    expect(fill, style.color);
    expect(rim.r, greaterThan(fill.r), reason: 'das Weiß hellt auf');
    expect(rim.g, greaterThan(fill.g));
    expect(rim.b, greaterThan(fill.b));
  });

  test('im Kopf steht wirklich ein Zeichen', () async {
    // **Ein einzelner Bildpunkt trägt diese Aussage nicht.** `flutter test`
    // lädt keine Schriften; das Emoji erscheint als Ersatzkasten, und
    // gemessen ist der ein **hohler** Rahmen: die Kopfmitte selbst bleibt
    // leer, gezeichnet wird nur der Umriss. Welcher Punkt getroffen wird,
    // hängt damit an der Ersatzschrift und nicht am Code.
    //
    // Geprüft wird deshalb der Unterschied zu einem sonst gleichen Ballon
    // **ohne** Zeichen. Der ist von der Schrift unabhängig und fällt, sobald
    // gar kein Zeichen mehr gesetzt wird. Ohne diese Prüfung überlebte genau
    // das: alle zwölf Ballons ohne Emoji, und „zwei Kategorien ergeben zwei
    // verschiedene Bilder" bliebe grün, weil die Farben sie unterscheiden.
    const FactCategoryStyle withEmoji = FactCategoryStyle(
      key: 'probe',
      emoji: '🌿',
      color: Color(0xFF22C55E),
      darkColor: Color(0xFF15803D),
    );
    const FactCategoryStyle withoutEmoji = FactCategoryStyle(
      key: 'probe',
      emoji: '',
      color: Color(0xFF22C55E),
      darkColor: Color(0xFF15803D),
    );

    final ui.Image drawn = await decode(
      await buildFactBalloonImage(withEmoji, pixelRatio: 1),
    );
    addTearDown(drawn.dispose);
    final ui.Image bare = await decode(
      await buildFactBalloonImage(withoutEmoji, pixelRatio: 1),
    );
    addTearDown(bare.dispose);

    // Der Emoji-Kasten ist 15 Pixel groß und sitzt mittig im Kopf, liegt also
    // vollständig innerhalb von (20, 20) bis (32, 30). Der Rahmen des Kopfes
    // beginnt erst bei Radius 12 und kommt darin nicht vor.
    int differing = 0;
    for (int y = 20; y <= 30; y++) {
      for (int x = 20; x <= 32; x++) {
        if (await pixelAt(drawn, x, y) != await pixelAt(bare, x, y)) {
          differing++;
        }
      }
    }

    expect(differing, greaterThan(0), reason: 'im Kopf steht ein Zeichen');
  });

  test('es entsteht ein Bild je Kategorie, mit eindeutiger Kennung', () async {
    final List<MapOverlayImage> images = await buildFactBalloonImages(
      pixelRatio: 1,
    );

    expect(images, hasLength(factCategoryStyles.length));
    expect(
      images.map((MapOverlayImage image) => image.styleId).toSet(),
      hasLength(factCategoryStyles.length),
    );
    expect(images.first.styleId, 'fact.hist.uncollected');
  });

  test('die Kennung trägt Kategorie und Zustand, mit Feature davor', () {
    // Das Präfix ist kein Schmuck: `addImage` legt Bilder in einen
    // Namensraum, den sich alle Layer der Karte teilen.
    expect(
      factBalloonStyleId('hist', factNotCollectedState),
      'fact.hist.uncollected',
    );
  });

  test('zwei Kategorien ergeben zwei verschiedene Bilder', () async {
    // Ohne diese Prüfung wäre eine Fabrik, die zwölfmal dasselbe zeichnet,
    // grün: die Kennungen wären verschieden, die Bilder nicht.
    final MapOverlayImage hist = await buildFactBalloonImage(
      factCategoryStylesByKey['hist']!,
      pixelRatio: 1,
    );
    final MapOverlayImage nat = await buildFactBalloonImage(
      factCategoryStylesByKey['nat']!,
      pixelRatio: 1,
    );

    expect(hist.bytes, isNot(nat.bytes));
  });
}
