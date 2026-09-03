import 'package:fact_app/features/collection/application/generated/wallet_cities.g.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Regal als Lesemodell: Reihenfolge, Zählung, Ausstattung.
void main() {
  Fact factWith({required int id, String? city}) => Fact(
    id: FactId(id),
    content: FactText(title: 'Titel $id'),
    city: city == null ? null : FactCity(city),
  );

  List<LibraryVolume> shelfOf(
    List<Fact> facts, [
    Set<int> collected = const {},
  ]) => libraryShelfOf(facts: facts, collected: collected);

  test('eine Stadt mit Fakten bekommt einen Band, gezählt wird beides', () {
    final List<LibraryVolume> shelf = shelfOf(
      <Fact>[
        factWith(id: 1, city: 'München'),
        factWith(id: 2, city: 'München'),
        factWith(id: 3, city: 'München'),
      ],
      <int>{2},
    );

    final LibraryVolume volume = shelf.single;
    expect(volume.cityKey, 'muenchen');
    expect(volume.total, 3);
    expect(volume.collected, 1);
  });

  test('eine Stadt ohne Fakten steht nicht im Regal', () {
    // Alle fünf Städte haben eine Palette, aber nur eine hat Daten. Die
    // Quelle filtert genauso (`screen-wallet.jsx:1831`).
    final List<LibraryVolume> shelf = shelfOf(<Fact>[
      factWith(id: 1, city: 'Passau'),
    ]);

    expect(shelf.map((LibraryVolume v) => v.cityKey), <String>['passau']);
  });

  test('die Regalfolge der Quelle gilt, danach kommen die Übrigen', () {
    // Absichtlich in einer anderen Reihenfolge übergeben als sie im Regal
    // stehen sollen. Rom kommt zuerst in den Daten und steht im Regal hinten,
    // weil `WalletCityOrder` es dorthin setzt.
    final List<LibraryVolume> shelf = shelfOf(<Fact>[
      factWith(id: 1, city: 'Rom'),
      factWith(id: 2, city: 'Nürnberg'),
      factWith(id: 3, city: 'Weimar'),
      factWith(id: 4, city: 'München'),
      factWith(id: 5, city: 'Bologna'),
    ]);

    expect(shelf.map((LibraryVolume v) => v.cityKey), <String>[
      'muenchen',
      'weimar',
      'rom',
      'nuernberg',
      'bologna',
    ]);
  });

  test('die Übrigen folgen ihrem ersten Vorkommen in den Daten', () {
    final List<LibraryVolume> shelf = shelfOf(<Fact>[
      factWith(id: 1, city: 'Bologna'),
      factWith(id: 2, city: 'Nürnberg'),
      factWith(id: 3, city: 'Bologna'),
    ]);

    expect(shelf.map((LibraryVolume v) => v.cityKey), <String>[
      'bologna',
      'nuernberg',
    ]);
  });

  test(
    'eine Stadt mit Palette trägt ihre Farben, ihren Namen und ihre Nummer',
    () {
      final LibraryVolume volume = shelfOf(<Fact>[
        factWith(id: 1, city: 'münchen'),
      ]).single;

      expect(volume.hasOwnPalette, isTrue);
      expect(volume.name, 'München');
      expect(volume.bandNumber, 1);
      expect(volume.palette.color, '#1E5FAD');
      expect(volume.palette.region, 'Bayern · Hauptstadt');
    },
  );

  test('eine Stadt ohne Palette bekommt die Vorgabe und keine Nummer', () {
    final LibraryVolume volume = shelfOf(<Fact>[
      factWith(id: 1, city: 'Bologna'),
    ]).single;

    expect(volume.hasOwnPalette, isFalse);
    expect(volume.palette, walletCityDefault);
    // `bandNo` ist in der Vorgabe `0`, und `0` heißt „keine Nummer".
    expect(volume.bandNumber, isNull);
  });

  test('ohne Palette steht der Anzeigename der Spalte auf dem Rücken', () {
    // **Und nicht der großgeschriebene Schlüssel.** Der wäre `Nuernberg`,
    // weil `_slugify` das `ü` umschreibt, und eine Ersatzschreibung in einem
    // Lesetext baut man nicht nach. Die Quelle zeigt `Nürnberg`, weil ihr
    // Schlüssel den Umlaut behält.
    final LibraryVolume volume = shelfOf(<Fact>[
      factWith(id: 1, city: 'Nürnberg'),
    ]).single;

    expect(volume.name, 'Nürnberg');
    expect(volume.name, isNot(contains('ue')));
  });

  test('bei mehreren Schreibweisen gewinnt die erste aus den Daten', () {
    final LibraryVolume volume = shelfOf(<Fact>[
      factWith(id: 1, city: 'Göttingen'),
      factWith(id: 2, city: 'GÖTTINGEN'),
    ]).single;

    expect(volume.name, 'Göttingen');
    expect(volume.total, 2);
  });

  test('Rom und Rome ergeben einen Band mit zwei Fakten', () {
    final LibraryVolume volume = shelfOf(
      <Fact>[factWith(id: 1, city: 'Rom'), factWith(id: 2, city: 'Rome')],
      <int>{1, 2},
    ).single;

    expect(volume.total, 2);
    expect(volume.collected, 2);
    // Der Name kommt aus der Palette und nicht aus der Spalte, sonst hinge er
    // davon ab, welcher der beiden Fakten zuerst gelesen wurde.
    expect(volume.name, 'Rom');
  });

  test('ein Fakt ohne Stadt zählt in keinem Band mit', () {
    final List<LibraryVolume> shelf = shelfOf(
      <Fact>[factWith(id: 1, city: 'München'), factWith(id: 2, city: null)],
      <int>{1, 2},
    );

    final LibraryVolume volume = shelf.single;
    expect(volume.total, 1);
    expect(volume.collected, 1);
  });

  test('eine gesammelte Kennung ohne passenden Fakt zählt nichts hoch', () {
    final LibraryVolume volume = shelfOf(
      <Fact>[factWith(id: 1, city: 'München')],
      <int>{99},
    ).single;

    expect(volume.collected, 0);
  });

  test('ohne Fakten ist das Regal leer und nicht fünf leere Bände', () {
    expect(shelfOf(<Fact>[]), isEmpty);
  });

  test('die Palettentabelle findet alle fünf Städte der Quelle', () {
    expect(walletCityPalettes.keys.toSet(), <String>{
      'muenchen',
      'regensburg',
      'weimar',
      'passau',
      'rom',
    });
    expect(libraryCityOrder, <String>[
      'muenchen',
      'regensburg',
      'weimar',
      'passau',
      'rom',
    ]);
  });

  test('die Bandnummern folgen der Regalfolge nicht', () {
    // Von links nach rechts stehen die Bände 1, 3, 5, 4, 2. Das ist der Stand
    // der Quelle: `bandNo` hängt an der Stadt, die Regalfolge an
    // `WalletCityOrder`. Festgenagelt, weil es wie ein Fehler aussieht und
    // keiner ist.
    expect(
      libraryCityOrder
          .map((String key) => walletCityPalettes[key]!.bandNo)
          .toList(),
      <int>[1, 3, 5, 4, 2],
    );
  });

  test('Bände haben Wertgleichheit', () {
    final List<LibraryVolume> a = shelfOf(<Fact>[
      factWith(id: 1, city: 'München'),
    ]);
    final List<LibraryVolume> b = shelfOf(<Fact>[
      factWith(id: 1, city: 'München'),
    ]);

    expect(a.single, b.single);
    expect(a.single.hashCode, b.single.hashCode);
  });
}
