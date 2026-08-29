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
  Browser-Standardschrift, in der die PWA sie unbeabsichtigt rendert. Folge,
  die dazugehört: Arial kennt kein Gewicht 900, in der PWA sehen beide Knöpfe
  gleich fett aus, hier nicht.
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

### Was `maplibre_gl 0.26.2` nicht kann, gemessen im Pub-Cache

Sechs Löcher, keins davon dokumentiert, und alle sechs prägen den Entwurf:

1. **Kein `isEasing()`**, null Treffer im Paket. Vorrangregel 3 hängt genau daran.
2. **`isCameraMoving` ist kein Ersatz, sondern eine Falle.** Gesetzt über
   `onCameraMoveStartedPlatform` (`lib/src/controller.dart:185`), gilt für jede
   Bewegung, auch fürs Ziehen mit dem Finger. `isEasing` meint nur
   programmgesteuerte Animation.
3. **`animateCamera` liefert auf iOS immer sofort `null`** (`controller.dart:416`,
   eigene Doku). Taugt nicht zum Abwarten. Gilt genauso für `moveCamera`.
4. **Kein `stop()`, kein `cancel()`** am Controller, obwohl Vorrangregel 1
   „bricht alles ab" heißt. Der harte Reset kann nur überschreiben.
5. **Kein `onCameraMoveStarted`** als Widget-Rückruf.
6. **`OnCameraMoveCallback = void Function(CameraPosition)`**, ohne Ursache,
   ohne `isGesture`.

Folge: der Host führt seinen Animationszustand selbst, und „der Nutzer hat
angefasst" ist nur als **unerklärte Kamerabewegung** erkennbar.

7. **Kein dauerhaftes Kamera-Padding.** `screen-map.jsx:1694` setzt
   `map.setPadding({ top: 320 })` und verschiebt damit den wirksamen
   Kartenmittelpunkt um 320 Pixel nach unten, damit die Figur im unteren
   Drittel steht. Im Paket gibt es `setPadding` nicht. `padding` kommt an zwei
   Stellen vor, `CameraUpdate.newLatLngBounds`
   (`maplibre_gl_platform_interface-0.26.2/lib/src/camera.dart:106-119`) und
   `setCameraBounds` (`controller.dart:1811-1826`). Die zweite grenzt den
   **erlaubten Kartenausschnitt** ein; wer sie für ein Kamera-Padding hält,
   sperrt das Schieben ein, statt die Kamera zu versetzen. **Entscheidet in
   den Schritten 15 bis 18**, wo Nutzermarker und Avatar landen und wie ein
   Neuzentrieren aussieht.
8. **`maxPitch` und `minPitch` haben kein Gegenstück** (`:1677-1678`), das SDK
   klemmt die Neigung zoomabhängig und still. Folgenlos, solange die
   Auto-Neigung bei 58 endet. `dragRotate: false` (`:1681`) ist auf dem Gerät
   gegenstandslos, es betrifft nur die Maus.

**Ungemessen und beim nächsten Gerätelauf zu klären:** ob `moveCamera` eine
laufende `animateCamera` auf maplibre-native wirklich verwirft. Wenn nicht,
springt die Kamera beim harten Reset in die Reset-Pose und kriecht danach
wieder weg. Prüfbar in Minuten: ein `jumpTo` mitten in ein 1500-ms-`flyTo`
setzen und zusehen.

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
bevor der nächstgelegene Ballon wieder stufenlos wächst, sich dreht und glüht.
Betroffen ist ohnehin nur einer, der nächste innerhalb 150 Metern
(`screen-map.jsx:2217-2232`, dort selbst als Korrektur dokumentiert).

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

### Vor Schritt 15 geprüft: drei Paketfallen bei Markern und Clustern

Alle drei am Pub-Cache belegt, alle drei lautlos, keine davon dokumentiert.

**1. `addGeoJsonSource` kann nicht clustern.** Die Methode, deren Name genau
das verspricht, reicht auf Android nur `withSynchronousUpdate` durch
(`MapLibreMapController.java:448`), es gibt keinen Cluster-Schalter. Eine so
angelegte Quelle clustert **nie**, ohne Fehlermeldung. Der tragende Weg ist
`addSource` mit `GeojsonSourceProperties`, das `cluster`, `clusterRadius` und
`clusterMaxZoom` führt; umgesetzt in `SourcePropertyConverter` auf beiden
Plattformen. Dieselbe Sorte Falle wie `PLAIN_MAP_LOOK`: der naheliegende Name
liefert das Falsche, und wer den Fehler beim Layer sucht, sucht Stunden.

**2. `getClusterExpansionZoom` gibt es nicht.** Null Treffer im ganzen Paket,
ebenso `getClusterChildren` und `getClusterLeaves`. Die PWA rechnet damit die
Zoomstufe, ab der genau dieser Cluster zerfällt (`screen-map.jsx:2447-2451`).
Das ist die einzige Stelle, an der die Überlagerung in den **fertigen**
Kameravertrag hineingreift, siehe D-b.

**3. Der Antipp-Rückruf liefert keine `properties`.** Android schickt nur
`layerId` und `feature.id()`, iOS nur `id`, `layerId` und die Positionen, und
Dart macht daraus blind `payload["id"].toString()`. Die PWA legt die
Fakt-Kennung nach `properties.id` (`screen-map.jsx:1896`). **Wer das GeoJSON
eins zu eins übernimmt, bekommt beim Antippen die Zeichenkette `"null"`**,
ohne Ausnahme und ohne Warnung. `promoteId` rettet das nicht, es wirkt laut
eigener Doku nur im Web und wird vom Android-Konverter gar nicht gelesen.
**Kein Test in diesem Repository kann das finden**, weil ohne Plattformkanal
kein Controller entsteht. Es fällt am Gerät auf, und dort als „beim Tippen
passiert nichts".

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

