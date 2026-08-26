import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/features/facts/data/datasources/remote/fact_remote_data_source.dart';
import 'package:fact_app/features/facts/data/repositories/supabase_fact_repository.dart';
import 'package:fact_app/features/facts/domain/failures/fact_failure.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_defect.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fact_row_fixtures.dart';

/// Verhalten des Repositories, mit einer Attrappe statt Supabase.
///
/// Es gibt in dieser Umgebung keinen Zugang zu einer echten Supabase-Instanz,
/// und das ist für diese Tests auch richtig: geprüft wird die Koordination
/// (Seitenbildung, Filter, Bericht, Fehlerdurchgriff), nicht das Netz.
/// `docs/engineering/testing.md` verlangt für Attrappen ausdrücklich echtes
/// Verhalten und keine Konservenantwort, deshalb bildet [FakeFactDataSource]
/// die Seitenbildung wirklich nach.
void main() {
  group('Seitenbildung', () {
    test('eine Antwort unter der Seitengröße beendet den Lauf', () async {
      final source = FakeFactDataSource(rowsFor(<int>[1, 2, 3]));
      final repository = SupabaseFactRepository(dataSource: source);

      final batch = await repository.fetchFacts();

      expect(batch.facts, hasLength(3));
      expect(source.requestedOffsets, orderedEquals(<int>[0]));
      expect(batch.report.isClean, isTrue);
    });

    test('eine leere Antwort ergibt eine leere Liste ohne Mangel', () async {
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(<Map<String, dynamic>>[]),
      );

      final batch = await repository.fetchFacts();

      expect(batch.facts, isEmpty);
      expect(batch.isEmpty, isTrue);
      expect(batch.report.isClean, isTrue);
    });

    test('volle Seiten werden nachgeladen, bis die letzte kürzer ist', () async {
      // 2500 Zeilen bei einer Seitengröße von 1000: drei Anfragen.
      final source = FakeFactDataSource(
        rowsFor(List<int>.generate(2500, (index) => index + 1)),
      );
      final repository = SupabaseFactRepository(dataSource: source);

      final batch = await repository.fetchFacts();

      expect(batch.facts, hasLength(2500));
      expect(
        source.requestedOffsets,
        orderedEquals(<int>[0, SupabaseFactRepository.pageSize, 2000]),
      );
      // Die Reihenfolge bleibt aufsteigend nach id, über Seitengrenzen hinweg.
      expect(batch.facts.first.id.value, 1);
      expect(batch.facts.last.id.value, 2500);
    });

    test('genau eine volle Seite fragt eine zweite, leere Seite an', () async {
      final source = FakeFactDataSource(
        rowsFor(
          List<int>.generate(
            SupabaseFactRepository.pageSize,
            (index) => index + 1,
          ),
        ),
      );
      final repository = SupabaseFactRepository(dataSource: source);

      final batch = await repository.fetchFacts();

      expect(batch.facts, hasLength(SupabaseFactRepository.pageSize));
      expect(source.requestedOffsets, hasLength(2));
    });

    test('Mängel aus mehreren Seiten landen in einem Bericht', () async {
      final rows = rowsFor(List<int>.generate(1500, (index) => index + 1));
      rows[0]['hero'] = 'kaputt';
      rows[1200]['puzzle_fit'] = 'mittel';
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(rows),
      );

      final batch = await repository.fetchFacts();

      expect(batch.facts, hasLength(1500));
      expect(batch.report.defects, hasLength(2));
      expect(
        batch.report.countsByKind[FactDefectKind.optionalFieldUnusable],
        1,
      );
      expect(batch.report.countsByKind[FactDefectKind.obsoleteFieldShape], 1);
    });

    test('eine Antwort, die keine Liste ist, beendet den Lauf', () async {
      final repository = SupabaseFactRepository(
        dataSource: BrokenShapeDataSource(<String, dynamic>{'message': 'nope'}),
      );

      final batch = await repository.fetchFacts();

      expect(batch.facts, isEmpty);
      expect(batch.report.defects.single.kind, FactDefectKind.responseNotAList);
    });
  });

  group('Stadtfilter', () {
    test('ohne Filter kommen alle Städte', () async {
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(citiesFixture()),
      );

      final batch = await repository.fetchFacts();

      expect(batch.facts, hasLength(4));
    });

    test(
      'der Filter vergleicht über den Slug, nicht über den Anzeigenamen',
      () async {
        final repository = SupabaseFactRepository(
          dataSource: FakeFactDataSource(citiesFixture()),
        );

        final batch = await repository.fetchFacts(
          query: const FactQuery(citySlug: 'muenchen'),
        );

        expect(batch.facts, hasLength(1));
        expect(batch.facts.single.city?.displayName, 'München');
      },
    );

    test('auch der Anzeigename als Filterwert trifft', () async {
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(citiesFixture()),
      );

      final batch = await repository.fetchFacts(
        query: const FactQuery(citySlug: 'München'),
      );

      expect(batch.facts, hasLength(1));
    });

    test('ein Fakt ohne Stadt fällt bei gesetztem Filter heraus', () async {
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(citiesFixture()),
      );

      final batch = await repository.fetchFacts(
        query: const FactQuery(citySlug: 'muenchen'),
      );

      expect(batch.facts.where((fact) => fact.city == null), isEmpty);
    });

    test('der Filter unterdrückt den Bericht nicht', () async {
      // Wichtig: ein Fakt aus einer anderen Stadt darf herausgefiltert werden,
      // sein Datenmangel darf aber nicht mitverschwinden. Sonst wäre der
      // Bericht vom Filter abhängig und damit als Diagnose wertlos.
      final rows = citiesFixture();
      rows[1]['hero'] = 'kaputt';
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(rows),
      );

      final batch = await repository.fetchFacts(
        query: const FactQuery(citySlug: 'muenchen'),
      );

      expect(batch.facts, hasLength(1));
      expect(batch.report.defects, hasLength(1));
    });
  });

  group('Einzelabruf', () {
    test('liefert genau einen Fakt', () async {
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(rowsFor(<int>[1004])),
      );

      final batch = await repository.fetchFactById(const FactId(1004));

      expect(batch.singleOrNull?.id.value, 1004);
    });

    test('nicht gefunden ist kein Fehlschlag', () async {
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(<Map<String, dynamic>>[]),
      );

      final batch = await repository.fetchFactById(const FactId(9999));

      expect(batch.singleOrNull, isNull);
      expect(batch.report.isClean, isTrue);
    });

    test('ein defekter Datensatz ergibt kein Fakt und einen Befund', () async {
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(<Map<String, dynamic>>[
          <String, dynamic>{'id': 1004},
        ]),
      );

      final batch = await repository.fetchFactById(const FactId(1004));

      expect(batch.singleOrNull, isNull);
      expect(batch.report.defects.single.field, 'titel');
    });
  });

  group('Fehlschläge', () {
    test('eine FactFailure der Datenquelle geht unverändert durch', () async {
      final repository = SupabaseFactRepository(
        dataSource: FailingDataSource(const FactAccessDenied(code: 'PGRST301')),
      );

      await expectLater(
        repository.fetchFacts(),
        throwsA(
          isA<FactAccessDenied>().having((f) => f.code, 'code', 'PGRST301'),
        ),
      );
    });

    test(
      'ein Fehlschlag wird nicht zu einer leeren Liste geschluckt',
      () async {
        // Genau das war der alte Ausfall: kein Fehler sichtbar, nur eine leere
        // Karte. Ein Fehlschlag muss sichtbar bleiben.
        final repository = SupabaseFactRepository(
          dataSource: FailingDataSource(const FactBackendUnreachable()),
        );

        await expectLater(
          repository.fetchFacts(),
          throwsA(isA<FactBackendUnreachable>()),
        );
      },
    );

    test('ein Fehlschlag auf der zweiten Seite bricht den Lauf ab', () async {
      final repository = SupabaseFactRepository(
        dataSource: FailOnSecondPageDataSource(
          rowsFor(
            List<int>.generate(
              SupabaseFactRepository.pageSize,
              (index) => index + 1,
            ),
          ),
        ),
      );

      await expectLater(
        repository.fetchFacts(),
        throwsA(isA<FactRequestRejected>()),
      );
    });

    test('die Fehlschlag-Arten tragen ihren Kurznamen', () {
      expect(const FactAccessDenied().kind, 'accessDenied');
      expect(const FactRequestRejected().kind, 'requestRejected');
      expect(const FactBackendUnreachable().kind, 'backendUnreachable');
      expect(
        const FactAccessDenied(code: '42501').toString(),
        contains('42501'),
      );
    });
  });

  group('Diagnose', () {
    test('ein sauberer Lauf meldet nichts', () async {
      final sink = RecordingDiagnosticSink();
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(rowsFor(<int>[1, 2])),
        diagnostics: sink,
      );

      await repository.fetchFacts();

      expect(sink.events, isEmpty);
    });

    test('Mängel werden als zählbares Ereignis gemeldet', () async {
      final rows = rowsFor(<int>[1, 2, 3]);
      rows[1]['hero'] = 'kaputt';
      rows[2].remove('id');
      final sink = RecordingDiagnosticSink();
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(rows),
        diagnostics: sink,
      );

      final batch = await repository.fetchFacts();

      expect(batch.facts, hasLength(2));
      final event = sink.events.single;
      expect(event.name, SupabaseFactRepository.defectEventName);
      expect(event.attributes['discarded'], '1');
      expect(event.attributes['degraded'], '1');
      expect(event.attributes['optionalFieldUnusable'], '1');
      expect(event.attributes['requiredFieldUnusable'], '1');
      expect(event.attributes['fields'], 'hero,id');
    });

    test('das Ereignis trägt keinen Inhalt und keine Koordinate', () async {
      final rows = rowsFor(<int>[1]);
      rows[0]['hero'] = 'kaputt';
      final sink = RecordingDiagnosticSink();
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(rows),
        diagnostics: sink,
      );

      await repository.fetchFacts();

      final serialized = sink.events.single.attributes.values.join(' ');
      expect(serialized, isNot(contains('Glyptothek')));
      expect(serialized, isNot(contains('48.1')));
      expect(serialized, isNot(contains('11.5')));
      expect(serialized, isNot(contains('MUC_')));
    });

    test('die Standardsenke schluckt still', () {
      const sink = SilentDiagnosticSink();

      expect(() => sink.report(DiagnosticEvent('x')), returnsNormally);
    });

    test('die Attribute eines Ereignisses sind unveränderlich', () {
      final event = DiagnosticEvent('x', <String, String>{'a': 'b'});

      expect(() => event.attributes['c'] = 'd', throwsUnsupportedError);
    });
  });

  group('watchFacts', () {
    test('sagt deutlich, dass Realtime noch nicht entschieden ist', () {
      final repository = SupabaseFactRepository(
        dataSource: FakeFactDataSource(<Map<String, dynamic>>[]),
      );

      expect(
        () => repository.watchFacts(),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            contains('E-09'),
          ),
        ),
      );
    });
  });
}

