import 'package:fact_app/app/routing/app_routes.dart';

/// Die zentrale Weiche des Routers als reine Funktion (ADR-004:
/// "Auth/onboarding redirects are centralized").
///
/// Absichtlich ohne `BuildContext` und ohne `Ref`: so ist jede Regel ohne
/// Widget-Baum und ohne Provider-Container prüfbar, und die Weiche kann nicht
/// unbemerkt anfangen, selbst Zustand zu lesen. Wer sie aufruft, liest den
/// Zustand vorher, siehe `app_router.dart`.
///
/// ## Regeln
///
/// | Zustand | Ziel | Ergebnis |
/// |---|---|---|
/// | Erstlauf offen **und** abgemeldet | nicht `/splash`, `/login`, `/signup` | `/splash` |
/// | sonst | `/splash` | `/map` |
/// | sonst | beliebig | `null` (durchlassen) |
///
/// ## Warum der Anmeldezustand mitzählt
///
/// Weil die Bedingung der Quelle zwei Hälften hat. `app.jsx:69` lautet
/// vollständig:
///
/// ```js
/// !localStorage.getItem('fact_has_launched') && !Storage.getUser() ? 'onboarding' : 'map'
/// ```
///
/// Ein **angemeldeter** Nutzer sieht also keinen Startbildschirm, auch wenn die
/// Merkung fehlt. Genau dieser Fall kann eintreten, weil die PWA das Flag erst
/// als Nachbesserung im Anmeldeweg setzt (`app.jsx:525-527`). Bis Schritt 8 war
/// nur die erste Hälfte umgesetzt, weil es keinen Sitzungszustand gab; mit
/// Schritt 9 gibt es einen.
///
/// ## Warum `/login` und `/signup` beim offenen Erstlauf frei sind
///
/// Weil zwei der drei Ausgänge des Startbildschirms sonst ins Leere führen. Die
/// Erstlauf-Merkung wird nur auf dem Gast-Weg gesetzt, Anmeldung und
/// Registrierung setzen sie erst bei Erfolg (Schritt 9 und 10). Ohne die
/// Ausnahme wäre `hasLaunched` beim Tippen also noch `false`, die Weiche schickte
/// den Nutzer sofort zurück, und beide Knöpfe täten sichtbar nichts.
///
/// **Keine Endlosschleife.** Eine frühere Fassung dieses Kommentars behauptete
/// das, und es ist nachgeprüft falsch: `/splash` ist ein Fixpunkt der Weiche,
/// go_router leitet genau einmal um und ist fertig. Der Schaden ohne die
/// Ausnahme ist ein toter Knopf, nicht ein Absturz. Das ist deshalb wichtig,
/// weil ein toter Knopf leiser ausfällt als eine Ausnahme: er fällt niemandem
/// auf, der nicht danach sucht.
///
/// Dass `/splash` ein Fixpunkt ist, ist per Test zugesichert: `resolveRedirect`
/// auf sein eigenes Ergebnis angewendet gibt immer `null`.
///
/// [location] ist `GoRouterState.matchedLocation`, also der Pfad ohne
/// Query-Parameter. Verglichen wird gegen die Pfade der typisierten Routen,
/// nicht gegen Literale.
///
/// Diese Weiche ist Bequemlichkeit für den Nutzer, **keine Sicherheitsgrenze**.
/// Der mobile Client ist unvertraut, Autorisierung ist serverseitig.
String? resolveRedirect({
  required bool hasLaunched,
  required bool isSignedIn,
  required String location,
}) {
  if (!hasLaunched && !isSignedIn) {
    return _isFirstLaunchPath(location) ? null : const SplashRoute().location;
  }
  if (location == const SplashRoute().location) {
    return const MapRoute().location;
  }
  return null;
}

/// Pfade, die beim offenen Erstlauf erreichbar bleiben.
bool _isFirstLaunchPath(String location) =>
    location == const SplashRoute().location ||
    location == const LoginRoute().location ||
    location == const SignupRoute().location;
