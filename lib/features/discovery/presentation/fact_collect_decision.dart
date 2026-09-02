/// Was ein Tipp auf einen Fakt-Ballon auslöst: sammeln oder nur die
/// Mini-Vorschau.
///
/// ## Die Regel, und warum sie hart erkämpft ist
///
/// `screen-map.jsx:2129-2145`. Innerhalb des Sammelradius wird gesammelt,
/// **alles andere zeigt nur den Mini-Teaser, und „alles andere" schließt
/// „keine Ortung" ausdrücklich ein**. Der Kommentar an der Fundstelle nennt
/// den Fehler, der dazu geführt hat, im Wortlaut: „ohne GPS NIE die
/// Fakt-Detail-Seite direkt oeffnen. Sonst koennte man durch Antippen aus
/// 1000 km Entfernung einen Fakt ‚lesen'". Vorher stand dort ein
/// `!dist || dist <= 50`, und der `!dist`-Zweig hat genau dieses Loch
/// geöffnet: ein Nutzer in Italien bekam einen Münchner Fakt vollständig
/// angezeigt.
///
/// Das ist keine Feinheit am Rand, sondern die Vor-Ort-Mechanik der ganzen
/// App. Wer diese Bedingung beim Aufräumen entfernt, weil sie wie eine
/// überflüssige Null-Prüfung aussieht, macht die App vom Sofa aus
/// durchlesbar. Dieselbe Begründung steht ein zweites Mal an `FactRoute` in
/// `lib/app/routing/app_routes.dart`, und zwar mit Absicht: die Route ist die
/// andere Stelle, an der man sie brechen könnte.
///
/// ## Der Vergleich ist `<` und nicht `<=`
///
/// Die Quelle widerspricht sich an derselben Zahl, gemessen am 02.09.2026 und
/// als E-67 aufgenommen: `dist < COIN_RADIUS` bei der Münz-Animation
/// (`:2249`, die Konstante heißt dort „in-range threshold"), `distM < 150` am
/// Nächster-Fakt-Knopf (`:3775`, `:3781`), aber `dist <= 150` beim Tipp auf
/// einen Ballon (`:2131`). Zwei von drei Fundstellen und der Name der
/// Konstante sagen „ausschließend", und
/// [factProximityRadiusInMeters] hält seit Schritt 17 fest, dass 150 Meter
/// **außen** liegen. Ein eigener Radius für den Tipp wäre eine vierte
/// Wahrheit.
///
/// **Der Unterschied trifft nur den Fall „genau 150,0 Meter"** und ist
/// deshalb praktisch nie zu sehen. Er steht hier trotzdem, weil er sonst beim
/// nächsten Lesen wie Schlamperei aussieht und jemand ihn „korrigiert".
///
/// ## Was hier bewusst fehlt
///
/// **Der Tour-Zweig.** Vor der Entfernungsprüfung fragt die Quelle
/// (`:2120-2127`), ob der Fakt ein noch nicht gesammelter Stopp der laufenden
/// Tour ist, und zeigt dann statt allem anderen die Hinweis-Tafel. Das gehört
/// zu Phase 6 (`features/tours`), hat heute keinen Zustand, an dem es hängen
/// könnte, und wäre hier Vorrat (ADR-002). Kommt er, ist er ein dritter
/// [FactTapAction] und keine Änderung an dieser Regel.
///
/// **Der gesammelte Zustand.** Ein bereits gesammelter Fakt bekommt in der
/// Quelle dasselbe Verhalten wie jeder andere; nur die Tour-Abfrage darüber
/// liest ihn. Es gibt im Neubau ohnehin keine Quelle dafür, siehe
/// `fact_overlay.dart`.
///
/// ## Warum die Regel in `discovery` liegt und nicht in `collection`
///
/// `lib/features/README.md` weist `discovery` ausdrücklich **nicht** die
/// „Sammel-Regeln" zu, und `collection` besitzt die „Sammel-Berechtigung".
/// Nach dem Buchstaben gehörte diese Datei also dorthin. Sie liegt trotzdem
/// hier, aus zwei nachprüfbaren Gründen:
///
/// 1. **Sie beantwortet keine Berechtigungsfrage, sondern eine
///    Interaktionsfrage:** was tut ein Tipp auf die Karte. Ob ein Sammeln
///    wirklich gutgeschrieben wird, entscheidet der Server
///    (`docs/engineering/security.md`), und das ist der Teil, der
///    `collection` gehört und den es noch nicht gibt.
/// 2. **Der Radius wäre von dort nicht erreichbar.** Er steht in
///    `fact_proximity.dart` unter `discovery/presentation/`, und Regel 8 der
///    `dependency-rules.md` verbietet jedem anderen Feature genau dieses
///    Verzeichnis. Eine Kopie der Zahl in `collection` wäre die vierte
///    Wahrheit, die E-67 gerade beseitigt hat.
///
/// Sobald `features/collection` mit einem Server-Vertrag entsteht, ist der
/// richtige Schnitt: die **Buchung** dorthin, diese Regel bleibt hier, und der
/// Radius zieht in einen gemeinsamen Vertrag um. Der Auslöser ist der erste
/// Verbraucher außerhalb von `discovery`.
library;

