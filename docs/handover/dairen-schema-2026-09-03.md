# Übergabe: das neue FACT-Datenbankschema

**An:** Maestro Dairen
**Von:** Janek, geschrieben von Claude Code am 03.09.2026
**Gegenstand:** acht Migrationen, die die Datenbank von null neu aufbauen
**Status:** ADR-010 ist `proposed`. Es fehlt deine Annahme.

Diese Datei ist zum Hochladen in Claude gedacht. Zusammen mit
`fact-schema-komplett.sql` reicht sie als Kontext, um über das Schema zu
sprechen, ohne das Repository geklont zu haben.

---

## 1. Wo das liegt

| | |
|---|---|
| Repository | `https://github.com/Daigon2/flutter-fact` (öffentlich) |
| Branch | `claude/fact-flutter-neubau-handoff-fa9426` |
| Commit | `cd40cbb` „feat(backend): das Schema, acht Migrationen" |
| Migrationen | `supabase/migrations/`, acht Dateien, 1578 Zeilen |
| Entscheidung | `docs/decisions/adr/ADR-010-database-rebuild-in-repository.md` |
| CI | `.github/workflows/gates.yml`, Lauf `33785330249`, beide Jobs grün |

Die Datenbank lag vorher im PWA-Monorepo. Sie zieht mit ADR-010 hierher, und
zwar nicht als Kopie, sondern neu gebaut. Das Monorepo bleibt lesende
Referenz für Verhalten und wird von hier aus nie geändert.

**Supabase-Projekt:** `ulnhwlynoecztcykbqtj`, neu angelegt, mit diesem
Repository über die GitHub-Integration verbunden. Ich habe zu keinem Zeitpunkt
einen Secret Key oder Service-Role-Key gehabt und will auch keinen; der Weg in
die Datenbank ist die Git-Integration und sonst nichts. **Offen: von welchem
Branch die Integration deployen soll.** Standard ist `main`, die Arbeit liegt
auf dem Branch oben.

## 2. Was du in fünf Minuten wissen musst

Das Schema hat 15 Tabellen, 2 Sichten und 8 Funktionen. Der Aufbau folgt einer
Idee, und wenn du nur eine Sache prüfst, prüfe diese:

> **Wo eine Belohnung hängt, schreibt kein Client.**

Daraus folgt die ganze Rechtestruktur. Es gibt genau vier Zugriffsarten:

| Art | Wo | Regel |
|---|---|---|
| öffentlich lesbar | Stammdaten und Inhalt | `select` für `anon` und `authenticated`, `using (true)`, kein Personenbezug |
| Besitzer schreibt | `profiles` (zwei Spalten), `saved_facts` | nur wo **keine** Belohnung dranhängt |
| nur Server | `reward_ledger`, `collected_facts` | kein `insert`/`update`/`delete` für irgendeinen Client, auch nicht den Besitzer |
| abgeleitet | `user_balances`, `user_city_scores` | Sichten mit `security_invoker = true` |

Und drei Regeln, die für alle Funktionen gelten:

1. **Keine Funktion nimmt eine Nutzerkennung als Parameter.** Sie nehmen
   `auth.uid()`. Das erledigt eine ganze Fehlerklasse des alten Backends, in dem
   Funktionen die Kennung als Argument nehmen und damit als jemand anderes
   handeln.
2. Jede Funktion setzt `set search_path = ''` und benutzt qualifizierte Namen.
3. Keine Funktion nimmt einen Betrag oder eine Zeit vom Client.

## 3. Die sieben Eigenschaften, um die es geht

Ich habe nicht Befunde behoben, sondern versucht, Familien von Befunden
**unmöglich** zu machen. Das ist der Unterschied, auf den ich deine Meinung
brauche.

