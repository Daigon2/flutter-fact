# Übergabe

**Diese Datei zuerst lesen.** Sie sagt, wo der Neubau steht, was zuletzt
passiert ist und was als Nächstes kommt. Sie ist bewusst kurz und wird bei
jedem abgeschlossenen Schritt aktualisiert.

Für Details nicht hier suchen, sondern:

| Frage | Dokument |
|---|---|
| Fortschritt aller 50 Schritte, offene Entscheidungen, Datenvertrags-Fallen | `REBUILD_STATUS.md` |
| Warum die Architektur so ist | `docs/architecture/`, `docs/decisions/adr/` |
| Welche Regeln beim Programmieren gelten | `docs/engineering/`, `.claude/rules/` |
| Wie die App sich verhalten muss | die PWA im Lese-Repo, siehe `CLAUDE.md` |

---

## Stand

**Zuletzt aktualisiert:** 28.08.2026, Nacht

**Phase 0 und Phase 1 abgeschlossen. Schritte 1 bis 11 von 50 fertig.** Die App
ist erstmals auf einem Gerät gelaufen, der Gerätelauf ist wegen E-38 seither
nicht wiederholt.

Steht zusätzlich seit dem Vormittag: die Anker-Registry in `lib/core/anchors/`
(E-27), eine Ergänzungs-Map für Oberflächentexte ohne PWA-Schlüssel (E-39), und
das Tutorial-Overlay unter `lib/app/onboarding/` mit neun Schritten.

**Seit der Nacht zum 29.08.2026: Schritt 12 ist fertig, die Karte ist echt.**
Unter dem Top-Chrome liegt ein `MapLibreMap` mit gebackenem Stil statt der
einfarbigen Fläche. Davor entstand das Fundament `lib/map/domain/`, die reinen
Domänenverträge des Karten-Hosts, **vor** Schritt 12 gebaut, weil der
Kameravertrag entscheidet, was danach zwei- bis dreitausend Zeilen kostet.
Dazu D-5, das Karten-Chrome ist jetzt eine geschlossene Einheit.

**Damit sind 13 von 50 Schritten fertig** (1 bis 12 plus 19).

**Kennzahlen:** 1084 Tests grün, alle vier Gates auf Exit-Code 0, dazu
`dart run tool/generate_i18n.dart --check` und
`dart run tool/bake_map_style.dart --check` auf Exit-Code 0.

**Zusätzlich fertig, außer der Reihe:** Schritt 19, das Top-Chrome des
Kartenbildschirms. Vorgezogen, weil Schritt 12 an einer Architekturentscheidung
hing und das Chrome über der Karte davon nicht abhängt. Damit sind **sieben von
neun Tutorial-Schritten** voll baubar statt vier. Dazu vier neue Regeln im
Prüfskript, die `lib/map/` bewachen, bevor es entsteht.

**Neu und projektweit nützlich:** `test/support/app_fonts.dart` lädt die echten
Schriften in Widget-Tests. Ohne das zeichnet `flutter test` jede Glyphe als
Quadrat der Schriftgröße, und **jede Layout-Zusicherung misst ein Layout, das
es auf keinem Gerät gibt**. Zum Größenvergleich: „FACT" in Nunito Black 64
belegt 166 Pixel, mit der Ersatzschrift 256. Aufruf nur aus `setUpAll`, im
Rumpf von `testWidgets` hängt er. Dazu `lib/core/async/detached_work.dart` mit
`reportDetached`, weil `docs/engineering/flutter.md:151` für abgekoppelte
Arbeit nicht nur einen Helfer, sondern auch eine Fehlermeldung verlangt.

**Stand der optischen Prüfung:** Startbildschirm, Anmeldung und Registrierung
sind am Emulator gesehen (Pixel 8, 411 logische Pixel, Systemschriftgröße 1.0).
Ungeprüft bleiben iOS, echte Hardware, andere Bildschirmbreiten und große
Systemschrift. Alle Aussagen zu 360 und 320 Pixeln und zu Skalierung 2.0 sind
strukturell.

**Der Build-Blocker ist seit dem 27.08.2026 gelöst**, siehe „Android-Build:
gelöst" unter „Rechner einrichten". Es war nie ein Netzwerkproblem: Java legt
für `Selector.open()` einen Unix-Domain-Socket im Temp-Verzeichnis an, und
AF_UNIX ist auf diesem Rechner unter `AppData` nicht verbindbar. Die Umgehung
ist eine Umgebungsvariable, siehe dort. Der erste Gerätebuild ist am selben Tag
gelaufen.

---

## Als Nächstes

1. **Den Gerätelauf nachholen, und er ist dringender geworden.** Steht seit
   E-38 aus, offen sind Splash, Anmeldung, Registrierung und das Tutorial.
   Dazu kommt jetzt die Karte, und von ihrer SDK-Verdrahtung ist **nichts**
   auf einem Gerät gesehen: `onMapCreated`, `onCameraMove` und `onCameraIdle`
   laufen im Widget-Test nie, weil ohne Plattformkanal gar kein Controller
   entsteht. Zugesichert ist nur, dass sie richtig und stabil übergeben
   werden. Zwei offene Messungen gleich mitnehmen: ob `moveCamera` eine
   laufende `animateCamera` verwirft (davon hängt Vorrangregel 1 ab, denn
   `stop()` gibt es nicht), und ob die 200 ms `steeringGrace` tragen.
2. **Schritt 13, Kamera-Verhalten, und er ist blockiert.** Der Regelkreis
   steht, `geolocator` liegt im `pubspec`, es fehlen nur die Absichten:
   GPS-Folgen, Sky-Fall, Neuzentrieren. Blockiert ist er an **einer** Frage,
   und die geht an Dairen: **wem gehört die Nutzerposition?** Das ist die
   dritte Instanz derselben Geo-Typ-Sperre nach `FactCoordinates` und
   `MapPosition`, und diesmal trifft sie mit E-07 eine Sicherheitsprüfung.
   Wer sie mit `MapPosition` beantwortet, gibt dem Karten-Host den
   Aufenthaltsort des Nutzers.
   Nicht blockierend, aber vorher zu beantworten: ob der Host im
   **unsichtbaren Tab** weiterfolgen soll. Der Tabwechsel entsorgt ihn nicht,
   das ist gemessen; die PWA kennt keine Tabs, es gibt also keine Quelle.
3. **Fünf Kartenanker warten auf ihre Anmeldung.** `DiscoveryAnchors` listet
   `balloon`, `user-marker`, `coins`, `mode-tour`, `compass` bereits als
   Kennungen. Sobald die Kartenwidgets entstehen, hüllt sie `AnchorTarget` ein
   und die fünf degradierenden Tutorial-Schritte werden voll baubar, ohne dass
   `lib/app/onboarding/` sich ändert.
4. **E-28, Lautstärke-Hinweis im Audio-Dialog.** Nur noch Wortlaut, die
   technische Sperre ist seit E-39 weg. Vorschlag DE/EN liegt in
   `REBUILD_STATUS.md` bei E-28, hergeleitet und nicht freigegeben.

---

## Protokoll

Neueste zuerst. Ein Eintrag je abgeschlossenem Schritt oder größerem Block.

### 29.08.2026, E-40: Materials Zeilenhöhe raus, wie E-38 eine Ebene tiefer

Die Suche nach der Ursache im Tutorial führte auf einen app-weiten Fehler.
**46 Absätze** erbten `height: 1.43` aus Materials `bodyMedium`, dazu
**sieben Eingabefelder** ein `height: 1.5` aus `bodyLarge`, einer zweiten
Quelle, die niemand auf dem Zettel hatte. `styles.css` enthält `line-height`
**null Mal**; die PWA setzt sie ausschließlich inline, 40 Mal über vier
Bildschirme. Wo sie keine setzt, rendert der Browser mit den Schriftmetriken.

Behoben an derselben Stelle wie E-38, in `ThemeData.typography`, weil der Wert
dort und nicht im `textTheme` sitzt, das `FactTheme` zusammenbaut. Für jeden
der 46 Absätze wurde die Quelle nachgeschlagen: nirgends steht dort eine
Zeilenhöhe, und jeder Text, für den die Quelle eine angibt, trug sie vorher
wie nachher.

