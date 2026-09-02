# Übergabe

**Diese Datei zuerst lesen.** Sie sagt, wo der Neubau steht, was zuletzt
passiert ist und was als Nächstes kommt. Sie ist bewusst kurz: Belege, Zahlen
und Fundstellen stehen in `REBUILD_STATUS.md`, nicht hier.

| Frage | Dokument |
|---|---|
| Fortschritt aller 50 Schritte, offene Entscheidungen, Datenvertrags-Fallen | `REBUILD_STATUS.md` |
| Was bei Dairen liegt, im Wortlaut, und was seither dazugekommen ist | `REBUILD_STATUS.md`, Abschnitt „Fragen an Dairen" |
| Was `maplibre_gl 0.26.2` nicht kann, und wie Tests hier blind werden | `REBUILD_STATUS.md`, zwei eigene Abschnitte |
| Warum die Architektur so ist | `docs/architecture/`, `docs/decisions/adr/` |
| Welche Regeln beim Programmieren gelten | `docs/engineering/`, `.claude/rules/` |
| Wie die App sich verhalten muss | die PWA im Lese-Repo, siehe `CLAUDE.md` |

---

## Zuerst: ein echter API-Schlüssel liegt ausgeliefert im Klartext

Am 02.09.2026 beim Zuschnitt von Schritt 25 gefunden, und es ist die einzige
Zeile in dieser Datei, die **heute** eine Handlung verlangt.

`02_Frontend/app/audio-player.jsx:12` hält eine Konstante `OPENAI_KEY` mit
einem vollständigen `sk-proj-…`-Schlüssel. Die Datei wird **nicht** gebündelt,
sondern im Quelltext ausgeliefert: `index.html:180` lädt sie als
`<script type="text/babel" src="audio-player.jsx?v=5">`. Wer die Seite offen
hatte, konnte den Schlüssel lesen.

**Vier Fundstellen, und die erste Zählung hier war falsch.** Sie stand kurz
als „genau eine", weil meine Suche auf `02_Frontend` begrenzt war und gebaute
Artefakte übersprungen hat. Tatsächlich:

1. `02_Frontend/app/audio-player.jsx:12`, die Quelle.
2. `02_Frontend/dist/assets/index-4JDjuKco.js`, das **gebaute Web-Bündel**.
3. `02_Frontend/android/app/src/main/assets/public/assets/index-4JDjuKco.js`,
   dasselbe Bündel **in den Android-Assets**. Wenn dieses Paket je verteilt
   wurde, ist der Schlüssel mitgegangen.
4. `06_Planung/plans/2026-05-14-openai-tts.md:275`, das Planungsdokument.

Nicht im Backend und nicht im eingefrorenen Flutter-Port. **Der Schlüssel
steht bewusst nirgends in diesem Repository**, auch nicht in
`REBUILD_STATUS.md`; dieses Repository ist öffentlich.

**Es war eine bewusste Entscheidung, nicht ein Versehen.** Punkt 4 sagt es im
Wortlaut: der Schlüssel werde im Quelltext sichtbar sein, das sei „acceptable
for a personal project at this scale", und man solle rotieren, falls
unerwartete Kosten auftauchen. Das war am 14.05.2026. Seither gibt es einen
DACH-Rollout-Plan und den Weg in die App Stores, und „personal project at this
scale" trifft es nicht mehr. **Ob die Abwägung heute noch gilt, ist eine
Entscheidung des Eigentümers und wurde von hier aus nicht getroffen.**

**Die Behebung ist kein Code:** den Schlüssel bei OpenAI zurückziehen und neu
ausstellen. Ihn nur aus den Dateien zu löschen genügt nicht, er steht in der
Versionsgeschichte des anderen Repositories und war ausgeliefert. Steht als
E-70, Stufe 4.

Für den Neubau ändert das nichts, es bestätigt die Entscheidung: E-15 heißt
„Gerät zuerst", und die Cloud-Variante läuft laut derselben Entscheidung über
Edge Function und Proxy, nie über einen Schlüssel im Client.

## Eine Sache liegt vor allem anderen, seit dem 02.09.2026

**Dieses Repository ist öffentlich.** Nachgesehen, nicht angenommen:
`gh repo view` meldet für `Daigon2/flutter-fact` die Sichtbarkeit `PUBLIC`.

In ihm liegt `REBUILD_STATUS.md` mit dem geprüften Verzeichnis der
Backend-Lücken, und `docs/operations/backend-inventory.md` nennt die Projekt-URL
der laufenden Supabase-Instanz. Der Schlüssel selbst liegt nicht im Repository,
aber der öffentliche Schlüssel der PWA ist aus jedem Browser zu holen, er ist
dafür gedacht. Öffentlich steht damit, **welche Tür offen ist und wo sie sitzt**.

Zwei Dinge, die auseinandergehalten gehören:

- Die Sichtbarkeit umzustellen behebt **nichts rückwirkend**. Was einmal
  öffentlich war, kann kopiert und indiziert sein.
- Die eigentliche Behebung ist, die Lücken zu schließen. Laut
  `docs/operations/backend-inventory.md` sind sechs der sieben Befunde wenige
  Zeilen SQL; nur E-58 verlangt, etwas Neues zu bauen.

**Beides ist eine Entscheidung des Eigentümers und wurde von hier aus nicht
getroffen.** Steht als E-64 im Register, Stufe 4.

---


> **Zu den Datumsangaben, und das betrifft fast alles unterhalb.** Diese
> Arbeitssitzung lief über **drei** Kalendertage, und das Protokoll kennt nur
> einen. Fast jeder Eintrag seit dem Fragenblock an Dairen trägt „31.08.2026",
> auch wenn er am 1. oder 2. September entstanden ist; die Wörter „am selben
> Tag" sind entsprechend oft falsch. Gemessen an den Commit-Zeitstempeln:
> `574c305` und alles davor liegt am **31.08.2026** (bis 22:58), `e1dd722` bis
> `6f955a8` am **01.09.2026** (14:53 bis 23:29), `add0394` bis `d559abe` am
> **02.09.2026** (00:17 bis 03:58).
>
> **Ein Rundumschlag wäre schlimmer als der Fehler.** Von den 65 falsch
> datierten Zeilen verweisen einige zu Recht auf den 31.08., etwa auf Dairens
> Antworten oder auf die Backend-Aufnahme. Wer eine einzelne Angabe braucht,
> holt sie mit `git log --format="%h %ad %s" --date=format:"%Y-%m-%d"` und
> setzt **diese eine** richtig. Die Überschriften der Protokolleinträge vom
> 2. September sind bereits nachgezogen.


## Stand

**Zuletzt aktualisiert:** 02.09.2026

Phase 0 und Phase 1 sind abgeschlossen. Aus Phase 2 sind laut Protokoll die
Schritte 12 bis 17 und 19 fertig, offen bleiben dort nur noch 18 und 20.
Phase 3 hat mit Schritt 21 begonnen, Phase 4 mit Schritt 27, Phase 5 mit
den Schritten 33 bis 37 und 39.

**Fertig sind 31 von 50:** 1 bis 17, dazu 19 bis 22, 25, 26, 27, 31, 33 bis 37 und 39. Schritt 14 ist
am 31.08.2026 dazugekommen, in zwei Teilen. Der
Zählwiderspruch vom 29.08.2026 ist geklärt: `REBUILD_STATUS.md` führte Schritt
19 als offen, obwohl `map_top_chrome.dart` mit neun Teildateien und 34 Tests
steht und D-5 ihn am selben Tag zur geschlossenen Einheit umgebaut hat. Das
Kästchen war das Veraltete, nicht der Stand.

**Am 31.08.2026 lagen Kästchen und Wirklichkeit ein zweites Mal auseinander, und
diesmal in der anderen Richtung:** Schritt 15 galt als `[x]`, enthielt das
Antippen der Gruppen aber ausdrücklich nicht. Seit dem Nachziehen ist er wirklich
fertig. **An der Zahl 22 ändert das nichts**, er war schon vorher so gezählt.
Wer aufaddiert, zählt also keinen Fortschritt, sondern bekommt eine Zahl, die
jetzt stimmt.

**Kennzahlen:** 2593 Tests grün, alle vier Gates auf Exit-Code 0 und der Analysator seit dem 02.09.2026 auf **null Meldungen**, mit `--fatal-infos` festgenagelt, dazu die
**drei** Drift-Werkzeuge `generate_i18n`, `bake_map_style` und
`generate_curated_data`, alle mit `--check` auf Exit-Code 0.

**Seit dem 31.08.2026 merkt sich die App etwas.** `shared_preferences` ist
aufgenommen, und alle fünf Speicher sind dauerhaft: Startbildschirm, Tutorial,
Audio-Modus, Sprachwahl und **die laufende Jagd**. Das war die erste Persistenz
im Projekt überhaupt.

**Stand der optischen Prüfung:** am 29.08.2026 zum ersten Mal **mit echter
Karte und echten Daten** am Emulator gesehen (Pixel 8, 411 logische Pixel,
Skalierungsfaktor 2,625). Gesehen und richtig: Startbildschirm, Tutorial,
Kartenbildschirm mit Top-Chrome, der gebackene Stil, Gruppen **mit ihren
Zahlen**, Sky-Fall, GPS-Folgen und die Näherungs-Animation samt Glühen und
Drehung. Ungeprüft bleiben iOS (nie compiliert), echte Hardware, 360 und 320
Pixel und Systemschrift 2.0; alle Aussagen dazu sind weiterhin strukturell.
Die vier offenen Gerätemessungen sind am 30.08.2026 alle beantwortet, Belege in
`REBUILD_STATUS.md`.

**Von den drei Dingen aus Schritt 15 sind am 31.08.2026 nach dem Neustart des
Rechners zwei am Gerät geprüft, das dritte nicht.**

- **Kommt beim Antippen einer Gruppe ein Ereignis an? Ja, gemessen.** Der Tipp
  auf eine Gruppe mit der Zahl 15 hat die Kamera bewegt, und die Gruppe war
  danach aufgelöst: an ihrer Stelle standen einzelne Nadeln. Das ist der
  vollständige Weg vom SDK-Ereignis über `groupTaps`, `projectToScreen`,
  `selectGroupMembers` und `rectFitZoom` bis zur Kamerafahrt, an einem Stück.
- **Stimmt die gerechnete Zoomstufe? Betrieblich ja.** Die Gruppe ist
  aufgegangen und die Kamera hat nicht überschossen. Genau das sollte die
  untere Schranke `groupExpandMinZoom = 16` garantieren, abgeleitet aus
  `clusterMaxZoom: 15`. Die Neigung war danach wieder da, die Absicht trägt
  also eine vollständige Kamera, wie D-12 es verlangt.
- **Trägt die Referenzkachelgröße 512? Weiter offen, und der Gruppentipp kann
  es nicht beantworten.** Wäre sie um den Faktor zwei falsch, läge die
  gerechnete Zoomstufe genau eine Stufe daneben, und zwischen der Schranke 16
  und `maxZoom` 18 würde die Gruppe trotzdem aufgehen. Die naheliegende
  Gegenprobe „sind hinterher alle Mitglieder im Bild" trägt auch nicht: die
  Auswahl der Mitglieder ist bewusst eine Näherung und liefert absichtlich ein
  zu kleines Rechteck. Es bleibt bei der Messung, die in
  `map_camera_fit.dart` beschrieben ist.

**Der Weg dorthin ist selbst ein Fund und spart dem Nächsten eine Stunde.**
Gruppen entstehen erst ab Zoom 15 oder kleiner, die Karte startet aber bei 16,5,
und **auf dem Emulator ist Herauszoomen nicht fernsteuerbar**: `input
motionevent` kennt nur einen Finger und wird als Verschieben gedeutet, nicht als
Doppeltipp-Zoom; `sendevent` auf `/dev/input/event2` scheitert im
Play-Store-Image an den Rechten; und die Emulator-Konsole kennt weder
`ABS_MT_*`-Codes noch ein Mausrad (`event codes EV_REL` hat nur `REL_X` und
`REL_Y`). **Der Trick: die Standortfreigabe verweigern.** Ohne Position folgt die
Karte niemandem, bleibt in der Stadtübersicht, und dort stehen die Gruppen samt
Zahlen (87, 49, 32, 28, 17, 15, 12) direkt zum Antippen.

Der Emulator ist zweimal an derselben Stelle gebrochen, beide Male in der
Grafikbrücke des Hosts und nie in der App: erst zeigte der Gast eine weiße
Fläche und meldete `Requested texture size (1, 1) exceeds maximum supported size
of (0, 0)` aus dem Impeller-Allokator, dann stürzte
`libgfxstream_backend.dll` mit `EXCEPTION_ACCESS_VIOLATION_WRITE` ab. Beteiligt
waren nur Emulator- und Intel-Treibermodule (`igvk64.dll`,
`igxelpgicd64.dll`). **Die Ursache war der Schlaf des Rechners:** die
Prozesslaufzeit im Absturzbericht betrug 158110 Sekunden, also knapp 44 Stunden,
und die GPU-Verbindung war seit dem Aufwachen tot. Der Prozess lebte danach
weiter, ohne über `adb` erreichbar zu sein, und sperrte die AVD, sodass ein
Neustart mit „Running multiple emulators with the same AVD" abbrach.
**Der Neustart mit Software-Rendering hat es nicht gelöst, und das ist der
entscheidende Befund.** Nach `taskkill /F /IM qemu-system-x86_64.exe` startete
der Emulator mit `-gpu swiftshader_indirect` sauber, bootete in 29 Sekunden, die
App lief ohne weiße Fläche, der Startbildschirm zeigte echte Daten aus Supabase
(950+ Fakten, 4 Städte). Beim ersten Antippen war das Gerät `offline`, und der
Prozess starb mit **Segfault** (Exit 139). Im Protokoll steht davor
`UpdateLayeredWindowIndirect failed ... (Ein an das System angeschlossenes
Gerät funktioniert nicht.)`. Das ist die **Fensterschicht des Hosts** und nicht
der Gast-Renderer: es sterben beide Pfade, der Intel-GPU-Pfad und der
Software-Pfad. Die Grafikschicht des Rechners ist seit dem Schlaf kaputt, nicht
die Wahl des Renderers.

**Wer hier weitermacht, kommt an einem Neustart des Rechners nicht vorbei**, oder
prüft auf echter Hardware, was ohnehin aussteht. Ein weiterer Emulator-Versuch
ohne Neustart ist verschwendete Zeit, das ist jetzt zweimal gemessen.

**Der Gerätelauf braucht Konfiguration, keine Arbeit:** URL und Schlüssel für
Supabase kommen über `--dart-define-from-file=env.json`, die Datei steht in
`.gitignore` und gehört nicht ins Repository. Ohne sie zeigt die App die
Startfehler-Seite. Der Build-Blocker selbst ist seit dem 27.08.2026 gelöst,
siehe „Rechner einrichten".

---

## Als Nächstes

**Am 02.09.2026 sind drei Schritte auf einmal frei geworden, und zwar durch
zwei Sätze.** Janek: „ja 1. passt und dann mach webview gern".

- **`flutter_tts` und `audioplayers` sind aufgenommen, Schritt 25 und 26 sind
  gebaut.** Der Audio-Modus hat einen Abnehmer, und der Hinweiston kommt bei
  Nähe. Offen ist aus diesem Bereich nur noch der Tour-Zweig des Beacons, und
  der gehört zu Phase 6.
- **`webview_flutter` ist wieder freigegeben, und die 3D-Laufzeit ist
  entschieden: WebView mit Three.js.** Damit ist **Schritt 18** (Avatar) frei.
  Der Grund für diese Wahl steht in `REBUILD_STATUS.md`: in `08_Flutter/` ist
  dort die geografische Verankerung auf der bewegten Karte schon gelöst.
  Beachten: das Paket war am 31.08.2026 ausdrücklich **aus** der Liste
  gefallen, weil der Avatar 2D werden sollte. Diese Entscheidung ist am selben
  Abend aufgehoben worden.

**Was daneben unmittelbar fällig wäre, ohne neue Entscheidung:** der zweite
Ballon-Bildsatz. Seit dem 02.09.2026 weiß die App, welcher Fakt gesammelt ist,
und auf der Karte sieht man es nicht: der goldene Ballon der Quelle ist
vollständig belegt (Farben, Haken, Graustufe, Schatten), es fehlt allein die
Zeichenarbeit. Der Auslöser dafür stand seit Schritt 16 in
`fact_balloon_images.dart` und ist jetzt eingetreten.

**Am 31.08.2026 hat Janek den ganzen Stapel Produkt-, UX- und Kostenfragen an
einem Stück beantwortet.** Wortlaut, Folgen und meine zwei Widersprüche stehen
in `REBUILD_STATUS.md` unter „Antworten von Janek, 31.08.2026“. Was unten steht,
ist die Reihenfolge danach.

