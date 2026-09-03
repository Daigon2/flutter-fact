import 'package:fact_app/features/collection/application/library_city_key.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Welchem Band ein Fakt zufällt.
///
/// Der Kern dieser Datei ist nicht die Normalisierung, sondern die
/// **Abweichung**: die Quelle gruppiert nach Luftlinie zur nächsten von zwölf
/// Städten, hier zählt die Spalte `facts.city`. Zwei Zusicherungen nageln
/// genau das fest, weil ein späterer „Fix zurück zur Quelle" sonst
/// unbemerkt durchgeht.
void main() {
  Fact factWith({
    int id = 1,
    String? city = 'München',
    double? latitude = 48.1351,
    double? longitude = 11.582,
  }) => Fact(
    id: FactId(id),
    content: FactText(title: 'Titel $id'),
    city: city == null ? null : FactCity(city),
    coordinates: latitude == null || longitude == null
        ? null
        : FactCoordinates(latitude: latitude, longitude: longitude),
  );

  test('der Schlüssel kommt aus der Spalte, in der Form von `_slugify`', () {
    expect(libraryCityKeyOf(factWith(city: 'München')), 'muenchen');
    expect(libraryCityKeyOf(factWith(city: 'Regensburg')), 'regensburg');
    expect(libraryCityKeyOf(factWith(city: 'Nürnberg')), 'nuernberg');
  });

  test('die Groß- und Kleinschreibung der Spalte ist gleichgültig', () {
    expect(libraryCityKeyOf(factWith(city: 'MÜNCHEN')), 'muenchen');
    expect(libraryCityKeyOf(factWith(city: 'münchen')), 'muenchen');
  });

  test('Rom und Rome landen im selben Band', () {
    // Beide Werte stehen heute in der Spalte: der Trigger schreibt `Rom`, der
    // Backfill vom 07.06.2026 hat dasselbe `nr`-Präfix auf `Rome` gesetzt.
    // Siehe E-56.
    expect(libraryCityKeyOf(factWith(city: 'Rom')), 'rom');
    expect(libraryCityKeyOf(factWith(city: 'Rome')), 'rom');
  });

  test('München und Munich landen im selben Band', () {
    expect(libraryCityKeyOf(factWith(city: 'Munich')), 'muenchen');
    expect(libraryCityKeyOf(factWith(city: 'München')), 'muenchen');
  });

  test('ein Fakt ohne Stadt gehört in kein Band', () {
    expect(libraryCityKeyOf(factWith(city: null)), isNull);
  });

  test(
    'eine Stadt, von der nach `_slugify` nichts bleibt, ergibt kein Band',
    () {
      // `_slugify` entfernt alles außer `a` bis `z`. Ein leerer Schlüssel wäre
      // ein gültiger Kartenschlüssel und hätte ein Band ohne Namen erzeugt.
      expect(libraryCityKeyOf(factWith(city: '123')), isNull);
      expect(libraryCityKeyOf(factWith(city: ' ')), isNull);
    },
  );

  test('die Quellschlüssel der Palette treffen die Schlüssel der Fakten', () {
    // Die erzeugte Tabelle trägt `münchen` mit Umlaut, ein Fakt bringt
    // `muenchen`. Ohne diesen gemeinsamen Weg fände die Palettensuche nichts,
    // und jede Stadt bekäme die Vorgabe-Ausstattung.
    expect(libraryCityKeyOfName('münchen'), 'muenchen');
    expect(libraryCityKeyOfName('München'), 'muenchen');
    expect(libraryCityKeyOfName('rom'), 'rom');
  });

  test('die Koordinate entscheidet nicht, die Spalte entscheidet', () {
    // Ein Fakt mitten in München, dessen Spalte Regensburg sagt.
    // `wltCityKey` der Quelle fragt `detectCity(lat, lng)` **zuerst** und
    // legte ihn deshalb ins Münchner Band. Hier gilt die Spalte.
    final Fact fact = factWith(
      city: 'Regensburg',
      latitude: 48.1351,
      longitude: 11.582,
    );

    expect(libraryCityKeyOf(fact), 'regensburg');
  });

  test('ohne Koordinate bleibt der Fakt trotzdem in seinem Band', () {
    // `detectCity` braucht Zahlen. In der Quelle fiele dieser Fakt auf `f.ort`
    // zurück, den einzigen Fall, in dem dieses Feld überhaupt gelesen wird.
    // Hier ändert die fehlende Koordinate nichts, weil sie nie beteiligt war.
    expect(
      libraryCityKeyOf(
        factWith(city: 'Passau', latitude: null, longitude: null),
      ),
      'passau',
    );
  });

  test('ein Fakt weit weg von jeder Pilotstadt bekommt kein Band', () {
    // Die Quelle kennt diesen Zustand nicht: `detectCity` gibt die
    // nächstgelegene von zwölf Städten **ohne Entfernungsgrenze** zurück, ein
    // Fakt in Reykjavík landete dort im Regal einer deutschen Stadt.
    expect(
      libraryCityKeyOf(
        factWith(city: null, latitude: 64.1466, longitude: -21.9426),
      ),
      isNull,
    );
  });

  test('die Zweitschreibungen sind die der Quelle und nicht mehr', () {
    expect(libraryCityKeyAliases, <String, String>{
      'munich': 'muenchen',
      'rome': 'rom',
    });
  });
}
