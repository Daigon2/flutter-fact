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

**Zuletzt aktualisiert:** 26.08.2026

**Phase 0 (Fundament), Schritt 6 von 50 in Arbeit.**

Fertig: Projektgerüst, Pakete, Design-Tokens, i18n, Fakt-Datenmodell mit
Supabase-Zugang, dazu das Architektur-Prüfskript mit eigener Testsuite.

In Arbeit: die App-Shell, also typisierte Routen, die schwebende Tab-Leiste,
unabhängige Navigationsstapel je Tab, Platz für den Mini-Player und die
Supabase-Initialisierung im Start.

**Kennzahlen:** 285 Tests grün, alle vier Gates auf Exit-Code 0.

**Wichtig:** Die App ist noch **nie gestartet**. Kein Android-Build, kein
iOS-Build, kein Emulatorlauf. Grüne Tests sagen nichts darüber, ob der erste
Gerätebuild durchläuft.

---

## Als Nächstes

1. **Schritt 6 abschließen** (App-Shell), dann ist Phase 0 komplett.
2. **Erster Gerätebuild.** Das ist der wichtigste ungeprüfte Punkt. Offen ist,
   ob `maplibre_gl` eine höhere `minSdk` braucht und ob die Schriften rendern.
3. **Phase 1** (Schritte 7 bis 11): Splash, Audio-Dialog, Login, Signup,
   Tutorial-Overlay.

Vor Phase 2 (Karte) ist eine Entscheidung fällig: **wie Discovery, Tours,
Challenges und Collection eine Karte teilen**, ohne dass ein Feature die
Presentation eines anderen importiert. Der Vorschlag steht in
`lib/features/README.md` unter „Was bewusst kein Feature ist".

---

## Protokoll

Neueste zuerst. Ein Eintrag je abgeschlossenem Schritt oder größerem Block.

### 26.08.2026, Schritt 6 begonnen: App-Shell

Erstmals Codegen im Einsatz (`go_router_builder`), weil ADR-004 typisierte
Routen verlangt. Erzeugte Dateien werden versioniert, siehe unten.

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

### Nicht aus einem OneDrive-Pfad bauen

Der AOT-Compiler bricht an Nicht-ASCII-Verzeichnisnamen. Dieses Repository
liegt deshalb unter `C:\dev\flutter-fact`. Wenn du es woanders klonst, nimm
einen kurzen ASCII-Pfad.

---

## Befehle

### Die vier Gates

Müssen alle vier auf Exit-Code 0 stehen, bevor etwas committet wird:

```
dart format --output=none --set-exit-if-changed .
dart analyze
dart run tool/check_architecture.dart
flutter test
```

**Hänge kein `| tail` an einen dieser Befehle, wenn du den Exit-Code
auswertest.** Die Pipe maskiert ihn, und genau dadurch wurde hier schon ein
rotes Gate stillschweigend durchgewinkt.

Es gibt **keinen CI-Workflow**. Diese vier Befehle laufen nur, wenn jemand sie
startet.

### Generierten Code neu erzeugen

```
dart run build_runner build --delete-conflicting-outputs
dart run tool/generate_i18n.dart
```

Erzeugte Dateien **sind versioniert**, `*.g.dart` steht nicht in
`.gitignore`. Grund: ADR-004 verlangt generierte typisierte Routen, und ohne
CI, die vorher `build_runner` ausführt, ließe sich ein frischer Klon nicht
kompilieren. Das ist eine bewusste Entscheidung, nachzulesen im Kommentar in
`.gitignore`.

### Drift der Sprachdateien prüfen

```
dart run tool/generate_i18n.dart --check
```

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
