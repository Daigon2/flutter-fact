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

import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
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

/// Besitzer des Zustands einer laufenden Jagd, Schritt 36.
///
/// Setzt den Zustand und schreibt ihn danach in den Speicher: derselbe
/// Zwei-Schritt wie bei `FirstLaunchNotifier` in
/// `identity/presentation/notifiers/first_launch_providers.dart`, dem Vorbild
/// für diese Bauform. Die Oberfläche folgt der Zustandsänderung sofort, der
/// Schreibvorgang läuft asynchron hinterher: er kann scheitern (Punkt 3 im
/// Kopfkommentar von `active_hunt_store.dart`), und ein gescheitertes
/// Speichern soll einen bereits vollzogenen Spielzug nicht zurücknehmen.
///
/// ## Warum kein `ref.invalidateSelf()` nach dem Schreiben
///
/// Der naheliegende Gegenentwurf: [build] liest, wie es das ohnehin tut, aus
/// einer Quelle, und jeder Befehl ruft nach dem Schreiben `ref.invalidateSelf()`
/// auf, statt `state` selbst zu setzen. Zwei Gründe dagegen, beide schon in
/// `FirstLaunchNotifier.markLaunched` angelegt, dessen Kommentar es wörtlich
/// sagt: „Die Oberfläche folgt sofort, der Schreibvorgang läuft hinterher."
///
/// 1. **Die Reihenfolge kippt.** `invalidateSelf()` müsste *nach* dem
///    Schreibvorgang stehen, sonst liest [build] noch den alten Wert. Das
///    dreht „setzen, dann speichern" in „speichern, dann lesen", und die
///    Oberfläche wartet auf den Speichervorgang, statt ihm voraus zu sein.
/// 2. **Ein gescheitertes Speichern würde die Änderung verschlucken.** Bleibt
///    der Schreibvorgang aus, läse ein `invalidateSelf()` beim nächsten
///    Zugriff wieder den unveränderten Speicherinhalt, und der Spielzug wäre
///    verloren, obwohl [HuntRun] ihn korrekt vollzogen hatte.
///
/// Deshalb setzt jeder Befehl hier `state` direkt und stößt den
/// Schreibvorgang nur als Nebenwirkung an.
class HuntRunNotifier extends Notifier<HuntRun?> {
  /// Keine laufende Jagd beim Start.
  ///
  /// **Das ist die Grenze aus ADR-007, kein vergessenes Wiederherstellen.**
  /// [ActiveHuntStore.readActiveHunt] liefert ein `ActiveHunt`: ein
  /// dauerhaftes Lesemodell aus Stationsnummer, Titel und Koordinate, aber
  /// ohne den dahinterstehenden `HuntPlan` mit seinem Fakt und Rätsel je
  /// Station, denn genau die werden nicht gespeichert (siehe den
  /// Kopfkommentar von `hunt_plan.dart`). Aus einer gespeicherten
  /// `ActiveHunt` lässt sich deshalb kein [HuntRun] bauen. Eine Jagd, die
  /// einen App-Neustart überlebt hat, bleibt über [activeHuntProvider] auf
  /// der Karte sichtbar (siehe dort für die Rangfolge), aber ohne [HuntRun]
  /// lässt sie sich nicht fortsetzen. Die vollständige Wiederherstellung ist
  /// ein eigener, späterer Schritt.
  @override
  HuntRun? build() => null;

  /// Beginnt eine neue Jagd nach [plan].
  Future<void> start(HuntPlan plan) => _apply(HuntRun.start(plan));

  /// Schaltet Hinweis [hintIndex] an der aktuellen Station frei.
  Future<void> unlockHint(int hintIndex) =>
      _update((HuntRun run) => run.unlockHint(hintIndex));

  /// Löst die Station an [index].
  Future<void> solveStop(
    int index, {
    required int pointsAwarded,
    required bool hintUsed,
  }) => _update(
    (HuntRun run) =>
        run.solveStop(index, pointsAwarded: pointsAwarded, hintUsed: hintUsed),
  );

  /// Überspringt die Station an [index].
  Future<void> skipStop(int index) =>
      _update((HuntRun run) => run.skipStop(index));

  /// Markiert den Fakt an [index] als eingesammelt.
  Future<void> collectStop(int index) =>
      _update((HuntRun run) => run.collectStop(index));

  /// Beendet die laufende Jagd und löscht sie aus dem Speicher.
  ///
  /// Ohne laufende Jagd passiert nichts, aus demselben Grund wie in
  /// [_update].
  Future<void> end() async {
    if (state == null) {
      return;
    }
    state = null;
    await ref.read(activeHuntStoreProvider).clearActiveHunt();
  }