/// Zeilen mit den angegebenen Kennungen.
List<Map<String, dynamic>> rowsFor(List<int> ids) {
  return ids
      .map(
        (id) => factRow(
          overrides: <String, Object?>{
            'id': id,
            'nr': 'MUC_${id.toString().padLeft(3, '0')}',
          },
        ),
      )
      .toList();
}

/// Vier Zeilen aus drei Städten, eine davon ohne Stadt.
List<Map<String, dynamic>> citiesFixture() {
  return <Map<String, dynamic>>[
    factRow(overrides: <String, Object?>{'id': 1, 'city': 'München'}),
    factRow(overrides: <String, Object?>{'id': 2, 'city': 'Nürnberg'}),
    factRow(overrides: <String, Object?>{'id': 3, 'city': 'Passau'}),
    factRow(overrides: <String, Object?>{'id': 4, 'city': null}),
  ];
}

/// Attrappe, die echte Seitenbildung nachbildet.
class FakeFactDataSource implements FactRemoteDataSource {
  FakeFactDataSource(this.rows);

  /// Der gesamte Bestand, aus dem Seiten geschnitten werden.
  final List<Map<String, dynamic>> rows;

  /// Welche Offsets abgefragt wurden, in Reihenfolge.
  final List<int> requestedOffsets = <int>[];