**Der lehrreichste Fund des Abends ist aber der Testrahmen.**
`map_top_chrome_test.dart` pumpte ein nacktes `MaterialApp` **ohne**
`FactTheme` und **ohne** `Material`. Dort erbten die Chrome-Texte Flutters
`_errorTextStyle` aus `WidgetsApp`, und der trägt `height: null`. Der Test hat
die Maße also die ganze Zeit **richtig** gemessen, während die App sie falsch
zeichnete: **die Zahlen waren belegt, grün und trotzdem nicht das, was der
Nutzer sah.** Ein Testrahmen, der die Vorfahrenkette der App nicht abbildet,
kann über die falsche Sache recht haben. Der Rahmen steht jetzt auf
`FactTheme.light()` plus `Material`, und keine einzige Maßzahl hat sich
dadurch geändert.

Zweiter Fund derselben Sorte: `SelectableText` und `EditableText` tauchen in
`find.byType(RichText)` **gar nicht** auf. Wer Textstile über Finder einsammelt
statt über einen Durchlauf des Renderbaums, übersieht jedes Eingabefeld. So ist
die zweite Quelle `bodyLarge` bis heute unbemerkt geblieben.

Sichtbar wird es als ein bis drei Pixel je Bauteil: Eingabefelder 83 → 80,
Stadt-Pille 52 → 51, Modus-Umschalter 43 → 42. **Am deutlichsten bei doppelter
Systemschrift**, dort schrumpfen die Fremdanmeldungs-Knöpfe von 104 auf 100,
und auf einem 360er Gerät sind vier Pixel im knappen Formular ein Unterschied.

### 29.08.2026, Der Stil einmal wirklich gesehen, und zwei Fehler dabei gefunden

Nach Schritt 12 lief zum ersten Mal ein Gerätebuild **mit verdrahteter Karte**.
Das war nicht selbstverständlich: `maplibre_gl` ist ab diesem Commit zum ersten
Mal in `lib/` wirklich importiert, und genau dieses Paket hat im Juli den
Android-Build zerlegt. Er läuft, Exit-Code 0.

**Er liefert aber eine Warnung, die eine Zeitbombe ist:** „Your app uses the
following plugins that apply Kotlin Gradle Plugin (KGP): maplibre_gl. **Future
versions of Flutter will fail to build**". Das ist dieselbe Bruchstelle wie im
Juli, von der anderen Seite: `0.27.0` verlangt `android.builtInKotlin=true`,
`app_links` verlangt `false`, und `0.26.2` wendet KGP an. Ein Flutter-Update
bricht den Build absehbar, nicht diffus.

**Die Karte selbst ist am Emulator gesehen**, über eine Wegwerf-Probe, die nur
die Kartenfläche mountet, ohne Supabase und ohne Anmeldung. Der gebackene Stil
trifft: grüne Grundfläche, sattere Parks, fast weiße Fahrbahnen mit sandfarbenem
Saum, flache Klötzchen-Häuser mit Umriss, keine einzige Beschriftung. Der
**Attributions-Knopf** unten rechts ist da und lässt sich mit
`maplibre_gl 0.26.2` nicht abschalten.

**Der Gerätelauf der App selbst bleibt blockiert**, und zwar nicht technisch:
URL und Schlüssel für Supabase kommen über `--dart-define` und stehen bewusst
nicht im Repository. Ohne sie zeigt die App die Startfehler-Seite.

**Und genau die hat den Fehler offenbart.** Ihr Text trug **gelbe
Doppellinien**, die dritte der drei Fallen dieser Woche. `MaterialApp(home:
ColoredBox(...))` hat keinen Material-Vorfahren, und beide Textstile setzen
Farbe und Größe, aber keine `decoration`, also überlebt die der Ersatzschrift
den Merge. Kein Test hat es gefunden, weil `takeException()` leer bleibt: es
ist kein Fehler, es ist Flutters absichtlich grelle Ersatzschrift.

Der Rundgang danach fand **eine zweite Stelle, und die ist für Nutzer
sichtbar**: der Audio-Aktivierungsdialog. Er ist eine eigene Route im Overlay,
das `Scaffold` des Startbildschirms steht daneben und nützt ihm nichts, und
`DialogRoute` bringt selbst kein `Material` mit.

**Der Nebeneffekt der Behebung ist der eigentliche Merksatz:** ein `Material`
ohne eigenen `textStyle` vererbt `theme.textTheme.bodyMedium` an jeden Text
darunter, der es nicht selbst setzt. Wer ein `Material` einzieht, um die
Doppellinie loszuwerden, holt sich Materials Typografie ins Haus, wenn er den
Basisstil nicht ausdrücklich hinschreibt.

**Nachgemessen, und dabei hat sich eine naheliegende Annahme als falsch
erwiesen:** die **Laufweite** kommt **nicht** durch. `letterSpacing` ist unter
dem `Material` überall `null`, auch vor der Behebung. **E-38 hält**, weil sein
Eingriff in `ThemeData.typography` sitzt und `bodyMedium` deshalb schon keine
Laufweite mehr trägt, die weitergereicht werden könnte. Durchgekommen ist
ausschließlich `height: 1.43`. Wer hier „Materials Typografie" liest, muss
wissen, welcher Teil davon in dieser App noch scharf ist und welcher nicht.

### 29.08.2026, Schritt 12: MapLibre-Host mit gebackenem Stil

Die Karte ist echt. Zwei Hälften: der gebackene Stil, und der Host darunter.
1017 → 1084 Tests.

**Der wichtigste Fund ist kein Fehler, sondern eine Grenze, die zum ersten Mal
scharf geworden ist.** `map_page.dart` darf `MapSurface` **nicht**
importieren, Regel 18 bricht mit Exit-Code 1 ab, gemessen mit einer
Wegwerf-Probe. Ein Feature kann den Karten-Host also **niemals selbst
mounten**. Die Kartenfläche kommt als Widget-Parameter herein, gesetzt vom
Routen-Adapter in `app_routes.dart`, genau wie `onAudioGuidePressed` in
Schritt 8. Das gilt ab jetzt für jedes weitere Karten-Bauteil, und es ist die
Sorte Konsequenz, die man beim Entscheiden nicht sieht und beim Bauen sofort.
Bis heute war `maplibre_gl` in `lib/` an keiner Stelle importiert, die Regeln
18 und 20 waren also nie erprobt.

**Der Stil wird gebacken, und das ist erzwungen, nicht gewählt.**
`maplibre_gl 0.26.2` hat weder `setPaintProperty` noch `setLayoutProperty`.
`setLayerProperties` setzt laut eigener Doku unbelegte Eigenschaften auf den
Standard zurück, die PWA ändert aber je Layer genau eine und lässt den Rest
stehen. Nachbauen hieße, für jeden der 111 Layer den vollständigen
Eigenschaftssatz zurückzulesen und über den Plattformkanal zurückzuschieben.

**Die Falle beim Stil heißt `PLAIN_MAP_LOOK`.** `screen-map.jsx:13` steht auf
`true`, und der Kommentar darüber liest sich wie „schlichte Karte". Der
Schalter kippt aber nur vier Dinge, `applyGameStyle` läuft **unbedingt** bei
jedem `style.load`, und die rund 250 Zeilen Umfärbung gelten immer. **Und die
Häuser sind sichtbar:** eine unbedingte Liste blendet sie aus, der große
Durchlauf schaltet sie danach wieder sichtbar. Wer nur die erste Stelle liest,
backt eine Karte ohne Häuser. Nebenbei ist der Kommentar bei `:1752` veraltet
und nennt 65 oder 75 Grad, wirksam sind **58**.

**Ein Fallstrick, der auf einem Gerät funktioniert und auf dem anderen
zerstört:** `animateCamera` liefert auf Android echtes `true`/`false` über
einen Listener, auf iOS **immer sofort `null`**. Ein
`if (await animateCamera(...) != true)` wäre auf Android richtig und auf iOS
fatal, weil der Host seinen Animationszustand nie mehr löschte und danach jede
Dauerabsicht unterdrückt. Die Regel lautet jetzt: `true` und `false` löschen,
`null` heißt „keine Auskunft" und lässt stehen.

**Zwei Dinge, die eine unabhängige Prüfung vor dem Bauen verhindert hat.**
Erstens: ein Host, der seine Buchführung im `State` hält, wäre unprüfbar, denn
ohne Plattformkanal läuft `onPlatformViewCreated` nie und es entsteht **nie
ein Controller**. Zweitens: Riverpod verbietet Provider-Mutation in `initState`
**und** `dispose`, und im Release passiert es still statt zu werfen. Beides
hätte man erst gemerkt, als es teuer war. Die Registry ist deshalb ein
gewöhnliches Objekt, wie `AnchorRegistry`, und die Buchführung hängt an keinem
Widget.

