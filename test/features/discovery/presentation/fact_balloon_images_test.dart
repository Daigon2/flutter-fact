import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Maße der Ballons, ihr Pinsel und die Bildfabrik.
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

  /// Zeichnet einen Ballon frei auf eine Leinwand von 120 mal 140 Pixeln.
  ///
  /// Groß genug für den betonten Ballon: bei Betonung 0,8 misst er 96,1 mal
  /// 125,9. Die Fläche ist bewusst **nicht** knapp, damit ein Ballon, der
  /// versehentlich zu groß oder versetzt gezeichnet wird, sichtbar wird statt
  /// abgeschnitten zu werden.
  Future<ui.Image> renderBalloon(
    FactCategoryStyle style, {
    required FactBalloonMetrics metrics,
    double spinDegrees = 0,
    double floatProgress = 0,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    paintFactBalloon(
      canvas,
      style,
      metrics: metrics,
      spinDegrees: spinDegrees,
      floatProgress: floatProgress,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(120, 140);
    picture.dispose();
    return image;
  }

  group('Maße', () {
    test('die Maße folgen dem RAF und nicht coinMakeEl', () {
      // **Vier Zahlen standen hier bis Schritt 17 falsch**, sauber aus
      // `coinMakeEl` abgeschrieben. `coinRafTick` überschreibt sie aber
      // unbedingt und noch vor dem ersten Bild (`screen-map.jsx:2325`,
      // `:2252-2270`). Was der Nutzer sieht, ist der Zustand nach dem RAF.
      //
      // Die Rechnung steht ausgeschrieben, damit eine geänderte Konstante
      // nicht nur die Formel mitverschiebt.
      expect(factBalloonRestingHeadDiameter, 26);
      expect(factBalloonWidth, 26 + 12 + 12);
      expect(factBalloonHeight, 12 + 26 + 50 + 7);
    });

    test('das Zeichen im Kopf ist zehn Pixel groß und nicht fünfzehn', () {
      // `screen-map.jsx:2261-2264`: der innere Kasten ist 0,7 des Kopfes, die
      // Schrift 0,55 davon. Bei 26 sind das 10,01 und nicht die 15 aus
      // `coinMakeEl`. Der Unterschied ist ein Drittel, und das Zeichen ist der
      // sichtbarste Teil des Ballons.
      expect(FactBalloonMetrics.resting.emojiSize, closeTo(10.01, 1e-9));
      expect(factBalloonInnerFraction, 0.7);
      expect(factBalloonEmojiFraction, 0.55);
    });

    test('der Bodenschatten ist 23,4 breit und nicht 22', () {
      // `screen-map.jsx:2269`: `sizePx * 0.9`, bei 26 also 23,4.
      expect(FactBalloonMetrics.resting.groundShadowWidth, closeTo(23.4, 1e-9));
    });

    test('der Kopf wächst von 26 auf 48, mit Exponent 1,5', () {
      // Die Kurve an ihren Enden und in der Mitte
      // (`screen-map.jsx:2255`).
      expect(FactBalloonMetrics.resting.headDiameter, 26);
      expect(const FactBalloonMetrics(emphasis: 1).headDiameter, 48);
      expect(
        const FactBalloonMetrics(emphasis: 0.5).headDiameter,
        // 26 + 22 * 0.5^1.5, unabhängig nachgerechnet.
        closeTo(33.7781746, 1e-6),
      );
    });

    test('Zeichen und Bodenschatten wachsen mit dem Kopf', () {
      const FactBalloonMetrics near = FactBalloonMetrics(emphasis: 1);
      expect(near.emojiSize, closeTo(48 * 0.7 * 0.55, 1e-9));
      expect(near.groundShadowWidth, closeTo(48 * 0.9, 1e-9));
    });

    test('der Stiel wächst ausdrücklich nicht mit', () {
      // **Das ist der Grund, warum diese Animation nicht über `icon-size`
      // geht.** Die Quelle fasst nur `.coin-head` an (`:2257-2258`), Stiel und
      // Bodenschattenhöhe bleiben (`:1862`, `:1864`). Ein Bildfaktor skalierte
      // alles und höbe den Kopf doppelt so hoch über seine Koordinate.
      expect(factBalloonStemHeight, 50);
      expect(factBalloonGroundShadowHeight, 7);
      expect(
        const FactBalloonMetrics(emphasis: 1).height,
        // Rand 30 (Blur des Scheins), Kopf 48, Stiel 50, Boden 7.
        closeTo(30 + 48 + 50 + 7, 1e-9),
      );
    });

    test('bei Betonung 0 hat der Maßsatz genau die Maße des Bildes', () {
      // **Die Zusicherung gegen den Sprung an der 150-Meter-Grenze.** Dort
      // trifft das native PNG auf den gezeichneten Ballon; laufen die beiden
      // Rechnungen auseinander, springt der Ballon, und zwar genau in dem
      // Moment, in dem der Nutzer hinsieht.
      expect(FactBalloonMetrics.resting.size, const Size(50, 95));
      expect(FactBalloonMetrics.resting.width, factBalloonWidth);
      expect(FactBalloonMetrics.resting.height, factBalloonHeight);
      expect(FactBalloonMetrics.resting.anchor, const Offset(25, 95));
      expect(FactBalloonMetrics.resting.headCenter, const Offset(25, 25));
    });

    test('der Ballon hängt an seiner Unterkante', () {
      // `icon-anchor: bottom` und `new mapboxgl.Marker({ anchor: 'bottom' })`
      // (`screen-map.jsx:2187`) setzen beide die **Unterkante** auf die
      // Koordinate. Der Kopf muss deshalb steigen, wenn er wächst, statt den
      // Ballon nach unten zu schieben.
      const FactBalloonMetrics resting = FactBalloonMetrics.resting;
      const FactBalloonMetrics near = FactBalloonMetrics(emphasis: 1);
      final double restingRise = resting.anchor.dy - resting.headCenter.dy;
      final double nearRise = near.anchor.dy - near.headCenter.dy;
      expect(restingRise, closeTo(70, 1e-9));
      expect(nearRise, greaterThan(restingRise));
    });
  });

  group('Glühen', () {
    test('der harte Farbring wächst von 4 auf 12 Pixel', () {
      // `screen-map.jsx:2283`. Ohne Weichzeichner und ohne Versatz: das ist
      // eine scharfe Kante, kein Schein.
      expect(factBalloonGlowRingSpread(0), 4);
      expect(factBalloonGlowRingSpread(0.5), 8);
      expect(factBalloonGlowRingSpread(1), 12);
    });

    test('der Farbring ist am Rand unsichtbar und nah bei 0,28', () {
      expect(factBalloonGlowRingAlpha(0), 0);
      expect(factBalloonGlowRingAlpha(0.5), closeTo(0.14, 1e-9));
      expect(factBalloonGlowRingAlpha(1), closeTo(0.28, 1e-9));
    });

    test('der weiche Schein geht von 16 auf 30 Pixel Blur', () {
      expect(factBalloonGlowBlur(0), 16);
      expect(factBalloonGlowBlur(0.5), 23);
      expect(factBalloonGlowBlur(1), 30);
    });

    test('seine Deckkraft geht von 0,15 auf 0,70', () {
      expect(factBalloonGlowAlpha(0), closeTo(0.15, 1e-9));
      expect(factBalloonGlowAlpha(0.5), closeTo(0.425, 1e-9));
      expect(factBalloonGlowAlpha(1), closeTo(0.70, 1e-9));
    });

    test('der ruhende Schlagschatten ist 10 Pixel und 0,40 deckend', () {
      // `screen-map.jsx:2315`, nicht `:1848`. Der Unterschied wäre an der
      // 150-Meter-Grenze als Schattensprung sichtbar.
      expect(factBalloonRestingShadowBlur, 10);
      expect(factBalloonRestingShadowAlpha, 0.4);
      expect(factBalloonRestingShadowOffsetY, 3);
      expect(factBalloonRestingEdgeOffsetY, 2);
      // In Reichweite rückt die harte Kante einen Pixel tiefer (`:2295`).
      expect(factBalloonNearEdgeOffsetY, 3);
    });

    test('der betonte Ballon bekommt Rand für seinen Schein', () {
      // Sonst schnitte der weiche Schein an der Bildkante ab, und der harte
      // Ring läge halb draußen.
      const FactBalloonMetrics near = FactBalloonMetrics(emphasis: 1);
      expect(near.shadowPadding, factBalloonGlowBlur(1));
      expect(
        near.shadowPadding,
        greaterThan(factBalloonGlowRingSpread(1)),
        reason: 'der harte Ring bleibt im Bild',
      );
    });
  });

  group('Kennungen', () {
    test('die Kennung trägt Kategorie und Zustand, mit Feature davor', () {
      // Das Präfix ist kein Schmuck: `addImage` legt Bilder in einen
      // Namensraum, den sich alle Layer der Karte teilen.
      expect(
        factBalloonStyleId('hist', factNotCollectedState),
        'fact.hist.uncollected',
      );
    });

    test(
      'der Rückweg trifft für alle zwölf Kategorien wieder zu Hause ein',
      () {
        // Ohne diese Prüfung fiele eine Kategorie mit einem Punkt im Schlüssel
        // lautlos aus der Näherungs-Animation heraus: sie bliebe nativ stehen
        // und würde nie leuchten.
        for (final FactCategoryStyle style in factCategoryStyles) {
          expect(
            factBalloonCategoryOf(
              factBalloonStyleId(style.key, factNotCollectedState),
            ),
            style,
            reason: style.key,
          );
        }
      },
    );

    test('der Rückweg lehnt ab, was nicht von hier stammt', () {
      expect(factBalloonCategoryOf('hist'), isNull);
      expect(factBalloonCategoryOf('fact.hist'), isNull);
      expect(factBalloonCategoryOf('other.hist.uncollected'), isNull);
      expect(factBalloonCategoryOf('fact.gibtsnicht.uncollected'), isNull);
      // Ein Punkt zu viel wird **nicht** zurechtgebogen.
      expect(factBalloonCategoryOf('fact.hist.uncollected.x'), isNull);
    });
  });

  group('Bildfabrik', () {
    test('bei Bildverhältnis 1 hat das Bild seine logische Größe', () async {
      final MapOverlayImage image = await buildFactBalloonImage(
        factCategoryStylesByKey['hist']!,
        pixelRatio: 1,
      );
      final ui.Image decoded = await decode(image);
      addTearDown(decoded.dispose);

      expect(decoded.width, 50);
      expect(decoded.height, 95);
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

      expect(decoded.width, 150);
      expect(decoded.height, 285);
      expect(image.pixelRatio, 3);
    });

    test('bei Bildverhältnis 3 wächst auch der Inhalt mit', () async {
      // **Die Maße oben messen das Rechteck, nicht die Zeichnung.** Ein
      // `canvas.scale(1)` statt `canvas.scale(pixelRatio)` liefert weiterhin
      // eine 150 mal 285 große Fläche, malt den Ballon aber in einfacher Größe
      // in die linke obere Ecke. Auf dem Gerät wäre das ein Ballon auf einem
      // Drittel seiner Größe, unten rechts von durchsichtiger Fläche umgeben.
      //
      // Gemessen wird deshalb die dreifach gerechnete Stelle der Kopffüllung:
      // (25, 15) mal drei. Ohne Skalierung liegt (75, 45) außerhalb des
      // gezeichneten Ballons und ist durchsichtig.
      final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
      final MapOverlayImage image = await buildFactBalloonImage(
        style,
        pixelRatio: 3,
      );
      final ui.Image decoded = await decode(image);
      addTearDown(decoded.dispose);

      expect(await pixelAt(decoded, 25 * 3, 15 * 3), style.color);
    });

    test('der Kopf trägt die Kategoriefarbe', () async {
      // Abgelesen an einem Punkt, der sicher innerhalb der Füllung liegt: zehn
      // Pixel über der Kopfmitte (25, 25), also innerhalb des Radius von 13
      // und oberhalb des Zeichenkastens, der bei 20 beginnt. Ohne diese
      // Prüfung wäre „das Bild hat die richtige Größe" auch für ein leeres
      // Bild grün.
      final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
      final MapOverlayImage image = await buildFactBalloonImage(
        style,
        pixelRatio: 1,
      );
      final ui.Image decoded = await decode(image);
      addTearDown(decoded.dispose);

      expect(await pixelAt(decoded, 25, 15), style.color);
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
      // Mitte des Stiels: er beginnt bei y = 38 (12 Rand plus 26 Kopf) und ist
      // 50 Pixel hoch, bei y = 50 liegt er also sicher darin. Der Verlauf geht
      // von Deckkraft 0xCC nach 0x11 (`screen-map.jsx:1862`), oben ist er
      // deshalb noch kräftig.
      final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
      final MapOverlayImage image = await buildFactBalloonImage(
        style,
        pixelRatio: 1,
      );
      final ui.Image decoded = await decode(image);
      addTearDown(decoded.dispose);

      final Color stem = await pixelAt(decoded, 25, 50);
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
        // **Diese Prüfung fehlte, und ihr Fehlen war teuer:** ein Bodenschatten
        // am falschen Ende blieb grün, weil die Bildmaße gleich bleiben.
        // Sichtbar wäre er als Fleck über dem Kopf statt als Auflagefläche.
        //
        // Er sitzt in den untersten sieben Pixeln des Bildes, seine Mitte liegt
        // also bei y = 91,5 (12 + 26 + 50 + 3,5).
        final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
        final MapOverlayImage image = await buildFactBalloonImage(
          style,
          pixelRatio: 1,
        );
        final ui.Image decoded = await decode(image);
        addTearDown(decoded.dispose);

        final Color shadow = await pixelAt(decoded, 25, 91);
        expect(shadow.a, greaterThan(0.15), reason: 'am Boden liegt etwas');
        expect(shadow.g, greaterThan(shadow.r));
        // Zwischen Stielende (y = 88) und Schatten ist die Fläche frei: der
        // Schatten reicht nicht bis in den Stiel hinauf.
        expect((await pixelAt(decoded, 25, 88)).a, 0);
      },
    );

    test('der Kopf trägt seinen hellen Rahmen', () async {
      // `border: 2px solid rgba(255,255,255,0.3)` innen liegend
      // (`screen-map.jsx:1854`), die Strichmitte also bei Radius 12. Ohne den
      // Rahmen wirkt der Ballon flach, und `strokeWidth = 0` wäre in Flutter
      // nicht „kein Strich", sondern ein Haarstrich an anderer Stelle: genau
      // der Fehler, den ein Test auf die Bildmaße nie sieht.
      final FactCategoryStyle style = factCategoryStylesByKey['nat']!;
      final MapOverlayImage image = await buildFactBalloonImage(
        style,
        pixelRatio: 1,
      );
      final ui.Image decoded = await decode(image);
      addTearDown(decoded.dispose);

      // (25, 13) liegt 12 Pixel über der Kopfmitte, also mitten im Ring;
      // (25, 15) liegt zehn Pixel darüber, also in der reinen Füllung.
      final Color rim = await pixelAt(decoded, 25, 13);
      final Color fill = await pixelAt(decoded, 25, 15);
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

      // Der Zeichenkasten ist gut zehn Pixel groß und sitzt mittig im Kopf
      // (25, 25), liegt also vollständig innerhalb von (20, 20) bis (30, 30).
      // Der Rahmen des Kopfes beginnt erst bei Radius 11 und kommt darin nicht
      // vor.
      int differing = 0;
      for (int y = 20; y <= 30; y++) {
        for (int x = 20; x <= 30; x++) {
          if (await pixelAt(drawn, x, y) != await pixelAt(bare, x, y)) {
            differing++;
          }
        }
      }

      expect(differing, greaterThan(0), reason: 'im Kopf steht ein Zeichen');
    });

    test('es entsteht ein Bild je Kategorie und Sammelzustand, mit '
        'eindeutiger Kennung', () async {
      // **Seit dem 03.09.2026 zwei Achsen.** Vorher stand hier „ein Bild je
      // Kategorie"; der zweite Bildsatz ist der goldene Ballon.
      final List<MapOverlayImage> images = await buildFactBalloonImages(
        pixelRatio: 1,
      );

      final int expected = factCategoryStyles.length * factBalloonStates.length;
      expect(images, hasLength(expected));
      expect(
        images.map((MapOverlayImage image) => image.styleId).toSet(),
        hasLength(expected),
      );
      expect(images.first.styleId, 'fact.hist.uncollected');
      expect(
        images.map((MapOverlayImage image) => image.styleId),
        contains('fact.hist.collected'),
      );
    });

    test('der goldene Ballon sieht anders aus als der ungesammelte', () async {
      // Ohne diese Prüfung wäre eine Fabrik, die den Zustand durchreicht und
      // ignoriert, grün: die Kennungen wären verschieden, die Bilder nicht.
      // Genau dieser Fall ist bei den Kategorien schon einmal aufgetreten.
      final MapOverlayImage offen = await buildFactBalloonImage(
        factCategoryStylesByKey['hist']!,
        pixelRatio: 1,
      );
      final MapOverlayImage gold = await buildFactBalloonImage(
        factCategoryStylesByKey['hist']!,
        pixelRatio: 1,
        state: factCollectedState,
      );

      expect(gold.styleId, 'fact.hist.collected');
      expect(gold.bytes, isNot(offen.bytes));
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
  });

  group('Der Pinsel bei Betonung 0,8', () {
    // **Kein Test hat den betonten Ballon je gezeichnet.** Jede Prüfung an
    // Bild und Widget lief mit `FactBalloonMetrics.resting`, und die Gruppe
    // „Glühen" misst die Konstantenfunktionen und nicht den Pinsel, der sie
    // benutzt. Zehn Mutationen in `_paintHeadShadows` und `_applySpin` haben
    // das überlebt, und alle zehn ändern Pixel.
    //
    // Betonung 0,8 ist gewählt, weil dort alles gleichzeitig da ist: Kopf
    // 41,74 Pixel, Rand 27,2, Ring 10,4, Kopfmitte bei (48,07 | 48,07).
    // **Ein Test, der eine Fläche misst, prüft nicht den Inhalt**, deshalb
    // steht hier kein einziges „ist anders als", sondern abgetastete Punkte.
    const FactBalloonMetrics near = FactBalloonMetrics(emphasis: 0.8);
    final FactCategoryStyle style = factCategoryStylesByKey['nat']!;

    // Die Kopfmitte, auf ganze Bildpunkte gerundet.
    const int cx = 48;
    const int cy = 48;

    test('der harte Farbring hat eine scharfe Kante', () async {
      // `screen-map.jsx:2295`, mittlerer Eintrag: `0 0 0 {glowSize}px` **ohne**
      // Blur-Radius. Bei Betonung 0,8 ragt er 10,4 Pixel über den Kopfradius
      // von 20,87 hinaus, seine Außenkante liegt also bei 79,3.
      //
      // Gemessen wird der Sprung über diese Kante. Ein Weichzeichner am Ring
      // verschmiert ihn, ein fehlender Ring lässt nur den weichen Schein
      // übrig, und der fällt über drei Pixel um weniger als drei Hundertstel.
      final ui.Image image = await renderBalloon(style, metrics: near);
      addTearDown(image.dispose);

      final double inside = (await pixelAt(image, 78, cy)).a;
      final double outside = (await pixelAt(image, 81, cy)).a;

      expect(
        inside - outside,
        greaterThan(0.15),
        reason: 'der Ring endet hart und nicht weich',
      );
    });

    test('der weiche Schein reicht über den Ring hinaus', () async {
      // `screen-map.jsx:2295`, letzter Eintrag: `0 4px {16 + g*14}px`, bei
      // Betonung 0,8 also 27,2 Pixel Blur. Jenseits der Ringkante bei 79,3
      // liegt deshalb noch etwas, und genau das verschwindet, wenn der Schein
      // wegfällt: dort steht dann nichts mehr.
      final ui.Image image = await renderBalloon(style, metrics: near);
      addTearDown(image.dispose);

      expect(
        (await pixelAt(image, 84, cy)).a,
        greaterThan(0.02),
        reason: 'außerhalb des Rings glüht es noch',
      );
      expect(
        (await pixelAt(image, 92, cy)).a,
        lessThan(0.05),
        reason: 'und es läuft nach außen aus',
      );
    });

    test('die dunkle Kante liegt über dem Ring und nicht darunter', () async {
      // **CSS-Schatten kommen von hinten nach vorn:** unter mehreren
      // `box-shadow`-Einträgen liegt der **zuerst** genannte oben, und das ist
      // `0 3px 0 {catDk}` (`screen-map.jsx:2295`). Gezeichnet wird deshalb in
      // umgekehrter Reihenfolge, dunkle Kante zuletzt.
      //
      // Abgetastet bei (56 | 68): dort liegt die um 3 Pixel tiefer gesetzte
      // Kante, der Kopf selbst endet an dieser Stelle schon bei 67,2, und der
      // Stiel steht zwei Pixel breit um x = 48. Läge der Ring darüber, mischte
      // er seine 0,224 Kategoriefarbe hinein.
      final ui.Image image = await renderBalloon(style, metrics: near);
      addTearDown(image.dispose);

      expect(await pixelAt(image, 56, 68), style.darkColor);
    });

    test('unter dem Kopf steht die Kante und nicht der Kopf', () async {
      // Die Gegenprobe zur Prüfung darüber: ohne sie wäre auch ein Ballon
      // grün, dessen Kante gar nicht existiert und bei dem (56 | 68) zufällig
      // noch in den Kopf fiele.
      final ui.Image image = await renderBalloon(style, metrics: near);
      addTearDown(image.dispose);

      expect(await pixelAt(image, 56, 62), style.color, reason: 'das ist Kopf');
      expect(
        await pixelAt(image, 56, 68),
        isNot(style.color),
        reason: 'und das nicht mehr',
      );
    });

    test('die Drehung verkürzt die wegdrehende Seite', () async {
      // **Hier hängt die bewusste Abweichung dieses Schritts.** In der Quelle
      // erreicht `perspective:300px` den Kopf gar nicht, siehe
      // `factBalloonPerspective`; hier tut sie es, und deshalb muss messbar
      // sein, dass sie wirkt und in welche Richtung.
      //
      // `rotateY(45)` dreht die **rechte** Kante weg: CSS bildet `(u,0,0)` auf
      // `(u·cos θ, 0, -u·sin θ)` ab, und negatives z heißt weiter weg. Die
      // linke Kante kommt näher und ragt deshalb weiter heraus, gerechnet
      // 15,52 Pixel links gegen 14,07 rechts. Ohne Perspektive wären beide
      // 14,76, mit umgedrehtem Vorzeichen oder umgekehrter Drehrichtung wäre
      // es seitenverkehrt.
      //
      // Abgetastet 15 Pixel neben der Kopfmitte: links steht der Kopf dort
      // noch deckend, rechts nicht mehr.
      final ui.Image spun = await renderBalloon(
        style,
        metrics: near,
        spinDegrees: 45,
      );
      addTearDown(spun.dispose);
      final ui.Image resting = await renderBalloon(style, metrics: near);
      addTearDown(resting.dispose);

      expect(
        (await pixelAt(spun, cx - 15, cy)).a,
        1,
        reason: 'links ragt der Kopf 15 Pixel weit',
      );
      expect(
        (await pixelAt(spun, cx + 15, cy)).a,
        lessThan(0.9),
        reason: 'rechts nicht mehr',
      );

      // Ohne Drehung ist beides gleich. Ohne diese Zeile könnte die Asymmetrie
      // auch aus einem verschobenen Mittelpunkt kommen.
      expect((await pixelAt(resting, cx - 15, cy)).a, 1);
      expect((await pixelAt(resting, cx + 15, cy)).a, 1);
    });

    test('das Hüpfen hebt allein den Kopf', () async {
      // `transform` verändert kein Layout: in der Quelle schwebt
      // `.coin-float-wrap`, und darin liegt allein der Kopf
      // (`screen-map.jsx:1844-1846`). Stiel und Bodenschatten stehen daneben.
      //
      // Der ruhende Kopf beginnt bei y = 27,2, der gehobene bei 18,2. Bei
      // y = 22 liegt deshalb im einen Fall die Kopffüllung und im anderen
      // nicht.
      final ui.Image floating = await renderBalloon(
        style,
        metrics: near,
        floatProgress: 1,
      );
      addTearDown(floating.dispose);
      final ui.Image resting = await renderBalloon(style, metrics: near);
      addTearDown(resting.dispose);

      expect(await pixelAt(floating, cx, 22), style.color);
      expect(await pixelAt(resting, cx, 22), isNot(style.color));
    });

    test('der Stiel bleibt stehen und wächst nicht mit dem Kopf', () async {
      // **Das ist der Grund, warum diese Animation nicht über `icon-size`
      // geht**, und der einzige Ort, an dem es an Pixeln hängt. Der Stiel ist
      // 2 Pixel breit und 50 hoch (`screen-map.jsx:1862`), unabhängig vom
      // Kopf. Er beginnt bei y = 68,9 und endet bei 118,9, sein Verlauf geht
      // dabei von Deckkraft 0xCC auf 0x11.
      //
      // Abgetastet bei (48 | 117), kurz vor dem Ende: dort steht ein schwacher
      // Rest. Wüchse der Stiel mit dem Kopf, wäre er 80 Pixel lang und an
      // dieser Stelle noch bei rund einem Drittel. Höbe das Hüpfen die ganze
      // Leinwand statt nur den Kopf, stünde dort gar nichts mehr.
      final ui.Image floating = await renderBalloon(
        style,
        metrics: near,
        floatProgress: 1,
      );
      addTearDown(floating.dispose);

      final double atStemEnd = (await pixelAt(floating, cx, 117)).a;
      expect(atStemEnd, greaterThan(0.03), reason: 'der Stiel ist noch da');
      expect(atStemEnd, lessThan(0.2), reason: 'und er läuft dort aus');

      // Und er ist zwei Pixel breit geblieben: die Spalte 46 liegt außerhalb
      // von 47,07 bis 49,07 und trägt nur den auslaufenden Schein.
      expect((await pixelAt(floating, 46, 90)).a, lessThan(0.1));
      expect((await pixelAt(floating, cx, 90)).a, greaterThan(0.3));
    });

    test('der Bodenschatten atmet mit dem Hüpfen', () async {
      // `coinShadowNear` (`styles.css:308-311`) läuft mit `coinFloatNear`
      // zusammen: `screen-map.jsx:2300-2303` schaltet beide ein, `:2304-2308`
      // beide aus. Im Scheitel ist der Schatten 0,55 mal so breit, 0,6 mal so
      // hoch und halb so deckend.
      //
      // Er liegt in den untersten sieben Pixeln, seine Mitte bei y = 122,4 und
      // sein Radius bei 18,79. Auf 0,55 geschrumpft reicht er nur noch bis
      // x = 58,4, der Punkt (60 | 122) fällt also heraus. Die Mitte bleibt
      // besetzt, nur blasser: `transform-origin` steht auf seinem Standard,
      // der Schatten wandert nicht.
      final ui.Image floating = await renderBalloon(
        style,
        metrics: near,
        floatProgress: 1,
      );
      addTearDown(floating.dispose);
      final ui.Image resting = await renderBalloon(style, metrics: near);
      addTearDown(resting.dispose);

      expect(
        (await pixelAt(resting, 60, 122)).a,
        greaterThan(0.01),
        reason: 'ruhend reicht er bis 60',
      );
      expect(
        (await pixelAt(floating, 60, 122)).a,
        0,
        reason: 'gehoben nicht mehr',
      );

      final double restingCenter = (await pixelAt(resting, cx, 122)).a;
      final double floatingCenter = (await pixelAt(floating, cx, 122)).a;
      expect(floatingCenter, greaterThan(0), reason: 'die Mitte bleibt');
      expect(
        floatingCenter,
        lessThan(restingCenter * 0.75),
        reason: 'und sie wird blasser',
      );
    });

    test('auf halbem Weg steht der Schatten zwischen beiden', () async {
      // Ohne diese Zeile wäre auch ein Schatten grün, der bei jedem
      // Fortschritt über null sofort ganz zusammenfällt.
      final ui.Image half = await renderBalloon(
        style,
        metrics: near,
        floatProgress: 0.5,
      );
      addTearDown(half.dispose);
      final ui.Image floating = await renderBalloon(
        style,
        metrics: near,
        floatProgress: 1,
      );
      addTearDown(floating.dispose);
      final ui.Image resting = await renderBalloon(style, metrics: near);
      addTearDown(resting.dispose);

      final double atHalf = (await pixelAt(half, cx, 122)).a;
      expect(atHalf, lessThan((await pixelAt(resting, cx, 122)).a));
      expect(atHalf, greaterThan((await pixelAt(floating, cx, 122)).a));
    });
  });
}