  @override
  Future<Object?> fetchPublishedFactPage({
    required int offset,
    required int pageSize,
  }) async {
    requestedOffsets.add(offset);
    if (offset >= rows.length) {
      return <Map<String, dynamic>>[];
    }
    final end = (offset + pageSize).clamp(0, rows.length);
    return rows.sublist(offset, end);
  }

  @override
  Future<Object?> fetchFactById(int id) async => rows;
}

/// Attrappe, die etwas liefert, das gar keine Liste ist.
class BrokenShapeDataSource implements FactRemoteDataSource {
  BrokenShapeDataSource(this.response);

  /// Was zurückkommt.
  final Object? response;

  @override
  Future<Object?> fetchPublishedFactPage({
    required int offset,
    required int pageSize,
  }) async => response;

  @override
  Future<Object?> fetchFactById(int id) async => response;
}

/// Attrappe, die sofort scheitert.
class FailingDataSource implements FactRemoteDataSource {
  FailingDataSource(this.failure);

  /// Der Fehlschlag, den die Datenquelle wirft.
  final FactFailure failure;

  @override
  Future<Object?> fetchPublishedFactPage({
    required int offset,
    required int pageSize,
  }) async => throw failure;

  @override
  Future<Object?> fetchFactById(int id) async => throw failure;
}

/// Attrappe, die erst auf der zweiten Seite scheitert.
class FailOnSecondPageDataSource implements FactRemoteDataSource {
  FailOnSecondPageDataSource(this.firstPage);

  /// Die erste, vollständige Seite.
  final List<Map<String, dynamic>> firstPage;

  @override
  Future<Object?> fetchPublishedFactPage({
    required int offset,
    required int pageSize,
  }) async {
    if (offset == 0) {
      return firstPage;
    }
    throw const FactRequestRejected(code: '42703');
  }

  @override
  Future<Object?> fetchFactById(int id) async => firstPage;
}

/// Senke, die mitschreibt.
class RecordingDiagnosticSink implements DiagnosticSink {
  /// Alles, was gemeldet wurde.
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}
