import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/features/collection/presentation/library_illustrations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Stadt-Illustrationen, `02_Frontend/app/screen-wallet.jsx:244-381`.
///
/// Geprüft wird zweierlei: die Rechnung hinter `preserveAspectRatio`, exakt und
/// ohne zu zeichnen, und danach die gezeichnete Fläche über einzelne
/// Bildpunkte. Dasselbe Vorgehen wie bei den Ballons in Schritt 16.
void main() {
  // `Picture.toImage` braucht eine Bindung.
  TestWidgetsFlutterBinding.ensureInitialized();

  const Color dark = Color(0xFF0D3A6B);
  const Color mid = Color(0xFF1E5FAD);
  const Color light = Color(0xFF3B82F6);

  Future<ui.Image> render(
    String cityKey, {
    Size size = const Size(240, 280),
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    paintLibraryIllustration(
      canvas,
      size,
      cityKey: cityKey,
      dark: dark,
      mid: mid,
      light: light,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    picture.dispose();
    return image;
  }

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

  group('preserveAspectRatio="xMidYMax slice"', () {
    test(
      'bei genau der viewBox ist der Maßstab eins und der Ursprung null',
      () {
        final ({double scale, Offset origin}) fit =
            libraryIllustrationTransform(libraryIllustrationViewBox);

        expect(fit.scale, 1);
        expect(fit.origin, Offset.zero);
      },
    );

    test('`slice` nimmt den größeren Maßstab, nicht den kleineren', () {
      // Ein breiter, flacher Kasten: 480 mal 280. Waagerecht bräuchte es
      // Faktor 2, senkrecht 1. `slice` füllt, also gewinnt die 2.
      // Mit `contain` (dem kleineren) stünde die Silhouette in der Luft.
      final ({double scale, Offset origin}) fit = libraryIllustrationTransform(
        const Size(480, 280),
      );

      expect(fit.scale, 2);
    });

    test('`xMid` zentriert waagerecht, `YMax` richtet unten aus', () {
      // 240 breit, 560 hoch: senkrecht bräuchte es Faktor 2, waagerecht 1.
      // Der größere gewinnt, das Bild wird 480 breit und ragt links und rechts
      // um je 120 hinaus. Senkrecht passt es genau, der Ursprung bleibt oben.
      final ({double scale, Offset origin}) tall = libraryIllustrationTransform(
        const Size(240, 560),
      );

      expect(tall.scale, 2);
      expect(tall.origin.dx, -120);
      expect(tall.origin.dy, 0);

      // Umgekehrt: 480 mal 280 wird mit Faktor 2 auch 560 hoch, also 280 zu
      // hoch. `YMax` schiebt den Überstand **nach oben** aus dem Bild, damit
      // die Häuserzeile unten stehen bleibt.
      final ({double scale, Offset origin}) wide = libraryIllustrationTransform(
        const Size(480, 280),
      );

      expect(wide.origin.dy, -280);
      expect(wide.origin.dx, 0);
    });
  });

  group('Gezeichnetes', () {
    test('oben links steht der Himmel in der dunklen Farbe', () async {
      // Der Verlauf beginnt bei `dark`, und oben links liegt nichts davor.
      final ui.Image image = await render('muenchen');

      expect(await pixelAt(image, 0, 0), dark);
      image.dispose();
    });

    test('die unterste Zeile ist überall gedeckt, ohne Loch', () async {
      // Häuserzeile plus Schleier laufen in `dark` aus. Ein durchsichtiger
      // Bildpunkt unten hieße, dass die Silhouette nicht bis zum Rand reicht,
      // und darunter läge der Buchdeckel durch.
      for (final String city in <String>[
        'muenchen',
        'rom',
        'regensburg',
        'passau',
      ]) {
        final ui.Image image = await render(city);
        for (final int x in <int>[0, 60, 120, 200, 239]) {
          expect((await pixelAt(image, x, 279)).a, 1, reason: '$city bei x=$x');
        }
        image.dispose();
      }
    });

    test('die Türme stehen dort, wo die Quelle sie hinsetzt', () async {
      // Der linke Turm der Frauenkirche füllt 55 bis 87 waagerecht und
      // beginnt bei 110 senkrecht (`rect x="55" y="110" width="32"`). Direkt
      // links davon, bei 50, ist auf derselben Höhe noch Himmel.
      final ui.Image image = await render('muenchen');

      expect(await pixelAt(image, 70, 150), dark);
      expect(await pixelAt(image, 50, 130), isNot(dark));
      image.dispose();
    });

    test('Rom zeichnet das Kolosseum und nicht die Frauenkirche', () async {
      // Bei 71/150 steht in München ein Turm, in Rom Himmel: der
      // Kolosseumskörper fängt erst bei y=160 an.
      final ui.Image rome = await render('rom');
      final ui.Image munich = await render('muenchen');

      expect(await pixelAt(munich, 71, 150), dark);
      expect(await pixelAt(rome, 71, 150), isNot(dark));
      // Und bei 120/200 ist es umgekehrt Fläche in Rom.
      expect((await pixelAt(rome, 120, 200)).a, 1);
      rome.dispose();
      munich.dispose();
    });

    test('Regensburg zeichnet das Wasser unter der Brücke', () async {
      // `rect x="14" y="240" width="212" height="40" fill={lt+'33'}` liegt
      // **über** dem Brückenriegel und hellt ihn auf. Der Punkt bei 120/250
      // ist deshalb weder reines `dark` noch der Schleier allein.
      final ui.Image regensburg = await render('regensburg');
      final ui.Image generic = await render('passau');

      expect(await pixelAt(regensburg, 120, 250), isNot(dark));
      expect(
        await pixelAt(regensburg, 120, 250),
        isNot(await pixelAt(generic, 120, 250)),
      );
      regensburg.dispose();
      generic.dispose();
    });

    test(
      'drei Städte haben eine eigene Zeichnung, alle anderen dieselbe',
      () async {
        expect(libraryIllustratedCities, <String>[
          'muenchen',
          'rom',
          'regensburg',
        ]);

        // Passau und Weimar stehen im Regal, haben eine eigene Palette und
        // **keine** eigene Silhouette. Das ist der Stand der Quelle, siehe den
        // Kopf von `library_illustrations.dart`.
        final ui.Image passau = await render('passau');
        final ui.Image weimar = await render('weimar');
        final ui.Image unbekannt = await render('gibtsnicht');

        final ByteData? a = await passau.toByteData();
        final ByteData? b = await weimar.toByteData();
        final ByteData? c = await unbekannt.toByteData();

        expect(a!.buffer.asUint8List(), b!.buffer.asUint8List());
        expect(a.buffer.asUint8List(), c!.buffer.asUint8List());
        passau.dispose();
        weimar.dispose();
        unbekannt.dispose();
      },
    );

    test('die eigenen Zeichnungen unterscheiden sich voneinander', () async {
      final List<Uint8List> pictures = <Uint8List>[];
      for (final String city in <String>[
        'muenchen',
        'rom',
        'regensburg',
        'passau',
      ]) {
        final ui.Image image = await render(city);
        pictures.add((await image.toByteData())!.buffer.asUint8List());
        image.dispose();
      }

      for (var i = 0; i < pictures.length; i++) {
        for (var j = i + 1; j < pictures.length; j++) {
          expect(
            pictures[i],
            isNot(pictures[j]),
            reason: 'Zeichnung $i und $j sind gleich',
          );
        }
      }
    });

    test('nichts wird außerhalb der Fläche gezeichnet', () async {
      // Die `viewBox` ist 240 mal 280. In einer kleineren Fläche skaliert
      // `slice` nach oben, und ohne `clipRect` liefe die Zeichnung über den
      // Rand. Geprüft wird, dass das Bild überhaupt entsteht und in der
      // Ecke gedeckt ist; ein Überlauf ließe den Ballon-Test von Schritt 16
      // nicht scheitern, aber im Cover den Buchrücken überzeichnen.
      final ui.Image image = await render(
        'muenchen',
        size: const Size(120, 140),
      );

      expect(image.width, 120);
      expect((await pixelAt(image, 119, 139)).a, 1);
      image.dispose();
    });
  });

  group('Als Widget', () {
    testWidgets('die Illustration bringt keine eigene Größe mit', (
      tester,
    ) async {
      // `position: absolute; inset: 0` in der Quelle. Ein Widget, das seine
      // Größe selbst bestimmt, sprengte den 58-Prozent-Kasten des Covers.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: LibraryCityIllustration(
                cityKey: 'muenchen',
                dark: dark,
                mid: mid,
                light: light,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(LibraryCityIllustration)),
        const Size(200, 100),
      );
    });
  });
}
