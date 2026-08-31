/// Vertrag für „die laufende Jagd übersteht einen Neustart der App".
///
/// ADR-007 hält das als Produktvorgabe fest: eine Jagd zieht sich über einen
/// Spaziergang durch eine Stadt, und genau während dieses Spaziergangs wird die
/// App in den Hintergrund geschoben und vom Betriebssystem abgeräumt. Die
/// Quelle hat dieselbe Lehre schon bezahlt, ihr Kommentar sagt es wörtlich:
/// „FIX (Daniel-Feedback): App-Crash mitten in Challenge soll Spielstand nicht
/// verlieren" (`app.jsx:86-88`). Gelesen wird beim Start
/// (`app.jsx:90-96`), geschrieben bei **jeder** Änderung (`app.jsx:194-201`).
///
/// ## Der fünfte Speicher, und der erste mit einem Grund zu persistieren
///
/// Vier Speicher dieser Bauart gab es schon: `FirstLaunchStore`, `TourStore`,
/// `AudioModeStore` und `LanguagePreferenceStore`. **Bis zum 31.08.2026 waren
/// alle vier flüchtig, und dieser hier war es mit ihnen.** Er ist trotzdem der
/// einzige, bei dem das falsch war und nicht bloß unbequem: die anderen vier
/// kosteten beim Neustart eine Unbequemlichkeit, dieser einen Spielstand.
///
/// Die Speichertechnik ist weiterhin **nicht** hier entschieden, und dieser
/// Vertrag hängt an keiner. Entschieden ist sie in ADR-007 und freigegeben am
/// 31.08.2026: `shared_preferences`, aufgenommen in `pubspec.yaml`, gekapselt
/// hinter `KeyValueStore` aus `lib/core/preferences/` und auf
/// `lib/services/preferences/` beschränkt (Regel 22). Die Messung aus ADR-007
/// hat gehalten: `flutter pub get` meldete „from transitive dependency to
/// direct dependency" und „Changed 1 dependency", es ist also kein Byte neuer
/// Code in den Bau gekommen.
///
/// ## Was der Vertrag von einer persistenten Umsetzung verlangt
///
/// 1. **[ActiveHuntStore.readActiveHunt] bleibt synchron.** Derselbe Grund wie
///    bei allen vier bestehenden Speichern: `bootstrap()` lädt vor dem ersten
///    Bild und überschreibt den Provider mit einer gefüllten Umsetzung. Ein
///    `Future` hier zwänge jeden Leser in einen Ladezustand, obwohl der Wert
///    beim ersten Bild feststeht. Bei einer laufenden Jagd wäre das besonders
///    unpassend, denn der Kartenbildschirm entscheidet daran, **ob** er die
///    Jagd-Leiste überhaupt aufbaut; ein Aufflackern der Karte ohne Jagd wäre
///    die schlechteste Reihenfolge.
/// 2. **Wiederherstellen prüft.** Eine unlesbare oder veraltete Nutzlast wird
///    verworfen und nicht repariert (ADR-007, „Rules"). Die Regel steht
///    vollständig in `ActiveHunt.tryFromPayload`, damit es nicht zwei Orte
///    gibt, an denen „gültig" definiert ist; die Umsetzung liefert nur den
///    entschlüsselten Rohwert und gibt `null` zurück, wenn dabei etwas
///    schiefgeht.
/// 3. **Schreiben darf scheitern, ohne die Jagd zu stören.** Die Quelle
///    verschluckt den Fehler ausdrücklich („localStorage voll oder geblockt —
///    ignorieren", `app.jsx:200`). [ActiveHuntStore.writeActiveHunt] gibt
///    deshalb `Future<void>` zurück und wirft nicht: ein verlorener
///    Speichervorgang darf einen Spielzug nicht zurücknehmen, genau wie bei
///    `FirstLaunchNotifier.markLaunched`.
///
/// ## Warum Punkt 3 und „keine eigene Prüfung" zusammen möglich sind
///
/// Sie waren es einmal nicht. Solange [ActiveHunt] einen offenen, ungeprüften
/// Konstruktor hatte, konnte eine Jagd `NaN` oder eine Unendlichkeit als Lage
/// tragen, und dann wirft `jsonEncode(hunt.toPayload())` einen
/// `JsonUnsupportedObjectError`. Eine Umsetzung, die aus Schlüssel schreiben
/// plus `jsonEncode` besteht, hätte also entweder geworfen (gegen Punkt 3) oder
/// eine zweite Gültigkeitsprüfung gebraucht (gegen Punkt 2).
///
/// Aufgelöst ist es an der Wurzel: der Konstruktor von [ActiveHunt] ist privat,
/// jede Jagd kommt aus `ActiveHunt.tryFrom`, und eine nicht-endliche Lage gibt
/// es dort nicht. Die Umsetzung braucht deshalb weder eine Prüfung noch ein
/// `try`, und wenn sie trotzdem eines will, dann für den Gerätespeicher und
/// nicht für die Nutzlast.
///
/// Die persistente Umsetzung gehört nach `challenges/data` (ADR-007), die
/// flüchtige bleibt die Vorgabe für Tests.
library;

