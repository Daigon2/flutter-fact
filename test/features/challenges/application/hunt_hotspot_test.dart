import 'package:fact_app/features/challenges/application/generated/hunt_hotspots.g.dart';
import 'package:fact_app/features/challenges/application/hunt_hotspot.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die kuratierten Hotspots, `02_Frontend/app/hunt-hotspots.js`.
///
/// ## Was diese Datei prüft und was nicht
///
/// Sie prüft den **Zugriff** und die Unversehrtheit der erzeugten Tabelle.
/// Ob die Tabelle noch zur PWA passt, prüft `dart run
/// tool/generate_curated_data.dart --check`, und zwar dort und nicht hier:
/// `flutter test` muss ohne Zugang zum Lese-Repository durchlaufen. Dieselbe
/// Arbeitsteilung wie bei `app_strings_supplement_test.dart` und
/// `tool/generate_i18n.dart`.
///
/// Die Zahlen unten sind am 30.08.2026 an der Quelle gezählt worden, vom
/// Generator ausgegeben: 10 Städte, 21 Hotspots, Dichtestufen `sehr hoch=1`,
/// `hoch=12`, `mittel=8`.
void main() {
  group('Die erzeugte Tabelle', () {
    test('trägt zehn Städte und einundzwanzig Hotspots', () {
      expect(huntHotspotRecordsByCityName, hasLength(10));
      expect(
        huntHotspotRecordsByCityName.values.expand(
          (List<HuntHotspotRecord> list) => list,
        ),
        hasLength(21),
      );
    });

    test('jede Stadt hat mindestens einen Hotspot', () {
      for (final MapEntry<String, List<HuntHotspotRecord>> entry
          in huntHotspotRecordsByCityName.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
      }
    });

    test('kein Name und keine Dichte ist leer', () {
      for (final HuntHotspotRecord record
          in huntHotspotRecordsByCityName.values.expand(
            (List<HuntHotspotRecord> list) => list,
          )) {
        expect(record.name, isNotEmpty);
        expect(record.density, isNotEmpty);
      }
    });

    test('alle Koordinaten liegen im gültigen Bereich', () {
      for (final HuntHotspotRecord record
          in huntHotspotRecordsByCityName.values.expand(
            (List<HuntHotspotRecord> list) => list,
          )) {
        expect(record.latitude, inInclusiveRange(-90, 90), reason: record.name);
        expect(
          record.longitude,
          inInclusiveRange(-180, 180),
          reason: record.name,
        );
      }
    });

    test('die Schlüssel sind die deutschen Anzeigenamen der Quelle', () {
      // Wörtlich abgeschrieben und **nicht** normalisiert, siehe E-11 im Kopf
      // von `hunt_hotspot.dart`. Wer hier normalisiert, verschiebt die
      // Entscheidung ins Werkzeug, wo sie niemand sucht.
      expect(huntHotspotRecordsByCityName.keys, contains('München'));
      expect(huntHotspotRecordsByCityName.keys, contains('Nürnberg'));
      expect(huntHotspotRecordsByCityName.keys, isNot(contains('muenchen')));
    });

    test('keine zwei Städte fallen auf denselben Slug', () {
      // Sonst verschwände eine der beiden lautlos aus der Nachschlagekarte.
      final Set<String> slugs = huntHotspotRecordsByCityName.keys
          .map((String name) => FactCity(name).slug)
          .toSet();
      expect(slugs, hasLength(huntHotspotRecordsByCityName.length));
    });
  });

  group('Nachschlagen', () {
    test(
      'München liefert die vier Hotspots der Quelle in ihrer Reihenfolge',
      () {
        final List<HuntHotspot> hotspots = huntHotspotsForCity(
          const FactCity('München'),
        );

        expect(hotspots.map((HuntHotspot h) => h.name).toList(), <String>[
          'Marienplatz',
          'Viktualienmarkt',
          'Odeonsplatz',
          'Englischer Garten / Chinesischer Turm',
        ]);
      },
    );

    test('der erste Münchner Hotspot trägt die Werte der Quelle', () {
      // `hunt-hotspots.js:5`: Marienplatz, 48.1374 / 11.5755, „sehr hoch".
      final HuntHotspot marienplatz = huntHotspotsForCity(
        const FactCity('München'),
      ).first;

      expect(marienplatz.position.latitude, 48.1374);
      expect(marienplatz.position.longitude, 11.5755);
      expect(marienplatz.density, 'sehr hoch');
    });

    test('die drei Schreibweisen derselben Stadt finden dasselbe', () {
      // Der Kern von E-11: die Quelle schreibt „München", `wallet-colors.jsx`
      // schreibt „münchen", die Datenbank und `FactQuery` rechnen mit
      // „muenchen". Alle drei müssen hier ankommen, sonst kostet die spätere
      // Antwort auf E-11 mehr als eine Stelle.
      final List<HuntHotspot> reference = huntHotspotsForCity(
        const FactCity('München'),
      );
      for (final String spelling in <String>[
        'münchen',
        'muenchen',
        'MÜNCHEN',
        'Muenchen',
      ]) {
        expect(
          huntHotspotsForCity(
            FactCity(spelling),
          ).map((HuntHotspot h) => h.name),
          reference.map((HuntHotspot h) => h.name),
          reason: spelling,
        );
      }
    });

    test('eine unbekannte Stadt liefert eine leere Liste und wirft nicht', () {
      // `(window.HUNT_HOTSPOTS || {})[city] || []`, `screen-challenge.jsx:3003`.
      expect(huntHotspotsForCity(const FactCity('Atlantis')), isEmpty);
      expect(huntHotspotsForCity(const FactCity('')), isEmpty);
    });

    test('jede Stadt der Tabelle ist über ihren Namen erreichbar', () {
      for (final String name in huntHotspotRecordsByCityName.keys) {
        expect(
          huntHotspotsForCity(FactCity(name)),
          hasLength(huntHotspotRecordsByCityName[name]!.length),
          reason: name,
        );
      }
    });
  });
}
