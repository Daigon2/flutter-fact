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
Schritte 12, 13, 15, 16, 17 und 19 fertig, offen bleiben dort 14, 18 und 20.
Phase 3 hat mit Schritt 21 begonnen, Phase 4 mit Schritt 27, Phase 5 mit
den Schritten 33, 34 und 35.

**Fertig sind 22 von 50:** 1 bis 13, dazu 15, 16, 17, 19, 21, 27, 33, 34 und 35. Der
Zählwiderspruch vom 29.08.2026 ist geklärt: `REBUILD_STATUS.md` führte Schritt
19 als offen, obwohl `map_top_chrome.dart` mit neun Teildateien und 34 Tests
steht und D-5 ihn am selben Tag zur geschlossenen Einheit umgebaut hat. Das
Kästchen war das Veraltete, nicht der Stand.

**Kennzahlen:** 1859 Tests grün, alle vier Gates auf Exit-Code 0, dazu die
**drei** Drift-Werkzeuge `generate_i18n`, `bake_map_style` und
`generate_curated_data`, alle mit `--check` auf Exit-Code 0.

**Stand der optischen Prüfung:** am 29.08.2026 zum ersten Mal **mit echter
Karte und echten Daten** am Emulator gesehen (Pixel 8, 411 logische Pixel,
Skalierungsfaktor 2,625). Gesehen und richtig: Startbildschirm, Tutorial,
Kartenbildschirm mit Top-Chrome, der gebackene Stil, Gruppen **mit ihren
Zahlen**, Sky-Fall, GPS-Folgen und die Näherungs-Animation samt Glühen und
Drehung. Ungeprüft bleiben iOS (nie compiliert), echte Hardware, 360 und 320
Pixel und Systemschrift 2.0; alle Aussagen dazu sind weiterhin strukturell.
Die vier offenen Gerätemessungen sind am 30.08.2026 alle beantwortet, Belege in
`REBUILD_STATUS.md`.

**Der Gerätelauf braucht Konfiguration, keine Arbeit:** URL und Schlüssel für
Supabase kommen über `--dart-define-from-file=env.json`, die Datei steht in
`.gitignore` und gehört nicht ins Repository. Ohne sie zeigt die App die
Startfehler-Seite. Der Build-Blocker selbst ist seit dem 27.08.2026 gelöst,
siehe „Rechner einrichten".

---

## Als Nächstes

1. **Der `balloon`-Anker**, ohne jede Antwort baubar, siehe Punkt 5. Er ist
   grösser als er aussieht: die Quelle sucht den **MapLibre-Marker** nächst der
   Rahmenmitte, und im Neubau sind nur die nahen Ballons Flutter-Widgets mit
   einem Kontext, die fernen sind native Symbole. Eine treue Umsetzung muss
   deren Lage über die Projektion selbst rechnen. Das Ersatzrechteck der Quelle
   (`x = Breite × 0,45`, `y = Höhe × 0,55`, 38 × 38) lässt sich als unsichtbares
   `AnchorTarget` an derselben Stelle nachbauen, dann braucht die Registry
   keinen neuen Mechanismus.

2. **Danach 45, 46 und 48 aus Phase 7.** Achtung beim Zuschnitt: 45 zeigt
   „X von N gesammelt" je Stadt, und `collection` ist heute eine Platzhalterseite,
   `progression` ein leerer Ordner. Die Ansicht ist trotzdem ehrlich baubar, sie
   zeigt dann den richtigen Zustand eines neuen Nutzers. 48 hängt zusätzlich an
   E-16.

3. **Die Schritte 36 und 37 warten auf D-16, nicht mehr auf Janek.** E-43 ist am
   30.08.2026 entschieden: die Solo-Jagd läuft auf der **Karte**, wie die
   Quelle. Damit ist der Plan an dieser Stelle überholt und der Zuschnitt neu zu
   machen. Was fehlt, ist die technische Antwort, **wie `discovery` an den
   Jagdzustand kommt**, denn das wäre die fünfte Cross-Feature-Kante. Siehe
   D-16.


4. **Acht Fragen für Dairen, sechs davon verschickt und unbeantwortet.**
   Wortlaut, Stand und Nachträge stehen in `REBUILD_STATUS.md` unter „Fragen an
   Dairen". Zwei blockieren heute: **D-12** das Antippen der Gruppen aus
   Schritt 15, **D-13** den ganzen Schritt 14. **D-15 ist am 30.08.2026 neu
   dazugekommen und liegt noch bei niemandem:** ob `puzzles` als Feature
   bestätigt ist, damit `tours` und `challenges` später davon abhängen dürfen.
   Sie blockiert Phase 5, **D-16** die Schritte 36 und 37. Die übrigen vier
   sperren nichts, kosten aber mit
   jedem Schritt mehr. Wer eine Antwort bekommt, trägt sie dort ein und nicht
   hier. Nicht Teil des Blocks und weiter offen: ob der Karten-Host
   im **unsichtbaren Tab** weiterfolgen soll. Der Tabwechsel entsorgt ihn nicht,
   das ist gemessen; die PWA kennt keine Tabs, es gibt also keine Quelle.
5. **Zwei Kartenanker fehlen noch, nicht fünf.** Diese Zeile stand bis zum
   30.08.2026 falsch hier: `discovery_anchors.dart:24-30` sagt, dass `coins`,
   `modeFactFinder`, `modeTour` und `compass` sich seit dem Top-Chrome aus
   Schritt 19 selbst anmelden. Übrig sind **`balloon`** und **`userMarker`**.
   `balloon` ist heute baubar und hängt an nichts: die Quelle sucht dafür den
   Marker nächst der **Rahmenmitte** (nicht nächst dem Nutzer) und nimmt bei
   Fehlanzeige ein festes Ersatzrechteck, `screen-tour.jsx:193-224`.
   `userMarker` dagegen wartet auf Schritt 18, denn den Marker selbst gibt es
   im Code noch gar nicht, und der hängt an E-10. Wer einen baut, streicht die
   Kennung aus `knownMissing`, sonst schlägt
   `discovery_anchors_test.dart` an.
6. **E-28, Lautstärke-Hinweis im Audio-Dialog.** Nur noch Wortlaut, die
   technische Sperre ist seit E-39 weg. Vorschlag DE/EN liegt in
   `REBUILD_STATUS.md` bei E-28, hergeleitet und nicht freigegeben.

---

## Protokoll

Neueste zuerst. Ein Eintrag je abgeschlossenem Schritt oder größerem Block, zwei
bis vier Sätze: was entstanden ist, und was daran überraschend war. Alle Belege
dazu stehen in `REBUILD_STATUS.md`.

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