**Die Typgrenze ersetzt eine Prüfregel.** Zwei Provider zeigen auf dasselbe
Objekt: Features lesen `Provider<MapHost>` und sehen kein `attach`, der Host
liest `Provider<MapHostRegistry>`. Gemessen: der Versuch bricht `dart analyze`
mit Exit-Code 3 ab. Dass die Registry selbst `MapHost` ist, erledigt nebenbei
zwei Dinge, ein Feature hält nie einen veralteten Host, und ein Abonnement auf
`cameraChanges` überlebt den Wechsel.

**Der teuerste Testfund betraf das Testnetz selbst.** `rootBundle` cacht das
`Future`. Ein Test, der den Ladevorgang anstößt, ohne ihn abzuwarten, lässt
ein totes `Future` in seiner `FakeAsync`-Zone zurück, und **jeder folgende
Test** bekam genau dieses zurück und sah eine Karte, die ewig lädt. Vier Tests
fielen mit „Bad state: No element", **ohne jede Ausnahme**. `rootBundle.clear()`
im `setUp` behebt es.

Zwei kleinere aus derselben Ecke: `LatLng` normalisiert den Längengrad
verlustbehaftet, aus 11.582 wird 11.581999999999994, also mit `closeTo`
messen. Und Methoden-Tear-offs sind `==`, aber **nicht** `identical`, ein
Test, der auf `identical` prüft, fällt gegen richtigen Code.

**Aus der unabhängigen Review danach, 25 Mutationen, 11 überlebend.** Der
teuerste Fund war wieder eine Begründung, die sich als gemessen ausgab. Das
Steuerfenster von 200 ms, in dem eine Kamerarückmeldung als eigene gilt,
verlängerte sich bei **jeder** eigenen Bewegung und verkürzte sich nie. Das
Blickrichtungs-Folgen tickt aber häufiger als alle 200 ms, also stand das
Fenster dauerhaft offen und **eine echte Zwei-Finger-Drehung rastete nie
ein**. Der Kommentar beschrieb den Preis als „verschluckt eine Drehung kurz
danach", tatsächlich war er „gar nicht mehr einrastbar".

Die Behebung ist lehrreich, weil beide naheliegenden Wege nicht tragen: auch
ein Fenster, das an den **letzten** Aufruf gebunden ist statt verlängert zu
werden, steht bei 100-ms-Ticks dauerhaft offen. **„Steuert der Host gerade"
ist als reine Zeitfrage nicht beantwortbar.** Der Host merkt sich jetzt die
Blickrichtung, die er selbst zuletzt gesetzt hat; weicht die eintreffende
darüber hinaus ab, hat kein eigener Aufruf sie verursacht.

**Ein Fund am Analyzer, der über diesen Schritt hinaus gilt:**
`@visibleForTesting` an einem **Feld** bewacht nur das Lesen. Ein
Konstruktoraufruf `MapSurface(debugCreateHost: …)` aus `lib/` lief anstandslos
durch, also genau der Missbrauch, um den es geht. Erst die Annotation am
**Konstruktorparameter** meldet ihn. Wer sich auf die Absicherung aus D-5
verlässt, muss wissen, wo sie greift und wo nicht.

**Eine Paritätslücke, die die Schritte 15 bis 18 mitbestimmt.**
`screen-map.jsx:1694` setzt `map.setPadding({ top: 320 })` und schiebt damit
den wirksamen Kartenmittelpunkt um 320 Pixel nach unten, damit die Figur im
unteren Drittel steht. **`maplibre_gl 0.26.2` hat kein dauerhaftes
Kamera-Padding.** `padding` gibt es nur an `CameraUpdate.newLatLngBounds` und
an `setCameraBounds`, und die zweite grenzt den **erlaubten Ausschnitt** ein:
wer sie dafür hält, sperrt das Schieben ein, statt die Kamera zu versetzen.
Derselbe Fundtyp wie das fehlende `setPaintProperty`, und er entscheidet, wo
Nutzermarker und Avatar landen.

**Zuletzt eine Vertragslücke, die erst in Schritt 13 aufgefallen wäre.**
`MapCameraSituation` verlangt Zustand *zu dieser* Dauerabsicht, aber
`MapCameraFollow` trug keine Identität, und nach der Herkunft zu schlüsseln
ist beweisbar falsch: GPS-Folgen und Blickrichtungs-Folgen sind beide
`discovery`. Jetzt kostete es ein Feld, in Schritt 13 wäre es eine
Vertragsänderung gewesen.

### 29.08.2026, D-5: das Karten-Chrome wird eine geschlossene Einheit

Aus zehn öffentlichen Typen in einer Datei von 1096 Zeilen wird **ein**
benutzbarer Name. Acht Hilfstypen tragen `@visibleForTesting`, zwei sind
privat. **Kein Test wurde umgeschrieben**, die Testzahl steht unverändert bei
987.

Zwei Prämissen der Frage waren falsch, und beide sind teuer, wenn man sie
glaubt:

*Die Präzedenz trägt nicht.* `tour_chrome.dart` galt als Beleg dafür, dass man
für Tests öffentlich exportiert. Stimmt nicht: seine Typen werden von
`tour_overlay.dart:210-218` im Produktivcode instanziiert, und was dort nur
intern gebraucht wird, ist privat. Die Datei ist das Gegenbeispiel.

*Die Messbarkeit hing gar nicht an den Typen.* Vier Bauteile greift die
Testdatei längst über die Anker-Registry ab und bekommt exakte Rechtecke, ohne
je einen Typ zu nennen.

**`@visibleForTesting` ist hier kein Linter-Gemecker, sondern ein Gate.**
Gemessen mit einer Wegwerf-Datei unter `lib/app/`: `dart analyze` bricht mit
**Exit-Code 2** ab. Und die Meldung nennt als erlaubten Ort
`map_top_chrome.dart`, obwohl der Typ in einer `part`-Datei darunter steht.
Das ist der Beleg, dass die Grenze die **Bibliothek** ist und nicht die Datei,
und genau darauf baut die Lösung: `_Blurred` und fünf private Konstanten
bleiben privat, obwohl vier Dateien sie benutzen. Bei einer Aufteilung in
eigene Bibliotheken hätten sie öffentlich werden müssen, aus zehn Namen wären
zwölf geworden.

Der Beweis, dass die Verschiebung rein war, steckt nicht im grünen Testlauf:
acht der neun Teildateien sind gegen ihren Original-Zeilenbereich aus
`git show HEAD:` **byte-identisch**, die neunte zeigt genau die vier Zeilen
der Umbenennung. Dazu zwei Mutationsproben, die belegen, dass die Tests die
verschobene Geometrie noch festhalten.

Eine fünfte Zeile hat der Analyzer erzwungen: nach der Umbenennung meldete
`unused_element_parameter` ein `super.key` an einer nun privaten Klasse, der
nie ein Key übergeben wurde. Ohne Entfernen wäre Gate 2 rot geblieben.

### 28.08.2026, Fundament von `lib/map/`: die Kamera als Vertrag

Fünf reine Domänenverträge unter `lib/map/domain/`, kein Flutter, kein
Riverpod, kein MapLibre, 149 Tests. Gebaut vor Schritt 12, weil der
Kameravertrag entscheidet, was der Host danach kostet.

**Der Grund, warum es diese Verträge überhaupt gibt, ist eine Messung am
Paket, und sie widerlegt drei naheliegende Annahmen auf einmal.**
`maplibre_gl 0.26.2` hat **kein `isEasing()`**, null Treffer im ganzen Paket,
und genau daran hängt Vorrangregel 3. `isCameraMoving` ist kein Ersatz,
sondern eine Falle: es wird über `onCameraMoveStarted` gesetzt und gilt für
jede Bewegung, auch fürs Ziehen mit dem Finger, während `isEasing` nur
programmgesteuerte Animation meint. Und `animateCamera` liefert laut eigener
Doku **auf iOS immer sofort `null`**, taugt also nicht zum Abwarten. Dazu drei
weitere Löcher, beim Nachsehen gefunden: **kein `stop()`** am Controller,
obwohl Vorrangregel 1 „bricht alles ab" heißt, kein `onCameraMoveStarted` als
Widget-Rückruf, und `OnCameraMoveCallback` ist `void Function(CameraPosition)`
ohne jede Ursachenangabe. Der Host muss seinen Animationszustand deshalb
selbst führen, und „der Nutzer hat angefasst" ist nur als **unerklärte
Kamerabewegung** erkennbar.

