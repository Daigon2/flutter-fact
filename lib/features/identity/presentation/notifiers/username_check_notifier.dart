import 'dart:async';

import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Zustand des Username-Feldes, `screen-auth.jsx:576` (`usernameStatus`).
///
/// Die fünf Werte der Quelle, mit denselben Namen. Sie steuern Rahmenfarbe und
/// Abzeichen am Feld und entscheiden mit, ob die Registrierung abgeschickt
/// werden darf.
enum UsernameStatus {
  /// Nichts geprüft. Auch der Zustand nach einem Fehlschlag der Prüfung und,
  /// **anders als in der Quelle**, bei leerem Feld (siehe
  /// [UsernameCheckNotifier.onChanged]).
  idle,

  /// Die Eingabe ist syntaktisch gültig, das Backend antwortet noch nicht.
  checking,

  /// Frei.
  ok,

  /// Schon vergeben.
  taken,

  /// Verstößt gegen [UsernameCheckNotifier.syntax].
  invalid,
}

/// Der Zustand des Username-Feldes der Registrierung.
///
/// `isAutoDispose`, aus demselben Grund wie bei `loginProvider`: wer die
/// Registrierung verlässt und wiederkommt, soll kein rotes Kreuz von vorhin
/// sehen. Der geplante Check wird beim Entsorgen abgebrochen.
final usernameCheckProvider =
    NotifierProvider<UsernameCheckNotifier, UsernameStatus>(
      UsernameCheckNotifier.new,
      isAutoDispose: true,
    );

/// Prüft den gewünschten Username gegen das Backend,
/// `screen-auth.jsx:592-604` (`handleUsernameChange`).
///
/// ## Zwei Defekte der Quelle sind hier absichtlich **nicht** nachgebaut
///
/// **1. Der Wettlauf.** Die Quelle ruft `clearTimeout` erst *nach* dem `return`
/// des Syntaxfehlschlags:
///
/// ```js
/// const valid = /^[a-zA-Z0-9_]{2,20}$/.test(val);
/// if (!valid) { setUsernameStatus('invalid'); return; }   // <- return zuerst
/// setUsernameStatus('checking');
/// clearTimeout(usernameTimerRef.current);                 // <- erst hier
/// ```
///
/// Wer einen gültigen Namen tippt und ihn innerhalb der 500 ms ungültig macht
/// (ein Zeichen zu viel, ein Punkt, ein Leerzeichen), hat einen bereits
/// geplanten Check für den *alten* Wert im Rennen. Der läuft ab, kommt zurück
/// und setzt `ok` oder `taken`. Der Rahmen wird grün, das Abzeichen zeigt ein
/// Häkchen, und der Absende-Guard lässt einen ungültigen Namen durch. Deshalb
/// steht der Abbruch hier **vor** jeder Rückkehr, und zusätzlich verwirft
/// [_generation] eine Antwort, die schon unterwegs war.
///
/// **2. Das leere Feld zeigt ein rotes Kreuz.** `/^[a-zA-Z0-9_]{2,20}$/` passt
/// nicht auf `''`, die Quelle setzt also `invalid`, sobald man das Feld leert.
/// Ein Fehlerzustand an einem Feld, das nichts enthält, ist eine Falschaussage:
/// der Nutzer hat nichts falsch gemacht, er ist noch nicht fertig. Leer ergibt
/// hier [UsernameStatus.idle], also denselben Zustand wie beim Öffnen.
///
/// Beides ist per Test festgenagelt, weil beides ohne Test nicht auffällt.
///
/// ## Was übernommen ist, obwohl es überrascht
///
/// Ein Fehlschlag der Prüfung ergibt [UsernameStatus.idle] und **nicht** einen
/// Fehlerzustand (`catch { setUsernameStatus('idle') }`). Damit gilt ein Name,
/// dessen Prüfung nie geantwortet hat, als absendbar. Das ist die Absicht: kein
/// Netz darf keine Registrierung verhindern, und die Eindeutigkeit entscheidet
/// am Ende ohnehin der Eindeutigkeitsindex der Datenbank, nicht der Client.
class UsernameCheckNotifier extends Notifier<UsernameStatus> {
  /// Die Syntaxregel der Quelle, unverändert.
  ///
  /// Zwei bis zwanzig Zeichen aus `a-z`, `A-Z`, `0-9` und `_`. Keine Umlaute,
  /// kein Bindestrich, kein Punkt. Das Feld begrenzt zusätzlich auf zwanzig
  /// Zeichen (`maxLength`), die Obergrenze wird also normalerweise nicht
  /// verletzt.
  static final RegExp syntax = RegExp(r'^[a-zA-Z0-9_]{2,20}$');

