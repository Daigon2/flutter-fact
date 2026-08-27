import 'package:fact_app/features/identity/presentation/state/auth_city.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die hartcodierte Städteliste und ihre Suche, festgenagelt gegen
/// `02_Frontend/app/screen-auth.jsx:562-567` und `:606-608`.
void main() {
  group('Die Liste', () {
    test('enthält die vier Städte der Quelle in ihrer Reihenfolge', () {
      // Die Reihenfolge ist Verhalten: der Picker belegt mit dem ersten Eintrag
      // vor. Die Zahlen sind der Stand des Tages, an dem sie jemand
      // hingeschrieben hat, und veralten ohne Vorwarnung.
      expect(
        authCities
            .map(
              (city) => <Object>[
                city.name,
                city.country,
                city.facts,
                city.active,
              ],
            )
            .toList(),
        <List<Object>>[
          <Object>['München', 'DE', 593, true],
          <Object>['Rom', 'IT', 100, false],
          <Object>['Passau', 'DE', 73, false],
          <Object>['Regensburg', 'DE', 200, false],
        ],
      );
    });

    test('nur München ist als aktiv beworben', () {
      expect(
        authCities.where((city) => city.active).map((city) => city.name),
        <String>['München'],
      );
    });
  });

  group('Wertgleichheit', () {
    test(
      'zwei zur Laufzeit gebaute Städte mit gleichen Feldern sind gleich',
      () {
        // Zur Laufzeit gebaut und mit `identical` gegengeprüft: zwei gleich
        // geschriebene `const`-Werte sind in Dart **dasselbe Objekt**, ein
        // Gleichheitstest darauf prüfte nichts. Dieselbe Falle hat in Schritt 9
        // eine Mutation von `AuthSession.==` überlebt.
        final left = AuthCity(
          name: 'Rom'.toUpperCase().toLowerCase(),
          country: 'IT',
          facts: 100,
        );
        final right = AuthCity(
          name: 'rom',
          country: 'IT',
          facts: int.parse('100'),
        );

        expect(identical(left, right), isFalse);
        expect(left, right);
        expect(left.hashCode, right.hashCode);
      },
    );

    test('jedes Feld zählt für die Gleichheit', () {
      const base = AuthCity(name: 'Rom', country: 'IT', facts: 100);

      expect(
        base,
        isNot(const AuthCity(name: 'Rome', country: 'IT', facts: 100)),
      );
      expect(
        base,
        isNot(const AuthCity(name: 'Rom', country: 'DE', facts: 100)),
      );
      expect(
        base,
        isNot(const AuthCity(name: 'Rom', country: 'IT', facts: 99)),
      );
      expect(
        base,
        isNot(
          const AuthCity(name: 'Rom', country: 'IT', facts: 100, active: true),
        ),
      );
    });
  });

  group('Die Suche', () {
    test('eine leere Suche liefert alles', () {
      expect(filterAuthCities(authCities, ''), authCities);
    });

    test('eine Suche aus Leerzeichen liefert alles', () {
      // `cityQuery.trim()` entscheidet, ob überhaupt gefiltert wird.
      expect(filterAuthCities(authCities, '   '), authCities);
    });

    test('sucht als Teilstring, unabhängig von der Schreibweise', () {
      expect(
        filterAuthCities(authCities, 'reg').map((city) => city.name),
        <String>['Regensburg'],
      );
      expect(
        filterAuthCities(authCities, 'AU').map((city) => city.name),
        <String>['Passau'],
      );
      expect(
        filterAuthCities(authCities, 'e').map((city) => city.name),
        <String>['München', 'Regensburg'],
      );
    });

    test('umlautlose Schreibweisen finden nichts', () {
      // Keine Normalisierung, nur `toLowerCase`. `FactCity.slug` könnte das,
      // gehört aber zu `facts` und zu den Faktdaten, nicht zu diesem
      // Formularfeld.
      expect(filterAuthCities(authCities, 'muenchen'), isEmpty);
      expect(filterAuthCities(authCities, 'munich'), isEmpty);
    });

    test('der Ländercode wird nicht durchsucht', () {
      expect(filterAuthCities(authCities, 'IT'), isEmpty);
    });

    test('eine Suche mit Leerzeichen drumherum findet nichts', () {
      // Eigenheit der Quelle: geprüft wird auf `trim()`, gesucht mit dem rohen
      // Wert. `" m "` filtert also und findet nichts.
      expect(filterAuthCities(authCities, ' m '), isEmpty);
    });

    test('ein Treffer ohne Ergebnis liefert eine leere Liste', () {
      // Der Picker rendert dann eine leere Liste, ohne Hinweistext.
      // `onboarding.noCityFound` existiert und wird in der PWA nicht benutzt.
      expect(filterAuthCities(authCities, 'Paris'), isEmpty);
    });
  });
}