**1. Der Stadtschlüssel ist eine Spalte, keine Ableitung.**
`facts.city_id` ist ein Pflicht-Fremdschlüssel auf `cities.id`, und `cities.id`
ist ein Text mit der Bedingung `^[a-z][a-z0-9-]{1,63}$`. Damit können `Rom`
und `Rome` nicht beide als Kennung existieren. Vorher war die Stadt eine
Textspalte, die leer sein durfte, und wurde an fünf Stellen unterschiedlich aus
einem Nummernpräfix geraten.

**2. Kategorie und Kapitel sind eine Tabelle.**
`fact_categories` trägt Farbe, Zeichen, Reihenfolge und `chapter_key`. Der
`chapter_key` ist ein Selbstbezug: bei zehn von elf Kategorien zeigt er auf sich
selbst, bei `nat` auf `geo`. Diese eine Spalte ersetzt fünf Präfixregeln im
Client, deren Reihenfolge über das Ergebnis entschied.

**3. Münzen und Erfahrung sind eine Summe, kein Zähler.**
`reward_ledger` ist append-only, und darauf liegt

```sql
unique (user_id, kind, ref)
```

Dieselbe Belohnung für dieselbe Sache zweimal ist damit unmöglich, nicht
unwahrscheinlich. Kein Vergleich, den jemand vergisst, keine Prüfung, die unter
Last durchrutscht.

**4. Die Beträge sind Zeilen.**
`reward_kinds` hat sechs Zeilen. Einen Betrag zu ändern ist ein `update`, keine
Migration. Vorher lag die Ökonomie in einem Trigger von 120 Zeilen, und dabei
ist die Sammelbelohnung einmal unbemerkt von 50 auf 10 gefallen.

**5. Standort wird geprüft, aber nicht gespeichert.**
`collect_fact(fact_id, lat, lng)` prüft, ob die behauptete Position im Radius
des Fakts liegt, und ob sie gegenüber der **letzten** Sammlung plausibel ist.
Die Rechnung benutzt dafür nur die Koordinaten der beiden **Fakten** und die
Sammelzeitpunkte, also öffentliche Stammdaten. Die behauptete Position wird
nicht gespeichert, es entsteht keine Standorthistorie. Grenze: 30 m/s.

**6. Die Rangliste gibt keine Kontokennung heraus.**
`get_leaderboard` liefert Rang, Username, Punktestand und `is_me`. Die alte
Rangliste gibt Konto-UUIDs heraus, ohne Hürde, und ist damit ein Verzeichnis
aller Konten.

**7. Rechte werden entzogen, bevor die erste Tabelle existiert.**
Migration 1 setzt `alter default privileges ... revoke all` für Tabellen,
Sequenzen und Funktionen gegen `anon` und `authenticated`. Danach ist jedes
Recht ein bewusstes `grant`. Kein „vergessen, RLS einzuschalten" mehr, weil
Vergessen nicht mehr zu Zugriff führt.

## 4. Die vier Brücken

Der Inhalt und das Konto berühren sich an genau vier Fremdschlüsseln. Wenn du
prüfen willst, ob die Trennung hält, prüfe diese vier und sonst keine:

```
collected_facts.fact_id  → facts.id        cascade
saved_facts.fact_id      → facts.id        cascade
reward_ledger.city_id    → cities.id       set null
facts.author_id          → auth.users.id   set null
```

Die letzte ist die einzige Kante, die von der Inhaltsseite auf das Konto zeigt.
`set null` heißt: ein eingereichter Fakt überlebt die Löschung seines Autors und
gilt danach als redaktionell.

Alles am Konto hängt an `on delete cascade`, mit dieser einen Ausnahme. Eine
Kontolöschung räumt also vollständig auf, ohne dass jemand daran denken muss.

## 5. Was ich entschieden habe und wo ich deine Meinung brauche

Sechs Punkte. Ich habe jeweils entschieden, damit es weitergeht, und schreibe
dazu, was der Preis ist.

**Stadtschlüssel als lesbarer Text statt UUID.**
Er kommt in Protokollen und Gesprächen vor, dort sagt eine UUID nichts. Preis:
er ist Teil des Vertrags und wird nie geändert.