**Der teuerste Fund kam aus der unabhängigen Review, und er lag in meinem
eigenen Auftrag.** Vorrangregel 2 heißt „direkte Manipulation schlägt
Automatik". Ich hatte das auf einen Zeitpunkt reduziert, nämlich eine
Karenzzeit nach der letzten Nutzerbewegung, mit dem Argument, ein Zeitpunkt
könne beide Lesarten ausdrücken und ein `bool` nur eine. Das stimmt für das
GPS-Folgen (`screen-map.jsx:2668` prüft wirklich nur `!isEasing()`) und ist
für die zweite Dauerabsicht **falsch**: `:2837` prüft zusätzlich
`!userInteracting`, gesetzt ab `touchstart`, also **bevor** sich die Kamera
überhaupt bewegt hat. Ein Fenster nach der Bewegung sperrt am Anfang zu spät
und am Ende zu lange. Schlimmer als die Lücke war, dass der Code die
Verkürzung als quellentreu dokumentierte: **ein Fehler, der sich als belegt
ausgibt, wird nicht nachgeprüft.** Der Vertrag hat jetzt zwei Eingänge, weil
es zwei verschiedene Dinge sind.

Zweiter Fund derselben Review: `MapCameraChange` durfte zwei seiner vier
Felder aus der Gleichheit fallen lassen, ohne dass ein Test anschlug. Sein
Zwilling `MapCameraView` hatte den Test, er nicht. **Zwei Typen, gleiches
Muster, nur einer geprüft**, dasselbe wie heute früh bei Anmeldung und
Registrierung. Das ist in diesem Projekt die Stelle, an der man suchen muss.

Dritter, und der mit der längsten Reichweite: ein Animationszustand mit Start
und **ohne** geplantes Ende galt als „läuft ewig" und fror damit jede
Dauerabsicht dauerhaft ein. Genau dort landet ein Host auf iOS, wo
`animateCamera` sofort `null` liefert und die Dauer nie zurückmeldet.

Bewusst **nicht** gebaut, gegen den ursprünglichen Zuschnitt: Überlagerung und
Projektion. Ob es überhaupt eine Projektion braucht, entscheidet sich erst
daran, ob Cluster und Marker SDK-Layer werden oder Flutter-Widgets über der
Karte, und das fällt in Schritt 15 bis 18. Ein Vertrag, der davor entsteht,
rät.

Nebenbefund aus dem Testbau, ehrlich mitgeschrieben: der erste Prüfwert für
die Haversine-Strecke war **in der Richtung** falsch geraten. Ein Längengrad
auf 60° Breite ist als Großkreisstrecke nicht länger als der halbe
Meridiangrad, sondern 0,53 Meter kürzer, weil die kürzeste Linie polwärts
ausweicht. Der Test fiel, und dass er fiel, belegt, dass er gegen eine
unabhängige Herleitung prüft und nicht gegen die Implementierung.

Und eine Falle für jeden frischen Worktree: ohne `.dart_tool/` meldet
`dart analyze` „Target of URI doesn't exist" für **jede** Datei im
Repository. Erst `flutter pub get` macht die Gates aussagefähig. Wer den
ersten Lauf für ein Ergebnis hält, sucht den Fehler an der falschen Stelle.

### 28.08.2026, Schritt 11: Tutorial-Overlay, Phase 1 abgeschlossen

Neun Schritte unter `lib/app/onboarding/`, ohne eigene Route: das Overlay hängt
über der ganzen `AppShell`, ein Tipp auf einen fremden Tab-Knopf schaltet den
Tutorial-Schritt weiter statt den Zweig zu wechseln, genau wie die PWA es per
Portal mit hohem `zIndex` löst. Vier Schritte sind heute voll baubar, fünf
degradieren ohne Pfeil und Ring, weil ihre Anker auf dem noch platzhalterhaften
Kartenbildschirm liegen.

Der teuerste Fund kam nicht aus einem Layout-Test, sondern aus einem `assert`
der Anker-Registry: die naheliegende Fassung `if (shown) return child;` hätte
beim Tourende den Elterntyp der Shell wechseln lassen und damit **die ganze
Shell samt aller vier Navigationsstapel neu gebaut**. Bemerkt, weil die neue
Tab-Leiste ihre Anker anmeldete, bevor die alte entsorgt war, und die Registry
das laut meldet. Ein Sicherheitsmechanismus aus Block 1 hat damit einen Fehler
in Block 2 gefangen, für den kein Test dieser Art vorgesehen war.

Zweiter Fund, aus der unabhängigen Review danach: `TourBubble` clippte Text bei
Systemschrift 2.0 auf kleinen Geräten lautlos, weil `Stack` clippt statt einen
Überlauf zu melden. Derselbe Fehlertyp wie zweimal zuvor in dieser Woche, und
diesmal hatte der Code die richtige Lösung schon zweimal im selben Ordner
liegen, `TourHeroView` und das Testmuster aus `signup_page_test.dart`, nur bei
der Blase fehlte sie.

Vorausgegangen, am selben Tag: die Anker-Registry in `lib/core/anchors/`
(E-27), mit einem Sichtbarkeitslauf, der einen Anker in einem inaktiven
Shell-Zweig zuverlässig erkennt, obwohl `IndexedStack` allein das nicht
verrät, nur das zusätzliche `Offstage` von go_router tut es. Und eine
Ergänzungs-Map für Oberflächentexte, die die PWA anzeigt, aber nicht als
Schlüssel führt (E-39), am ersten Fall genutzt (Schrittanzeige des Tutorials)
und am zweiten (die zwei goldenen Meta-Zeilen der Hero-Schritte) noch am
selben Tag nachgezogen, wortwörtlich aus der Quelle, nichts erfunden.

**605 → 761 Tests an diesem Tag**, in sechs geprüften Blöcken: E-38, zehn
Review-Lücken aus Schritt 9/10, die Anker-Registry, die i18n-Ergänzung, das
Overlay, zwei weitere Review-Funde.

### 28.08.2026, Review der Schritte 9 und 10, zehn Lücken geschlossen

Eine unabhängige Review hat 47 Mutationen gesetzt, 13 haben die Suite überlebt.
**Kein blockierender Fund**, der Code war bis auf eine Stelle richtig. Was fehlte,
war die Zusicherung, und der teuerste Fall wäre unsichtbar geblieben: die
Anmeldung hätte E-Mail und Passwort vertauschen können, und alle 614 Tests wären
grün geblieben. Der Fake trägt `lastEmail`, aber nur der Notifier-Test las es,
nie der Seiten-Test. Die Registrierung war an derselben Stelle dicht. Zwei
Bildschirme, gleiches Muster, nur einer geprüft: **das ist die Stelle, an der man
in diesem Projekt suchen muss.**

Der eine echte Defekt kam aus einer Richtung, gegen die es hier schon einmal
einen Fund gab. Die Fremdanmeldungs-Knöpfe standen auf Flutters Standard
`center`, CSS steht auf `align-items: stretch`. Bei Systemschrift 2.0 waren sie
64 und 104 Pixel hoch. Gesehen hat es keiner der vier Skalierungstests, weil die
nur `takeException()` prüfen: **ein Umbruch ist kein Überlauf**, derselbe blinde
Fleck wie am 27.08., nur an anderer Stelle. Ein Test, der Rechtecke misst,
findet ihn sofort.

`CrossAxisAlignment.stretch` allein wirft übrigens, weil beide Bildschirme die
Zeile in ein `SingleChildScrollView` stellen und die Höhe dort unbeschränkt ist:
`BoxConstraints forces an infinite height`. Es braucht `IntrinsicHeight` darum.
Und ehrlich mitgeschrieben: tragend ist dabei das `IntrinsicHeight`, nicht das
`stretch`, weil der `Container` seinen Inhalt ohnehin zentriert. Wer nur
`stretch` entfernt, bricht heute nichts.

Zwei Wertobjekt-Tests aus Schritt 5 lagen noch in der const-Falle:
`expect(const FactId(7), const FactId(7))` prüft nichts, Dart kanonisiert beide
zu demselben Objekt. Beide Male überlebte eine Mutation, die `==` auf
`identical` reduziert. Das richtige Muster stand seit Schritt 10 in
`auth_city_test.dart:59` und war nur nicht zurückportiert.

Nebenbefund für die Werkzeugkiste: `pumpEventQueue()` hängt im Rumpf von
`testWidgets` bis zur Zeitüberschreitung, genauso wie `loadAppFonts()`.

### 28.08.2026, E-27 entschieden

Die Anker-Registry entsteht unter `lib/core/anchors/`, die Kennungen bleiben bei
der Oberfläche, die sie besitzt. Ausschlaggebend war nicht „ist das allgemein
genug für `core`", sondern die **Importrichtung**: ab Phase 2 registrieren sich
Widgets aus `features/*/presentation/`, und für die lässt `dependency-rules.md:20`
nur Application, Domain und eng abgegrenztes Core zu. Von den beiden Kandidaten
ist `core` damit der einzige legale Ort.

