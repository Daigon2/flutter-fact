import 'dart:convert';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/facts/domain/collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';

/// [CollectedFactsStore] auf dem Gerätespeicher.
///
/// Schlüsselname wie in der Quelle: `Storage` setzt vor jeden Schlüssel
/// `fact_` (`storage.jsx:4`) und legt die Sammlung unter `collected` ab
/// (`storage.jsx:48-52`), zusammen also `fact_collected`. Wie beim
/// Jagd-Speicher ist das Nachvollziehbarkeit und **keine gemeinsame Nutzung**:
/// die PWA und diese App laufen nicht auf demselben Speicher.
///
/// ## Ein defekter Eintrag kostet nicht die ganze Sammlung
///
/// `KeyValueActiveHuntStore` verwirft eine unlesbare Nutzlast **vollständig**,
/// und das ist dort richtig: eine halbe Jagd ist keine Jagd. Hier ist es
/// falsch. Die Einträge sind voneinander unabhängig, und wer wegen einer
/// kaputten Zahl die Sammlung von zwei Wochen verliert, hat den schlechteren
/// Tausch gemacht. Diese Umsetzung liest deshalb, was lesbar ist, und meldet
/// den Rest.
///
/// Verworfen wird ein Eintrag, der keine Zahl ist, der keine ganze Zahl ist,
/// oder der nicht positiv ist. Die letzte Bedingung ist dieselbe, die
/// [FactId] von seinem Mapper erwartet: `facts.id` ist
/// `generated always as identity` und beginnt bei 1. Eine `0` oder eine
/// negative Zahl ist keine Kennung, die es je gegeben hat.
///
/// Ist der **ganze** Wert kein JSON oder keine Liste, ist das ein Defekt des
/// Speichers und nicht der Sammlung; dann ist die Sammlung leer, gemeldet mit
/// demselben Ereignis.
final class KeyValueCollectedFactsStore implements CollectedFactsStore {
  /// [store] ist der geladene Gerätespeicher aus `bootstrap()`, [sink] nimmt
  /// verworfene Einträge auf.
  const KeyValueCollectedFactsStore(
    this._store, {
    this._sink = const SilentDiagnosticSink(),
  });

  /// Schlüssel im Gerätespeicher, wie in der Quelle.
  static const String storageKey = 'fact_collected';

  /// Name des Ereignisses, mit dem verworfene Einträge gemeldet werden.
  ///
  /// Steht als Konstante da, damit ein Test ihn nicht ein zweites Mal tippt.
  static const String discardedEventName = 'facts.collected_entries_discarded';

  /// Schlüssel im Meldungsanhang, unter dem die Anzahl verworfener Einträge
  /// steht.
  static const String discardedCountField = 'discarded';

  final KeyValueStore _store;
  final DiagnosticSink _sink;

  /// Die gespeicherte Sammlung, in der Reihenfolge des Einsammelns.
  ///
  /// **Ohne eigenen Zwischenspeicher, und das ist eine Entscheidung.** Jeder
  /// Aufruf liest und entschlüsselt neu. Die Alternative wäre ein Feld, das
  /// nach dem ersten Lesen stehen bleibt, und damit eine zweite Wahrheit
  /// neben dem Gerätespeicher: sobald ein Schreibvorgang scheitert, gingen
  /// die beiden auseinander, und der Nutzer sähe eine Sammlung, die nach dem
  /// Neustart kleiner ist. Der Preis ist ein `jsonDecode` je Aufruf, und der
  /// Verbraucher ist ohnehin ein Riverpod-Notifier, der den Wert hält.
  @override
  List<FactId> readCollectedFacts() {
    final String? raw = _store.readString(storageKey);
    if (raw == null) {
      // Der Normalzustand jedes neuen Nutzers. Ihn zu melden hieße, die Senke
      // bei jedem Start mit einer Nichtmeldung zu füllen, genau wie beim
      // leeren Jagd-Schlüssel.
      return const <FactId>[];
    }
    final Object? decoded = _tryDecode(raw);
    if (decoded is! List) {
      _report(1);
      return const <FactId>[];
    }
    final List<FactId> collected = <FactId>[];
    int discarded = 0;
    for (final Object? entry in decoded) {
      final FactId? id = _tryReadId(entry);
      if (id == null) {
        discarded++;
        continue;
      }
      // Ein doppelter Eintrag ist kein verworfener: die Sammlung enthält
      // ihn, nur eben einmal. Gemeldet wird er nicht, weil `collectFact`
      // ihn nie erzeugt und ein von Hand veränderter Speicher keine
      // Meldung wert ist, die wie ein Datenverlust aussieht.
      if (collected.contains(id)) {
        continue;
      }
      collected.add(id);
    }
    if (discarded > 0) {
      _report(discarded);
    }
    return List<FactId>.unmodifiable(collected);
  }

  /// Nimmt [factId] auf, falls sie fehlt.
  ///
  /// Liest dafür die gespeicherte Liste, und **nicht** einen im Speicher
  /// gehaltenen Zwischenstand, siehe die Begründung an [readCollectedFacts].
  /// Ohne `try` um `jsonEncode`: die Liste enthält nur `int`, das kann nicht
  /// scheitern, und der Vertrag von [KeyValueStore.writeString] verschluckt
  /// den Rest.
  @override
  Future<void> collectFact(FactId factId) async {
    final List<FactId> collected = readCollectedFacts();
    if (collected.contains(factId)) {
      return;
    }
    await _store.writeString(
      storageKey,
      jsonEncode(<int>[
        ...collected.map((FactId id) => id.value),
        factId.value,
      ]),
    );
  }

  /// Der entschlüsselte Rohwert, oder `null`, wenn [raw] kein JSON ist.
  Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// [entry] als Kennung, oder `null`, wenn daraus keine werden kann.
  ///
  /// `is int` und nicht `is num`: `jsonDecode` liefert für `7.0` ein `double`,
  /// und eine Kennung mit Nachkommastelle ist keine. Sie stillschweigend zu
  /// runden hieße, einen fremden Fakt in die Sammlung zu nehmen.
  FactId? _tryReadId(Object? entry) {
    if (entry is! int || entry <= 0) {
      return null;
    }
    return FactId(entry);
  }

  void _report(int discarded) {
    _sink.report(
      DiagnosticEvent(discardedEventName, <String, String>{
        discardedCountField: '$discarded',
      }),
    );
  }
}