  /// Die Verzögerung vor der Prüfung, `setTimeout(..., 500)`.
  ///
  /// Sie ist der Grund, warum die Prüfung nicht bei jedem Tastendruck ins Netz
  /// geht. Wer sie auf null setzt, macht aus einem Namen mit zehn Zeichen zehn
  /// Anfragen; der Test dagegen prüft beide Seiten (vorher keine Anfrage,
  /// danach genau eine).
  static const Duration checkDelay = Duration(milliseconds: 500);

  Timer? _timer;

  /// Zählt jede Eingabe. Eine Antwort mit veralteter Nummer wird verworfen.
  ///
  /// Der [Timer] allein genügt nicht: er deckt nur die Wartezeit ab. Ist die
  /// Anfrage schon unterwegs, hilft kein Abbrechen mehr, und ohne diesen Zähler
  /// entstünde derselbe Wettlauf noch einmal, nur ein Stück später.
  int _generation = 0;

  @override
  UsernameStatus build() {
    ref.onDispose(_cancelPendingCheck);
    return UsernameStatus.idle;
  }

  /// Der Nutzer hat das Feld geändert.
  ///
  /// Reihenfolge, und sie ist bedeutungstragend: **erst** den geplanten Check
  /// abbrechen, dann entscheiden. Siehe die Begründung in der Klassendoku.
  void onChanged(String value) {
    _cancelPendingCheck();
    if (value.isEmpty) {
      state = UsernameStatus.idle;
      return;
    }
    if (!syntax.hasMatch(value)) {
      state = UsernameStatus.invalid;
      return;
    }
    state = UsernameStatus.checking;
    final generation = _generation;
    _timer = Timer(checkDelay, () {
      // `unawaited` und nicht `reportDetached`: [_check] trägt keinen
      // Schreibvorgang und legt jeden Fehlschlag selbst in seinen Zustand.
      unawaited(_check(value, generation));
    });
  }

  /// Bricht Wartezeit **und** laufende Antwort ab.
  void _cancelPendingCheck() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }

  Future<void> _check(String value, int generation) async {
    final bool taken;
    try {
      taken = await ref.read(authRepositoryProvider).checkUsernameTaken(value);
    } catch (_) {
      // Wie die Quelle: ein Fehlschlag der Prüfung ist kein Fehler des Nutzers.
      // Der Fehlschlag wird nicht gemeldet, weil er beim Registrieren erneut
      // auftritt und dort sichtbar wird.
      _apply(UsernameStatus.idle, generation);
      return;
    }
    _apply(taken ? UsernameStatus.taken : UsernameStatus.ok, generation);
  }

  /// Setzt [next], solange [generation] noch die aktuelle Eingabe ist.
  void _apply(UsernameStatus next, int generation) {
    if (!ref.mounted || generation != _generation) {
      return;
    }
    state = next;
  }
}

/// Ob mit diesem Zustand abgeschickt werden darf,
/// `screen-auth.jsx:614` (`usernameStatus === 'taken' || ... 'invalid' || ...
/// 'checking'`).
///
/// [UsernameStatus.idle] steht **nicht** in der Liste der Quelle und blockiert
/// deshalb auch hier nicht. Praktische Folge: ein Name, dessen Prüfung
/// gescheitert ist, geht durch. Siehe die Begründung in
/// [UsernameCheckNotifier].
bool blocksSignup(UsernameStatus status) => switch (status) {
  UsernameStatus.taken ||
  UsernameStatus.invalid ||
  UsernameStatus.checking => true,
  UsernameStatus.idle || UsernameStatus.ok => false,
};