Wichtiger als die Entscheidung ist, was sie **nicht** absichert: Regel 11 des
Prüfskripts zerlegt nur Pfade und sieht den Dateiinhalt nie. `anchor_ids.dart`
mit Fachkennungen darin passiert das Gate und verletzt trotzdem genau das, was
E-27 verhindern soll. Umgekehrt ist `tour_anchor.dart` verboten, obwohl es
harmlos wäre, und das ist ausgerechnet der Name, den die Quelle nahelegt
(`data-tour-anchor`). Die Regel schützt hier nicht, sie täuscht Schutz vor.

Dabei fiel auf, dass die Anker-Bilanz in dieser Datei falsch war: nicht sechs
baubare und drei degradierende Schritte, sondern **vier und fünf**. Neun
Schritte, zwei ohne Anker, sieben mit, davon fünf auf dem Kartenbildschirm, der
heute ein Platzhalter ist. Nachgezählt in `screen-tour.jsx:140-169`, nicht aus
den Vorlagen übernommen.

### 27.08.2026, E-38: Materials Laufweite raus

Der Eingriff sitzt woanders, als jeder erwartet, der sich `FactTheme` ansieht.
Materials `letterSpacing` steht **nicht** in dem `textTheme`, das `_textTheme`
zusammenbaut, sondern in `ThemeData.typography`, und das `Theme`-Widget mischt
es erst beim Lokalisieren ein, als **Basis** unter dem eigenen Stil
(`theme_data.dart:1762`, `localTextGeometry.merge(baseTheme.textTheme)`). Ein
`letterSpacing: null` in `_textTheme` hätte deshalb genau den Wert
durchgelassen, den es entfernen soll. An einer Wegwerf-Probe gemessen: dort
stand schon vorher `null`, und auch `fontSize` war `null`. Der Eingriff läuft
jetzt über `typography` und erledigt `textTheme` und `primaryTextTheme` in einem.

Zweitens: alle 15 hartcodierten Laufweiten der Identity-Bildschirme sind gegen
`screen-auth.jsx` belegt und **keine einzige wurde geändert**. Verdächtig waren
0.1, 0.15 und 0.25, weil das genau die Material-2021-Werte sind. Sie stehen
trotzdem so in der Quelle, der Gleichklang ist Zufall. Wer hier pauschal
aufgeräumt hätte, hätte die Parität zerstört.

Drittens ist nur ein einziges festgenageltes Maß gefallen, und zwar aus dem
umgekehrten Grund als vermutet: bei 411 Pixeln gibt der Kopfhörer-Knopf jetzt
nicht mehr nach, weil die Zeile aufgeht. Die Regel gilt weiter, sie ist bei 411
nur nicht mehr beobachtbar. Deshalb auf 390 verlegt, das Rahmenmaß der Quelle,
mit unveränderten exakten Zusicherungen statt einer aufgeweichten Toleranz.
E-36 bleibt offen: der Fehlbetrag bei 360 schrumpft von rund 19,5 auf rund
14,7, er verschwindet nicht.

### 27.08.2026, erster Gerätelauf

Der Build-Blocker fiel, und danach lief die App zum ersten Mal. Vier Funde, die
keine Testsuite hätte finden können, und drei davon haben eine Annahme
widerlegt.

**Der Paketkonflikt war nicht die `minSdk`.** Seit Phase 0 stand in
`REBUILD_STATUS.md` die Vermutung, `maplibre_gl` könnte eine höhere `minSdk`
verlangen. Es setzt bei 21 an, völlig unkritisch. Der echte Konflikt liegt
zwischen AGP 9.0.1, das das Flutter-Template selbst wählt, und der Art, wie zwei
Pakete auf Flutters Kotlin-Umstellung reagieren. `maplibre_gl 0.27.0` braucht
`android.builtInKotlin=true`, `app_links` braucht `false`, und `app_links` ist
nicht einmal direkt eingebunden. Beide sind laut `flutter pub outdated` aktuell.
Gelöst durch Festnageln auf `^0.26.1`, Begründung in `pubspec.yaml`.

**Das Format-Gate war ab dem ersten Build kaputt.** `dart format .` stürzt in
`build/` an Pfaden jenseits der Windows-Längengrenze ab und meldet Exit-Code 1,
ohne dass am Code etwas falsch ist. Bis zu diesem Tag fiel das nicht auf, weil
`build/` nie existierte. Das Gate zielt jetzt auf `lib test tool`.

**Die Sprachzeile brach um, und mein Verdacht war falsch.** Sichtbar stand
„Deutsch" als „Deutsc / h". Ich hatte die Deckelung des Kopfhörer-Knopfes auf
115 Pixel verdächtigt; die band bei Skalierung 1.0 nie. Die Ursache ist `Row`
mit `Expanded`, das die Breite verteilt, bevor es die Kinder nach ihrem Bedarf
fragt. Gemessen: eine Karte braucht 127,1 Pixel min-content, verfügbar waren
118. Der Defekt trat damit auch bei 390 auf, dem Rahmenmaß der Quelle.

**Und der Fund mit der größten Reichweite ist einer am Testnetz:** die Tests
prüfen auf **Überlauf**, und ein Zeilenumbruch ist keiner. Flutter meldet
nichts, es bricht einfach um. Es gab Tests für genau diese Zeile, und sie waren
blind. Jetzt ist die Einzeiligkeit zugesichert. Dasselbe Muster beim nativen
Startbildschirm: eine Mutationsprobe hat belegt, dass XML für `flutter test`
vollständig unsichtbar ist, die Farbe auf Weiß zu setzen überlebte alle vier
Gates. Dafür gibt es jetzt Dateiprüfungen.

Nebenbefunde, jeder eine Zeile wert. Der wirksame native Startbildschirm ist
`drawable-v21/`, nicht `drawable/`, und `NormalTheme` wiegt schwerer als
`LaunchTheme`, weil `FlutterActivity` in `onCreate` darauf umstellt. Der
Emulator hatte 2 GB und schoss die App per `lowmemorykiller` ab, jetzt 4 GB.
Und zweimal habe ich mir selbst falsche Ergebnisse gebaut, indem ich Auswertung
und Ausgabe in eine `&&`-Kette gemischt habe: einmal kam ein Exit-Code 0 von
`tail`, während der Build mit 1 abbrach, einmal lief ein Build gar nicht, weil
ein vorgeschaltetes `grep` die Kette abbrach. Die Warnung in „Befehle" gilt
nicht nur für die Gates.

### 27.08.2026, Schritt 9: Anmeldung mit Auth-Unterbau

Vertrag in `identity/domain/repositories/`, Supabase-Anbindung in `data/`,
Sitzungszustand und Bildschirm in `presentation/`. 463 Tests.

Der Kern war keine Zeichenaufgabe, sondern eine Verdrahtungsfrage:
**`presentation` darf `data` nicht importieren**, ein Anmeldeformular braucht
aber Supabase. Der Weg, der alle neun Prüfungen erfüllt: ein Provider, der auf
den **Domänenvertrag** typisiert ist, mit einem untätigen Standard, und die
Implementierung kommt per Override aus `bootstrap.dart`. Der Standard fällt zur
sicheren Seite aus, er kann keinen angemeldeten Nutzer erfinden, und
`flutter test` läuft weiter ohne `--dart-define`.

Überraschend war viererlei. Erstens hätte die naheliegende Lösung an Regel 7
gescheitert: das Prüfskript meldet in `presentation` jeden Konstruktoraufruf
einer Klasse, deren Name auf `Repository`, `DataSource` oder `Client` endet. Ein
`const UnavailableAuthRepository()` im Provider wäre ein Verstoß. Die drei
bestehenden Store-Provider überleben die Prüfung nur, weil ihre Klassen auf
`Store` enden. Gelöst über einen kleingeschriebenen `const`-Wert im Vertrag,
vorher mit zwei Wegwerf-Proben belegt.

Zweitens ist `Override` aus `flutter_riverpod 3.4.2` **nicht exportiert**, eine
Funktion `List<Override> productionOverrides()` ist nicht schreibbar. Die
benannte, testbare Funktion gibt deshalb die `ProviderScope` selbst zurück.

Drittens der teuerste Testfehler dieser Sitzung: eine Mutation von
`AuthSession.==` auf Identität **überlebte** die Suite. Ursache ist Darts
`const`-Kanonisierung. Zwei gleich geschriebene `const AuthSession.signedIn(...)`
sind dasselbe Objekt, der Gleichheitstest prüfte also nichts, und mit ihm der
Test gegen das Erneuerungs-Gewitter im Router. Echte Sitzungen entstehen zur
Laufzeit und sind nicht konstant. Nach der Korrektur fällt die Mutation an fünf
Stellen.

