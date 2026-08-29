/// Die zuletzt brauchbare Ortung des Nutzers, als Zustand des
/// Kartenbildschirms.
///
/// ## Was hier passiert und was ausdrücklich nicht
///
/// Hier passiert **eine** Entscheidung: ist diese Ortung genau genug, um
/// benutzt zu werden. Alles Weitere, also ob daraus ein Sky-Fall oder ein
/// GPS-Folgen wird, ob die Karte überhaupt schon lebt und ob der eigene
/// Tab-Zweig sichtbar ist, entscheidet der Bildschirm in
/// `pages/map_page.dart`. Der Grund ist keine Geschmacksfrage: der Notifier
/// hat keinen `BuildContext` und kann deshalb nicht wissen, ob sein Zweig
/// gerade angezeigt wird, und ein Notifier, der Kameraabsichten abgibt, wäre
/// nur zusammen mit einem Karten-Host prüfbar.
///
/// ## Der Strom läuft auch im unsichtbaren Tab weiter
///
/// Der Kartenbildschirm gibt keine Kameraabsicht ab, solange sein Zweig
/// inaktiv ist. **Dieser Strom läuft trotzdem**, und das ist Absicht: er trägt
/// später den Audio-Beacon (`02_Frontend/app/screen-map.jsx:2692` und folgende)
/// und das Geofencing, und ein Strom, der beim Tabwechsel abreißt, bricht
/// beide. Beendet wird er erst, wenn der Provider entsorgt wird.
library;

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Was der Kartenbildschirm über den Standort weiß.
///
/// ## Bewusst ohne Wertgleichheit
///
/// Zwei Ortungen an derselben Stelle, eine Sekunde auseinander, sind **zwei
/// Ereignisse**. Riverpod benachrichtigt seine Zuhörer nur, wenn
/// `previous != next` (`riverpod-3.4.2`,
/// `ProviderElement.defaultUpdateShouldNotify`); mit einem `==` über die
/// Felder verschwände die zweite Ortung lautlos, und mit ihr der Anlass, die
/// Kamera nachzuziehen. Ob eine Ortung etwas bewirkt, entscheiden Totzone und
/// Mindestpause im Karten-Gate, nicht der Vergleichsoperator hier. Dieselbe
/// Begründung wie bei `MapCameraIntent`, siehe dort „Warum keine Absicht
/// Wertgleichheit hat".
///
/// [acceptedFixes] gibt es genau deshalb: es macht „eine neue Ortung ist
/// angekommen" auch dann prüfbar, wenn sie zufällig dieselben Koordinaten
/// trägt wie die vorige.
@immutable
final class UserLocationState {
  /// Erzeugt einen Zustand. Der Startzustand ist „noch keine Ortung".
  const UserLocationState({this.fix, this.acceptedFixes = 0});

  /// Die zuletzt **angenommene** Ortung, oder `null`, solange es keine gibt.
  ///
  /// Angenommen heißt: sie hat den Genauigkeitsfilter passiert. Eine zu
  /// ungenaue Ortung ersetzt diesen Wert nicht und lässt ihn auch nicht auf
  /// `null` zurückfallen.
  final DevicePosition? fix;

  /// Wie viele Ortungen angenommen wurden. `1` ist die erste.
  final int acceptedFixes;
}

/// Der Standort des Nutzers auf dem Kartenbildschirm.
final userLocationProvider =
    NotifierProvider<UserLocationNotifier, UserLocationState>(
      UserLocationNotifier.new,
    );

/// Besitzer des Standorts.
class UserLocationNotifier extends Notifier<UserLocationState> {
  /// Name des Diagnose-Ereignisses für einen Fehler auf dem Ortungsstrom.
  static const String streamErrorEvent = 'discovery.user_location.stream_error';

  @override
  UserLocationState build() {
    final subscription = ref
        .watch(locationServiceProvider)
        .positionUpdates()
        .listen(_apply, onError: _reportStreamError);
    ref.onDispose(subscription.cancel);
    return const UserLocationState();
  }

  /// Nimmt eine Ortung an oder verwirft sie.
  ///
  /// **Der Filter ist Parität und keine Vorsicht.** `screen-map.jsx:2744`
  /// verwirft jede Ortung mit `accuracy > 35`, und der Kommentar darüber nennt
  /// den Grund: sonst springt die Karte während der Aufwärmfolge Funkzelle,
  /// WLAN, GPS. Ohne ihn landet der Sky-Fall auf einer groben Ortung und die
  /// Karte fährt danach weg.
  ///
  /// Die verworfene Ortung wird **nicht** gemeldet. Beim Kaltstart ist sie der
  /// Normalfall, und ein Diagnose-Ereignis, das im Normalbetrieb im Sekundentakt
  /// feuert, liest nach der dritten Woche niemand mehr.
  void _apply(DevicePosition position) {
    // Dieselbe Prüfung und derselbe Grund wie in `AuthSessionNotifier._apply`:
    // der Strom kommt von außen, seine Zustellgarantien sind nicht unsere, und
    // eine bereits eingereihte Ausgabe nach dem Entsorgen ließe `state =` mit
    // „Cannot use the Ref ... after it has been disposed" werfen.
    if (!ref.mounted) {
      return;
    }
    if (!isAccurateEnough(position)) {
      return;
    }
    state = UserLocationState(
      fix: position,
      acceptedFixes: state.acceptedFixes + 1,
    );
  }

  /// Ein Fehler auf dem Strom nimmt die letzte Ortung **nicht** zurück.
  ///
  /// Dieselbe Regel wie bei der Sitzung: der letzte bekannte Stand bleibt
  /// gültig. Die Quelle verhält sich genauso, ihr Fehlerzweig
  /// (`screen-map.jsx:2747`) blendet nur die Suchanzeige aus und lässt
  /// `posRef` stehen.
  ///
  /// Gemeldet wird ausschließlich der **Typname**. Die Meldung des Vendors kann
  /// Interna tragen, und eine Ortungsmeldung kann Koordinaten tragen, was
  /// `docs/engineering/security.md` §6 im Log verbietet.
  void _reportStreamError(Object error, StackTrace stackTrace) {
    if (!ref.mounted) {
      return;
    }
    ref
        .read(diagnosticSinkProvider)
        .report(
          DiagnosticEvent(streamErrorEvent, <String, String>{
            'type': error.runtimeType.toString(),
          }),
        );
  }
}
