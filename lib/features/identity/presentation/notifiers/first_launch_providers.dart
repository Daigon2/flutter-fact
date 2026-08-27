import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod-Komposition der Erstlauf-Merkung (ADR-005: Riverpod ist der einzige
/// DI-Mechanismus). Handgeschriebene Provider, weil `riverpod_generator` mit
/// diesem Abhängigkeitsstand nicht neben `go_router_builder` auflösbar ist
/// (ADR-003).
///
/// ## Warum das hier in `presentation/notifiers/` liegt und nicht in `data/`
///
/// `tool/check_architecture.dart` verbietet `presentation` jeden Import aus
/// `data`, auch aus dem eigenen Feature. Der Startbildschirm muss das Flag aber
/// selbst setzen, also braucht er einen Zugang, der nicht durch `data` führt.
/// `docs/architecture/project-structure.md` deckt das ab: "Feature UI providers
/// live in `presentation`". Der Vertrag selbst steht in der Domäne, hier steht
/// nur die Verdrahtung.
///
/// Sobald echte Persistenz kommt, zieht die persistente Implementierung nach
/// `features/identity/data/` und wird per `overrideWithValue` aus `bootstrap()`
/// gebunden. An dieser Datei ändert sich dabei nichts.

/// Speicher der Erstlauf-Merkung.
///
/// Der Standard ist flüchtig, siehe [InMemoryFirstLaunchStore].
final firstLaunchStoreProvider = Provider<FirstLaunchStore>(
  (ref) => InMemoryFirstLaunchStore(),
);

/// Ob der Startbildschirm schon durchlaufen wurde.
///
/// `true` heißt: die Weiche in `lib/app/routing/route_guards.dart` lässt die
/// App direkt auf die Karte. `false` heißt: sie leitet auf `/splash` um.
final firstLaunchProvider = NotifierProvider<FirstLaunchNotifier, bool>(
  FirstLaunchNotifier.new,
);

/// Besitzer der Erstlauf-Merkung.
///
/// Der Zustand ist ein einzelner unveränderlicher Wert, kein `ChangeNotifier`
/// (ADR-003).
class FirstLaunchNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(firstLaunchStoreProvider).hasLaunched();

  /// Merkt den erfolgten Start und speichert ihn danach.
  ///
  /// Die Oberfläche folgt sofort, der Schreibvorgang läuft hinterher. Ein
  /// fehlgeschlagenes Speichern soll den laufenden Start nicht zurücknehmen,
  /// sonst springt der Nutzer mitten im Tippen zurück auf den Startbildschirm.
  ///
  /// Idempotent: ist die Merkung schon gesetzt, passiert nichts. Ohne diese
  /// Abkürzung würde jeder Aufruf einen Provider-Zyklus und damit ein
  /// `router.refresh()` auslösen.
  Future<void> markLaunched() async {
    if (state) {
      return;
    }
    state = true;
    await ref.read(firstLaunchStoreProvider).markLaunched();
  }
}