import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';

/// Speicher der laufenden Jagd.
abstract interface class ActiveHuntStore {
  /// Die gespeicherte Jagd, oder `null`.
  ///
  /// `null` heißt „es läuft keine Jagd" und deckt damit **beide** Fälle ab: es
  /// wurde keine gespeichert, oder die gespeicherte war unlesbar und ist
  /// verworfen. Die Unterscheidung wäre für den Aufrufer ohne Nutzen, denn er
  /// kann in keinem der beiden Fälle etwas anderes tun. Wer den Unterschied
  /// zählen will, meldet ihn in der Umsetzung an `DiagnosticSink`, nicht über
  /// den Rückgabewert.
  ActiveHunt? readActiveHunt();

  /// Speichert [hunt] dauerhaft und ersetzt eine bereits gespeicherte Jagd.
  ///
  /// Es gibt bewusst nur diese eine Schreiboperation und keinen Feld-Zugriff:
  /// die Quelle schreibt bei jeder Änderung den ganzen Zustand
  /// (`app.jsx:194-201`), und ein teilweiser Schreibvorgang wäre eine zweite
  /// Wahrheit auf der Platte.
  ///
  /// **Was erwartet wird, und wer dafür sorgt:** [hunt] ist eine gültige Jagd.
  /// Dafür sorgt nicht der Aufrufer und nicht diese Methode, sondern der Typ,
  /// dessen Konstruktor privat ist. Eine ungültige Jagd könnte diese Methode
  /// nicht abweisen, ohne die Prüfregeln ein zweites Mal aufzuschreiben, und sie
  /// könnte sie nicht annehmen, ohne dass `ActiveHunt.tryFromPayload` sie beim
  /// nächsten Start verwirft. Deshalb steht die Prüfung am Konstruktor und nicht
  /// hier.
  Future<void> writeActiveHunt(ActiveHunt hunt);

  /// Löscht die gespeicherte Jagd.
  ///
  /// Getrennt von [writeActiveHunt] und nicht als `write(null)`, weil die
  /// Quelle es genauso trennt (`Storage.clearActiveChallenge`,
  /// `storage.jsx:192`, gerufen in `app.jsx:199`). Ein nullbarer Parameter
  /// machte „die Jagd ist zu Ende" und „ich habe gerade keinen Wert" an der
  /// Aufrufstelle ununterscheidbar.
  ///
  /// Idempotent: ohne gespeicherte Jagd passiert nichts.
  Future<void> clearActiveHunt();
}

/// Flüchtiger Speicher, Vorgabe für Tests.
///
/// Die Jagd überlebt den Neustart nicht. **Bis zum 31.08.2026 war das der
/// Zustand der laufenden App**, und damit genau der Fall, den ADR-007 mit
/// seiner Produktvorgabe ausgeschlossen hatte. Seither überschreibt
/// `bootstrap()` den Provider mit `KeyValueActiveHuntStore` aus
/// `challenges/data`, und dieser hier bleibt, was er immer sein sollte: die
/// Vorgabe für Tests.
final class InMemoryActiveHuntStore implements ActiveHuntStore {
  /// [hunt] setzt eine bereits laufende Jagd, etwa in einem Test.
  InMemoryActiveHuntStore({ActiveHunt? hunt}) : _hunt = hunt;

  ActiveHunt? _hunt;

  @override
  ActiveHunt? readActiveHunt() => _hunt;

  @override
  Future<void> writeActiveHunt(ActiveHunt hunt) async {
    _hunt = hunt;
  }

  @override
  Future<void> clearActiveHunt() async {
    _hunt = null;
  }
}
