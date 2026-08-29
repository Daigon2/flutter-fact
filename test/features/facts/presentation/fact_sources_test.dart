import 'package:fact_app/features/facts/presentation/fact_sources.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Quellenliste aus `facts.quelle` samt Auffüllung mit Platzhaltern,
/// `02_Frontend/app/screen-fact.jsx:455-475`.
void main() {
  test('ohne Quellenangabe gibt es keine Liste', () {
    expect(factSourcesOf(null), isEmpty);
    expect(factSourcesOf(''), isEmpty);
    expect(factSourcesOf('   '), isEmpty);
    expect(factSourcesOf(' · · '), isEmpty);
  });

  test('eine einzelne Angabe ergibt eine Zeile', () {
    // Echter Wert aus `muenchen-data.jsx:14`.
    expect(factSourcesOf('Hirschgarten (München)'), <FactSource>[
      const FactSource('Hirschgarten (München)'),
    ]);
  });

  test('zwei Angaben werden am Mittelpunkt getrennt', () {
    // Echter Wert aus `muenchen-data.jsx:35`.
    expect(factSourcesOf('Wikipedia · Stadtarchiv München'), <FactSource>[
      const FactSource('Wikipedia'),
      const FactSource('Stadtarchiv München'),
    ]);
  });

  test('jede Angabe steht genau einmal in der Liste', () {
    final List<FactSource> sources = factSourcesOf(
      'Wikipedia · Stadtarchiv München · NS-Dokumentationszentrum',
    );

    expect(sources, hasLength(3));
    for (final String name in <String>[
      'Wikipedia',
      'Stadtarchiv München',
      'NS-Dokumentationszentrum',
    ]) {
      expect(
        sources.where((FactSource source) => source.name == name),
        hasLength(1),
        reason: name,
      );
    }
  });

  test('die Reihenfolge der Zeichenkette bleibt erhalten', () {
    // Gegenprobe zu einer Umsetzung, die sortiert oder umdreht: der Platz in
    // der Liste ist die Zahl, auf die eine Hochziffer zeigt.
    expect(
      factSourcesOf('C · A · B').map((FactSource s) => s.name).toList(),
      <String>['C', 'A', 'B'],
    );
  });

  test('Leerraum um den Trenner fällt weg, Leerraum innen bleibt', () {
    // `/\s*·\s*/` in `:460`, danach `.trim()`. Ein Leerzeichen **innerhalb**
    // eines Namens darf davon nicht betroffen sein.
    expect(
      factSourcesOf('  Bayerische   Staatsbibliothek  ·Wikipedia  '),
      <FactSource>[
        const FactSource('Bayerische   Staatsbibliothek'),
        const FactSource('Wikipedia'),
      ],
    );
  });

  test('leere Stücke zwischen zwei Trennern fallen weg', () {
    expect(factSourcesOf('A ·  · B'), <FactSource>[
      const FactSource('A'),
      const FactSource('B'),
    ]);
  });

  test('eine doppelte Angabe wird nicht stillschweigend geschluckt', () {
    // Die Quelle entdoppelt nicht, und bei einer Quellenangabe wäre das die
    // falsche Freundlichkeit: aus zwei Belegen würde einer.
    expect(factSourcesOf('Wikipedia · Wikipedia'), hasLength(2));
  });

  test('ein normaler Punkt trennt nicht', () {
    // Der Trenner ist U+00B7, nicht der Satzpunkt. Eine Umsetzung, die auf
    // `.` trennt, zerlegte jede Quellenangabe mit Abkürzung.
    expect(factSourcesOf('Hrsg. Stadtarchiv'), <FactSource>[
      const FactSource('Hrsg. Stadtarchiv'),
    ]);
  });

  test('die Liste ist unveränderlich', () {
    expect(
      () => factSourcesOf('A · B').add(const FactSource('C')),
      throwsUnsupportedError,
    );
  });

  group('Die Auffüllung mit Platzhaltern, `:472-475`', () {
    // Der Wortlaut kommt in der App aus `fact.sourceMissing`. Hier steht er
    // als Literal, damit die Zusicherung an der Auffüllung hängt und nicht an
    // der Ergänzungs-Map; die prüft
    // `test/app/localization/app_strings_supplement_test.dart`.
    const String fehlt = 'Quelle fehlt';

    test('genau so viele Platzhalter, wie zur höchsten Referenz fehlen', () {
      final List<FactSource> sources = factSourcesOf(
        'Wikipedia · Stadtarchiv München',
        highestReference: 5,
        missingLabel: fehlt,
      );

      expect(sources, hasLength(5));
      expect(sources[0], const FactSource('Wikipedia'));
      expect(sources[1], const FactSource('Stadtarchiv München'));
      for (final int index in <int>[2, 3, 4]) {
        expect(sources[index].name, fehlt, reason: 'Zeile ${index + 1}');
        expect(sources[index].missing, isTrue, reason: 'Zeile ${index + 1}');
      }
    });

    test(
      'und keiner mehr: gezählt wird bis zur Referenz, nicht bis zum Ende',
      () {
        // Gegenprobe zu einer Umsetzung, die `highestReference` Platzhalter
        // anhängt, statt bis dorthin aufzufüllen: die ergäbe hier fünf Zeilen.
        expect(
          factSourcesOf(
            'Wikipedia · Stadtarchiv München',
            highestReference: 3,
            missingLabel: fehlt,
          ),
          hasLength(3),
        );
      },
    );

    test('reichen die Angaben, entsteht kein einziger Platzhalter', () {
      final List<FactSource> sources = factSourcesOf(
        'Wikipedia · Stadtarchiv München',
        highestReference: 2,
        missingLabel: fehlt,
      );

      expect(sources, hasLength(2));
      expect(sources.any((FactSource s) => s.missing), isFalse);
    });

    test('mehr Angaben als Referenzen werden nicht gekürzt', () {
      // `:473` ist eine `while`-Schleife über die Länge und keine Zuweisung.
      // Eine Umsetzung, die auf `highestReference` **setzt**, würde hier die
      // dritte Quellenangabe verschlucken.
      expect(
        factSourcesOf('A · B · C', highestReference: 1, missingLabel: fehlt),
        hasLength(3),
      );
    });

    test('ohne Quellenangabe entstehen reine Platzhalterzeilen', () {
      // `:459` greift gar nicht, `:473` füllt trotzdem: `[1]` und `[2]` im
      // Text müssen eine Zeile finden.
      final List<FactSource> sources = factSourcesOf(
        null,
        highestReference: 2,
        missingLabel: fehlt,
      );

      expect(sources, hasLength(2));
      expect(sources.every((FactSource s) => s.missing), isTrue);
    });

    test('ohne Referenz bleibt es bei den Angaben', () {
      expect(factSourcesOf('Wikipedia', missingLabel: fehlt), <FactSource>[
        const FactSource('Wikipedia'),
      ]);
      expect(factSourcesOf(null, missingLabel: fehlt), isEmpty);
    });

    test('die englische Beschriftung geht unverändert durch', () {
      // Die Funktion kennt keine Sprache und darf keine wählen.
      expect(
        factSourcesOf(
          null,
          highestReference: 1,
          missingLabel: 'Source missing',
        ).single.name,
        'Source missing',
      );
    });

    test('eine echte Quelle namens "Quelle fehlt" bleibt echt', () {
      // `missing` ist ein Feld und keine Ableitung aus dem Namen. Sonst
      // färbte die Zeile blass, obwohl sie eine Angabe trägt.
      final List<FactSource> sources = factSourcesOf(
        'Quelle fehlt',
        highestReference: 2,
        missingLabel: fehlt,
      );

      expect(sources, hasLength(2));
      expect(sources.first.missing, isFalse);
      expect(sources.last.missing, isTrue);
      expect(sources.first, isNot(sources.last));
    });

    test('ohne Beschriftung bleibt die Auffüllung aus und meldet sich', () {
      expect(
        () => factSourcesOf('Wikipedia', highestReference: 3),
        throwsA(isA<AssertionError>()),
      );
    });

    test('auch die aufgefüllte Liste ist unveränderlich', () {
      expect(
        () => factSourcesOf(
          null,
          highestReference: 1,
          missingLabel: fehlt,
        ).add(const FactSource('C')),
        throwsUnsupportedError,
      );
    });
  });
}
