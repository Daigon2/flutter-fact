# Neubau-Status

Fortschritt des Flutter-Neubaus. Diese Datei ist die dauerhafte Quelle, nicht der
Gesprächsverlauf. Wer nach einem Kontextverlust weiterarbeitet, liest zuerst hier.

**Reihenfolge und Inhalt der 50 Schritte** stehen in `08_Flutter/REBUILD_PLAN.md`
im Lese-Repo, die Anforderungen pro Screen in
`06_Planung/specs/2026-07-23-flutter-rebuild-parity-spec.md`. Beide sind dort
nicht in Git eingecheckt und existieren nur lokal.

**Achtung:** Der REBUILD_PLAN gibt die Reihenfolge vor, nicht die Architektur.
Sein Grundprinzip 4 nennt `provider` und ein globales `AppState`. Das widerspricht
ADR-003 und ADR-005 und gilt hier nicht. Die nachgewiesenen Sachfehler des
Plans und der Parity-Spec stehen unten unter „Korrekturen an den
Quelldokumenten". Es sind inzwischen zwölf, und **auch Kommentare in der PWA
selbst** sind darunter.

## Legende

`[x]` fertig und verifiziert · `[~]` in Arbeit · `[ ]` offen · `[!]` blockiert
durch eine offene Entscheidung

## Phase 0, Fundament

- [x] **1. Projekt-Gerüst.** `flutter create` mit Android und iOS, Store-IDs aus
  dem alten Port übernommen (`de.factapp.fact_app`, `de.factapp.factApp`), damit
  der Neubau im Store dieselbe App bleibt. Feature-Ordner nach Domain-Map,
  Ownership in `lib/features/README.md`.
- [x] **2. Pakete festgenagelt.** Abweichungen von der Planliste siehe
  „Paket-Abweichungen" unten.
- [x] **3. Design-Tokens.** `lib/app/theme/`, Werte aus `styles.css`, per Test
  festgenagelt. Schriftgrößen und Schatten bewusst nicht global, siehe
  „Bewusste Auslassungen".
- [x] **4. i18n-Fundament.** Generiert aus `translations.jsx` und
  `audio-strings.jsx`, kein ARB und kein `gen_l10n`, weil die punktierten
  PWA-Schlüssel sonst verloren gehen. **716 Schlüssel je Sprache**, DE und EN
  deckungsgleich. Generator unter `tool/generate_i18n.dart` mit `--check` für
  Drift-Erkennung. 47 Tests.
- [x] **5. Datenmodell und Supabase-Client.** Defensives `Fact`-Mapping. Fünf
  bekannte Cast-Fallen, siehe „Datenvertrag". (Das Kästchen stand bis zum
  27.08.2026 fälschlich auf offen, obwohl der Schritt laut Protokoll in
  `HANDOFF.md` und laut `test/features/facts/` fertig war.)
- [x] **6. App-Shell.** Typisierte Routen über `go_router_builder`, vier Tabs
  aus `chrome.jsx:55-60` belegt, `StatefulShellRoute` für unabhängige Stapel,
  schwebende Tab-Leiste mit den Werten der Quelle, reservierter
  Mini-Player-Platz, Supabase im Start verdrahtet. Der Scroll-Freiraum kommt
  über `Scaffold(extendBody: true)`, sodass keine Seite ihn selbst kennen muss.
  Fehlt die Supabase-Konfiguration, startet ein Fehlerbildschirm mit dem
  nötigen Befehl statt eines stillen Absturzes.
  Nicht nachgebaut: der Inset-Anteil des Leisten-Schattens (`BoxShadow` kann
  das nicht) und der Challenge-Punkt, weil dessen Sitzungszustand
  (`window.__huntActive`) im Neubau noch nicht existiert. Maße für beides im
  Code dokumentiert.

## Phase 1, Auth und Onboarding

