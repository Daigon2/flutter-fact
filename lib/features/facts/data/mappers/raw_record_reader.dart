/// Liest Felder aus einer ungeprüften Rohzeile, ohne je zu werfen.
///
/// ## Warum es diesen Leser gibt
///
/// Der alte Flutter-Port las mit `m['hero'] as String?` und Verwandten. Ein
/// einziger Wert der falschen Form löschte damit die komplette Faktenliste,
/// weil `getFacts` als Ganzes scheiterte. Fehler-Isolation durch Sorgfalt am
/// Aufrufort hat dort nicht funktioniert und wird auch hier nicht funktionieren.
///
/// Deshalb gilt es hier **durch die Konstruktion**: dieser Leser enthält keinen
/// einzigen `as`-Cast auf einen Rohwert, jede Methode prüft mit `is` und liefert
/// im Zweifel den Ausfallwert. Wer über diesen Leser geht, kann keinen
/// Cast-Fehler auslösen. Der Mapper greift nirgends direkt in die Rohkarte.
///
/// ## Was der Leser nicht entscheidet
///
/// Er weiß nicht, welches Feld pflicht ist, und kennt den Fakt nicht, zu dem
/// die Zeile gehört. Er sammelt nur [RawFieldDefect]-Einträge; erst der Mapper
/// macht daraus `FactDefect`-Befunde mit Bezug und Schwere.
library;

/// Ein Feld hatte nicht die erwartete Form.
///
/// Absichtlich ohne Fakt-Bezug und ohne Wert: der Leser kennt beides nicht, und
/// der Wert gehört in keinen Bericht.
class RawFieldDefect {
  /// [field] ist der Spalten- oder Schlüsselname, [encounteredType] der
  /// vorgefundene Laufzeittyp.
  const RawFieldDefect(this.field, this.encounteredType);

  /// Name des Feldes in den Rohdaten.
  final String field;

  /// Was stattdessen dastand, etwa `String` statt `List`.
  final String encounteredType;

  @override
  String toString() => 'RawFieldDefect($field: $encounteredType)';
}

/// Tolerantes Lesen einer Rohzeile.
class RawRecordReader {
  RawRecordReader._(this._values, this.defects);

  /// Baut einen Leser über [raw].
  ///
  /// Ist [raw] kein Objekt, ist [isRecord] `false` und jeder Lesezugriff
  /// liefert den Ausfallwert. Ein `null` ist dabei kein Mangel: PostgREST
  /// liefert für eine leere Spalte `null`, und das ist der Normalfall.
  factory RawRecordReader(Object? raw) {
    if (raw is Map<Object?, Object?>) {
      return RawRecordReader._(raw, <RawFieldDefect>[]);
    }
    return RawRecordReader._(null, <RawFieldDefect>[]);
  }

  final Map<Object?, Object?>? _values;

  /// Was beim Lesen aufgefallen ist, in Lesereihenfolge.
  final List<RawFieldDefect> defects;

  /// War [raw] überhaupt ein Objekt?
  bool get isRecord => _values != null;

  /// Der Rohwert eines Feldes, ungeprüft. Für Sonderfälle wie `puzzle_fit`,
  /// das mehrere Formen haben darf.
  Object? rawValue(String field) => _values?[field];

  /// Gibt es das Feld überhaupt, egal mit welchem Wert?
  bool has(String field) => _values?.containsKey(field) ?? false;