**`chapter_key` als Selbstbezug auf derselben Tabelle.**
Elegant oder zu clever? Die Alternative wäre eine eigene Kapitel-Tabelle, in der
zehn von elf Zeilen Duplikate der Kategorie sind.

**Erfahrung wird gebucht, nicht gerechnet.**
Die Vorlage rechnet `gesammelt × 10 + eigene × 50 + Serie × 5` aus Zählwerten.
Ich buche je Ereignis. Dieselbe Summe, aber sie kann von ihren Ursachen nicht
abweichen.

**30 m/s als Plausibilitätsgrenze, geprüft nur gegen die letzte Sammlung.**
Gewählt, nicht gemessen. Wer langsam genug fälscht, kommt durch. Ist das die
richtige Tiefe für jetzt?

**Eine Kategorie-Reihenfolge statt zwei.**
Die Vorlage hat zwei Reihenfolgen für dasselbe: `CAT` ordnet zwölf Kategorien
für die Karte, `WalletCatOrder` sechs Kapitel für den Reiseführer, und die
beiden stimmen nicht überein. `sort_order` ist jetzt **eine**, die der Karte.
**Folge:** die Kapitel im Reiseführer stehen in anderer Folge als bisher, ihre
römischen Zahlen verschieben sich. Bei leerer Datenbank kostenlos, aber es ist
eine sichtbare Änderung, und der Client hat dafür heute noch eine eigene Liste.

**`reward_ledger.ref` ist bewusst kein Fremdschlüssel.**
Eine Buchung kann sich auf einen Fakt, eine Jagd, eine Trophäe oder einen Tag
beziehen; eine Spalte je Art wäre eine Tabelle voller leerer Felder. Die Form
ist `art:kennung`, etwa `fact:412`. **Die Folge, und die ist mir erst beim
Aufschreiben der Löschregeln aufgefallen:** wird ein Fakt gelöscht, verschwindet
die Zeile in `collected_facts`, die Buchung über 50 Münzen bleibt aber stehen.
Verdiente Münzen bleiben verdient, aber Sammelzahl und Journal sagen danach
Verschiedenes. Beim geplanten Löschen aller Fakten vor dem Start ist das
gleichgültig, im Betrieb nicht.

## 6. Was noch fehlt

Bewusst, nicht aus Versehen.

**Trophäen.** Definitionen und Freischaltstand. Entschieden ist, dass der Server
die einzige Wahrheit ist; die Tabellen dafür sind nicht gebaut. Der Reiseführer
zeigt heute 36 gesperrte Trophäen, und das ist für einen neuen Nutzer der
richtige Zustand.

**Gruppen- und Team-Jagd.** Die Produktvorgabe steht seit dem 03.09.2026: erste
und letzte Station gemeinsam, die **zweite und die vorletzte müssen sich
unterscheiden**, dazwischen darf gekreuzt werden, und beide Wege sollen ähnlich
lang sein. Fehlt im Schema und im Generator.

**Creator und Bildablage.** Fotos aus dem Creator-Modus werden gespeichert,
Fotos aus Jagd-Rätseln ausdrücklich **nicht** (Anweisung Janek, 03.09.2026).
Einen Ablageort gibt es noch nicht.

**Vier Zusicherungen als Test.** Kein Tisch ohne RLS, keine Policy mit
`using (true)` auf Personendaten, keine Funktion mit Nutzerkennung als
Parameter, kein doppeltes Gutschreiben. Die fehlen mit Absicht: an einer leeren
Datenbank wären alle vier grün, ohne etwas geprüft zu haben. Sie brauchen
Testdaten und zwei Testkonten.

**Rätsel-Auswertung.** Rührt niemand an. Anweisung Janek vom 03.09.2026: „Lass
den teil erstmal ruhen." Grund: von 1911 Rätseln der Vorlage sind nur 247
überhaupt richtig zu beantworten. `fact_puzzles` speichert deshalb Frage und
Musterlösung und **kein** Vergleichsfeld; die Musterlösung wird angezeigt, nicht
verglichen. Die heutige Vergleichslogik einzubauen hieße, genau das
festzuschreiben, was gerade neu gedacht wird.

