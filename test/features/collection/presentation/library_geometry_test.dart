import 'package:fact_app/features/collection/application/generated/wallet_cities.g.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Maße des Regals, ohne Widget-Baum.
void main() {
  LibraryVolume volumeWith({
    String cityKey = 'muenchen',
    int collected = 0,
    int total = 10,
    int bandNo = 1,
  }) => LibraryVolume(
    cityKey: cityKey,
    name: cityKey,
    palette: (
      key: cityKey,
      name: cityKey,
      initial: 'X',
      bandNo: bandNo,
      region: '',
      color: '#000000',
      colorDk: '#000000',
      colorLt: '#000000',
      accent: '#000000',
    ),
    hasOwnPalette: bandNo > 0,
    collected: collected,
    total: total,
  );

  group('Buchhöhe', () {
    test('ohne gesammelten Fakt steht das Buch auf der kleinsten Höhe', () {
      expect(libraryBookHeight(collected: 0, total: 10), 165);
    });

    test('die volle Höhe ist bei knapp 46 Prozent erreicht, nicht bei 100', () {
      // `Math.min(1, collected / total * 2.2)`: 1 / 2,2 sind 45,45 Prozent.
      // Wer den Faktor für einen Tippfehler hält und ihn auf 1 setzt, macht
      // jedes Buch niedriger, ohne dass die Bücher untereinander falsch
      // stünden. Deshalb hängt diese Zusicherung an einem Wert **unter** der
      // Hälfte.
      expect(libraryBookHeight(collected: 5, total: 11), 215);
      expect(libraryBookHeight(collected: 10, total: 10), 215);
    });

    test('dazwischen wächst die Höhe und wird gerundet', () {
      // 2 von 10 sind 44 Prozent des Wegs: 165 + 0,44 * 50 = 187.
      expect(libraryBookHeight(collected: 2, total: 10), 187);
      // 1 von 10 sind 22 Prozent: 165 + 11 = 176.
      expect(libraryBookHeight(collected: 1, total: 10), 176);
    });

    test('ohne Fakten gibt es keine Division durch null', () {
      expect(libraryBookHeight(collected: 0, total: 0), 165);
      expect(libraryBookHeight(collected: 3, total: 0), 165);
    });

    test('der Leerplatz ist drei Pixel höher als das leerste Buch', () {
      // 168 gegen 165, und weil das Gitter unten ausgerichtet ist, sieht man
      // den Unterschied oben. Zwei Zahlen der Quelle, keine abgeleitete.
      expect(libraryEmptySlotHeight - libraryBookMinHeight, 3);
    });
  });

  group('Reihen', () {
    test('ein einziger Band ergibt zwei Reihen mit sieben Leerplätzen', () {
      final List<List<LibraryVolume?>> rows = libraryShelfRows(<LibraryVolume>[
        volumeWith(),
      ]);

      expect(rows.length, 2);
      expect(rows[0].length, 4);
      expect(rows[1].length, 4);
      expect(rows[0].first, isNotNull);
      expect(rows[0].skip(1).every((LibraryVolume? v) => v == null), isTrue);
      expect(rows[1].every((LibraryVolume? v) => v == null), isTrue);
    });

    test('ohne Bände stehen trotzdem zwei Reihen da', () {
      final List<List<LibraryVolume?>> rows = libraryShelfRows(
        <LibraryVolume>[],
      );

      expect(rows.length, 2);
      expect(
        rows.every(
          (List<LibraryVolume?> row) =>
              row.length == 4 && row.every((LibraryVolume? v) => v == null),
        ),
        isTrue,
      );
    });

    test('vier Bände füllen genau eine Reihe, die zweite bleibt leer', () {
      final List<List<LibraryVolume?>> rows = libraryShelfRows(<LibraryVolume>[
        volumeWith(cityKey: 'a'),
        volumeWith(cityKey: 'b'),
        volumeWith(cityKey: 'c'),
        volumeWith(cityKey: 'd'),
      ]);

      expect(rows.length, 2);
      expect(rows[0].every((LibraryVolume? v) => v != null), isTrue);
      expect(rows[1].every((LibraryVolume? v) => v == null), isTrue);
    });

    test('fünf Bände ergeben zwei Reihen, die zweite mit drei Leerplätzen', () {
      final List<List<LibraryVolume?>> rows = libraryShelfRows(<LibraryVolume>[
        for (int i = 0; i < 5; i++) volumeWith(cityKey: 'stadt$i'),
      ]);

      expect(rows.length, 2);
      expect(rows[1][0], isNotNull);
      expect(rows[1].skip(1).every((LibraryVolume? v) => v == null), isTrue);
    });

    test('neun Bände ergeben drei Reihen, die Mindestzahl greift nicht', () {
      final List<List<LibraryVolume?>> rows = libraryShelfRows(<LibraryVolume>[
        for (int i = 0; i < 9; i++) volumeWith(cityKey: 'stadt$i'),
      ]);

      expect(rows.length, 3);
      expect(rows[2][0], isNotNull);
      expect(rows[2].skip(1).every((LibraryVolume? v) => v == null), isTrue);
    });

    test('die Bände behalten ihre Reihenfolge über die Reihen hinweg', () {
      final List<List<LibraryVolume?>> rows = libraryShelfRows(<LibraryVolume>[
        for (int i = 0; i < 6; i++) volumeWith(cityKey: 'stadt$i'),
      ]);

      expect(rows[0].map((LibraryVolume? v) => v?.cityKey), <String?>[
        'stadt0',
        'stadt1',
        'stadt2',
        'stadt3',
      ]);
      expect(rows[1].map((LibraryVolume? v) => v?.cityKey), <String?>[
        'stadt4',
        'stadt5',
        null,
        null,
      ]);
    });
  });

  group('Bandnummer', () {
    test('eine Stadt mit Nummer trägt ihre eigene, nicht die Position', () {
      expect(
        libraryVolumeNumber(volumeWith(bandNo: 5), rowIndex: 0, columnIndex: 0),
        5,
      );
    });

    test('ohne Nummer zählt die Gitterposition, und die wandert', () {
      // Der Fund aus E-75: die Nummer einer Stadt ohne Palette hängt an ihrem
      // Platz im Gitter. Kommt eine Stadt davor dazu, heißt dieselbe Stadt
      // plötzlich anders. Festgenagelt, damit die Übernahme dieses Verhaltens
      // sichtbar bleibt.
      final LibraryVolume volume = volumeWith(bandNo: 0);

      expect(libraryVolumeNumber(volume, rowIndex: 0, columnIndex: 0), 1);
      expect(libraryVolumeNumber(volume, rowIndex: 0, columnIndex: 2), 3);
      expect(libraryVolumeNumber(volume, rowIndex: 1, columnIndex: 0), 5);
      expect(libraryVolumeNumber(volume, rowIndex: 2, columnIndex: 3), 12);
    });

    test('die Vorgabe-Palette hat keine Nummer, also greift die Position', () {
      final LibraryVolume volume = LibraryVolume(
        cityKey: 'bologna',
        name: 'Bologna',
        palette: walletCityDefault,
        hasOwnPalette: false,
        collected: 0,
        total: 3,
      );

      expect(volume.bandNumber, isNull);
      expect(libraryVolumeNumber(volume, rowIndex: 0, columnIndex: 1), 2);
    });
  });
}
