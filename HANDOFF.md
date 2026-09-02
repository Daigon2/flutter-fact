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

## Stand

**Zuletzt aktualisiert:** 31.08.2026

Phase 0 und Phase 1 sind abgeschlossen. Aus Phase 2 sind laut Protokoll die
Schritte 12 bis 17 und 19 fertig, offen bleiben dort nur noch 18 und 20.
Phase 3 hat mit Schritt 21 begonnen, Phase 4 mit Schritt 27, Phase 5 mit
den Schritten 33 bis 37 und 39.

**Fertig sind 26 von 50:** 1 bis 17, dazu 19, 21, 27, 33 bis 37 und 39. Schritt 14 ist
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

**Kennzahlen:** 2287 Tests grün, alle vier Gates auf Exit-Code 0, dazu die
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

### 31.08.2026, Schritt 39, und die Kette war seit Schritt 35 durchtrennt

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

**Sichtbar geworden, nicht neu entstanden:** eine Jagd, die einen App-Neustart
überlebt hat, ist auf der Karte als Pille da, im Challenge-Reiter nicht. Das ist
die Grenze aus ADR-007, die hier zum ersten Mal auf einen Bildschirm durchschlägt.

**Richtiggestellt: E-44.** Der 1,5-Faktor am letzten Stopp war Schritt 37
zugeordnet, sitzt aber in der abgelösten Altansicht. Im neuen Ablauf kommt er
nirgends vor, der Neubau erbt ihn also nicht.


### 31.08.2026, Die Jagd-Pille, und zwei Korrekturen nach dem Bericht

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

**Ein Befund bleibt offen, und ich sage es lieber selbst.** `dart analyze` meldet
24 Hinweise (`prefer_initializing_formals`), Gate 2 bleibt trotzdem auf 0, weil
ein `info` es nicht kippt. Vier mögliche Ursachen habe ich einzeln gemessen und
ausgeschlossen: die SDK-Anhebung, die Sprachfassung, `analysis_options.yaml` und
die Lint-Fassungen. Zugleich hat `dart analyze` in dieser Sitzung mehrfach
wörtlich „No issues found!" ausgegeben. **Beides kann nicht stimmen, und welche
Beobachtung falsch ist, habe ich nicht aufgelöst.** Belege in
`REBUILD_STATUS.md`.

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
dart analyze
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
