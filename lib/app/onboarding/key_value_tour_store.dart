import 'package:fact_app/app/onboarding/tour_store.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';

/// [TourStore] auf dem Gerätespeicher.
///
/// Löst die Lücke, die [InMemoryTourStore] in ihrer Dokumentation benennt: „das
/// Tutorial erscheint bei jedem Start erneut".
///
/// Liegt hier und nicht in einem Feature, weil der Vertrag hier liegt. Das
/// Tutorial ist keine Einstellung und gehört keiner Fachdomäne; `app/onboarding`
/// ist App-Komposition und darf `core` und `services` sehen
/// (`dependency-rules.md`, Zeile „App composition").
///
/// Schlüsselname wie in der Quelle (`fact_tour_shown`, `storage.jsx:100-101`),
/// aus demselben Grund wie bei `KeyValueFirstLaunchStore`: Nachvollziehbarkeit,
/// keine gemeinsame Nutzung.
///
/// **Die Quelle speichert hier einen Wahrheitswert als Zeichenkette** („true"
/// beziehungsweise „false", `storage.jsx:101`). Diese Umsetzung speichert einen
/// echten Wahrheitswert. Das ist kein Paritätsbruch, weil die beiden Speicher
/// nichts miteinander zu tun haben, aber es steht hier, damit niemand die
/// Zeichenkette der Quelle für einen Vertragsteil hält.
final class KeyValueTourStore implements TourStore {
  /// [store] ist der geladene Gerätespeicher aus `bootstrap()`.
  const KeyValueTourStore(this._store);

  /// Schlüssel im Gerätespeicher, wie in der Quelle.
  static const String storageKey = 'fact_tour_shown';

  final KeyValueStore _store;

  @override
  bool hasSeenTour() => _store.readBool(storageKey) ?? false;

  @override
  Future<void> markTourSeen() => _store.writeBool(storageKey, true);
}