## 7. Wie man es prüft

Gate 5 in der CI wendet alle Migrationen von null auf ein leeres Postgres an und
lässt dann den Linter darüber. Lokal, mit Docker:

```bash
npx supabase@2.116.0 db start
npx supabase@2.116.0 db lint --level warning
```

Auf Janeks Maschine läuft das nicht, dort ist kein Docker; deshalb ist Gate 5
CI-only. Die sieben anderen Gates stehen in `docs/engineering/quality-gates.md`.

**Warum keine deklarativen Schemas.** Supabase empfiehlt inzwischen
`supabase/schemas/` mit `db diff`. Ich habe das geprüft und abgelehnt: der
Diff-Mechanismus zieht RLS-Policies, Grants und Spaltenrechte **nicht** mit, und
genau die sind hier die Substanz. Ein Werkzeug, das den wichtigsten Teil
schweigend übergeht, ist hier das falsche. Steht als Begründung in ADR-010.

## 8. Maschinen-Eigenheiten, die Zeit kosten

Stehen ausführlich in `CLAUDE.md`, hier die drei, die wirklich beißen:

- **Die PowerShell kann kein UTF-8 schreiben.** Gemessen am 02.09.2026: ein
  Heredoc-Body und Kommandozeilen-Argumente laufen durch eine Legacy-Codepage,
  `python -c 'print("Übergabe")'` kommt als `?bergabe` an. Lesen, `grep` und das
  Starten einer Skriptdatei sind in Ordnung; nur Text, der **durch** die
  Kommandozeile geht, wird zerlegt. Also: jedes Skript mit deutschem Text in
  eine Datei schreiben und dann ausführen.
- **`dart format` schreibt, bevor es den Exit-Code setzt.** Nur mit
  `--output=none --set-exit-if-changed` benutzen. Ohne `--output=none` hat das
  Gate am 02.09.2026 sechs Dateien eines parallel laufenden Agenten umformatiert.
- **Das Flutter-SDK liegt in `C:\flutter-fresh` und ist nicht im PATH.**
  `C:\flutter` ist kaputt. Bei hängendem Flutter-Tool `dart analyze` statt
  `flutter analyze`.

## 9. Was von hier aus nie geändert wird

- Das PWA-Monorepo unter `…\01_Persönliches\12_Claude\Claude Code\Fact` ist
  **lesende Referenz**. Verhalten, Texte, i18n-Schlüssel und Design-Tokens
  kommen von dort. Geändert wird es von hier aus nicht.
- Und die Referenz ist **kein Goldstandard**. Anweisung Janek vom 02.09.2026:
  Fehler der Quelle zu finden und zu beheben ist ein *Zweck* dieses Neubaus. Ein
  gemessener Defekt ist ein Fund, keine Vorlage. Verhalten folgen, Defekte
  besser machen und aufschreiben.
- Dieses Repository ist **öffentlich**. Projekt-URL und Publishable Key gehen
  über `--dart-define` beziehungsweise eine lokale `env.json`, nie in den
  Quelltext.

## 10. Übergabeprotokoll

**Was passiert ist.** Die Datenbank ist aus dem PWA-Monorepo hierher gezogen und
dabei von null neu gebaut worden, in acht Migrationen. ADR-010 hält die
Begründung, sieben strukturelle Eigenschaften, eine Migrations- und
Rollback-Tabelle und vier Prüfungen fest. Gate 5 ist neu in der CI und baut das
Schema bei jedem Lauf von null. Beide CI-Jobs sind grün.

**Was überraschend war.**

