import 'dart:async';

import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/features/challenges/application/active_hunt_providers.dart';
import 'package:fact_app/features/challenges/application/hunt_hotspot.dart';
import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/application/hunt_route_generator.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:fact_app/features/challenges/application/hunt_start_options.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/challenges/presentation/notifiers/hunt_start_providers.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_setup_view.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_toast.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_pause_view.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_result_view.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_start_point_view.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Challenge-Reiter, `02_Frontend/app/screen-challenge.jsx`.
///
/// Zeigt den Assistenten und, nachdem er zu Ende bedient ist, den
/// Startpunkt-Picker. Beides ist **ein** Bildschirm mit Zustand und keine
/// zweite Route: die Quelle schaltet `view` um (`:4153`, `:4319-4329`,
/// `:4423-4447`), und E-25 hat die öffentliche Routenfläche auf sieben Pfade
/// festgelegt.
///
/// ## Die laufende Jagd geht vor Assistent und Picker (`:4292-4317`)
///
/// `huntRunProvider` entscheidet, was dieser Reiter zeigt: läuft keine Jagd,
/// bleibt alles wie zuvor (Assistent oder Picker über [_choice]); läuft eine
/// und ist sie fertig ([HuntRun.isFinished]), zeigt der Reiter [HuntResultView];
/// läuft sie noch, zeigt er [HuntPauseView]. Diese Prüfung steht **vor** der
/// Fallunterscheidung nach [_choice] und nicht daneben, exakt wie die Quelle
/// mit ihrem frühen `if (activeHunt)`.
///
/// **Warum `huntRunProvider` und nicht `activeHuntProvider` (Entscheidung
/// 1 aus Schritt 39).** `activeHuntProvider` liefert auch eine aus dem
/// Speicher wiederhergestellte Jagd, und die trägt weder Stationszustände
/// noch Punkte, also genau das, was diese beiden Bildschirme brauchen. Die
/// Folge: **eine Jagd, die einen App-Neustart überlebt hat, ist auf der
/// Karte als Pille sichtbar, in diesem Reiter aber nicht.** Dort steht dann
/// wieder der Assistent. Das ist keine Nachlässigkeit dieses Schritts,
/// sondern die schon dokumentierte Lücke aus `HuntRunNotifier.build`
/// (`active_hunt_providers.dart`), die hier zum ersten Mal sichtbar wird.
/// Ein abgespeckter Pausebildschirm für genau diesen Fall ist bewusst nicht
/// gebaut.
///
/// ## Die zwei Gruppen-Rückrufe sind weiterhin leer
///
/// „Gruppe" und „Mit Code beitreten" führen in den Koop-Unterbau, von dem im
/// Neubau nichts existiert: kein Repository, keine RPC-Anbindung, keine
/// Domäne. Das ist Schritt 40. Der dritte, „Starten", führt seit diesem
/// Schritt in den Picker, womit sich der Teil von E-47 erledigt, der den
/// Startknopf betraf.
class ChallengesPage extends ConsumerStatefulWidget {
  /// Erzeugt die Seite.
  const ChallengesPage({super.key});

  /// Die Stadt, für die Hotspots und Fakten gesucht werden.
  ///
  /// **Ein Platzhalter, kein Architekturentscheid**, wortgleich zu
  /// `MapPage.placeholderCityName` und aus demselben Grund: die
  /// Stadt-Identität gehört `features/city`, das es noch nicht gibt.
  /// Mehrstädtigkeit bleibt erhalten: der Wert geht als [FactCity] in
  /// [huntHotspotsForCity] und in den Faktenfilter, beides ist auf einen
  /// beliebigen Namen umstellbar.
  ///
  /// **Und eine bewusste Abweichung von der Quelle, nicht ihre Fortsetzung.**
  /// `screen-challenge.jsx:4426` schreibt zwar `currentCity || 'München'`,
  /// aber das gehört zum **Setup**-Bildschirm, nicht zum Picker. Der Picker
  /// selbst bekommt seine Stadt in `:4443` mit `city={currentCity || ''}`:
  /// ohne Stadt zeigt die Quelle dort ihren **Leer-Zustand** und keine
  /// Münchner Hotspots. Ohne `features/city` fällt dieser Bildschirm hier
  /// trotzdem auf München zurück, weil ein Leer-Zustand beim allerersten
  /// Öffnen schlechter testbar und schlechter vorzeigbar wäre als ein
  /// Platzhalter mit echtem Inhalt; das ist Parität mit dem *Setup*-Zweig
  /// der Quelle und keine mit dem *Picker*-Zweig.
  ///
  /// Er steht hier und nicht in `MapPage`, weil Regel 8 diesem Feature den
  /// Import aus `discovery/presentation` verbietet. Zwei Platzhalter mit
  /// demselben Wert sind der sichtbare Preis dafür, dass `features/city`
  /// fehlt; wer es baut, löscht beide.
  static const String placeholderCityName = 'München';