Viertens ist der Passwort-Reset **nicht angeboten**, und der Grund ist neu:
`supabase_flutter` fährt standardmäßig PKCE, und `resetPasswordForEmail` legt
den Code-Verifier auf dem Gerät ab. Der Link ginge an die Site-URL, also in die
PWA, die den Verifier nicht hat. Eine Mail zu schicken, deren Link niemand
einlösen kann, ist schlechter als kein Angebot. Zurücksetzen läuft bis auf
Weiteres über die PWA.

Nebenbefund: `FactButton` kann **nicht** nach `core/widgets` umziehen, wie sein
eigener Kommentar vorschlägt. Regel 11 zerlegt den Pfad und meldet, dass `core`
das Konzept `fact` nicht besitzen darf. Nachgewiesen, nicht vermutet.

### 27.08.2026, Schritt 8: Audio-Aktivierungsdialog

Der 🎧-Knopf des Startbildschirms öffnet ihn, „Aktivieren" setzt eine
Präferenz, „Abbrechen" schließt nur. 384 Tests.

**Wichtig zur Erwartung:** der Dialog setzt eine Präferenz, die **nichts
bewirkt**. Es gibt keine Wiedergabe und keine Sprachausgabe, die sie liest.
Nicht gebaut, jeweils dokumentiert statt implementiert: die
iOS-DeviceMotion-Berechtigung, die gesprochene Hilfe (`announceHelp`, gehört zu
Schritt 25 und der offenen Entscheidung E-15) und `fact_audio_help_shown`, das
ohne die Hilfe keinen Konsumenten hat.

Überraschend war viererlei. Erstens verlangte die Aufgabe eine echte
Architekturentscheidung statt Zeichnen: der Bildschirm gehört `identity`, die
Audio-Präferenz laut `lib/features/README.md:22` aber `settings`, und Regel 8
der Dependency-Rules verbietet den direkten Import. Der Ausweg steht in Regel
10, „an app-level composition adapter": `SplashRoute.build` setzt die Aktion
ein, `identity` erfährt nichts von `settings`.

Zweitens rendern die beiden Dialog-Knöpfe in der PWA in der
**Browser-Standardschrift**. Ein `<button>` erbt `font-family` nicht, und
`styles.css` holt das nur für `.tab-pill button` nach, während jeder andere
Knopf der App Nunito ausdrücklich setzt. Hier ist Nunito 14 gewählt, also die
Absicht statt des sichtbaren Zustands. Nebenwirkung, die dazugehört: Arial
kennt kein Gewicht 900, in der PWA sehen beide Knöpfe gleich fett aus, im
Nachbau nicht.

Drittens, und das ist der Fund mit der größten Reichweite: **`flutter test`
lädt keine Schriften.** Jede Glyphe ist ein Quadrat der Schriftgröße, „FACT"
belegt dort 256 statt 166 Pixel. Alle Layout-Zusicherungen der Schritte 7 und 8
haben damit ein Layout geprüft, das es nicht gibt, und die Knopfzeile des
Dialogs lief schon bei Skalierung 1.0 um. Behoben mit
`test/support/app_fonts.dart`. Aufruf nur aus `setUpAll`: im Rumpf von
`testWidgets` hängt `FontLoader`, weil dort eine `FakeAsync`-Zone läuft, in der
echte Datei-Ein-/Ausgabe nie fortschreitet.

Viertens fielen mit echten Schriften zwei **echte** Überläufe auf, beide in
Schritt 7 und beide bei doppelter Systemschrift, also innerhalb von Androids
Maximum: die Wortmarke um 65 Pixel und die Sprachzeile um 3,8 Pixel. Die
Wortmarke skaliert jetzt bewusst nicht mit (CSS-`px` folgt der
Betriebssystem-Textgröße nicht, und eine feste Kachel neben einem mitwachsenden
Schriftzug wäre ein halb skaliertes Logo), der Kopfhörer-Knopf ist auf 115
Pixel gedeckelt. Ein `LayoutBuilder` wäre dort der naheliegende Weg und ist
unmöglich: die Inhaltsspalte liegt in einem `IntrinsicHeight`, und der bricht
mit `LayoutBuilder does not support returning intrinsic dimensions`.

### 27.08.2026, Schritt 7: Startbildschirm und Router-Weiche

`/splash` außerhalb der Shell, dazu `route_guards.dart` mit der Weiche als
reiner Funktion und `FirstLaunchStore` nach dem Muster des Sprach-Speichers.
Login und Signup existieren als Platzhalter, damit die drei Ausgänge ein Ziel
haben. 348 Tests.

Überraschend war fünferlei. Erstens ist der Splash **kein Ladebildschirm**: der
zeitgesteuerte Boot-Splash der PWA wurde am 06.06.2026 in Commit `83be52f`
absichtlich entfernt, das Skript in `index.html:222-245` beginnt mit
`if (!splash) return` und ist toter Code. Die Zahlen 1200 ms und 15000 ms, die
in den Vorlagen stehen, gehören zu diesem toten Pfad. Was „SplashScreen" heißt,
ist ein interaktiver Bildschirm mit drei gleichrangigen Ausgängen, darunter ein
Gastmodus, der in beiden Vorlagen fehlt.

Zweitens ist `slideUp` **zweimal** definiert, in `styles.css:251` mit
`translateY(100%)` und in `index.html:25` mit 24 Pixeln plus Deckkraft. Der
Inline-Block steht nach dem Stylesheet, bei gleichnamigen `@keyframes` gewinnt
die letzte Definition. Wer nur das Stylesheet liest, baut das Falsche.