1. **Der Umzug ist der kleinere Teil.** Erwartet hatte ich Reibung beim
   Verschieben. Die eigentliche Arbeit war, dass die Hälfte der bekannten
   Befunde keine Fehler in Funktionen sind, sondern **fehlende Spalten**. Die
   Stadt wurde geraten, weil es keine Stadtspalte gab. Das Kapitel wurde aus
   einem Präfix abgeleitet, weil es keine Kapitelspalte gab. Fünf Befunde
   verschwinden, indem man zwei Spalten hinzufügt, nicht indem man Code
   repariert.
2. **Die Löschregeln haben eine Frage aufgedeckt, die vorher niemand gestellt
   hat.** Erst beim Aufschreiben der zwanzig Fremdschlüssel fiel auf, dass ein
   gelöschter Fakt seine Buchung im Journal zurücklässt. Das ist vermutlich
   richtig, aber es ist eine Produktentscheidung und war keine. Steht als
   sechster Punkt in Abschnitt 5.
3. **Der moderne Weg war der falsche.** Deklarative Schemas sind die aktuelle
   Supabase-Empfehlung, und sie taugen hier nicht, weil `db diff` genau die
   Objekte nicht vergleicht, um die es geht. Das kostet einmal Rechercheaufwand
   und ist es wert, weil die Frage sonst in sechs Monaten wieder aufkommt.
4. **Es gibt kein Kategoriemodell in der Vorlage, es gibt zwei.** Zwölf
   Kategorien für die Karte, sechs Kapitel für den Reiseführer, verschiedene
   Reihenfolgen, und niemand hat das als Widerspruch notiert. Eine Reihenfolge
   daraus zu machen verschiebt sichtbare Kapitelnummern; das ist die einzige
   Stelle, an der dieses Schema den Client zu einer Änderung zwingt.

**Was als nächstes dran ist.**

1. Deine Annahme oder Ablehnung von ADR-010, und die sechs Punkte aus
   Abschnitt 5.
2. Entscheiden, von welchem Branch die Supabase-Integration deployt.
3. Trophäen, Team-Jagd und Creator-Ablage ins Schema.
4. Die vier Zusicherungen als Test, mit Testdaten und zwei Konten.
5. Im Client: aufhören, den Stadtschlüssel abzuleiten, und `city_id` lesen;
   die eine `sort_order` aus der Datenbank übernehmen.

**Eine Frage an Janek, nicht an dich.** Wie viele echte PWA-Konten gibt es? Das
ist das einzige reale Risiko in ADR-010, weil `auth.users` zwischen zwei
Supabase-Projekten zu bewegen keine unterstützte Operation ist. Bei „ein
Handvoll Testkonten" ist die Antwort: neu anlegen.

---

## Anhang: die acht Migrationen

| Datei | Zeilen | Was drin ist |
|---|---|---|
| `20260903190000_fundament.sql` | 80 | Schema `app`, Entzug der Default-Privilegien, `set_updated_at()` |
| `20260903190100_taxonomie.sql` | 187 | `cities`, `fact_categories`, `fact_category_aliases` |
| `20260903190200_identitaet.sql` | 142 | `profiles`, `handle_new_user()`, Trigger auf `auth.users` |
| `20260903190300_inhalt.sql` | 314 | `facts` und die sechs abhängigen Inhaltstabellen |
| `20260903190400_oekonomie.sql` | 240 | `reward_kinds`, `reward_ledger`, `collected_facts`, `saved_facts`, zwei Sichten |
| `20260903190500_funktionen.sql` | 333 | `distance_m`, `grant_reward`, `collect_fact`, `reveal_hint` |
| `20260903190600_stammdaten.sql` | 165 | 12 Kategorien, 32 Aliasse, 5 Städte, 6 Belohnungsarten |
| `20260903190700_rangliste.sql` | 117 | `get_leaderboard`, `get_my_cities` |

Jede Migration trägt ihre Begründung im Kopf. Die Kommentare sind nicht Deko:
sie halten fest, welcher Befund der Vorlage damit wegfällt und wo eine Zahl
widersprüchlich belegt ist. Der vollständige Quelltext liegt in
`fact-schema-komplett.sql`.
