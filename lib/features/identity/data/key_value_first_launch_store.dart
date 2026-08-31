import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';

/// [FirstLaunchStore] auf dem Gerätespeicher.
///
/// Löst die Lücke, die [InMemoryFirstLaunchStore] in ihrer Dokumentation
/// benennt: „die App zeigt bei jedem Start den Startbildschirm".
///
/// Der Schlüsselname ist der der Quelle (`fact_has_launched`, `app.jsx:68-70`).
/// Das ist **Nachvollziehbarkeit und keine gemeinsame Nutzung**: die PWA
/// schreibt in den `localStorage` eines Browsers, diese App in die
/// Präferenzen des Betriebssystems. Es gibt keinen Weg, auf dem ein Wert von
/// dort hierher käme. Denselben Namen zu nehmen kostet nichts und macht das
/// Nachlesen in der Quelle möglich.
final class KeyValueFirstLaunchStore implements FirstLaunchStore {
  /// [store] ist der geladene Gerätespeicher aus `bootstrap()`.
  const KeyValueFirstLaunchStore(this._store);

  /// Schlüssel im Gerätespeicher, wie in der Quelle.
  static const String storageKey = 'fact_has_launched';

  final KeyValueStore _store;

  @override
  bool hasLaunched() => _store.readBool(storageKey) ?? false;

  /// Schreibt `true` und ist damit idempotent, wie der Vertrag verlangt.
  ///
  /// Ohne Vorprüfung, ob der Wert schon steht. Ein Lesezugriff, um einen
  /// Schreibzugriff zu sparen, wäre hier teurer als der Schreibzugriff selbst,
  /// und `FirstLaunchNotifier.markLaunched` ruft ohnehin nur einmal.
  @override
  Future<void> markLaunched() => _store.writeBool(storageKey, true);
}