import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Was ein Tipp auf einen Fakt auslöst.
enum FactTapAction {
  /// Der Nutzer steht nah genug: sammeln, mit Münzflug und Fakt-Blatt.
  collect,

  /// Zu weit weg oder ohne Ortung: nur die Mini-Vorschau, **nie** das Blatt.
  teaser,
}

/// Das Ergebnis der Regel: was passiert, und wie weit es war.
final class FactTapDecision {
  /// Erzeugt eine Entscheidung.
  const FactTapDecision({required this.action, required this.distanceInMeters});

  /// Sammeln oder Vorschau.
  final FactTapAction action;

  /// Die Entfernung zum Fakt in Metern, oder `null` **ohne Ortung**.
  ///
  /// `null` ist nicht dasselbe wie „sehr weit": die Vorschau zeigt dafür eine
  /// eigene Zeile („Standort unbekannt") und keine Zahl, genau wie
  /// `screen-map.jsx:3856-3858`.
  final double? distanceInMeters;

  /// Kurzform für den Verbraucher, der nur die Verzweigung braucht.
  bool get collects => action == FactTapAction.collect;

  @override
  String toString() =>
      // Ohne die Entfernung, siehe `FactProximityPoint.toString`: zusammen
      // mit der öffentlich bekannten Fakt-Koordinate legt sie den
      // Aufenthaltsort des Nutzers fest, und das verbietet
      // `docs/engineering/security.md` §6.
      'FactTapDecision(${action.name}, '
      '${distanceInMeters == null ? 'ohne Ortung' : 'mit Ortung'})';
}

/// Ob bei [distanceInMeters] gesammelt wird.
///
/// ## Warum das eine eigene Funktion ist und keine Zeile in [decideFactTap]
///
/// **Weil der Fall „genau 150,0 Meter" über Koordinaten nicht erreichbar
/// ist, und das ist gemessen.** Eine Bisektion über die Breitendifferenz
/// zwischen zwei Punkten auf demselben Längengrad kommt bei
/// `MapPosition.distanceInMetersTo` auf 149,99999999998155 und springt von
/// dort über 150 hinweg; `2 * R * asin(sqrt(a))` hat an dieser Stelle keine
/// feinere Auflösung. `fact_proximity_test.dart` hält dieselbe Beobachtung
/// fest und **zieht daraus den Schluss, den Rand nicht zu prüfen** („die
/// Grenze selbst steht als `>=` im Code und ist bei der Konstanten
/// begründet").
///
/// Damit wäre `<` von `<=` durch keinen Test unterscheidbar, und E-67 ist
/// genau die Entscheidung zwischen diesen beiden Zeichen. Eine Zusicherung,
/// die die eigene Entscheidung nicht sehen kann, ist keine. Als eigene
/// Funktion mit einer Zahl statt zwei Koordinaten ist der Rand prüfbar, und
/// er ist es exakt.
bool factTapCollectsAt(double distanceInMeters) =>
    distanceInMeters < factProximityRadiusInMeters;

/// Die Regel selbst, `screen-map.jsx:2129-2145`.
///
/// [user] ist `null`, solange keine Ortung vorliegt, und **dann wird nie
/// gesammelt**. Siehe den Kopf dieser Datei; das ist der Kern der Regel und
/// kein Randfall.
FactTapDecision decideFactTap({
  required MapPosition? user,
  required MapPosition fact,
}) {
  if (user == null) {
    return const FactTapDecision(
      action: FactTapAction.teaser,
      distanceInMeters: null,
    );
  }
  final double distance = user.distanceInMetersTo(fact);
  return FactTapDecision(
    action: factTapCollectsAt(distance)
        ? FactTapAction.collect
        : FactTapAction.teaser,
    distanceInMeters: distance,
  );
}
