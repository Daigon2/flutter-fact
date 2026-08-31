/// Der Weg, auf dem `discovery` an die laufende Jagd kommt, und der Ort, an dem
/// der Speicher gebunden wird. Umsetzung von ADR-007.
///
/// ## Warum diese Datei in `application/` liegt und nicht woanders
///
/// Es ist derselbe konstruktive Zwang wie beim Karten-Host und bei den Fakten,
/// und `dependency-rules.md` führt ihn dort als dritten und vierten Fall unter
/// „Providers that construct dependencies". Dies ist der **fünfte**:
///
/// * Der Vertrag liegt in `challenges/domain/`, und dort verbietet Regel 2
///   jeden Riverpod-Import. Der Provider kann also nicht zum Vertrag.
/// * `challenges/presentation/` ist für den Verbraucher `discovery` nach
///   Regel 8 unerreichbar, und **das prüft Gate 4 maschinell**. Dort kann der
///   Provider also auch nicht liegen, obwohl die vier bestehenden Speicher
///   genau dort gebunden werden (`firstLaunchStoreProvider` in
///   `identity/presentation/notifiers/`). Der Unterschied ist der Verbraucher
///   und nicht der Geschmack: die Erstlauf-Merkung liest nur ihr eigenes
///   Feature.
/// * `application/` bleibt übrig, und Regel 10 nennt genau das als erlaubten
///   Weg über eine Feature-Grenze.
///
/// ## Wie der Nur-Lese-Zugriff gehalten wird
///
/// `map/application/map_host_providers.dart` löst dieselbe Frage mit **zwei**
/// Providern über demselben Objekt: `mapHostProvider` ist auf `MapHost`
/// typisiert und hat kein `attach`, `mapHostRegistryProvider` auf die
/// Registry. Der dort notierte Kern gilt auch hier: „Whenever a provider must
/// be readable by two layers with different rights, split it by type before
/// splitting it by convention."
///
/// **Das Mittel passt, das Fahrzeug nicht.** Der Karten-Host braucht eine
/// schmale *Objekt*-Fassade, weil ein Feature dort ein Objekt in der Hand
/// halten muss, um Absichten abzugeben. Hier braucht der Verbraucher gar kein
/// Objekt: [activeHuntProvider] liefert einen **unveränderlichen Wert**. Ein
/// `ActiveHunt` hat keine Methode, die etwas ändern könnte, und ein `Provider`
/// hat, anders als ein `NotifierProvider`, kein `.notifier`. Wer nur diesen
/// Provider hält, kann den Jagdzustand nicht schreiben, und das hält der
/// Übersetzer und kein Kommentar. Ein zweiter Provider über demselben Objekt
/// wäre hier kein Gewinn, er brächte nur das Objekt zurück, das der
/// Verbraucher nicht braucht.
///
/// **Was der Übersetzer nicht hält**, und das gehört dazu:
/// [activeHuntStoreProvider] steht in derselben Bibliothek und trägt den
/// Schreibweg. Rein technisch könnte `discovery` ihn benennen, auf
/// `ActiveHuntStore` typisiert und in einer Zeile.
///
/// **Der Vergleich mit `mapHostRegistryProvider` trägt hier nicht.** Beim
/// Karten-Host ist ein falscher Griff laut: das Kartenbild ändert sich, oder es
/// ändert sich nicht. Hier ist er stumm. Weil [activeHuntProvider] sein
/// Ergebnis merkt, erzeugt ein Schreibvorgang aus `discovery` **keine**
/// Benachrichtigung; der Fehler erscheint als „die Station rückt nicht vor",
/// also als Fehler in der Karte und nicht als Fehler in der Zuständigkeit. Und
/// ADR-007 Regel 2 nennt genau diesen Griff namentlich: „Writes to hunt state
/// happen through `challenges`, never from the map screen."
///
/// Deshalb steht dafür jetzt eine Textwache in
/// `test/features/challenges/application/active_hunt_write_access_test.dart`:
/// keine Datei unter `lib/features/discovery/` darf diesen Namen nennen. Was
/// die Wache nicht kann, steht in ihrem eigenen Kommentar. Regel 10 bleibt im
/// Übrigen Review-Sache, weil `tool/check_architecture.dart` sie nach eigener
/// Aussage nicht sieht.
library;

import 'package:fact_app/features/challenges/domain/active_hunt_store.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Speicher der laufenden Jagd.
///
/// Der Standard ist flüchtig, siehe [InMemoryActiveHuntStore]. Sobald es eine
/// persistente Umsetzung gibt, entsteht sie in `challenges/data` und wird aus
/// `bootstrap()` per `overrideWithValue` hier eingehängt; an dieser Datei
/// ändert sich dabei nichts.
///
/// **Wer hier landet, weil er die laufende Jagd nur ansehen will, ist falsch:**
/// dafür gibt es [activeHuntProvider]. Dieser Provider trägt den Schreibweg
/// und wird von `challenges` selbst und von der App-Komposition gelesen.
final Provider<ActiveHuntStore> activeHuntStoreProvider =
    Provider<ActiveHuntStore>((Ref ref) => InMemoryActiveHuntStore());

/// Die laufende Jagd, oder `null`, wenn keine läuft.
///
/// Das ist der Provider, den `discovery/presentation` beobachtet, und der
/// einzige Zugang von außen zum Jagdzustand.
///
/// ## Er wird heute nicht benachrichtigt, und das ist die Naht zu Schritt 36
///
/// Ein `Provider` fragt seinen Rumpf einmal und merkt sich das Ergebnis. Wer
/// den Speicher hinter diesem Provider direkt beschreibt, ändert den
/// gespeicherten Wert, **ohne** dass ein Beobachter davon erfährt: die Karte
/// zeigte weiter die alte Station. Ein Test hält das fest, damit es nicht nur
/// als Kommentar in einer Datei steht, die beim Weiterbauen niemand aufschlägt.
///
/// Die Phasenmaschine aus Schritt 36 löst das so, wie es in diesem Projekt
/// schon viermal gelöst ist (`FirstLaunchNotifier`): ein `Notifier` besitzt den
/// Zustand, setzt ihn und schreibt danach in den Speicher. Der Rumpf hier wird
/// dann ein `ref.watch` auf diesen Notifier, **der Typ dieses Providers bleibt
/// wie er ist**, und für `discovery` ändert sich nichts. Genau das ist der Sinn
/// dieser Naht.
final Provider<ActiveHunt?> activeHuntProvider = Provider<ActiveHunt?>(
  (Ref ref) => ref.watch(activeHuntStoreProvider).readActiveHunt(),
);