- [x] **7. Startbildschirm.** `/splash` außerhalb der Shell, Weiche als reine
  Funktion in `lib/app/routing/route_guards.dart`, `FirstLaunchStore` in
  `lib/features/identity/domain/`. **Kein Ladebildschirm und kein Timer**: der
  zeitgesteuerte Boot-Splash der PWA ist seit Commit `83be52f` (06.06.2026)
  entfernt, die Zahlen 1200 ms und 15000 ms in den Vorlagen gehören zu totem
  Code. Drei gleichrangige Ausgänge, darunter der Gastmodus „Ohne Konto
  erkunden", der in beiden Vorlagen fehlt.
  Bewusste Abweichungen, jede im Code begründet: die Erstlauf-Merkung wird
  **nur** auf dem Gast-Weg gesetzt, nicht wie in `app.jsx:477` bei jeder
  Navigation (dort sieht man den Startbildschirm nach einem abgebrochenen
  Signup nie wieder); Überlauf über `IntrinsicHeight` statt Abschneiden, weil
  Flutter sonst einen Overflow-Fehler zeigt; `MediaQuery.disableAnimations`
  schaltet beide Animationen ab, was gleichzeitig Systemeinstellung und
  Testbarkeit erfüllt.
  **`onboarding.quote` ist ein toter Schlüssel:** er existiert, wird in der PWA
  nirgends benutzt und weicht im Text ab (»…« statt „…", plus „(vermutlich)").
  Für das sichtbare Goethe-Zitat gibt es also keinen Schlüssel, und Invariante 4
  („kein Text hartcodieren") hat hier keine Quelle.
  **Die Safe Area liegt andersherum als angenommen:** `index.html:101-107` setzt
  `env(safe-area-inset-*)` als `padding` an den **`body`**, die PWA rückt also
  den ganzen Bildschirm samt Verlauf und Pins ein. Eine `SafeArea` nur um die
  Inhaltsspalte hätte die Wortmarke richtig und die fünf Pins um die Notch-Höhe
  zu hoch gesetzt.
  Offen: der Startbildschirm deckt nur die erste Hälfte von `app.jsx:69` ab.
  Die zweite (`&& !Storage.getUser()`, also „angemeldet heißt kein Splash")
  braucht die Sitzung und gehört in Schritt 9 in die Weiche, nicht in den
  Speicher.
- [x] **8. Audio-Aktivierungsdialog.** `showDialog` mit
  `barrierDismissible: false`, weil die Quelle kein Schließen durch Tippen auf
  den Hintergrund kennt. `AudioModeStore` in `lib/features/settings/domain/`,
  denn die Audio-Präferenz gehört `settings`, während der auslösende Knopf
  `identity` gehört; verdrahtet über den von Regel 10 vorgesehenen
  App-Kompositions-Adapter in `SplashRoute.build`.
  **Die Präferenz bewirkt noch nichts**, weil es keine Wiedergabe gibt. Nicht
  gebaut und jeweils dokumentiert: iOS-DeviceMotion-Berechtigung, gesprochene
  Hilfe (Schritt 25, E-15), `fact_audio_help_shown`.
  Der Lautstärke-Hinweis der Quelle **entfällt**, siehe E-28: sein i18n-
  Schlüssel existiert in der PWA nicht, sie zeigt dem Nutzer den rohen
  Schlüsselnamen.
  Bewusste Abweichung: die beiden Knöpfe bekommen Nunito statt der
  Browser-Standardschrift, in der die PWA sie unbeabsichtigt rendert. Ein
  `<button>` erbt `font-family` nicht, und `styles.css` holt das nur für
  `.tab-pill button` nach, während jeder andere Knopf der App Nunito
  ausdrücklich setzt. Folge, die dazugehört: Arial kennt kein Gewicht 900, in
  der PWA sehen beide Knöpfe gleich fett aus, hier nicht.
  **Mit echten Schriften fielen zwei echte Überläufe aus Schritt 7 auf**, beide
  bei doppelter Systemschrift und damit innerhalb von Androids Maximum: die
  Wortmarke um 65 Pixel und die Sprachzeile um 3,8 Pixel. Die Wortmarke skaliert
  jetzt bewusst nicht mit, weil CSS-`px` der Betriebssystem-Textgröße nicht
  folgt und eine feste Kachel neben einem mitwachsenden Schriftzug ein halb
  skaliertes Logo wäre; der Kopfhörer-Knopf ist auf 115 Pixel gedeckelt. Ein
  `LayoutBuilder` wäre dort der
  naheliegende Weg und ist unmöglich: die Inhaltsspalte liegt in einem
  `IntrinsicHeight`, und der bricht mit `LayoutBuilder does not support
  returning intrinsic dimensions`.
- [x] **9. Anmeldung.** Vertrag in `identity/domain/repositories/`, damit Regel
  13 greift, Supabase-Anbindung in `data/`, Zugang über einen auf den Vertrag
  typisierten Provider mit untätigem Standard plus Override in `bootstrap.dart`.
  Direkt geht es nicht: `presentation` darf `data` nicht importieren. Der
  Standard fällt zur sicheren Seite aus und kann keinen angemeldeten Nutzer
  erfinden; `flutter test` läuft weiter ohne `--dart-define`.
  Fehlerübersetzung in drei Stationen: Vendor-Ausnahme in der Datenquelle,
  `AuthFailure` ohne Text und ohne Backend-Meldung in der Domäne, i18n-Zuordnung
  in `presentation/formatting/`. `AuthException.code` ist brauchbar, die
  Aufzählung `ErrorCode` kennt aber `invalid_credentials` nicht, deshalb bleibt
  der Teilstring-Vergleich als Rückfallebene an genau einer Stelle.
  Die Weiche erfüllt jetzt **beide** Hälften von `app.jsx:69`: ein angemeldeter
  Nutzer sieht keinen Startbildschirm.
  Bewusste Abweichungen: im Fehler-Restfall generischer Text statt der rohen
  englischen Supabase-Meldung (`cross-cutting-concerns.md` verbietet
  Backend-Details); kein Beitrittsdatum, weil die Quelle dort bei jeder
  Anmeldung das heutige Datum schreibt; „Angemeldet bleiben" ist gebaut, aber
  wirkungslos, genau wie in der Quelle, siehe E-33.
  **Passwort-Reset entfällt**, siehe E-34.
  Zwei Verdrahtungsfallen, beide mit Wegwerf-Proben belegt: Regel 7 meldet in
  `presentation` **jeden** Konstruktoraufruf einer Klasse, deren Name auf
  `Repository`, `DataSource` oder `Client` endet, ein `const
  UnavailableAuthRepository()` im Provider wäre also ein Verstoß (gelöst über
  einen kleingeschriebenen `const`-Wert im Vertrag; die drei bestehenden
  Store-Provider überleben die Prüfung nur, weil ihre Klassen auf `Store`
  enden). Und `Override` aus `flutter_riverpod 3.4.2` ist **nicht exportiert**,
  eine Funktion `List<Override> productionOverrides()` ist nicht schreibbar,
  deshalb gibt die benannte, testbare Funktion die `ProviderScope` selbst zurück.
  **Aus der Review vom 28.08.2026** (47 Mutationen, 13 überlebend, kein
  blockierender Fund): der eine echte Defekt waren die Fremdanmeldungs-Knöpfe,
  die auf Flutters Standard `center` standen, während CSS auf
  `align-items: stretch` steht. `CrossAxisAlignment.stretch` allein wirft, weil
  beide Bildschirme die Zeile in ein `SingleChildScrollView` stellen und die Höhe
  dort unbeschränkt ist (`BoxConstraints forces an infinite height`); es braucht
  ein `IntrinsicHeight` darum. Ehrlich mitgeschrieben: **tragend ist das
  `IntrinsicHeight`, nicht das `stretch`**, weil der `Container` seinen Inhalt
  ohnehin zentriert, wer nur `stretch` entfernt, bricht heute nichts.
- [x] **10. Registrierung.** Username-Feld mit fünf Statuszuständen und
  entprellter Prüfung über `check_username`, Passwort-Stärkeanzeige, Stadt-Picker
  mit Suche und Username-Vorschlag, Einwilligung, Fortschrittsleiste (statisch,
  die Quelle hat nur einen Schritt). Nutzt die geteilten Bausteine aus Schritt 9.
  Drei Defekte der Quelle bewusst **nicht** übernommen: der Wettlauf der
  Username-Prüfung (die Quelle bricht den geplanten Check erst nach dem `return`
  ab, ein älterer Check setzt danach „frei", obwohl das Feld ungültig ist), das
  rote Kreuz am geleerten Feld, und das Verschlucken des Fehlers beim Schreiben
  des Usernames. Der Bestätigungshinweis bei unbestätigter E-Mail steht in einer
  positiven Box, nicht wie in der Quelle in der roten Fehlerbox.
  Gemeldet, nicht gelöst: die AGB-Zustimmung wird nirgends übertragen, es gibt
  also keinen Nachweis; der Client schreibt direkt in `profiles`, dieselbe Klasse
  wie E-24; `raw_user_meta_data` ist frei beschreibbar und trägt trotzdem `name`
  und `hometown`; und `check_username` vergleicht case-insensitiv, während der
  Eindeutigkeitsindex case-sensitiv ist.
- [x] **11. Tutorial-Overlay.** Neun Schritte unter `lib/app/onboarding/`
  (E-26), aufgehängt über `AppShellRoute.builder` um `AppShell`, ohne eigene
  Route: das Overlay hängt über der ganzen Shell, ein Tipp auf einen fremden
  Tab-Knopf schaltet den Schritt weiter statt den Zweig zu wechseln.
  Anker-Registry in `lib/core/anchors/` (E-27), Mechanismus dort, Kennungen bei
  der besitzenden Oberfläche (`ShellTab.anchorId`, `DiscoveryAnchors`).
  Vier Schritte sind heute voll baubar (1, 5, 7, 9), fünf degradieren
  paritätstreu ohne Pfeil und Ring, weil ihre Anker auf dem Kartenbildschirm
  liegen und der noch ein Platzhalter ist (Korrektur 13).
  `fact_tour_shown` in `lib/app/onboarding/tour_store.dart`, nach dem
  Speichermuster von `language_preference_store.dart`, unabhängig von
  `fact_has_launched` und **nicht** in `route_guards.dart`.
  Zwei goldene Meta-Zeilen der Hero-Schritte als E-39-Ergänzung nachgetragen
  (`tour.step1.meta`, `tour.step9.meta`), wortwörtlich aus der Quelle.
  Zwei Funde einer unabhängigen Review behoben: `OnboardingHost` hätte mit der
  naheliegenden `if (shown) return child;`-Fassung beim Tourende die ganze
  Shell samt aller vier Navigationsstapel neu aufgebaut; `TourBubble` schnitt
  Text bei großer Systemschrift lautlos ab, weil `Stack` clippt statt einen
  Überlauf zu melden.
  Bemerkt wurde der erste Fund nicht in einem Layout-Test, sondern über ein
  `assert` der Anker-Registry: die neue Tab-Leiste meldete ihre Anker an, bevor
  die alte entsorgt war, und die Registry sagt das laut. Ein
  Sicherheitsmechanismus aus Block 1 hat damit einen Fehler in Block 2 gefangen,
  für den kein Test dieser Art vorgesehen war.
  Der Sichtbarkeitslauf der Registry erkennt einen Anker in einem inaktiven
  Shell-Zweig zuverlässig, obwohl `IndexedStack` allein das nicht verrät; nur
  das zusätzliche `Offstage` von `go_router` tut es.
  **605 → 761 Tests an diesem Tag**, in sechs geprüften Blöcken: E-38, zehn
  Review-Lücken aus Schritt 9/10, die Anker-Registry, die i18n-Ergänzung, das
  Overlay, zwei weitere Review-Funde.

## Phase 2, Map-Kern

**Die Strukturfrage vor Schritt 12 ist am 28.08.2026 entschieden**, siehe unten
unter „Offene Entscheidungen". Der Karten-Host entsteht unter `lib/map/`, die
Bewachung dazu steht seit demselben Tag im Prüfskript.

**Das Fundament steht seit der Nacht zum 29.08.2026**, gebaut vor Schritt 12,
weil der Kameravertrag entscheidet, was der Host danach kostet. Fünf reine
Domänenverträge unter `lib/map/domain/`, 149 Tests:

| Datei | Was darin steht |
|---|---|
| `map_position.dart` | Wertobjekt Breite/Länge plus Haversine. Erdradius `6371000` aus `screen-map.jsx:297`, nicht der Lehrbuchwert. |
| `map_camera.dart` | `MapCameraView` (Ist-Zustand), `MapCameraChange` (`null` heißt unverändert), `MapCameraMotion` (animiert oder sofort, als Typ und nicht über `Duration.zero`). |
| `map_camera_intent.dart` | Versiegelt: Befehl (Rang 1), Einmal-Absicht (Rang 3), Dauerabsicht (Rang 4), je mit Herkunft. |
| `map_camera_gate.dart` | Die reine Entscheidung samt Schwellwerten, plus die Einrast-Regel. Keine Uhr, kein Zustand. |
| `map_host.dart` | `abstract interface class`, die veröffentlichte Fassade. |

**Bewusst nicht gebaut:** Überlagerung und Projektion. Ob es überhaupt eine
Projektion braucht, hängt daran, ob Cluster und Marker SDK-Layer werden oder
Flutter-Widgets über der Karte, und das fällt in Schritt 15 bis 18. Der
Auslöser für `MapProjection` ist der erste geografisch verankerte
**Flutter**-Aufbau, also Avatar (18) und Münz-Animation (17), nicht Cluster.

**Ebenfalls nicht gebaut, mit benanntem Auslöser:** die Rücknahme einer
Dauerabsicht. Die Quelle hat dafür heute keinen Aufrufer, der einzige echte
Abschaltfall ist das Einrasten der Blickrichtung, und das ist Zustand am Gate.
Gebraucht wird sie beim ersten Feature, das eine Dauerabsicht beendet, also
beim Tourende in Phase 6.

**Vorrangregel 2 hat zwei Eingänge, weil es zwei verschiedene Dinge sind.** Der
erste Entwurf reduzierte „direkte Manipulation schlägt Automatik" auf einen
Zeitpunkt, also eine Karenzzeit nach der letzten Nutzerbewegung, mit dem
Argument, ein Zeitpunkt könne beide Lesarten ausdrücken und ein `bool` nur eine.
Für das GPS-Folgen stimmt das (`screen-map.jsx:2668` prüft wirklich nur
`!isEasing()`), für die zweite Dauerabsicht ist es **falsch**: `:2837` prüft
zusätzlich `!userInteracting`, gesetzt ab `touchstart`, also **bevor** sich die
Kamera überhaupt bewegt hat. Ein Fenster nach der Bewegung sperrt am Anfang zu
spät und am Ende zu lange. Schlimmer als die Lücke war, dass der Code die
Verkürzung als quellentreu dokumentierte.

**Zwei Belege aus dem Testbau des Fundaments.** `MapCameraChange` durfte zwei
seiner vier Felder aus der Gleichheit fallen lassen, ohne dass ein Test anschlug;
sein Zwilling `MapCameraView` hatte den Test, er nicht. Und der erste Prüfwert
für die Haversine-Strecke war **in der Richtung** falsch geraten: ein Längengrad
auf 60° Breite ist als Großkreisstrecke nicht länger als der halbe
Meridiangrad, sondern 0,53 Meter kürzer, weil die kürzeste Linie polwärts
ausweicht. Dass der Test fiel, belegt, dass er gegen eine unabhängige Herleitung
prüft und nicht gegen die Implementierung.

### Was `maplibre_gl 0.26.2` nicht kann

Alles am Pub-Cache gemessen, nichts davon steht in der Paketdoku, und jede Zeile
prägt entweder den Host, die Überlagerung oder den Stil. Diese Tabelle ist die
Sammelstelle: was hier fehlt, ist auch nicht anderswo dokumentiert.

| Lücke | Fundstelle | Folge für den Neubau |
|---|---|---|
| **Kein `isEasing()`** | null Treffer im ganzen Paket | Vorrangregel 3 hängt genau daran. Der Host führt seinen Animationszustand selbst. |
| **`isCameraMoving` ist kein Ersatz, sondern eine Falle** | gesetzt über `onCameraMoveStartedPlatform`, `lib/src/controller.dart:185` | Gilt für **jede** Bewegung, auch fürs Ziehen mit dem Finger, während `isEasing` nur programmgesteuerte Animation meint. |
| **Kein `stop()`, kein `cancel()`** am Controller | — | Vorrangregel 1 heißt „bricht alles ab"; der harte Reset kann nur überschreiben. |
| **`animateCamera` liefert auf iOS immer sofort `null`**, auf Android echte Werte über einen Listener | `controller.dart:416`, eigene Doku; gilt genauso für `moveCamera` | Taugt nicht zum Abwarten. `if (await animateCamera(...) != true)` wäre auf Android richtig und auf iOS fatal: der Host löschte seinen Animationszustand nie mehr und unterdrückte danach jede Dauerabsicht. Regel: `true` und `false` löschen, `null` heißt „keine Auskunft" und lässt stehen. Ein Animationszustand mit Start und **ohne** geplantes Ende gilt sonst als „läuft ewig" und friert jede Dauerabsicht dauerhaft ein. |
| **Keine Bewegungsursache im Rückruf** | `OnCameraMoveCallback = void Function(CameraPosition)`, ohne Ursache, ohne `isGesture`; `onCameraMoveStarted` gibt es als Widget-Rückruf nicht | „Der Nutzer hat angefasst" ist nur als **unerklärte Kamerabewegung** erkennbar. |
| **Kein `setPaintProperty`, kein `setLayoutProperty`** | vorhanden ist nur `setLayerProperties`, das laut eigener Doku unbelegte Eigenschaften auf den Standard zurücksetzt | Der Stil wird **gebacken** statt zur Laufzeit umgefärbt, erzwungen und nicht gewählt. Die PWA ändert je Layer genau eine Eigenschaft und lässt den Rest stehen; nachbauen hieße, für jeden der **111 Layer** den vollständigen Eigenschaftssatz zurückzulesen und über den Plattformkanal zurückzuschieben. |
| **Kein dauerhaftes Kamera-Padding** | `setPadding` fehlt; `padding` kommt nur an `CameraUpdate.newLatLngBounds` (`maplibre_gl_platform_interface-0.26.2/lib/src/camera.dart:106-119`) und an `setCameraBounds` (`controller.dart:1811-1826`) vor | `screen-map.jsx:1694` setzt `map.setPadding({ top: 320 })` und schiebt den wirksamen Kartenmittelpunkt um 320 Pixel nach unten, damit die Figur im unteren Drittel steht. `setCameraBounds` grenzt den **erlaubten Ausschnitt** ein; wer sie dafür hält, sperrt das Schieben ein, statt die Kamera zu versetzen. **Entscheidet in den Schritten 15 bis 18**, wo Nutzermarker und Avatar landen und wie ein Neuzentrieren aussieht. |
| **`maxPitch` und `minPitch` haben kein Gegenstück** | `screen-map.jsx:1677-1678` | Das SDK klemmt die Neigung zoomabhängig und still. Folgenlos, solange die Auto-Neigung bei 58 endet. `dragRotate: false` (`:1681`) ist auf dem Gerät gegenstandslos, es betrifft nur die Maus. |
| **Kein `getClusterExpansionZoom`** | null Treffer im ganzen Paket, ebenso `getClusterChildren` und `getClusterLeaves` | Die PWA rechnet damit die Zoomstufe, ab der genau dieser Cluster zerfällt (`screen-map.jsx:2447-2451`). Das ist die einzige Stelle, an der die Überlagerung in den **fertigen** Kameravertrag hineingreift, siehe D-b. |
| **`addGeoJsonSource` kann nicht clustern** | reicht auf Android nur `withSynchronousUpdate` durch, `MapLibreMapController.java:448` | Die Methode, deren Name genau das verspricht, hat keinen Cluster-Schalter; eine so angelegte Quelle clustert **nie**, ohne Fehlermeldung. Tragend ist `addSource` mit `GeojsonSourceProperties`, das `cluster`, `clusterRadius` und `clusterMaxZoom` führt, umgesetzt in `SourcePropertyConverter` auf beiden Plattformen. Dieselbe Sorte Falle wie `PLAIN_MAP_LOOK`: der naheliegende Name liefert das Falsche, und wer den Fehler beim Layer sucht, sucht Stunden. |
| **Der Antipp-Rückruf liefert keine `properties`**, nur die Top-Level-`id` | Android schickt `layerId` und `feature.id()`, iOS `id`, `layerId` und die Positionen; Dart macht daraus blind `payload["id"].toString()` | Die Fakt-Kennung muss die **Top-Level-`id`** des GeoJSON-Merkmals sein. Die PWA legt sie nach `properties.id` (`screen-map.jsx:1896`); wer das GeoJSON eins zu eins übernimmt, bekommt beim Antippen die Zeichenkette `"null"`, ohne Ausnahme und ohne Warnung. `promoteId` rettet das nicht, es wirkt laut eigener Doku nur im Web und wird vom Android-Konverter gar nicht gelesen. **Kein Test in diesem Repository kann das finden**, weil ohne Plattformkanal kein Controller entsteht; es fällt am Gerät auf, und dort als „beim Tippen passiert nichts". |

**Teilweise doch möglich, entgegen einem eigenen Kommentar:**
`setGeoJsonFeature` aktualisiert einzelne Punkte sehr wohl. Der Kommentar dazu
schloss aus `:451`, das gehe mit diesem Paketstand nicht; `:451` ist eine
Leerzeile, der Eintrag steht auf `:450` und ein zweiter auf `:477`, in genau der
Methode, die bei jeder Aktualisierung läuft. Richtig ist nur „vor dem ersten
`setGeoJsonSource` nicht".

**Am 30.08.2026 gemessen: ja, `moveCamera` verwirft eine laufende
`animateCamera`** auf maplibre-native unter Android. Zwei unabhängige Signale,
Belege unter „Die vier offenen Gerätemessungen". Vorrangregel 1 trägt damit,
allerdings nur, solange der harte Reset eine **vollständige** Kamera setzt; die
Bedingung steht dort als Fund B. Für iOS fehlt die Messung weiterhin, und dort
fehlt auch das zweite Signal, weil `animateCamera` immer `null` liefert.

### Am 29.08.2026 von Janek entschieden: vier Fragen zur Karte

**1. Die Karte bekommt eine Karenzzeit** (`manualMoveGrace`, Lesart B). Wer
die Karte wegzieht, wird für N Sekunden nicht zurückgerissen. Sichtbare
Abweichung von der PWA, und sie ist begründet: dort ist die Sperre für die
Blickrichtung vorhanden, für den Mittelpunkt fehlt sie, weil `userInteracting`
im Closure des Kompass-Effekts liegt und für `applyPos` gar nicht erreichbar
ist (`screen-map.jsx:2807` gegen `:2668`). Ob das gewollt war, ist aus dem Code
nicht ablesbar. **N ist noch zu wählen**, das Gate trägt beide Lesarten bereits.

**2. Die Fakt-Ballons werden nativ gezeichnet**, mit einer ausdrücklichen
Auflage: *„aber Animation und Glühen, Drehung müssen dann später aber
kommen!!"*. Das ist eine **Zusage, keine Option.** Der native Weg ist damit
eine Vertagung und kein Verzicht, und Schritt 17 ist nicht abgeschlossen,
bevor die Ballons wieder stufenlos wachsen, sich drehen und glühen.

**Korrektur an der Einschätzung, die dieser Entscheidung zugrunde lag.** Beim
Vorbereiten von Schritt 17 nachgemessen: es ist **nicht** nur der
nächstgelegene Ballon. Größe, Drehung und Glühen gelten für **jeden** nicht
gesammelten Ballon innerhalb von `COIN_RADIUS = 150` Metern
(`screen-map.jsx:2207`, `:2234-2295`). Nur das Auf-und-ab (`coinFloatNear`)
bekommt allein der nächste (`:2298-2308`), und genau darauf bezieht sich der
Korrekturkommentar bei `:2217-2222`. In einer dichten Altstadt sind das
mehrere gleichzeitig, und das Beispiel dafür steht in der Quelle selbst:
Weimars Altstadt.

Die gemessenen Kurven, alle je Bild gerechnet, mit `t = 1 - dist / 150`:

| Größe | `26 + 22 * pow(t, 1.5)` Pixel, also 26 fern bis 48 nah (`:2250-2255`) |
|---|---|
| Drehung | `0.12 + 17.88 * pow(t, 2.2)` Grad je Bild, aufsummiert (`:2207-2209`, `:2273-2278`) |
| Glühen | Radius `4 + t * 8` px, Deckkraft `0.15 + t * 0.55` (`:2281-2283`) |

**Was das für den Entwurf bedeutet**, und es ist eher eine Chance als ein
Problem: Größe und Glühen hängen nur an der Entfernung, nicht an der Zeit. Sie
sind als datengetriebene Stil-Ausdrücke über eine Merkmalseigenschaft
darstellbar, die beim GPS-Takt (1 bis 5 Hz) aktualisiert wird, nicht beim
Bildtakt. Wirklich je Bild ist nur die **Drehung**, und die ist eine
Y-Achsen-Spiegelung, die `icon-rotate` nicht kann. Ob daraus eine
Flutter-Überlagerung je Ballon wird oder nur eine für den nächsten, ist die
Entwurfsfrage von Schritt 17.

**3. Die Ballon-Bilder entstehen zur Laufzeit**, nicht als Dateien im
Repository. Sie folgen damit den Design-Tokens automatisch. Die Zahl der
Bilder bleibt Kategorie mal Sammelzustand; die **Entfernungsstufe darf
niemals** in die Bildfabrik, sie ist stufenlos (`:2252-2256`) und machte sie
unbegrenzt.

**4. Keine Deckelung über Zoom 16.** Die PWA zeigt dort nur die 25 nächsten,
und ihr Kommentar nennt als Grund ausdrücklich den Lag-Schutz im Browser
(`:2050`). Nativ gezeichnet gibt es diesen Grund nicht. Die App zeigt mehr
Fakten als die PWA, das ist bewusst.

**Selbst entschieden, Kleinkram:** ein Cluster heißt im Domänenvertrag
**Gruppe**, nicht Cluster. „Cluster" ist Vokabular des Karten-SDK, und
`map/domain` soll keine Vendor-Sprache tragen.

### Vor Schritt 15 geprüft: was Marker und Cluster kosten

Die drei Paketfallen dazu stehen in der Tabelle oben: `addGeoJsonSource`
clustert nicht, `getClusterExpansionZoom` fehlt, und der Antipp-Rückruf liefert
nur die Top-Level-`id`. Alle drei sind lautlos und keine ist dokumentiert.

**Korrektur an einer Annahme, die naheliegt und falsch ist:** die PWA animiert
**einen** Ballon, nicht alle. `screen-map.jsx:2217-2232` ist ausdrücklich als
Korrektur dokumentiert, vorher hüpften alle und „auf dichten Karten wie
Weimars Altstadt sahen Nutzer dauerndes Gehüpfe". Animiert wird nur der
nächstgelegene innerhalb 150 Metern. Und die vier Cluster-Layer wippen gar
nicht, `clusterBob` gehört allein dem Stadt-Marker.

**Folge für den Entwurf:** Cluster und Fakt-Ballons werden native Layer, der
Nutzermarker kann es nicht werden (er trägt den Avatar-Container, und eine
WebView ist kein Symbol-Layer). Eine `MapProjection` braucht `map/domain`
deshalb in Schritt 15 **nicht**. Der Auslöser ist auch nicht „der erste
Flutter-Aufbau", wie es unten stand, sondern „der erste Aufbau, der
**zwischen zwei Kamerabildern** seine Bildschirmlage braucht": bei geneigter
Kamera bis 58 Grad ist die Abbildung perspektivisch, und Sichtfeld und
Kamerahöhe gibt das Paket nicht heraus. Das trifft die Münz-Animation
(Schritt 17) und den Avatar (18).

### Schritt 12 ist fertig, und drei Dinge daran prägen alles Weitere

**Ein Feature kann den Karten-Host niemals selbst mounten.** Gemessen mit
einer Wegwerf-Probe: `map_page.dart` darf `map/presentation/` nicht
importieren, Regel 18 bricht mit Exit-Code 1 ab. Die Kartenfläche kommt als
Widget-Parameter herein und wird vom Routen-Adapter in `app_routes.dart`
gesetzt, dasselbe Muster wie `onAudioGuidePressed` aus Schritt 8. Für jedes
weitere Karten-Bauteil gilt derselbe Weg. Bis zu diesem Schritt war
`maplibre_gl` in `lib/` an keiner Stelle importiert, Regel 18 und 20 waren
also nie erprobt.

**Die Grenze zwischen Feature und Host hängt am Typ, nicht an einer
Konvention.** Zwei Provider zeigen auf dasselbe Objekt: Features lesen
`Provider<MapHost>` und sehen kein `attach`, `map/presentation` liest
`Provider<MapHostRegistry>`. Gemessen: der Versuch über den falschen Provider
bricht `dart analyze` mit Exit-Code 3 ab. Damit ist keine neue Prüfregel
nötig. Dass die Registry selbst `MapHost` ist, erledigt zwei Dinge nebenbei:
kein Feature hält je einen veralteten Host, und ein Abonnement auf
`cameraChanges` überlebt einen Hostwechsel.

**`lib/map/application/` ist das erste `application/`-Verzeichnis im
Repository**, und sein Inhalt ist Komposition, keine Anwendungsfälle. Als
Ausnahme in `architecture-overview.md` festgehalten, weil kein anderer Ort
übrig bleibt: die Domäne darf kein Riverpod, und `presentation/` ist für
Features durch Regel 18 unerreichbar.

**Vier Entscheidungen, die beim Bauen fielen und im Code begründet sind:** die
Identität einer Dauerabsicht ist eine geschlossene Aufzählung statt einer
freien Zeichenkette (ein Tippfehler sähe sonst wie eine neue Dauerabsicht aus
und liefe ohne jede Totzone); eine Absicht vor der Karte wird fallen gelassen
und gemeldet, nicht aufgehoben; `zoomend` gibt es im SDK nicht, Ersatz ist
`onCameraIdle` plus Vergleich mit dem Zoom beim letzten Stillstand; und
`steeringGrace` steht auf 200 ms, ausdrücklich geschätzt und nicht gemessen.

**Zwei Angaben der Quelle sind dabei als veraltet aufgefallen:** der Kommentar
bei `screen-map.jsx:1752` nennt 65 oder 75 Grad Neigung, wirksam sind **58**
(`:1758`). Und der lange Kompassdruck löscht in `:3165` nur `lastCameraPosRef`,
den Zeitstempel `lastCameraAtRef` fasst er nicht an; `clearsFollowAnchor`
leert deshalb den Ort und lässt den Zeitpunkt stehen.

**Sichtbar anders als die PWA:** der native Attributions-Knopf bleibt stehen.
Die PWA setzt `attributionControl: false`, `maplibre_gl 0.26.2` hat dafür
keinen Schalter, nur Position und Rand. Nicht behoben, weil eine Attribution
auch rechtlich hingehört.

### Schritt 12, weitere Belege

1017 → 1084 Tests, danach eine unabhängige Review mit 25 Mutationen, 11
überlebend.

- **Die Falle beim Stil heißt `PLAIN_MAP_LOOK`.** `screen-map.jsx:13` steht auf
  `true` und der Kommentar darüber liest sich wie „schlichte Karte". Der
  Schalter kippt aber nur vier Dinge, `applyGameStyle` läuft **unbedingt** bei
  jedem `style.load`, und die rund 250 Zeilen Umfärbung gelten immer. **Die
  Häuser sind sichtbar:** eine unbedingte Liste blendet sie aus, der große
  Durchlauf schaltet sie danach wieder sichtbar. Wer nur die erste Stelle liest,
  backt eine Karte ohne Häuser.
- **Das Steuerfenster stand dauerhaft offen.** Die 200 ms, in denen eine
  Kamerarückmeldung als eigene gilt, verlängerten sich bei **jeder** eigenen
  Bewegung und verkürzten sich nie; das Blickrichtungs-Folgen tickt häufiger als
  alle 200 ms, also **rastete eine echte Zwei-Finger-Drehung nie ein**. Der
  Kommentar nannte den Preis „verschluckt eine Drehung kurz danach", tatsächlich
  war er „gar nicht mehr einrastbar". Auch ein Fenster, das an den **letzten**
  Aufruf gebunden ist statt verlängert zu werden, steht bei 100-ms-Ticks
  dauerhaft offen: **„steuert der Host gerade" ist als reine Zeitfrage nicht
  beantwortbar.** Der Host merkt sich jetzt die zuletzt selbst gesetzte
  Blickrichtung; weicht die eintreffende darüber hinaus ab, hat kein eigener
  Aufruf sie verursacht.
- **`@visibleForTesting` an einem Feld bewacht nur das Lesen.** Ein
  Konstruktoraufruf `MapSurface(debugCreateHost: …)` aus `lib/` lief anstandslos
  durch, also genau der Missbrauch, um den es geht. Erst die Annotation am
  **Konstruktorparameter** meldet ihn. Wer sich auf die Absicherung aus D-5
  verlässt, muss wissen, wo sie greift.
- **Zwei Dinge, die eine unabhängige Prüfung vor dem Bauen verhindert hat.** Ein
  Host, der seine Buchführung im `State` hält, wäre unprüfbar, weil ohne
  Plattformkanal `onPlatformViewCreated` nie läuft und **nie ein Controller
  entsteht**. Und Riverpod verbietet Provider-Mutation in `initState` **und**
  `dispose`, im Release still statt werfend. Die Registry ist deshalb ein
  gewöhnliches Objekt wie `AnchorRegistry`.
- **Vertragslücke, die erst in Schritt 13 aufgefallen wäre:**
  `MapCameraSituation` verlangt Zustand *zu dieser* Dauerabsicht, aber
  `MapCameraFollow` trug keine Identität, und nach der Herkunft zu schlüsseln
  ist beweisbar falsch, weil GPS-Folgen und Blickrichtungs-Folgen beide
  `discovery` sind. Jetzt kostete es ein Feld.
- Kleinkram mit Reichweite: `LatLng` normalisiert den Längengrad
  verlustbehaftet, aus 11.582 wird 11.581999999999994, also mit `closeTo`
  messen. Und Methoden-Tear-offs sind `==`, aber **nicht** `identical`; ein Test
  auf `identical` fällt gegen richtigen Code.

### Schritt 13, was daran gemessen ist

Ortungsdienst, GPS-Folgen, Sky-Fall und die drei Bedienelemente des Top-Chrome,
1116 → 1198 Tests.

- **Nicht von D-9 blockiert.** `domain-map.md:153-156` führt den `geolocation
  provider` unter „The following are **not** business domains", in derselben
  Liste wie `map rendering`, und genau dieser Absatz trägt den Umzug von
  `map rendering` nach `lib/map/`. Also `lib/services/location/` und kein
  Feature. `DevicePosition` ist bewusst so klein, dass ein „ja, gemeinsamer Typ"
  die Datei ersatzlos löscht.
- **Bestandsdefekt am Kompass-Knopf.** Er benutzte `GestureDetector.onLongPress`
  und damit Flutters `kLongPressTimeout` von **500 ms**, die Quelle wartet
  **700**. Unsichtbar, solange beide Rückrufe `null` waren. Teurer ist die
  Nebenwirkung: `tester.longPress` hält `kLongPressTimeout + kPressTimeout` =
  600 ms und wäre ab jetzt ein **kurzer** Druck gewesen, der bestehende Test
  hätte lautlos den falschen Rückruf gemessen.
- **Zwei Zahlen der Quelle, die man ohne Nachschlagen falsch baut:** jede Ortung
  schlechter als **35 Meter** wird verworfen, sonst springt der Marker während
  der Aufwärmfolge Funkzelle → WLAN → GPS. Und die **12 Meter Totzone gehören
  der Kamera**, nicht dem Ortungsdienst; wer sie zusätzlich als `distanceFilter`
  setzt, lässt die Schwelle zweimal wirken.
- **Der leere Befehl.** Der Kompass-Tipp ohne Ortung erzeugte eine
  `MapCameraChange` ohne Änderung; der Kommentar nannte das unsichtbar, „weil es
  ohne Position auch keinen Sky-Fall gab". Die Aufzählung war unvollständig,
  **die Auto-Neigung braucht keine Position**: der leere Befehl verwarf den
  Animationszustand und fror die Neigung auf halbem Weg ein. Behoben im Host,
  eine Änderung ohne Inhalt fasst die Kamera nicht mehr an. Der Vertrag sagte
  das längst, der Host hielt es nicht ein.
- **Widerlegte Begründung, ausdrücklich als widerlegt stehen geblieben:** die
  bedingte Erzeugung der Gesten-Erkenner war mit „nähme sonst an der Gestenarena
  teil" begründet. `TapGestureRecognizer.isPointerAllowed` lehnt jeden Zeiger
  ab, solange alle Rückrufe `null` sind. Der Preis, den es wirklich gibt:
  `RawGestureDetector` leitet seine Sprachausgabe-Aktionen aus den vorhandenen
  **Erkennern** ab, nicht aus deren Rückrufen, der Knopf sagt also Bedienungen
  an, die ins Leere laufen.
- **Die Kompassnadel zeigte eine Richtung an, die die Karte nicht hat.** Sie
  stand fest auf 0, obwohl die Quelle sie ohne jeden Gerätekompass gegen die
  Kartenblickrichtung dreht (`:1792`); sobald der Nutzer mit zwei Fingern
  drehte, log sie. Behoben, der Bildschirm abonnierte `cameraChanges` ohnehin.

### Schritte 15 und 16, was daran gemessen ist

Zusammen gebaut, weil gruppierte und einzelne Punkte nativ **eine** GeoJSON-
Quelle teilen; die Trennung des Plans ist für diesen Weg künstlich. 1203 → 1308
Tests. **Antippen ist bewusst nicht gebaut:** das Aufklappen einer Gruppe hängt
an einer offenen Entscheidung, und der Punkt-Tipp hat bis Schritt 21 keinen
Empfänger.

- **Die teuerste Lücke fand die Review, nicht die Gates.** `MapOverlayHost` war
  vorbildlich getestet, die Registry auch, der Bildschirm gegen einen Fake, und
  **genau die sechs Zeilen Durchreichung im echten Host, die in der App wirklich
  laufen, hatten null Tests.** Macht man `setOverlay` zu einer leeren Methode,
  erscheint **kein einziger Fakt auf der Karte**, ohne Fehler, ohne Meldung, und
  alle 1290 Tests bleiben grün. Dasselbe Muster wie bei Anmeldung und
  Registrierung am 28.08.2026.
- **17 von 17 Mutationen der Review überlebten**, weil die Bildtests das
  Rechteck maßen statt des Inhalts; nach der Behebung fallen alle 26. Bei den
  zwölf Kategorien hatte der Autor eine zweite, unabhängige Abschrift aus der
  Quelle angelegt, bei den **45 Farbwerten** der Gruppen-Layer nicht.
- **`Picture.toImage` kommt in einem `testWidgets` doch zurück**, aber nur, wenn
  `pumpWidget` selbst innerhalb von `tester.runAsync` läuft. Der Unterschied ist
  die **Zone**, nicht die Zeit: ein Future, das in der fingierten Zeit erzeugt
  wird, kommt auch in `runAsync` nicht an. Die erste Messung war für ihren
  Aufbau richtig und ihre Verallgemeinerung falsch, und sie hatte bereits eine
  öffentliche Testfläche am Bildschirm gerechtfertigt; die ist ersatzlos weg.
- **Riverpod 3 wiederholt einen gescheiterten Provider von selbst**, zehnmal
  über rund 38 Sekunden, und nimmt dabei nur `Error` und `ProviderException`
  aus. `FactFailure` ist eine `Exception`, wird also wiederholt. Das trifft jeden
  künftigen Bildschirm mit einem `FutureProvider`.

### Schritt 17, was daran gemessen ist

Größe, Glühen und Drehung für **jeden** nicht gesammelten Ballon innerhalb der
150 Meter, 1308 → 1421 Tests. Damit ist Janeks Auflage aus Entscheidung 2
eingelöst.

- **Der Entwurf ist an der Größe gescheitert, nicht an der Drehung.** Der Plan
  war, Größe und Glühen nativ über eine Merkmalseigenschaft zu machen und nur
  die Drehung als Widget. `icon-size` skaliert aber das **ganze** Bild, während
  die Quelle nur den Kopf vergrößert (`:2257-2258` fasst allein `.coin-head`
  an); der 50 Pixel lange Stiel wäre mitgewachsen und der Ballon bei Annäherung
  vom Boden abgehoben. Die nahen Punkte verlassen deshalb die native
  Überlagerung und werden als Widgets gezeichnet, alles übrige bleibt nativ. Das
  Ergebnis ist **einfacher**: keine Betonungszahl im Vertrag, keine Farbe, kein
  Neubau von 600 Features im GPS-Takt, und der Kartenvertrag wächst um genau
  eine Sache, die Projektion.
- **Die Perspektive erreicht den Ballonkopf in der PWA gar nicht.**
  `perspective:300px` sitzt an `el` (`:1841`), der Kopf ist ein **Enkel**, und
  der Wrap dazwischen hat kein `preserve-3d`; `grep` über die ganze Quelle
  findet `preserve-3d` genau einmal, an `:1850`, also am Kopf selbst.
  CSS-Perspektive gilt nur für direkte Kinder, aus `rotateY(θ)` wird dort ein
  symmetrisches `scaleX(cos θ)` ohne Verkürzung. **Entschieden: die Perspektive
  bleibt**, weil die Quelle sie ausdrücklich wollte und nur an einer CSS-Feinheit
  scheitert, derselbe Fehlertyp wie der statische `coinShadowFar`. Sichtbare
  Abweichung, Janek informiert, eine Zeile in beide Richtungen.
- **Vier Zahlen im eigenen Bestand waren falsch.** Sie waren korrekt aus
  `coinMakeEl` abgeschrieben, aber diese Funktion beschreibt einen Zustand, den
  es **weniger als ein Bild lang** gibt: `coinRafTick` läuft ab `:2325`
  unbedingt und überschreibt ihn, auch ohne Ortung. Der ruhende Ballon ist 26
  Pixel breit statt 28, sein Emoji **10,01 statt 15**. Ein Drittel, und es wäre
  nie aufgefallen, weil beide Zahlen belegt aussahen.
- **Vierzehn Mutationen überlebten**, weil der Bildtest wieder die Fläche maß:
  man konnte den harten Farbring entfernen, die Drehrichtung umkehren, die
  Perspektive streichen und den Stiel mitwachsen lassen, ohne dass etwas
  anschlug. Jetzt fallen alle zwanzig.
- **Zwei Testentwürfe haben sich beim Bauen selbst widerlegt.** Das
  **Verhältnis** zweier Zuwächse trägt einen Zeitbezug nicht: bei 100 und 200 ms
  liefern die richtige und die falsche Fassung dasselbe Verhältnis 2, gemessen
  werden muss der absolute Winkel. Und die Perspektive lässt sich nicht durch
  zeilenweises Abtasten belegen, weil die Kopfmitte bei 48,07 nicht auf einer
  Pixelgrenze liegt und daraus schon ohne Perspektive eine Scheinasymmetrie von
  1,14 Pixeln entsteht.
- **Zwei Fehler der Quelle bewusst nicht nachgebaut**, beide belegt: der
  statische `coinShadowFar` (`:1866` gegen `:2316-2320`), der bei jedem Ballon
  atmet, der **nie** nah war, und bei keinem, der einmal nah war; und „Grad je
  Bild", das auf einem 120-Hz-Gerät doppelt so schnell dreht. Der Nah-Schatten
  dagegen **ist** gebaut, er ist mit dem Hüpfen gepaart und kein Unfall.
- **Bekannte, offene Abweichung:** `:1851` blendet den Schattenwechsel über 0,4
  Sekunden weich, bei uns schlägt er um. Teuer, weil die 150-Meter-Grenze
  zugleich der Wechsel zwischen nativem Layer und gezeichnetem Widget ist; eine
  Blende müsste beide Seiten kennen.

### Erster vollständiger Gerätelauf, 29.08.2026 abends

Nicht mehr nur der Stil über eine Wegwerf-Probe, sondern **die ganze App mit
echten Daten**: Supabase verbunden, Standort erlaubt, Karte, Fakten,
Näherungs-Animation.

Aufbau: Pixel 8 als Emulator, 1080 × 2400 physisch, Dichte 420, also **411
logische Pixel und Skalierungsfaktor 2,625**. Künstliche Position über
`adb emu geo fix <lon> <lat>`, ohne die es keine Näherungs-Animation zu sehen
gibt. Testfakt 3262 bei 48.14680, 11.56340.

| Frage | Ergebnis |
|---|---|
| Liefert `toScreenLocation` logische oder Geräte-Pixel? | ~~**Der Code stimmt, wie er ist.** Gegenprobe mit und ohne Division durch 2,625: die Ballons stehen beide Male an derselben Stelle.~~ **Am 30.08.2026 widerlegt**, siehe „Ungefragter Fund A". Es sind Gerätepixel, und die Division fehlt. Der Eintrag bleibt stehen, damit sichtbar ist, dass zwei verglichene Bilder eine abgelesene Zahl nicht ersetzen. |
| Bekommen die Gruppen ihre Zahlen? | **Ja**, 17, 2, 32, 4 und 5 gesehen. Der Glyphen-Endpunkt liefert, das war ungeprüft. |
| Laufen Sky-Fall und GPS-Folgen? | **Ja.** Das Gate arbeitet nachweislich: `map.host.intent_suppressed reason=distanceDeadZone` im Log, die 12-Meter-Totzone greift. |
| Läuft die Näherungs-Animation? | **Ja**, Größe, Glühen und Drehung, sechs Fakten gleichzeitig in Reichweite. |
| Ist das Launcher-Symbol noch das Flutter-Logo (E-37)? | **Nein**, der native Startbildschirm zeigt das FACT-Symbol. E-37 ist insoweit veraltet. |

**Diese vier waren offen und sind es seit dem 30.08.2026 nicht mehr:** ob
`moveCamera` eine laufende `animateCamera` verwirft (davon hängt Vorrangregel 1
ab), ob die 200 ms `steeringGrace` tragen, was für einen Punkt hinter dem
Horizont zurückkommt, und ob die Projektion bei schneller Kartenbewegung
sichtbar hinterherhängt. Ergebnisse im nächsten Abschnitt.

**Zwei Datenfunde, die erst die redende Diagnose-Senke sichtbar gemacht hat:**

- `discovery.facts.unknown_category categories=Archäologie,Geschichte,Kunst count=3`.
  Drei Kategorien der echten Daten stehen in keiner der beiden
  Kategorietabellen und fallen auf `hist` zurück, sind also rot statt in ihrer
  Farbe. Der Rückfall ist Parität (`screen-map.jsx:259-262`), die Lücke in den
  Daten ist neu und gehört ins andere Repository.
- `facts.mapping_defects degraded=14 optionalFieldUnusable=14`, Felder
  `puzzle_fit[0..2].question`. Vierzehn Fakten tragen unbrauchbare
  Rätselfragen. Fällt in Phase 4 auf die Füße, nicht vorher.

**Ein Fehler von mir, der hier steht, weil er lehrreich ist.** Der erste Lauf
zeigte an der Nutzerposition keinen Ballon, und zwei Fotos hintereinander waren
bytegleich. Daraus habe ich geschlossen, die Überlagerung zeichne nicht, und
über zwei Runden eine Ursachenkette bis zur Einheitenverwechslung gebaut.
**Der Zustand war ein Startzeit-Artefakt**, es waren schlicht noch keine Fakten
geladen. Belegt hat es erst eine Wegwerf-Probe, die Zahlen ausgibt:
`zoom=16.5 inRange=6 toDraw=6 screen=6`. Eine Beobachtung ist keine Messung,
und genau diesen Vorwurf hatte ich in derselben Woche sechsmal an anderer
Stelle erhoben. Merksatz für den nächsten Gerätelauf: **erst warten, bis die
Daten da sind, dann messen**, und im Zweifel eine Zahl ausgeben lassen statt
ein Bild zu deuten.

### Die vier offenen Gerätemessungen, 30.08.2026 nachts

Alle vier beantwortet, dazu zwei ungefragte Funde. Gemessen mit einer
Wegwerf-Probe, die **direkt mit dem SDK redet** und bewusst nicht über
`MapCameraHost` oder `MapCameraDriver` läuft: gemessen werden sollte
`maplibre_gl`, nicht der eigene Wrapper. Ein Host-Aufruf wäre durch das Gate
gelaufen und hätte die Antwort verfälscht.

Aufbau: Pixel 8 als Emulator, 1080 × 2400 physisch, 411 logische Pixel,
Skalierungsfaktor 2,625. Gastmodus, Position über `adb emu geo fix 11.56340
48.14680`, Kamera beim Start 48.146798 / 11.563398, Zoom 16,5, Neigung 58,
Blickrichtung 0. Die Probe startet **14 Sekunden nach dem Kartenaufbau**, damit
Sky-Fall und erstes GPS-Folgen durch sind; bei stehender Position unterdrückt
die 12-Meter-Totzone danach jede weitere Dauerabsicht.

**Jede Zeile trug eine laufende Nummer**, weil Logcat bei hoher Rate Zeilen
verwirft und die Senke absichtlich nicht puffert. 79 von 79 sind angekommen,
keine Lücke. Ohne diese Nummern wäre ein unvollständiges Protokoll nicht von
einem vollständigen zu unterscheiden gewesen.

| Frage | Ergebnis |
|---|---|
| Verwirft `moveCamera` eine laufende `animateCamera`? | **Ja**, auf Android. Zwei unabhängige Signale, beide einig. |
| Tragen die 200 ms `steeringGrace`? | **Ja**, mit rund zwanzigfachem Abstand: 3,7 bis 9,6 ms. |
| Was liefert ein Punkt hinter dem Horizont? | **Eine endliche Zahl, die gültig aussieht.** Kein `NaN`, keine Ausnahme, stattdessen eine stille Spiegelung. |
| Hängt die Projektion bei schneller Bewegung hinterher? | **Nein, sie ist die frischere von beiden.** Hinterher hängt die gemeldete Kamera. |

**1. `moveCamera` bricht ab, Vorrangregel 1 trägt.** Die Positionsspur: bei
593 ms steht die Kamera mitten im Flug auf 48.153743, der Sprung geht raus, bei
700 ms steht sie auf 48.126798, also exakt auf dem Sprungziel, und bleibt dort
bis zum Ende der Messung. Unabhängig davon liefert `animateCamera` bei 607 ms
`false` zurück, und das Paket sagt selbst „false if the movement was canceled"
(`controller.dart:409-416`). Der harte Reset durch Überschreiben funktioniert
also, obwohl es kein `stop()` gibt. **Gilt für Android. iOS ist nie compiliert
worden, und dort liefert `animateCamera` laut Paketdoku ohnehin immer `null`;
das zweite Signal fehlt dort also.**

**2. Die 200 ms `steeringGrace` sind reichlich bemessen.** Gemessen wurde die
Spanne zwischen dem eigenen `moveCamera` und der ersten Kamerarückmeldung, die
die Position wirklich ändert, fünf Läufe: 6,9 / 3,7 / 5,3 / 9,6 / 4,8 ms. Der
erste Lauf ist der langsamste, danach pendelt es sich ein. Das Fenster hat damit
rund den Faktor 20 Luft. **Was die Messung nicht zeigt:** einen Emulator ohne
Last. Auf einem belasteten Gerät kann die Spanne wachsen, und die Regel bleibt,
dass sie nur unterhalb von 200 ms tragen darf.

**3. Der gefährlichste Fund: hinter der Kamera wird still gespiegelt.** Zwei
Leitern entlang des Meridians, Bildschirmlage in Gerätepixeln.

> **Korrektur vom 30.08.2026, noch in derselben Nacht.** Die Spalte
> „Entfernung" ist gegen die **Startposition der Probe** gemessen, nicht gegen
> die Kamera: Messung 1 hatte die Kamera vorher um 0,02 Grad nach Süden
> gesprungen, also rund 2,2 km. Jeder Wert der Leiter ist damit um diese
> Strecke nach Norden verschoben, und der Zoom stand bei 14,94 statt 16,5. Das
> **qualitative** Ergebnis trägt trotzdem, weil es nur die Reihenfolge der
> Werte braucht: das Vorzeichen kippt, und danach läuft alles gegen denselben
> Fluchtwert. Die **Entfernungen** stimmen nicht. Richtig ist: der Umschlag
> liegt zwischen rund 1,2 km und 2,8 km hinter der Kamera. Wer eine genauere
> Grenze braucht, misst sie mit stehender Kamera nach.

| Entfernung | nach vorn (y) | nach hinten (y) |
|---|---|---|
| 0,1 km | 1533,23 | 1774,76 |
| 1 km | 815,38 | 3825,91 |
| 5 km | −215,73 | **−3241,45** |
| 20 km | −779,01 | −1391,32 |
| 100 km | −991,74 | −1112,72 |
| 500 km | −1038,86 | −1063,01 |
| 2000 km | −1047,95 | −1053,83 |

Nach vorn ist alles plausibel: der Wert wandert nach oben aus dem Bild und
läuft gegen etwa −1050, den Fluchtpunkt. **Nach hinten kippt das Vorzeichen
zwischen 1 und 5 km**, und ab da liegen die Werte in genau demselben Bereich wie
die weit vorne liegenden Punkte. Ein Punkt hinter der Kamera ist an seinen
Koordinaten allein **nicht** von einem weit voraus liegenden zu unterscheiden.
Es gibt kein `NaN`, keine Ausnahme und keinen Sonderwert, an dem ein Aufrufer
das erkennen könnte. Wer der Projektion glaubt, zeichnet ein Bauteil an eine
Stelle, an der es geometrisch nichts zu suchen hat.

Heute trifft das die App nicht, weil nur Punkte innerhalb von 150 Metern
gezeichnet werden und in dieser Nähe nichts hinter der Kamera liegen kann, was
nicht ohnehin sichtbar wäre. **Es trifft Schritt 18**, sobald der Avatar
geografisch verankert wird, und jeden künftigen Aufrufer der Projektion. Der
Vertrag braucht deshalb eine Aussage darüber, was ein Punkt hinter der Kamera
bedeutet, und die kann nicht aus dem Rückgabewert kommen.

**4. Die Projektion hängt nicht hinterher, die gemeldete Kamera tut es.** In
26 Stichproben über eine 1500-ms-Animation ändert sich die Bildschirmlage
mehrfach, **während `cameraPosition` unverändert bleibt**: bei 140 ms wandert
die Lage von 674,99 auf 441,93, die gemeldete Kameramitte steht beide Male auf
48.150798. Dasselbe bei 763 ms. Umgekehrt gibt es keinen einzigen Fall. Beide
Werte kommen über denselben Plattformkanal, aber `cameraPosition` ist ein in
Dart zwischengespeicherter Wert aus `onCameraMove` und wird nur alle 70 bis
140 ms nachgeführt, während `toScreenLocation` jedes Mal wirklich fragt.

**Die Folge ist eine Regel und kein Fehler:** wer eine Bildschirmlage mit der
gemeldeten Kamera **desselben Bildes** verrechnet, mischt zwei verschiedene
Zeitpunkte. Für die Näherungs-Animation ist das heute folgenlos, sie benutzt nur
die Projektion. Ein zweiter Verbraucher, der beides kombiniert, hätte einen
Fehler, den kein Test dieser Art fände.

**Was die Messung 4 ausdrücklich nicht kann:** sie trennt nicht, ob eine
Abweichung von der Projektion selbst kommt oder von der Latenz des
Plattformkanals, denn beide Werte werden nacheinander über denselben Kanal
geholt. Sie zeigt die Richtung des Unterschieds, nicht seine Ursache.

#### Ungefragter Fund A: `toScreenLocation` liefert Gerätepixel

`controller.dart:1779` sagt „screen pixels (not display pixels)", und
`map_surface.dart` hält seit Schritt 12 fest, dass dieser Satz beides heißen
kann. **Er heißt das Geräteraster**, und zwar mit dem Faktor genau und ohne
jeden Versatz.

**Belegt mit einer zweiten Probe, die die Kameramitte selbst projiziert.** Die
erste Fassung dieses Absatzes führte zwei Argumente, und das zweite war falsch
hergeleitet: es schätzte die Bildmitte als Mittelwert zweier Leiterpunkte, aber
bei geneigter Kamera ist dieser Mittelwert nicht die Mitte, und die Leiter lief
außerdem gegen eine Position, an der die Kamera nicht mehr stand. Das Ergebnis
stimmte, die Begründung nicht, und genau diese Sorte Begründung wird hier nie
nachgeprüft. Deshalb steht sie nicht mehr da.

Gemessen wird stattdessen die Abbildung selbst, alles aus einem Messsatz und
alles abgelesen statt geschlossen:

| Größe | Wert |
|---|---|
| Kartenfläche, logisch | 411,43 × 914,29, Ursprung im Fenster (0 \| 0) |
| Kartenfläche, Gerätepixel | 1080,00 × 2400,00, Skalierungsfaktor 2,6250 |
| Kameramitte projiziert auf | **(540,75 \| 1200,94)** Gerätepixel |
| Mitte der Fläche wäre | (540,00 \| 1200,00) Gerätepixel |
| dieselbe Lage geteilt durch 2,625 | (206,00 \| 457,50) logisch, Mitte wäre (205,7 \| 457,1) |

Die Kameramitte landet also in der Mitte der Fläche, und sie tut es **im
Geräteraster**. Damit sind Maßstab und Ursprung zugleich geklärt: der Faktor
ist der Skalierungsfaktor, ein Versatz existiert nicht, und `toScreenLocation`
bezieht sich auf die Kartenfläche und nicht auf das Fenster. Die
Restabweichung von unter einem Pixel ist die Rundung des SDK.

Zur Gegenprobe vier Punkte in 100 Metern Abstand, jeweils in logischen Pixeln
ab der Mitte: Osten +177,5, Westen −177,5, Norden −84,8, Süden +105,6. Die
Achsen sind sauber getrennt, und die kleinere senkrechte Strecke ist die
Neigung von 58 Grad, nicht ein zweiter Maßstab.

**Das widerspricht dem Eintrag vom 29.08.2026**, der aus einer Gegenprobe mit
und ohne Division durch 2,625 schloss, „der Code stimmt, wie er ist". Beide
Aussagen können nicht zugleich gelten. Die hier gemessene ist die direktere: sie
liest eine einzelne Zahl ab, statt zwei Bilder zu vergleichen, und genau dieser
Unterschied steht seit dem 29.08.2026 als Merksatz im Dokument.

**Die betroffene Stelle ist bekannt und benannt.**
`fact_balloon_overlay.dart` sagte wörtlich: „Ergibt eine Gerätemessung, dass
dort das Geräteraster liegt, gehört genau hier eine Division durch
`MediaQuery.devicePixelRatioOf(context)` hin, und nirgendwo sonst." Genau das
ist am 30.08.2026 passiert, von Janek freigegeben, weil es ändert, was der
Nutzer sieht. **Dass es nur eine Stelle war, war der Zweck des Aufbaus aus
Schritt 17 und hat sich ausgezahlt: die Behebung ist eine Zeile.**

#### Wie die Behebung geprüft ist, und warum kein Bild dabei gedeutet wird

Drei Prüfungen, und keine davon beruht auf einem Eindruck.

**1. Zwei Skalierungsfaktoren im Test statt einem.** Der Platzierungstest läuft
jetzt über 2,625 und 1,5. Mit nur einem Faktor wäre die Division durch eine
beliebige Konstante zu ersetzen, und der Test bliebe grün. Gesetzt wird über
`tester.view.devicePixelRatio` und nicht über eine eigene `MediaQuery`, denn
die läge unter der echten und wäre wirkungslos, siehe „Wie Tests hier blind
werden", Muster 11.

**2. Mutationsprobe, angelegt und wieder gelöscht.** Beide Divisionen entfernt,
Suite gefahren: **beide** Testfälle fallen, für 2,625 wie für 1,5. Danach
zurückgenommen.

**3. Die Gegenprüfung am Gerät, als Zahl gegen Zahl.** Der Emulator stand 80 m
südwestlich des Testfakts 3262, der damit innerhalb der 150 Meter lag und als
Flutter-Widget gezeichnet wurde. Die Probe hat die Projektion dieses Fakts
mitgeloggt: **(768,27 | 1059,30) Geräte-Pixel**. Ein Bildschirmfoto liegt im
selben Raster, die Zahl ist also direkt gegen das Bild prüfbar. Gemessen im
Foto: der Stielfuß mit seinem Bodenschatten sitzt bei **(768 | 1049)**. Die
x-Achse trifft auf unter einen Pixel, die zehn Pixel in y sind das Hüpfen des
nahen Ballons, das innerhalb seines Kastens läuft.

**Der eigentliche Beleg ist aber ein anderer, und er braucht gar keine
Genauigkeit:** ohne die Division stünde derselbe Ballon bei **logisch**
(768 | 1059), und die Kartenfläche ist logisch nur 411 × 914 groß. Er wäre
vollständig außerhalb und damit unsichtbar. Sichtbar war er trotzdem nie als
Fehler aufgefallen, weil ein fehlender Ballon aussieht wie ein Fakt, der eben
nicht in Reichweite ist.

#### Ungefragter Fund B: eine abgebrochene Flugbewegung lässt ihren Zoom stehen

Beim Abbruch aus Messung 1 blieb der Zoom auf 14,94 statt der 16,5 vom Anfang.
Ursache ist keine Eigenart des Abbruchs, sondern die Flugkurve: `animateCamera`
zoomt für eine weite Strecke erst heraus und dann wieder herein, und wer sie in
der Mitte abbricht, erwischt sie unten. Die Probe hat mit `newLatLng` nur den
Mittelpunkt überschrieben, der Zwischen-Zoom blieb.

**Die App ist davon nicht betroffen, und das ist gemessen, nicht angenommen:**
`MapLibreCameraDriver.updateFor` baut immer ein
`CameraUpdate.newCameraPosition` mit Mittelpunkt, Zoom, Blickrichtung und
Neigung. Jeder Sprung des Hosts setzt also eine **vollständige** Kamera und
räumt einen liegengebliebenen Zwischenzustand mit weg. Der Fund steht trotzdem
hier, weil er die Bedingung benennt, unter der Vorrangregel 1 trägt: sie trägt,
solange der harte Reset vollständig ist. Eine spätere Teiländerung an dieser
Stelle wäre lautlos falsch.

### Der Kartenstil am Gerät, 29.08.2026

Erster Gerätebuild **mit verdrahteter Karte**, Exit-Code 0. Das war nicht
selbstverständlich: `maplibre_gl` ist ab diesem Commit zum ersten Mal in `lib/`
wirklich importiert, und genau dieses Paket hat im Juli den Android-Build
zerlegt. Die KGP-Warnung dazu steht unter „`maplibre_gl` ist eine Zeitbombe im
Build".

**Gesehen über eine Wegwerf-Probe**, die nur die Kartenfläche mountet, ohne
Supabase und ohne Anmeldung: der gebackene Stil trifft. Grüne Grundfläche,
sattere Parks, fast weiße Fahrbahnen mit sandfarbenem Saum, flache
Klötzchen-Häuser mit Umriss, keine einzige Beschriftung. Der Attributions-Knopf
unten rechts ist da und lässt sich nicht abschalten.

**Der Gerätelauf der App selbst blieb blockiert**, nicht technisch: URL und
Schlüssel für Supabase kommen über `--dart-define` und stehen bewusst nicht im
Repository, ohne sie zeigt die App die Startfehler-Seite. Genau die hat einen
Fehler offenbart, und der Rundgang danach einen zweiten:

- **Gelbe Doppellinien** im Text der Startfehler-Seite. `MaterialApp(home:
  ColoredBox(...))` hat keinen `Material`-Vorfahren, und beide Textstile setzen
  Farbe und Größe, aber keine `decoration`, also überlebt die der Ersatzschrift
  den Merge. Kein Test hat es gefunden, weil `takeException()` leer bleibt: es
  ist kein Fehler, es ist Flutters absichtlich grelle Ersatzschrift.
- **Zweite Stelle, für Nutzer sichtbar:** der Audio-Aktivierungsdialog. Er ist
  eine eigene Route im Overlay, das `Scaffold` des Startbildschirms steht daneben
  und nützt ihm nichts, und `DialogRoute` bringt selbst kein `Material` mit.
- **Der Nebeneffekt der Behebung ist der Merksatz:** ein `Material` ohne eigenen
  `textStyle` vererbt `theme.textTheme.bodyMedium` an jeden Text darunter, der es
  nicht selbst setzt. Wer ein `Material` einzieht, um die Doppellinie
  loszuwerden, holt sich Materials Typografie ins Haus, wenn er den Basisstil
  nicht ausdrücklich hinschreibt.
- **Nachgemessen, und eine naheliegende Annahme fiel:** die **Laufweite** kommt
  **nicht** durch. `letterSpacing` ist unter dem `Material` überall `null`, auch
  vor der Behebung, weil E-38 in `ThemeData.typography` sitzt und `bodyMedium`
  deshalb schon keine Laufweite mehr trägt. Durchgekommen ist ausschließlich
  `height: 1.43`. Wer „Materials Typografie" liest, muss wissen, welcher Teil
  davon in dieser App noch scharf ist.

### Fundstellen des Karten-Chrome: 41 von 138 waren falsch

Ein vollständiger Rundgang über die zehn Chrome-Dateien und ihre Testdatei, am
29.08.2026. **138 Fundstellen, 41 falsch**, also fast ein Drittel. Nur
Kommentartext geändert, kein Verhalten, Testzahl unverändert 1198. Der Nachweis
ist nicht der grüne Lauf: `git diff -U0`, gefiltert auf Zeilen ohne `//`, ist
**leer**, und die Dateilängen sind unverändert.

**Warum das kein Aufräumen war.** Fundstellen sind hier Vertragsfläche, die
nächste Sitzung liest sie **statt** der Quelle. Eine falsche Angabe wird nie
nachgeprüft, weil sie sich als belegt ausgibt.

**Der Versatz war uneinheitlich**, ein bis drei Zeilen, mal zu hoch, mal zu
tief. Es gibt keine Formel, jede Angabe muss einzeln aufgeschlagen werden. An
drei Stellen zeigte die Angabe auf die schließende Klammer statt auf die
Eigenschaft. Eine Vermutung zur Ursache, **nicht belegt**: im Lese-Repo liegen
mehrere Arbeitskopien mit eigener `screen-map.jsx`; wer gegen eine andere als
die in `CLAUDE.md` benannte liest, bekommt genau so einen wandernden Versatz.

**Zwei Funde sind keine Zahlen, sondern Aussagen**, und deshalb stehen
geblieben: `actBg` und `actText` zeigen buchstäblich richtig auf ihre
**Verwendungsstelle**, die Farbwerte selbst stehen sieben Zeilen höher. Und eine
Zahl trägt zwei Aussagen, von denen nur eine stimmt. Beides ist eine
Formulierungsfrage und gehört in einen eigenen Durchgang.

### Schritt 19 wurde vorgezogen

Das Top-Chrome des Kartenbildschirms entstand **vor** Schritt 12, weil dieser an
einer Architekturentscheidung hing und das Chrome über der Karte davon nicht
abhängt. Damit wurden **sieben von neun Tutorial-Schritten** voll baubar statt
vier (Korrektur 13 beschreibt den Stand davor). Dazu kamen vier neue Regeln ins
Prüfskript, die `lib/map/` bewachen, bevor es entsteht.

**Widerspruch, nicht geglättet:** das Kästchen in der Liste unten steht trotzdem
auf offen, `HANDOFF.md` meldet den Schritt seit dem 28.08.2026 als fertig. Wer
das nächste Mal an Phase 2 arbeitet, prüft, ob noch etwas fehlt, und setzt genau
eine der beiden Stellen richtig.

- [x] 12. MapLibre mit gebackenem Style · [x] 13. Kamera-Verhalten
- [!] 14. Kompass-Rotation (Sensorpaket fehlt) · [x] 15. Cluster-Layer
  · [x] 16. Einzel-Marker
- [x] 17. Münz-Proximity-Animation · [!] 18. 3D-Avatar (WebView-Entscheidung)
- [x] 19. Top-Chrome (vorgezogen, D-5 am 29.08.2026 abgeschlossen) · [ ] 20. Sammel-Erlebnis

## Phase 3, Fakt-Akte und Audio

### Schritt 21, was daran gemessen ist

Der größte einzelne Bildschirm des Neubaus bis hierher. 1421 → 1540 Tests, 41
plus 19 Mutationen, alle gefallen.

- **Der Zuschnitt kam aus einer Produktregel, nicht aus dem Plan.** Ein
  Ballon-Tipp führt **nicht** in die Akte: innerhalb von 150 Metern löst er das
  Sammeln aus, außerhalb zeigt er nur eine Mini-Kachel. Der Grund steht als
  ausdrücklicher Fix in der Quelle (`screen-map.jsx:2137-2142`): „ohne GPS NIE
  die Fakt-Detail-Seite direkt oeffnen. Sonst koennte man durch Antippen aus
  1000 km Entfernung einen Fakt ‚lesen'". Es gab dort ein Schlupfloch, und ein
  Nutzer in Italien bekam einen München-Fakt vollständig angezeigt.
- **Die Akte ist deshalb ohne Einstieg gebaut**, und ein Test bewacht das: er
  durchsucht `lib/` nach der Route und fällt, sobald jemand einen Einstieg legt.
  Die Regel steht wörtlich an der Route. Öffnen darf sie erst Schritt 20.
- **Die Akte zeigt eine andere Kategoriefarbe als die Karte, und das ist
  Parität.** Die Quelle hat dort eine eigene, kleinere Tabelle
  (`screen-fact.jsx:245-249` gegen `KAT_MAP`), und für `kult`, `dark` und
  `kirche` gibt es in den erzeugten Sprachtabellen **gar keinen**
  `cat.`-Eintrag; wer die große Tabelle einsetzt, zeigt dem Nutzer den nackten
  Schlüssel. Sichtbare Folge: ein „Persönlichkeiten"-Fakt ist auf der Karte pink
  und in der Akte rot.
- **Zwei Anzeigefehler der Quelle sind nicht mitportiert.** Ohne Ortung schreibt
  sie buchstäblich „null entfernt" in die Pille, weil JavaScript das `null` in
  den String schreibt (`:395`), und der Ortsname hat „Passau" als fest
  verdrahteten Ersatzwert (`:394`), was der Mehrstädtigkeit widerspricht. Gebaut
  ist der Text, den die Quelle an derselben Bedingung wenige Zeilen später selbst
  wählt.
- **Zwei Sprachschlüssel über die Ergänzungs-Map (E-39)**, beide wortwörtlich
  aus der Quelle: `fact.fileNumber` steht in **beiden** Sprachkarten deutsch,
  weil die PWA „Akte #7" auch im englischen Modus so zeigt, genau wie
  `tour.step9.meta`. `fact.sourceMissing` hat in der Quelle beide Sprachen.
- **Aufräumarbeit, die Voraussetzung war:** `css_gradient_geometry.dart` ist von
  `features/identity/presentation/widgets/` nach `lib/core/widgets/` gezogen. Die
  Datei trug den Vermerk „sobald ein zweiter Bildschirm dieselbe Umrechnung
  braucht, zieht diese Datei um", und `project-structure.md:200` nennt genau
  diese Bedingung.

- [x] 21. Fact-Detail-Sheet · [ ] 22. Collect-Reveal-Overlay
- [ ] 23. Akte-Interaktion · [ ] 24. Damals/Heute · [!] 25. Audio-Service (TTS-Weg)
- [ ] 26. Map-Audio-Kopplung

## Phase 4, Rätsel-Engine

### Schritt 27, was daran gemessen ist

1554 → 1625 Tests. Gebaut ist der typisierte Rätselvertrag und der Rahmen des
Sheets, **ohne jeden Einstieg**, wie die Fakt-Akte in Schritt 21.

- **Der Zuschnitt ist gemessen und nicht abgeleitet.** Zwei Wegwerf-Proben,
  angelegt, ausgeführt, gelöscht: `puzzles/domain` mit einem Import aus
  `facts/domain` bricht den Architektur-Check mit **Exit-Code 1** ab, genau eine
  Meldung („Domain-Erlaubnisliste"); derselbe Import aus `puzzles/application`
  läuft auf **Exit-Code 0** durch und `dart analyze` bleibt sauber. Deshalb
  liegt der Übersetzer in `application` und ist die **einzige** Datei des
  Features, die `FactPuzzle` kennt.
- **Der naheliegende Entwurf wäre falsch gewesen.** Eine versiegelte Klasse,
  deren Auswahl an `type` hängt, trifft die Quelle nicht: `puzzle-sheet.jsx:247`
  liefert bedingungslos die Auswahlform, sobald Antwortoptionen vorliegen, und
  zwar **bevor** `type` gelesen wird; erst danach kommt `switch` ab `:250` und
  ein ausdrücklicher Standardzweig bei `:270`. Der Kommentar der Quelle
  (`:243-246`) nennt den Grund selbst: der Typ wird im Konverter geraten und
  trägt das mcq-Signal nicht zuverlässig.
- **Der Standardzweig ist der Mengenschwerpunkt, keine Ausnahme.** Von elf
  Typwerten der Live-Daten kennt die Tabelle der Quelle sechs nicht, zusammen
  1469 Vorkommen (`fact_puzzle.dart:88-93`). Eine Aufzählung über `type` hätte
  sie verworfen oder umbenannt.
- **Zwei Typkopien, und das ist D-9 zum zweiten Mal.** `PuzzleDifficulty` und
  `PuzzleOperand` entstehen wortgleich neu, weil Gate 6 die Domäne sperrt.
  Beide tragen den Verweis im Kopfkommentar. Nachtrag bei D-9.
- **Der teuerste Fund der Review war eine Wache mit einem Loch.** Die
  Einstiegs-Sperre schnitt jede Zeile ab dem ersten `//` ab, um ihren eigenen
  Kommentar nicht zu finden. Damit war sie umgehbar: ein Konstruktoraufruf muss
  nicht **in** einer Zeichenkette stehen, sondern nur dahinter auf derselben
  Zeile, ein Kartenschlüssel `'//r':` reicht. Die Probe kam durch Format,
  Analyzer, Architektur-Check **und** die Wache. Nach der Behebung meldet die
  Wache genau diese Datei, während der Architektur-Check im selben Zustand
  weiter auf 0 durchläuft: **hier ist der Test die Regel und nicht die
  Maschine**, zum zweiten Mal gemessen nach E-27.
- **Elf Mutationen an der Optik überlebten die erste Fassung**, darunter die
  hergeleitete Verlauf-Endfarbe, der Schimmer, die Lichtkante und alle drei
  Zierkreise. Nach einem Bildtest der Marken-Blase fallen **elf von elf**.
  Gemessen wird dabei die gezeichnete Fläche und nicht das Rechteck, siehe
  Muster 4.
- **Zwei neue Blindstellen sind beim Bauen selbst entstanden**, beide jetzt als
  Muster 18 und 19 festgehalten: eine Zusicherung gegen die Konstante, die sie
  festnageln soll, und `toImage()`, das im Rumpf von `testWidgets` bis zur
  Zeitüberschreitung hängt.
- **Vier hartcodierte Texte der Quelle** kommen über die Ergänzungs-Map aus
  E-39: Stationszeile, Rätselüberschrift, die Beschriftung „Aufgabe" und die
  Bildunterschrift des Zeitreise-Fotos. Der Gedankenstrich in
  „Damals — was hat sich verändert?" bleibt stehen, weil es Text der
  Verhaltensquelle ist und keiner, den wir schreiben.

- [x] 27. Puzzle-Sheet mit vollem Mapping · [!] 28. Alle Rätseltypen
  (sprachneutrale Auswertung) · [ ] 29. In-Puzzle-Hint · [ ] 30. Reveal-Screen
- [!] 31. Hinweis-Ökonomie (Reward-Ledger) · [!] 32. Punkte gegen Coins

## Phase 5, Challenge

### Schritte 33 und 34, was daran gemessen ist

Zusammen gebaut, weil sie in der Quelle **derselbe Bildschirm** sind: der
Assistent hält seine Schritte selbst, Schritt 1 ist die Solo- und Gruppenwahl,
Schritt 2 sind Schwierigkeit, Dauer und Genres, und der Generator hängt am
Ausgang von Schritt 2. 1625 → 1725 Tests.

- **Der grösste Fund kam vor dem Bau und betrifft den Plan, nicht den Code.**
  Die Solo-Jagd läuft in der Quelle auf der **Karte**, nicht im Challenge-Reiter.
  Damit beschreiben die Plan-Schritte 36 und 37 den Demo-Pfad. Steht als E-43,
  und deshalb endet dieser Block nach 34 statt nach 37.
- **Der Generator löst D-9 nicht zum dritten Mal aus.** Zwei Wegwerf-Proben:
  `challenges/domain` mit Importen auf `facts/domain` **und** `map/domain`
  bricht mit **Exit-Code 1** und zwei Verstössen ab, dieselben zwei Importe aus
  `challenges/application` laufen auf **0** durch. Er benutzt deshalb die
  vorhandene Haversine-Rechnung aus `map/domain/map_position.dart`, und es
  entsteht kein vierter Koordinatentyp. Der Preis ist eine andere Ausnahme,
  Datenklassen in `application`, dritter Nachtrag bei D-9.
- **Drei der vier Auswahlstufen des Generators laufen im echten Bestand nie.**
  `confidence` steht durchgehend auf `curated`, `quality` und `findability`
  kommen im ausgelieferten Bestand gar nicht vor; gemessen in Schritt 5, zitiert
  in `fact_puzzle.dart`. Die Stufen sind trotzdem gebaut, weil die Pipeline die
  Felder setzen kann, und jede trägt den Vermerk, dass sie heute kein Nutzer
  erreicht.
- **Eine vierte tote Stelle, diesmal in der Quelle selbst.** Die gestufte
  Auswahl der ersten Station trägt den Kommentar „FIX (Daniel-Feedback): erste
  Station muss nah am Startpunkt sein" und **kann das Ergebnis nicht ändern**:
  die Liste ist aufsteigend sortiert, die beiden engeren Stufen sind
  Anfangsstücke davon, genommen wird immer das erste Element. Alle drei Zweige
  liefern denselben Kandidaten. Nachgerechnet und bestätigt. Der Nachbau lässt
  die Stufung weg und trägt den Beweis im Kommentar, mit dem Satz, dass drei
  Zweige, die kein Test trennen kann, drei Zweige sind, die niemand prüft.
- **Auch der Zufallszweig ist unerreichbar**, weil die einzige Aufrufstelle des
  Generators immer einen Startpunkt übergibt. Gebaut ist er trotzdem, sonst wäre
  der Generator vor Schritt 35 gar nicht prüfbar; der Vermerk steht dran.
- **Die Themenrouten sind ganz herausgefallen, und das ist Parität.** Sie sind
  eine kuratierte Datendatei nach deutschem Stadt-Anzeigenamen verschlüsselt,
  mit den Texten in den Daten statt in den Sprachtabellen, und der Tourplaner
  benutzt sie mit. Ihr Ort ist damit eine feature-übergreifende Frage und
  berührt E-11. Ausschlaggebend war aber die Quelle selbst: sie blendet den
  ganzen Routenblock aus, wenn eine Stadt keine kuratierten Routen hat. Was
  dasteht, ist also der vorgesehene Zustand und kein Platzhalter. Gemessen
  nebenbei: das `stopCount` einer Route liest der Generator nirgends, es gewinnt
  die Stationszahl aus der Dauer. Der Tourplaner liest es sehr wohl, es ist also
  keine Altlast.
- **Die Review hat 51 Mutationen gefahren, 22 haben überlebt**, davon vier
  verhaltenswirksam: die Bonuswerte des Scorings waren nur in ihrer **Richtung**
  geprüft, nie in ihrem **Wert**. Sie sind jetzt gegen ihre Kippgrenze
  eingegrenzt, jeweils mit einem Test „gewinnt" und einem „verliert", und die
  Grenzen stehen als Intervall im Kommentar. Dazu der Genre-Code, der gegen
  `facts.genre` in der geteilten Datenbank läuft und dessen Tippfehler still
  ausfiele. Nach der Behebung fallen alle dreizehn benannten Mutationen.
- **Der teuerste Einzelfund war wieder eine Begründung, nicht Code.** Der
  Kommentar am umgezogenen Knopf behauptete Regel 10 und dass das Prüfskript
  den Verstoss nicht meldet. Es ist Regel 8, und das Skript bricht mit
  Exit-Code 1 ab. Zweimal unabhängig gemessen. Die Schlussfolgerung stimmte,
  der Weg dorthin nicht. Siehe E-35.

### Schritt 35, was daran gemessen ist

1729 → 1813 Tests. Der Picker schliesst den Ausgang des Assistenten an: „Starten"
führt jetzt in ihn, und er ruft den Generator aus Schritt 34.

- **Er braucht keine Karte, und das ist gemessen.** `HotspotPickView` ist eine
  Liste mit höchstens vier Radioknöpfen; die zwei `map`-Treffer darin sind
  `Array.map`. Die Regel aus Schritt 12, dass ein Feature den Karten-Host nie
  selbst mountet, ist gar nicht berührt, und am Kameravertrag fehlt nichts.
- **Zwei verschiedene Dichten, nicht eine.** Für „Hier wo ich bin" werden Fakten
  im Umkreis von 600 Metern gezählt, für die Hotspots wird das Feld `density`
  gelesen. Beide Wege ergeben eine Beschriftung „Hohe Faktendichte", aber mit
  verschiedenen Zeichen, `✓` gezählt und `💎` gelesen. Wortgleich übernommen und
  als zwei getrennte Werte modelliert.
- **Die kuratierten Datendateien haben jetzt ein Muster statt einer Lösung.**
  `tool/generate_curated_data.dart` liest die PWA direkt, schreibt eine
  eingecheckte Dart-Datei und meldet mit `--check` Drift. Es trägt eine
  **Registrierung**: `wallet-colors.jsx`, `hunt-routes.jsx`, `damals-heute.jsx`
  und `city-intros.jsx` kosten je einen Listeneintrag, kein zweites Werkzeug.
  Fünf Werkzeuge mit fünf Aufrufen vergisst nach dem dritten Mal jemand.
- **E-11 kostet damit eine Stelle statt zehn.** Die erzeugte Tabelle trägt den
  Schlüssel wörtlich wie die Quelle, normalisiert wird über `FactCity.slug`. Der
  Stadtname geht nirgends als roher String durch. Nebenbei belegt: es sind
  **drei** Schreibweisen im Umlauf, nicht zwei, denn `wallet-colors.jsx` nimmt
  Kleinschreibung mit Umlauten.
- **Der lehrreichste Teil sind die zwei Mutationsläufe.** Der Bauende fuhr zwölf
  Mutationen, zwölf fielen. Die Review fuhr zwölf andere, **zwölf überlebten**.
  Wer seine eigenen Zusicherungen mutiert, misst, wie gut er getroffen hat, was
  er ohnehin im Blick hatte; erst ein fremder Blick misst, was fehlt. Nach der
  Nachbesserung fallen alle zwölf, dazu zwei Lücken, die beim Messen auffielen.
- **Der schwerste Fund war eine Wiederholung von Schritt 15.** Die Faktenliste
  der Kartenüberlagerung auf leer zu setzen liess **kein einziges Fakt** auf der
  Karte erscheinen, bei 1792 grünen Tests. Dieser Block hatte genau diese Ebene
  angefasst, mit der Begründung „sichtbar ändert sich nichts", die stimmte und
  nirgends belegt war. Belegt ist sie jetzt: gemessen bleibt die Wiederholkette
  bei elf Repository-Aufrufen, vorher wie nachher.
- **Eine Grenze liess sich nicht so prüfen, wie sie dasteht.** Der 600-Meter-Fall
  ist mit einem Punkt „genau 600 Meter nördlich" nicht messbar, weil die
  Umrechnung real 599,9999999999262 Meter ergibt und die Zusicherung dann mit
  `<=` **und** mit `<` grün wäre. Geprüft wird deshalb gegen die gemessene
  Entfernung selbst.

- [x] 33. Wizard · [x] 34. Solo-Setup · [x] 35. Hotspot-Picker
- [!] 36. Phasen-Maschine (E-43 entschieden, wartet auf D-16) · [!] 37. Active-UI (dito)
  · [!] 38. Rätsel und Ökonomie
- [ ] 39. Pause und Results · [!] 40. Gruppen-Flow (Realtime-Entscheidung)

## Phase 6, Tour

- [!] 41. TourSetupSheet · [!] 42. Route (OpenRouteService) · [ ] 43. HUD
- [!] 44. Hint und Rätsel

## Phase 7, Reiseführer und Profil

- [ ] 45. Library · [ ] 46. Cover und Illustrationen · [!] 47. Chapters und
  Reader („Frag Claude") · [ ] 48. Leaderboard · [ ] 49. Trophäen

## Phase 8, Abschluss

- [!] 50. Creator (Foto-Storage) und Paritäts-Sweep

## Arbeit außerhalb der 50 Schritte

Nicht im REBUILD_PLAN, aber notwendig:

- [x] **Lint-Pflicht in den Dokumenten angepasst.** `quality-gates.md`,
  `architecture-overview.md` §16 und `engineering-principles.md` führen
  `riverpod_lint` nicht mehr als erfüllbare Pflicht, sondern als begründete
  Abweichung mit prüfbarer Wiederaufnahme-Bedingung. ADR-003 bleibt bewusst
  unberührt: dort steht die Aussage in den Konsequenzen, nicht in den Regeln.
- [x] **Architektur-Gegenüberstellung.** Parity-Spec gegen die fünf ADRs,
  Domain-Map und Dependency-Rules. Ergebnis: 21 offene Entscheidungen, unten
  die noch offenen davon.
- [x] **`tool/check_architecture.dart`.** Die neun Prüfungen aus
  `docs/engineering/quality-gates.md`. Ersetzt teilweise `riverpod_lint`, das
  nicht auflösbar ist.
- [x] **Aufarbeitung der ersten Review.** Neun verifizierte Erkennungslücken im
  Architektur-Check geschlossen, das Skript von 371 auf 989 Zeilen mit einem
  eigenen Scanner, der Kommentare und String-Literale maskiert. Token-Paare
  getrennt, erfundener Schattenwert entfernt.
- [x] **Testabdeckung für `tool/check_architecture.dart`.** 53 Black-Box-Tests
  in `test/tool/`, die das Skript als Prozess gegen temporäre Bäume prüfen,
  vier Prozessaufrufe, rund 6 Sekunden. Mit Mutationsproben belegt: eine
  absichtlich blind gemachte Prüfung macht die Suite rot.
- [x] **Sechs weitere Lücken im Architektur-Check geschlossen.** Schichtmuster
  greifen jetzt auch bei verschachtelten Feature-Strukturen (vorher fielen
  `features/x/unterstruktur/domain/` komplett aus allen Prüfungen). Die Domäne
  hat eine **Erlaubnisliste** statt einer Verbotsliste, und die Liste ist
  derzeit leer, weil kein Paket aus `pubspec.yaml` qualifiziert. Regel 7 gilt
  auch in `application`, `presentation` darf nicht auf das eigene `data`
  zeigen, `integration_test/` wird mitgelesen, und `presentation` wird auch
  außerhalb von `features/` geprüft.
- [x] **Echte Schriften in Widget-Tests.** `test/support/app_fonts.dart`.
  `flutter test` lädt die Schriften aus `pubspec.yaml` nicht und zeichnet jede
  Glyphe als Quadrat der Schriftgröße. Jede Maß- und Überlaufprüfung hat
  vorher ein Layout geprüft, das es auf keinem Gerät gibt: „FACT" in Nunito
  Black 64 belegt dort 256 statt 166 Pixel, und die Knopfzeile des Audio-Dialogs lief schon bei
  Skalierung 1.0 um. Aufruf **nur aus `setUpAll`**, im Rumpf von `testWidgets`
  hängt `FontLoader` in der `FakeAsync`-Zone. Bytes werden synchron gelesen und
  in ein `SynchronousFuture` gepackt, `rootBundle` funktioniert nicht, weil
  Schriften in `FontManifest.json` stehen und nicht im Asset-Manifest.
- [x] **`reportDetached` für abgekoppelte Arbeit.**
  `lib/core/async/detached_work.dart`. `docs/engineering/flutter.md:151`
  verlangt „an explicit helper **and error reporting**"; drei Aufrufstellen
  hatten nur den Helfer. Ohne Meldung heißt ein gescheiterter Schreibvorgang:
  Zustand sagt `true`, Speicher sagt `false`, nach dem Neustart ist die
  Einstellung weg, und nirgends liegt eine Spur.
- [ ] **Der Provider in `features/facts/data/` ist eine Sackgasse, und sein
  Kommentar behauptet das Gegenteil.**
  `lib/features/facts/data/repositories/supabase_fact_repository.dart`
  deklariert `factRepositoryProvider` neben der Implementierung und schreibt
  dazu, Widgets und Notifier lesten „diesen Provider". Genau das können sie
  nicht: `presentation → data` wird von `tool/check_architecture.dart` als
  Regel 17 gemeldet. Dasselbe gilt für `factRemoteDataSourceProvider`.
  Es ist **kein** Regelverstoß, weil es heute nur die App-Komposition liest,
  aber es ist ein Kopiervorbild mit falscher Begründung. Der Weg, der
  funktioniert, steht seit Schritt 9 in `lib/features/identity/`: Vertrag in
  `domain/repositories/`, Provider auf den Vertrag typisiert in
  `presentation/notifiers/`, Implementierung per Override aus `bootstrap.dart`.
  Behebung gehört zu dem Schritt, der `facts` an die Karte hängt, nicht
  hierher. Die Regel dahinter ist mit E-32 seit dem 28.08.2026 geklärt, siehe
  unten; offen ist nur noch diese Fundstelle.
- [ ] **Quellprüfung im i18n-Generator für unbekannte Schlüssel.** `t('...')`
  im JSX ohne Eintrag im Wörterbuch ist für `tool/generate_i18n.dart` heute
  unsichtbar; die Prüfung liest nur die beiden Wörterbuchdateien. Genau diese
  Lücke hat `audio.dialog.volumeHint` (E-28) durchgelassen, gefunden wurde er
  von Hand. Eine Prüfung wäre billig und deckt die ganze Fehlerklasse ab.
  **Nicht mit E-39 erledigt:** die dort ergänzte Gegenprüfung läuft in die
  andere Richtung, sie meldet Ergänzungs-Schlüssel, die es in der PWA
  inzwischen gibt. Ein `t('...')` ohne Wörterbucheintrag sieht sie nicht.
- [ ] **Gate für generierten Code fehlt.** `docs/engineering/quality-gates.md`
  nennt `tool/check_generated_code.dart`, das Skript existiert nicht. Ein
  veralteter `*.g.dart`-Stand fällt heute nur auf, wenn jemand zufällig
  `build_runner` startet. Am 27.08.2026 einmal von Hand geprüft: ein frischer
  Lauf erzeugt `app_routes.g.dart` byteidentisch.
- [ ] **Drei verbleibende Asymmetrien im Architektur-Check.** Erstens ist die
  Cross-Feature-Prüfung flach: ein fremdes `features/x/unterstruktur/data/`
  entkommt den Regeln 8 und 9, während dieselbe Verschachtelung für die
  eigenen Schichten geschlossen ist. Zweitens hat `application` weiter nur
  eine Verbotsliste. Letzteres setzt eine Aussage voraus, was „narrowly
  scoped Core" konkret bedeutet, und die fehlt in `dependency-rules.md`.
  Drittens hängt **Regel 17** (`presentation` zeigt nicht auf `data`, auch
  nicht auf das eigene) weiter an `_pointsIntoOwnFeatureLayer` und damit an
  `lib/features/`: ein `lib/map/presentation/` auf `lib/map/data/` wird nicht
  gemeldet, am 28.08.2026 mit einer Wegwerf-Probe gemessen. Heute nicht
  auslösbar, weil es außerhalb von `lib/features/` kein `data/` gibt, und
  spätestens fällig, wenn der Karten-Host eines bekommt. Die Behebung ist
  dieselbe Ableitung über `_modulwurzel`, die für die Domäne schon dasteht;
  bewusst nicht mitgemacht, weil der Auftrag vom 28.08.2026 vier benannte
  Regeln umfasste und diese nicht.
- [x] **Zwei gemessene blinde Flecken im Architektur-Check geschlossen**
  (28.08.2026). `_domainPath`, `_applicationPath` und `_dataPath` verlangten
  das Literal `lib/features/`, nur `_presentationPath` war allgemein: eine
  Datei `lib/map/domain/x.dart` mit Flutter-, Riverpod- und Supabase-Import
  passierte das Gate, dieselben Importe unter `lib/features/` wurden gemeldet.
  Und die Regeln 8 und 9 brachen bei `if (ownFeature == null) continue;` ab,
  womit jedes Modul außerhalb von `features/` auf fremde Presentation und
  fremdes Data zugreifen durfte. Beides am 28.08.2026 an Wegwerf-Dateien
  gemessen, nicht vermutet. **Dazu gehört untrennbar `_modulwurzel`:** ohne
  sie meldet die Erlaubnisliste der Domäne, die nur „eigenes Feature" kannte,
  in einem Modul außerhalb von `features/` jeden modulinternen Import als
  Verstoß.
- [ ] **Der dritte gemessene blinde Fleck ist offen: die Karten-SDK ist
  außerhalb des Hosts frei.** `import 'package:maplibre_gl/maplibre_gl.dart'`
  in `lib/features/discovery/presentation/` passiert das Gate mit Exit-Code 0,
  am 28.08.2026 **nach** allen Regeländerungen desselben Tages erneut
  gemessen. Das Verbot bei den Domänen-Bans gilt nur der Domäne. Regel 18
  schließt die Lücke nicht: sie hält Features aus `map/presentation/` heraus,
  nicht aus dem Paket. Die Behebung hätte genau die Form von Regel 19,
  nämlich `maplibre_gl` nur unterhalb `lib/map/`, und wäre heute risikofrei,
  weil das Paket in `lib/` an keiner Stelle importiert wird. Nicht gebaut,
  weil der Auftrag vier benannte Regeln umfasste und diese nicht; das ist
  eine Entscheidung, keine Auslassung aus Versehen.
  **Widerspruch, ungeprüft:** die Protokolleinträge vom 29.08.2026 setzen
  `maplibre_gl` als **Regel 20** voraus („nur unterhalb `lib/map/`") und nennen
  sie erprobt. Entweder ist dieser Punkt seit dem 28.08.2026 erledigt und das
  Kästchen falsch, oder die Regel deckt etwas anderes ab. Wer als Nächstes am
  Prüfskript arbeitet, misst es und schließt den Punkt.
- [x] **Regel 21: `geolocator` bekommt ein Heimatverzeichnis** (29.08.2026). Das
  Paket gehört maschinell nach `lib/services/location/` und nirgendwo sonst.
  Vorher durfte **jedes** Verzeichnis unterhalb von `lib/` außer einem
  `domain/`-Segment es importieren, mit sieben Wegwerf-Proben vermessen;
  `shared_preferences` verhält sich bis heute identisch. Im Bestand ändert die
  Regel nichts, es gibt genau einen Import und der liegt richtig. Keine neue
  Entscheidung, sondern die Durchsetzung einer akzeptierten: `domain-map.md:153-156`
  führt den `geolocation provider` unter „not business domains". Der
  Präzedenzfall steht im Skript: **Regel 19 entstand, bevor `webview_flutter`
  überhaupt im Projekt war**, weil „hinter einer klaren Schnittstelle kapseln"
  ohne so eine Zeile nur eine Absichtserklärung ist. **Das Verbot trifft die
  ganze Paketfamilie** (`^package:geolocator`), weil `Position` und
  `LocationAccuracy` in `geolocator_platform_interface` liegen; ein Verbot nur
  auf den Hauptnamen ließe den naheliegendsten Umweg offen.
  Drei Funde am Rand, alle behoben: *Regel 20 stand nie im Dokument*, sie
  existierte seit dem 28.08.2026 ausschließlich im Skript, und
  `dependency-rules.md` beschreibt genau diesen Fehler bei Regel 17 selbst
  („The strictest rule of the project existed in a script and in no document,
  which is the wrong way round."); jetzt stehen 20 und 21 dort. *Regel 19
  meldete in einer Domäne doppelt*, weil `_ausserhalbAvatarHome` die
  Domänen-Ausnahme nicht trug und `webview_flutter` in keinem `_domainBans`
  stand, und in einer Domäne wäre die Regel-19-Meldung sogar **irreführend**,
  weil sie auf `lib/map/presentation/avatar/` verweist, wohin eine Domäne nie
  zeigen darf. *Regel 4 war im Dokument enger formuliert als im Skript*, das
  Dokument nannte „routing, storage or analytics", das Skript hatte längst
  Karten-, Geräte- und WebView-SDKs darunter.
- [ ] **Vier bewusst offene Lücken**, je mit Begründung im Skript und einem
  Test, der den heutigen Zustand festhält: benannte Konstruktoren umgehen
  Regel 7, Direktiven werden nur am Zeilenanfang erkannt, `.go(variable)`
  wird nicht gemeldet, und Regel 10 (Cross-Feature nur über öffentlichen
  Vertrag) bleibt Review-Sache, weil am Text nicht unterscheidbar ist, ob ein
  Import den Vertrag nutzt oder umgeht.
- [ ] **CI-Workflow.** `.github/workflows/` existiert nicht. Kein Gate läuft
  automatisch. `quality-gates.md` ruft zusätzlich
  `tool/check_generated_code.dart`, das es noch nicht gibt.
- [x] **Standort-Permissions.** `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION` und `INTERNET` in `AndroidManifest.xml`,
  `NSLocationWhenInUseUsageDescription` in `Info.plist`, Texte aus dem alten
  Port übernommen. Beide Dateien nach der Änderung als valides XML bzw.
  Property-List geparst. **Bewusst nur Vordergrund-Standort.** Hintergrund,
  Kamera, Fotos, Mikrofon und Sensoren folgen je mit dem Paket, das sie
  braucht, damit die Berechtigungsliste nicht vor den Features herläuft.
- [x] **App-Name.** `android:label`, `CFBundleName` und `CFBundleDisplayName`
  stehen auf „FACT".
- [x] **Schrift-Lizenzen.** `OFL-Nunito.txt`, `OFL-DMSans.txt` und
  `OFL-JetBrainsMono.txt` liegen in `assets/fonts/`, aus den offiziellen
  Repositories geholt und am Inhalt als OFL-Text bestätigt.
- [x] **Generierte Dateien werden versioniert.** `*.g.dart` und
  `*.freezed.dart` stehen nicht mehr in `.gitignore`. Grund: ADR-004 verlangt
  generierte typisierte Routen, und ohne CI-Workflow, der vorher
  `build_runner` fährt, ließe sich ein frischer Klon nicht kompilieren. Die
  Entscheidung kann neu bewertet werden, sobald CI existiert.
- [x] **PR-Vorlage.** Die nicht abhakbare Checkbox „Custom lint" ist durch das
  Architektur-Skript ersetzt.

## Paket-Abweichungen von der Planliste

| Paket | Stand | Grund |
|---|---|---|
| `provider` | **nicht aufgenommen** | ADR-003 verlangt Riverpod 3 |
| `riverpod_annotation`, `riverpod_generator` | **nicht aufgenommen** | nicht gleichzeitig mit `go_router_builder` auflösbar; ADR-004 verlangt letzteres, Riverpod-Codegen ist optional. Provider werden manuell geschrieben. |
| `riverpod_lint`, `custom_lint` | **nicht installierbar** | `riverpod_lint 3.1.8` verlangt `analyzer ^13.0.0`. `flutter_test` aus dem SDK pinnt `test_api 0.7.11`, was `test` in `analyzer >=8.0.0 <13.0.0` zwingt; der Ausweg über ältere `test`-Versionen ist durch `supabase_flutter` → `supabase 2.16.1` → `realtime_client 2.13.0` → `web_socket_channel ^3.0.3` versperrt. Zusätzlich kollidieren `analyzer_plugin ^0.14.0` gegen `^0.13.0`. Vier Auflösungsversuche verifiziert. |
| `webview_flutter`, `flutter_compass`, `sensors_plus`, `flutter_tts`, `audioplayers`, `image_picker`, `share_plus`, `qr_flutter` | **noch nicht aufgenommen** | kommen phasenweise, jeweils mit Freigabe |

`docs/engineering/quality-gates.md`, `architecture-overview.md` §16 und
`engineering-principles.md` fordern `riverpod_lint` als Pflichtbasis. Diese
Dokumente beschreiben derzeit einen unerreichbaren Zustand und werden mit
Begründung und Wiederaufnahme-Bedingung angepasst.

### `maplibre_gl` ist eine Zeitbombe im Build, mit Ansage

Der erste Gerätebuild **mit verdrahteter Karte** lief am 29.08.2026 auf
Exit-Code 0, und er meldet dabei wörtlich:

> Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
> maplibre_gl. **Future versions of Flutter will fail to build** if your app
> uses plugins that apply KGP.

Das ist dieselbe Bruchstelle wie beim Paketkonflikt vom 27.08.2026, nur von der
anderen Seite gesehen. `0.27.0` braucht `android.builtInKotlin=true`,
`app_links` braucht `false`, und `0.26.2` wendet KGP an, was künftige
Flutter-Versionen ablehnen. **Ein Flutter-Update bricht den Build absehbar**,
nicht diffus irgendwann.

Zu tun ist heute nichts, aber wer Flutter aktualisiert, muss zuerst hier
nachsehen. Der Ausweg wird sein, dass `maplibre_gl` eine Fassung mit
Built-in-Kotlin bekommt; dann ist zu prüfen, ob der `app_links`-Konflikt
dabei mit verschwindet.

## Fragen an Dairen, gestellt und unbeantwortet

Am 29.08.2026 als Block verschickt, seither ohne Antwort. **Der Wortlaut steht
hier, weil er sonst nirgends stand.** Im Repository gab es die D-Nummerierung
bis dahin in genau drei Vorkommen: `D-5` (entschieden), ein beiläufiges `D-9` in
`lib/services/location/device_position.dart:24` und ein `D-b` in der
maplibre-Tabelle, das nirgends aufgelöst wird. Die sechs Fragen selbst lebten
allein im Chatverlauf, und `CLAUDE.md` sagt, dass Chatverlauf keine Quelle ist.
Eine eintreffende Antwort wäre ihrer Frage nicht mehr sicher zuzuordnen gewesen.

Der Stand **im Fragetext** ist der vom Absenden: Schritte 12 und 13 fertig, 1203
Tests. Was sich seither geändert hat, steht als **Nachtrag** unter der jeweiligen
Frage. Der Fragetext selbst wird nicht nachgeführt, denn Dairen hat genau ihn
bekommen.

**Verschickt sind D-9 bis D-14, also sechs.** D-15 und D-16 sind am 30.08.2026
dazugekommen und liegen **noch bei niemandem**: D-15 beim Bau von Schritt 27,
D-16 als technische Folge von Janeks Entscheidung zu E-43. Wer den nächsten
Block schickt, nimmt beide mit.

| Nr | Frage in einem Satz | Blockiert | Nachtrag seit dem Absenden |
|---|---|---|---|
| D-9 | Ein gemeinsamer Geo-Typ oder weiter je ein lokaler | nichts, wird teurer | Der angekündigte vierte Typ ist **nicht** entstanden |
| D-10 | Ist `lib/map/application/` als Kompositionsschicht bestätigt | nichts | Seit Schritt 15 gibt es ein **zweites** `application/` |
| D-11 | Braucht die Karten-Host-Regel ein Gegenstück für `test/` | nichts | Eine pauschale Regel träfe heute zwei Testdateien, die eine teuer gefundene Lücke schließen |
| D-12 | Wie klappt eine Gruppe ohne `getClusterExpansionZoom` auf | Antippen in Schritt 15 | Schritt 15 ist **ohne** Antippen gebaut, die Ergänzung ist jetzt die Vertragsänderung, vor der die Frage warnte |
| D-13 | Welches Sensorpaket für die Kompass-Drehung, und ist es frei | Schritt 14 | Der eingefrorene Port nennt `flutter_compass ^0.8.1` |
| D-14 | Darf `presentation` direkt aus `lib/services/` lesen | nichts | Aus einer Lesestelle sind vier geworden |
| D-15 | Ist `puzzles` als Feature bestätigt, damit `tours` und `challenges` später davon abhängen dürfen | nichts, blockiert aber Phase 5 | Am 30.08.2026 mit Schritt 27 entstanden |
| D-16 | Wie liest `discovery` den Zustand der laufenden Jagd, wenn sie auf der Karte läuft | die Umsetzung von E-43, also Schritt 36 und 37 | Am 30.08.2026 aus E-43 entstanden |

### D-9, gemeinsamer Geo-Typ

**Blockiert nichts, wird aber teurer.**

> Es gibt drei Typen für dieselben zwei Koordinaten: einen für Fakten, einen für
> die Karte, einen für die Nutzerposition. Grund ist Gate 6, das jeder Domäne den
> Import aus `core` verbietet, während die Strukturdokumente ein gemeinsames
> `core/geo/GeoPoint` vorsehen. Beides gleichzeitig geht nicht. Der vierte Typ
> kommt in Schritt 15.
>
> Zur Wahl: **(a)** eine eng begrenzte Ausnahme für `core/geo` in der
> Erlaubnisliste, dann ein Typ statt vier und eine Umrechnung weniger an jeder
> Modulgrenze, dafür bekommt Gate 6 sein erstes Loch. **(b)** Bei lokalen Typen
> bleiben, Gate 6 bleibt unberührt, dafür Konvertierung an jeder Grenze.
>
> Der dritte Typ ist bewusst so klein gehalten, dass ein „ja" bei (a) ihn
> ersatzlos löscht.

**Nachtrag, 29.08.2026 abends:** die Vorhersage hat sich nicht erfüllt. Nach den
Schritten 15, 16, 17 und 21 gibt es weiterhin genau **drei** Geo-Typen, nicht
vier: `features/facts/domain/value_objects/fact_coordinates.dart`,
`map/domain/map_position.dart` und `services/location/device_position.dart`. Die
Überlagerung kam ohne einen eigenen aus. Der Druck ist damit kleiner als beim
Absenden angenommen, die Abwägung selbst unverändert.

**Zweiter Nachtrag, 30.08.2026, und er erweitert die Frage.** Schritt 27 hat
dieselbe Sperre ein zweites Mal ausgelöst, diesmal nicht bei Koordinaten:
`puzzles/domain` darf `facts/domain` nicht importieren, deshalb entstehen dort
eine zweite Schwierigkeitsstufe (`PuzzleDifficulty`) und ein zweites
Operanden-Wertobjekt (`PuzzleOperand`), beide wortgleich zu ihren Originalen in
`facts`. **Das ist mit einer Wegwerf-Probe gemessen**, angelegt, ausgeführt,
gelöscht: der Import aus `puzzles/domain` bricht den Architektur-Check mit
Exit-Code 1 und genau einer Meldung ab („Domain-Erlaubnisliste"), derselbe
Import aus `puzzles/application` läuft auf Exit-Code 0 durch.

D-9 ist damit nicht mehr die Frage nach **einem Geo-Typ**, sondern die nach
Wertobjekten einer fremden Feature-Domäne allgemein. Eine Antwort, die nur
Koordinaten regelt, lässt die zwei neuen Kopien stehen; eine, die
verallgemeinert, löscht sie ersatzlos, so wie sie `device_position.dart`
löschen würde. Die Kopien tragen den Verweis auf D-9 in ihrem Kopfkommentar,
damit sie beim Aufräumen gefunden werden.

**Dritter Nachtrag, 30.08.2026, Schritt 34, und diesmal weicht der Bau aus
statt zu kopieren.** Der Routengenerator der Schnitzeljagd rechnet Entfernungen
zwischen Fakten und ist damit eine Geschäftsregel. In `challenges/domain` wäre
er nicht baubar: eine Wegwerf-Probe mit Importen auf `facts/domain` **und**
`map/domain` lässt den Architektur-Check mit **Exit-Code 1** und **zwei**
Verstössen abbrechen, beide „Domain-Erlaubnisliste". Aus `challenges/application`
laufen dieselben zwei Importe auf **Exit-Code 0** durch, Analyzer sauber. Beide
Proben angelegt, ausgeführt, gelöscht.

Statt vier wortgleicher Kopien (Fakt-Kennung, Koordinate, Rätsel, Stufe) liegen
`HuntPlan` und `HuntStop` deshalb **in `challenges/application/`** und halten
`Fact` und `FactPuzzle` direkt. Der Generator benutzt die vorhandene
Haversine-Rechnung aus `map/domain/map_position.dart`, es entsteht also **kein**
vierter Koordinatentyp.

**Das ist trotzdem eine Ausnahme, und sie gehört benannt.**
`architecture-overview.md` §7 gibt Entitäten der Domäne und nennt genau eine
dokumentierte Ausnahme, nämlich `map/application/` für die Komposition des
Karten-Hosts. Hier liegen zum ersten Mal **Datenklassen** in `application`. Es
ist nicht dieselbe Bauform wie bei den Rätseln, wo in `application` ein
Übersetzer liegt, also ein Anwendungsfall. `dependency-rules.md:189-197`
verlangt für jede Ausnahme einen Grund, eine enge Schnittstelle, einen
Eigentümer und eine Rücknahmebedingung; die ersten drei stehen im Kopfkommentar
von `hunt_plan.dart`, die vierte ist genau diese Frage: **wird D-9 zugunsten
eines geteilten Typs beantwortet, zieht die Datei ohne Feldänderung nach
`domain/` um.**

Nebenbei ist damit die vierte Cross-Feature-Kante des Repositories entstanden,
`challenges → facts`. Die drei bestehenden sind `discovery → facts`,
`facts → discovery` und `puzzles → facts`. Regel 10 sieht das Prüfskript
ausdrücklich nicht, das steht im Skript selbst; es bleibt Review-Sache.

### D-10, `lib/map/application/`

**Bestätigung, blockiert nichts.**

> Der Karten-Host hat ein `lib/map/application/` bekommen. Das ist das erste
> `application/`-Verzeichnis im Repository, und es enthält Komposition statt
> Anwendungsfällen. Kein anderer Ort bleibt übrig: die Domäne darf kein Riverpod,
> und die Presentation des Hosts ist für Features per Regel gesperrt. Als
> Ausnahme dokumentiert.
>
> Die Grenze zwischen Feature und Host hängt jetzt am Typ: Features sehen eine
> Schnittstelle ohne `attach`, der Versuch bricht schon beim Analysieren ab.
> Dafür braucht es keine zusätzliche Prüfregel.

**Nachtrag, 29.08.2026 abends:** die Prämisse „das erste `application/`" stimmte
beim Absenden und stimmt nicht mehr. `lib/map/application/` entstand mit Schritt
12 (`6a8b038`), `lib/features/facts/application/fact_providers.dart` kam mit den
Schritten 15 und 16 dazu (`12b8119`), beides über `git log --diff-filter=A`
belegt. Die Frage lautet damit nicht mehr „darf es diese eine Ausnahme geben",
sondern „ist `application/` die reguläre Kompositionsschicht". Das ist eine
andere Frage mit einer anderen Folge: Antwort A wäre ein Eintrag in
`project-structure.md`, Antwort B ein Rückbau an zwei Stellen.

### D-11, die Karten-Host-Regel gilt in `test/` nicht

**Offene Lücke, entschärft. Blockiert nichts.**

> Die Regel, die Features vom Karten-Host fernhält, gilt in `test/` nicht: sie
> hängt am Pfad `lib/features/`. Ein Test darf also alles importieren. Die
> konkrete undichte Stelle ist behoben, die Lücke bleibt. Eigene Regel dafür,
> oder bewusst offen lassen?

**Nachtrag, 29.08.2026 abends, und er formt die Antwort.** Eine pauschale
Pfadregel für `test/features/` wäre heute nicht folgenlos. Zwei Testdateien
importieren `map/presentation` genau dort:

- `test/features/discovery/presentation/fact_overlay_test.dart:17`
  (`map_overlay_host.dart`)
- `test/features/discovery/presentation/map_camera_intents_host_test.dart:9-10`
  (`map_camera_driver.dart`, `map_camera_host.dart`)

Das sind keine Nachlässigkeiten, sondern die Gegenprobe gegen den teuersten Fund
der Schritte 15 und 16: die sechs Zeilen Durchreichung im **echten** Host hatten
null Tests, und `setOverlay` leer zu machen löschte jeden Fakt von der Karte, bei
1290 grünen Tests. Eine Regel, die den Pfad verbietet, verbietet damit
ausgerechnet die Tests, die diese Lücke geschlossen haben. Wer D-11 mit „eigene
Regel" beantwortet, muss also sagen, woran die Ausnahme hängt: am Dateinamen, an
einer Anmerkung oder an einer Erlaubnisliste.

### D-12, Aufklappen einer Gruppe

**Blockiert das Antippen in Schritt 15.**

> Wenn man in der PWA auf eine Cluster-Blase tippt, zoomt sie genau so weit auf,
> dass der Cluster zerfällt. Die Zoomstufe dafür liefert
> `getClusterExpansionZoom`. Diese Funktion gibt es im Flutter-Kartenpaket nicht,
> null Treffer im ganzen Paket.
>
> Zur Wahl: **(a)** eine feste Zoomstufe raten. Kostet nichts, weicht sichtbar
> ab, und bei dichten Clustern muss man mehrmals tippen. **(b)** Die Kamera auf
> ein Rechteck fahren lassen, berechnet aus den Punkten, die das Feature ohnehin
> hält. Trifft immer, kostet aber ein neues Feld im gerade fertiggestellten
> Kameravertrag und einen zweiten Bewegungspfad im Host.
>
> Empfehlung: **(b)**, und zwar bevor Schritt 15 anfängt. Danach ist es in
> Schritt 16 eine Vertragsänderung statt einer Ergänzung.

**Nachtrag, 29.08.2026 abends.** Der empfohlene Zeitpunkt ist verstrichen.
Schritt 15 ist seit `12b8119` gebaut, das Antippen der Gruppen bewusst nicht,
und der Kameravertrag ist fertig und in Betrieb. Die Ergänzung ist damit genau
die Vertragsänderung, vor der die Frage gewarnt hat. Zwei Messungen dazu, beide
neu:

- **Das Rechteck kann nur aus den eigenen Quelldaten kommen.** `getClusterLeaves`
  und `getClusterChildren` fehlen im Paket ebenso wie `getClusterExpansionZoom`,
  siehe „Was `maplibre_gl 0.26.2` nicht kann". Das SDK sagt also nicht, welche
  Punkte in einer angetippten Gruppe stecken. Die Überlagerung hält sie ohnehin,
  der Weg ist gangbar, aber er läuft über das Feature und nicht über die Karte.
- **Was die Quelle genau tut**, für den Fall, dass (a) gewählt wird und die
  Abweichung beziffert werden muss: `screen-map.jsx:2439-2459` fährt `easeTo` auf
  `min(expansionZoom + 0.4, 18)` über 700 ms, zentriert auf die Koordinaten des
  Cluster-Merkmals.

### D-13, Sensorpaket für die Kompass-Drehung

**Blockiert Schritt 14.**

> Dafür braucht es die Geräteorientierung. Das vorhandene `geolocator` liefert
> nur die Richtung, in die man sich bewegt, nicht wohin das Telefon zeigt. Wer
> stehenbleibt und sich dreht, ändert nur das Zweite. Die PWA nutzt dafür
> `deviceorientationabsolute`, in Flutter braucht es ein neues Paket. Keins ist
> im Projekt.
>
> Frage: welches, und ist es freigegeben?

**Nachtrag, 29.08.2026 abends:** der eingefrorene Port hat die Frage für sich
schon beantwortet. `08_Flutter/pubspec.yaml` führt unter „Sensors / Location"
`flutter_compass: ^0.8.1`, daneben `sensors_plus: ^6.1.0` für die
Schüttel-Geste der Audio-Bedienung. Das ist keine Freigabe und kein Präjudiz,
aber es ist der Präzedenzfall, den `CLAUDE.md` für genau solche Fragen im
Lese-Repo nachschlagen lässt. Das `pubspec.yaml` hier führt heute weder das eine
noch das andere. Ein neues Paket ist laut `CLAUDE.md` zustimmungspflichtig, die
Frage bleibt also so oder so eine Frage.

### D-14, `presentation` liest aus `lib/services/`

**Bestätigung, blockiert nichts.**

> Der Ortungsdienst liegt unter `lib/services/location/`, und die Oberfläche
> liest ihn direkt. Das ist die erste Stelle im Repository, an der
> `presentation` aus `lib/services/` liest, und die Abhängigkeitstabelle sieht es
> nicht vor, dort steht „Application, Domain, narrowly scoped Core". Das
> Prüfskript merkt es nicht, weil `lib/services/` keine Schicht ist.
>
> Der vollständig geschichtete Weg wäre möglich, kostet drei zusätzliche Dateien
> und einen vierten Koordinatentyp, also genau das, was D-9 loswerden will.
> Bestätigen, oder soll es umgebaut werden?

**Nachtrag, 29.08.2026 abends:** aus der einen Lesestelle sind vier geworden. Es
lesen heute `features/discovery/presentation/fact_proximity.dart`,
`features/discovery/presentation/notifiers/user_location_providers.dart`,
`features/discovery/presentation/pages/map_page.dart` und
`features/facts/presentation/pages/fact_page.dart` aus `lib/services/location/`.
Ein Umbau kostet damit mehr als beim Absenden, und die Frage wird mit jedem
Schritt, der die Nutzerposition braucht, teurer statt billiger.

### D-15, ist `puzzles` als Feature bestätigt

**Am 30.08.2026 mit Schritt 27 entstanden, noch nicht verschickt. Blockiert
Schritt 27 nicht, blockiert Phase 5.**

`lib/features/README.md` führt `puzzles` unter „Über die Domain-Map hinaus" und
sagt dort selbst: „Der Zuschnitt ist ein Vorschlag und **wartet auf
Bestätigung**." Drei akzeptierte Dokumente kennen das Wort nicht:
`domain-map.md` (§2 nennt zehn Domänen), `architecture-overview.md` §5 und
`project-structure.md`. Alle drei tragen `status: accepted`.

**Zu bestätigen ist nicht, ob `puzzles` existieren darf, sondern ob `tours` und
`challenges` später davon abhängen dürfen.** Diese Abhängigkeit entsteht in
Schritt 33 und folgenden, nicht heute: Schritt 27 baut das Sheet ohne jeden
Einstieg, und der einzige Verbraucher des Vertrags liegt im selben Feature.
Deshalb ist der Schritt gebaut worden, und deshalb ist keines der drei
Dokumente angefasst. Präzedenzfall für die Zurückhaltung ist E-26: das Tutorial
ging nach `lib/app/onboarding/`, ausdrücklich damit `domain-map.md` und
`lib/features/README.md` nicht geändert werden müssen.

Mit zu entscheiden: ob dieselben drei Dokumente auch `library` und `creator`
nachtragen sollen, die unter demselben Vorbehalt stehen.

### D-16, wie `discovery` an den Jagdzustand kommt

**Am 30.08.2026 aus E-43 entstanden, noch nicht verschickt. Blockiert die
Umsetzung von E-43, also die Schritte 36 und 37.**

Janek hat entschieden, dass die Solo-Jagd auf der **Karte** läuft, wie in der
Quelle. Damit braucht der Kartenbildschirm, der `discovery` gehört, Lesezugriff
auf den Zustand der laufenden Jagd, der `challenges` gehört: welche Station
gerade dran ist, wie weit sie entfernt ist, wie viele Hinweise schon gekauft
sind.

**Das wäre die fünfte Cross-Feature-Kante des Repositories.** Die vier
bestehenden sind `discovery → facts`, `facts → discovery`, `puzzles → facts`
und seit Schritt 34 `challenges → facts`. Regel 10 verlangt dafür einen
öffentlichen Domänen- oder Application-Vertrag, und das Prüfskript sieht diese
Regel ausdrücklich **nicht**, das steht im Skript selbst; es bleibt Review-Sache.

Was die Quelle tut, ist gemessen und hilft bei der Antwort nur halb: sie hält
`activeHunt` eine Ebene höher im App-Zustand (`app.jsx:90`) und schreibt sie
bei jeder Änderung in den lokalen Speicher (`:198`), damit ein Neuladen sie
nicht verliert. Drei Bildschirme lesen sie. Eine App-Komposition als
Eigentümerin wäre also quellentreu, widerspricht aber der Feature-Ordnung, die
`challenges` den Sitzungszustand gibt.

Zur Wahl stehen mindestens: ein Vertrag in `challenges/domain` plus ein
Provider in `challenges/application`, den `discovery/presentation` liest; oder
ein Adapter in der App-Komposition, der beide Seiten entkoppelt; oder der
Jagdzustand wandert als geteilte Anwendungsschicht aus beiden Features heraus.
Die erste Variante ist die kleinste und liegt auf der Linie von
`dependency-rules.md:180-187` („Placement follows the consumer, not taste"),
die dritte die sauberste und teuerste.

**Mit zu beantworten:** ob die Jagd einen Neustart der App überleben muss. Die
Quelle sagt ja und legt sie im lokalen Speicher ab; im Neubau gibt es dafür
Präzedenzfälle (`FirstLaunchStore`, `TourStore`, `AudioModeStore`), aber keinen
Vertrag.

### Zwei Punkte aus demselben Block, die keine Fragen sind

Im selben Block mitgeschickt, ausdrücklich als selbst entschieden gekennzeichnet
und beide mit einer Zeile umkehrbar:

- **`geolocator` hat ein Heimatverzeichnis** und ist außerhalb davon maschinell
  verboten (Regel 21). Das setzt eine bereits akzeptierte Entscheidung durch. Der
  Präzedenzfall steht im Skript: dieselbe Regel für die WebView entstand
  ebenfalls, bevor das Paket überhaupt im Projekt war.
- **Die Cluster-Parameter gehören dem Feature**, nicht dem Karten-Host, weil sie
  technisch ohnehin an der Datenquelle hängen und zwei Überlagerungen
  unterschiedlich clustern dürfen.

## Offene Entscheidungen

> **Hinweis zur Öffentlichkeit dieses Dokuments.** Das Repository ist öffentlich.
> Die Einträge E-06, E-07, E-16, E-21, E-23 und E-24 beschreiben offene
> Schwachstellen des
> produktiven Backends, das die laufende PWA mitbenutzt. Der Eigentümer hat am
> 26.08.2026 ausdrücklich entschieden, sie hier trotzdem im Klartext zu führen,
> einschließlich der beiden schwereren Funde E-23 und E-24,
> weil der Nutzen als Arbeitsdokument höher gewichtet wird als das Risiko.
> Das ist eine bewusste Entscheidung, kein Versehen.


Nummerierung aus der Architektur-Gegenüberstellung. Bereits entschieden und
deshalb nicht mehr gelistet: Feature-Zuschnitt, Gold-Trennung im hellen Theme,
Nunito-600, Umgang mit `riverpod_lint`, dazu **E-25** (siehe unten).

**E-26, E-27 und E-38 sind am 27.08.2026 entschieden.**

*E-26, Ordner für das Tutorial:* es entsteht unter **`lib/app/onboarding/`**, als
App-Komposition. Kein vierter Feature-Ordner, damit keine Änderung an
`domain-map.md` und `lib/features/README.md` nötig wird. `features/identity/`
war ausdrücklich nicht die Wahl: die PWA führt zwei unabhängige Flags,
`fact_has_launched` für den Splash und `fact_tour_shown` für das Tutorial, und in
Phase 2 wächst das Tutorial um fünf Kartenanker. Ein Wechsel nach
`features/onboarding/` bleibt später möglich und kostet ein Verschieben plus
Importe, keine Umschreibung.

*E-38, Laufweite:* Materials `letterSpacing` wird **global auf null gesetzt, wo
die Quelle keine angibt**. Grund: es verbreitert jede Beschriftung um etwa 1,75
Pixel, hat die Sprachzeile bei 411 Pixeln zum Umbruch gebracht, und betrifft
jede Textbreite der App. Jetzt einmal im Theme statt später an jedem Bildschirm.
**Folge, die dazugehört:** das verschiebt Texte auf allen bisherigen
Bildschirmen, die festgenagelten Maße in den Tests müssen neu gemessen werden,
und der erste Gerätelauf danach gehört wiederholt.

**Der Eingriff sitzt woanders, als jeder erwartet, der sich `FactTheme`
ansieht.** Materials `letterSpacing` steht **nicht** in dem `textTheme`, das
`_textTheme` zusammenbaut, sondern in `ThemeData.typography`, und das
`Theme`-Widget mischt es erst beim Lokalisieren ein, als **Basis** unter dem
eigenen Stil (`theme_data.dart:1762`, `localTextGeometry.merge(baseTheme.textTheme)`).
Ein `letterSpacing: null` in `_textTheme` hätte deshalb genau den Wert
durchgelassen, den es entfernen soll; an einer Wegwerf-Probe gemessen, dort
stand schon vorher `null`, und auch `fontSize` war `null`. Über `typography`
sind `textTheme` und `primaryTextTheme` in einem erledigt.

**Alle 15 hartcodierten Laufweiten der Identity-Bildschirme sind gegen
`screen-auth.jsx` belegt und keine einzige wurde geändert.** Verdächtig waren
0.1, 0.15 und 0.25, weil das genau die Material-2021-Werte sind; sie stehen
trotzdem so in der Quelle, der Gleichklang ist Zufall. Wer hier pauschal
aufgeräumt hätte, hätte die Parität zerstört.

**Ein einziges festgenageltes Maß ist gefallen, aus dem umgekehrten Grund als
vermutet:** bei 411 Pixeln gibt der Kopfhörer-Knopf nicht mehr nach, weil die
Zeile aufgeht. Die Regel gilt weiter, sie ist bei 411 nur nicht mehr
beobachtbar. Der Test liegt deshalb jetzt bei 390, dem Rahmenmaß der Quelle, mit
unveränderten exakten Zusicherungen statt einer aufgeweichten Toleranz.

*E-27, Anker-Registry:* der Mechanismus entsteht unter **`lib/core/anchors/`**,
die Ankerkennungen bleiben bei der Oberfläche, die sie besitzt. Heute sind das
die zwei Tab-Anker in `lib/app/shell/`, ab Phase 2 die fünf Kartenanker in
`lib/features/discovery/presentation/`. Ausschlaggebend war die Importrichtung,
nicht die Frage „ist das allgemein genug für `core`": ab Phase 2 registrieren
sich Widgets aus `features/*/presentation/`, und `dependency-rules.md:20` lässt
für die nur Application, Domain und eng abgegrenztes Core zu. Von den beiden
Kandidaten ist `core` damit der einzige legale. Der übliche Gegengrund, nämlich
die Änderung eines akzeptierten Dokuments, trägt hier nicht: der `app/`-Baum in
`project-structure.md` kennt wegen E-26 ohnehin kein `onboarding/` und muss so
oder so nachgezogen werden.

**Was diese Entscheidung ausdrücklich nicht absichert:** Regel 11 des
Prüfskripts zerlegt nur Pfade und sieht den Dateiinhalt nie. Eine Datei
`lib/core/anchors/anchor_ids.dart` mit Fachkennungen darin würde das Gate
passieren und trotzdem genau das verletzen, was E-27 verhindern soll. Umgekehrt
ist `tour_anchor.dart` verboten, obwohl es harmlos wäre, und das ist
ausgerechnet der Name, den die Quelle nahelegt (`data-tour-anchor`). Die Regel
schützt hier nicht, sie täuscht Schutz vor. Die Trennung hält die Review, nicht
die Maschine. Deshalb gehört ein Satz dazu
in die „Placement rules" von `project-structure.md`.

**Ebenfalls am 27.08.2026 freigegeben:** ein Edit an
`docs/architecture/project-structure.md`, obwohl das Dokument `status:
accepted` trägt. Er trägt `anchors/` und `onboarding/` ein, ergänzt die
Placement rules um den Satz oben und zieht dabei vier Abweichungen nach, die
heute schon im Code stehen und im Dokument fehlen: `lib/core/diagnostics/`,
`lib/core/async/`, `lib/services/supabase/`, sowie `bootstrap/` und
`fact_app.dart`, die real `lib/app/bootstrap.dart` und `lib/app/app.dart`
heißen.

**E-25 ist am 27.08.2026 entschieden.** Die vier Tab-Pfade bleiben `/map`,
`/collection`, `/challenges`, `/profile`, also die Domänennamen aus der
Domain-Map statt der PWA-Bezeichner `wallet` und `profil`. Begründung: sie sind
deckungsgleich mit den Feature-Ordnern, und die PWA kennt ohnehin keine URLs,
gegen die man sich angleichen könnte. Gleichzeitig entschieden: Splash, Login
und Signup werden **eigene Routen** `/splash`, `/login`, `/signup` mit
zentraler Redirect-Weiche, nicht zustandsgesteuerte Overlays. Der öffentliche
Vertrag umfasst damit sieben Pfade statt vier. Ab jetzt kostet ein Umbenennen
eine Migration, vorher eine Zeile.

**E-39 ist am 28.08.2026 entschieden.** Oberflächentexte, die die PWA sichtbar
anzeigt, **ohne sie als Schlüssel zu führen**, kommen aus einer handgepflegten
Ergänzungs-Map in `lib/app/localization/app_strings_supplement.dart`. Sie liegt
außerhalb von `generated/`, damit `tool/generate_i18n.dart` sie nie
überschreibt. Der Generator prüft sie in **beiden** Betriebsarten gegen: jeder
Ergänzungs-Schlüssel muss in der PWA fehlen, sonst Exit-Code 1 mit dem Namen
des Schlüssels und dem Hinweis, den lokalen Eintrag zu löschen. Die Prüfung
sitzt bewusst dort und nicht in einem Test: `flutter test` muss ohne Zugang zum
Lese-Repo durchlaufen.

`AppStrings` sucht in der Reihenfolge erzeugt/gewählte Sprache, Ergänzung/
gewählte Sprache, erzeugt/Fallback, Ergänzung/Fallback. Der erzeugte Wert
gewinnt gegen den gleichnamigen Ergänzungs-Wert, damit ein Schlüssel, den die
PWA nachträglich bekommt, sofort aus der Quelle kommt und nicht aus der lokalen
Kopie. Nachgewiesen wird das über `AppStrings.debugResolve`, weil in echten
Daten per Konstruktion nie eine Überlappung entsteht.

Erster und bisher einziger Eintrag ist `tour.stepCounter`, die Schrittanzeige
des Tutorials. `screen-tour.jsx:483` baut sie als hartcodierten Ternär
(`SCHRITT {step} VON {total}` / `STEP {step} OF {total}`, Großschreibung aus der
Quelle) und hat dafür keinen Schlüssel. **Zum Namen:** der Präfix `tour.` trägt
in den erzeugten Tabellen zwei Bildschirme, ab `tour.planTitle` gehört alles dem
Tour-Planer. Der Stamm `step` ist innerhalb von `tour.` aber eindeutig das
Tutorial, der Planer zählt in `stops`. Nicht `tour.stepOf` genannt, weil
`challenge.stepOf` schon existiert und dort nur das Bindewort „von" trägt.

**Der Karten-Host ist am 28.08.2026 entschieden.** Er gehört keiner
Geschäftsdomäne, sondern entsteht als eigene App- und UI-Infrastruktur unter
**`lib/map/`**, mit `presentation/` und `domain/`. Die Kamera gehört dem Host;
Features geben Absichten ab, statt die Karte zu steuern, und sehen vom Host nur
`map/domain/`. Der 3D-Avatar bleibt vorerst WebView, aber hinter einer
Schnittstelle, die der Rest des Codes nicht kennt, unterhalb
`lib/map/presentation/avatar/`.

Ausschlaggebend war dieselbe Frage wie bei E-27, die Importrichtung: vier
Features teilen sich eine Karte, und läge der Host in einem davon, müssten die
anderen drei dessen Presentation importieren. Genau das verbietet Regel 8. Die
frühere Angabe `services/map` in `lib/features/README.md` trägt nicht, weil der
Host eine Oberfläche mitbringt und `services/` für Vendor-Adapter ohne
Oberfläche gedacht ist. `domain-map.md` §7 bleibt wörtlich stehen: die Karte ist
weiterhin keine eigenständige Geschäftsdomäne. Eingetreten ist der `unless`-
Nebensatz in §3.

**Was daran neu maschinell geprüft wird**, seit demselben Tag und jeweils mit
einer Wegwerf-Probe belegt: Regel 18 (ein Feature sieht vom Host nur
`map/domain/`) und Regel 19 (`webview_flutter` nur unterhalb
`lib/map/presentation/avatar/`). Regel 19 ist heute nicht auslösbar, weil das
Paket noch nicht im Projekt ist; sie steht trotzdem schon da, damit sie wirkt,
wenn E-10 es freigibt. **E-10 bleibt offen**: entschieden ist die Kapselung,
nicht die endgültige Wahl zwischen WebView und einem Flutter-Nachbau.

**D-5 ist am 28.08.2026 entschieden und in der Nacht zum 29.08.2026
umgesetzt**, mit Ausnahmebudget null. Aus zehn öffentlichen Typen ist einer
geworden: `map_top_chrome.dart` ist jetzt eine Bibliothek mit neun
`part`-Dateien, acht Hilfstypen tragen `@visibleForTesting`, zwei sind privat.
Kein Test wurde umgeschrieben, die Testzahl blieb bei 987.

Dass das trägt, ist gemessen und nicht angenommen: eine Wegwerf-Datei unter
`lib/app/`, die einen annotierten Typ benutzt, lässt `dart analyze` mit
**Exit-Code 2** abbrechen (`invalid_use_of_visible_for_testing_member`). Die
Meldung nennt als erlaubten Ort die **Bibliothek** `map_top_chrome.dart`,
obwohl der Typ in einer `part`-Datei darunter deklariert ist. Deshalb bleiben
`_Blurred` und fünf private Konstanten privat, obwohl vier Dateien sie teilen.
Bei einer Aufteilung in eigene Bibliotheken hätten sie öffentlich werden
müssen, aus zehn Namen wären zwölf geworden.

**Der Beweis, dass die Verschiebung rein war, steckt nicht im grünen Testlauf:**
acht der neun Teildateien sind gegen ihren Original-Zeilenbereich aus
`git show HEAD:` **byte-identisch**, die neunte zeigt genau die vier Zeilen der
Umbenennung. Dazu zwei Mutationsproben, die belegen, dass die Tests die
verschobene Geometrie noch festhalten. Eine fünfte Zeile hat der Analyzer
erzwungen: nach der Umbenennung meldete `unused_element_parameter` ein
`super.key` an einer nun privaten Klasse, der nie ein Key übergeben wurde; ohne
Entfernen wäre Gate 2 rot geblieben.

Wortlaut der Entscheidung: „Chrome bitte als
geschlossene Einheit wenn möglich, falls Claude es gar nicht schafft dann
können Teile offen sein, aber nur in zwingend notwendigen Ausnahmen", mit der
Auflage, vorher nach Architekturverbesserungen zu suchen, weil ein
Testproblem dieser Art danach riecht.

Die Suche hat die Prämisse der Frage in zwei Punkten gekippt:

- **Die Präzedenz trägt nicht.** `lib/app/onboarding/widgets/tour_chrome.dart`
  ist nicht „öffentlich für Tests": seine drei Typen werden von
  `tour_overlay.dart:210-218` im Produktivcode instanziiert, und was dort nur
  intern gebraucht wird, ist privat (`_Dot`, `:200`). Die Datei ist das
  Gegenbeispiel, nicht das Vorbild.
- **Die Messbarkeit hängt heute schon nicht an den öffentlichen Typen.** Vier
  der sechs gemessenen Bauteile greift der Test bereits über die
  Anker-Registry ab, nicht über `find.byType`. Coin-Pille, Kompass und beide
  Modus-Knöpfe liefern exakte Rechtecke ohne öffentlichen Typ.

**Der Ort bleibt.** Ein Umzug nach `lib/map/` wäre nicht nur unnötig, sondern
illegal: Regel 18 verbietet jedem Feature den Import von `map/presentation`,
`map_page.dart` könnte das Chrome dann nicht mehr benutzen. Und der Host das
Chrome zeichnen zu lassen, gäbe ihm Münzstand, Level und Stadtname, also genau
die Fachlichkeit, die er nicht haben darf. Dass die Bauteile fachlich
`progression`, `city` und `tours` gehören, ist kein Einwand: dieselbe Frage
ist für denselben Bildschirm schon beantwortet, `discovery_anchors.dart:14-22`
sagt „ein Anker gehört der Oberfläche, nicht den Daten darin", mit den Coins
als Beispiel.

**Das Symptom ist die Datei, nicht die Fläche.** 1096 Zeilen, die mit Abstand
längste handgeschriebene Datei in `lib/` (nächste: 518), und die einzige, die
`naming-and-files.md:18` („ein Haupttyp je Datei") um den Faktor zehn reißt.

*Auslöser für eine Neubewertung des Orts, nicht heute:* sobald ein zweites
Feature eigenes Chrome über dieselbe Karte legt. Dann ist es geteilte
Oberfläche und gehört unter `lib/app/`, wie das Tutorial-Overlay.

**Neue offene Punkte aus dem Fundament von `lib/map/`.** Alle drei sind
benannt und keiner blockiert:

- **Der gemeinsame Geo-Typ, zweite Instanz.** `api-and-domain-design.md:38`
  und `project-structure.md:40` sehen `GeoPoint` beziehungsweise `core/geo/`
  vor, und Gate 6 verbietet jeder Domäne den `core`-Import. `FactCoordinates`
  war Umweg eins, `MapPosition` ist Umweg zwei, und Umweg drei steht in
  Schritt 13: die Nutzerposition fürs GPS-Folgen. Nimmt sie `MapPosition`,
  besitzt der Karten-Host den Aufenthaltsort des Nutzers, und `collection`
  importiert für die 150-Meter-Prüfung aus E-07 einen Kartentyp.
- **Wie ein Feature an den `MapHost` kommt.** Das Muster von E-32 trägt hier
  **nicht**: `authRepositoryProvider` ist für sein eigenes Feature lesbar,
  weil ein Feature seine eigene Presentation lesen darf, und `map/presentation`
  darf **kein** Feature lesen. Dazu ist der Host ein gemountetes Widget, das
  `bootstrap.dart` nicht überschreiben kann, weil es beim Start nicht
  existiert. Der Provider wird deshalb eine Registrierung mit untätigem
  Standard, Vorbild `unavailableAuthRepository`.
- **Eine Absicht vor gemounteter Karte.** Der Sky-Fall beim ersten GPS-Fix ist
  einmalig. Kommt der Fix, bevor die Karte steht, fällt er ins Leere und die
  App startet ohne Eröffnungsanimation im Standardzoom. Fallenlassen,
  aufheben und nachholen, oder alle aufheben.

**Zwei Abweichungen von der Quelle, bewusst und belegt.** Beide sind
Verhaltensänderungen und gehören Janek zur Kenntnis:

- **Die Winkel-Totzone misst gegen die echte Kartenausrichtung**, die Quelle
  gegen ihren eigenen `lastAppliedBearing` (`screen-map.jsx:2836`), der nur im
  Erfolgszweig fortgeschrieben wird (`:2839`). Folge in der Quelle: nach dem
  langen Kompassdruck, der `jumpTo({bearing: 0})` setzt (`:3168`) und das
  Folgen ausdrücklich wieder einschaltet (`:3166`), ist das Kompass-Folgen
  still tot, bis die Peilung um mehr als 1,5° vom veralteten Wert abweicht.
  Das ist ein Defekt der Quelle, kein Entwurf, und wird nicht mitportiert.
- **Der Nachbau rastet nicht ein, wenn der Nutzer dreht, während der Host
  animiert.** Die Quelle tut es, ihr `rotatestart`-Wächter (`:1692`) fragt
  `isEasing()` nicht. Ob eine Zwei-Finger-Drehung während einer laufenden
  Animation bei `maplibre_gl` überhaupt ankommt, ist ohne Gerät nicht messbar
  und deshalb in Schritt 12 zu prüfen.

**Offen bei Janek:** `manualMoveGrace`, Lesart A oder B. Lesart A ist der
Standard und die belegte: wer die Karte wegzieht und dann zwölf Meter läuft,
dem reißt die App die Karte zurück (`:2668` prüft nur `!isEasing()`). Lesart B
lässt ihn eine wählbare Zeitspanne in Ruhe. Ein Schalter, beide Lesarten sind
zugesichert.

**E-40 ist am 29.08.2026 entstanden und im selben Zug geschlossen**, als
Anwendung von E-38 und nicht als neue Entscheidung. Materials Zeilenhöhe kam
in der App an: **46 Absätze** erbten `height: 1.43` aus `bodyMedium`, dazu
**sieben Eingabefelder** ein `height: 1.5` aus `bodyLarge`. `styles.css`
enthält `line-height` **null Mal**, die Quelle setzt sie ausschließlich inline,
40 Mal über vier Bildschirme; wo sie keine setzt, rendert der Browser mit den
Schriftmetriken. Behoben am selben Hebel wie E-38, in `ThemeData.typography`,
weil der Wert dort sitzt und nicht im `textTheme`, das `FactTheme` zusammenbaut.
Für jeden der 46 Absätze wurde die Quelle nachgeschlagen: nirgends steht dort
eine Zeilenhöhe, und jeder Text, für den die Quelle eine angibt, trug sie vorher
wie nachher.

**Sichtbar wird es als ein bis drei Pixel je Bauteil:** Eingabefelder 83 → 80,
Stadt-Pille 52 → 51, Modus-Umschalter 43 → 42. **Am deutlichsten bei doppelter
Systemschrift**, dort schrumpfen die Fremdanmeldungs-Knöpfe von 104 auf 100, und
auf einem 360er Gerät sind vier Pixel im knappen Formular ein Unterschied.

Zwei Funde daran betreffen das Testnetz und nicht den Code:

- **`map_top_chrome_test.dart` pumpte ein nacktes `MaterialApp`**, ohne
  `FactTheme` und ohne `Material`. Dort erbten die Chrome-Texte Flutters
  `_errorTextStyle`, und der trägt `height: null`. Der Test hat die Maße also
  richtig gemessen, während die App sie falsch zeichnete. **Die Zahlen waren
  belegt, grün und trotzdem nicht das, was der Nutzer sah.** Ein Testrahmen,
  der die Vorfahrenkette der App nicht abbildet, kann über die falsche Sache
  recht haben.
- **`SelectableText` und `EditableText` tauchen in `find.byType(RichText)`
  nicht auf.** Wer Textstile über Finder einsammelt statt über einen Durchlauf
  des Renderbaums, übersieht jedes Eingabefeld. Deshalb ist die zweite Quelle
  `bodyLarge` bis dahin unbemerkt geblieben.

**E-33 und E-36 sind am 30.08.2026 entschieden**, beide sichtbare
Verhaltensänderungen in bereits gebauten Bildschirmen.

*E-33, „Angemeldet bleiben":* **entfernt.** Janek hat nicht zwischen den zwei
vorgelegten Möglichkeiten gewählt, sondern die Vorfrage gestellt, ob ein
solches Kästchen überhaupt sinnvoll ist. Die Prüfung sagt nein, aus drei
gemessenen und zwei inhaltlichen Gründen.

Gemessen: `_staySignedIn` wurde ausser zum Zeichnen **nirgends gelesen**, genau
wie `stayIn` in der Quelle (`screen-auth.jsx:431`, kein Leser). `persistSession`
ist eine Option von `FlutterAuthClientOptions` (`supabase_flutter 2.17.2`,
`lib/src/flutter_go_true_client_options.dart:28`, Vorgabe `true` in `:37`) und
wird an `Supabase.initialize` übergeben, das daraufhin
`SharedPreferencesLocalStorage` oder `EmptyLocalStorage` wählt
(`lib/src/supabase.dart:128-136`). Die Frage ist damit **beim App-Start
entschieden**, in `lib/app/bootstrap.dart:55`; ein Kästchen auf der
Anmeldeseite kann sie gar nicht mehr umlegen. Und ein Abmelden gibt es
heute nicht, das kommt laut `auth_repository.dart:34` mit Schritt 20.

Inhaltlich: das Kästchen ist ein **Web-Muster**, entstanden für geteilte
Rechner. Ein Telefon ist ein persönliches Gerät, und für einen Stadtführer, an
dessen Konto Münzen, Punkte und Trophäen hängen, wäre ein Abmelden bei jedem
Start feindselig. Der Fall „auf diesem Gerät nicht angemeldet sein" ist durch
den **Gastmodus** schon besser gelöst.

**Der Abstand darunter war keine gewählte Zahl.** Am Kästchen hing
`margin: '6px 0 22px'` (`screen-auth.jsx:523`); ohne es bleibt der
`marginBottom: 12` des Feldes selbst (`:82`), und den trägt `AuthField`
bereits. Es war also nichts einzusetzen, nur ein `Padding` zu löschen.
Der Schlüssel `login.stayIn` bleibt in den erzeugten Tabellen stehen, weil der
Generator jeden Schlüssel der PWA übernimmt; ein Satz im Kopfkommentar von
`LoginPage` sagt, dass er absichtlich unbenutzt ist.

*E-36, die Sprachzeile bei 360 Pixeln:* **unterhalb von 390 logischen Pixeln
wird die Flagge von 30 auf 20 verkleinert.**

**Korrektur an diesem Eintrag, und sie betrifft seine Begründung.** E-36 nannte
als eine der Möglichkeiten „kleinere Flagge unter einer Breitenschwelle
(Quelle: 30)" und legte damit nahe, die Quelle tue das auch. **Sie tut es
nicht.** Nachgeschlagen: `screen-auth.jsx:348` zeichnet unbedingt
`<Flag size={30}/>`, eine Breitenschwelle für die Flagge gibt es in der ganzen
PWA nicht; der einzige Umbruchpunkt ist `@media (max-width: 500px)` in
`styles.css:269` und schaltet den Telefonrahmen auf Vollbild. Die 30 war die
Grösse, nicht eine Regel. **Die Verkleinerung ist damit eine bewusste
Abweichung von der Quelle und kein Nachbau**, und sie wurde Janek mit der
falschen Begründung vorgelegt.

Schwelle und Grösse sind hergeleitet und gemessen, mit echten Schriften: der
Fehlbetrag von 14,657 Pixeln verteilt sich auf zwei Karten, jede muss 7,33
schmaler werden, die Flagge darf also höchstens 22,67 breit sein. **22 wäre das
Maximum und geht mit 0,039 Pixeln Rest auf**, also ein Zufallstreffer; gewählt
ist 20 mit 5,343 Pixeln Rest. Die Schwelle 390 ist das Rahmenmass der Quelle
(`chrome.jsx:135`) und damit die schmalste Breite, für die sie je entworfen
hat; ab 390 ist jede gemessene Zahl unverändert.

**E-36 ist damit für 360 gelöst und für 320 nicht.** Ein eigener Test hält das
ausdrücklich fest, damit niemand die Entscheidung für allgemeiner hält, als sie
ist.

**E-43, E-45 und E-46 sind am 30.08.2026 von Janek entschieden.**

*E-43, wo die Solo-Jagd läuft:* **auf der Karte, wie die Quelle.** Der
Challenge-Reiter zeigt bei laufender Jagd nur Pause und Ergebnis, gespielt wird
auf dem Kartenbildschirm. Damit ist der Plan an dieser Stelle überholt, und die
Schritte 36 und 37 werden neu zugeschnitten: was dort als „Phasen-Maschine" und
„Active-UI" steht, beschreibt `SnjdActiveView`, also den Demo- und Gruppenpfad
auf hartcodierten Beispieldaten. Gebaut wird stattdessen, was
`screen-map.jsx` für die laufende Jagd tut: Stationspille, Stationszähler,
Navigations-Gating nach Schwierigkeit, gestufte Hinweise und die Öffnung des
Rätsel-Sheets.

**Die technische Folge ist noch offen und geht an Dairen, siehe D-16:** liegt
die laufende Jagd auf der Karte, muss `discovery` den Jagdzustand lesen, und
das wäre die fünfte Cross-Feature-Kante des Repositories. Die Entscheidung
selbst ist damit nicht blockiert, ihre Umsetzung schon.

*E-45, gewählte gegen geschätzte Dauer:* **die gewählte gilt.** 30, 60 oder 90
Minuten sind die Ansage an den Nutzer, und ein Wert, der ihm unmittelbar nach
seiner eigenen Wahl etwas anderes sagt, ist ein Fehler und keine Parität.
`HuntPlan.estimatedDurationMinutes` trägt deshalb die gewählte Dauer statt
`stops.length * 14`. **Bewusste Abweichung von der Quelle**, dokumentiert an
der Stelle. Offen bleibt der Randfall, dass der Generator weniger Stationen
findet als die Dauer vorsieht; dann steht die Ansage über dem, was die Jagd
wirklich kostet. Sichtbar ist das an der Stationszahl, erfunden wird dafür
keine Formel.

**Beim Umsetzen kam heraus, dass die Abweichung nichts kostet, und das ist
gemessen:** `grep` über das ganze PWA-Verzeichnis findet für
`estimatedDuration` **genau einen** Treffer, und das ist die Zuweisung selbst
(`hunt-generator.jsx:354`). Kein Bildschirm liest sie. Die 70 Minuten wurden dem
Nutzer also nie gezeigt; der Widerspruch entsteht erst dadurch, dass der Neubau
die Zahl an einen Bildschirm gäbe. Die Entscheidung weicht damit von einer
Zeile ab, die in der Quelle tote Fläche ist.

**Die Umsetzung hat die Signatur geändert, und zwar so, dass der Widerspruch
nicht wieder entstehen kann:** `generateHuntRoute` nimmt jetzt die gewählte
Dauer und leitet die Stationszahl daraus ab, statt beides einzeln zu bekommen.
Eine Eingabe, keine Hintertür für Tests. Der Preis waren 37 Testaufrufe, von
denen 28 mit Stationszahlen ausserhalb von 5, 7 und 9 arbeiteten; 25 davon
kosteten nur eine längere Erwartungsliste, weil die Schleife bei kleinem
Bestand ohnehin von selbst abbricht. Die drei Tests, die eine Regel an ihrer
**Position im Lauf** prüfen, sind neu gelegt und ihre Läufe vorher mit einem
Simulator aus der **Quelle** ausgerechnet statt aus dem Dart-Code.

*E-46, der unübersetzte Startpunkt-Picker:* **ich leite Wortlaute her und lege
sie als nicht freigegeben vor**, so wie bei E-28. Sie gehen in die
Ergänzungs-Map nach E-39 und tragen den Vermerk, dass sie auf Bestätigung
warten. Der Bildschirm ist damit in beiden Sprachen vollständig, und der
erfundene Anteil ist als solcher markiert statt sich als Quelle auszugeben.

**E-35 ist am 30.08.2026 entschieden**, beim Bau von Schritt 33, und die Wahl
war beim Nachmessen gar keine mehr. Der Startknopf der Schnitzeljagd ist
derselbe wie in der Anmeldung; damit brauchte ihn ein zweites Feature. Die
Alternative „bei `identity` lassen" ist damit technisch tot: eine Wegwerf-Probe,
die aus `challenges/presentation` nach `identity/presentation` importiert,
lässt `tool/check_architecture.dart` mit **Exit-Code 1** abbrechen, Meldung
„Regel 8: presentation von `identity` darf nur dieses Feature selbst
importieren". Angelegt, ausgeführt, gelöscht.

Der Knopf liegt jetzt als `PrimaryButton` in `lib/core/widgets/primary_button.dart`.
**Umbenannt werden musste er auch**, und zwar von der Maschine erzwungen: Regel
11 zerlegt Pfade in Wortbestandteile, `fact_button.dart` fiel über den Begriff
„fact", obwohl der Knopf nach der App heisst und nicht nach der Entität.
Ebenfalls mit einer Probe gemessen. Die Wache wurde dafür **nicht** aufgeweicht.

**Die Fälligkeitsangabe des alten Eintrags war falsch gesetzt** und das ist der
lehrreiche Teil: dort stand „wenn ein drittes Feature ihn braucht". Regel 8
schlägt schon beim **zweiten** zu. Wer eine Fälligkeit an eine Zahl hängt, statt
an die Regel, die sie auslöst, verschiebt sie um eine Runde.

**E-31 und E-32 sind am 28.08.2026 geschlossen**, beide durch einen Edit an
akzeptierten Architekturdokumenten.

*E-31:* `presentation → data` steht jetzt wörtlich in der Forbidden-Liste von
`dependency-rules.md`, einschließlich des eigenen `data/`, und zusätzlich als
harte Regel 17. Das Skript setzt sie seit Schritt 9 durch, das Dokument leitete
sie nur aus der Weißliste der Tabelle ab.

*E-32:* der zweideutige Satz in `project-structure.md` ist ersetzt. Ein
Provider, der eine `data`- oder `application`-Implementierung baut, steht neben
dieser Implementierung und wird **ausschließlich von der App-Komposition**
gelesen. Höhere Schichten lesen einen Provider, der auf dem Domänenvertrag
typisiert ist, neben dem Vertrag oder in `presentation`, mit sicherem Standard
und Override aus `bootstrap.dart`. Am Code nachgeprüft, und beide Vorbildstellen
sind danach richtig eingeordnet: `authRepositoryProvider` (Vertrag,
`presentation/notifiers/`, Override im Bootstrap) ist das Muster zum Kopieren,
`diagnosticSinkProvider` steht neben seinem Vertrag in `core` und ist deshalb
für `presentation` lesbar, `factRepositoryProvider` steht neben der
Implementierung und ist damit nur für die App-Komposition erreichbar. **Der
falsche Kommentar an `factRepositoryProvider` bleibt offen** und steht weiter
oben unter „Arbeit außerhalb der 50 Schritte"; E-32 klärt die Regel, nicht die
eine Fundstelle.

| Nr | Entscheidung | Level | Fällig vor |
|---|---|---|---|
| E-06 | **Reward-Ledger.** `increment_coins(uid, amount)` im geteilten Backend ist `security definer` und prüft den Betrag nicht. Der Client bestimmt, wie viele Coins er bekommt. Die gesamte Rätsel-Ökonomie hängt daran. Zusätzlich widersprechen sich die Zahlen der Quelle: Server bucht 10 beim Sammeln, die Map-Animation zeigt „+12", das Fact-Detail „+10 und ⭐+50", das Puzzle Basis 50. | **4** | Phase 4 |
| E-07 | **Location-Spoofing.** `collect_fact_validated` prüft die 150-Meter-Distanz gegen die vom Client geschickte Position. | **4** | Phase 2 |
| E-08 | **Sprachneutrale Rätsel-Auswertung.** Belegt, nicht vermutet: `puzzle-sheet.jsx:425` baut die acht Kompass-Knöpfe aus `puzzle.compass.N` bis `.NW` und vergleicht in Zeile 450 mit `String(pick) === String(puzzle.expected)`. `expected` kommt deutsch aus den Faktdaten, EN liefert `North` bis `Northwest`. **Auf Englisch ist das Kompass-Rätsel in der PWA unlösbar.** Verwandt: `puzzle-sheet.jsx:320-323` (Freitext), `screen-challenge.jsx:2326` mit hartcodierten deutschen Antworten in `:808` und `:954`, `bearingName: 'Westen'` in `:427`, `:805`, `:948`. Behebung heißt sprachfreier Antwortwert in den Faktdaten, also Datenstruktur im anderen Repo. | 3, bei Formatänderung 4 | Phase 4 |
| E-09 | **Multiplayer echt oder Mock.** Backend ist fertig (`group_sessions`, `team_sessions`, Realtime-Kanäle). Realtime kommt in keinem Architekturdokument vor. | 3 | Phase 5 |
| E-10 | **3D-Avatar.** WebView mit Three.js behalten (270 KB Assets, JS-Bridge, geografisch verankert auf bewegter Karte) oder in Flutter nachbauen (sichtbare Abweichung). | 3 | Phase 2 |
| E-11 | **City-Identität.** Die Datenbank speichert `facts.city` als Anzeigename, das Frontend nutzt Slugs, die Brücke ist eine SQL-Funktion `_slugify`, welche die JS-Normalisierung nachbaut. Dieser Mismatch hat schon einmal `create_team_session` scheitern lassen. Domain-Map fordert `CityId` als Wertobjekt. | 3 | Phase 0 Schritt 5 |
| E-13 | **AI-Zugang.** Anthropic-Schlüssel niemals im Client, `ai_proxy` und Edge Function nutzen, Quota serverseitig. | **4** | Phase 7 |
| E-14 | **OpenRouteService** für Fußweg-Routen: Konto, Kosten, Rate Limits, Fallback. | **4** | Phase 6 |
| E-15 | **TTS-Weg.** Gerät (`flutter_tts`) oder Cloud. Cloud heißt laufende Kosten. | 4 bei Cloud, sonst 3 | Phase 3 |
| E-16 | **Leaderboard-Sichtbarkeit.** `user_city_scores` und `user_trophies` haben `USING (true)` für SELECT. Alle Punktestände und Trophäen sind für jeden lesbar. Zusammenspiel mit dem Schalter „Echten Namen zeigen". | **4** | Phase 7 |
| E-17 | **Creator-Foto.** Storage-Bucket, Policy, Moderation vor `is_approved`. | 3, Bucket-Anlage 4 | Phase 8 |
| E-19 | **Trusted Time.** Der 45-Minuten-Timer für das Session-Ende und die Finale-Punkte ×1.5 rechnen clientseitig. `security.md` §1 verbietet vertrauenswürdige Zeitstempel aus dem Client. | 3 | Phase 5 |
| E-20 | **Kamera-Permission** für Damals/Heute und Foto-Rätsel, mit Zweckbindung. | 3 | Phase 3 |
| E-23 | **Die Distanzprüfung beim Sammeln ist nicht nur umgehbar, sie ist optional.** Die Policy `create policy "own collected" on public.collected_facts for all using (auth.uid() = user_id)` erlaubt dem Client, direkt in `collected_facts` einzufügen. Damit entfällt `collect_fact_validated` samt der 150-Meter-Prüfung vollständig, und der Trigger `handle_fact_collected` bucht danach Punkte, Stadtwertung und Trophäen. E-07 beschreibt nur, dass die Positionsangabe fälschbar ist; hier braucht man gar keine. | **4** | Phase 2 |
| E-24 | **Coins und Punktestand sind direkt setzbar.** Die Policy `create policy "own profile" on public.profiles for all using (auth.uid() = id)` hat kein `WITH CHECK`. Der Client kann seine eigene Profilzeile aktualisieren, einschließlich `coins` und `score_total`. **Wichtig für die Reihenfolge der Behebung:** wer E-06 behebt, also `increment_coins` absichert, hat damit nichts gewonnen, solange E-24 offen ist. Die Funktion ist dann nur der bequemere von zwei Wegen. | **4** | Phase 2 |
| E-21 | **`start_group_session` ist doppelt definiert**, in `2026-06-04_group_sessions.sql:193` und erneut in `2026-06-05_team_sessions.sql:473`. Welche Version produktiv läuft, hängt an der Ausführungsreihenfolge im SQL-Editor. Backend-Frage, aber der Client hängt daran. | 3, im anderen Repo | Phase 5 |
| E-28 | **Text für `audio.dialog.volumeHint`.** Der Schlüssel wird in `screen-auth.jsx:251` benutzt und existiert **in der PWA nicht**; sie zeigt dem Nutzer wörtlich `🔊 audio.dialog.volumeHint`. Beide Vorlagen beschreiben den Kasten, als hätte er Text. **Die technische Sperre ist seit E-39 weg:** ein handgeschriebener Schlüssel überlebt den Generator jetzt, die Ergänzungs-Map ist der vorgesehene Ort dafür. Offen ist nur noch der Wortlaut, je ein Satz DE und EN. Solange er fehlt, entfällt der Kasten im Neubau weiter, denn erfundener Nutzertext ist keine Lösung. Die bessere Behebung bleibt ein Schlüssel in der PWA; dann räumt die Gegenprüfung des Generators den lokalen Eintrag von selbst wieder ab.<br><br>**Vorschlag, am 28.08.2026 hergeleitet, nicht freigegeben:** DE „Dreh die Lautstärke vorher auf. Der Guide spricht laut los, sobald du in der Nähe einer Sehenswürdigkeit bist.", EN „Turn your volume up first. The guide speaks out loud when you approach a landmark." Bewusst ohne Stummschalter-Hinweis: das ist ein iOS-Begriff und steuert auf keiner der beiden Plattformen die Medienlautstärke, ein Hinweis darauf wäre für die halbe Zielgruppe falsch. Das 🔊-Symbol rendert die PWA außerhalb des Strings, gehört also nicht in den Wert. | 2 | vor Auslieferung |
| E-29 | **DM Sans Kursiv und 700 fehlen als Asset.** Das Goethe-Zitat auf dem Startbildschirm ist kursiv, das letzte Wort fett. `assets/fonts/` hat nur 400, 500 und 600, alle aufrecht. Die PWA hat dasselbe Loch (`styles.css:3` lädt weder Italic noch 700) und lässt den Browser synthetisieren; Flutter tut das für Asset-Schriften nicht. `fontStyle: italic` und `w700` stehen im Code, damit die Absicht stimmt, sobald die Dateien da sind. | 2 | vor Auslieferung |
| E-30 | **`reference-features/settings.md` widerspricht `dependency-rules.md`.** `settings.md:19-27` zeigt einen Notifier in `presentation/notifiers/` neben einem `data/settings_store.dart`, Zeile 33-38 sagt „persists through `SettingsStore`", Zeile 42-44 begründet ausdrücklich, dass es **keine** Domänenschicht gibt. Es gibt keine Verdrahtung, die das erfüllt: den direkten Import meldet `tool/check_architecture.dart` als Regel 17, und ohne Domänenschicht gibt es keinen Ort für den Vertrag. Der gebaute Code weicht deshalb ab und legt den Vertrag nach `lib/features/settings/domain/audio_mode_store.dart`. Zu entscheiden: `settings.md` korrigieren, oder die Ausnahme im Abschnitt „Exceptions" der `dependency-rules.md` schriftlich fassen. | 3 | vor dem Ausbau von `features/settings` |
| E-34 | **Passwort-Reset ist nicht angeboten.** `supabase_flutter 2.17.2` fährt standardmäßig `AuthFlowType.pkce`, und `resetPasswordForEmail` legt den Code-Verifier **auf dem Gerät** ab. Ohne `redirectTo` ginge der Link an die Site-URL, also in die PWA, die den Verifier nicht hat: der Tausch scheitert. Eine Mail zu schicken, deren Link niemand einlösen kann, ist schlechter als kein Angebot. Der Nutzer sieht deshalb kein „Vergessen?" über dem Passwortfeld, Zurücksetzen läuft über die PWA. Die Behebung braucht ein Deep-Link-Ziel und damit eine **neue öffentliche Vertragsfläche**. | 3 | vor Auslieferung |
| E-37 | **Das Launcher-Symbol ist noch das Flutter-Logo.** Android 12 und neuer zeichnet `@mipmap/ic_launcher` über die SplashScreen-API mitten in den nativen Startbildschirm. Der Hintergrund ist seit dem 27.08.2026 richtig (`#FF0F0D0A`), das Symbol nicht. Braucht das FACT-Symbol in allen Dichten, plus eine Entscheidung, ob der native Startbildschirm es überhaupt zeigen soll. | 2 | vor Auslieferung |
| E-41 | **Drei Rätseltypen rendern eine leere Auswahl mit totem Antwortknopf.** `puzzle-sheet.jsx:255-257` und `:268-269` schicken `klang-sinnes-check`, `verstecktes-detail` und `zeitreise` auf `PszMcq`. Diese Zweige sind aber **nur mit leerer Optionenliste erreichbar**, weil `:247` alles mit Optionen vorher abfängt. `PszMcq` erzeugt dann null Antwortknöpfe (`:353-358`), `pick` bleibt `null`, `canSubmit` (`:344`) ist dauerhaft falsch, und das Rätsel ist nur über „Überspringen (0 Punkte)" (`:230-236`) verlassbar. Wie viele Datensätze das trifft, ist **nicht gezählt**: die Markdown-Quellen in `05_Content/facts/` tragen eine andere Typkodierung (`T2`, `T3`, `T9`) als die Datenbank, es braucht die Live-Daten. Zu entscheiden ist, welche Form ein solches Rätsel im Neubau bekommt. Der Zustand ist an `ChoicePuzzle.choices` ablesbar. | 3, verwandt mit E-08 | Phase 4, Schritt 28 |
| E-42 | **Der 150-Meter-Radius der Foto-Rätsel wirkt in der PWA nie.** `screen-map.jsx:3915` übergibt die Nutzerposition als `userPos`, `puzzle-sheet.jsx:50` erwartet sie als `userPosition`. Folge in `PszPhoto`: `:373` liefert immer `null`, `:374` setzt `inRange = true`, und die Näherungsprüfung `:378` läuft nie. `foto-beweis` und `perspektiven` sind damit von überall mit einem beliebigen Foto lösbar, obwohl `gpsRadius` (`:372`) in den Daten durchgehend auf 150 steht. Dieselbe Klasse wie E-08: ein Defekt der Quelle, der wie Parität aussieht, und wie E-07 einer, der eine Ortsprüfung aushebelt. **Ändert sichtbares Verhalten, geht deshalb an Janek.** | 3, verwandt mit E-07 | Phase 4, Schritt 28 |
| E-44 | **Der Faktor 1,5 am letzten Stopp wird angezeigt, aber nicht gutgeschrieben.** `screen-challenge.jsx:2479` übergibt dem Nächster-Fakt-Abzeichen `isLast ? Math.round(diff.points * 1.5) : diff.points`. Die tatsächlich vergebenen Punkte rechnet `handleChallengeComplete` (`:2295-2299`), und dort kommt der Faktor nicht vor. Das Abzeichen verspricht am letzten Stopp das Anderthalbfache, gutgeschrieben wird der einfache Satz. Widerspruch in der Quelle, nicht in E-19. Sichtbares Verhalten. | 3 | Schritt 37 |
| E-47 | **Drei Bedienelemente im Challenge-Reiter tun bis Schritt 35 nichts.** Seit Schritt 33 zeigt der Reiter den Assistenten. Wer ihn zu Ende bedient, drückt einen vollflächigen roten Knopf „Starten", sieht die Drück-Animation und danach passiert nichts, weil der Startpunkt-Picker fehlt. Dasselbe gilt für die Kachel „Gruppe" und für „Mit Code beitreten", deren Formulare Sitzungen über Supabase anlegen müssten, die es im Neubau nicht gibt. **Eine Sackgasse ist es nicht**, der Zurück-Knopf und die Tab-Leiste bleiben erreichbar, gemessen im Widget-Test. Aber es ist derselbe Zustand, den E-33 beim Kästchen „Angemeldet bleiben" beanstandet, und der Bau begründet an anderer Stelle ausdrücklich, warum die Zufallskarte **nicht** antippbar ist („ein Tipp, der nichts ändert, ist ein Bedienelement, das nichts tut"). Die Ungleichbehandlung ist bewusst, weil eine erfundene Navigation schlechter wäre als keine, aber sie gehört gewusst. Löst sich mit den Schritten 35 und 40 von selbst auf. | 2 | Schritt 35 |

## Wie Tests hier blind werden

Jedes Muster unten ist in diesem Repository einmal aufgetreten und hat eine
grüne Suite über eine falsche Aussage laufen lassen. Wer hier einen Test
schreibt, liest das **vorher**, sonst kostet es beim nächsten Mal wieder einen
halben Tag.

1. **Ein Zeilenumbruch ist kein Überlauf.** Flutter meldet nichts, es bricht
   einfach um, und `takeException()` bleibt leer. Beleg: die Sprachzeile des
   Startbildschirms stand sichtbar als „Deutsc / h", obwohl Tests für genau
   diese Zeile existierten. Ursache war `Row` mit `Expanded`, das die Breite
   verteilt, bevor es die Kinder nach ihrem Bedarf fragt: eine Karte braucht
   127,1 Pixel min-content, verfügbar waren 118. Zweiter Beleg: die
   Fremdanmeldungs-Knöpfe waren bei Systemschrift 2.0 unterschiedlich hoch (64
   gegen 104 Pixel), gesehen hat es keiner der vier Skalierungstests. Ein Test,
   der Rechtecke misst, findet beides sofort.
2. **Ein `Stack` clippt lautlos.** Beleg: `TourBubble` schnitt bei
   Systemschrift 2.0 auf kleinen Geräten Text ab, ohne einen Überlauf zu melden.
   Die richtige Lösung lag zweimal im selben Ordner, `TourHeroView` und das
   Testmuster aus `signup_page_test.dart`, nur bei der Blase fehlte sie.
3. **Ein Testrahmen ohne die Vorfahrenkette der App misst die falsche Sache.**
   Beleg: E-40, `map_top_chrome_test.dart` pumpte ein nacktes `MaterialApp`. Der
   Rahmen steht jetzt auf `FactTheme.light()` plus `Material`, und **keine
   einzige Maßzahl hat sich dadurch geändert** — der Test hatte die ganze Zeit
   recht und trotzdem über die falsche Sache.
4. **Ein Bildtest, der die Fläche misst, sieht den Inhalt nicht.** Dreimal in
   einer Woche passiert, zwei davon benannt: die Ballon- und Gruppenbilder in
   den Schritten 15 und 16, die Nah-Animation in Schritt 17. Man konnte Emoji,
   Rahmen, Farbring, Drehrichtung und Schattenlage ändern, ohne dass etwas
   anschlug. Zahlen in den jeweiligen Abschnitten.
5. **Ein Tipp, der außerhalb des Sichtfelds landet, trifft nichts, und Flutter
   warnt nur.** Beleg: vier Skalierungstests in Schritt 21 tippten „Mehr
   anzeigen" an, der Knopf lag bei doppelter Systemschrift außerhalb des
   Sichtfelds, zwei der vier Kombinationen waren dadurch blind. Im Lauf standen
   zwei Warnungen, und ein grünes Gate hat sie durchgewinkt. Gegenmittel, seitdem
   in dieser Testdatei gesetzt: `WidgetController.hitTestWarningShouldBeFatal =
   true`, damit ein Fehlgriff ein Fehler ist statt einer Zeile, die niemand
   liest.
6. **Umbruch, Ellipse und Überlauf sind drei verschiedene Dinge, und
   `takeException()` sieht nur das dritte.** Beleg: in Schritt 21 überlebte eine
   Mutation, weil der Ortsname bei gleichen Flex-Anteilen ein
   **Auslassungszeichen** bekommt, ohne dass eine Ausnahme fällt. Jetzt misst
   der Test `RenderParagraph.didExceedMaxLines`.
7. **Dart kanonisiert `const`.** `expect(const FactId(7), const FactId(7))`
   prüft nichts, beide Seiten sind dasselbe Objekt, und eine Mutation von `==`
   auf `identical` überlebt. Beleg: zweimal in den Wertobjekt-Tests aus Schritt 5
   und einmal bei `AuthSession.==`, wo mit dem Gleichheitstest zugleich der Test
   gegen das Erneuerungs-Gewitter im Router wertlos war; nach der Korrektur
   fällt die Mutation an fünf Stellen. Das richtige Muster steht in
   `auth_city_test.dart:59`. Echte Sitzungen entstehen zur Laufzeit und sind
   nicht konstant.
8. **`SelectableText` und `EditableText` tauchen in `find.byType(RichText)` gar
   nicht auf.** Wer Textstile über Finder einsammelt statt über einen Durchlauf
   des Renderbaums, übersieht jedes Eingabefeld. Beleg: E-40, die zweite Quelle
   `bodyLarge` blieb dadurch unbemerkt.
9. **Eine Begründung, die sich als gemessen ausgibt, wird nie nachgeprüft.** Das
   ist das teuerste Muster in diesem Projekt, sechs Fälle in einer Woche: die
   Verkürzung von Vorrangregel 2 auf einen Zeitpunkt; das Steuerfenster von
   200 ms, dessen Preis falsch beschrieben war; der leere Kompass-Befehl, dessen
   Begründung die Auto-Neigung vergaß; die Gestenarena als angeblicher Grund für
   bedingte Erkenner; die Zeilennummer `:451`, die auf eine Leerzeile zeigte und
   eine technische Aussage trug; und vier Ballon-Zahlen, die aus `coinMakeEl`
   korrekt abgeschrieben und trotzdem falsch waren. Dazu die 41 von 138 falschen
   Fundstellen im Karten-Chrome. Fundstellen und Begründungen sind hier
   Vertragsfläche, keine Zierde.
10. **Zwei Stellen, gleiches Muster, nur eine geprüft.** Das ist die Stelle, an
    der man in diesem Projekt suchen muss. Belege: die Anmeldung hätte E-Mail und
    Passwort vertauschen können und alle 614 Tests wären grün geblieben, weil nur
    der Notifier-Test `lastEmail` las, der Seiten-Test nie, während die
    Registrierung an derselben Stelle dicht war; `MapCameraChange` hatte den
    Gleichheitstest nicht, sein Zwilling `MapCameraView` schon; und die
    Durchreichung im echten Karten-Host hatte null Tests, während alles um sie
    herum vorbildlich getestet war.
11. **Eine eigene `MediaQuery` um `FactApp` verdeckt die echte.** `pumpWidget`
    steckt das Widget in ein `View`, und erst dieses legt `MediaQuery.fromView`
    an; die eigene sitzt darunter, `size` und `padding` fallen auf Null, und jede
    Layout-Zusicherung ist lautlos wertlos. Gemessen: 141 statt 0 als
    `view.padding.top`. Der richtige Weg ist
    `tester.platformDispatcher.accessibilityFeaturesTestValue`.
12. **`flutter test` sieht kein XML.** Eine Mutationsprobe hat belegt, dass der
    native Startbildschirm für die Suite vollständig unsichtbar ist: seine Farbe
    auf Weiß zu setzen überlebte alle vier Gates. Dafür gibt es jetzt
    Dateiprüfungen.
13. **`rootBundle` cacht das `Future` über Testgrenzen hinweg.** Ein Test, der
    einen Ladevorgang anstößt, ohne ihn abzuwarten, lässt ein totes `Future` in
    seiner `FakeAsync`-Zone zurück, und **jeder folgende Test** bekommt genau
    dieses. Beleg: vier Tests fielen mit „Bad state: No element", **ohne jede
    Ausnahme**, und sahen eine Karte, die ewig lädt. `rootBundle.clear()` im
    `setUp` behebt es.
14. **Zwei Helfer hängen im Rumpf von `testWidgets` bis zur
    Zeitüberschreitung:** `pumpEventQueue()` und `loadAppFonts()`. Der Aufruf
    gehört in `setUpAll`, weil im Rumpf eine `FakeAsync`-Zone läuft, in der echte
    Datei-Ein-/Ausgabe nie fortschreitet. Warum die Schriften überhaupt geladen
    werden müssen, steht oben unter „Echte Schriften in Widget-Tests".
15. **Ohne Mutationsproben sieht eine Testdatei vollständig aus und ist es
    nicht.** Beleg: in Schritt 7 überlebte „der Knopf Anmelden öffnet die
    Registrierung" die ganze Suite. Was einen guten Prüfauftrag ausmacht, steht
    in `HANDOFF.md` unter „Arbeitsweise mit Claude".
16. **Ein Test, der `lib/` nach einer Zeichenkette durchsucht, findet zuerst
    sich selbst, und wer das behebt, reisst ein Loch auf.** Beide Hälften sind
    in Schritt 27 passiert. Die Einstiegs-Wache des Rätsel-Sheets schlug im
    ersten Lauf an, weil in **ihrem eigenen Kopfkommentar** das Wort steht, nach
    dem sie sucht. Die naheliegende Behebung, vor dem Vergleich alles ab dem
    ersten `//` einer Zeile abzuschneiden, hat die Wache dann umgehbar gemacht:
    ein Konstruktoraufruf muss nicht **in** einer Zeichenkette stehen, sondern
    nur **dahinter auf derselben Zeile**, und ein Kartenschlüssel wie `'//r':`
    reicht. Die Review hat genau das als Probe gebaut, ein echter benutzbarer
    Einstieg, und er kam durch `dart format`, `dart analyze`, den
    Architektur-Check **und** die Wache. Wer eine Textsuche als Zusicherung
    benutzt, schreibt ihre bekannte Grenze in ihren Kommentar, sonst entschärft
    sie der Nächste beim ersten Fehlalarm.
17. **`MaterialApp` legt ein `AnimatedTheme` über seinen Inhalt.** Ein
    Themenwechsel im laufenden Baum blendet über `kThemeAnimationDuration`
    hinüber, und nach einem einzelnen `pump()` steht
    `Theme.of(context).brightness` noch auf dem alten Wert. Der Test sieht dann
    aus wie ein Fehler im Widget und ist einer im Rahmen. Beleg: der
    Themen-Test des Rätsel-Sheets, seitdem in zwei getrennten `testWidgets`
    statt einem.
18. **Eine Zusicherung gegen die Konstante, die sie festnageln soll, prüft
    nichts.** `expect(station.color, PuzzleSheet.stationLineColor)` ist immer
    wahr, egal welchen Wert die Konstante trägt; wer sie ändert, ändert beide
    Seiten der Gleichung. Beleg: beim ersten Mutationsdurchlauf von Schritt 27
    überlebten „Textschattenfarbe" und „Stationszeilen-Farbe", obwohl gerade
    Zusicherungen dafür geschrieben worden waren, und dieselbe Form steckte in
    zwei älteren Zeilen. Der Wert muss aus der **Quelle** kommen, nicht aus dem
    Code, den er bewachen soll. Verwandt mit Muster 9: die Zusicherung sieht
    gemessen aus und ist es nicht.
19. **`toImage()` hängt im Rumpf von `testWidgets` bis zur Zeitüberschreitung.**
    Zehn Minuten ohne eine einzige Meldung. Das ist Muster 14 mit einem dritten
    Helfer neben `pumpEventQueue()` und `loadAppFonts()`, und der Ausweg ist
    hier ein anderer: nicht `setUpAll`, sondern `tester.runAsync`. Der
    Unterschied zu Muster 13 ist die **Zone**, nicht die Zeit.

## Datenvertrag: die bekannten Fallen

Ein einzelner falscher Cast in `Fact.fromJson` löscht die gesamte Faktenliste,
weil es keinen statischen Fallback gibt. Mapping deshalb feldweise mit
Einzelfehler-Isolation: ein defektes Feld degradiert einen Fakt, ein defekter
Fakt degradiert nicht die Liste.

| Spalte | Typ in der Datenbank | Falle |
|---|---|---|
| `puzzle_fit` | `jsonb`, inhaltlich ein Array von 2 bis 4 Rätsel-Objekten | Früher war es ein Schwierigkeits-String `leicht\|mittel\|schwer`. Der alte Port trägt beide Bedeutungen im selben Feldnamen. Beim Neubau trennen: eine Liste `puzzles`, und wenn nötig eine abgeleitete `difficulty`. Das Mapping muss **alle** Felder übernehmen (`choices`, `targetCount`, `bearing`, `formula`, Bild), sonst degradiert jedes Rätsel auf Text. Genau daran ist der alte Port gescheitert. |
| `hero` | `text[]` mit Vorgabe `['#2C3E50','#4A6741']` | Postgres-Array, kommt als JSON-Liste. Wird als Gradient benutzt. |
| `hint_media` | `jsonb`-Objekt | Muss Map, http-String und `null` tolerieren. |
| `_i18n` | `jsonb not null default '{}'` | **Existiert**, entgegen der Behauptung im REBUILD_PLAN. Migration `2026-06-06_i18n_facts.sql` legt Spalte und GIN-Index an und definiert `pickFact(fact, lang)` als einzigen erlaubten Zugriffsweg. |
| `city` | `text`, nachträglich ergänzt | Existiert erst seit `2026-06-07`, gefüllt aus dem `nr`-Präfix, kann für neue Datensätze `NULL` sein. |
| `zone`, `next_station_hint` | `integer`, `text` | Der REBUILD_PLAN nennt sie `next_hints`. Der Feldname im Plan stimmt nicht mit dem Schema überein. |

## Korrekturen an den Quelldokumenten

Nachgewiesene Sachfehler in den Vorlagen. Wer sie liest, muss das wissen.

1. **REBUILD_PLAN Grundprinzip 3 behauptet, `facts` habe kein `_i18n`.** Falsch,
   siehe oben. Wer dem Plan folgt, baut den zweisprachigen Renderpfad nicht.
2. **REBUILD_PLAN Schritt 3 ordnet `:root` dem hellen und `.theme-dark` dem
   dunklen Theme zu.** In `styles.css` ist `:root` das **dunkle** Theme, und die
   überschreibende Klasse heißt `.theme-light`. Ein `.theme-dark` existiert dort
   nicht.
3. **Parity-Spec Abschnitt 0 nennt Nunito 600 nicht als benötigtes Gewicht.**
   Es wird benutzt, in `chrome.jsx:115` und `:197` für die Tab-Bar und in
   `screen-entdecken.jsx:170` für die Modus-Chips.
4. **Parity-Spec und REBUILD_PLAN nennen 761 bis 763 i18n-Schlüssel.** Die
   Quelle hat **716** je Sprache (683 aus `translations.jsx` plus 33 aus
   `audio-strings.jsx`). Die 763 ist der Bestand des **alten Flutter-Ports**.
   Die Rechnung geht auf: 763 minus 84 Schlüssel, die es in der PWA nicht gibt,
   ergibt 679 gemeinsame, und 716 minus 679 sind die 37 fehlenden. Der Spec
   nennt 35, weil er `creator.steps` und `profil.levelTitles` nicht zählt.
5. **Zwei Schlüssel nutzen eine zweite Interpolationsform.**
   `group.active.counter` und `group.results.summary` arbeiten mit `%d` statt
   `{name}`, positionsweise ersetzt in `screen-challenge.jsx:3506` und `:3602`.
   `AppStrings.text()` löst `%d` nicht auf. Wer den Gruppenmodus portiert,
   formatiert diese beiden am Aufrufort. Per Test festgenagelt.

6. **Der zeitgesteuerte Boot-Splash existiert nicht mehr.** Er wurde am
   06.06.2026 in Commit `83be52f` aus `index.html` entfernt („Startbildschirm-Marke
   '!' entfernt"). Das Steuerskript steht noch da, beginnt aber mit
   `if (!splash) return`. Die Zahlen `MIN_MS = 1200` und `TIMEOUT_MS = 15000`
   gehören zu diesem toten Pfad, ebenso `@keyframes splashFadeOut`. Wer sie
   nachbaut, baut einen Ladebildschirm, den die Quelle bewusst abgeschafft hat.
7. **REBUILD_PLAN Schritt 7 ist unvollständig.** Er nennt Wortmarke, Untertitel,
   Sprachpicker, CTAs, Ballon-Pins, Bottom-Wash und Goethe-Zitat, aber nicht das
   Gitter-Overlay, den radialen Lichtkegel, den Kennzahlen-Streifen „950+ / 4",
   den 🎧-Knopf und den Gast-Ausgang „Ohne Konto erkunden". Der Gast-Ausgang
   fehlt auch in der Parity-Spec, obwohl er die Startmaschine substanziell
   verändert: ohne ihn wäre die Anmeldung faktisch Pflicht.
8. **`@keyframes slideUp` ist zweimal definiert**, in `styles.css:251` mit
   `translateY(100%)` und in `index.html:25` mit `translateY(24px)` plus
   Deckkraft. Der Inline-Block steht nach dem Stylesheet, bei gleichnamigen
   Keyframes gewinnt die letzte Definition. **Maßgeblich ist `index.html:25`.**
   Dasselbe gilt für `.screen-transition`. Wer nur `styles.css` liest, portiert
   die falsche Animation.
9. **Parity-Spec: der Wortmarken-Untertitel ist kein großgeschriebenes Literal.**
   Die Quelle enthält `Stadtführer · Urban Explorer` in gemischter Schreibung und
   macht die Großschreibung per `textTransform: uppercase`
   (`screen-auth.jsx:51`). Ein Nachbau muss die Transformation übernehmen.
10. **Parity-Spec: die `audio.dialog.*`-Schlüssel fehlen nicht.** `title`, `body`,
   `activate` und `cancel` existieren in `audio-strings.jsx`. Es fehlt genau
   einer, `audio.dialog.volumeHint`, und der fehlt **in der PWA selbst**: sie
   zeigt dem Nutzer wörtlich `🔊 audio.dialog.volumeHint`. Siehe E-28.
11. **REBUILD_PLAN: das Signup hat kein Feld „Name".** Es hat ein Feld
   **Username** mit dem Regex `^[a-zA-Z0-9_]{2,20}$`, `maxLength 20` und einem
   um 500 ms verzögerten Server-Check über `check_username`. Der alte
   Flutter-Port ist an dieser Stelle richtig, der Plan nicht.
12. **Die Kommentare der PWA über die Tutorial-Schritte sind falsch.**
   `screen-tour.jsx:2` und `:137` sagen „8 Schritte", `storage.jsx:99` sagt
   „5-Schritt". Es sind **neun**, belegt dreifach: neun Objekte im `STEPS`-Array,
   `tour.step1` bis `tour.step9` in beiden Sprachen, und die Anzeige rechnet mit
   `STEPS.length`. Hier hilft es nicht, der Quelle zu glauben, man muss zählen.
13. **Die Anker-Bilanz des Tutorials, und damit der Umfang von Schritt 11.**
   `HANDOFF.md` hat behauptet, sechs der neun Schritte seien heute voll baubar
   und drei degradierten. Aus `screen-tour.jsx:140-169` folgt etwas anderes:
   neun Schritte, davon zwei Hero-Schritte ohne Anker und sieben mit Anker, und
   von diesen sieben liegen **fünf** auf dem Kartenbildschirm (`balloon`,
   `user-marker`, `coins`, `mode-tour`, `compass`). `map_page.dart` ist heute
   ein Platzhalter mit einem einzigen `Text`. Voll baubar sind also die Schritte
   1, 5, 7 und 9, es heißt **4 baubar und 5 degradierend**. Zwei der fünf,
   `balloon` und `user-marker`, sind auch in der PWA keine festen Anker: sie
   fallen dort auf Bildschirmanteile zurück (`:219` und `:239`). Die
   „Bildschirmanteile", welche die Parity-Spec als Lücke des alten Ports
   markiert, sind für genau diese zwei also der dokumentierte Weg der Quelle.

## Bewusste Auslassungen

Damit sie nicht später als Versehen „repariert" werden.

- **Keine globale Schriftgrößen-Skala.** Die PWA setzt Größen direkt am Element.
  Eine erfundene Skala würde beim Portieren von den echten Werten ablenken.
- **Keine Schatten-Tokens.** `--shadow-sm`, `--shadow-md`, `--shadow-lg` und
  `--shadow` haben in der PWA null `var()`-Verwendungen, alle 169 Schatten liegen
  inline am Element.
- **`.go(variable)` wird vom Architektur-Check nicht gemeldet.** Genau so sehen
  typisierte Routen aus. Ein Verbot würde ADR-004-konformen Code melden.

## Der Android-Build-Blocker, forensisch

Gelöst am 27.08.2026. Die Umgehung und der Schnelltest stehen in `HANDOFF.md`
unter „Rechner einrichten"; hier stehen die Belege, damit niemand die zwei Tage
noch einmal bezahlt.

**Ursache:** `Selector.open()` scheitert, weil Java dafür einen
Unix-Domain-Socket im Temp-Verzeichnis anlegt, und AF_UNIX ist auf diesem
Rechner unter `AppData` nicht verbindbar. Die Fehlermeldung „Unable to establish
loopback connection" ist irreführend: der scheiternde Vorgang ist **kein
Netzwerkaufruf**, sondern ein Verbindungsaufbau auf eine **Datei**.

Der Weg dorthin, aus den JDK-Quellen (`lib/src.zip` von Temurin):

```
WEPollSelectorImpl.java:79   new PipeImpl(sp, /* AF_UNIX */ true, /*buffering*/ false)
PipeImpl.java:127            createListener(preferUnixDomain)
PipeImpl.java:132            SocketChannel.open(sa)      // sa ist eine UnixDomainSocketAddress
```

`Pipe.open()` ruft denselben Konstruktor mit `false` und geht über TCP, deshalb
**gelingt `Pipe.open()` und scheitert `Selector.open()`**. Wer die beiden
verwechselt, schließt aus einem erfolgreichen `Pipe.open()`, Java sei in
Ordnung, und sucht danach an der falschen Stelle. Genau das ist hier zwei Tage
passiert.

Der Pfad der Socket-Datei kommt aus `jdk.net.unixdomain.tmpdir` und zeigt
standardmäßig auf `java.io.tmpdir`, unter Windows also nach
`%LOCALAPPDATA%\Temp`. Gemessen:

| Verzeichnis für die Socket-Datei | AF_UNIX `connect` |
|---|---|
| `C:\Users\<user>\AppData\Local\Temp` (Standard) | **Fehler** |
| `C:\Users\<user>\AppData\Local\<beliebig>` | **Fehler** |
| `C:\Users\<user>\AppData\<beliebig>` | **Fehler** |
| `C:\Users\<user>\<beliebig>` | OK |
| `C:\Users\Public\<beliebig>` | OK |
| `C:\Windows\Temp` | OK |
| `C:\gtmp` | OK |

**Alles unter `AppData` scheitert, alles andere funktioniert.** `bind` gelingt
jeweils, die Socket-Datei entsteht, nur `connect` darauf nicht. Nicht die
Ursache: Pfadlänge (61 Bytes am Wurzelpfad gehen, 54 unter `AppData` nicht), der
8.3-Kurzname `JANEKP~1`, das Leerzeichen im Profilnamen, Reparse-Punkte, der
Ordnerschutz von Defender. **Warum es früher funktionierte:** vermutlich hat
sich die Bedingung unter `AppData` geändert, nicht Java und nicht Gradle. Der
eigentliche Systemdefekt ist damit nicht behoben, nur umgangen.

Belegt am leeren Testprojekt unter `C:\gtmp\gt`:

```
ohne die Variable : EXIT=1  java.io.IOException: Unable to establish loopback connection
mit der Variable  : EXIT=0  BUILD SUCCESSFUL in 5s
```

Die Prüfschleife dauert eine Sekunde statt eines Builds. Als
`SelectorProbe.java` ablegen und mit `java SelectorProbe.java` starten
(Quelldatei-Modus, kein `javac` nötig); die Datei liegt unter
`C:\gtmp\SelectorProbe.java`.

```java
import java.nio.channels.Pipe;
import java.nio.channels.Selector;

public class SelectorProbe {
  public static void main(String[] a) {
    try { Pipe p = Pipe.open(); p.source().close(); p.sink().close();
      System.out.println("Pipe.open() OK");
    } catch (Throwable t) { System.out.println("Pipe.open() FEHLER: " + t); }
    try { Selector s = Selector.open(); s.close();
      System.out.println("Selector.open() OK");
    } catch (Throwable t) { System.out.println("Selector.open() FEHLER: " + t.getCause()); }
  }
}
```

Gesund: beide Zeilen `OK`. Defekt: `Pipe.open() OK`, dann
`Selector.open() FEHLER: java.net.SocketException: Invalid argument: connect`.

**Was vorher ausgeschlossen wurde.** Geschichte, kein Arbeitsvorrat. Sie steht
hier, weil sie zeigt, wie teuer eine irreführende Fehlermeldung wird:
**vierzehn Vermutungen, jede einzeln gemessen, alle im Netzwerk-Stack, alle
richtig ausgeschlossen und alle am falschen Objekt.**

Temp-Pfad mit Leerzeichen · Sandbox der Werkzeugumgebung · Loopback generell
(Python verbindet 127.0.0.1 fehlerfrei) · `Pipe.open()` (gelingt, siehe oben) ·
reservierte und ausgeschlossene Portbereiche · Speichermangel ·
IPv6-Auflösung von `localhost` · hängender Gradle-Daemon · beschädigte
Daemon-Registry · Neustart · TotalAV vollständig deinstalliert ·
Selektor-Implementierung (auch der alte `WindowsSelectorProvider`) · das JDK
(JBR 17, 21, 25 **und** Temurin 21) · `--no-daemon` · alle fünf
JVM-Umgebungsvariablen · Winsock-Katalog (kein einziger Layered Service
Provider) · Netzwerk-Filtertreiber (nur Microsoft) · Defender Network
Protection · `hosts`-Datei · Reihenfolge im Prozess · **Winsock- und IP-Reset
samt Neustart**.

Eine Fehlspur ist erwähnenswert, weil sie überzeugend aussah: im WFP-Dump steht
ein Filter von **Rivet Networks** (Killer Networking) auf
`FWPM_LAYER_ALE_CONNECT_REDIRECT_V4`, ohne Bedingungen, mit Aktion
`FWP_ACTION_CALLOUT_TERMINATING`, und die Software ist längst deinstalliert. Das
passte perfekt zur Fehlermeldung und war trotzdem falsch. Widerlegt hat es ein
einfacher Gegencheck: ein Filter ohne Bedingungen würde **jede** Verbindung
treffen, und das Netz funktioniert. Drei Löschversuche über die
WFP-Schnittstelle scheiterten ohnehin an `ERROR_NOT_SUPPORTED`, es wurde also
nichts verändert.

Die Lehre: **den Aufrufweg lesen, bevor man der Fehlermeldung glaubt.** Die
vollständige Stapelspur (`--stacktrace`) und dreißig Zeilen JDK-Quelle haben
gelöst, was vierzehn Systemmessungen nicht gelöst haben.

### Nebenbefunde des ersten Gerätelaufs, 27.08.2026

- Der wirksame native Startbildschirm ist `drawable-v21/`, nicht `drawable/`,
  und `NormalTheme` wiegt schwerer als `LaunchTheme`, weil `FlutterActivity` in
  `onCreate` darauf umstellt.
- Der Emulator hatte 2 GB und schoss die App per `lowmemorykiller` ab, jetzt
  4 GB.
- Zweimal sind hier falsche Ergebnisse entstanden, weil Auswertung und Ausgabe
  in einer `&&`-Kette gemischt waren: einmal kam ein Exit-Code 0 von `tail`,
  während der Build mit 1 abbrach, einmal lief ein Build gar nicht, weil ein
  vorgeschaltetes `grep` die Kette abbrach.
- Ein frischer Worktree ohne `.dart_tool/` lässt `dart analyze` „Target of URI
  doesn't exist" für **jede** Datei melden. Erst `flutter pub get` macht die
  Gates aussagefähig; wer den ersten Lauf für ein Ergebnis hält, sucht den
  Fehler an der falschen Stelle.

## Noch am Gerät zu verifizieren

Nicht durch Tests abdeckbar, muss auf echter Hardware oder im Emulator geprüft
werden.

- Variable Schrift `Nunito[wght].ttf`: ob die Gewichtsachse über
  `fontVariations` tatsächlich rendert. Schriften werden in Widget-Tests nicht
  geladen.
- ~~`maplibre_gl 0.27.0`: ob `minSdk` angehoben werden muss.~~ **Am 27.08.2026
  geprüft und widerlegt.** Es setzt bei `minSdkVersion 21` an. Der echte Konflikt
  lag bei AGP 9 und Kotlin, Begründung im Kommentar in `pubspec.yaml`.
- ~~Der erste Android-Build überhaupt.~~ **Am 27.08.2026 gelaufen.** Debug-APK
  gebaut, auf dem Emulator installiert, Startbildschirm, Anmeldung und
  Registrierung gesehen (Pixel 8, 411 logische Pixel, Systemschriftgröße 1.0).
  **iOS ist weiter nie compiliert worden.**
- Offen bleibt: iOS, echte Hardware, 360 und 320 logische Pixel,
  Systemschriftgröße 2.0, und ein Vergleich mit einem Screenshot der laufenden
  PWA, um Schriftmetriken, Schatten und Abstände zu belegen statt sie aus
  Zahlenwerten zu schließen.