  /// Die Meldung, für Tests.
  static const Key toastKey = Key('challenges-toast');

  @override
  ConsumerState<ChallengesPage> createState() => _ChallengesPageState();
}

/// Was der Assistent an den Picker weiterreicht.
///
/// `handleSetupStart` merkt sich in der Quelle dieselben Werte im Zustand des
/// Bildschirms (`:4319-4321`) und benutzt sie erst in `handleHotspotPick`
/// (`:4331-4358`). Der Modus fehlt, weil dieser Assistent nur den Solo-Pfad
/// zu Ende führt, und `routeKey` fehlt mit den kuratierten Themenrouten.
typedef _HuntChoice = ({
  PuzzleDifficulty difficulty,
  HuntDuration duration,
  List<String> genres,
});

class _ChallengesPageState extends ConsumerState<ChallengesPage> {
  /// `view`, `:4153`. `null` heißt Assistent, sonst Picker.
  _HuntChoice? _choice;

  /// `chalToast`, `:4163`.
  String? _toast;

  Timer? _toastTimer;

  @override
  void dispose() {
    // Ohne das überlebt der Zeitgeber den Baum, und im Test heißt das
    // „A Timer is still pending".
    _toastTimer?.cancel();
    super.dispose();
  }

  /// `showChalToast`, `:4164-4167`.
  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(ChallengeToast.visibleFor, () {
      if (mounted) {
        setState(() => _toast = null);
      }
    });
  }

  /// `handleSetupStart` für den Solo-Pfad, `:4319-4329`.
  void _onSetupDone(
    PuzzleDifficulty difficulty,
    HuntDuration duration,
    List<String> genreCodes,
  ) {
    setState(() {
      _choice = (
        difficulty: difficulty,
        duration: duration,
        genres: genreCodes,
      );
    });
  }

  /// `handleHotspotPick`, `:4331-4358`.
  ///
  /// ## Der Empfänger ist jetzt eingehängt
  ///
  /// Die Quelle reicht die erzeugte Jagd mit `onHuntStart(generated)`
  /// (`:4354`) eine Ebene höher, und der Kartenbildschirm spielt sie.
  /// **D-16 war offen** (wie `discovery` an den Jagdzustand kommt) **und ist
  /// beantwortet**: ADR-007 legt den Vertrag fest, ADR-009 die
  /// Gruppen-Erweiterung, und `huntRunProvider` (`active_hunt_providers.dart`,
  /// Schritt 36) ist der Besitzer des Zustands. Diese Methode hängt den
  /// Empfänger deshalb an, statt hier zu enden: [HuntRunNotifier.start] setzt
  /// den Lauf, `ChallengesPage.build` sieht ihn über `huntRunProvider` und
  /// zeigt ab dem nächsten Bild [HuntPauseView] statt des Pickers, siehe den
  /// Klassenkopf.
  ///
  /// Was **schon vorher** gebaut war und unverändert bleibt: der Fehlschlag.
  /// Findet der Generator keine einzige Station, zeigt die Quelle eine kurze
  /// Meldung und schickt zurück in den Assistenten (`:4347-4352`).
  void _startHunt(_HuntChoice choice, MapPosition point, List<Fact> facts) {
    final HuntPlan? plan = generateHuntRoute(
      facts: _factsOfCity(facts),
      difficulty: choice.difficulty,
      duration: choice.duration,
      startNear: point,
      genres: choice.genres,
    );

    if (plan == null) {
      // `:4347`: die Quelle prüft `!generated || !generated.stops ||
      // generated.stops.length === 0`. [generateHuntRoute] fasst alle drei zu
      // `null` zusammen; eine **zu kurze** Jagd ist ausdrücklich kein
      // Fehlschlag, weder dort noch hier.
      _showToast(
        ref.read(appStringsProvider).text('challenge.hotspot.noFacts'),
      );
      setState(() => _choice = null);
      return;
    }

    // `unawaited` und keine `async`-Methode: `HuntRunNotifier._apply` setzt
    // den Zustand **synchron**, bevor sie auf den Schreibvorgang wartet
    // (siehe dort), also sieht `huntRunProvider` den neuen Lauf schon vor dem
    // nächsten Frame, ganz ohne dass hier auf das zurückgegebene `Future`
    // gewartet wird. Diese Methode hat nach dem Setzen nichts mehr zu tun,
    // ein Fehlschlag beim Speichern behandelt `_apply` bereits selbst
    // (verwerfen statt reparieren); ein `await` hier würde also nur die
    // Rückkehr aus einem `VoidCallback` verzögern, ohne das Ergebnis zu
    // nutzen.
    unawaited(ref.read(huntRunProvider.notifier).start(plan));
  }

  /// Der Kandidatenpool des Generators: die Fakten dieser Stadt.
  ///
  /// [generateHuntRoute] verlangt die Liste **bereits auf die Stadt
  /// eingegrenzt** und entscheidet selbst nichts über Stadt-Identität, siehe
  /// seinen Kopf. Der Vergleich läuft über [FactCity.matchesSlug], also über
  /// dieselbe Normalisierung wie `FactQuery.citySlug` und wie
  /// [huntHotspotsForCity]. E-11 kostet damit auch hier nur eine Zeile.
  ///
  /// **Ein Fakt ohne Stadt fällt heraus.** Die Spalte `facts.city` darf `NULL`
  /// sein, und die Quelle rät in diesem Fall mit `detectCity` die nächste
  /// Pilotstadt (`hunt-generator.jsx:110-121`). Dieses Raten ist genau der
  /// Bruch, den E-11 beschreibt, und wird hier nicht nachgebaut: eine erratene
  /// Stadt in einem Kandidatenpool ist schlechter als ein Fakt weniger.
  List<Fact> _factsOfCity(List<Fact> facts) {
    final FactCity city = const FactCity(ChallengesPage.placeholderCityName);
    return facts
        .where((Fact fact) => fact.city?.matchesSlug(city.displayName) ?? false)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final HuntRun? run = ref.watch(huntRunProvider);
    final _HuntChoice? choice = _choice;
    final String? toast = _toast;

    return Stack(
      children: <Widget>[
        // Die Meldung liegt über allen drei Zweigen, `:4163-4167` und der
        // ganze `<Stack>` der Quelle, unverändert seit Schritt 35.
        if (run != null && run.isFinished)
          HuntResultView(run: run, onClose: _endHunt)
        else if (run != null)
          HuntPauseView(
            run: run,
            cityName: ChallengesPage.placeholderCityName,
            onBackToMap: () => const MapRoute().go(context),
            onAbort: _endHunt,
          )
        else if (choice == null)
          _setup()
        else
          _picker(choice),
        if (toast != null)
          Positioned(
            top: ChallengeToast.topOffset,
            left: ChallengeToast.horizontalInset,
            right: ChallengeToast.horizontalInset,
            child: Center(
              child: ChallengeToast(
                key: ChallengesPage.toastKey,
                message: toast,
              ),
            ),
          ),
      ],
    );
  }

  /// `onHuntAbort`, `:4300` und `:4312`: die Quelle ruft für „Ja, abbrechen"
  /// und für „Fertig" denselben Rückruf, ohne zwischen Abbruch und
  /// planmäßigem Ende zu unterscheiden. [HuntRunNotifier.end] räumt in beiden
  /// Fällen dasselbe auf: Zustand löschen, Speicher leeren.
  void _endHunt() => ref.read(huntRunProvider.notifier).end();

  Widget _setup() {
    return ChallengeSetupView(
      onStart: _onSetupDone,
      onGroupSelected: () {
        // Der Gruppenpfad braucht Koop-Sitzungen in Supabase.
      },
      onJoinRequested: () {
        // Der Beitritt mit Code prüft ihn gegen den Server.
      },
    );
  }

  /// `view === 'hotspot'`, `:4441-4446`.
  ///
  /// Beide Eingaben sind bewusst **weich**: solange die Fakten laden, wird mit
  /// einer leeren Liste gerechnet, und ohne Ortung fehlt „Hier wo ich bin".
  /// Genau so verhält sich die Quelle, deren `window.FACTS` beim ersten
  /// Rendern ebenfalls leer sein kann und deren `userPosition` `undefined`
  /// ist, bis die erste Ortung eintrifft. Ein Ladebildschirm davor wäre neues
  /// Verhalten.
  ///
  /// Ein Fehlschlag beim Laden führt damit auf dieselbe Anzeige wie „noch
  /// nichts geladen". Sichtbar wird er trotzdem, nur eine Stufe später: ohne
  /// Fakten liefert der Generator `null`, und dann steht die Meldung da.
  Widget _picker(_HuntChoice choice) {
    final List<Fact> facts =
        ref.watch(allFactsProvider).value ?? const <Fact>[];
    final MapPosition? position = ref.watch(huntUserPositionProvider).value;

    return HuntStartPointView(
      options: huntStartOptions(
        hotspots: huntHotspotsForCity(
          const FactCity(ChallengesPage.placeholderCityName),
        ),
        facts: facts,
        userPosition: position,
      ),
      onPick: (MapPosition point) => _startHunt(choice, point, facts),
      onBack: () => setState(() => _choice = null),
    );
  }
}
