/// Wertgleichheit für Listen und Karten, ohne Paket und ohne Flutter.
///
/// Warum das hier steht und nicht in `core/`: Gate 6 aus
/// `docs/engineering/quality-gates.md` und die Schichttabelle in
/// `docs/architecture/dependency-rules.md` verbieten der Feature-Domäne jeden
/// Import aus `core/`. `package:collection` und `foundation.dart` sind
/// ebenfalls aus: das eine wäre ein neues Paket (Stufe 3), das andere Flutter
/// in der Domäne (Regel 1).
///
/// Die Funktionen vergleichen flach in Reihenfolge, verlassen sich also auf das
/// `==` der Elemente. Für die unveränderlichen Wertobjekte dieses Features
/// reicht das genau.
library;

/// Sind [a] und [b] gleich lang und elementweise gleich?
///
/// `null` ist nur zu `null` gleich. Zwei leere Listen sind gleich.
bool listsEqual<T>(List<T>? a, List<T>? b) {
  if (a == null || b == null) {
    return a == null && b == null;
  }
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// Haben [a] und [b] dieselben Schlüssel mit denselben Werten?
bool mapsEqual<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (a == null || b == null) {
    return a == null && b == null;
  }
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

/// Reihenfolgetreuer Hash über [values].
///
/// `Object.hashAll` liefert das, die Funktion existiert nur, damit ein
/// `null` nicht am Aufrufort behandelt werden muss.
int hashList<T>(List<T>? values) => values == null ? 0 : Object.hashAll(values);

/// Hash über eine Karte, unabhängig von der Einfügereihenfolge.
int hashMap<K, V>(Map<K, V>? values) {
  if (values == null) {
    return 0;
  }
  return Object.hashAllUnordered(
    values.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}