Drittens ist `onboarding.quote` ein **toter Schlüssel**: er existiert, wird in
der PWA nirgends benutzt und weicht im Text ab (»…« statt „…", plus
„(vermutlich)"). Für das sichtbare Goethe-Zitat gibt es also keinen Schlüssel,
und Invariante 4 („kein Text hartcodieren") hat hier keine Quelle.

Viertens, und das ist die teuerste Falle: eine eigene `MediaQuery` um `FactApp`
in einem Widget-Test **verdeckt die echte**. `pumpWidget` steckt das Widget in
ein `View`, und erst dieses legt `MediaQuery.fromView` an. Die eigene sitzt
darunter, `size` und `padding` fallen auf Null, und jede Layout-Zusicherung ist
lautlos wertlos. Der richtige Weg ist
`tester.platformDispatcher.accessibilityFeaturesTestValue`. Gemessen, nicht
vermutet: 141 statt 0 als `view.padding.top`.

Fünftens hat die Safe Area andersherum gelegen als angenommen.
`index.html:101-107` setzt `env(safe-area-inset-*)` als `padding` an den
**`body`**, die PWA rückt also den ganzen Bildschirm samt Verlauf und Pins ein.
Eine `SafeArea` nur um die Inhaltsspalte hätte die Wortmarke richtig und die
fünf Pins um die Notch-Höhe zu hoch gesetzt. Die unabhängige Review hat das
gefunden, nachdem die erste Vorgabe das Gegenteil verlangte.

Nebenbefund zur Arbeitsweise: die Review hat drei Mutationen gefunden, die die
Suite überlebten, darunter „der Knopf Anmelden öffnet die Registrierung". Die
Tests sahen vollständig aus und waren es nicht. Mutationsproben sind der
einzige Weg, das zu merken.

### 26.08.2026, Schritt 6: App-Shell, Phase 0 abgeschlossen

Vier Tabs, aus `chrome.jsx:55-60` belegt statt geraten. `StatefulShellRoute`
für unabhängige Stapel, typisierte Routen über `go_router_builder`, also
erstmals Codegen.

Überraschend war dreierlei. Erstens rechnet der alte Port den Bodenabstand der
Leiste als Summe aus 14 und der Safe Area, die Quelle nimmt das Maximum, und
er setzt die Unschärfe auf 18 statt der 24 aus `chrome.jsx:78`. Beides nicht
übernommen. Zweitens zählt `Container` die Rahmenstärke zum Innenabstand,
`DecoratedBox` nicht, was den ersten Höhentest bei 76 statt 78 scheitern ließ.
Drittens schließt `analysis_options.yaml` alle `*.g.dart` aus: der Analyzer
ist für die erzeugte Routendatei blind, ein Fehler dort fällt erst beim
Kompilieren auf. Gemessen mit einer absichtlich fehlerhaften Probedatei, nicht
vermutet.

### 26.08.2026, Nachbesserungen am Fundament

Nunito 600 fehlte, wird von der PWA aber für die Tab-Leiste genutzt. Google
Fonts liefert keine statische Instanz mehr, deshalb mit `fontTools` bei
`wght=600` aus der variablen Schrift herausgeschnitten.
`always_use_package_imports` aktiviert, damit relative
Cross-Feature-Importe nicht entstehen können.

### 26.08.2026, Schritt 5: Fakt-Datenmodell und Supabase

Fehler-Isolation durch Konstruktion: kein `as`-Cast auf Rohwerte, jeder
Datensatz einzeln abgebildet, Ausfälle in einem zählbaren Bericht. Das
Rätsel-Mapping übernimmt 21 Felder statt der vier, an denen der alte Port
gescheitert ist. Vier Spalten gefunden, die im eingecheckten Schema fehlen,
aber existieren.

### 26.08.2026, Schritt 4: i18n

716 Schlüssel je Sprache, aus der PWA generiert. Die Zahl 763 in Parity-Spec
und REBUILD_PLAN ist falsch, das ist der Bestand des alten Flutter-Ports.

### 26.08.2026, Schritt 3: Design-Tokens

31 Farb-Tokens aus `styles.css`, per Test festgenagelt. Drei Alias-Paare
getrennt, die `.theme-light` nur halbseitig überschreibt.

### 26.08.2026, Architektur-Prüfskript

`tool/check_architecture.dart` mit den neun Prüfungen aus den Quality-Gates,
53 Black-Box-Tests. Ersatz für `riverpod_lint`, das mit diesem
Abhängigkeitsstand nicht auflösbar ist.

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
**nicht** auf dem PATH. `C:\flutter` ist dort kaputt. Auf einem anderen
Rechner gilt das nicht: nimm deinen eigenen Pfad und ersetze ihn in allen
Befehlen unten.

Geprüft mit **Flutter 3.44.1 / Dart 3.12.1**.

Bevorzuge `dart analyze` gegenüber `flutter analyze`, weil das Flutter-Werkzeug
auf diesem System gelegentlich hängt.

### Pfad zur PWA

Der i18n-Generator liest die Quelltexte aus der PWA. Der Standardpfad im
Skript zeigt auf ein OneDrive-Verzeichnis des ursprünglichen Rechners. Auf
einem anderen Rechner brauchst du:

```
dart run tool/generate_i18n.dart --source <pfad-zu>/02_Frontend/app
```

oder die Umgebungsvariable `FACT_PWA_APP_DIR`. Ohne einen davon bricht das
Skript mit Exit-Code 2 und einer Anleitung ab.

**Ohne PWA-Zugang kann man trotzdem arbeiten.** Die erzeugten Sprachdateien
sind versioniert, der Generator ist nur nötig, wenn sich die PWA-Texte
ändern.

### Supabase

URL und publizierbarer Schlüssel kommen über `--dart-define`, es steht kein
Wert im Repository:

```
flutter run --dart-define=SUPABASE_URL=https://<projekt>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_<rest>
```

Gilt genauso für `flutter build apk`, `flutter build ipa` und `flutter test`.
Alternativ `--dart-define-from-file=env.json`, diese Datei gehört **nicht** ins
Repository.

### Android-Build: gelöst am 27.08.2026

**Ursache: `Selector.open()` scheitert, weil Java dafür einen Unix-Domain-Socket
im Temp-Verzeichnis anlegt, und AF_UNIX auf diesem Rechner unter `AppData`
nicht verbindbar ist.**

Die Fehlermeldung war die ganze Zeit irreführend. Sie lautet „Unable to
establish loopback connection", und alle Verdächtigen, die man daraufhin prüft,
liegen im Netzwerk-Stack. Der scheiternde Vorgang ist aber **kein
Netzwerkaufruf**, sondern ein Verbindungsaufbau auf eine **Datei**.

Der Weg dorthin, aus den JDK-Quellen (`lib/src.zip` von Temurin):

```
WEPollSelectorImpl.java:79   new PipeImpl(sp, /* AF_UNIX */ true, /*buffering*/ false)
PipeImpl.java:127            createListener(preferUnixDomain)
PipeImpl.java:132            SocketChannel.open(sa)      // sa ist eine UnixDomainSocketAddress
```

`Pipe.open()` ruft denselben Konstruktor mit `false` und geht über TCP, deshalb
**gelingt `Pipe.open()` und scheitert `Selector.open()`**. Wer die beiden
verwechselt, schließt aus einem erfolgreichen `Pipe.open()`, Java sei in Ordnung,
und sucht danach an der falschen Stelle. Genau das ist hier zwei Tage passiert.

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
Ordnerschutz von Defender.

**Warum es früher funktionierte:** vermutlich hat sich die Bedingung unter
`AppData` geändert, nicht Java und nicht Gradle. Der eigentliche Systemdefekt
ist damit nicht behoben, nur umgangen.

#### Die Umgehung

Eine Benutzer-Umgebungsvariable, keine Administratorrechte nötig:

```
[Environment]::SetEnvironmentVariable('JAVA_TOOL_OPTIONS', '-Djdk.net.unixdomain.tmpdir=C:\gtmp', 'User')
```

Wirkt in jedem **neu gestarteten** Programm, also auch in Android Studio.
Bestehende Terminals neu öffnen. Jede JVM gibt danach die Zeile
`Picked up JAVA_TOOL_OPTIONS: ...` auf der Fehlerausgabe aus, das ist normal.

Belegt am leeren Testprojekt unter `C:\gtmp\gt`:

```
ohne die Variable : EXIT=1  java.io.IOException: Unable to establish loopback connection
mit der Variable  : EXIT=0  BUILD SUCCESSFUL in 5s
```

Das Verzeichnis `C:\gtmp` muss existieren. Jeder Pfad außerhalb von `AppData`
geht.

#### Die Prüfschleife: eine Sekunde statt eines Builds

Als `SelectorProbe.java` ablegen, mit `java SelectorProbe.java` starten
(Quelldatei-Modus, kein `javac` nötig). Liegt unter `C:\gtmp\SelectorProbe.java`.

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

#### Was vorher ausgeschlossen wurde, und die Lehre daraus

Diese Liste ist Geschichte, nicht Arbeitsvorrat. Sie steht hier, weil sie zeigt,
wie teuer eine irreführende Fehlermeldung wird: **vierzehn Vermutungen, jede
einzeln gemessen, alle im Netzwerk-Stack, alle richtig ausgeschlossen und alle
am falschen Objekt.**

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
treffen, und das Netz funktioniert. Drei Löschversuche über die WFP-Schnittstelle
scheiterten ohnehin an `ERROR_NOT_SUPPORTED`, es wurde also nichts verändert.

Die Lehre: **den Aufrufweg lesen, bevor man der Fehlermeldung glaubt.** Die
vollständige Stapelspur (`--stacktrace`) und dreißig Zeilen JDK-Quelle haben
gelöst, was vierzehn Systemmessungen nicht gelöst haben.


### Nicht aus einem OneDrive-Pfad bauen

Der AOT-Compiler bricht an Nicht-ASCII-Verzeichnisnamen. Dieses Repository
liegt deshalb unter `C:\dev\flutter-fact`. Wenn du es woanders klonst, nimm
einen kurzen ASCII-Pfad.

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
`build/`, und darin liegen Gradle-Zwischenprodukte mit Pfaden jenseits der
Windows-Längengrenze. `dart format .` stürzt dort mit
`PathNotFoundException: Directory listing failed` ab und liefert Exit-Code 1,
ohne dass am Quellcode etwas falsch ist. Vor dem 27.08.2026 fiel das nicht auf,
weil `build/` nie existierte. `build/` und `.dart_tool/` stehen in
`.gitignore`, das Gate soll sie also ohnehin nicht ansehen.

**Hänge kein `| tail` an einen dieser Befehle, wenn du den Exit-Code
auswertest.** Die Pipe maskiert ihn, und genau dadurch wurde hier schon ein
rotes Gate stillschweigend durchgewinkt.

Es gibt **keinen CI-Workflow**. Diese vier Befehle laufen nur, wenn jemand sie
startet.

### Generierten Code neu erzeugen

```
dart run build_runner build
dart run tool/generate_i18n.dart
```

`--delete-conflicting-outputs` gibt es in `build_runner` 2.15.1 nicht mehr, das
Flag wird nur mit einer Warnung ignoriert.

Erzeugte Dateien **sind versioniert**, `*.g.dart` steht nicht in
`.gitignore`. Grund: ADR-004 verlangt generierte typisierte Routen, und ohne
CI, die vorher `build_runner` ausführt, ließe sich ein frischer Klon nicht
kompilieren. Das ist eine bewusste Entscheidung, nachzulesen im Kommentar in
`.gitignore`.

### Drift der erzeugten Dateien prüfen

Zwei Werkzeuge, beide mit `--check`, beide müssen auf 0 stehen:

```
dart run tool/generate_i18n.dart --check
dart run tool/bake_map_style.dart --check
```

Das zweite gibt es seit Schritt 12: der Kartenstil wird **gebacken**, nicht zur
Laufzeit umgefärbt. Der Grund ist gemessen und nicht gewählt. `maplibre_gl
0.26.2` hat weder `setPaintProperty` noch `setLayoutProperty`; was es hat, ist
`setLayerProperties`, und dessen eigene Doku sagt, dass unbelegte
Eigenschaften auf den Standard zurückfallen. Die PWA ändert je Layer genau
eine Eigenschaft und lässt den Rest stehen. Das nachzubauen hieße, für jeden
der 111 Layer den vollständigen Eigenschaftssatz zurückzulesen und über den
Plattformkanal zurückzuschieben.

Der Ausgangsstil ist deshalb eingecheckt (`tool/map_style/liberty_upstream.json`)
und wird **nicht** bei jedem Lauf aus dem Netz geholt. Ein Werkzeug, das lädt,
erzeugt still bei jedem Lauf ein anderes Ergebnis, und niemand sieht, wann sich
der Anbieter geändert hat.

---

## Was man wissen muss, bevor man Code anfasst

Die vier Punkte, die am häufigsten falsch gemacht werden.

**1. Der REBUILD_PLAN im Lese-Repo gibt die Reihenfolge vor, nicht die
Architektur.** Sein Grundprinzip 4 nennt `provider` und ein globales
`AppState`. Das widerspricht ADR-003 und ADR-005 und gilt hier nicht. Drei
weitere nachgewiesene Sachfehler des Plans stehen in `REBUILD_STATUS.md`.

**2. Die Domäne darf fast nichts importieren.** Erlaubt sind nur
`dart:`-Importe und Dateien der eigenen Feature-Domäne. Kein Flutter, kein
Riverpod, kein Supabase, kein Routing, auch **kein `core`**. Das prüft
`tool/check_architecture.dart` maschinell über eine Erlaubnisliste, die derzeit
leer ist.

**3. Navigation nur über typisierte Routen.** Route-Strings gibt es
ausschließlich in `lib/app/routing/`. Zum Schließen `context.pop()`, nicht
`Navigator.pop(context)`. Der Prüfer meldet jeden `Navigator.`-Aufruf außerhalb
des Routing-Verzeichnisses.

**4. Kein Text hartcodieren.** Alle Beschriftungen kommen über `AppStrings`
aus den generierten Sprachdateien. Werte für Farben, Größen und Abstände
kommen aus der PWA, nicht aus dem alten Flutter-Port, der an mehreren Stellen
weggedriftet ist.

---

## Arbeitsweise mit Claude

Bewährt hat sich, was nicht im Code steht und deshalb hier festgehalten wird.

**Zwei Entscheidungswege, und sie werden nicht vermischt.** Janek ist Product
Owner, hat die App gebaut und sich alles ausgedacht: Design, Schriften,
Features, Namen, Aufbau, Inhalt gehen an ihn und dürfen jederzeit direkt
gefragt werden. **Technische Fragen, vor allem Architekturfragen, gehen an
Dairen**, werden aber **gesammelt** und am Anfang oder Ende einer Sitzung als
Block ausgegeben, ausdrücklich als Fragen an Dairen gekennzeichnet.

Der Grund steht nicht im Code: Janek muss für jede Dairen-Frage eine WhatsApp
schicken, jede einzelne verzögert den Prozess spürbar. Deshalb gilt beides
zugleich. Kleinkram wird **nicht** eskaliert, sondern selbst entschieden und
dokumentiert. Was das Ergebnis wirklich prägt, darf umgekehrt nicht
unterschlagen werden, nur weil Fragen unbequem sind.

**Grün heißt hochladen.** Angewiesen am 28.08.2026, ersetzt die frühere Regel
„pushen nur mit Freigabe": sind die Gates gelaufen und grün und steht keine
wichtige Frage offen, wird committet, nach `main` gemerged und gepusht, ohne
zu fragen. Die Bedingung ist wörtlich zu nehmen: **gelaufen**, nicht vermutet.
Ein Gate, dessen Exit-Code niemand angesehen hat, zählt nicht, und eine offene
Entscheidung, die den Stand prägt, ist ein Grund zu warten.

**Gefundene Fehler werden behoben, nicht mitportiert.** Angewiesen am
28.08.2026: wer beim Bauen einen Fehler im bestehenden System findet, behebt
ihn, und zwar **bevor** der nächste Schritt beginnt. Ein Fehler, der bewusst
nachgebaut wird, ist ab jetzt die begründungspflichtige Ausnahme, nicht der
Normalfall.

Zwei Abgrenzungen gehören dazu, sonst wird die Anweisung falsch angewendet:

*Nicht jede Abweichung von der Erwartung ist ein Fehler.* Die PWA ist die
Verhaltensquelle. Wo sie etwas absichtlich anders macht, ist das Parität und
kein Defekt. Der Unterschied ist nachweisbar: ein Defekt ist etwas, das der
Quelle selbst schadet und das niemand so gewollt hat, wie das unlösbare
Kompass-Rätsel auf Englisch (E-08) oder ein Kästchen, das nichts tut (E-33).

*Manche Fehler liegen nicht hier.* Die drei Sicherheitslücken im geteilten
Supabase und die Fehler der PWA selbst liegen im anderen Repository, und
`CLAUDE.md` verbietet, es von hier aus zu ändern. Dort heißt "beheben":
belegen, Migration oder Auftrag schreiben, übergeben. Siehe
`docs/operations/backend-security-fixes.md`.

*Ändert eine Behebung, was der Nutzer sieht*, wird sie trotzdem gemacht, aber
Janek erfährt davon. Er ist Product Owner, und eine stillschweigende
Verhaltensänderung ist auch dann eine Überraschung, wenn sie richtig ist.

**Spezialisten arbeiten, die Hauptsitzung orchestriert.** Die Agenten aus
`.claude/agents/` erledigen die Umsetzung, die Hauptsitzung schreibt die
Aufträge, entscheidet und führt widersprüchliche Ergebnisse zusammen. Das
Auftragsformat steht in `docs/ai/context-routing.md` unter „Context packet",
das Antwortformat in `docs/ai/agent-output.md`.

Was einen guten Auftrag ausmacht, gemessen an dem, was heute Fehler gefunden
hat: nicht „schau mal drüber", sondern benannte Prüfpunkte. Nicht „teste es",
sondern „lege eine Probe an, die den Verstoß enthält, führe die Prüfung aus,
lösche die Probe und berichte, was du so verifiziert hast". Der Unterschied
war heute mehrfach der zwischen einem grünen Lauf und einem gefundenen Fehler.

**Nach jedem Block eine unabhängige Review.** `code-reviewer` hat im ersten
Änderungssatz fünf blockierende Fehler in etwa 700 Zeilen gefunden, darunter
neun Erkennungslücken im Prüfskript, jede einzeln nachgewiesen. Der Wert liegt
im frischen Kontext: der Prüfer weiß nicht, was sich der Autor gedacht hat.

**Vor den großen Brocken der `architecture-guardian`,** nicht danach. Bei der
Rätsel-Engine und beim Map-Host entscheidet die Struktur, was danach zwei- bis
dreitausend Zeilen kostet.

**Jeden Schritt ansagen,** in der Form „Schritt N von 50: Titel". Der Stand
gehört zusätzlich hierher, siehe unten, weil eine Sitzung endet und diese
Datei bleibt.

**Nie behaupten, was nicht gelaufen ist.** Und beim Prüfen von Exit-Codes kein
`| tail` anhängen, siehe „Befehle". Diese eine Pipe hat hier schon zweimal ein
rotes Gate als grün ausgegeben.

## Diese Datei pflegen

Wer einen Schritt abschließt, aktualisiert hier:

1. **Stand:** Datum, Schrittnummer, Testzahl
2. **Als Nächstes:** was jetzt dran ist
3. **Protokoll:** einen neuen Eintrag oben, zwei bis vier Sätze. Was
   entstanden ist, und vor allem was dabei **überraschend** war. Die
   Überraschungen sind der Teil, den niemand aus dem Code zurücklesen kann.

Details gehören nicht hierher, sondern in `REBUILD_STATUS.md`. Diese Datei
soll in fünf Minuten lesbar bleiben, sonst liest sie niemand, und dann ist sie
schlimmer als keine.