  /// Wendet [transition] auf den laufenden [HuntRun] an, oder tut nichts.
  ///
  /// **Kein Wurf ohne laufende Jagd.** Jeder Aufrufer dieser Befehle ist eine
  /// Oberfläche, die selbst nur anzeigt, was gerade läuft (die aktuelle
  /// Station, ihre Hinweise); sie kann also gar keinen Index oder Hinweis für
  /// eine Jagd anbieten, die es nicht mehr gibt. Erreicht ein Befehl den
  /// Notifier trotzdem nach dem Ende der Jagd, etwa weil eine asynchrone
  /// Prüfung erst zurückkommt, nachdem [end] schon lief, ist das ein
  /// Wettlauf zwischen zwei Bedienhandlungen und kein Programmfehler: die
  /// Jagd ist vorbei, der verspätete Befehl hat nichts mehr zu tun. Ein
  /// `StateError` dafür wäre so, als würfe ein Aufzug einen Fehler, weil ein
  /// Knopf gedrückt wurde, nachdem die Tür schon zu ist.
  Future<void> _update(HuntRun Function(HuntRun current) transition) {
    final HuntRun? current = state;
    if (current == null) {
      return Future<void>.value();
    }
    return _apply(transition(current));
  }

  /// Setzt [run] als neuen Zustand und schreibt ihn danach in den Speicher.
  ///
  /// **Speichert bei jeder Änderung, nicht nur beim Beenden** (`app.jsx:194-
  /// 201`, siehe den Kopfkommentar von `active_hunt_store.dart`). Ist
  /// [HuntRun.toActiveHunt] `null`, wird nicht geschrieben: nach dem
  /// Kopfkommentar von `hunt_run.dart` ist das kein Fehler dieser
  /// Phasenmaschine, sondern eine nicht-endliche oder außerhalb von
  /// ±90/±180 liegende Koordinate am zugrunde liegenden Fakt, also ein
  /// Datenfehler, der schon vor [HuntRun] entstanden ist. ADR-007 verlangt
  /// für genau diesen Fall „verwerfen statt reparieren, nicht werfen": der
  /// laufende Zustand bleibt im Notifier unverändert stehen, nur die
  /// Persistenz dieser einen Änderung entfällt.
  Future<void> _apply(HuntRun run) async {
    state = run;
    final ActiveHunt? activeHunt = run.toActiveHunt();
    if (activeHunt == null) {
      return;
    }
    await ref.read(activeHuntStoreProvider).writeActiveHunt(activeHunt);
  }
}

/// Der Zustand der laufenden Jagd, oder `null`, wenn keine läuft.
///
/// Besitzer ist [HuntRunNotifier]; siehe dort für die Übergänge und die
/// Begründung, warum [HuntRunNotifier.build] keine gespeicherte Jagd
/// wiederherstellt.
final NotifierProvider<HuntRunNotifier, HuntRun?> huntRunProvider =
    NotifierProvider<HuntRunNotifier, HuntRun?>(HuntRunNotifier.new);

/// Die laufende Jagd, oder `null`, wenn keine läuft.
///
/// Das ist der Provider, den `discovery/presentation` beobachtet, und der
/// einzige Zugang von außen zum Jagdzustand.
///
/// ## Zwei Quellen, und ihre Rangfolge
///
/// Läuft gerade eine Jagd (ein [HuntRun] steht in [huntRunProvider]), kommt
/// der Wert aus dessen `toActiveHunt()`. Läuft keine, kommt er wie zuvor aus
/// dem Speicher. Das ist keine beliebige Reihenfolge: eine Jagd, die einen
/// Neustart der App überlebt hat, steht im Speicher, obwohl es keinen
/// laufenden [HuntRun] gibt (siehe [HuntRunNotifier.build]), und soll dort
/// trotzdem auf der Karte sichtbar bleiben. Der Speicher ist also nicht nur
/// die Ersatzquelle, sondern die einzige Quelle für genau diesen Fall, und
/// genau dafür ist die Persistenz aus ADR-007 gebaut.
///
/// ## Warum das jetzt einen Beobachter benachrichtigt
///
/// [huntRunProvider] ist ein `NotifierProvider`; sein `ref.watch` hier löst
/// bei jeder Zustandsänderung eine neue Auswertung dieses Rumpfs aus. Ein
/// Schreibvorgang über [HuntRunNotifier] erreicht diesen Provider deshalb
/// zuverlässig. Ein Schreibvorgang **am Speicher vorbei am Notifier**, also
/// direkt über [activeHuntStoreProvider], erreicht ihn weiterhin nicht: der
/// Speicher wird nur gelesen, wenn keine Jagd läuft, und ein `Provider` fragt
/// seinen Rumpf sonst nicht erneut. Das ist jetzt kein Defekt mehr, sondern
/// der Grund, warum es [HuntRunNotifier] gibt: wer den Speicher direkt
/// beschreibt, umgeht den Besitzer des Zustands.
final Provider<ActiveHunt?> activeHuntProvider = Provider<ActiveHunt?>((
  Ref ref,
) {
  final HuntRun? run = ref.watch(huntRunProvider);
  if (run != null) {
    return run.toActiveHunt();
  }
  return ref.watch(activeHuntStoreProvider).readActiveHunt();
});