- [x] 12. MapLibre mit gebackenem Style · [x] 13. Kamera-Verhalten
- [ ] 14. Kompass-Rotation · [ ] 15. Cluster-Layer · [ ] 16. Einzel-Marker
- [ ] 17. Münz-Proximity-Animation · [!] 18. 3D-Avatar (WebView-Entscheidung)
- [ ] 19. Top-Chrome · [ ] 20. Sammel-Erlebnis

## Phase 3, Fakt-Akte und Audio

- [ ] 21. Fact-Detail-Sheet · [ ] 22. Collect-Reveal-Overlay
- [ ] 23. Akte-Interaktion · [ ] 24. Damals/Heute · [!] 25. Audio-Service (TTS-Weg)
- [ ] 26. Map-Audio-Kopplung

## Phase 4, Rätsel-Engine

- [ ] 27. Puzzle-Sheet mit vollem Mapping · [!] 28. Alle Rätseltypen
  (sprachneutrale Auswertung) · [ ] 29. In-Puzzle-Hint · [ ] 30. Reveal-Screen
- [!] 31. Hinweis-Ökonomie (Reward-Ledger) · [!] 32. Punkte gegen Coins

## Phase 5, Challenge

- [ ] 33. Wizard · [ ] 34. Solo-Setup · [ ] 35. Hotspot-Picker
- [ ] 36. Phasen-Maschine · [ ] 37. Active-UI · [!] 38. Rätsel und Ökonomie
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
  vorher ein Layout geprüft, das es auf keinem Gerät gibt: „FACT" belegt dort
  256 statt 166 Pixel, und die Knopfzeile des Audio-Dialogs lief schon bei
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
passieren und trotzdem genau das verletzen, was E-27 verhindern soll. Die
Trennung hält hier die Review, nicht die Maschine. Deshalb gehört ein Satz dazu
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
Schriftmetriken. Behoben am selben Hebel wie E-38, in `ThemeData.typography`.

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
| E-33 | **„Angemeldet bleiben" ist wirkungslos.** In der PWA wird `stayIn` gesetzt und **nirgends gelesen**, `persistSession` kommt dort nicht vor. Das Kästchen ist im Neubau nachgebaut, die Semantik nicht: Sitzungspersistenz wäre eine Auth-Verhaltensänderung. Zu entscheiden: implementieren, oder das Kästchen entfernen. Ein Haken, der nichts tut, ist gegenüber dem Nutzer eine Unwahrheit. | 3 | vor Auslieferung |
| E-34 | **Passwort-Reset ist nicht angeboten.** `supabase_flutter 2.17.2` fährt standardmäßig `AuthFlowType.pkce`, und `resetPasswordForEmail` legt den Code-Verifier **auf dem Gerät** ab. Ohne `redirectTo` ginge der Link an die Site-URL, also in die PWA, die den Verifier nicht hat: der Tausch scheitert. Eine Mail zu schicken, deren Link niemand einlösen kann, ist schlechter als kein Angebot. Der Nutzer sieht deshalb kein „Vergessen?" über dem Passwortfeld, Zurücksetzen läuft über die PWA. Die Behebung braucht ein Deep-Link-Ziel und damit eine **neue öffentliche Vertragsfläche**. | 3 | vor Auslieferung |
| E-35 | **`FactButton` kann nicht nach `core/widgets`.** Sein eigener Kommentar verlangt den Umzug, sobald ein zweiter Aufrufer existiert; der existiert seit Schritt 9. Regel 11 des Prüfskripts zerlegt aber den Pfad und meldet, dass `core` das Konzept `fact` nicht besitzen darf, nachgewiesen mit einer Wegwerf-Probe. Zu entscheiden: bei `identity` lassen, oder unter einem Namen ohne Fachbegriff umziehen. | 2 | wenn ein drittes Feature ihn braucht |
| E-36 | **Bei 360 logischen Pixeln passt die Sprachzeile nicht einzeilig.** Gerechnet mit echten Schriftmetriken, neu gemessen nach E-38: zwei Karten à 125,35 plus Knopf-Untergrenze 63,96 plus 16 Abstände ergibt 330,66 gegen 316 verfügbare Pixel, Fehlbetrag rund 14,7. E-38 hat den Fehlbetrag also verkleinert, aber nicht beseitigt. Die vorher hier stehenden 337,5 waren im Übrigen auch vor E-38 nicht reproduzierbar, gemessen wurden 335,53. Die Quelle hat dasselbe Problem und schneidet mit `#root { overflow: hidden }` etwa vier Pixel des Knopfes ab. Zur Wahl: kleinere Flagge unter einer Breitenschwelle (Quelle: 30), kürzere Knopfbeschriftung oder nur das Emoji, die Zeile auf schmalen Geräten zweizeilig legen, oder abschneiden wie die Quelle. Aktuell entschieden ist nichts: die Titel brechen dort um, nichts läuft über, und ein Test hält die **Ursache** fest, damit die nächste Änderung dort anschlägt. | 2 | vor Auslieferung |
| E-37 | **Das Launcher-Symbol ist noch das Flutter-Logo.** Android 12 und neuer zeichnet `@mipmap/ic_launcher` über die SplashScreen-API mitten in den nativen Startbildschirm. Der Hintergrund ist seit dem 27.08.2026 richtig (`#FF0F0D0A`), das Symbol nicht. Braucht das FACT-Symbol in allen Dichten, plus eine Entscheidung, ob der native Startbildschirm es überhaupt zeigen soll. | 2 | vor Auslieferung |

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