  /// Ein Text, oder `null`.
  ///
  /// Rand-Leerzeichen fallen weg, ein danach leerer Text gilt als nicht
  /// gesetzt. Zahlen und `bool` werden **nicht** in Text verwandelt: das würde
  /// aus einem Datenfehler stillschweigend einen Anzeigewert machen.
  ///
  /// Der Literaltext `'null'` gilt als nicht gesetzt. Das ist kein
  /// Übereifer, sondern ein belegtes Vorkommnis: die Pipeline hat `hint`-Werte
  /// als Zeichenkette `"null"` geschrieben, und der alte Port musste das
  /// abfangen (`08_Flutter/lib/models/fact.dart:340`).
  String? optionalString(String field) {
    final Object? value = _values?[field];
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'null') {
        return null;
      }
      return trimmed;
    }
    _record(field, value);
    return null;
  }

  /// Eine Ganzzahl, oder `null`.
  ///
  /// Nimmt `int`, ganzzahlige `double` und Zahlen als Text. `numeric`-Spalten
  /// kommen je nach Transportweg als `int`, `double` oder String an.
  int? optionalInt(String field) {
    final Object? value = _values?[field];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      final asDouble = value.toDouble();
      if (asDouble.isFinite && asDouble == asDouble.roundToDouble()) {
        return asDouble.toInt();
      }
      _record(field, value);
      return null;
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
      final asDouble = double.tryParse(value.trim());
      if (asDouble != null &&
          asDouble.isFinite &&
          asDouble == asDouble.roundToDouble()) {
        return asDouble.toInt();
      }
    }
    _record(field, value);
    return null;
  }

  /// Eine Ganzzahl innerhalb von [min] bis [max], sonst `null`.
  ///
  /// Ein Wert außerhalb ist ein Mangel und kein stiller Ersatz: `quality_score`
  /// darf laut `facts_quality_check` nur 1 bis 3 sein, und eine 7 würde die
  /// Tour-Sortierung verzerren.
  int? optionalIntInRange(String field, {required int min, required int max}) {
    final value = optionalInt(field);
    if (value == null) {
      return null;
    }
    if (value < min || value > max) {
      _record(field, 'int($value)');
      return null;
    }
    return value;
  }

  /// Eine Zahl, oder `null`. Nimmt auch Zahlen als Text.
  num? optionalNum(String field) {
    final Object? value = _values?[field];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value;
    }
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    _record(field, value);
    return null;
  }

  /// Eine Gleitkommazahl, oder `null`.
  ///
  /// Gebraucht für `lat`, `lng` und `rating`. Alle drei sind `numeric` und
  /// kommen je nach Client als `num`, `int`, `double` oder String an.
  double? optionalDouble(String field) => optionalNum(field)?.toDouble();

  /// Ein Wahrheitswert, ersatzweise [orElse].
  ///
  /// Nimmt auch `"true"` und `"false"` als Text, weil manche Transportwege
  /// `bool` so schreiben.
  bool boolOr(String field, {required bool orElse}) {
    final Object? value = _values?[field];
    if (value == null) {
      return orElse;
    }
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    _record(field, value);
    return orElse;
  }

  /// Ein Zeitstempel in UTC, oder `null`.
  ///
  /// PostgREST liefert `timestamptz` als ISO-8601-Text mit Zeitzone.
  DateTime? optionalUtcTimestamp(String field) {
    final Object? value = _values?[field];
    if (value == null) {
      return null;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    _record(field, value);
    return null;
  }

  /// Die Texte einer Liste.
  ///
  /// Ist das Feld gar keine Liste, ist das ein Mangel und das Ergebnis leer.
  /// Genau dieser Fall trifft `hero`: die Spalte ist `text[]` und kommt als
  /// JSON-Liste, ein `as String` bricht dort.
  ///
  /// Einzelne unbrauchbare Elemente fallen weg, die brauchbaren bleiben. Jedes
  /// verworfene Element wird gemeldet.
  List<String> stringList(String field) {
    final Object? value = _values?[field];
    if (value == null) {
      return const <String>[];
    }
    if (value is! List) {
      _record(field, value);
      return const <String>[];
    }
    final result = <String>[];
    for (final element in value) {
      final Object? entry = element;
      if (entry is String) {
        final trimmed = entry.trim();
        if (trimmed.isNotEmpty && trimmed != 'null') {
          result.add(trimmed);
          continue;
        }
        continue;
      }
      if (entry == null) {
        continue;
      }
      _record(field, entry);
    }
    return List<String>.unmodifiable(result);
  }

  /// Die Elemente einer Liste, ungeprüft.
  ///
  /// Für `puzzle_fit` und andere Listen von Objekten. Ist das Feld keine Liste,
  /// gibt es `null` zurück, damit der Aufrufer „war keine Liste" von „war eine
  /// leere Liste" unterscheiden kann. Hier wird **nicht** gemeldet, weil der
  /// Aufrufer die Form besser einordnen kann.
  List<Object?>? rawList(String field) {
    final Object? value = _values?[field];
    if (value is List) {
      return List<Object?>.unmodifiable(value);
    }
    return null;
  }

  /// Ein verschachteltes Objekt, oder `null`.
  ///
  /// Trifft `_i18n` und `hint_media`. Bei `hint_media` gibt es zusätzlich den
  /// belegten Fall, dass dort nur eine URL als Text steht; den behandelt der
  /// Mapper über [rawValue].
  Map<Object?, Object?>? optionalObject(String field) {
    final Object? value = _values?[field];
    if (value == null) {
      return null;
    }
    if (value is Map<Object?, Object?>) {
      return value;
    }
    _record(field, value);
    return null;
  }

  /// Meldet einen Mangel an [field]. Öffentlich, damit der Mapper eigene
  /// Befunde in dieselbe Liste legen kann.
  void recordDefect(String field, String encounteredType) {
    defects.add(RawFieldDefect(field, encounteredType));
  }

  void _record(String field, Object value) {
    defects.add(RawFieldDefect(field, _typeNameOf(value)));
  }

  /// Der Laufzeittyp als kurzer Name, ohne Generik und ohne den Wert.
  ///
  /// `runtimeType` einer JSON-Karte heißt `_Map<String, dynamic>` und wäre in
  /// einem Bericht nur Rauschen.
  static String _typeNameOf(Object value) {
    if (value is String) {
      return 'String';
    }
    if (value is int) {
      return 'int';
    }
    if (value is double) {
      return 'double';
    }
    if (value is num) {
      return 'num';
    }
    if (value is bool) {
      return 'bool';
    }
    if (value is List) {
      return 'List';
    }
    if (value is Map) {
      return 'Map';
    }
    return 'unbekannt';
  }

  /// Der Typname eines beliebigen Rohwerts, auch von `null`. Für den Mapper.
  static String typeNameOf(Object? value) =>
      value == null ? 'null' : _typeNameOf(value);
}