1. **Die Antworten in Code umsetzen. Das ist jetzt der Hauptweg, nicht mehr das
   Warten.** In dieser Reihenfolge, weil jede Zeile die nächste billiger macht:

   a. ~~**`shared_preferences` aufnehmen**~~ **fertig am 31.08.2026.** Alle
      fünf Speicher sind dauerhaft, `bootstrap()` lädt einmal vor dem ersten
      Bild, das Paket sitzt hinter `KeyValueStore` und hat mit Regel 22 ein
      Heimatverzeichnis. Belege im Protokoll unten.
   a2. ~~**Den Shared Kernel einführen**~~ **fertig am 31.08.2026, ADR-008.**
      `lib/kernel/` hält `PuzzleDifficulty` und `PuzzleOperand`, die beiden
      Kopien in `puzzles/domain` sind gelöscht, `lib/` ist netto 67 Zeilen
      kleiner, und Regel 23 setzt beide Richtungen maschinell durch. **D-18 ist
      damit freigemacht, aber noch nicht gebaut**, siehe (b).
   b. ~~**Das Hinweis-Feld auf Indizes umstellen**~~ **fertig am 31.08.2026,
      zusammen mit der Schwierigkeitsstufe aus D-18 in einem Zug.**
      `payloadVersion` steht auf 2, die Felder heißen `unlockedHintIndices` und
      `difficulty`. Sieben Pflichtmutationen, sieben Fälle. **Damit sind E-50 und
      E-51 im Neubau gelöst**, und D-18 ist nicht mehr nur freigemacht, sondern
      gebaut. Durch (a) ist es teurer und wichtiger
      geworden: ab jetzt liegen echte Nutzlasten auf echten Geräten, und eine
      Formänderung trifft sie. Der Zweig, der sie verwirft, ist geprüft
      (`key_value_active_hunt_store_test.dart`, „eine Nutzlast der falschen
      Fassung wird verworfen"). Siehe den zweiten Nachtrag in
      ADR-007. Heute heißt es `purchasedHintCount` und trägt eine Anzahl; es soll
      die Indizes der freigeschalteten Hinweise tragen. Ändert einen
      Nutzlastschlüssel, dafür ist `payloadVersion` da.
   c. ~~**Schritt 14, Kompass**~~ **fertig am 31.08.2026, in zwei Teilen.** Die
      Karte folgt der Blickrichtung des Geräts: Sensordienst unter
      `lib/services/orientation/`, Glättung in `map/domain/bearing_smoothing.dart`,
      Regel 24, die Absicht `compassBearingFollowIntent` und der Wachhund im
      Kartenbildschirm. **Am Gerät ungeprüft**, wie alles seit dem 29.08.2026:
      dass sich die Karte beim Drehen des Telefons mitdreht, kann kein
      Widget-Test zeigen.

      **Die Paketwahl hat sich beim Nachprüfen verschoben, und das war der Punkt
      der Recherche.** `^0.4.0` ist unerreichbar: 0.4.0 hat Web-Unterstützung
      bekommen und dafür `intl ^0.20.3` aufgenommen, während
      `flutter_localizations` aus der SDK `intl 0.20.2` festnagelt.
      **Dasselbe Muster wie bei `maplibre_gl 0.27.0`, zum zweiten Mal.**
      Aufgenommen ist `^0.3.1`, und das ist kein Verzicht: der Bezugsrahmen kam
      in 0.3.0, und 0.3.1 hat „corrected iOS orientation values". Begründung mit
      Quellen in `REBUILD_STATUS.md` unter „Schritt 14, die Wahl des
      Sensorpakets".

      **Neu offen: E-59**, der Bezugsrahmen. Der Neubau setzt magnetisch Nord,
      weil der Android-Pfad der Quelle magnetometerbasiert ist. Ob die Quelle auf
      iOS dasselbe tut, ist offen; der Unterschied wäre die örtliche Missweisung
      und damit mehr als die Totzone von 1,5 Grad.

   d. **Schritt 36 und 37**, die Phasen-Maschine und die Active-UI, auf dem
      Vertrag aus ADR-007.

2. **Der D-17-Block hat keine unabhängige Prüfung.** Der Jagd-Vertrag hat eine
   bekommen, und sie hat vier Dinge gefunden, die kein Test fing. Die Geometrie
   in `map_camera_horizon.dart` beruht auf zwei abgelesenen Zahlen und einer
   Annahme (`f/H = 1,5` sei eine feste SDK-Konstante) und ist eine zweite
   Meinung wert.

3. **Eine Gerätemessung ist jetzt möglich und offen.** Der Emulator läuft nach
   dem Neustart wieder. Die eine Ablesung, die `f/H = 1,5` bestätigt oder
   ersetzt, steht in `map_camera_horizon.dart` samt vorhergesagten Zahlen für
   vier Neigungen. Ebenso offen: die Referenzkachelgröße 512, Messung
   beschrieben in `map_camera_fit.dart`. Beide brauchen eine kurze, wieder
   entfernte Sonde, weil der Diagnosekanal absichtlich nicht druckt.

4. **Der zweite Fragenblock ist beantwortet, alle fünf, und bei Dairen liegt
   nichts mehr.** Wortlaut der Fragen **und** der Antworten stehen in
   `REBUILD_STATUS.md` unter „Der zweite Fragenblock an Dairen, 31.08.2026".
   Kurz:

   - **D-18: Shared Kernel.** Keine der drei vorgelegten Optionen, sondern der
     vierte Weg, den der Fragetext nur nebenbei nannte. Die Architektur wird an
     dieser Stelle ausdrücklich als zu streng bewertet und **minimal**
     aufgelockert, die Kopien in `puzzles/domain` werden über denselben Weg
     aufgelöst, und beides gehört als Architekturentscheidung festgehalten. Das
     ist der größte offene Bauauftrag und steht als Nächstes.
   - **E-19: der Server rechnet, keine Ausnahme von `security.md`.** Regel für
     den Neubau: **der Client rechnet keine Zeit, an der eine Belohnung hängt.**
     Zwillingsregel zu „der Client bestimmt nie einen gutgeschriebenen Betrag".
     Die Umsetzung ist Backend, damit ist das Sitzungsende in Phase 5 bis dahin
     nicht parität-treu baubar; anzeigen ja, verbuchen nein.
   - **E-49: der Server ist die einzige Wahrheit**, dazu zwei Aufträge, die
     nicht auf der Liste standen: die defekte Client-Ableitung
     (`wltDeriveTrophies`) wird **nicht portiert**, und **E-16 wird
     mitgeschlossen**. E-16 hängt an E-55, denn dieselben zwei Tabellen sind
     nicht nur lesbar, sondern schreibbar.
   - **Gruppen-Jagd: Supabase Realtime, und es passt neben ADR-007** statt es
     aufzubrechen. Ein Folge-ADR für Group Hunt Synchronization gehört dazu, und
     **der Transport bleibt austauschbar**: der Vertrag darf nicht auf
     `postgres_changes` zeigen.
   - **D-11: (b), so lassen.** Geschlossen, kostet keine Arbeit.
   - **OD-002 bleibt offen**, bis ein echtes Offline-Ticket die Anforderungen
     liefert. Der `KeyValueStore` von heute ist ausdrücklich keine
     Vorentscheidung dafür.

   **Die Lehre daneben ist teurer als eine der fünf Antworten.** Der Fragenblock
   stand wieder nur im Chat, und die Antworten kamen als Liste „1. bis 5.". Zwei
   davon waren ohne den Fragetext nicht auflösbar, und das ist genau der Fehler,
   den `REBUILD_STATUS.md` für den **ersten** Block schon protokolliert hatte.
   Er steht jetzt vollständig im Repository. **Wer den dritten Block schickt,
   legt ihn vorher dort ab.**

4b. **Eine neue Frage an Janek, E-60, und sie ist beim Zuschnitt von Schritt 36
   aufgefallen.** **Die gestuften Hinweise der Jagd beschreiben die Station
   *nach* der aktuellen, nicht die aktuelle.** Gemessen: der Generator legt an
   Stopp `i` das Trio des Fakts von Stopp `i+1` ab, die Pille liest an der
   aktuellen Station genau dieses Feld, und `currentStopIdx` springt beim Lösen
   sofort weiter. Wer Station 3 sucht, bekommt Hinweise zu Station 4.

   Zwei Lesarten, beide vertretbar: **Absicht** (der erste Hinweis heißt im
   Kommentar „atmospheric teaser", also eine Vorschau) oder **Defekt** (dann
   zahlt man 20 und 30 Münzen für Hinweise auf einen Ort, den man nicht sucht,
   während Pfeil und Distanz daneben auf die aktuelle Station zeigen). Dazu ein
   Nebenbefund: der Vorrangzweig `stop.locationHints`, den die Pille zuerst
   prüft, wird in der ganzen PWA **nie** befüllt.

   Der Neubau kann beide Lesarten, der Unterschied ist ein Index. Belege in
   `REBUILD_STATUS.md` unter „Ein Fund beim Zuschnitt von Schritt 36".

5. **Vier Dinge sind an mich delegiert und können jederzeit gemacht werden:**
   der Kamera-Zweckwortlaut (E-20, muss Damals/Heute **und** Foto-Rätsel in
   einem Satz abdecken), der Tutorial-Pfeil ohne Ballon in der Nähe (E-48), der
   Lautstärke-Wortlaut (E-28), und die Konsistenz der Ökonomie.

6. **Zwei Aufgaben für das andere Repository, die von hier nicht gehen.** E-06
   (`increment_coins` prüft den Betrag nicht) und E-24 (Policy auf `profiles`
   ohne `WITH CHECK`). Sie betreffen **jetzt** die laufende PWA. Die Regel für
   den Neubau lautet deshalb: der Client bestimmt nie einen gutgeschriebenen
   Betrag.

7. **Ein Kartenanker fehlt noch: `userMarker`.** Er wartet auf Schritt 18. Wer
   ihn baut, streicht die Kennung aus `knownMissing`, sonst schlägt
   `discovery_anchors_test.dart` an.

8. **Der Avatar wird gleich 3D, und damit ist eine neue technische Frage offen:
   welche 3D-Laufzeit.** Die 2D-Entscheidung von wenigen Minuten vorher ist am
   31.08.2026 aufgehoben („bau doch gleich 3D … das ist es wert“). Drei Wege in
   `REBUILD_STATUS.md`, meine Neigung ist WebView mit Three.js für den ersten
   Bau, weil dort die geografische Verankerung auf der bewegten Karte schon
   gelöst ist. `webview_flutter` kehrt damit in die Paketliste zurück.

9. **Das Backend kommt nach dem Frontend, und ein Neubau ist es vermutlich
   nicht.** Entschieden am 31.08.2026, abends: „Aber das Frontend sollten wir
   erstmal abschließen, dann kommt später das backend.“ Damit ist die Reihenfolge
   geklärt und der Punkt aus dem Weg. Die Vormittagsrichtung „neu bauen mit
   Leitplanken“ ist im selben Zug wieder aufgemacht worden („vielleicht braucht
   es auch keinen echten neubau, sondern nur eine fehleranalyse“), und nach der
   Aufnahme ist das die bessere Frage: **sechs der sieben neuen Befunde sind
   Reparaturen von wenigen Zeilen SQL.** Nicht reparierbar ist nur E-58, denn
   einen Admin-Server gibt es nicht, den müsste man bauen, und das wäre ein
   kleines neues Teil und kein Backend-Neubau. Dazu käme ein Migrationssystem,
   das unter den Bestand gelegt wird. Begründung und Kostenschätzung je Befund in
   `docs/operations/backend-inventory.md`.

   **Zwei Dinge, die die Reihenfolge nicht abwartet.** Erstens wirken E-06 und
   E-24 samt E-52, E-53 und E-55 **heute** gegen echte Konten; sie kosten rund
   eine Stunde SQL, brauchen keine Flutter-Arbeit und hängen nur an
   Datenbankzugriff. Zweitens hält „Backend später“ nur bis etwa Schritt 48: das
   Leaderboard erbt E-16, E-55 und E-56, und **Schritt 50 braucht einen
   Storage-Bucket, den es heute überhaupt nicht gibt** (E-17). Fünf der 28
   restlichen Schritte fassen das Backend an, die anderen 23 nicht.

   **Vorarbeit ohne Entscheidung:** ein Schema-Dump der laufenden Datenbank.
   Solange er fehlt, steht jeder Satz über das Backend unter „laut Dateien“.

---

## Protokoll

Neueste zuerst. Ein Eintrag je abgeschlossenem Schritt oder größerem Block, zwei
bis vier Sätze: was entstanden ist, und was daran überraschend war. Alle Belege
dazu stehen in `REBUILD_STATUS.md`.

### 03.09.2026, Schritt 31 war schon gebaut, Schritt 32 ist gesperrt

Beim Suchen nach dem nächsten freien Schritt nachgemessen. **31 von 50.**

**Die Hinweis-Ökonomie steht vollständig**, mitgekommen mit den Schritten 36
und 37: `huntHintCosts` hält `[0, 20, 30]`, `unlockHint` addiert den Betrag auf
die Station statt ihn vom Konto abzuziehen, `solveStop` rechnet
`max(0, punkte - kosten)`, und der Knopf in der Jagd-Pille hängt daran.
Fünfter Fall, in dem Kästchen und Wirklichkeit auseinanderliegen.

**Schritt 32 ist an einer Antwort gefallen, die es beim Zuschnitt noch nicht
gab.** Er besteht in der Quelle aus drei Zeilen, und alle drei bestimmen im
Client einen gutgeschriebenen Betrag: der Umtauschkurs am Jagdende
(`Math.floor(score / 8)`), die Münzen nach einem gelösten Rätsel und eine
negative Gutschrift beim Ausgeben. **Genau das verwirft E-19.** Am 31.08.2026
stand der Schritt als frei in der Liste; die Antwort kam am selben Abend.

Baubar wird er mit einem serverseitigen Jagdabschluss, der den Umtauschkurs
kennt und selbst bucht, also mit demselben Buchungsjournal, das J-C für das
Sammeln verlangt. **Das ist eine Entscheidung und keine Umsetzungsfrage.**

### 03.09.2026, Schritt 26, der Audio-Beacon, und die Hysterese ist der Kern

2593 Tests, vierzehn Mutationen, alle gefallen. **30 von 50.** Wer im
Fakt-Finder-Modus mit eingeschaltetem Audio-Guide an einem Fakt vorbeikommt,
hört einen Ton und danach „Alter Peter, 80 Meter, auf 2 Uhr".

**Die Hysterese ist der eigentliche Inhalt und leicht zu übersehen.** Der Ton
kommt unter 150 Metern, der Merkzustand fällt erst über 200, und dazwischen
passiert nichts. Wer die zweite Zahl auf die erste zieht, weil zwei Grenzen für
dieselbe Sache wie ein Versehen aussehen, baut genau das, was sie verhindert:
wer an der Grenze steht und sich zwei Meter bewegt, bekäme alle fünf Sekunden
denselben Ton. Dazu die Fünf-Sekunden-Sperre, und die steht **vor** der Suche.

**Die Ansage läuft am Fakt-Vorleser vorbei, und dafür war die Trennung aus
Schritt 25 da.** Die Quelle schiebt für Ansagen eine Fakt-Attrappe mit leerem
Titel in ihren Spieler; ihr eigener Kommentar nennt die Folge, „made MiniPlayer
pop up with an empty title for every beacon". Hier hält `factSpeechProvider`
den Fakt, der Dienst spricht nur Text, und der Beacon spricht über den Dienst.
Der Kopfhörer-Knopf in der Akte bekommt vom Hinweiston nichts mit.

**Drei Eigenheiten von `audioplayers`, wieder im Quelltext nachgelesen:** der
Pfad trägt kein `assets/`, `play` nimmt die Verteilung als Parameter mit, und
die Bedeutung von `balance` passt **genau** auf die Quelle, hier ist also
nichts umzurechnen. Das ist der Grund, jede Eigenheit einzeln nachzulesen statt
von Schritt 25 auf Schritt 26 zu schließen: dort war die Umrechnung der Fund,
hier wäre sie der Fehler.

**Eine vierte hat einen Testlauf gekostet.** Der Konstruktor von `AudioPlayer`
greift sofort auf den Plattformkanal zu; `bootstrap_test` wurde daran rot,
**ohne jede Fehlermeldung**. Der Adapter legt seinen Spieler jetzt erst beim
ersten Ton an, was auch die bessere Bauform ist: beim Start belegt die App
keine Audio-Ressourcen für ein Merkmal, das die meisten nie einschalten.

**Gebaut, aber nicht einschaltbar:** die Kopfhörer-Verteilung. Sie hängt am
Einstellungs-Bildschirm wie die Sprechgeschwindigkeit, jetzt als dritter Punkt
in E-71. Der Weg ist durchgezogen und geprüft, der Schalter fehlt.

### 02.09.2026, Schritt 25, und die Zahl der Quelle wäre die schnellste Stufe

2539 Tests, vierzehn Mutationen. **29 von 50.** Der Audio-Modus hat nach vier
Tagen seinen ersten Abnehmer: die Fakt-Akte hat einen Kopfhörer-Knopf, und wer
den Modus eingeschaltet hat, bekommt den Fakt beim Öffnen vorgelesen.

**Der teuerste Fund steckt im Paket, nicht in der Quelle.** „Normal" ist bei
`flutter_tts` **0,5** und nicht 1,0: die Doku sagt „0.0 (slowest) to 1.0
(fastest)", der Android-Teil rechnet `rate * 2.0f` mit dem eigenen Kommentar
„Android 1.0 is mapped to flutter 0.5", und auf iOS ist der Normalwert von
`AVSpeechUtterance.rate` ebenfalls 0,5. Die Quelle rechnet umgekehrt, dort ist
1,0 normal. **Wer die Zahl unbesehen übernimmt, lässt die App in der
schnellsten Stufe vorlesen.** Der Vertrag trägt deshalb die menschliche
Einheit, der Adapter rechnet um.

Drei weitere Eigenheiten des Pakets stehen im Kopf von
`flutter_tts_speech_service.dart`, alle im Quelltext nachgelesen: es gibt kein
`resume()` (fortgesetzt wird durch ein erneutes `speak`, auf Android nur mit
**demselben** Text), Anhalten ist auf Android nachgebaut und erst ab SDK 26
zuverlässig, und `awaitSpeakCompletion` bleibt aus.

**Zwei Defekte der Quelle sind nicht mitgebaut.** Der Vorlesetext enthält dort
die Zitat-Hochziffern als `[3]`, und die Sprachausgabe macht daraus „Der Turm
drei wurde". `audio.dialog.body` sagt, für wen der Modus gebaut ist: für
blinde und sehbehinderte Nutzer, für die der Vortrag der Text ist und nicht
die Beigabe. Und ein fehlender Titel wird mitgesprochen, wörtlich als
„undefined". Dazu ein dritter: die Akte vergleicht „läuft dieser Fakt gerade"
über den **Titel** statt über die Kennung.

**Die iOS-Gestensperre der Quelle wird nicht nachgebaut.** Sie hängt zwei
globale Lauscher auf, nur um zu wissen, ob sie sprechen darf, weil iOS Safari
`speechSynthesis.speak()` ohne Nutzergeste verwirft. Das ist eine Regel des
Browsers; `AVSpeechSynthesizer` und `TextToSpeech` verlangen keine Geste.

**Zwei Mutationen haben überlebt, und beide lagen an blinden Tests von mir.**
Die zweite ist die lehrreichere und steht als Muster 27 im Blindheitskatalog:
ein Provider, der mit einem **festen** Wert überschrieben ist, meldet genau
einmal, und damit kann eine Zusicherung über die zweite Meldung nicht falsch
werden. Der Test „liest genau einmal vor" blieb grün, als der Vermerk dagegen
entfernt wurde. Erst ein Override mit einem echten `Future` plus `invalidate`
stellt den Fall her.

Beim Nachsehen, warum diese Mutation überlebte, fiel noch ein Abonnement-Leck
auf: `didUpdateWidget` legte bei jedem Wechsel der Kennung ein weiteres
`listenManual` an, ohne das vorige zu schließen.

**Zwei Umzüge gehören dazu.** Der Audio-Modus ist von
`settings/presentation/notifiers/` nach `settings/application/` gewandert, weil
sein erster Verbraucher in einem anderen Feature sitzt und Regel 8 den Import
aus fremdem `presentation` verbietet. Und `flutter_tts` hat mit **Regel 25**
ein Heimatverzeichnis bekommen, wie das Karten-, Geo-, Speicher- und
Sensor-SDK vor ihm.

### 02.09.2026, Schritt 22 war schon fertig, und dafür fehlte das Gedächtnis

2468 Tests, neun Mutationen, alle gefallen. **28 von 50.**

**„Collect-Reveal-Overlay" hatte keinen eigenen Bauteil mehr.** Nachgemessen
vor dem Zuschnitt: in der Quelle ist das `CollectAnimOverlay`
(`screen-map.jsx:1157-1200`), also der Münzflug plus `+12 🪙`, und der
Aufrufer legt danach mit `setTimeout(..., 1400)` das Fakt-Blatt auf. Genau das
steht seit Schritt 20 als `FactCollectBurst`. Vierter Fall, in dem Kästchen
und Wirklichkeit auseinanderliegen, nach 19, 15 und 23.

**Dafür fehlten zwei Dinge, und das erste war größer als der Schritt.**

1. **Es gab keinen Speicher für gesammelte Fakten.** Seit Schritt 20 kann man
   sammeln, und es überlebte den nächsten Start nicht: `MapPage` meldete das
   Ereignis an die Diagnosesenke, und das war alles. Jetzt gibt es
   `CollectedFactsStore` als sechsten Speicher am `KeyValueStore`, unter dem
   Schlüssel `fact_collected` wie in der Quelle. **Münzen bucht dabei weiter
   nichts**, das bleibt beim Server (E-19), und die Meldung
   `discovery.collect.unbooked` markiert nur noch diese halbe Naht.

   Eine Entscheidung darin ist die Umkehrung der Regel vom Jagd-Speicher: ein
   **einzelner** unlesbarer Eintrag verwirft nicht die ganze Sammlung. Bei der
   Jagd ist die halbe Nutzlast keine Jagd, hier sind die Einträge unabhängig,
   und wer wegen einer kaputten Zahl zwei Wochen Sammlung verliert, hat den
   schlechteren Tausch gemacht.

2. **Man sammelt in der Quelle auch ohne jeden Tipp, und davon stand hier
   nichts.** `scanAutoOpenRef` (`:1471-1489`) läuft bei jeder Ortung und löst
   innerhalb von 18 Metern von selbst `triggerCollect` aus. **Das verschiebt,
   was Schritt 20 überhaupt ist:** der Tipp ist nur für die mittlere
   Entfernung nötig. Gebaut in `fact_auto_collect.dart`, aufgenommen als E-68.

   Drei Angaben stimmen an der Fundstelle nicht: der Kommentar sagt 30 Meter
   und der Code prüft 18; der Kommentar sagt „pop a fact's full sheet" und der
   Code **sammelt**, bucht also; und die 20-Meter-Meldung wird gerendert,
   während `setAutoToast` in der **ganzen PWA nie** aufgerufen wird. Gebaut
   sind die 18 Meter, die tote Meldung nicht.

**Ein Fund als Nebenwirkung, und er ist die scharfe Fassung von E-06.**
`onCollectFact` hat keine Prüfung auf „schon gesammelt" (`app.jsx:680-716`).
Die Liste entdoppelt sich, aber `Storage.addCoins(50)` und
`Api.addCoins(userId, 50)` laufen bei **jedem** Aufruf, und ein gesammelter
Fakt lässt sich beliebig oft antippen. **50 Münzen je Tipp, lokal und auf dem
Server.** Steht als E-69, Stufe 3. Der Neubau ist davon durch Bauweise frei.

**Und ein Muster für den Blindheitskatalog, Nummer 26, das mich fast erwischt
hat.** Das automatische Sammeln machte drei bestehende Tests derselben Datei
kaputt, zwei davon sichtbar rot. Der dritte blieb **grün und verlor dabei
seine Aussage**: er prüfte, dass die Entfernung aus der Punktkoordinate kommt
und nicht aus der Fingerstelle, mit einem Fakt in 10 Metern. Den sammelte die
Ortung ab jetzt ohnehin ein, und damit wäre er auch bei einem falschen
Empfänger grün gewesen. Eine grüne Suite sagt nach so einer Änderung nur, dass
nichts bricht.

**Was mich am meisten gekostet hat, war mein eigenes Mutations-Skript.** Es
setzte jede Mutation mit `git checkout -- <datei>` zurück. Für die **neuen**
Dateien tut das gar nichts (unverfolgt), und für die eine verfolgte setzt es
auf **HEAD** zurück, also auf den Stand vor dieser Arbeit: es hat mitten im
Durchgang meine Änderungen an `fact_collect_overlay.dart` verworfen. Die drei
folgenden Mutationen „fielen" danach, weil das ganze Merkmal weg war, und nicht
weil ein Test sie fing. Wiederhergestellt, mit Sicherungskopien statt
`git checkout` wiederholt, und danach fielen alle neun einzeln und jede auf
ihren eigenen Test. **Regel daraus: eine Mutationsschleife sichert per
Dateikopie, nie über die Versionsverwaltung.**

### 02.09.2026, Schritt 20, und der Kern-Griff der App hatte keinen Empfänger

2315 → 2400 Tests. Ein Tipp auf einen einzelnen Fakt-Ballon tut jetzt etwas:
innerhalb von 150 Metern sammeln, sonst nur die Vorschau, und **ohne Ortung nie
die Detailseite**. Das ist die Vor-Ort-Mechanik der App, in der Quelle mit
einem `FIX (Daniel + Janek)`-Kommentar versehen, der einen früheren Schlupf
nennt, über den ein Nutzer in Italien einen Münchner Fakt vollständig lesen
konnte.

Fünf Pflichtmutationen, alle gefallen. Danach zwei eigene Gegenproben auf genau
die zwei Funde, die **nicht** im Auftrag standen; die erste fiel, die zweite
überlebte.

**Der Fund, ohne den der ganze Schritt wirkungslos gewesen wäre**, stand nicht
in meinem Auftrag. Fakten innerhalb von 150 Metern nimmt `map_page.dart` aus
der nativen Ebene heraus und zeichnet sie als Flutter-Widgets, und die lagen
komplett in einem `IgnorePointer`. `MapHost.pointTaps` meldet sie also **nie**,
und das sind genau die Fakten, bei denen gesammelt wird. Mit nur dem
beauftragten Empfänger hätte der Sammelweg ausschliesslich unterhalb der
Gruppierungsgrenze funktioniert. Gemeldet, gebaut, und ein Test heisst jetzt
„der Tipp auf einen lebenden Ballon sammelt, obwohl der Punkt nicht mehr nativ
liegt".

**Eine Mutation hat überlebt, und die Lücke war eine Frage der Reihenfolge.**
Das Widget hält die Ortung mit `listenManual(..., fireImmediately: true)`, und
der Kommentar daran nennt den Grund: nach einem Tabwechsel entsteht das Widget
neu, während längst eine Ortung vorliegt. Ohne die Flagge bliebe sie ungelesen,
die Regel entschiede „ohne Ortung", und es gäbe **nie** ein Sammeln. Die Flagge
zu entfernen brach trotzdem keinen Test: **alle Tests der Datei ordnen erst das
Widget und dann die Ortung an**, und in dieser Richtung feuert der Hörer
ohnehin. Der neue Test dreht die Reihenfolge um. Muster 25, nur andersherum:
nicht die Zusicherung war zu schwach, sondern der Aufbau prüfte den Fall nie.

### Meine Auftragsprämisse war falsch, und sie betrifft eine Migration

Ich hatte geschrieben, der Server buche beim Sammeln 10 Coins. **Es sind drei
Zahlen an drei Stellen**, alle am 02.09.2026 nachgemessen:

* `app.jsx:712-714` bucht im **Solo-Sammelweg 50**, client-seitig. Das ist der
  Weg, der heute läuft.
* `collect_fact_validated` bucht **10** und hat in der **ganzen Referenz keinen
  einzigen Aufrufer**. Toter Code.
* Die Animation zeigt **12**.

**Folge für Migration 3a, und die gehört gelesen, bevor sie läuft:** sie
schliesst den direkten Insert und zwingt damit auf `collect_fact_validated`.
Sobald die PWA dorthin umgestellt wird, **fällt die Belohnung von 50 auf 10**,
ohne dass es jemand entschieden hat. Eine Balance-Änderung, versteckt in einer
Sicherheitsmigration. Sie blockiert die Migration nicht, weil bis zur
Umstellung dort ohnehin niemand sammelt, muss aber vor dem PWA-Release
entschieden sein. Steht als Warnblock im Kopf von
`03-e23-collected-facts.sql`.

**Und eine vierte Fundstelle für die 150, die einzige serverseitige:**
`collect_fact_validated` prüft `> 150`, nimmt genau 150,0 also an. Der Server
ist einschliessend, der Neubau ausschliessend; die Richtung ist die harmlose.
Nebenfund zur Prüfbarkeit: genau 150,0 Meter sind über Koordinaten gar nicht
erreichbar, per Bisektion gemessen. `fact_proximity_test.dart` hatte dieselbe
Beobachtung und daraus geschlossen, den Rand **nicht** zu prüfen. Schritt 20
zieht den Vergleich als eigenes Prädikat heraus, erst damit ist E-67 prüfbar.
Der blinde Fleck in `fact_proximity_test.dart` bleibt.


### 02.09.2026, Englisch ist jetzt Englisch, und E-16 hat eine Migration

Janeks Antwort auf E-61 hat 26 Werte fällig gemacht, dazu eine Wache und
zwölf Tests. Und weil J-B die Sichtbarkeitsfrage beantwortet hat, ist die
E-16-Migration schreibbar geworden. 2314 → 2315 Tests, alle Tore auf null.

**Der teure Fehler ist ab jetzt nicht der falsche Wortlaut, sondern der
vergessene.** Ein neuer Schlüssel, den jemand mit demselben deutschen Satz in
beide Karten schreibt, fällt sonst niemandem auf. Dagegen steht jetzt eine
Wache: kein englischer Wert darf seinem deutschen gleichen, es sei denn, er
steht auf einer **begründeten** Ausnahmeliste. Zehn stehen drauf, jeder mit
seinem Grund („Challenge" ist englisch, ein Gedankenstrich ist sprachfrei,
Goethe heißt in beiden Sprachen so). Die Liste hat eine Gegenprobe gegen das
eigene Verrotten: ein Eintrag, dessen Werte inzwischen auseinanderlaufen, wird
gemeldet.

**Ein Test hatte seinen eigenen Umbau vorhergesehen.** In
`tour_overlay_test.dart` stand am Test „die Meta-Zeile bleibt auch auf Englisch
deutsch" der Satz „Bricht dieser Test, ist die Freigabe erteilt worden". Genau
das ist passiert. Dasselbe Muster wie beim durchtrennten Jagdstart: eine
Zusicherung auf eine bekannte Lücke meldet sich selbst, eine Notiz muss gelesen
werden.

**Und der Umweg von Schritt 39 hat sich ausgezahlt.** Die drei
Schwierigkeitsstufen im Pausebildschirm auf Englisch zu bringen kostete **zwei
Werte und keine Zeile Code**, weil die Anzeige damals über `AppStrings` gelegt
wurde statt über `PuzzleDifficulty.code`. Das war damals die Begründung, und
jetzt ist sie eingelöst.

**Beim Nachsuchen fanden sich drei weitere rote Tests** ausserhalb der Datei,
die ich benannt hatte. Der Auftrag hatte ausdrücklich zum Nachsuchen
aufgefordert, weil ich nicht erschöpfend gesucht hatte. Ohne diesen Satz wären
sie später als rätselhafter Fehlschlag aufgetaucht.

### E-16, zwei Teile, und zwei Dinge, die erst dabei sichtbar wurden

**7a läuft heute**, 7b wartet auf einen PWA-Release, weil eine zusätzliche
Spalte den Rückgabetyp ändert und `create or replace` das nicht kann.

**Erstens: `get_leaderboard` gibt heute den echten Namen heraus**, wenn der
Schalter an ist (`supabase-schema.sql:382`, nachgeprüft). Janeks
Username-Entscheidung nimmt diesen Zweig weg. Folge, die niemand bestellt hat:
der Schalter „Echten Namen zeigen“ schreibt danach ein Feld, das niemand
liest. Ein Schalter, der lügt, ist schlechter als keiner, und das Entfernen
liegt in der PWA.

**Zweitens, und das ist unbequem: „keine Städtenamen“ ist nicht vollständig
erreichbar**, solange es Städte-Ranglisten gibt. `get_leaderboard('münchen')`
sagt dem Aufrufer, dass diese zehn Nutzer messbar in München waren. Heute für
jeden ohne Konto, danach für zehn je Stadt mit Konto. Besser, aber nicht zu.
Vollständig wäre es nur ohne Städte-Ranglisten, und das ist eine Produktfrage.

**Neuer Fund beim Städtezählen, als E-66 aufgenommen und selbst nachgemessen:**
ein Fakt, dessen Stadt sich weder aus `facts.city` noch aus dem `nr`-Präfix
ergibt, bekommt den Schlüssel `'unknown'` (`:247`), und zwei Zeilen weiter zählt
`count(distinct city_key)` ihn als Stadt (`:288`). `weltenbummler` ist damit mit
zwei echten Städten plus einem nicht zuordenbaren Fakt zu haben. Dritte Folge
derselben Wurzel wie E-11 und E-56: die Stadt wird geraten statt gepflegt.

**Und eine Korrektur an meinem eigenen Auftrag, die die halbe Testliste
gerettet hat:** ich hatte Negativtests so beschrieben, dass sie nach der
Migration mit einem Fehler scheitern. Das gilt nur für ein fehlendes
**Recht** (`42501`). Eine **Policy** weist nicht ab, sie liefert **null Zeilen
ohne Fehler**. Wer das verwechselt, schreibt drei Tests, die immer grün sind.


### 02.09.2026, Drei Backend-Löcher haben Migrationen, und zwölf Meldungen zurück

Janek hat den Auftrag gegeben, die Backend-Löcher zuzumachen, und zugleich
gefragt, ob stopfen reicht oder das Backend neu gehört. **Antwort: das Schema
stopfen, den Prozess neu.** Die elf Tabellen und die RLS-Struktur sind in
Ordnung, die Löcher sind fehlende `WITH CHECK`, ein ungeprüfter Betrag, ein
Index mit falschem Geltungsbereich. Was wirklich fehlt, ist ein
Migrationssystem: aus dem Repository ist nicht zu sehen, was in der Datenbank
steht, und solange das so bleibt, flickt jede Migration eine Vermutung. Weil
noch nichts live ist, ist jetzt der billigste Moment dafür, den es geben wird.

**Meine eigene frühere Aussage war zu optimistisch, und das ist jetzt
nachgemessen.** Ich hatte gesagt, sechs von sieben Befunden seien wenige Zeilen
SQL. Es sind drei Stufen: **drei** sind reine Migration (E-52, E-53, E-55, jetzt
geschrieben), **vier** brauchen vorher eine Entscheidung (E-16, E-54, E-56,
E-57), **einer** verlangt, etwas Neues zu bauen (E-58, der Admin).

Angewendet ist nichts. Das Backend liegt im Monorepo, von hier wird dort nie
geschrieben, und gegen eine Datenbank läuft von hier ohnehin nichts.

### Zwölf Meldungen zurück, und vier davon waren Fehler in meinen Dokumenten

Der Auftrag verlangte, jede Abweichung zu melden statt sie stillschweigend
umzubauen. Das hat sich gelohnt, und zwar in beide Richtungen.

**Zwei hätten die Produktion gebrochen.** Ein pauschaler Entzug der
`anon`-Ausführrechte hätte die **Registrierung** in beiden Clients getötet:
`check_username` läuft vor der Anmeldung, und beide Seiten verschlucken den
Fehler, es wäre also stumm gescheitert. Und `_is_group_member` sieht wie ein
interner Helfer aus, steckt aber in **drei RLS-Policies**; Policy-Ausdrücke
laufen mit den Rechten der abfragenden Rolle, ein Revoke gegen `authenticated`
hätte den ganzen Gruppenmodus abgeschaltet. Beides nachgeprüft, beides
ausgenommen, beides mit eigenem Test.

**Eine widerlegt meine eigene Vorgabe.** Ich hatte für E-53 den
Spaltenrechte-Umweg aus Abschnitt 3 verlangt. Er ist hier nicht nur unnötig,
sondern **schädlich**: bei `INSERT` gibt es keine alte Zeile, `is_approved is
not true` ist exakt, und ein `revoke insert (is_approved)` würde einen
inhaltlich richtigen Aufruf der PWA mit `42501` abweisen.

**Vier waren Fehler in meinen Dokumenten**, alle richtiggestellt:

* Die Sperre, die E-54 nennt, gibt es seit dem 05.06.2026 nicht mehr; sie ist
  durch zwei partielle Indizes ersetzt. Wichtiger noch: **die naheliegende
  Behebung ist keine Indexänderung**, weil `group_collects` keine Spalte
  `user_id` hat.
* Die Prüfanweisung zu E-52 **sieht den Befund nicht**:
  `information_schema.role_routine_grants` zeigt an `PUBLIC` vergebene Rechte
  gar nicht an, und genau die sind das Problem. Wer sie laufen lässt, hält den
  Befund für behoben.
* E-53 zeigte auf `api.jsx:167`, dort steht `text: factData.text`. Richtig ist
  `:176`.
* Abschnitt 10 der Fix-Datei prüft mit einem Griff nach `.rpc(` und findet
  damit den **einzigen** RPC-Aufruf dieses Repositories nicht, weil er
  `_client.rpc<Object?>(` heißt. Das Ergebnis stimmte, die Methode nicht.

Dazu eine Entwurfsentscheidung, die mein Auftrag offen gelassen hatte:
`p_user_id` **bleibt** in der Signatur und wird nur nicht mehr geglaubt. Ein
Bruch wäre unsichtbar, weil die PWA jeden Fehler an dieser Stelle mit einem
leeren `catch` abfängt, und die Lücke ist mit dem Vergleich gegen `auth.uid()`
ohnehin zu. Der Weg zur parameterfreien Fassung liegt fertig daneben.


### 02.09.2026, Eine unabhängige Prüfung, und sie hat zwei echte Löcher gefunden

Die ganze Nacht hat dieselbe Instanz die Aufträge geschrieben **und** geprüft,
die die Arbeit vergeben hat. Am Ende hat ein unabhängiger Blick über fünf
Commits gelesen. Er hat sich gelohnt, und zwar zweimal ernsthaft.

**Der erste Fund entwertet eine Begründung, die ich selbst geschrieben habe.**
Ich hatte in vier Dokumentstellen behauptet, eine Jagd nach einem App-Neustart
sei „auf der Karte als Pille sichtbar, im Challenge-Reiter aber nicht". Das ist
falsch. `HuntPill` liest **ebenfalls** `huntRunProvider`, und
`activeHuntProvider` hat in `lib/` **keinen einzigen Verbraucher**. Nach einem
Neustart ist die Jagd **nirgends** sichtbar, und die Produktvorgabe aus
ADR-007, die `bootstrap.dart` wörtlich zitiert, ist an keiner Stelle eingelöst.
Der Schreibweg der Persistenz funktioniert, der Leseweg hat keinen Abnehmer.

Das Bittere daran: die falsche Behauptung war der **Trost**, mit dem ich eine
Entwurfsentscheidung begründet habe. Sie ließ eine offene Lücke wie eine
hingenommene Kleinigkeit aussehen. Alle vier Stellen sind berichtigt, der Fund
steht als **E-65** mit den zwei Wegen, die zur Wahl stehen. Gewählt ist keiner,
das gehört nicht hierher.

**Der zweite Fund betrifft ausgerechnet die Prüfung gegen stille Fehler.** Der
Kommentar-Entferner des i18n-Generators hielt eine mit `'` begonnene
Zeichenkette über Zeilen offen. Ein Minutenzeichen im JSX-Text (`{min}'`) kippt
damit seine Parität, und ein `//` in einer echten Zeichenkette gilt danach als
Zeilenkommentar. Der `t()`-Aufruf dahinter fällt **still** weg. An einer
Wegwerf-Datei ausgelöst und reproduziert.

Die Reparatur ist eine Zeile und folgt aus der Sprache: eine `'`- oder
`"`-Zeichenkette schließt in JavaScript spätestens am Zeilenende, der Zustand
wird also am Umbruch zurückgesetzt. Damit verdirbt ein verlesenes Zeichen
höchstens seine eigene Zeile. Für ` gilt es nicht, ein Template-Literal darf
mehrzeilig sein. **An der echten PWA ändert sich nichts**, 452 Schlüssel wie
zuvor: heute hat die Kaskade nichts verschluckt, die Reparatur ist vorbeugend.

**Und dabei ist mir ein zweiter eigener Fehler aufgefallen**, den erst eine
Mutation gezeigt hat: mein Test für das Template-Literal legte den Aufruf
**hinter** das Literal, und dort fand ihn auch ein Scanner, der beim Backtick
genauso zurücksetzt. Der Test prüfte nichts. Scharf wird er erst mit einem `//`
**im** Literal. Wieder Muster 25, nur andersherum: es reicht nicht, den Fall
hinzuschreiben, er muss auch der Fall sein.

**Der neue `--fatal-infos`-Riegel hat am ersten Tag zugeschlagen**, an meinem
eigenen Testcode, zwei `prefer_single_quotes`. Genau dafür ist er da.

Was die Prüfung **nicht** gefunden hat, ist auch eine Aussage: der Code tut,
was die Commit-Nachrichten sagen, die Tore stehen wirklich auf grün, und der
Umbau an Regel 17 hält der Gegenprobe stand, samt der Zusicherung, dass fremdes
`data/` nur **eine** Meldung erzeugt.


### 02.09.2026, Der Analysator steht auf null, und bleibt jetzt dort

24 Hinweise `prefer_initializing_formals` standen wochenlang, Gate 2 blieb
trotzdem grün, weil ein `info` es nicht kippt. Alle 24 sind weg, in 15 Dateien,
als Initialisierungs-Kurzform. **Die Testzahl blieb bei 2308**, und das war die
Bedingung: wer bei so einer Umstellung Tests anfassen muss, hat mehr getan als
umgestellt.

**Meine Vermutung war falsch, und das Nachmessen war das Wertvolle daran.** Ich
hatte angenommen, der Lint sei hier gar nicht befolgbar, weil Dart keine
privaten benannten Parameter erlaubt. An einer Wegwerf-Datei gemessen: `required
this._x` ist erlaubt, und der Aufrufer schreibt weiter den öffentlichen Namen
`x:`. Deshalb hat sich **keine einzige Aufrufstelle** geändert. Hätte ich der
Vermutung geglaubt, stünde jetzt eine falsche Begründung im Dokument und die 24
Hinweise stünden weiter da.

**Ein Zwischenfund des Bauenden, der die Sache fast gedreht hätte:** eine
Kurzform **mit** Typ (`bool this._x = false`) ist gültig, löst aber sofort einen
anderen Hinweis aus (`type_init_formals`). Wer die 24 Stellen ohne diese
Messung umgestellt hätte, hätte 24 Meldungen gegen 24 andere getauscht. Er hat
es an einer Datei geprüft, bevor er die übrigen 23 angefasst hat.

**Eine Stelle blieb bewusst stehen**, und der Analysator hatte sie auch nie
gemeldet: in `map_camera_host.dart` wird `diagnostics` in derselben
Initialisierungsliste ein zweites Mal gebraucht. Als Kurzform gäbe es den
lokalen Namen nicht mehr.

**Seit demselben Tag läuft Gate 2 mit `--fatal-infos`.** Vorher kippte ein
`info` das Tor nicht, und genau daran konnten 24 Meldungen so lange stehen: wo
24 stehen, fällt die 25. nicht auf. Jetzt kostet die Flagge nichts und hält den
Stand. Damit ist auch der Widerspruch erledigt, den `HANDOFF.md` als offen
führte („24 Hinweise" gegen „No issues found!"): die 24 waren echt und sind weg.
Warum irgendein Lauf grün gemeldet hat, bleibt unerklärt, und dieser Unterschied
zwischen verschwunden und aufgelöst steht auch so da.


### 02.09.2026, Das Tor stand offen, aber nicht an diesem Zweig

Beim Suchen nach dem nächsten Posten stellte sich heraus, dass gleich zwei
Einträge im Statusdokument die Wirklichkeit falsch beschrieben.

**Der CI-Workflow existiert seit dem 30.08.2026**, das Dokument führte ihn als
„gibt es nicht". `gh run list` zeigt Läufe, darunter eine bewusste Gegenprobe
auf einem eigenen Zweig, die rot wurde. Das war das **vierte** veraltete
Kästchen in diesem Dokument.

**Und dann der Fund dahinter, der wirklich wehtut:** der Auslöser war `push`
auf `main` und `pull_request`. Der Zweig, auf dem gebaut wird, ist keins von
beidem. **Fünf Pushes an diesem Abend haben keinen einzigen Lauf ausgelöst.**
Die vier Gates liefen die ganze Nacht nur, weil sie hier von Hand gestartet
wurden. Ein Tor, das erst beim Zusammenführen zuschlägt, meldet den Fehler eine
Tagesarbeit zu spät. Der Auslöser nimmt jetzt `claude/**` mit, und der Push
dieses Eintrags ist zugleich seine eigene Gegenprobe.

**Der Posten `check_generated_code.dart` war viel kleiner als sein Eintrag, und
er ist erledigt.** Nachgezählt: von den sechs `*.g.dart` im Baum stammt genau
**eine** von `build_runner`, `app_routes.g.dart`. Die anderen fünf erzeugen die
drei eigenen Werkzeuge, und die haben ihre `--check`-Prüfung längst. Diese eine
prüft jetzt der CI-Lauf: `build_runner` läuft, danach muss `git diff
--exit-code` still bleiben.

**Nicht lokal, und das ist gemessen.** Der Lauf dauert 40 Sekunden für eine
Datei; die vier lokalen Tore zusammen liegen darunter. Ein Tor, das niemand
mehr abwartet, ist keins. Dazu schlägt `git diff` auf Windows an genau dieser
Datei allein durch die Zeilenenden an, obwohl der Inhalt gleich ist. Das ist
beim Einbau aufgefallen und war zuerst ein Schreck: `git status` meldete die
Datei als geändert, `git diff` zeigte nichts. Der Stand ist aktuell.


### 02.09.2026, Der i18n-Generator prüft jetzt auch die Aufrufstellen

Die Lücke, die E-28 durchgelassen hat, ist zu. 2292 → 2308 Tests, sieben
Mutationen, alle gefallen. Dazu hat das Werkzeug endlich eine Testdatei; es war
das einzige der vier ohne, obwohl es die gesamte Zeichenketten-Tabelle erzeugt.

**Überraschend war, wie sehr die Handmessung den Entwurf bestimmt hat.** Sieben
Rohtreffer, und erst ihre Aufteilung ergab die drei Regeln: einer stand nur in
einem Kommentar, vier waren Präfixe aus `t('cat.' + x, lang)`, zwei waren echt.
Wer die Prüfung ohne diese Messung gebaut hätte, hätte fünf Fehlalarme
eingebaut, und eine Prüfung mit Fehlalarmen wird abgeschaltet, nicht repariert.

**Die Liste bekannter Lücken kann selbst verfallen, und das ist die Hälfte, die
man vergisst.** Ein Eintrag, der nicht mehr fehlt, wird gemeldet. Ohne diese
Hälfte verrottet so eine Liste still und bewacht irgendwann nichts mehr. Die
schärfste Mutation war deshalb ein **erfundener dritter Eintrag**: er wird als
veraltet gemeldet, die Liste kann also nicht unbemerkt wachsen.


### 02.09.2026, Zwei Löcher im Architektur-Tor, und ein Fund nebenbei

Das Skript hinter Gate 3 hatte zwei gemessene Lücken, beide seit dem 28.08.2026
im Dokument benannt und beide seither offen. Jetzt zu: die Cross-Feature-Prüfung
war flach (ein fremdes `features/x/unterstruktur/data/` entkam den Regeln 8 und
9), und Regel 17 hing an `lib/features/` (ein `lib/map/presentation/` auf
`lib/map/data/` wurde nicht gemeldet). 85 → 90 Tests am Skript, sechs
Mutationen, alle gefallen, 2292 Tests insgesamt.

**Überraschend war, dass die verschärfte Prüfung im Bestand nichts findet.** Bei
den vorigen zwei Runden am selben Skript war das anders. Beide Lücken waren
heute nicht auslösbar, weil es außerhalb von `lib/features/` schlicht kein
`data/` gibt; sie waren Fallen für den Tag, an dem der Karten-Host eines bekommt,
und genau als solche sind sie jetzt entschärft.

**Eine Entscheidung hat der Bauende getroffen, weil mein Auftrag sie offen
gelassen hatte**, und sie war richtig: die neue Modulwurzel-Prüfung **ergänzt**
die alte, statt sie zu ersetzen. Ein Ersatz hätte den Schutz für eine
Presentation-Datei in einer Feature-Unterstruktur verengt. Beide Bedingungen
stehen als Oder in einem `if` mit einem `found.add`, und eine Zusicherung prüft
die **Anzahl** der Meldungen, damit eine Doppelmeldung auffällt.

**Nebenbei ein echter Fund in der PWA, und er kam aus einer Handmessung.** Die
fehlende Quellprüfung des i18n-Generators habe ich erst einmal von Hand
nachgestellt: 716 Wörterbuch-Schlüssel gegen 457 benutzte, sieben Treffer, davon
vier dynamisch zusammengesetzte Präfixe und einer nur in einem Kommentar. Zwei
sind echt: der bekannte E-28, und neu **E-63**, `group.join.title`. Dort steht
`t('group.join.title', lang) || 'Session-Code eingeben'`, und **der Rückfall kann
nie greifen**: `window.t` gibt bei fehlendem Schlüssel den Schlüssel selbst
zurück, und der ist wahrheitswertig. Auf dem Bildschirm steht in beiden Sprachen
die Zeichenkette `group.join.title`. Fällig in Schritt 40.

**Schritt 38 trug als einziges Sperrzeichen im ganzen Dokument keinen Grund.**
Nachgeprüft und nachgetragen: die Sperre ist berechtigt, liegt aber bei E-08 über
Schritt 28 und **nicht** bei der Ökonomie. Dieselben Ökonomie-Fragen sind bei den
Schritten 31 und 32 am selben Tag als Restrisiko freigegeben worden.


### 02.09.2026, Schritt 39, und die Kette war seit Schritt 35 durchtrennt

Pause- und Ergebnisbildschirm der Jagd stehen. 2266 → 2287 Tests, neun
Mutationen, neun Treffer (fünf aus dem Auftrag, vier danach zur Gegenprobe).
Belege in `REBUILD_STATUS.md`.

**Überraschend war nicht der Bildschirm, sondern was beim Anschließen auffiel:**
`_startHunt` hat den fertig erzeugten Jagdplan seit Schritt 35 **weggeworfen**.
Begründet, nicht vergessen, D-16 war offen. Nur ist D-16 längst beantwortet,
`huntRunProvider` steht seit Schritt 36, und niemand hat den Draht wieder
angeschlossen. Der Schritt war abgehakt, die Lücke saß in einem Kommentar, und
Kommentare liest kein Tor. **Eine dokumentierte Lücke in einem erledigten
Schritt findet von allein niemand wieder.**

**Gefunden hat sie ein Test, der genau dafür gebaut war.** „Mit genug Fakten
erscheint keine Meldung" sicherte zu, dass nach dem Start nichts passiert, und
sein Kommentar sagte wörtlich, er sei die Stelle, die auffällt, sobald jemand den
Empfänger einhängt. Er wurde rot. Das ist die billigere Hälfte der Lehre: eine
Zusicherung auf eine bekannte Lücke meldet sich selbst, eine Notiz muss gelesen
werden.

**Neu offen: E-62.** Die Zeit auf beiden Bildschirmen zeigt `—` statt einer
Dauer. E-19 ist mit „der Server rechnet“ entschieden, `HuntRun` hat bewusst
keine Zeitstempel, und Dairens Satz deckt den Fall ab. Kachel und Zeile bleiben
stehen, damit das später eine Zeile kostet und keinen Umbau.

**Und hier habe ich mich geirrt, nachgewiesen von der Prüfung derselben Nacht.**
Ich schrieb, eine Jagd nach einem Neustart sei „auf der Karte als Pille da, im
Challenge-Reiter nicht". `HuntPill` liest aber ebenfalls `huntRunProvider`, und
`activeHuntProvider` hat in `lib/` keinen Verbraucher. Nach einem Neustart ist
die Jagd **nirgends** sichtbar, und die Produktvorgabe aus ADR-007, die
`bootstrap.dart` zitiert, ist an keiner Stelle eingelöst. E-65.

**Richtiggestellt: E-44.** Der 1,5-Faktor am letzten Stopp war Schritt 37
zugeordnet, sitzt aber in der abgelösten Altansicht. Im neuen Ablauf kommt er
nirgends vor, der Neubau erbt ihn also nicht.


### 02.09.2026, Die Jagd-Pille, und zwei Korrekturen nach dem Bericht

Schritt 37 steht: die laufende Jagd ist auf der Karte sichtbar. 2240 → 2266
Tests, fünf Pflichtmutationen ohne Nachschärfen. Belege in `REBUILD_STATUS.md`.

**Überraschend war, dass beide wertvollen Korrekturen aus dem Bericht kamen und
nicht aus den Tests.** Der Bauende hat gemeldet, dass `MapPosition` keine
Peilung hat, und die Formel **nicht** im Widget nachgebaut, sondern die Lücke
offen gelassen. Genau richtig: sie gehört in die Domäne, ist jetzt dort, und der
Pfeil erscheint seither wirklich, statt geprüft und unverdrahtet dazustehen. Und
er hat gemeldet, dass meine Vorgabe „die letzte Station bekommt keine Hinweise"
von der Quelle abweicht. Sie tat es, die Quelle zeigt dort den Rückfallsatz.

**Der Test dazu war grün, während das Verhalten falsch war**, und der Grund ist
allgemein genug für Muster 25: er prüfte nur, dass bestimmte Texte **fehlen**,
und die fehlen in beiden Fassungen. Wer prüft, dass etwas weg ist, prüft im
selben Test, was stattdessen da ist.

**Ein echter Bug kam vom Widget-Test selbst:** ohne `HitTestBehavior.opaque`
reagiert die Pille nicht auf Tipps neben dem Text, obwohl in der Quelle die
ganze Zeile klickbar ist. Das hätte auf dem Gerät genauso ausgesehen.


### 31.08.2026, Schritt 36 ist zu, und eine Wache hatte eine Lücke

Der Zustandshalter schließt die Naht, die `active_hunt_providers.dart` seit
Tagen beschreibt: ein Notifier besitzt die Jagd, setzt sie und schreibt danach.
`activeHuntProvider` behält seinen Typ und hat zwei Quellen mit Rangfolge.
2232 → 2240 Tests.

**Überraschend war, dass der Bauende eine Lücke gemeldet hat, die nicht in
seinem Auftrag stand.** Die Wache gegen Schreibzugriffe aus `discovery` kannte
nur den Speicher-Provider; der neue `huntRunProvider` gibt über `.notifier`
denselben Zugriff und stand nicht darauf. Geschlossen, und die neue Hälfte ist
mit einer Wegwerf-Datei nachweislich zum Beißen gebracht worden.

**Und wieder hat eine Mutation zuerst überlebt**, jetzt Muster 24: der Test ließ
den Halter in genau den Speicher schreiben, den er danach abfragte, also sagten
beide Quellen dasselbe und die Rangfolge war gar nicht geprüft.

**Eine Kleinigkeit über Mutationsproben selbst**, die ich mir merke: eine
Mutation, die schon am Übersetzer scheitert, macht `flutter test` ebenfalls rot
und ist trotzdem ein **schwächerer** Beleg als ein fallender Test.


### 31.08.2026, Die Phasen-Maschine, und zwei Mutationen, die zuerst überlebt haben

`HuntRun` steht: die Übergänge der laufenden Jagd, rein und unveränderlich, ohne
Uhr. 2212 → 2232 Tests. Belege in `REBUILD_STATUS.md`.

**Überraschend war, warum zwei der sechs Pflichtmutationen zuerst überlebt
haben, denn beide Gründe sind allgemein und stehen jetzt als Muster 22 und 23
im Katalog.** Die Untergrenze `max(0, punkte - kosten)` war unsichtbar, weil der
Test 50 gegen 50 prüfte und beide Formeln dort 0 liefern. Und die Bedingung
„nächste offene Station mit **größerem** Index" war unsichtbar, weil in jedem
naheliegenden Aufbau vor der aktuellen Station ohnehin nichts mehr offen war.
Beide Male hat nicht der Testentwurf den Fehler gefunden, sondern die
Mutationsprobe.

**Die Lehre daraus ist eine Regel für den Testentwurf**, nicht für die Probe:
wer eine Untergrenze prüft, wählt Eingaben, die sie **auslösen**; wer eine
Richtungsbedingung prüft, baut einen Fall, in dem die andere Richtung überhaupt
einen Kandidaten hätte.

### 31.08.2026, Die Regeln der Jagd, und eine Meldung, die nichts bedeutet hat

Der erste Teil des neu zugeschnittenen Schritts 36: Hinweiskosten,
Navigations-Gating nach Schwierigkeit, Pfeilindex. 2192 → 2212 Tests, fünf
Pflichtmutationen, fünf Fälle. Belege in `REBUILD_STATUS.md`.

**Überraschend war, dass „completed" nichts über den Arbeitsbaum sagt.** Der
bauende Agent geriet in eine Warteschleife und meldete dabei mehrfach „fertig",
inhaltlich jedes Mal „ich warte noch". Ich habe die erste Meldung für das Ende
gehalten und **eine Datei mitten in seiner Mutationsprobe gelesen**: für ein
paar Minuten sah `isHuntHintFree` wie ein ausgelieferter Fehler aus. War es
nicht, er hat sie zurückgenommen. Aber damit war **ich** der zweite Schreiber im
Arbeitsbaum, also genau die Falle, die im Protokoll schon steht, nur mit
vertauschten Rollen. Ein Agent in einer Warteschleife wird beendet, nicht
abgewartet.

**Und der Teil, den er nicht mehr geschafft hat, war der wichtigste.** Die
Mutationsproben standen aus. Ohne sie wären drei Dateien mit grünen Tests
eingegangen, ohne dass jemand wüsste, ob die Tests etwas halten. Ich habe sie
selbst gefahren; sie halten, alle fünf.

### 31.08.2026, Schritt 14 ist zu, und das Meiste stand schon da

Die Karte folgt dem Kompass. 2180 → 2192 Tests, vier Dateien geändert, keine
neue. Vier von fünf Pflichtmutationen gefangen.

**Überraschend war, wie wenig Teil 2 gekostet hat.** `MapCameraFollowKind.compassBearing`
lag samt Fundstellen im Absichtstyp, die 1,5-Grad-Totzone im Gate,
`isCompassDead` im Top-Chrome mit der Deckkraft der Quelle. Alles davon ist
gebaut worden, **bevor** es einen Sensor gab, und es hat gepasst. Wer eine
Schwelle einbaut, für die es noch keinen Erzeuger gibt, baut nicht auf Vorrat,
sondern lässt die Naht offen, und hier war sie es.

**Die fünfte Mutation ist nicht fangbar, und es steht kein erfundener Test da.**
`setState` unbedingt statt bedingt ändert allein die Zahl der Neuaufbauten, und
die ist von außen nicht beobachtbar. Ein Rebuild-Zähler wäre genau der Testhaken,
den dieselbe Datei schon einmal begründet ausgebaut hat. Die richtige Fassung ist
gebaut, nur unbewiesen, und das ist der ehrlichere Zustand als ein Test, der
etwas anderes misst.

**Und eine meiner Vorgaben war falsch.** Ich hatte `DateTime.now()` als
Zeitquelle des Wachhunds vorgegeben; die wird von `fake_async` nicht
mitverschoben, ein Test dagegen bräuchte ein neues Paket oder echtes Warten.
Genommen ist das Muster, das der Karten-Layer dafür schon hat.

### 31.08.2026, Schritt 14 Teil 1, und eine Paketfalle zum zweiten Mal

Der Kompass hat eine Quelle: Sensordienst, Glättung, Regel 24, sechs
Pflichtmutationen, sechs Fälle. 2148 → 2180 Tests. Die Verdrahtung in der Karte
ist Teil 2 und absichtlich getrennt.

**Überraschend war, dass die freigegebene Paketfassung nicht auflösbar ist.**
`flutter_rotation_sensor 0.4.0` hat Web-Unterstützung bekommen und dafür
`intl ^0.20.3` aufgenommen, und `flutter_localizations` aus der festgenagelten
Flutter-SDK hält `intl 0.20.2`. Das ist **dasselbe Muster wie bei
`maplibre_gl 0.27.0`**, zum zweiten Mal in diesem Projekt: eine festgenagelte SDK
friert eine transitive Abhängigkeit ein und macht die neueste Fassung eines
Pakets unerreichbar. `^0.3.1` ist die Antwort und kostet nichts, weil dort nur
das Web-Plugin fehlt.

**Und die Regelmechanik hatte einen Fall, den ich nicht vorhergesehen habe.**
`flutter_rotation_sensor` ist das erste Vendor-Paket, dessen Name selbst mit
`flutter_` beginnt, und fällt in einer Domäne damit schon unter Regel 1. Ein
zusätzlicher Regel-4-Eintrag hätte zwei Meldungen für denselben Import erzeugt.
Wer das nächste Heimatverzeichnis baut, prüft zuerst, ob sein Paket schon unter
Regel 1 fällt.

**Dieser Befund ist am 02.09.2026 erledigt, aber nicht erklärt.** Er lautete:
`dart analyze` meldet 24 Hinweise (`prefer_initializing_formals`), und zugleich
hat dasselbe Werkzeug in derselben Sitzung mehrfach wörtlich „No issues found!"
ausgegeben; beides kann nicht stimmen. **Die 24 waren echt**, sie standen mit
Datei und Zeile da und ließen sich einzeln aufzählen. Sie sind jetzt weg, alle
24 als Initialisierungs-Kurzform. **Warum irgendein Lauf grün gemeldet hat,
bleibt unerklärt**; der wahrscheinlichste Grund steht weiter unten in dieser
Datei, zwei Läufe auf demselben Arbeitsbaum. Der Widerspruch ist damit
verschwunden, nicht aufgelöst, und der Unterschied gehört hierher.

Damit er nicht zurückkommt, läuft Gate 2 seit demselben Tag mit
`--fatal-infos`. Vorher kippte ein `info` das Tor nicht, und genau daran konnten
24 Meldungen wochenlang stehen bleiben: wo 24 stehen, fällt die 25. nicht auf.

### 31.08.2026, Zwei nachgeholte Reviews, und beide Befunde lagen in meinen Dokumenten

Der Shared Kernel ist ohne Prüfung eingegangen, obwohl `HANDOFF.md` den
`architecture-guardian` **vor** den großen Brocken verlangt. Nachgeholt am selben
Tag, zwei Prüfer, und es hat sich gelohnt: drei echte Befunde aus der Architektur,
zwei aus der Umsetzung. Belege in `REBUILD_STATUS.md`.

**Überraschend war, dass kein einziger Befund eine falsche Zeile Code war.** Alle
fünf saßen in Dokumenten: eine Rücknahmebedingung, die als erfüllt las und zu
einem Viertel erfüllt ist; eine Vorhersage, die auf die falsche Regel zeigte; die
Behauptung „beide Richtungen maschinell durchgesetzt", die für eine Richtung
nichts zu prüfen hat; eine Regel, die enger geschrieben war als sie gemeint sein
kann; und ein Satz über den leeren String, der gemessen falsch war. Das ist
genau die Klasse, die dieses Repository schon dreimal als teuersten Fund
protokolliert hat, und diesmal habe ich sie selbst produziert.

**Der nützlichste Befund war eine Regel, die keine Kontrolle war.** Aufnahmeregel
4 von ADR-008 („jeder Eintrag steht im ADR") war eine Absichtserklärung: nichts
hinderte einen Commit, einen Typ in den Kern zu legen. Jetzt prüft
`kernel_admission_test.dart` das in beide Richtungen, und die Probe ist gefallen:
ein Typ ohne Eintrag macht rot, ein Eintrag ohne Typ auch. Für Regel 1 und 3 ist
**bewusst** keine Näherung gebaut, mit Begründung im ADR: eine Prüfung, die „zwei
Importe existieren" mit „zwei Domänen brauchen es" verwechselt, sieht wie eine
Kontrolle aus und ist keine.

### 31.08.2026, Nutzlast-Fassung 2, und ein falscher Reflex in meinem eigenen Test

Die laufende Jagd trägt jetzt die Indizes ihrer freigeschalteten Hinweise **und**
ihre Schwierigkeitsstufe, in einer Formänderung statt zwei. 2131 → 2144 Tests,
sieben Pflichtmutationen, sieben Fälle. Damit sind E-50 und E-51 im Neubau
gelöst und D-18 ist gebaut, nicht nur freigemacht.

**Überraschend war, wohin der erste Reflex zeigte, und er war meiner.** Mein
Speicher-Test baute die kaputte Nutzlast mit einem `!` über jeden Wert, und mit
einer nullbaren Stufe stirbt das. Der naheliegende Griff ist, die Testvorgabe zu
ändern, damit der `!` nicht mehr trifft. Genau das ist die falsche Richtung: der
`!` war von Anfang an überflüssig, ich hatte nur ein Literal zu eng getippt.
**Wenn eine neue Vorgabe an einem Testkonstrukt scheitert, ist erst das Konstrukt
verdächtig und dann die Vorgabe.**

**Und ein Mutationsergebnis war genauer als „gefallen".** Das Entfernen der
Elementprüfung in der Nutzlast lässt den Test nicht über den Rückgabewert
scheitern, sondern über einen `CastError` aus einer erzwungenen Umwandlung. Rot
ist rot, aber die Fehlerform ist eine andere, und wer das nicht weiß, hält den
Zweig für stärker geprüft als er ist.

### 31.08.2026, Der geteilte Kern, und ein Kommentar, der seine eigene Fälligkeit kannte

ADR-008 ist gebaut: `lib/kernel/` mit zwei Typen, die beiden Kopien in
`puzzles/domain` gelöscht, die zwei Umrechnungen im Übersetzer mit ihnen.
2112 → 2131 Tests, `lib/` netto **67 Zeilen kleiner**. Dazu ADR-009 für die
Gruppen-Jagd und Regel 23 im Prüfskript, beide Richtungen. Belege in
`REBUILD_STATUS.md`.

**Überraschend war zum zweiten Mal an einem Tag, dass die Regel schon
geschrieben war, bevor sie galt.** Bei `shared_preferences` heute Vormittag stand
die Ablaufbedingung im Kommentar, hier stand sie in ADR-006: die Doppelung war
als „known, measured cost" geführt, und der Review-Auslöser nannte wörtlich den
Fall, der jetzt eingetreten ist. Beide Male hat das die nächste Entscheidung
finden lassen, ohne dass jemand suchen musste. Wer einen Preis benennt, soll
gleich die Bedingung dazuschreiben, unter der er zurückgezahlt wird.

**Der teuerste Teil war nicht der Kern, sondern das Nein.** Die Aufnahmeregeln in
ADR-008 lehnen mehr ab als sie zulassen: die drei Geo-Typen aus D-9, `FactId`,
einen Ersatzwert für die Stufe, jede Entität. Ohne diese Liste wäre aus dem Kern
in vier Wochen der Ablageort geworden, an dem jede Domäne an jeder hängt, und der
wäre teurer als die Doppelung, die er ersetzt hat.

### 31.08.2026, Fünf technische Antworten, und der Block, der sie erklärt

Dairen hat den zweiten Fragenblock beantwortet: **Shared Kernel** für D-18,
**Server rechnet** für E-19, **Server ist die Wahrheit** für E-49 samt E-16,
**Realtime passt neben ADR-007** für die Gruppen-Jagd, **(b)** für D-11, und
OD-002 bleibt offen. Kein Code geändert. Wortlaut und Folgen in
`REBUILD_STATUS.md`.

**Überraschend war, dass die Antwort auf D-18 keine der drei Optionen war.**
Vorgelegt waren Kopieren, Zeichenkette und Umlagerung nach `application`, alle
drei Umgehungen. Gewählt wurde der vierte Weg, der im Fragetext nur als Nebensatz
stand: den Grenzverlauf selbst ändern. Wer drei Wege vorlegt, die alle das
Symptom behandeln, bekommt zu Recht keinen davon.

**Und derselbe Fehler ist zum zweiten Mal passiert, obwohl er protokolliert
war.** Der Fragenblock lebte wieder nur im Chat, die Antworten kamen als Liste
„1. bis 5.", und zwei waren nicht auflösbar. Für Block 1 stand die Lehre seit dem
29.08.2026 im Repository, und sie hat Block 2 nicht geschützt: eine
aufgeschriebene Lehre wirkt erst, wenn sie an der Stelle steht, an der die
nächste Handlung passiert, nicht dort, wo die letzte erklärt wird.

### 31.08.2026, Die erste Persistenz, und eine Lücke, die zur Regel wurde

`shared_preferences` ist aufgenommen, und alle fünf Speicher sind dauerhaft:
Startbildschirm, Tutorial, Audio-Modus, Sprachwahl und die laufende Jagd.
2048 → 2112 Tests. Der Vertrag `KeyValueStore` liegt in `core/preferences/`, das
Vendor-Paket ausschließlich in `services/preferences/`, wie bei
`core/diagnostics` und `services/diagnostics`.

**Überraschend war, dass das Skript seine eigene nächste Regel schon
aufgeschrieben hatte.** `check_architecture.dart` führte `shared_preferences`
ausdrücklich als bewusste Lücke, mit zwei Bedingungen: das Paket stehe nicht in
`pubspec.yaml`, und es gebe keine Entscheidung, die ein Heimatverzeichnis
benennt. Diese Änderung hat beide Bedingungen aufgehoben, und damit war Regel 22
keine Entscheidung mehr, sondern eine Durchsetzung. Ein Kommentar, der seine
eigene Ablaufbedingung nennt, ist mehr wert als einer, der nur begründet.

**Der zweite Fund war ein Absturzweg, den niemand bestellt hatte.**
`SharedPreferences.getBool` castet hart (`_preferenceCache[key] as bool?`) und
**wirft** bei einem Typwechsel unter demselben Schlüssel. Gelesen wird in
`bootstrap()` vor dem ersten Bild; ohne das `try` im Adapter wäre ein
Formatwechsel also kein verworfener Wert, sondern ein Absturz beim Start. Das ist
gemessen, der Test dazu ist grün.

**Und eine Kleinigkeit, die ein Standardwert fast versteckt hätte.**
`productionProviderScope` bekommt den Speicher als **Pflichtparameter**. Bequem
wäre ein `InMemoryKeyValueStore()` als Vorgabe gewesen, und das hätte genau den
stillen Ausfall gebaut, gegen den diese Funktion samt Test überhaupt existiert:
eine App, die startet, heil aussieht und sich nichts merkt.

### 31.08.2026, Die Aufnahme des Backends, und was daran fehlt

11 Tabellen, 30 Funktionen, 3 Trigger, 15 Policies, eine Edge Function, dazu
der Admin und 11 Pipeline-Skripte. Sieben neue Befunde als E-52 bis E-58, kein
Code geändert, `docs/operations/backend-inventory.md`. **Überraschend war, dass
der schwerste Fund eine Abwesenheit ist:** es gibt kein Migrationssystem, kein
`config.toml`, keine Ledger-Tabelle, jede der acht Dateien trägt „Run manually
in Supabase SQL Editor" im Kopf. Die Dateien sagen, was jemand vorhatte, nicht
was in der Datenbank steht, und zwei Funktionen sind deshalb zweimal definiert,
mit unterschiedlichem Verhalten je nach Kopierreihenfolge. **Der zweite
Überraschungsfund ging in die andere Richtung:** der Client-Vertrag der PWA
liegt vollständig in **einer** Datei, `api.jsx`, und der Neubau ruft von den 17
RPCs bisher **keinen einzigen**. Die Kopplung ist heute fast null und wächst mit
jedem Schritt ab 36.

### 31.08.2026, der ganze Entscheidungsstapel ist beantwortet

Janek hat Produkt, UX, Kosten und Paketfreigaben an einem Stück beantwortet.
Wortlaut und Folgen in `REBUILD_STATUS.md`. Sechs Pakete frei, Phase 7 frei, die
Schritte 14, 18, 25, 31 und 32 nicht mehr blockiert, `library` gestrichen.

**Überraschend war, wo ich als Fragesteller falsch lag, und zwar zweimal in
entgegengesetzte Richtungen.** Zur Ökonomie fragte ich nach einer Entscheidung,
wo keine war: die Zahlen sind Herleitung aus der Quelle, und was übrig bleibt,
sind zwei Backend-Löcher, die von hier ohnehin nicht anfassbar sind. Sein
„das ist doch keine wichtige entscheidung von mir?“ war berechtigt. Umgekehrt
hatte ich **Trusted Time** und **die Trophäen-Quelle** bei ihm einsortiert, weil
ich auf die Kostenseite geschaut hatte; das sind aber Fragen nach der
Vertrauensgrenze und nach einer einzigen Wahrheit und gehören zu Dairen. Die
Lehre fürs nächste Mal: nicht danach sortieren, wer es bezahlt, sondern danach,
was die Frage eigentlich fragt.

**Ein Widerspruch von mir bleibt stehen und ist wichtiger als die Antwort.** Der
Avatar soll „wie bei pokemon go“ aussehen, und die Freigabe für einen
Flutter-Nachbau war an „wenn es langfristig sinnvoller ist“ gebunden. Für den
heutigen Avatar trägt das, für eine schöne 3D-Person nicht: Flutter hat keine
eingebaute 3D-Szene. Entschieden ist deshalb nur „jetzt 2D, kein WebView“, und
die Frage lautet beim nächsten Mal nicht „Flutter oder WebView“, sondern
„welche 3D-Laufzeit“.

**Und eine Antwort hat eine Entscheidung von wenigen Stunden vorher verbessert.**
Der Nachtrag zu ADR-007 hatte für das Hinweis-Feld die Münzsumme gewählt. Weil
die freigeschalteten Hinweise jetzt einen Neustart überleben sollen, sind die
**Indizes** die richtige Nutzlast: aus ihnen folgt die Summe, umgekehrt nicht.
Das Feld hat damit an einem Tag drei Formen gehabt, und die Reihenfolge steht
absichtlich sichtbar im ADR.

### 31.08.2026, der Vertrag für die laufende Jagd steht, und eine Prüfung hat vier Dinge gefunden

ADR-007 ist umgesetzt: `ActiveHunt` als Lesemodell und Nutzlast in
`challenges/domain`, `ActiveHuntStore` mit In-Memory-Vorgabe, ein nur lesender
`Provider<ActiveHunt?>` in `challenges/application`. Damit sind **Schritt 36 und
37 nicht mehr blockiert**. Keine persistente Umsetzung, `shared_preferences`
bleibt zustimmungspflichtig.

**Überraschend war, was eine unabhängige Prüfung an einer Testdatei fand, die
schon 14 eigene Mutationsproben überstanden hatte:** von 25 fremden Mutationen
überlebten fünf. Der teuerste Fund war keine Zusicherung, sondern eine fehlende:
der **Schreibweg prüfte nichts**. Eine ungültig gebaute Jagd lief eine Sitzung
lang einwandfrei und war nach dem Neustart lautlos weg, weil erst
`tryFromPayload` prüft. Behoben an der Wurzel, indem der öffentliche Konstruktor
verschwand: `tryFrom` und `tryFromPayload` sind die einzigen Zugänge, und damit
fielen NaN-Ungleichheit und ein Widerspruch zwischen zwei Kopfkommentaren im
selben Zug weg. Dazu war eine Wache **bei jeder Eingabe unerreichbar**, weil eine
andere Regel sie schon erzwang, und der Test dafür sah gemessen aus.

**Zweitens, und das ist die übertragbare Lehre:** die Schreiblücke aus
`discovery` ist **nicht** dieselbe wie beim Karten-Host, obwohl beide gleich
aussehen. Dort ist der Fehlgriff sichtbar, hier stumm, weil der Provider sein
Ergebnis merkt und ein Schreibvorgang keine Benachrichtigung auslöst. Aus dem
Review-Versprechen ist deshalb ein Gate geworden: eine Textwache, die belegt
rot wird, wenn eine Datei unter `lib/features/discovery/`
`activeHuntStoreProvider` nennt. Ohne sie kostete das Wiederöffnen der Lücke
**null** rote Tests, und das ist gemessen und nicht vermutet.

**Ein Prozessfehler von mir gehört dazu:** ich hatte zwei Bauagenten gleichzeitig
auf denselben Arbeitsbaum gesetzt. Dadurch meldete der eine `dart analyze` grün
und der Prüfer gleichzeitig rot, und beide hatten recht, nur zu verschiedenen
Zeitpunkten. Wer hier weiterarbeitet: **immer nur ein Schreiber je Arbeitsbaum**,
Prüfer dürfen parallel laufen, wenn sie ihre Gates in einer Kopie fahren.

**Was aus diesem Block offen bleibt, drei Dinge:**

1. **Der D-17-Block hat keine unabhängige Prüfung.** Der Jagd-Vertrag hat eine,
   D-17 nicht. Die Geometrie in `map_camera_horizon.dart` beruht auf zwei
   abgelesenen Zahlen und einer Annahme (`f/H = 1,5` sei eine feste
   SDK-Konstante), und die Ablesung war klug genug, um eine zweite Meinung wert
   zu sein. Die eine Gerätemessung, die die Annahme fallen lässt, steht dort
   samt vorhergesagten Zahlen für vier Neigungen.
2. **`purchasedHintCount` heißt noch Anzahl und soll Münzen tragen.** Entschieden
   im Nachtrag zu ADR-007, dort auch die Belege: die Quelle speichert
   `hintCostSpent`, und bei Kosten `[0, 20, 30]` bedeuten die Summen 20 und 30
   beide „ein Hinweis“. Die Umsetzung ändert einen Nutzlastschlüssel, wofür
   `payloadVersion` da ist. ADR und Code widersprechen sich bis dahin in genau
   diesem Feld, und der Nachtrag sagt das ausdrücklich.
3. **D-18 ist neu und liegt bei Dairen:** die Schwierigkeitsstufe hat keinen Weg
   über die Domänengrenze, `FactPuzzleDifficulty` gehört `facts` und Gate 6
   sperrt sie aus. Solange das offen ist, kann eine wiederhergestellte Jagd ihre
   eigene Stufe nicht kennen.

### 31.08.2026, D-17 ist gebaut: die Projektion sagt jetzt, ob ein Punkt vor der Kamera liegt

`MapScreenPoint` trägt ein drittes, pflichtiges Feld, der Karten-Host füllt es,
die drei Verbraucher in `discovery` prüfen es statt die Lücke ein viertes Mal zu
umschreiben. +25 Tests.

**Überraschend war, dass das fehlende Sichtfeld gar nicht fehlte.** Die Frage
sah nach einer Sackgasse aus: `maplibre_gl 0.26.2` gibt Sichtfeld und
Kamerahöhe nicht heraus, also müsste eine Rechnung im Host eine Konstante raten,
und Raten war ausgeschlossen. Die Zahl steckte aber schon in der Messnacht vom
30.08.2026: die Leiter der Messung 3 läuft gegen einen Fluchtwert, dieser
Fluchtwert **ist** der Horizont, und daraus folgt die Brennweite in einer Zeile
Arithmetik. Sie kommt auf das 1,5009-fache der Flächenhöhe, also auf das
Sichtfeld `2·arctan(1/3) = 36,87°`. Eine Messung, die für eine andere Frage
gemacht war, hat die neue mitbeantwortet, und zwar seit einem Tag.

**Der zweite Fund ist eine Vereinfachung, mit der ich nicht gerechnet hatte:**
der Abstand der Kamera zu ihrem Ziel fällt aus der Rechnung heraus. Übrig bleibt
ein Vergleich einer Bildzeile mit dem Horizont, ohne Kamerahöhe, ohne Zoom und
ohne Umrechnung von Metern in Pixel. Die teuer aussehende Alternative, jeden
Punkt mit `toLatLng` zurückzurechnen, hätte 25 zusätzliche Kanalaufrufe je
Kamerameldung gekostet **und** eine eigene Gerätemessung gebraucht, bevor man
überhaupt anfangen kann: rechnet `toLatLng` die Spiegelung rückwärts genauso wie
`toScreenLocation` sie vorwärts, erkennt die Probe gar nichts.

**Der dritte Fund ist unangenehm und gehört hierher:** dasselbe Modell rechnet
alle vierzehn Ablesungen der Messung 3 auf 0,42 % nach, und dabei fällt auf, dass
die Korrektur, die in derselben Nacht an die Tabelle geschrieben wurde, selbst
falsch ist. Das Kameraziel lag nicht 2,2 km südlich, sondern 0,44 km nördlich
des Startpunkts. Muster 9 zum siebten Mal: eine Begründung, die nach Messung
aussieht und eine Rechnung war. Das qualitative Ergebnis der Messung bleibt.

**Offen bleibt genau eine Annahme, und sie fällt mit einer einzigen Ablesung
am Gerät:** dass das Verhältnis 1,5 bei **jeder** Neigung gilt, nicht nur bei
den gemessenen 58 Grad. Wie zu messen ist und welche Zahl herauskommen muss,
steht in `map_camera_horizon.dart` und in `REBUILD_STATUS.md` bei D-17.

**Zur Testzahl:** die 2042 oben enthalten Testdateien unter
`features/challenges/`, die nicht zu dieser Änderung gehören. Vor den 25 neuen
Tests lief die Suite in diesem Arbeitsverzeichnis auf 2017, nicht auf den 1979,
die hier vorher standen.

### 31.08.2026, Schritt 15 ist wirklich fertig, und der Preis von D-12 fiel nicht an

Das Antippen der Gruppen ist gebaut, in drei Blöcken mit je einer unabhängigen
Review, 1885 → 1979 Tests. **Überraschend war, dass der von D-12 vorhergesagte
Preis gar nicht anfiel.** Er sollte „ein neues Feld im gerade fertiggestellten
Kameravertrag und einen zweiten Bewegungspfad im Host" kosten. Der naheliegende
Weg dorthin, `CameraUpdate.newLatLngBounds`, übergibt der nativen Seite aber
keinen Neigungswert, und ob die Neigung dadurch auf 0 fällt, ist im Pub-Cache
**nicht** nachprüfbar. Eine Fahrt, die die 58 Grad möglicherweise still
flachlegt, taugt nicht als Grundlage. Also ist das Rechteck eine Rechnung **vor**
der Absicht: reine Geometrie in `map/domain/`, und am Ende eine gewöhnliche
`MapCameraOneShot` mit Mittelpunkt und Zoom. Kameravertrag, Gate und
Bewegungspfade sind unangetastet, erweitert ist nur die Fassade `MapHost`.

**Der zweite Fund ist eine Untergrenze, die fast geschenkt war:** `clusterMaxZoom:
15` heißt, dass es ab Zoom 16 überhaupt keine Gruppen mehr gibt. Ein Fahrziel von
mindestens 16 lässt die angetippte Gruppe also sicher aufgehen, ohne dass irgendwer
MapLibres Gruppierung nachrechnet. Damit ist die Näherung bei der Auswahl der
Punkte bezahlbar: sie irrt in die sichere Richtung.

**Der dritte und lehrreichste Fund gehört der Review, und sie brauchte dafür keine
Mutation.** `_onGroupTap` hatte keine Sequenzsicherung, eine veraltete
Projektionsantwort konnte die frische Absicht überschreiben. Gefunden hat sie es
durch **Vergleich mit zwei Nachbarstellen**, die dasselbe Problem längst lösen und
beide älter sind als der neue Code. Das ist Muster 10 in seiner unangenehmsten
Form: nicht zwei Stellen, von denen eine ungeprüft ist, sondern eine dritte, die
eine bereits bezahlte Lehre nicht mitgenommen hat. Wer hier nur mutiert, findet
das nicht; man muss die Nachbarn lesen.

Nebenbei zwei neue Blindheitsmuster, 20 und 21 in „Wie Tests hier blind werden",
und eine falsche Zeile in der Paketlücken-Tabelle behoben: dauerhaftes
Kamera-Padding gibt es doch, es heißt nur `updateContentInsets` und nicht
`setPadding`. „Null Treffer im ganzen Paket" war eine Aussage über den
Suchbegriff.

### 31.08.2026, Der `balloon`-Anker, und eine Schwelle, die das Gegenteil tut

Ein Tutorial-Schritt degradiert nicht mehr, 1859 → 1885 Tests, und
`knownMissing` führt nur noch den Nutzermarker. **Überraschend war die Regel
selbst:** die Quelle verwirft beim Suchen alles unter 30 mal 30 Pixel, um den
Nutzermarker auszusortieren, und ein ruhender Ballon ist selbst nur 26 breit.
Die Regel sortiert also fast alles aus, was sie behalten wollte, und die
PWA zeigt in der Regel auf ein festes Ersatzrechteck statt auf einen Ballon.
Der Neubau misst versehentlich etwas anderes und trifft deshalb ab Zoom 14,6
echte Ballons; das steht jetzt als E-48 bei Janek statt als Parität im Code.
**Und wieder liefen zwei Mutationsläufe gegensätzlich:** fünf eigene fielen
alle, zwölf fremde liessen sechs überleben, vier davon in dem Filter, den der
Autor selbst als blind erkannt und korrigiert hatte.

### 31.08.2026, CI, und die Trophäen als Probe aufs Muster

Die vier Gates laufen jetzt maschinell, `.github/workflows/gates.yml`, und der
erste Lauf ist Schritt für Schritt grün, nicht nur als Ganzes. Danach die
Trophäenliste, 1813 → 1859 Tests, und sie war zugleich die Probe, ob die
Registrierung des neuen Datenwerkzeugs beim **zweiten** Fall trägt. Sie trug,
ungebogen, obwohl die Quelle strukturell anders ist: eine Liste statt einer
Abbildung, Einträge mit unterschiedlichen Feldern, dazu `§`, `⌂`, `☾` und
deutsche Anführungszeichen. **Überraschend war, dass zwei von fünf
Pflicht-Mutationen echte Lücken aufdeckten statt die Mutation zu bestätigen:**
die Graustufe zu entfernen überlebte, weil eine gesperrte Karte ohnehin nur
neutrale Töne trägt, und eine Stufenfarbe zu ändern überlebte, weil kein Test je
den Farbwert prüfte, nur die Zuordnung des Wortes.

### 31.08.2026, Schritt 35, und zwei Mutationsläufe mit gegensätzlichem Ergebnis

Der Startpunkt-Picker steht, „Starten" führt jetzt irgendwohin, und die
kuratierten Datendateien der PWA haben ein Muster bekommen statt einer Lösung:
ein Werkzeug mit Registrierung, die nächste Datei kostet einen Listeneintrag.
1729 → 1813 Tests. **Überraschend war der Vergleich der beiden
Mutationsläufe:** der Bauende fuhr zwölf Mutationen und zwölf fielen, die
Review fuhr zwölf andere und **zwölf überlebten**. Wer seine eigenen
Zusicherungen mutiert, misst nur, wie gut er getroffen hat, was er ohnehin im
Blick hatte. Der schwerste Fund daraus war eine Wiederholung: die Faktenliste
der Kartenüberlagerung auf leer zu setzen liess keinen einzigen Fakt auf der
Karte erscheinen, bei 1792 grünen Tests, genau wie in Schritt 15 eine Ebene
tiefer.

### 30.08.2026, E-33 und E-36, und eine Begründung von mir, die nicht stimmte

Das Kästchen „Angemeldet bleiben" ist raus, und unter 390 logischen Pixeln
schrumpft die Flagge der Sprachzeile von 30 auf 20, damit die Zeile bei 360
einzeilig bleibt. 1726 → 1729 Tests. **Überraschend war die Vorfrage:** Janek
hat nicht zwischen den vorgelegten Möglichkeiten gewählt, sondern gefragt, ob
so ein Kästchen überhaupt sinnvoll ist, und beim Nachmessen fiel die Antwort
eindeutig aus. `persistSession` wird beim App-Start entschieden, ein Kästchen
auf der Anmeldeseite kann es gar nicht mehr umlegen. **Und der zweite Fund war
mein eigener Fehler:** E-36 schrieb der Quelle eine Regel zu, die sie nicht
hat. Sie zeichnet ihre Flaggen unbedingt mit 30, eine Breitenschwelle gibt es
dort nirgends. Ich hatte die Option mit dieser falschen Begründung vorgelegt;
die Verkleinerung ist eine bewusste Abweichung und kein Nachbau.

### 30.08.2026, Schritte 33 und 34, und ein Plan, der den falschen Pfad beschreibt

Der Assistent der Schnitzeljagd ersetzt den Platzhalter im Reiter, dazu der
reine Routengenerator, 1625 → 1726 Tests. **Überraschend war, was die
Vorprüfung im Plan gefunden hat:** die Solo-Jagd läuft in der Quelle auf der
Karte, nicht im Reiter, und die Plan-Schritte 36 und 37 beschreiben deshalb den
Demo-Pfad, der seine Stationen aus rund 650 Zeilen hartcodierter Beispieldaten
schneidet und die Ausgabe des Generators nie sieht. Der zweite Fund liegt in
der Quelle selbst: eine dreistufige Auswahl mit dem Kommentar „FIX
(Daniel-Feedback)" **kann das Ergebnis nicht ändern**, weil die engeren Stufen
Anfangsstücke derselben sortierten Liste sind. Und zum zweiten Mal in dieser
Nacht war der teuerste Reviewfund keine falsche Zeile Code, sondern eine
Begründung, die sich als gemessen ausgab und beim Nachmessen zwei Aussagen
daneben lag.

### 30.08.2026, Schritt 27: das Rätsel-Sheet, Anfang von Phase 4

Typisierter Rätselvertrag, Übersetzer und Sheet-Rahmen, ohne Einstieg wie die
Fakt-Akte, 1554 → 1625 Tests. **Der naheliegende Entwurf wäre falsch gewesen:**
die Quelle wählt die Rätselform nicht am Feld `type`, sondern sieht zuerst
darauf, ob Antwortoptionen vorliegen, und ihr Standardzweig trägt 1469 der
Datensätze. Eine Aufzählung über `type` hätte sie verworfen. **Der teuerste Fund
kam wieder aus der Review und betraf eine Wache, nicht den Code:** die
Einstiegs-Sperre schnitt jede Zeile ab dem ersten `//` ab, um ihren eigenen
Kommentar nicht zu finden, und war damit hinter einem Kartenschlüssel `'//r':`
umgehbar. Die Probe kam durch alle vier Gates **und** durch die Wache. Elf
Mutationen an der Optik überlebten zunächst; nach einem Bildtest der
Marken-Blase fallen elf von elf.

### 30.08.2026, Die Ballons standen außerhalb des Bildschirms

Die Projektion liefert Geräte-Pixel, die Umrechnung fehlte, und damit stand
jeder nahe Ballon um den Faktor 2,625 zu weit von der linken oberen Ecke weg.
1553 → 1554 Tests, Behebung eine Zeile, geprüft über zwei Skalierungsfaktoren,
eine Mutationsprobe und eine Zahl gegen ein Bildschirmfoto. **Überraschend war,
warum das niemandem aufgefallen ist:** ein Ballon, der aus der Fläche fällt,
wird nicht falsch gezeichnet, sondern gar nicht, und ein fehlender Ballon sieht
aus wie ein Fakt, der eben nicht in Reichweite ist. Der Fehler hatte damit kein
Aussehen, an dem man ihn hätte erkennen können, nur eine Abwesenheit.

### 30.08.2026, Die vier Gerätemessungen, und eine Zahl kippt eine Gegenprobe

Alle vier sind beantwortet: `moveCamera` bricht ab, die 200 ms `steeringGrace`
haben Faktor 20 Luft, und die Projektion hängt nicht hinterher, sondern ist von
beiden Werten der frischere. **Überraschend war, dass die zwei teuersten Funde
gar nicht auf der Liste standen.** Hinter der Kamera liefert die Projektion
keine Ausnahme und kein `NaN`, sondern eine still gespiegelte Zahl, die von
einem weit voraus liegenden Punkt nicht zu unterscheiden ist. Und
`toScreenLocation` liefert **Gerätepixel**: eine einzelne abgelesene Zahl kippt
damit die Bildvergleichs-Gegenprobe vom Vortag, und zwar genau in der Richtung,
vor der derselbe Eintrag gewarnt hatte.

### 29.08.2026, Die sechs Fragen an Dairen stehen endlich im Repository

Wortlaut, Blockadewirkung und Nachträge liegen jetzt in `REBUILD_STATUS.md`,
kein Code geändert. **Überraschend war der Anlass:** die sechs Fragen, an denen
praktisch jeder verbleibende Schritt hängt, existierten nur im Chatverlauf,
während das Repository ihre Nummerierung an drei Stellen benutzte und an keiner
auflöste. Beim Abgleich sind zwei Prämissen abgelaufen: D-12 empfahl eine
Entscheidung **vor** Schritt 15, der am selben Tag gebaut wurde, und D-10s
„das erste `application/`" gilt seit den Schritten 15 und 16 nicht mehr. Der
dritte Fund formt eine Antwort um: eine pauschale Testregel für D-11 würde
ausgerechnet die zwei Tests verbieten, die den teuersten Fund der Woche
abgedeckt haben.

### 29.08.2026, Erster Gerätelauf mit echter Karte, und eine zurückgenommene Diagnose

Die Karte läuft: gebackener Stil, Gruppen mit Zahlen, Sky-Fall, GPS-Folgen,
Näherungs-Animation mit Glühen und Drehung. Zwei der fünf offenen Messungen
sind damit beantwortet, die Glyphen kommen und die Projektion liefert
brauchbare Werte. **Überraschend war mein eigener Fehler:** ich hatte aus dem
allerersten Lauf, in dem noch nichts geladen war, geschlossen, die
Überlagerung zeichne nicht, und darauf eine Ursachenkette bis zur
Einheitenverwechslung gebaut. Die Gegenprobe hat sie widerlegt, mit und ohne
Umrechnung stehen die Ballons an derselben Stelle. Nebenbei entstand dabei die
erste **redende Diagnose-Senke**, und die hat sofort zwei Datenfunde geliefert.

### 29.08.2026, E-40: Materials Zeilenhöhe raus, wie E-38 eine Ebene tiefer

Die Suche nach der Ursache im Tutorial führte auf einen app-weiten Fehler,
behoben am selben Hebel wie E-38. Der lehrreichste Fund des Abends ist aber der
Testrahmen: `map_top_chrome_test.dart` pumpte ein nacktes `MaterialApp` und hat
die Maße deshalb die ganze Zeit **richtig** gemessen, während die App sie falsch
zeichnete. Ein Testrahmen, der die Vorfahrenkette der App nicht abbildet, kann
über die falsche Sache recht haben.

### 29.08.2026, Der Stil einmal wirklich gesehen, und zwei Fehler dabei gefunden

Erster Gerätebuild mit verdrahteter Karte, Exit-Code 0, und der gebackene Stil
trifft. Überraschend war, was die Startfehler-Seite offenbarte: gelbe
Doppellinien, weil `MaterialApp(home: ColoredBox(...))` keinen `Material`-Vorfahren
hat, und derselbe Fehler saß sichtbar im Audio-Dialog. Wer dagegen ein `Material`
einzieht, holt sich Materials Typografie ins Haus. Beim Nachmessen fiel eine
naheliegende Annahme: durchgekommen ist nur `height: 1.43`, die Laufweite nicht,
weil E-38 in `ThemeData.typography` sitzt.

### 29.08.2026, Schritt 21: die Fakt-Akte, Anfang von Phase 3

Der größte einzelne Bildschirm des Neubaus bis hierher, 1421 → 1540 Tests. Der
Zuschnitt kam überraschend aus einer Produktregel und nicht aus dem Plan: ein
Ballon-Tipp darf nie in die Akte führen, sonst liest jemand aus 1000 km
Entfernung einen Fakt, also ist die Akte **ohne Einstieg** gebaut und ein Test
bewacht das. Der zweite Fund ist ein blinder Test, den Flutter sogar gemeldet
hatte: zwei von vier Skalierungstests tippten ins Leere, `tap()` warnt dann nur,
und ein grünes Gate hat die Warnungen durchgewinkt.

### 29.08.2026, Schritt 17: die Münzen reagieren auf Nähe

Größe, Glühen und Drehung sind da, für **jeden** Ballon innerhalb der 150 Meter
und nicht nur für den nächsten; Janeks Zusage ist eingelöst, 1308 → 1421 Tests.
Der Entwurf ist am Gegenteil dessen gescheitert, was ich erwartet hatte: nicht
die Drehung bricht ihn, sondern die Größe, weil `icon-size` das ganze Bild
skaliert und der Ballon bei Annäherung vom Boden abgehoben wäre. Der tiefste Fund
der Woche: die Perspektive erreicht den Ballonkopf in der PWA gar nicht, sie
bleibt trotzdem, weil die Quelle sie ausdrücklich wollte.

### 29.08.2026, Schritte 15 und 16: die Fakten liegen auf der Karte

Zusammen gebaut, weil gruppierte und einzelne Punkte nativ eine GeoJSON-Quelle
teilen, 1203 → 1308 Tests; Antippen bewusst nicht. Die teuerste Lücke fand die
Review und nicht die Gates, und sie lag genau dort, wo niemand hinsah: die sechs
Zeilen Durchreichung im echten Host hatten null Tests, `setOverlay` leer zu
machen löscht jeden Fakt von der Karte und lässt alle 1290 Tests grün. Zweite
Überraschung: eine falsche Zeilennummer hat eine technische Aussage getragen,
die so nicht stimmt.

### 29.08.2026, Regel 21: der Ortungsdienst bekommt ein Heimatverzeichnis

`geolocator` gehört ab jetzt maschinell nach `lib/services/location/`; im Bestand
ändert das nichts, es gibt genau einen Import und der liegt richtig. Das war
keine neue Entscheidung, sondern die Durchsetzung einer akzeptierten.
Überraschend war der Rand: Regel 20 stand seit dem 28.08.2026 nur im Skript und
in keinem Dokument, Regel 19 meldete in Domänen doppelt und irreführend, und
Regel 4 war im Dokument enger formuliert als im Skript.

### 29.08.2026, Fundstellen des Karten-Chrome: 41 von 138 waren falsch

Ein vollständiger Rundgang über die zehn Chrome-Dateien und ihre Testdatei, nur
Kommentartext geändert, Testzahl unverändert 1198. Überraschend ist nicht die
Quote, sondern dass es keine Formel gibt: der Versatz war ein bis drei Zeilen,
mal zu hoch, mal zu tief, jede Angabe muss einzeln aufgeschlagen werden.
Fundstellen sind hier Vertragsfläche, weil die nächste Sitzung sie **statt** der
Quelle liest.

### 29.08.2026, Schritt 13: die Karte folgt dem Nutzer

Ortungsdienst, GPS-Folgen, Sky-Fall und die drei Bedienelemente des Top-Chrome,
1116 → 1198 Tests. Überraschend war, dass der Schritt gar nicht blockiert war:
wo der Standort hingehört, stand die ganze Zeit in einem akzeptierten Dokument.
Der teuerste Bestandsdefekt nebenbei: der Kompass-Knopf wartete 500 statt 700 ms,
und der bestehende Test hätte ab jetzt lautlos den falschen Rückruf gemessen.

### 29.08.2026, Schritt 12: MapLibre-Host mit gebackenem Stil

Die Karte ist echt, zwei Hälften, gebackener Stil und Host darunter, 1017 → 1084
Tests. Der wichtigste Fund ist kein Fehler, sondern eine Grenze, die zum ersten
Mal scharf wurde: ein Feature kann den Karten-Host **niemals selbst mounten**,
Regel 18 bricht ab, die Kartenfläche kommt als Widget-Parameter vom Routen-Adapter.
Der teuerste Testfund betraf das Testnetz selbst, `rootBundle` cacht sein
`Future` über Testgrenzen hinweg und vier Tests fielen ohne jede Ausnahme. Aus
der Review kam ein Steuerfenster, das dauerhaft offen stand, sodass eine echte
Zwei-Finger-Drehung nie einrastete.

### 29.08.2026, D-5: das Karten-Chrome wird eine geschlossene Einheit

Aus zehn öffentlichen Typen in einer Datei von 1096 Zeilen wird ein benutzbarer
Name; kein Test wurde umgeschrieben, die Testzahl blieb bei 987. Überraschend
waren beide Prämissen der Frage falsch: `tour_chrome.dart` ist kein
Präzedenzfall, sondern das Gegenbeispiel, und die Messbarkeit hing nie an den
öffentlichen Typen. `@visibleForTesting` ist hier kein Linter-Gemecker, sondern
ein Gate, und seine Grenze ist die **Bibliothek**, nicht die Datei.

### 28.08.2026, Fundament von `lib/map/`: die Kamera als Vertrag

Fünf reine Domänenverträge unter `lib/map/domain/`, 149 Tests, gebaut **vor**
Schritt 12, weil der Kameravertrag entscheidet, was der Host danach kostet. Der
Grund, warum es diese Verträge überhaupt gibt, ist eine Messung am Paket: ohne
`isEasing()` und ohne `stop()` muss der Host seinen Animationszustand selbst
führen. Der teuerste Fund kam aus der Review und lag im eigenen Auftrag,
Vorrangregel 2 auf einen Zeitpunkt zu verkürzen ist beweisbar falsch. Schlimmer
als die Lücke war, dass der Code die Verkürzung als quellentreu dokumentierte:
**ein Fehler, der sich als belegt ausgibt, wird nicht nachgeprüft.**

### 28.08.2026, Schritt 11: Tutorial-Overlay, Phase 1 abgeschlossen

Neun Schritte unter `lib/app/onboarding/`, ohne eigene Route: das Overlay hängt
über der ganzen `AppShell`, ein Tipp auf einen fremden Tab-Knopf schaltet den
Tutorial-Schritt weiter statt den Zweig zu wechseln. Der teuerste Fund kam nicht
aus einem Layout-Test, sondern aus einem `assert` der Anker-Registry: die
naheliegende Fassung hätte beim Tourende die ganze Shell samt aller vier
Navigationsstapel neu gebaut. Ein Sicherheitsmechanismus aus Block 1 hat einen
Fehler in Block 2 gefangen, für den kein Test dieser Art vorgesehen war.

### 28.08.2026, Review der Schritte 9 und 10, zehn Lücken geschlossen

47 Mutationen, 13 haben die Suite überlebt, kein blockierender Fund. Der teuerste
Fall wäre unsichtbar geblieben: die Anmeldung hätte E-Mail und Passwort
vertauschen können, und alle 614 Tests wären grün geblieben, während die
Registrierung an derselben Stelle dicht war. **Zwei Bildschirme, gleiches Muster,
nur einer geprüft: das ist die Stelle, an der man in diesem Projekt suchen muss.**

### 28.08.2026, E-27 entschieden

Die Anker-Registry entsteht unter `lib/core/anchors/`, die Kennungen bleiben bei
der Oberfläche, die sie besitzt. Ausschlaggebend war nicht „ist das allgemein
genug für `core`", sondern die **Importrichtung**. Wichtiger als die Entscheidung
ist, was sie nicht absichert: Regel 11 zerlegt nur Pfade und sieht den
Dateiinhalt nie, sie schützt hier nicht, sie täuscht Schutz vor.

### 27.08.2026, E-38: Materials Laufweite raus

Der Eingriff sitzt woanders, als jeder erwartet, der sich `FactTheme` ansieht,
nämlich in `ThemeData.typography`, weil das `Theme`-Widget Materials Werte erst
beim Lokalisieren als **Basis** unter den eigenen Stil mischt. Überraschend war
der zweite Teil: alle 15 hartcodierten Laufweiten der Identity-Bildschirme sind
gegen die Quelle belegt, auch die drei, die genau wie Material-2021-Werte
aussehen. Wer hier pauschal aufgeräumt hätte, hätte die Parität zerstört.

### 27.08.2026, erster Gerätelauf

Der Build-Blocker fiel, und danach lief die App zum ersten Mal; vier Funde, die
keine Testsuite hätte finden können. Der Paketkonflikt war **nicht** die
`minSdk`, wie seit Phase 0 vermutet, sondern AGP 9 gegen Flutters
Kotlin-Umstellung. Der Fund mit der größten Reichweite ist einer am Testnetz: die
Tests prüften auf **Überlauf**, und ein Zeilenumbruch ist keiner, es gab Tests
für genau die umbrechende Zeile und sie waren blind. Dasselbe beim nativen
Startbildschirm, für den `flutter test` vollständig blind ist.

### 27.08.2026, Schritt 9: Anmeldung mit Auth-Unterbau

Vertrag in `identity/domain/repositories/`, Supabase-Anbindung in `data/`,
Sitzungszustand und Bildschirm in `presentation/`, 463 Tests. Der Kern war keine
Zeichenaufgabe, sondern eine Verdrahtungsfrage: **`presentation` darf `data`
nicht importieren**, ein Anmeldeformular braucht aber Supabase; der Weg, der alle
neun Prüfungen erfüllt, ist ein auf den Domänenvertrag typisierter Provider mit
untätigem Standard plus Override aus `bootstrap.dart`. Überraschend war, dass die
naheliegende Lösung an Regel 7 gescheitert wäre und dass `Override` aus
`flutter_riverpod` gar nicht exportiert ist. Der Passwort-Reset ist bewusst nicht
angeboten, weil PKCE den Code-Verifier auf dem Gerät ablegt.

### 27.08.2026, Schritt 8: Audio-Aktivierungsdialog

Der 🎧-Knopf des Startbildschirms öffnet ihn, „Aktivieren" setzt eine Präferenz,
die **nichts bewirkt**, weil es noch keine Wiedergabe gibt; 384 Tests. Die
Aufgabe verlangte überraschenderweise eine echte Architekturentscheidung statt
Zeichnen, weil der Bildschirm `identity` gehört und die Audio-Präferenz
`settings`. Der Fund mit der größten Reichweite: **`flutter test` lädt keine
Schriften**, jede Glyphe ist ein Quadrat der Schriftgröße, und damit haben alle
Layout-Zusicherungen der Schritte 7 und 8 ein Layout geprüft, das es nicht gibt.

### 27.08.2026, Schritt 7: Startbildschirm und Router-Weiche

`/splash` außerhalb der Shell, die Weiche als reine Funktion, dazu
`FirstLaunchStore`; Login und Signup als Platzhalter, 348 Tests. Überraschend ist
schon der Gegenstand: der Splash ist **kein Ladebildschirm**, der zeitgesteuerte
Boot-Splash der PWA wurde am 06.06.2026 absichtlich entfernt, und was
„SplashScreen" heißt, ist ein interaktiver Bildschirm mit drei gleichrangigen
Ausgängen samt Gastmodus. Die teuerste Falle war ein Testmuster: eine eigene
`MediaQuery` um `FactApp` verdeckt die echte, und jede Layout-Zusicherung ist
danach lautlos wertlos.

### 26.08.2026, Schritt 6: App-Shell, Phase 0 abgeschlossen

Vier Tabs, aus `chrome.jsx:55-60` belegt statt geraten, `StatefulShellRoute` für
unabhängige Stapel, typisierte Routen über `go_router_builder`, also erstmals
Codegen. Überraschend war dreierlei: der alte Port rechnet den Bodenabstand der
Leiste falsch (Summe statt Maximum, Unschärfe 18 statt 24), `Container` zählt die
Rahmenstärke zum Innenabstand und `DecoratedBox` nicht, und
`analysis_options.yaml` schließt alle `*.g.dart` aus, der Analyzer ist für die
erzeugte Routendatei also blind.

### 26.08.2026, Nachbesserungen am Fundament

Nunito 600 fehlte, wird von der PWA aber für die Tab-Leiste genutzt; Google Fonts
liefert keine statische Instanz mehr, deshalb mit `fontTools` bei `wght=600` aus
der variablen Schrift herausgeschnitten. `always_use_package_imports` aktiviert,
damit relative Cross-Feature-Importe nicht entstehen können.

### 26.08.2026, Schritt 5: Fakt-Datenmodell und Supabase

Fehler-Isolation durch Konstruktion: kein `as`-Cast auf Rohwerte, jeder Datensatz
einzeln abgebildet, Ausfälle in einem zählbaren Bericht. Das Rätsel-Mapping
übernimmt 21 Felder statt der vier, an denen der alte Port gescheitert ist. Vier
Spalten gefunden, die im eingecheckten Schema fehlen, aber existieren.

### 26.08.2026, Schritt 4: i18n

716 Schlüssel je Sprache, aus der PWA generiert. Die Zahl 763 in Parity-Spec und
REBUILD_PLAN ist falsch, das ist der Bestand des alten Flutter-Ports.

### 26.08.2026, Schritt 3: Design-Tokens

31 Farb-Tokens aus `styles.css`, per Test festgenagelt. Drei Alias-Paare
getrennt, die `.theme-light` nur halbseitig überschreibt.

### 26.08.2026, Architektur-Prüfskript

`tool/check_architecture.dart` mit den neun Prüfungen aus den Quality-Gates, 53
Black-Box-Tests. Ersatz für `riverpod_lint`, das mit diesem Abhängigkeitsstand
nicht auflösbar ist.

### 26.08.2026, Schritte 1 und 2: Gerüst und Pakete

`flutter create` mit den Store-Kennungen des alten Ports, damit der Neubau im
Store dieselbe App bleibt. Feature-Struktur nach der Domain-Map.

### 26.08.2026, Architektur-Gegenüberstellung

Parity-Spec gegen die fünf ADRs geprüft. Ergebnis: 21 offene Entscheidungen,
Stand in `REBUILD_STATUS.md`.

---

## Rechner einrichten

Alles hier ist **maschinenabhängig** und steht absichtlich nicht im Code.

### Flutter-SDK

Auf dem bisherigen Rechner liegt es unter `C:\flutter-fresh\bin\` und ist
**nicht** auf dem PATH, `C:\flutter` ist dort kaputt. Auf einem anderen Rechner
gilt das nicht: nimm deinen eigenen Pfad und ersetze ihn in allen Befehlen unten.
Geprüft mit **Flutter 3.44.1 / Dart 3.12.1**. Bevorzuge `dart analyze` gegenüber
`flutter analyze`, weil das Flutter-Werkzeug auf diesem System gelegentlich
hängt. In einem frischen Worktree zuerst `flutter pub get`, sonst meldet der
Analyzer „Target of URI doesn't exist" für jede Datei.

### Pfad zur PWA

Der i18n-Generator liest die Quelltexte aus der PWA. Der Standardpfad im Skript
zeigt auf ein OneDrive-Verzeichnis des ursprünglichen Rechners. Auf einem anderen
Rechner brauchst du:

```
dart run tool/generate_i18n.dart --source <pfad-zu>/02_Frontend/app
```

oder die Umgebungsvariable `FACT_PWA_APP_DIR`. Ohne einen davon bricht das Skript
mit Exit-Code 2 und einer Anleitung ab. **Ohne PWA-Zugang kann man trotzdem
arbeiten:** die erzeugten Sprachdateien sind versioniert, der Generator ist nur
nötig, wenn sich die PWA-Texte ändern.

### Supabase

URL und publizierbarer Schlüssel kommen über `--dart-define`, es steht kein Wert
im Repository:

```
flutter run --dart-define=SUPABASE_URL=https://<projekt>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_<rest>
```

Gilt genauso für `flutter build apk`, `flutter build ipa` und `flutter test`.
Alternativ `--dart-define-from-file=env.json`, diese Datei gehört **nicht** ins
Repository.

### Android-Build: gelöst am 27.08.2026

**Ursache:** `Selector.open()` scheitert, weil Java dafür einen
Unix-Domain-Socket im Temp-Verzeichnis anlegt, und AF_UNIX ist auf diesem Rechner
unter `AppData` nicht verbindbar. Es war nie ein Netzwerkproblem, obwohl die
Meldung „Unable to establish loopback connection" genau das nahelegt. Die
Messreihe, der Weg durch die JDK-Quellen, die vierzehn ausgeschlossenen
Vermutungen und die Prüfschleife `SelectorProbe.java` stehen in
`REBUILD_STATUS.md` unter „Der Android-Build-Blocker, forensisch".

Die Umgehung ist eine Benutzer-Umgebungsvariable, keine Administratorrechte
nötig:

```
[Environment]::SetEnvironmentVariable('JAVA_TOOL_OPTIONS', '-Djdk.net.unixdomain.tmpdir=C:\gtmp', 'User')
```

Wirkt in jedem **neu gestarteten** Programm, also auch in Android Studio;
bestehende Terminals neu öffnen. Jede JVM gibt danach `Picked up
JAVA_TOOL_OPTIONS: ...` auf der Fehlerausgabe aus, das ist normal. Das
Verzeichnis `C:\gtmp` muss existieren, und jeder Pfad außerhalb von `AppData`
geht.

### Nicht aus einem OneDrive-Pfad bauen

Der AOT-Compiler bricht an Nicht-ASCII-Verzeichnisnamen. Dieses Repository liegt
deshalb unter `C:\dev\flutter-fact`. Wenn du es woanders klonst, nimm einen
kurzen ASCII-Pfad.

---

## Befehle

### Die vier Gates

Müssen alle vier auf Exit-Code 0 stehen, bevor etwas committet wird:

```
dart format --output=none --set-exit-if-changed lib test tool
dart analyze --fatal-infos
dart run tool/check_architecture.dart
flutter test
```

**Warum `lib test tool` und nicht `.`:** ab dem ersten Gerätebuild existiert
`build/` mit Gradle-Zwischenprodukten jenseits der Windows-Längengrenze, und
`dart format .` stürzt dort mit `PathNotFoundException: Directory listing failed`
ab und liefert Exit-Code 1, ohne dass am Quellcode etwas falsch ist. `build/` und
`.dart_tool/` stehen in `.gitignore`, das Gate soll sie also ohnehin nicht
ansehen.

**Hänge kein `| tail` an einen dieser Befehle, wenn du den Exit-Code
auswertest.** Die Pipe maskiert ihn, und genau dadurch wurde hier schon ein rotes
Gate stillschweigend durchgewinkt.

**Seit dem 31.08.2026 laufen die vier auch maschinell**,
`.github/workflows/gates.yml`, bei jedem Push nach `main` und bei jedem Pull
Request. Der Flutter-Stand ist dort auf dasselbe Tag festgenagelt wie lokal,
3.44.1; wer ihn hebt, hebt ihn an beiden Stellen, sonst prüfen zwei
verschiedene Stände. **Die drei Drift-Werkzeuge laufen dort nicht**, zwei davon
lesen die PWA im Lese-Repo, und das liegt auf einem privaten Rechner. Eine von
Hand bearbeitete erzeugte Datei kommt also durch CI, und das ist gemessen: ein
verfälschter Hotspot-Name ließ alle 1792 Tests grün und schlug nur im
Drift-Werkzeug an. Diese drei bleiben lokal, und **grün in CI heißt deshalb
nicht, dass alles geprüft ist**.

**Dass der Workflow auch rot wird, ist gemessen und nicht angenommen.** Ein
grüner Lauf beweist nur, dass er läuft. Am 31.08.2026 lief deshalb eine
Gegenprobe auf einem Wegwerf-Zweig: ein absichtlich fallender Test, Gates 1 bis
3 grün, **Gate 4 rot, ganzer Lauf rot**. Zweig und Test sind danach gelöscht.
Ein Gate, das nie gefallen ist, ist ein Gate, das niemand geprüft hat.

### Generierten Code neu erzeugen

```
dart run build_runner build
dart run tool/generate_i18n.dart
```

`--delete-conflicting-outputs` gibt es in `build_runner` 2.15.1 nicht mehr, das
Flag wird nur mit einer Warnung ignoriert. Erzeugte Dateien **sind versioniert**,
`*.g.dart` steht nicht in `.gitignore`; Grund im Kommentar dort und in
`REBUILD_STATUS.md`.

### Drift der erzeugten Dateien prüfen

**Drei** Werkzeuge, alle mit `--check`, alle müssen auf 0 stehen:

```
dart run tool/generate_i18n.dart --check
dart run tool/bake_map_style.dart --check
dart run tool/generate_curated_data.dart --check
```

Das zweite gibt es seit Schritt 12: der Kartenstil wird **gebacken**, nicht zur
Laufzeit umgefärbt, und das ist gemessen und nicht gewählt, siehe „Was
`maplibre_gl 0.26.2` nicht kann". Der Ausgangsstil ist eingecheckt
(`tool/map_style/liberty_upstream.json`) und wird **nicht** bei jedem Lauf aus
dem Netz geholt: ein Werkzeug, das lädt, erzeugt still bei jedem Lauf ein anderes
Ergebnis, und niemand sieht, wann sich der Anbieter geändert hat.

Das dritte gibt es seit Schritt 35 und es ist **eine Registrierung, kein
Einzelfall**: die PWA hat mehrere kuratierte Datendateien, die der Neubau
braucht, und vier davon liegen auf dem Weg der nächsten Schritte
(`hunt-hotspots.js` 45 Zeilen, `wallet-colors.jsx` 155, `hunt-routes.jsx` 229,
`damals-heute.jsx` 112, dazu `city-intros.jsx` mit 747). Eine weitere kostet
einen Listeneintrag und eine Render-Funktion, **kein zweites Werkzeug**. Fünf
Werkzeuge mit fünf `--check`-Aufrufen vergisst nach dem dritten Mal jemand.

Anders als `bake_map_style.dart` liest dieses Werkzeug die **PWA direkt**, wie
`generate_i18n.dart`, weil sein Ursprung kein Anbieter im Netz ist, sondern
das Lese-Repo. Ohne Zugang dorthin bricht es mit einer Anleitung ab, und
`flutter test` läuft trotzdem durch: die erzeugten Dateien sind versioniert.

---

## Was man wissen muss, bevor man Code anfasst

Die vier Punkte, die am häufigsten falsch gemacht werden.

**1. Der REBUILD_PLAN im Lese-Repo gibt die Reihenfolge vor, nicht die
Architektur.** Sein Grundprinzip 4 nennt `provider` und ein globales `AppState`.
Das widerspricht ADR-003 und ADR-005 und gilt hier nicht. Weitere nachgewiesene
Sachfehler des Plans stehen in `REBUILD_STATUS.md`.

**2. Die Domäne darf fast nichts importieren.** Erlaubt sind nur `dart:`-Importe
und Dateien der eigenen Feature-Domäne. Kein Flutter, kein Riverpod, kein
Supabase, kein Routing, auch **kein `core`**. Das prüft
`tool/check_architecture.dart` maschinell über eine Erlaubnisliste, die derzeit
leer ist.

**3. Navigation nur über typisierte Routen.** Route-Strings gibt es
ausschließlich in `lib/app/routing/`. Zum Schließen `context.pop()`, nicht
`Navigator.pop(context)`. Der Prüfer meldet jeden `Navigator.`-Aufruf außerhalb
des Routing-Verzeichnisses.

**4. Kein Text hartcodieren.** Alle Beschriftungen kommen über `AppStrings` aus
den generierten Sprachdateien. Werte für Farben, Größen und Abstände kommen aus
der PWA, nicht aus dem alten Flutter-Port, der an mehreren Stellen weggedriftet
ist.

---

## Arbeitsweise mit Claude

Bewährt hat sich, was nicht im Code steht und deshalb hier festgehalten wird.

**Zwei Entscheidungswege, und sie werden nicht vermischt.** Janek ist Product
Owner, hat die App gebaut und sich alles ausgedacht: Design, Schriften, Features,
Namen, Aufbau und Inhalt gehen an ihn und dürfen jederzeit direkt gefragt werden.
**Technische Fragen, vor allem Architekturfragen, gehen an Dairen**, werden aber
**gesammelt** und am Anfang oder Ende einer Sitzung als Block ausgegeben,
ausdrücklich als Fragen an Dairen gekennzeichnet. Der Grund steht nicht im Code:
Janek muss für jede Dairen-Frage eine WhatsApp schicken, jede einzelne verzögert
spürbar. Kleinkram wird **nicht** eskaliert, sondern selbst entschieden und
dokumentiert; was das Ergebnis wirklich prägt, darf umgekehrt nicht
unterschlagen werden, nur weil Fragen unbequem sind.

**Grün heißt hochladen.** Angewiesen am 28.08.2026, ersetzt die frühere Regel
„pushen nur mit Freigabe": sind die Gates gelaufen und grün und steht keine
wichtige Frage offen, wird committet, nach `main` gemerged und gepusht, ohne zu
fragen. Die Bedingung ist wörtlich zu nehmen, **gelaufen**, nicht vermutet. Ein
Gate, dessen Exit-Code niemand angesehen hat, zählt nicht, und eine offene
Entscheidung, die den Stand prägt, ist ein Grund zu warten.

**Gefundene Fehler werden behoben, nicht mitportiert.** Ebenfalls am 28.08.2026
angewiesen: wer beim Bauen einen Fehler im bestehenden System findet, behebt ihn,
und zwar **bevor** der nächste Schritt beginnt. Drei Abgrenzungen gehören dazu,
sonst wird die Anweisung falsch angewendet:

- *Nicht jede Abweichung von der Erwartung ist ein Fehler.* Die PWA ist die
  Verhaltensquelle; wo sie etwas absichtlich anders macht, ist das Parität. Ein
  Defekt ist etwas, das der Quelle selbst schadet und das niemand so gewollt hat,
  wie das unlösbare Kompass-Rätsel auf Englisch (E-08) oder ein Kästchen, das
  nichts tut (E-33).
- *Manche Fehler liegen nicht hier.* Die drei Sicherheitslücken im geteilten
  Supabase und die Fehler der PWA selbst liegen im anderen Repository, und
  `CLAUDE.md` verbietet, es von hier aus zu ändern. Dort heißt „beheben": belegen,
  Migration oder Auftrag schreiben, übergeben. Siehe
  `docs/operations/backend-security-fixes.md`.
- *Ändert eine Behebung, was der Nutzer sieht*, wird sie trotzdem gemacht, aber
  Janek erfährt davon. Eine stillschweigende Verhaltensänderung ist auch dann
  eine Überraschung, wenn sie richtig ist.

**Spezialisten arbeiten, die Hauptsitzung orchestriert.** Die Agenten aus
`.claude/agents/` erledigen die Umsetzung, die Hauptsitzung schreibt die
Aufträge, entscheidet und führt widersprüchliche Ergebnisse zusammen. Das
Auftragsformat steht in `docs/ai/context-routing.md` unter „Context packet", das
Antwortformat in `docs/ai/agent-output.md`. Was einen guten Auftrag ausmacht,
gemessen an dem, was hier Fehler gefunden hat: nicht „schau mal drüber", sondern
benannte Prüfpunkte; nicht „teste es", sondern „lege eine Probe an, die den
Verstoß enthält, führe die Prüfung aus, lösche die Probe und berichte, was du so
verifiziert hast".

**Nach jedem Block eine unabhängige Review**, und **vor** den großen Brocken der
`architecture-guardian`, nicht danach. Der Wert der Review liegt im frischen
Kontext: der Prüfer weiß nicht, was sich der Autor gedacht hat. Bei der
Rätsel-Engine und beim Map-Host entscheidet die Struktur, was danach zwei- bis
dreitausend Zeilen kostet.

**Jeden Schritt ansagen,** in der Form „Schritt N von 50: Titel". **Nie
behaupten, was nicht gelaufen ist**, und beim Prüfen von Exit-Codes kein `| tail`
anhängen, siehe „Befehle". Diese eine Pipe hat hier schon zweimal ein rotes Gate
als grün ausgegeben.

## Diese Datei pflegen

Wer einen Schritt abschließt, aktualisiert hier:

1. **Stand:** Datum, Schrittnummer, Testzahl
2. **Als Nächstes:** was jetzt dran ist
3. **Protokoll:** einen neuen Eintrag oben, zwei bis vier Sätze. Was entstanden
   ist, und vor allem was dabei **überraschend** war. Die Überraschungen sind der
   Teil, den niemand aus dem Code zurücklesen kann.

Details gehören nicht hierher, sondern in `REBUILD_STATUS.md`: jede Zahl, jede
Fundstelle, jede Messung. Diese Datei soll in fünf Minuten lesbar bleiben, sonst
liest sie niemand, und dann ist sie schlimmer als keine. Am 29.08.2026 war sie
bei 1433 Zeilen und rund 10.400 Wörtern angekommen, also beim Zehnfachen; wer
einen Eintrag schreibt, der länger wird als vier Sätze, schreibt am falschen Ort.
