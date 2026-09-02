---
id: OPS-BACKEND-SECURITY-FIXES
status: proposed
owner: operations
scope:
  - backend
  - security
load_when:
  - migration
  - authorization
  - incident
---

# Backend-Sicherheitslücken E-24, E-06, E-23: Analyse und Migrations-SQL

**Zweck.** Dieses Dokument ist eine Übergabe an jemanden mit Backend-Zugang zum
geteilten Supabase-Projekt. Es enthält den geprüften Ist-Zustand, die
Wirkungsanalyse gegen die laufende PWA, fertige Migrations-SQL und zu jedem
Block ein Rückabwicklungs-Skript.

**Das Backend liegt in einem anderen Repository und wird aus diesem hier nicht
verändert** (`CLAUDE.md`, „Reference repository (read-only)"). Alles unten ist
Text, kein ausgeführter Befehl. Nichts davon wurde gegen eine Datenbank laufen
gelassen, auch nicht lesend.

**Alle Zeilenangaben** beziehen sich auf das Referenz-Repository unter
`C:\Users\Janek Postpischil\OneDrive\DokumenteClaudeSortierung\Documents\01_Persönliches\12_Claude\Claude Code\Fact\`,
Stand 28.08.2026.

---

## Entscheidungsstand: die Reihenfolge ist entschieden, und sie ist nicht 1-2-3

Der technische Entscheider hat am 28.08.2026 auf die drei offenen Rückfragen
geantwortet (D-6, D-7, D-8). Das Ergebnis steht hier oben, weil es die
Ausführung bindet.

> ### Migration 1 und Migration 2 laufen jetzt. Migration 3 läuft noch nicht.

| Schritt | Was | Wann |
|---|---|---|
| 1 | Migration 1, `profiles` spaltenweise sperren (E-24) | sofort |
| 2 | Migration 2a **und** 2b, `increment_coins` (E-06) | sofort, direkt danach |
| Zwischenschritt | **PWA-Release**, der `02_Frontend/app/api.jsx:145` auf `collect_fact_validated` umstellt | eigener Auftrag im PWA-Repository |
| 3 | Migration 3, `collected_facts` (E-23) | **erst nach diesem Release** |

**Wer Schritt 3 vorzieht, nimmt die Produktion vom Netz.** `api.jsx:145` ist der
einzige Weg, auf dem in der laufenden PWA ein Fakt gesammelt wird, und der
Fehler wird im Client verschluckt: der Nutzer sieht weiter „gesammelt", während
nichts gespeichert wird. Begründung und Folgeschäden in Abschnitt 4.

**Die drei Antworten im Wortlaut und was daraus folgt:**

- **D-6, Reihenfolge:** „okay passt, gerne fixen." Migration 1 und 2 sind
  freigegeben, Migration 3 bleibt liegen, bis die PWA umgestellt ist.
- **D-7, `increment_coins`:** „ja mit schließen und Betragsdeckel ja. Höhe selbst
  entscheiden, aber leicht anpassbar machen." Die Fremdkonten-Lücke wird
  mitgeschlossen (Block 2a), der Deckel kommt (Block 2b). **Gewählt: 500**, und
  der Wert steht nicht im Funktionsrumpf, sondern in einer Datenbank-Einstellung,
  siehe Abschnitt 4.1 und Block 2b.
- **D-8, wirkungsloses Revoke in `2026-06-20_ai_proxy.sql:61`:** „ja bitte
  selbständig eine Lösung finden und sauber fixen." Ergebnis der Nachprüfung:
  **Migration 1 erledigt das, eine zweite Migration wäre Doppelarbeit.** Eine
  Ergänzung war trotzdem nötig, weil das Empfängerpaar `authenticated, anon`
  nicht vollständig ist. Abschnitt 6.1 begründet beides.

---

## 0. Die vier Befunde, die die Aufgabenstellung korrigieren

Bevor irgendetwas ausgeführt wird, vier Ergebnisse aus der Prüfung am echten
SQL. Jedes einzelne ändert, was zu tun ist.

**1. Ein `WITH CHECK` auf `profiles` behebt E-24 nicht. Es ändert gar nichts.**
Die Policy lautet `for all using (auth.uid() = id)`. PostgreSQL benutzt bei
einer Policy ohne `WITH CHECK` den `USING`-Ausdruck **auch** als Prüfung für
neue und geänderte Zeilen. Ein zusätzliches `with check (auth.uid() = id)` wäre
wörtlich derselbe Ausdruck und würde denselben Satz Zeilen zulassen. Dazu kommt:
eine `WITH CHECK`-Klausel sieht bei `UPDATE` nur die **neue** Zeile, nie die
alte. „`coins` darf sich nicht ändern" ist in RLS überhaupt nicht formulierbar.
Spaltenschutz braucht **Spaltenrechte** (`GRANT`/`REVOKE`) oder einen
`BEFORE UPDATE`-Trigger. Migration 1 unten macht Ersteres.

**2. Die PWA fügt direkt in `collected_facts` ein, und `collect_fact_validated`
ist in der PWA toter Code.** `02_Frontend/app/api.jsx:145`. Ein Aufruf von
`collect_fact_validated` existiert in `02_Frontend/app/` **nirgends**; der
einzige Treffer auf den Namen ist ein SQL-Kommentar in `api.jsx:5`, und der
zitiert `increment_coins`. Der Einwand aus dem Auftrag ist damit **belegt, nicht
entkräftet**: Migration 3 nimmt die Produktion vom Netz, solange die PWA
unverändert bleibt.

**3. Es gibt keine Spalten `xp` und `level` auf `profiles`.** Die
Aufgabenstellung nennt sie unter den serverseitig zu schützenden Feldern. XP und
Level werden in der PWA zur Anzeigezeit aus `collectedFacts.length` und
`userFacts.length` gerechnet (`02_Frontend/app/app.jsx:706-707`,
`window.computeXP`), sie sind nirgends persistiert. `profiles` hat zwölf
Spalten, Liste in Abschnitt 3.

**4. Der Anti-Cheat-Schutz aus `2026-06-20_ai_proxy.sql:61` ist mit hoher
Wahrscheinlichkeit wirkungslos.** Dort steht
`revoke update (ai_used, ai_limit) on public.profiles from authenticated, anon;`
ohne dass vorher das **tabellenweite** `UPDATE`-Recht entzogen wird. Rechte in
PostgreSQL sind additiv: wer `UPDATE` auf der Tabelle hält, darf jede Spalte
schreiben, unabhängig von entzogenen Spaltenrechten. Supabase vergibt per
Default-Privilegien `all on all tables in schema public` an `anon` und
`authenticated`. Ob das in diesem Projekt tatsächlich so steht, ist mit Abfrage
D in Abschnitt 7 in einer Sekunde zu klären. Falls ja, ist das
Gratis-Kontingent für die LLM-Anfragen bis heute per `UPDATE` zurücksetzbar, und
**Migration 1 schließt das als Nebenwirkung mit**. Die Nachprüfung dazu (D-8)
steht in Abschnitt 6.1, samt der einen Zeile, die dafür ergänzt werden musste.

---

## 1. Ist-Zustand am echten SQL

### E-24: `profiles`

`03_Backend/supabase-schema.sql:140-142`

```sql
-- Profiles: own row only
create policy "own profile" on public.profiles
  for all using (auth.uid() = id);
```

Die Beschreibung in `REBUILD_STATUS.md:421` ist wörtlich korrekt: kein
`WITH CHECK`. Die daraus abgeleitete Folgerung stimmt ebenfalls, ein
angemeldeter Nutzer darf seine eigene Zeile beliebig aktualisieren, also auch
`coins` und `score_total`. Nur der naheliegende Schluss auf die Behebung ist
falsch, siehe Befund 1 oben.

Weitere Rechte auf derselben Tabelle: `2026-06-20_ai_proxy.sql:61` (siehe Befund
4). Keine weitere Policy auf `profiles` im gesamten Referenz-Repo.

### E-06: `increment_coins`

`03_Backend/supabase-schema.sql:84-89`

```sql
-- ── RPC: atomic coin increment ───────────────────────────────────────

create or replace function increment_coins(uid uuid, amount integer)
returns void language sql security definer as $$
  update public.profiles set coins = coins + amount where id = uid;
$$;
```

Die Beschreibung in `REBUILD_STATUS.md:407` ist korrekt und **untertreibt**.
Drei Defekte, nicht einer:

1. `amount` wird nicht geprüft. Der Client bestimmt die Höhe.
2. `uid` wird nicht geprüft. Es gibt keinen Vergleich mit `auth.uid()`. **Jeder
   angemeldete Nutzer kann jedem beliebigen anderen Konto Coins schreiben**,
   solange er dessen UUID kennt. Die UUID steht in jeder Leaderboard-Antwort:
   `get_leaderboard` gibt `user_id` mit aus (`supabase-schema.sql:371`, `p.id`
   in allen vier Zweigen). Das ist keine Reward-Frage mehr, das ist
   Fremdkontenmanipulation.
3. Kein `set search_path`. Bei einer `SECURITY DEFINER`-Funktion ist das der
   Standardbefund jedes Supabase-Linters. Praktisch nicht über PostgREST
   ausnutzbar, weil ein REST-Client kein `CREATE TEMP TABLE` absetzen kann, aber
   kostenlos zu beheben.

Zusatzbefund zum `search_path`: `ai_consume` und `ai_refund`
(`2026-06-20_ai_proxy.sql:25,41`) setzen `search_path = public`. Das schützt
nicht vollständig. PostgreSQL durchsucht das Temp-Schema für **Relationen**
immer, und zwar **zuerst**, wenn `pg_temp` nicht ausdrücklich im Pfad genannt
ist. Wer das dichtmachen will, schreibt `set search_path = public, pg_temp`,
also `pg_temp` ausdrücklich an letzter Stelle. Alle Blöcke unten tun das.

### E-23: `collected_facts`

`03_Backend/supabase-schema.sql:152-154`

```sql
-- Collected / saved: own rows only
create policy "own collected" on public.collected_facts
  for all using (auth.uid() = user_id);
```

Die Beschreibung in `REBUILD_STATUS.md:420` ist korrekt. Der Client darf direkt
einfügen, und die 150-Meter-Prüfung aus `collect_fact_validated`
(`supabase-schema.sql:120-122`) ist damit optional statt nur umgehbar.

### Keine der drei ist behoben

Im gesamten `03_Backend/` gibt es genau zwei `with check`-Klauseln, beide auf
anderen Tabellen (`supabase-schema.sql:150` für `facts`, `:162` für
`comments`). Es existiert keine spätere Migration, die eine der drei Policies
ersetzt oder eine der drei Funktionen absichert.

---

## 2. Wer schreibt heute wohin

Vollständige Erhebung. Gesucht wurde in `02_Frontend/app/` (PWA, produktiv),
`02_Frontend/admin/`, `02_Frontend/landing/`, `fact-website/`,
`04_Datenpipeline/`, `supabase/functions/`, `08_Flutter/` (eingefrorener Port)
und `lib/` (dieses Repository).

### Schreibzugriffe auf `profiles`

| Wo | Zeile | Operation | Spalten |
|---|---|---|---|
| PWA `api.jsx` | 253-257 (`setUsername`) | `update` | `username`, bedingt `username_changed_at` |
| PWA `screen-profil.jsx` | 693 | `update` | `show_real_name` |
| dieses Repo `lib/features/identity/data/datasources/remote/supabase_auth_remote_data_source.dart` | 329-332 | `update` | `username` |
| alter Port `08_Flutter/lib/services/supabase_service.dart` | 158-160 | `update` | `show_real_name` |

Serverseitig, per `SECURITY DEFINER`, also ohne Policy-Prüfung:
`handle_new_user` (`supabase-schema.sql:70`, `insert` bei der Registrierung),
`collect_fact_validated:125` (`coins +10`), `handle_fact_collected:255`
(`score_total +1`), `collect_group_fact` (`2026-06-04_group_sessions.sql:329`,
`coins +50`), `collect_team_fact` (`2026-06-05_team_sessions.sql:592`,
`coins +50`), `tag_endpoint` (`:680`, `coins +100`), `ai_consume` / `ai_refund`
(`2026-06-20_ai_proxy.sql:28,44`), `increment_coins`.

**Kein Client legt eine `profiles`-Zeile an.** Weder die PWA noch dieses
Repository. Die Zeile entsteht ausschließlich über den Trigger
`on_auth_user_created` (`supabase-schema.sql:80-82`) aus `raw_user_meta_data`.
Der Auftrag vermutete das Gegenteil („Unsere eigene Registrierung schreibt
direkt in `profiles`"). Der Befund ist präziser: `SignupNotifier` ruft
`auth.signUp` mit `name` und `hometown` als Metadaten
(`supabase_auth_remote_data_source.dart:266-269`) und danach `setUsername`, also
ein **`UPDATE` einer Spalte**, kein `INSERT` einer Zeile
(`signup_notifier.dart:186`).

**Kein Client schreibt `name` oder `hometown` nach der Registrierung.**
`screen-creator.jsx:39-44` sieht danach aus, schreibt aber in `Storage.setUser`,
also in den `localStorage`. Der Server behält den Registrierungswert dauerhaft.

### Schreibzugriffe auf `collected_facts`

| Wo | Zeile | Operation |
|---|---|---|
| PWA `api.jsx` | 145 (`collectFact`) | `upsert({ user_id, fact_id })` |
| alter Port `08_Flutter/lib/services/supabase_service.dart` | 119-123 | `upsert` |
| dieses Repo `lib/` | keine | keine |

Aufrufer in der PWA: `app.jsx:714` (normales Sammeln), `app.jsx:738`
(`onHuntCollectFact`, Schnitzeljagd-Reveal). Serverseitig:
`collect_fact_validated:124`, `collect_group_fact`
(`2026-06-04_group_sessions.sql:323`), `collect_team_fact`
(`2026-06-05_team_sessions.sql:586`).

### Aufrufe von `increment_coins`

| Wo | Zeile | Betrag |
|---|---|---|
| PWA `api.jsx` | 157 (`addCoins`) | Durchreichung |
| PWA `app.jsx` | 714 | `50` beim Sammeln |
| PWA `app.jsx` | 761 | `12` oder `17` für einen selbst erstellten Fakt (`app.jsx:753`) |
| PWA `app.jsx` | 769 (`onAwardCoins`) | beliebiges `n` der Aufrufer unten |
| PWA `screen-fact.jsx` | 214 | `2` |
| PWA `screen-map.jsx` | 3542 | **`-10` oder `-20`** (Hinweiskosten, `:3538`) |
| PWA `screen-challenge.jsx` | 4364 | `Math.floor(score / 8)`, **Höchstwert 270**, Herleitung unten |
| PWA `puzzle-sheet.jsx` | 585 | `netCoins`, **Höchstwert 50**, Herleitung unten |
| alter Port `08_Flutter/lib/services/supabase_service.dart` | 155-156 | Durchreichung, **ohne Aufrufer** |
| dieses Repo `lib/` | keine | keine |

**Das ist der harte Teil des Befundes.** Die Coin-Ökonomie der PWA wird
vollständig im Client gerechnet, die Beträge sind nicht konstant, und **negative
Beträge sind ein regulärer Anwendungsfall** (`screen-map.jsx:3542`, Hinweis
kaufen). Eine Server-Prüfung der Form „Betrag muss positiv und klein sein"
bricht das Kaufen von Hinweisen. Eine Whitelist erlaubter Beträge ist nicht
aufstellbar, weil zwei der Beträge gerechnet werden.

### Nachtrag zu D-7: die beiden gerechneten Beträge sind doch nach oben belegt

Für die Wahl des Deckels wurden die zwei offenen Beträge im zweiten Durchgang
bis zur Konstanten zurückverfolgt. Die erste Fassung dieses Dokuments nannte sie
„nach oben nicht belegt". **Das war zu vorsichtig, beide sind beschränkt.**

**`screen-challenge.jsx:4364`, `Math.floor(score / 8)`: Höchstwert 270.**
`score` entsteht ausschließlich in `SnjdActiveView` (`screen-challenge.jsx:2185`,
addiert in `:2300`, verringert in `:2318` und `:2334`). Pro Station kommen
höchstens `diff.points` Punkte dazu, Abzüge für Hinweise und Fehlversuche gehen
nur nach unten und sind bei `Math.max(0, ...)` gekappt (`:2296`). Der größte
Wert von `diff.points` ist `240` (`SNJD_DIFF.schwer`, `:167`). Die Stationszahl
ist `Math.min(ids.length, SNJD_SLICE[diffKey])`; alle fünf Routen in
`SNJD_ROUTES` haben genau `9` IDs (`:183, :210, :237, :264, :291`), und
`SNJD_SLICE.schwer` ist `9` (`:307`). Also `9 × 240 = 2160` Punkte im perfekten
Lauf, geteilt durch 8 macht **270 Coins**. Der `onFinish`-Aufruf bei Abbruch
(`:2273`) übergibt `0`.

**`puzzle-sheet.jsx:585`, `netCoins`: Höchstwert 50.**
`netCoins = Math.max(0, coins - hintsSpent)` (`:574`). `coins` ist
`revealState.coinsForFact` (`:104`), das ist entweder `PSZ_BASE_COINS[diff]`
oder `PSZ_FAIL_COINS` (`:94`). `PSZ_BASE_COINS` ist für alle drei
Schwierigkeiten `50` (`:22`), `PSZ_FAIL_COINS` ist `10` (`:24`). `hintsSpent`
ist nie negativ (`PSZ_HINT_COSTS` ist `[0, 20, 30]`, `:29-33`). Obergrenze
also **50**, und durch `Math.max(0, ...)` ist der Wert nie negativ.

**Damit ist der größte Betrag, den ein legitimer PWA-Ablauf heute an
`increment_coins` übergibt, `270`**, und der kleinste ist `-20`. Die Konsequenz
für den Deckel steht in Abschnitt 4.1.

**Der eingefrorene Port ist kein Aufrufer.**
`08_Flutter/lib/services/supabase_service.dart:155` reicht `amount` durch, aber
die Methode `SupabaseService.addCoins` wird in `08_Flutter/lib/` von niemandem
gerufen. Der einzige Treffer auf `addCoins` dort ist `_storage.addCoins(10)`
(`app_state.dart:102`), also der lokale Speicher, nicht die RPC. Für die
Deckelwahl fällt der alte Port damit ganz weg.

### Aufrufe von `collect_fact_validated`

| Wo | Zeile |
|---|---|
| PWA | **keine** |
| alter Port `08_Flutter/lib/services/supabase_service.dart` | 127-140 |
| dieses Repo `lib/` | keine |

Die serverseitig validierte Sammelfunktion wird in der Produktion von niemandem
benutzt. Der eingefrorene Flutter-Port hat sie als einziger angebunden, und zwar
zusätzlich zu `collectFact` (`:119`), nicht anstelle.

### Nicht betroffen

`02_Frontend/admin/index.html` arbeitet mit `service_role` und ausschließlich
auf `facts` (Zeilen 1156, 1426, 1523, 1543, 1728, 1733, 1912). `service_role`
umgeht RLS und alle Spaltenrechte. `04_Datenpipeline/scripts/test_auth_e2e.py`
liest `profiles` mit `service_role` (`:56`). `supabase/functions/llm/index.ts`
ruft nur `ai_consume` (`:62`). Keine dieser Stellen ändert sich durch die drei
Migrationen.

---

## 3. Spaltenweise Trennung für `profiles`

Die Tabelle hat zwölf Spalten, aus drei Stellen zusammengesetzt:
`supabase-schema.sql:7-14` (Grundgerüst), `:200-204` (Ranking),
`2026-06-20_ai_proxy.sql:15-17` (LLM-Kontingent).

| Spalte | Wer setzt sie heute | Darf der Nutzer? | Begründung |
|---|---|---|---|
| `id` | Trigger `handle_new_user` | nein | Primärschlüssel, gleich `auth.users.id` |
| `name` | Trigger, aus `raw_user_meta_data` | **nein, aber ungefährlich** | kein Client schreibt sie heute; Hinweis unten |
| `hometown` | Trigger, aus `raw_user_meta_data` | **nein, aber ungefährlich** | dito |
| `coins` | nur Server-RPCs | **nein** | Kern von E-24 |
| `join_date` | Default `current_date` | nein | wird nur gelesen (`api.jsx:102`) |
| `created_at` | Default `now()` | nein | wird nirgends gelesen |
| `username` | Client | **ja** | `api.jsx:255`, `supabase_auth_remote_data_source.dart:331` |
| `username_changed_at` | Client | **ja** | `api.jsx:254`, Teil derselben Schreiboperation |
| `score_total` | nur Trigger `handle_fact_collected` | **nein** | Grundlage der Rangliste (`get_leaderboard:418`) |
| `show_real_name` | Client | **ja** | `screen-profil.jsx:693` |
| `ai_used` | nur `ai_consume` / `ai_refund` | **nein** | Kostenschutz, siehe Befund 4 |
| `ai_limit` | niemand zur Laufzeit | **nein** | dito |

**Ergebnis: genau drei Spalten sind aus dem tatsächlichen Gebrauch abgeleitet
schreibbar**, `username`, `username_changed_at`, `show_real_name`. Migration 1
gibt genau diese drei frei. Das ist die enge Fassung, und sie bricht heute
nichts, weil jede der vier gefundenen Client-Schreibstellen ausschließlich diese
drei anfasst.

**Hinweis zu `name` und `hometown`.** Beide sind sicherheitlich unkritisch: ihr
Inhalt kommt ohnehin aus `raw_user_meta_data`, und das ist über
`auth.updateUser` frei vom Client beschreibbar. Sie mitzugeben würde einem
Angreifer nichts geben. Sie sind trotzdem **nicht** in Migration 1, weil heute
kein Code sie schreibt und die enge Fassung die belegbare ist. Sobald ein
Profil-Bearbeiten-Bildschirm entsteht (Phase 7 in `REBUILD_STATUS.md`), reicht
eine Zeile:

```sql
grant update (name, hometown) on public.profiles to authenticated;
```

**Warum die Richtung von `REVOKE` und `GRANT` wichtig ist.** Wird künftig eine
Spalte per `ALTER TABLE ADD COLUMN` ergänzt, ist sie für `authenticated`
**nicht** schreibbar, weil das tabellenweite Recht fehlt und die Spalte in
keiner `GRANT`-Liste steht. Der Fehler fällt zur sicheren Seite aus: eine neue
Spalte ist zunächst gesperrt und muss ausdrücklich freigegeben werden. Das ist
genau die umgekehrte Falle zum heutigen Zustand.

---

## 4. Die Reihenfolge, und wo die App dabei kaputtgeht

`REBUILD_STATUS.md:421` sagt: „wer E-06 behebt, also `increment_coins`
absichert, hat damit nichts gewonnen, solange E-24 offen ist". **Das stimmt und
gilt in beide Richtungen.** Solange `increment_coins` offen ist, gewinnt auch
E-24 für die Coins nichts: die Funktion ist dann der bequemere von zwei Wegen.
Coins sind erst geschützt, wenn **beide** zu sind.

Trotzdem ist die vorgegebene Reihenfolge richtig, aus einem Grund, der in
`REBUILD_STATUS.md` nicht steht: **E-24 ist der einzige der drei Schritte, der
für sich allein einen echten Gewinn bringt und dabei nichts bricht.** Er sperrt
`score_total` (die Rangliste), er sperrt `ai_used`/`ai_limit` (die laufenden
LLM-Kosten, siehe Befund 4), und keine der vier Client-Schreibstellen fasst eine
gesperrte Spalte an.

Reihenfolge mit Bewertung:

| Schritt | Sicherheitsgewinn für sich allein | Bricht die PWA? | Bricht diese App? |
|---|---|---|---|
| 1. E-24, `profiles` | `score_total` und das LLM-Kontingent sind dicht | **nein** | **nein** |
| 2. E-06, `increment_coins` | Fremdkonten-Manipulation ist dicht, Coins gedeckelt | **nein**, Nachweis je Aufrufer in 4.1 | nein, `lib/` ruft die RPC nicht |
| 3. E-23, `collected_facts` | Rangliste und Trophäen sind serverbestimmt | **ja, vollständig** | nein, `lib/` schreibt dort nicht |

**Zwischen Schritt 1 und 2 entsteht kein kaputter Zustand.** Nach Schritt 1 ist
`coins` per `UPDATE` gesperrt, `increment_coins` läuft als Definer weiter und
ist von Spaltenrechten nicht betroffen. Die PWA schreibt Coins ohnehin nur über
die RPC.

**Schritt 2 ist mit D-7 vollständig entschieden**, Block 2a und Block 2b laufen
beide. Die gewählte Deckelhöhe und ihre Begründung stehen in Abschnitt 4.1.

---

## 4.1 Der Betragsdeckel: Höhe, Verstellbarkeit, Wirkung je Aufrufer

### Gewählt: 500

Nach dem Nachtrag in Abschnitt 2 ist der größte Betrag, den ein legitimer
PWA-Ablauf heute an `increment_coins` übergibt, **270** (perfekter Quizlauf auf
`schwer`), der kleinste **-20** (dritter Hinweis auf der Karte). `500` ist damit

- das **1,85-fache** des größten belegten Betrags, also Luft für eine weitere
  Quiz-Schwierigkeit oder eine Route mit mehr Stationen, ohne dass jemand eine
  Migration anfassen muss;
- das **Zehnfache** des größten konstanten Betrags (`50` beim Sammeln);
- klein genug, dass ein Missbrauch pro Aufruf höchstens zwei perfekte Quizläufe
  wert ist statt eines beliebigen Kontostands.

Die erste Fassung schlug `1000` vor, mit der Begründung „zwei Beträge sind nach
oben unbelegt". Diese Begründung ist weggefallen, weil beide Beträge inzwischen
bis zur Konstanten zurückverfolgt sind. `500` ist deshalb kein engerer Deckel
aus Vorsicht, sondern einer aus Kenntnis.

### Wirkung je Aufrufer, einzeln durchgegangen

Prüfpunkt: kein heute legitimer Ablauf darf durch den Deckel scheitern.

| Aufrufer | Betrag | Belegter Höchstbetrag | Unter 500? |
|---|---|---|---|
| `app.jsx:714`, Fakt sammeln | `+50` | 50 | ja |
| `app.jsx:761`, eigener Fakt | `+12` / `+17` (`app.jsx:753`) | 17 | ja |
| `screen-fact.jsx:214`, Kommentar | `+2` | 2 | ja |
| `screen-map.jsx:3542`, Hinweis kaufen | `-10` / `-20` (`:3538`) | -20 | ja, unterer Zweig |
| `screen-challenge.jsx:4364`, Quizabschluss | `Math.floor(score / 8)` | 270 | ja |
| `puzzle-sheet.jsx:585`, Rätselabschluss | `netCoins` | 50 | ja |
| `08_Flutter/.../supabase_service.dart:155` | Durchreichung | kein Aufrufer | entfällt |
| `lib/` in diesem Repository | ruft die RPC nicht | entfällt | entfällt |

**Was der Deckel ausdrücklich nicht anfasst.** Die serverseitigen Gutschriften
laufen nicht über `increment_coins`, sondern schreiben `profiles.coins` direkt
aus einer `SECURITY DEFINER`-Funktion. Sie sind vom Deckel nicht betroffen, auch
nicht die größte davon:

| Funktion | Betrag | Fundstelle |
|---|---|---|
| `collect_fact_validated` | `+10` | `supabase-schema.sql:125` |
| `collect_group_fact` | `+50` | `2026-06-04_group_sessions.sql:329` |
| `collect_team_fact` | `+50` | `2026-06-05_team_sessions.sql:592` |
| `tag_endpoint` | `+100` | `2026-06-05_team_sessions.sql:680` |

**Wo der Nachweis endet.** Belegt ist der Zustand des PWA-Codes vom 28.08.2026.
Für zukünftige Beträge gilt der Nachweis nicht. Eine neue Quiz-Schwierigkeit mit
`points: 500` und neun Stationen ergäbe `4500 / 8 = 562` und liefe gegen den
Deckel. Genau deshalb ist die Höhe verstellbar, siehe unten.

### Richtung: der Deckel prüft beide Seiten, aber getrennt

Prüfpunkt: negative Beträge müssen zulässig bleiben.

Der Hinweiskauf bucht `-10` und `-20`. Ein Deckel, der `amount > 0` verlangt,
bricht ihn. Ein Deckel, der `abs(amount) > 500` prüft, bricht ihn nicht, ist
aber aus zwei Gründen die schlechtere Formulierung:

1. **`abs()` versteckt die Richtung.** Sicherheitsrelevant ist ausschließlich
   die obere Seite: nur eine Gutschrift verschafft einem Angreifer etwas. Die
   untere Seite ist ein Plausibilitätsfilter gegen Unsinn, kein Schutz. Wer das
   in einem `abs()` zusammenzieht, lädt den nächsten Leser ein, die untere
   Grenze aus Bequemlichkeit zu verschärfen und damit den Hinweiskauf zu
   zerstören.
2. **`abs()` kann selbst fehlschlagen.** In PostgreSQL ist
   `abs(-2147483648::integer)` ein Laufzeitfehler, `integer out of range`, weil
   der positive Gegenwert nicht mehr in `integer` passt. Statt einer sauberen
   Ablehnung käme ein Fehler aus einer anderen Ecke zurück. Zwei getrennte
   Vergleiche haben dieses Verhalten nicht.

Block 2b schreibt deshalb `amount > v_max` und `amount < -v_max` als zwei
getrennte Bedingungen mit zwei unterschiedlichen Fehlertexten.

### Verstellbarkeit: die Höhe steht nicht im Funktionsrumpf

D-7 sagt „Höhe selbst entscheiden, aber leicht anpassbar machen". Eine
Konstante im `DECLARE`-Block ist nur mit `CREATE OR REPLACE FUNCTION` änderbar,
also mit einer neuen Migration, einem neuen Review und einem neuen
Ausführfenster. Das ist nicht „leicht anpassbar".

Gewählter Weg: **eine benutzerdefinierte Datenbank-Einstellung**
`fact.coins_max_delta`, gelesen mit `current_setting('fact.coins_max_delta', true)`,
gesetzt mit `ALTER DATABASE`. Warum das hier trägt:

- **Der Name mit Punkt ist entscheidend.** PostgreSQL erlaubt beliebige
  zweiteilige Einstellungsnamen als Platzhalter, ohne dass eine Erweiterung sie
  vorher anmeldet. `fact.coins_max_delta` ist damit ohne Schemaänderung nutzbar.
- **`SECURITY DEFINER` stört nicht.** Das Lesen einer Einstellung ist keine
  Objektberechtigung, es hängt nicht an der Rolle, unter der die Funktion läuft.
  Das `set search_path = public, pg_temp` an der Funktion setzt nur
  `search_path` und lässt andere Einstellungen unberührt.
- **Der Client kann sie nicht selbst setzen.** Über PostgREST kommt kein
  beliebiges `SET` durch; aus dem JWT übernimmt PostgREST nur Einstellungen im
  Namensraum `request.` sowie `role`. `fact.coins_max_delta` liegt außerhalb
  davon. Das ist der Grund, den Namen **nicht** mit `request.` beginnen zu
  lassen.
- **Poolbetrieb: der Wert wirkt nicht sofort.** `ALTER DATABASE ... SET` landet
  in `pg_db_role_setting` und wird beim **Aufbau** einer Verbindung angewandt.
  PostgREST und der Supabase-Pooler halten Verbindungen offen, und das
  `SET LOCAL ROLE` pro Anfrage setzt die Einstellung nicht neu. Eine Änderung
  greift also erst, wenn die bestehenden Verbindungen erneuert werden. Für einen
  Betragsdeckel ist das unkritisch, muss aber gewusst sein, sonst hält jemand
  die Änderung für wirkungslos und dreht weiter. Sofort wirksam wird sie mit
  einem Neustart des Projekts.

**Verworfen: eine Konfigurationstabelle.** Eine Zeile in einer Tabelle
`app_config(key, value)` wäre sofort für alle Verbindungen wirksam und
auditierbar. Sie ist trotzdem nicht der Vorschlag, weil sie eine **neue Tabelle**
und damit eine Schemaänderung über die drei Migrationen hinaus wäre. Das ist
laut Auftrag zu melden statt zu entscheiden. Wenn der sofortige Durchgriff
wichtiger ist als die Zahl der Migrationen, ist das eine bewusste Entscheidung
und keine Nebenwirkung dieses Dokuments.

### Fehlende Einstellung heißt nicht „kein Deckel"

Prüfpunkt, und die gefährlichste Stelle des ganzen Blocks.

`current_setting('fact.coins_max_delta', true)` liefert bei nicht gesetzter
Einstellung `NULL`. Der naive Code

```sql
if amount > current_setting('fact.coins_max_delta', true)::integer then ...
```

wäre dann `amount > NULL`, und das ist in SQL weder wahr noch falsch, sondern
`NULL`. Ein `IF` auf `NULL` nimmt in PL/pgSQL den `ELSE`-Zweig. Die Prüfung
**fiele lautlos aus**, und niemand würde es merken, weil nichts fehlschlägt.

Block 2b behandelt den gelesenen Wert deshalb als Text und validiert ihn, bevor
er zur Zahl wird:

| Inhalt der Einstellung | Ergebnis |
|---|---|
| nicht gesetzt (`NULL`) | Ausfallwert **500** |
| leerer Text | Ausfallwert **500** |
| `'800'` | 800 |
| `'abc'`, `'8 0 0'`, `'-5'`, `'1e3'` | Ausfallwert **500** |
| `'0'` | Ausfallwert **500**, ein Deckel von 0 wäre ein Ausfall, kein Schutz |
| `'99999999999'`, also mehr als neun Stellen | Ausfallwert **500** |

Der Ausfallwert ist eine `constant` im Funktionsrumpf. Das ist bewusst die
einzige Zahl, die eine Migration braucht: sie ist die Untergrenze der
Verlässlichkeit, nicht der Betriebswert. **Ein fehlender Wert bedeutet nie
„kein Deckel".**

Auf einen ungeprüften Cast wird bewusst verzichtet, statt ihn in einen
Ausnahmeblock zu packen: ein Tippfehler in der Einstellung würde sonst jede
einzelne Coin-Buchung mit `22P02` abbrechen, und ein Betriebsfehler an einer
Verstellschraube darf nicht die Anwendung anhalten. Die Regel `^[0-9]{1,9}$`
fängt zusätzlich den Überlauf ab, weil neunstellige Zahlen sicher in `integer`
passen.

**Was der Deckel nicht kann: er ist kein Notaus.** Wer Coin-Buchungen komplett
stoppen will, entzieht das Ausführrecht
(`revoke execute on function public.increment_coins(uuid, integer) from authenticated;`)
statt die Einstellung auf einen winzigen Wert zu drehen.

### Der eine Satz für jemanden ohne SQL-Kenntnisse

> Deckel ändern: im Supabase-Dashboard „SQL Editor" öffnen, die Zeile
> `alter database postgres set fact.coins_max_delta = '800';` einfügen, „Run"
> drücken, danach unter „Settings" das Projekt einmal neu starten, damit die
> laufenden Verbindungen den neuen Wert lesen.

Zurück auf den eingebauten Wert `500`:
`alter database postgres reset fact.coins_max_delta;`, wieder mit Neustart.

Falls `ALTER DATABASE` mit „must be owner of database" abgelehnt wird, weil die
Editor-Rolle die Datenbank nicht besitzt, greift dieselbe Einstellung auch auf
der Login-Rolle von PostgREST:
`alter role authenticator set fact.coins_max_delta = '800';`. Das deckt die
API-Aufrufe ab, aber nicht Sitzungen im SQL-Editor selbst. Welche der beiden
Varianten das Projekt zulässt, beantwortet Abfrage I in Abschnitt 7.

**Schritt 3 nimmt die PWA vom Netz, und zwar nicht teilweise.** `api.jsx:145`
ist der **einzige** Weg, auf dem in der Produktion ein Fakt gesammelt wird.
Fällt er weg, dann fallen mit ihm:

- das Sammeln selbst (`app.jsx:714`) und das Sammeln in der Schnitzeljagd
  (`app.jsx:738`);
- über den Trigger `on_fact_collected` die Zählung `score_total`, die
  Stadtwertung `user_city_scores` und **sämtliche Trophäen**
  (`supabase-schema.sql:226-341`);
- die Wochen-Rangliste, weil `get_leaderboard` im `weekly`-Zweig auf
  `collected_facts` zählt (`:385-386`).

`_apiCheck` (`api.jsx:139-146`) schluckt den Fehler übrigens: es schreibt eine
Konsolen-Warnung und meldet an Sentry, die Oberfläche zeigt weiter „gesammelt".
Der Nutzer sieht also **nicht**, dass nichts gespeichert wurde, bis er neu lädt.
Ein stiller Datenverlust ist schlimmer als eine Fehlermeldung.

**Deshalb ist Migration 3 nicht auszuführen, bevor die PWA umgestellt ist.** Die
Umstellung ist keine Zeile. `collect_fact_validated` verlangt `p_user_lat` und
`p_user_lng`, gibt bei zu großer Entfernung `ok:false` zurück und bucht selbst
`+10` Coins (`supabase-schema.sql:124-127`), während die PWA an derselben Stelle
`50` bucht (`app.jsx:714`). Wer nur den Aufruf tauscht, verdoppelt entweder die
Gutschrift oder senkt sie von 50 auf 10, und der Reveal-Pfad
`onHuntCollectFact` (`app.jsx:735-741`) hat an seiner Stelle möglicherweise gar
keine belastbare Position. Das ist ein PWA-Auftrag im anderen Repository, kein
Migrations-Auftrag.

---

## 5. Der Trigger nach der Abdichtung

Frage: feuert `handle_fact_collected` nach Migration 3 noch, und nimmt
`collect_fact_validated` denselben Weg?

**Ja, beides**, unter einer Voraussetzung, die per Abfrage E in Abschnitt 7 zu
bestätigen ist.

`on_fact_collected` ist `AFTER INSERT ON public.collected_facts FOR EACH ROW`
(`supabase-schema.sql:343-345`). Ein Trigger hängt an der Tabelle, nicht an der
aufrufenden Rolle. Er feuert bei **jedem** Insert, auch bei einem aus einer
`SECURITY DEFINER`-Funktion. Migration 3 nimmt dem Client nur das Recht und die
Policy für den Insert, sie ändert an der Tabelle nichts.

`collect_fact_validated` ist `security definer` (`supabase-schema.sql:98`). Eine
Definer-Funktion läuft mit den Rechten ihres Besitzers. Ist der Besitzer
zugleich Eigentümer der Tabelle, dann gilt zweierlei: RLS-Policies greifen für
ihn nicht (Tabelleneigentümer sind von RLS ausgenommen, solange nicht
`FORCE ROW LEVEL SECURITY` gesetzt ist), und `GRANT`/`REVOKE` gegen
`authenticated` betreffen ihn nicht. Das Schema wurde laut Kopfzeile
(`supabase-schema.sql:2`) im SQL-Editor ausgeführt, damit ist `postgres` sowohl
Funktions- als auch Tabelleneigentümer. **Abfrage E in Abschnitt 7 bestätigt das
in einer Sekunde, und sie sollte vor Migration 3 laufen.**

**Wichtig, damit es so bleibt: `alter table ... force row level security` darf
nicht gesetzt werden.** Es steht in keiner der geprüften Dateien, und es kommt
in keiner der Migrationen unten vor. Wer es setzt, legt in einem Zug
`collect_fact_validated`, `collect_group_fact`, `collect_team_fact`,
`handle_fact_collected`, `handle_new_user`, `ai_consume` und `ai_refund` still.

Dieselbe Prüfung gilt für die Gruppen- und Team-Modi: `collect_group_fact`
(`2026-06-04_group_sessions.sql:257`) und `collect_team_fact`
(`2026-06-05_team_sessions.sql:509`) sind ebenfalls Definer-Funktionen und
schreiben ebenfalls in `collected_facts` und `profiles`. Sie laufen nach allen
drei Migrationen unverändert weiter. Der Gruppenmodus ist damit nach Migration 3
der **einzige** in der Produktion funktionierende Sammelweg, weil er als
einziger schon heute über eine RPC geht.

---

## 6. Die Migrationen

Format wie die vorhandenen Migrationen des Backend-Repos: eine Datei je Block
unter `03_Backend/migrations/`, einmalig im Supabase-SQL-Editor auszuführen,
idempotent geschrieben.

Alle Blöcke sind in eine Transaktion gefasst. `GRANT`, `REVOKE`,
`CREATE POLICY` und `CREATE OR REPLACE FUNCTION` sind in PostgreSQL
transaktional, ein `rollback;` statt `commit;` macht den Block spurlos
rückgängig. **Empfehlung: den Block zuerst mit `rollback;` am Ende ausführen,
die Diagnoseabfragen dazwischen ansehen, dann mit `commit;` wiederholen.**

---

### Migration 1: `profiles` spaltenweise sperren (E-24)

Dateiname im Backend-Repo: `2026-08-28_e24_profiles_column_grants.sql`

```sql
-- ============================================================================
-- FACT — E-24: coins und score_total sind vom Client direkt setzbar
-- ----------------------------------------------------------------------------
-- Die Policy "own profile" (supabase-schema.sql:141) begrenzt die ZEILE, nicht
-- die SPALTE. Ein WITH CHECK hilft nicht: PostgreSQL benutzt bei fehlendem
-- WITH CHECK ohnehin den USING-Ausdruck als Prüfung, und WITH CHECK sieht bei
-- UPDATE nur die neue Zeile, kann also "coins darf sich nicht ändern" gar
-- nicht ausdrücken. Spaltenschutz geht über Spaltenrechte.
--
-- Behebt zugleich D-8 (2026-06-20_ai_proxy.sql:61): das dortige
-- "revoke update (ai_used, ai_limit)" ist wirkungslos, solange das
-- tabellenweite UPDATE-Recht steht (Rechte in PostgreSQL sind additiv).
-- Es braucht dafür KEINE eigene Migration, Begründung in Abschnitt 6.1.
--
-- Bricht heute nichts: die einzigen Client-Schreibzugriffe sind
--   02_Frontend/app/api.jsx:255           -> username, username_changed_at
--   02_Frontend/app/screen-profil.jsx:693 -> show_real_name
--   flutter-fact .../supabase_auth_remote_data_source.dart:331 -> username
-- ============================================================================

begin;

-- 1. Tabellenweite Schreibrechte entziehen. Erst danach greifen Spaltenrechte.
--    Das dritte Ziel `public` ist die PUBLIC-Pseudorolle, NICHT das Schema.
--    Ein an PUBLIC vergebenes Recht hält jede Rolle der Datenbank, und ein
--    revoke gegen authenticated und anon entfernt es nicht. Ohne diese Zeile
--    bliebe die Lücke aus D-8 offen, falls im Projekt jemals
--    `grant all on all tables in schema public to public` gelaufen ist.
--    Kostenlos, weil kein Ablauf ein PUBLIC-Schreibrecht auf profiles braucht.
revoke insert, update, delete on public.profiles from authenticated, anon, public;

-- 2. Genau die drei Spalten zurückgeben, die ein Nutzer heute selbst setzt.
grant update (username, username_changed_at, show_real_name)
  on public.profiles to authenticated;

-- Nicht freigegeben und damit nur noch über SECURITY-DEFINER-Funktionen
-- schreibbar: id, name, hometown, coins, join_date, created_at, score_total,
-- ai_used, ai_limit.
--
-- Sobald ein Profil-Bearbeiten-Bildschirm entsteht, hier ergänzen:
--   grant update (name, hometown) on public.profiles to authenticated;

-- 3. Zeilengrenze weiterhin über RLS. Die FOR-ALL-Policy wird durch zwei
--    ausdrückliche ersetzt, damit im Katalog steht, was gilt. Der Insert- und
--    der Delete-Zweig entfallen bewusst: die Zeile legt der Trigger
--    on_auth_user_created an, gelöscht wird sie per ON DELETE CASCADE.
drop policy if exists "own profile" on public.profiles;

create policy "own profile select" on public.profiles
  for select using (auth.uid() = id);

create policy "own profile update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

commit;
```

**Rückabwicklung 1**, Dateiname `2026-08-28_e24_profiles_column_grants_down.sql`:

```sql
-- Stellt den Zustand von supabase-schema.sql:141 plus ai_proxy.sql:61 her.
-- Vorher Abfrage B und C aus Abschnitt 7 laufen lassen und die Ausgabe sichern,
-- falls im Projekt von der Supabase-Vorgabe abgewichen wurde.
begin;

drop policy if exists "own profile select" on public.profiles;
drop policy if exists "own profile update" on public.profiles;

create policy "own profile" on public.profiles
  for all using (auth.uid() = id);

grant insert, update, delete on public.profiles to authenticated, anon;

-- Absichtlich KEIN "grant ... to public": ein an PUBLIC vergebenes Recht wäre
-- ein neues Loch, kein wiederhergestellter Zustand. Ob im Ist-Zustand eines
-- bestand, sagt Abfrage B; nur dann und nur dann hier ergänzen.

-- Der ursprüngliche, wirkungslose Versuch aus dem AI-Proxy, der
-- Vollständigkeit halber. Ohne diese Zeile ist der Zustand danach sicherer
-- als vorher.
revoke update (ai_used, ai_limit) on public.profiles from authenticated, anon;

commit;
```

---

### 6.1 D-8: das wirkungslose Revoke im AI-Proxy, nachgeprüft

**Antwort in einem Satz: Migration 1 schließt es vollständig, eine zusätzliche
Migration wäre Doppelarbeit. Eine Zeile musste ergänzt werden, nämlich `public`
in der Revoke-Liste.**

Die Nachprüfung war verlangt, bevor irgendetwas gebaut wird. Hier ist sie.

#### Warum `2026-06-20_ai_proxy.sql:61` heute nichts bewirkt

Der Rechtebegriff in PostgreSQL kennt zwei Ebenen. Für ein `UPDATE` auf
bestimmte Spalten prüft der Server: hat die Rolle das **tabellenweite**
`UPDATE`-Recht? Dann ist sie durch, egal welche Spalte. Nur wenn dieses Recht
fehlt, wird auf **Spaltenrechte** heruntergeschaltet, und dann braucht sie ein
Spaltenrecht für **jede** geschriebene Spalte. Die beiden Ebenen sind additiv,
nicht schneidend: die feinere Ebene kann die gröbere nicht einschränken.

`revoke update (ai_used, ai_limit) on public.profiles from authenticated, anon;`
entfernt ein **Spaltenrecht**. Steht das tabellenweite `UPDATE` (und Supabase
vergibt es per Default-Privilegien an `anon` und `authenticated`), dann greift
die Spaltenebene nie, und die Anweisung ist ein Fehlschlag ohne Fehlermeldung.
PostgreSQL sagt dazu höchstens `WARNING: no privileges could be revoked for
column "ai_used"`, und ein `WARNING` im SQL-Editor liest niemand. Wichtig für
das Verständnis: das Revoke **spaltet das tabellenweite Recht nicht auf**. Es
entsteht kein Zwischenzustand „Tabelle ohne diese zwei Spalten".

Der Kommentar in `ai_proxy.sql:57-60` beschreibt also eine Absicht, die im
laufenden System nicht eingetreten ist. Praktische Folge: das
LLM-Gratiskontingent ist bis zur Ausführung von Migration 1 per
`update profiles set ai_used = 0 where id = <eigene uuid>` zurücksetzbar, und
zwar von jedem angemeldeten Nutzer für sein eigenes Konto. Die
Zeilen-Policy `own profile` erlaubt genau das. Das kostet echtes Geld, weil
dahinter Anthropic-Aufrufe stehen (`supabase/functions/llm/index.ts:62`).

#### Warum Migration 1 genau das erledigt

Migration 1 entzieht das **tabellenweite** `INSERT`, `UPDATE` und `DELETE` und
gibt danach ausschließlich drei Spalten zurück. Damit ist der Weg, der
`ai_proxy.sql:61` unterlaufen hat, weg:

| Frage | Nach Migration 1 |
|---|---|
| Hat `authenticated` tabellenweites `UPDATE` auf `profiles`? | nein, Zeile 1 der Migration |
| Hat `authenticated` ein Spaltenrecht auf `ai_used` oder `ai_limit`? | nein, sie stehen in keiner `GRANT`-Liste |
| Hat `anon` irgendetwas davon? | nein, weder tabellenweit noch spaltenweise |
| Hat PUBLIC noch etwas? | nein, seit `public` in der Revoke-Liste steht |
| Kommt jemand per `INSERT ... ON CONFLICT DO UPDATE` daran vorbei? | nein, das braucht `UPDATE` **und** `INSERT`, beide sind entzogen |
| Kommt jemand per `DELETE` plus Neuanlage daran vorbei? | nein, `DELETE` ist entzogen, und die Zeile legt nur der Trigger `on_auth_user_created` an |
| Schreiben `ai_consume` und `ai_refund` weiter? | ja, `SECURITY DEFINER` als Eigentümer, von Spaltenrechten nicht betroffen |

Eine zusätzliche Migration hätte nichts, was Migration 1 nicht schon tut. Eine
zweite Anweisung derselben Wirkung an anderer Stelle macht den Zustand nicht
sicherer, sondern schwerer nachvollziehbar, und beim Rückabwickeln entsteht
genau daraus ein Halbzustand.

#### Der eine Teil, der gefehlt hat

Die erste Fassung von Migration 1 entzog nur `from authenticated, anon`. Das
deckt die Supabase-Vorgabe ab, aber nicht den Fall, dass irgendwann jemand
`grant all on all tables in schema public to public` ausgeführt hat, etwa beim
Debuggen. Ein an PUBLIC vergebenes Recht hält **jede** Rolle, auch
`authenticated`, und es verschwindet nicht, wenn man es `authenticated` entzieht.
Die Revoke-Liste heißt deshalb jetzt `authenticated, anon, public`.

Das ist keine Vermutung ins Blaue, sondern die einzige mir bekannte Restlücke
derselben Klasse. Ob sie im Projekt tatsächlich besteht, ist unbekannt und muss
es auch nicht sein: das erweiterte Revoke kostet nichts und ist ohne Wirkung,
wenn kein PUBLIC-Recht existiert.

#### Wie man es empirisch abschließt statt zu glauben

Alle Argumente oben sind aus dem SQL abgeleitet, nicht gemessen; aus diesem
Repository wird keine Datenbank angefasst. Die Entscheidung braucht das auch
nicht, weil `has_column_privilege` eine einzige Antwort über **alle** Wege
gibt, tabellenweit, spaltenweise, über PUBLIC und über Rollenmitgliedschaften:

- **Vorher** Abfrage D (Abschnitt 7). Liefert `ai_used_updatable = true`, ist
  der Befund bestätigt und das Kontingent war bis dahin zurücksetzbar.
- **Nachher** Abfrage F. Muss `false, false, false` liefern. Tut sie das nicht,
  gibt es im Projekt einen Rechteweg, den dieses Dokument nicht kennt, und
  **dann** ist eine zusätzliche Anweisung fällig, gezielt auf den dann sichtbaren
  Empfänger.
- **Dauerhaft** Abfrage F als Regressionsprobe. Ein späteres, gut gemeintes
  `grant update on public.profiles to authenticated` macht in einer Zeile alles
  wieder auf, einschließlich `coins`, `score_total` und `ai_used`.

Die Datei `2026-06-20_ai_proxy.sql` wird **nicht** angefasst. Ausgeführte
Migrationen werden nicht umgeschrieben, sonst stimmt die Historie nicht mehr
mit der Datenbank überein. Ihre Zeile 61 bleibt als das stehen, was sie ist:
wirkungslos, aber ab Migration 1 auch nicht mehr nötig.

---

### Migration 2: `increment_coins` (E-06)

Dateiname: `2026-08-28_e06_increment_coins.sql`

Zwei Blöcke, getrennt ausführbar, **beide sind mit D-7 freigegeben und beide
laufen**. 2a schließt die Fremdkonten-Lücke, 2b setzt den Betragsdeckel. Wer nur
2a ausführt, hat einen sinnvollen Zwischenstand, aber nicht den beschlossenen.

2b ersetzt die Funktion aus 2a vollständig, es ist kein Zusatz. Beide Blöcke
nacheinander im selben Fenster auszuführen ist in Ordnung; die Zwischenversion
aus 2a existiert dann nur für Sekundenbruchteile.

```sql
-- ============================================================================
-- FACT — E-06: increment_coins prüft weder Konto noch Betrag
-- ----------------------------------------------------------------------------
-- BLOCK 2a: Konto-Bindung, Ausführrechte, search_path.
-- Bricht nichts: die PWA übergibt in api.jsx:157 immer die eigene userId
-- (app.jsx:714, :761, :769 reichen `userId` aus der Session durch).
-- ============================================================================

begin;

create or replace function public.increment_coins(uid uuid, amount integer)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'increment_coins: not authenticated' using errcode = '42501';
  end if;

  -- `uid` bleibt in der Signatur, damit alle bestehenden Aufrufer ohne
  -- Änderung weiterlaufen. Der Wert wird nicht mehr geglaubt: bisher konnte
  -- jeder angemeldete Nutzer jedem beliebigen Konto Coins schreiben, und die
  -- fremde UUID liefert get_leaderboard frei Haus (supabase-schema.sql:371).
  if uid is not null and uid <> v_uid then
    raise exception 'increment_coins: foreign account' using errcode = '42501';
  end if;

  if amount is null or amount = 0 then
    return;
  end if;

  update public.profiles
     set coins = coins + amount
   where id = v_uid;
end;
$$;

-- Nur angemeldete Nutzer dürfen rufen. Muster aus ai_proxy.sql:51-54.
revoke all on function public.increment_coins(uuid, integer) from public, anon;
grant execute on function public.increment_coins(uuid, integer) to authenticated;

commit;
```

```sql
-- ============================================================================
-- BLOCK 2b: Betragsdeckel, ohne Migration verstellbar.
--
-- ENTSCHEIDUNG D-7: Deckel ja, Höhe frei gewählt, Auflage "leicht anpassbar".
-- Gewählt: 500. Herleitung, Aufrufer-Nachweis und Bedienanleitung in
-- Abschnitt 4.1. Kurzfassung: der größte heute belegte legitime Betrag ist 270
-- (perfekter Quizlauf auf schwer, screen-challenge.jsx:4364), der kleinste -20
-- (dritter Kartenhinweis, screen-map.jsx:3542).
--
-- Die Höhe steht NICHT im Rumpf, sondern in der Datenbank-Einstellung
-- fact.coins_max_delta. Verstellen ohne Codeänderung:
--     alter database postgres set fact.coins_max_delta = '800';
-- Zurück auf den eingebauten Wert:
--     alter database postgres reset fact.coins_max_delta;
-- In beiden Fällen greift der neue Wert erst für neu aufgebaute Verbindungen,
-- also nach einem Neustart des Projekts (Poolbetrieb, Abschnitt 4.1).
--
-- NICHT GESETZT HEISST NICHT "KEIN DECKEL": current_setting(..., true) liefert
-- dann NULL, und "amount > NULL" ist NULL, also weder wahr noch falsch. Ein IF
-- auf NULL nimmt den ELSE-Zweig, die Prüfung fiele lautlos aus. Deshalb wird
-- der Wert als Text gelesen, validiert und sonst durch c_default_max ersetzt.
-- ============================================================================

begin;

create or replace function public.increment_coins(uid uuid, amount integer)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  -- Die einzige Zahl, die eine Migration braucht. Sie ist die Untergrenze der
  -- Verlässlichkeit, nicht der Betriebswert: sie greift, wenn die Einstellung
  -- fehlt oder Unsinn enthält.
  c_default_max constant integer := 500;

  v_uid uuid := auth.uid();
  v_raw text;
  v_max integer;
begin
  if v_uid is null then
    raise exception 'increment_coins: not authenticated' using errcode = '42501';
  end if;

  if uid is not null and uid <> v_uid then
    raise exception 'increment_coins: foreign account' using errcode = '42501';
  end if;

  if amount is null or amount = 0 then
    return;
  end if;

  -- Deckel lesen. Bewusst kein Cast auf ungeprüften Text: ein Tippfehler in
  -- der Einstellung würde sonst JEDE Coin-Buchung mit 22P02 abbrechen. Eine
  -- Verstellschraube darf die Anwendung nicht anhalten können.
  -- Die Regel erlaubt höchstens neun Ziffern, damit der Cast nicht überläuft.
  v_raw := coalesce(current_setting('fact.coins_max_delta', true), '');
  if v_raw ~ '^[0-9]{1,9}$' then
    v_max := v_raw::integer;
  else
    v_max := c_default_max;
  end if;
  if v_max < 1 then
    v_max := c_default_max;   -- '0' wäre ein Ausfall, kein Schutz
  end if;

  -- Richtung ausdrücklich in zwei Vergleichen, nicht über abs(). Zwei Gründe:
  --   1. Sicherheitsrelevant ist nur die obere Seite. Negative Beträge sind
  --      regulär (Hinweiskauf -10/-20, screen-map.jsx:3542) und müssen bleiben.
  --      Getrennte Zweige verhindern, dass jemand später "positiv und klein"
  --      daraus macht und den Hinweiskauf zerstört.
  --   2. abs(-2147483648) ist in PostgreSQL "integer out of range", also ein
  --      Fehler statt einer Ablehnung.
  if amount > v_max then
    raise exception 'increment_coins: credit % exceeds cap %', amount, v_max
      using errcode = '22003';
  end if;
  if amount < -v_max then
    raise exception 'increment_coins: debit % exceeds cap %', amount, v_max
      using errcode = '22003';
  end if;

  update public.profiles
     set coins = greatest(coins + amount, 0)
   where id = v_uid;
end;
$$;

commit;
```

**Die Einstellung setzen** (eigene Anweisung, gehört nicht in die
Migrationsdatei, weil `500` ohne sie bereits gilt):

```sql
-- Optional. Nur nötig, wenn ein anderer Wert als 500 gelten soll.
alter database postgres set fact.coins_max_delta = '800';

-- Falls das mit "must be owner of database" abgelehnt wird, greift dieselbe
-- Einstellung auf der Login-Rolle von PostgREST. Deckt die API ab, nicht den
-- SQL-Editor:
-- alter role authenticator set fact.coins_max_delta = '800';
```

**Zur Klammer `greatest(..., 0)` in Block 2b:** sie verhindert einen negativen
Kontostand. Das ist eine **Verhaltensänderung**, keine reine Absicherung. Heute
prüft die PWA die Deckung eines Hinweiskaufs im Client
(`puzzle-sheet.jsx:573` rechnet netto, `screen-map.jsx:3542` prüft nicht) und
könnte den Saldo theoretisch unter Null drücken. Nach der Änderung wird das
still auf 0 gekappt statt zu scheitern. Wer das nicht will, lässt `greatest` weg
und schreibt `set coins = coins + amount`.

Die Richtung dieser Nachsicht ist zu Gunsten des Nutzers: ein Hinweiskauf ohne
Deckung kostet ihn dann weniger als `-10`, nie mehr. Ein Missbrauch entsteht
daraus nicht, weil niemand durch das Ausgeben von Coins reicher wird.

**Rückabwicklung 2**, Dateiname `2026-08-28_e06_increment_coins_down.sql`:

```sql
-- Stellt supabase-schema.sql:86-89 wörtlich wieder her.
begin;

create or replace function public.increment_coins(uid uuid, amount integer)
returns void language sql security definer as $$
  update public.profiles set coins = coins + amount where id = uid;
$$;

grant execute on function public.increment_coins(uuid, integer)
  to public, anon, authenticated;

commit;
```

Hinweis: `create or replace function` behält Besitzer und bestehende Rechte, der
Wechsel von `plpgsql` zurück auf `sql` ist zulässig. Das `grant` am Ende nimmt
das `revoke` aus Block 2a zurück.

**Rückabwicklung nur für Block 2b**, Dateiname
`2026-08-28_e06_increment_coins_cap_down.sql`. Nimmt den Deckel zurück und
behält die Konto-Bindung aus Block 2a. Das ist der Weg, wenn sich der Deckel als
zu eng erweist und niemand die Höhe nachziehen will:

```sql
begin;

create or replace function public.increment_coins(uid uuid, amount integer)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'increment_coins: not authenticated' using errcode = '42501';
  end if;
  if uid is not null and uid <> v_uid then
    raise exception 'increment_coins: foreign account' using errcode = '42501';
  end if;
  if amount is null or amount = 0 then
    return;
  end if;

  update public.profiles
     set coins = coins + amount
   where id = v_uid;
end;
$$;

commit;
```

Danach, falls die Einstellung gesetzt wurde, sie ebenfalls entfernen. Das ist
ohne den Funktionsrumpf oben wirkungslos, hinterlässt aber sonst einen Wert, den
der nächste Leser für aktiv hält:

```sql
alter database postgres reset fact.coins_max_delta;
-- bzw., falls über die Rolle gesetzt:
-- alter role authenticator reset fact.coins_max_delta;
```

**Reihenfolge beim Zurückrollen beachten.** Zuerst die Funktion ersetzen, dann
die Einstellung zurücksetzen. Andersherum gilt zwischenzeitlich der Ausfallwert
`500`, und das ist genau der Zustand, den man gerade loswerden will.

---

### Migration 3: `collected_facts` (E-23)

Dateiname: `2026-08-28_e23_collected_facts.sql`

> **Nicht ausführen, solange die PWA `api.jsx:145` benutzt.** Siehe Abschnitt 4.
> Dieser Block ist fertig, damit er bereitliegt, nicht damit er heute läuft.

```sql
-- ============================================================================
-- FACT — E-23: der Client fügt direkt in collected_facts ein
-- ----------------------------------------------------------------------------
-- Danach ist collect_fact_validated (supabase-schema.sql:93) der einzige Weg
-- für Einzelsammeln, collect_group_fact und collect_team_fact bleiben für die
-- Gruppenmodi. Der Trigger on_fact_collected (:343) hängt an der Tabelle und
-- feuert bei jedem dieser Inserts unverändert weiter.
--
-- VORAUSSETZUNG: Abfrage E aus Abschnitt 7 hat bestätigt, dass die
-- SECURITY-DEFINER-Funktionen demselben Rollen-Eigentümer gehören wie die
-- Tabelle und dass FORCE ROW LEVEL SECURITY nicht gesetzt ist.
--
-- BRECHENDE ÄNDERUNG für 02_Frontend/app/api.jsx:145. Erst nach dem
-- PWA-Release ausführen, der dort auf die RPC umstellt.
-- ============================================================================

begin;

revoke insert, update, delete on public.collected_facts from authenticated, anon;

drop policy if exists "own collected" on public.collected_facts;

create policy "own collected select" on public.collected_facts
  for select using (auth.uid() = user_id);

commit;
```

**Optionaler Block 3b, dieselbe Härtung für die RPC selbst.** Er behebt einen
Defekt derselben Klasse wie E-06 Punkt 2: `collect_fact_validated` nimmt
`p_user_id` vom Client entgegen und vergleicht ihn mit nichts, ein angemeldeter
Nutzer kann also für ein fremdes Konto sammeln. Zusätzlich sind
`collected_facts`, `facts` und `profiles` im Rumpf **unqualifiziert**
(`supabase-schema.sql:103,107,124,125`), was ohne gesetzten `search_path`
theoretisch über eine temporäre Tabelle schattenbar ist.

```sql
-- Ändert die 150-Meter-Logik NICHT. E-07 (die Position kommt weiterhin vom
-- Client und ist fälschbar) bleibt offen und ist hier nicht Gegenstand.
begin;

create or replace function public.collect_fact_validated(
  p_user_id  uuid,
  p_fact_id  bigint,
  p_user_lat numeric,
  p_user_lng numeric
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_fact    record;
  v_dist_m  numeric;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;
  if p_user_id is not null and p_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'reason', 'foreign_account');
  end if;

  if exists (select 1 from public.collected_facts
              where user_id = v_user_id and fact_id = p_fact_id) then
    return jsonb_build_object('ok', false, 'reason', 'already_collected');
  end if;

  select lat, lng into v_fact from public.facts where id = p_fact_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'fact_not_found');
  end if;

  v_dist_m := 6371000 * acos(
    least(1.0,
      cos(radians(p_user_lat)) * cos(radians(v_fact.lat)) *
      cos(radians(v_fact.lng) - radians(p_user_lng)) +
      sin(radians(p_user_lat)) * sin(radians(v_fact.lat))
    )
  );

  if v_dist_m > 150 then
    return jsonb_build_object('ok', false, 'reason', 'too_far',
                              'dist_m', round(v_dist_m));
  end if;

  insert into public.collected_facts (user_id, fact_id)
    values (v_user_id, p_fact_id);
  update public.profiles set coins = coins + 10 where id = v_user_id;

  return jsonb_build_object('ok', true, 'coins_earned', 10);
end;
$$;

revoke all on function public.collect_fact_validated(uuid, bigint, numeric, numeric)
  from public, anon;
grant execute on function public.collect_fact_validated(uuid, bigint, numeric, numeric)
  to authenticated;

commit;
```

**Rückabwicklung 3**, Dateiname `2026-08-28_e23_collected_facts_down.sql`:

```sql
begin;

drop policy if exists "own collected select" on public.collected_facts;

create policy "own collected" on public.collected_facts
  for all using (auth.uid() = user_id);

grant insert, update, delete on public.collected_facts to authenticated, anon;

commit;
```

**Rückabwicklung 3b** (nur nötig, wenn Block 3b lief): der Funktionsrumpf aus
`supabase-schema.sql:93-129` wörtlich, plus
`grant execute on function public.collect_fact_validated(uuid, bigint, numeric, numeric) to public, anon, authenticated;`.

---

## 7. Diagnoseabfragen

Alle rein lesend. **A bis E vor der ersten Migration ausführen und die Ausgabe
sichern**, sie ist die Grundlage jeder Rückabwicklung. F bis J danach zur
Kontrolle.

```sql
-- A) Policies im Ist-Zustand
select tablename, policyname, cmd, qual, with_check
  from pg_policies
 where schemaname = 'public'
   and tablename in ('profiles', 'collected_facts')
 order by tablename, policyname;

-- B) Tabellenweite Rechte. Steht hier UPDATE für authenticated, dann ist
--    Befund 4 bestätigt und ai_proxy.sql:61 war wirkungslos.
--    'PUBLIC' ist mitgeprüft (D-8, Abschnitt 6.1): ein an PUBLIC vergebenes
--    Recht hält jede Rolle und ist an dieser Stelle sonst unsichtbar.
select table_name, grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema = 'public'
   and table_name in ('profiles', 'collected_facts')
   and grantee in ('anon', 'authenticated', 'PUBLIC')
 order by table_name, grantee, privilege_type;

-- C) Spaltenrechte
select grantee, column_name, privilege_type
  from information_schema.column_privileges
 where table_schema = 'public' and table_name = 'profiles'
   and grantee in ('anon', 'authenticated', 'PUBLIC')
 order by grantee, column_name;

-- D) Die eine Frage aus Befund 4, direkt beantwortet.
--    true = das LLM-Kontingent ist heute per UPDATE zurücksetzbar
select has_column_privilege('authenticated','public.profiles','ai_used','UPDATE')
         as ai_used_updatable,
       has_column_privilege('authenticated','public.profiles','coins','UPDATE')
         as coins_updatable,
       has_column_privilege('authenticated','public.profiles','score_total','UPDATE')
         as score_updatable;

-- E) Voraussetzung für Migration 3: gehören Tabelle und Definer-Funktionen
--    derselben Rolle, und ist FORCE RLS aus?
select c.relname,
       pg_get_userbyid(c.relowner) as owner,
       c.relrowsecurity            as rls_enabled,
       c.relforcerowsecurity       as rls_forced
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('profiles', 'collected_facts');

select p.proname,
       pg_get_userbyid(p.proowner) as owner,
       p.prosecdef                 as security_definer,
       p.proconfig                 as settings
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('increment_coins', 'collect_fact_validated',
                     'handle_fact_collected', 'handle_new_user',
                     'collect_group_fact', 'collect_team_fact',
                     'tag_endpoint', 'ai_consume', 'ai_refund');
```

Nachkontrolle. Diese müssen **nach** den jeweiligen Migrationen gelten:

```sql
-- F) nach Migration 1: muss (false, false, false) liefern
select has_column_privilege('authenticated','public.profiles','coins','UPDATE'),
       has_column_privilege('authenticated','public.profiles','score_total','UPDATE'),
       has_column_privilege('authenticated','public.profiles','ai_used','UPDATE');

-- G) nach Migration 1: muss (true, true, true) liefern,
--    sonst bricht die Registrierung
select has_column_privilege('authenticated','public.profiles','username','UPDATE'),
       has_column_privilege('authenticated','public.profiles','username_changed_at','UPDATE'),
       has_column_privilege('authenticated','public.profiles','show_real_name','UPDATE');

-- H) nach Migration 3: muss false liefern
select has_table_privilege('authenticated', 'public.collected_facts', 'INSERT');

-- I) nach Migration 2b: welcher Deckel gilt?
--    Erste Spalte = Wert in DIESER Sitzung. Ist sie NULL, greift der
--    eingebaute Ausfallwert 500; das ist ein gültiger Zustand, kein Fehler.
select current_setting('fact.coins_max_delta', true) as wert_in_dieser_sitzung;

--    Und was dauerhaft hinterlegt ist. Leeres Ergebnis = nichts gesetzt.
select d.datname, r.rolname, sr.setconfig
  from pg_db_role_setting sr
  left join pg_database d on d.oid = sr.setdatabase
  left join pg_roles    r on r.oid = sr.setrole;

-- J) nach Migration 2: hängen die Ausführrechte richtig?
--    Erwartet: authenticated true, anon false, PUBLIC false.
select has_function_privilege('authenticated',
         'public.increment_coins(uuid, integer)', 'EXECUTE') as auth_darf,
       has_function_privilege('anon',
         'public.increment_coins(uuid, integer)', 'EXECUTE') as anon_darf;
```

---

## 8. Negativtests

`docs/engineering/security.md`, Abschnitt 4, verlangt zu jeder geschützten
Tabelle Positiv- **und** Negativtests. Diese hier sind formuliert, aber **nicht
ausgeführt**, weil aus diesem Repository keine Verbindung zu einem
Supabase-Projekt aufgebaut wird. Sie gehören in eine Testdatenbank, nicht in die
Produktion. Zwei angelegte Testkonten `A` und `B`, Aufrufe mit deren jeweiligem
Session-Token.

| # | Handlung | Vor der Migration | Danach erwartet |
|---|---|---|---|
| 1 | `A` setzt `username` im eigenen Profil | erlaubt | erlaubt |
| 2 | `A` setzt `show_real_name` im eigenen Profil | erlaubt | erlaubt |
| 3 | `A` setzt `coins = 999999` im eigenen Profil | **erlaubt** | Fehler `42501` |
| 4 | `A` setzt `score_total = 999` im eigenen Profil | **erlaubt** | Fehler `42501` |
| 5 | `A` setzt `ai_used = 0` im eigenen Profil | **vermutlich erlaubt** (Befund 4, D-8) | Fehler `42501` |
| 6 | `A` setzt `username` bei `B` | abgelehnt | abgelehnt |
| 7 | Registrierung: neues Konto, dann `username` setzen | erlaubt | erlaubt |
| 8 | `A` ruft `increment_coins(A, 50)` | erlaubt | erlaubt |
| 9 | `A` ruft `increment_coins(A, -10)` | erlaubt | erlaubt |
| 10 | `A` ruft `increment_coins(B, 5000)` | **erlaubt** | Fehler `foreign account` |
| 11 | `A` ruft `increment_coins(A, 10000000)` | **erlaubt** | Fehler `22003`, `credit ... exceeds cap` |
| 12 | Nicht angemeldet, `increment_coins` | erlaubt, wirkungslos | Fehler, kein `EXECUTE` |
| 13 | `A` fügt `collected_facts(A, 1)` ein | **erlaubt** | Fehler `42501`, Migration 3 |
| 14 | `A` ruft `collect_fact_validated` in Reichweite | erlaubt, Trigger feuert | unverändert, Trigger feuert |
| 15 | Zu 14: `score_total`, `user_city_scores`, `user_trophies` gewachsen | ja | **ja** |
| 16 | `A` liest die eigenen `collected_facts` | erlaubt | erlaubt |

Test 15 ist der wichtige: er belegt Abschnitt 5 empirisch. Läuft er rot, ist die
Eigentümer-Annahme falsch und Migration 3 muss zurückgerollt werden.

### Zusätzliche Fälle aus D-7 (Deckel) und D-8 (Revoke)

Alle Aufrufe mit dem Session-Token von `A`, sofern nicht anders vermerkt. Der
Ausfallwert `500` gilt, solange `fact.coins_max_delta` nicht gesetzt ist.

| # | Handlung | Vor der Migration | Danach erwartet | Prüft |
|---|---|---|---|---|
| 17 | `increment_coins(B, 50)`, `B` ist ein fremdes Konto | **erlaubt, Coins landen bei `B`** | Fehler `42501`, `foreign account`, `B.coins` unverändert | Fremdkonto |
| 18 | `increment_coins(null, 50)` | schreibt nirgends hin (`where id = null`) | erlaubt, Coins landen bei `A` | Fremdkonto, Nullfall |
| 19 | `increment_coins(A, 270)`, größter belegter Echtbetrag | erlaubt | **erlaubt** | Deckel bricht nichts |
| 20 | `increment_coins(A, 500)`, genau der Deckel | erlaubt | **erlaubt**, die Grenze ist einschließend | Deckelrand |
| 21 | `increment_coins(A, 501)` | erlaubt | Fehler `22003`, `credit 501 exceeds cap 500` | Deckel oben |
| 22 | `increment_coins(A, -20)`, dritter Kartenhinweis | erlaubt | **erlaubt**, Saldo sinkt um 20 | negative Buchung bleibt zulässig |
| 23 | `increment_coins(A, -500)` | erlaubt | **erlaubt** | untere Grenze einschließend |
| 24 | `increment_coins(A, -501)` | erlaubt | Fehler `22003`, `debit -501 exceeds cap 500` | Deckel unten |
| 25 | `increment_coins(A, -50)` bei Saldo `10` | Saldo wird `-40` | Saldo wird `0` | `greatest(..., 0)`, siehe Hinweis zu Block 2b |
| 26 | `alter database postgres set fact.coins_max_delta = '800';`, Projekt neu starten, dann `increment_coins(A, 700)` | entfällt | **erlaubt** | Deckel verstellbar |
| 27 | Danach `increment_coins(A, 801)` | entfällt | Fehler `22003`, `exceeds cap 800` | neuer Wert greift wirklich |
| 28 | `alter database postgres reset fact.coins_max_delta;`, Neustart, dann `increment_coins(A, 700)` | entfällt | Fehler `22003`, `exceeds cap 500` | **fehlende Einstellung heißt nicht „kein Deckel"** |
| 29 | `alter database postgres set fact.coins_max_delta = 'abc';`, Neustart, dann `increment_coins(A, 50)` | entfällt | **erlaubt**, es gilt 500 | Unsinn kappt nicht die Anwendung |
| 30 | Zu 29: `increment_coins(A, 700)` | entfällt | Fehler `22003`, `exceeds cap 500` | Ausfallwert greift statt „kein Deckel" |
| 31 | `A` setzt `ai_used = 0` per `update profiles` auf dem eigenen Profil (D-8) | **erlaubt, LLM-Kontingent zurückgesetzt** | Fehler `42501` | D-8, Kernfall |
| 32 | `A` setzt `ai_limit = 9999` auf dem eigenen Profil | **erlaubt** | Fehler `42501` | D-8 |
| 33 | `A` schreibt `insert into profiles (id, ai_used) values (A, 0) on conflict (id) do update set ai_used = 0` | erlaubt | Fehler `42501` | D-8, Umweg über Upsert |
| 34 | `A` löscht die eigene `profiles`-Zeile | erlaubt | Fehler `42501` | D-8, Umweg über Neuanlage |
| 35 | Nicht angemeldet (`anon`), `update profiles set ai_used = 0` | scheitert an der Policy, nicht am Recht | Fehler `42501` | D-8, `anon` |
| 36 | `A` ruft die Edge Function `llm` elfmal, Limit ist 10 | elfter Aufruf scheitert, danach per `update` zurücksetzbar | elfter Aufruf scheitert und **bleibt** gescheitert | D-8, Wirkung im Ablauf |

**Test 28 und 30 sind die entscheidenden für D-7.** Sie sind die einzigen, die
den Unterschied zwischen „Ausfallwert greift" und „Prüfung fällt lautlos aus"
sichtbar machen. Läuft 28 oder 30 grün im Sinne von „Buchung geht durch", ist
die `NULL`-Behandlung kaputt und der Deckel existiert nur auf dem Papier.

**Test 36 ist der entscheidende für D-8**, weil er als einziger nicht die
Berechtigung prüft, sondern die Wirkung: er beantwortet die Frage, ob das
Gratiskontingent tatsächlich hält. Er kostet echte Anthropic-Aufrufe und gehört
deshalb in eine Testumgebung mit eigenem Schlüssel oder ist bewusst
auszulassen; die Tests 31 bis 35 decken den Mechanismus vollständig ab.

**Zu den Tests 26 bis 30: der Neustart ist kein Beiwerk.** Ohne ihn liest die
bestehende Verbindung den alten Wert weiter (Poolbetrieb, Abschnitt 4.1), und
der Test misst dann nicht den Deckel, sondern die Verbindungsdauer. Wer die
Tests direkt per `psql` fährt statt über die API, baut für jeden Fall eine neue
Verbindung auf und braucht den Neustart nicht.

---

## 9. Was danach immer noch offen ist

Damit niemand die drei Migrationen für eine abgeschlossene Absicherung hält:

- **E-07 bleibt offen.** `collect_fact_validated` prüft die 150 Meter gegen eine
  Position, die der Client schickt. Ein gefälschtes GPS reicht weiter aus.
  Gleiches gilt für `collect_group_fact` und `collect_team_fact`.
- **Die Coin-Ökonomie bleibt clientbestimmt.** Nach Migration 2 kann ein Nutzer
  nur noch für das eigene Konto und nur noch bis `500` je Aufruf buchen. Er
  bestimmt die Höhe innerhalb dieses Rahmens weiterhin selbst, weil die PWA sie
  im Client rechnet, und er bestimmt die **Anzahl** der Aufrufe ohnehin. Der
  Deckel begrenzt die Schrittweite, nicht die Summe: wer `500` in einer Schleife
  bucht, kommt weiterhin beliebig hoch, nur langsamer und deutlich sichtbarer im
  Zugriffsprotokoll. Eine echte Behebung heißt: Server berechnet den Betrag,
  Client meldet nur das Ereignis. Das ist ein Umbau der PWA und der Rätsel- und
  Quiz-Logik, keine Migration.
- **Es gibt keine Ratenbegrenzung für `increment_coins`.** Das ist die
  Ergänzung, die den Deckel erst scharf macht, und sie ist bewusst nicht Teil
  dieser Migrationen. Ohne sie ist `500` eine Schrittweitenbegrenzung, kein
  Budget.
- **Der Deckelwert ist ein Betriebsschalter, keine Sicherheitsgrenze gegen
  jemanden mit Datenbankzugang.** Wer eine direkte SQL-Sitzung hat, ändert
  ohnehin `coins` unmittelbar. `fact.coins_max_delta` schützt gegen den
  untrusted Client, gegen sonst nichts.
- **Es gibt kein Buchungsjournal.** `coins` ist ein Saldo ohne Historie. Nach
  einem Missbrauch lässt sich weder feststellen, wann er stattfand, noch
  zurückrechnen. `docs/engineering/security.md`, Abschnitt 11, verlangt für
  sicherheitsrelevante Funktionen ein Erkennungssignal. Für die Coins gibt es
  keines. Eine Tabelle `coin_ledger(user_id, delta, reason, created_at)`,
  beschrieben ausschließlich von den Definer-Funktionen, wäre der nächste
  Schritt und ist eine eigene Entscheidung.
- **`raw_user_meta_data` bleibt clientbeschreibbar** und speist über
  `handle_new_user` die Spalten `name` und `hometown`. Das ist bekannt
  (`REBUILD_STATUS.md:122`) und durch keine der drei Migrationen berührt.

---

## 10. Auswirkung auf diese App

**Keine.** Nach allen drei Migrationen scheitert in `lib/` keine Stelle.

> **Nachtrag vom 02.09.2026 zur Methode, nicht zum Ergebnis.** Ein Griff nach
> `.rpc(` findet den **einzigen** RPC-Aufruf dieses Repositories nicht: er heißt
> `_client.rpc<Object?>(`, das Typargument steht zwischen Name und Klammer. Das
> Ergebnis oben bleibt richtig, nachgeprüft mit
> `grep -rnE "\.(from|rpc)\s*(<[^>]*>)?\s*\(" lib/`, aber wer die Prüfung
> wiederholt, nimmt dieses Muster und nicht das naheliegende.

Belegt durch die vollständige Liste der Schreibzugriffe dieses Repositories auf
Supabase, ermittelt über `.insert(`, `.upsert(`, `.update(`, `.delete(` und
`.rpc(` in `lib/` ohne generierte Dateien. Es gibt genau einen:

- `lib/features/identity/data/datasources/remote/supabase_auth_remote_data_source.dart:329-332`,
  `update({username}).eq('id', userId)`. Die Spalte `username` bleibt in
  Migration 1 ausdrücklich freigegeben.

Lesend zusätzlich: `check_username` über RPC (`:295-298`) und `facts` über
`SupabaseFactRemoteDataSource` (`:46,57`). Beide von den Migrationen nicht
berührt.

Der Kommentar in `supabase_auth_remote_data_source.dart:315-319` beschreibt E-24
richtig und bleibt inhaltlich gültig; nach Migration 1 wäre eine Aktualisierung
sinnvoll, aber das ist ein eigener Auftrag und wird hier nicht ausgeführt.

**Was Phase 2 beachten muss:** sobald das Sammeln gebaut wird, geht es über
`collect_fact_validated`, nicht über ein `insert` in `collected_facts`. Der alte
Port hat beide Wege angebunden (`08_Flutter/lib/services/supabase_service.dart:119`
und `:127`) und den unsicheren im Zweifel benutzt. Dieser Fehler darf sich nicht
wiederholen.

---

## 11. Nachtrag 02.09.2026: E-52, E-53 und E-55

**Was dieser Nachtrag ist.** Drei weitere Migrationen, für drei Befunde aus
`backend-inventory.md`, Abschnitt 3. Er steht in derselben Datei, weil er
dieselben Tabellen, dieselben Definer-Funktionen und dieselbe Rechtelogik
betrifft wie die Migrationen 1 bis 3. Die Abschnitte 0 bis 10 sind unverändert;
nichts hier ersetzt etwas dort. Die Nummerierung läuft weiter: **Migration 4
(E-52), Migration 5 (E-53), Migration 6 (E-55)**.

**Dieselben Grenzen wie oben.** Nichts davon wurde ausgeführt, auch nicht
lesend. Das Backend liegt im anderen Repository und wird von hier nicht
verändert. Zeilenangaben beziehen sich auf das Referenz-Repository, nachgeprüft
am 02.09.2026.

**Und dieselbe Vorbedingung, verschärft.** `backend-inventory.md`, Abschnitt 2:
es gibt kein Migrationssystem, keine Ledger-Tabelle, und zwei Funktionen sind
doppelt definiert. Aus dem Repository ist nicht zu sehen, was in der laufenden
Datenbank steht. Alle drei Blöcke unten sind deshalb idempotent, sie geben nach
jedem `revoke` ausdrücklich zurück, was gebraucht wird, statt auf einen
vorhandenen Grant zu vertrauen, und die Ausführrechte werden über eine Schleife
auf `pg_proc` gesetzt statt über eine Liste von Signaturen. Warum die Schleife
und nicht die Liste, steht in 11.4.

### 11.0 Acht Befunde, die diesen Auftrag korrigieren

Wie Abschnitt 0: die Ergebnisse der Prüfung am echten SQL stehen vor den
Migrationen, weil jedes einzelne ändert, was zu tun ist.

**1. Für `INSERT` prüft ein `WITH CHECK` die Spalte sehr wohl.** Der Auftrag
verlangte für E-53 den Umweg aus Abschnitt 3, also Spaltenrechte. Der ist hier
nicht nötig und wäre sogar schädlich. Abschnitt 3 begründet die Spaltenrechte
mit `UPDATE`: dort sieht `WITH CHECK` nur die neue Zeile und kann „darf sich
nicht ändern" nicht ausdrücken. Bei `INSERT` gibt es keine alte Zeile, und
`is_approved is not true` ist eine vollständige, exakte Bedingung.
**Schädlich wäre der Umweg, weil die PWA die Spalte namentlich mitschickt**
(`02_Frontend/app/api.jsx:176`, `is_approved: false`). Ein
`revoke insert (is_approved)` würde diesen Aufruf mit `42501` abweisen, obwohl
er inhaltlich richtig ist. Die Policy lässt ihn durch.

**2. „Der Eigentümer darf seine Zeile bearbeiten" beschreibt keinen Zustand,
den es gibt.** Auf `public.facts` existieren genau zwei Policies,
`read facts` (`supabase-schema.sql:145-146`) und `insert own fact`
(`:149-150`). Es gibt **keine** `UPDATE`- und keine `DELETE`-Policy, also kann
ein Nutzer seinen Fakt heute nicht ändern und nicht löschen, unabhängig von
allen Spaltenrechten. Migration 5 öffnet das Bearbeiten deshalb **nicht**:
das wäre eine neue Fähigkeit, kein Sicherheitsfix, und sie brächte genau die
Frage mit, die Abschnitt 3 für `profiles` schon beantwortet hat. Das Rezept für
später steht in 11.5, ausgeschrieben und ungenutzt.

**3. E-52 ist zu zwei Dritteln bereits geschrieben, und der eine offene Teil ist
nicht blockiert.** E-52 nennt drei Funktionen. `increment_coins` erledigt
**Block 2a**, `collect_fact_validated` erledigt **Block 3b**, beide oben, beide
mit derselben Konto-Bindung und demselben `revoke ... from public, anon`.
Migration 4 fügt deshalb nur `unlock_trophy` hinzu und schließt die
Ausführrechte des restlichen Funktionsbestands. **Wichtig, weil es leicht
übersehen wird: Block 3b ist nicht durch den PWA-Release blockiert.** Blockiert
ist Block 3**a**, der Insert-Weg. `collect_fact_validated` wird in der PWA von
niemandem gerufen (Abschnitt 2, „Aufrufe von `collect_fact_validated`"), also
kann 3b sofort laufen und E-52 für diese Funktion sofort schließen.

**4. Ein pauschales Revoke gegen `anon` bricht die Registrierung, und zwar in
beiden Clients.** `check_username` wird **vor** der Anmeldung gerufen, während
der Nutzer den Namen eintippt: PWA `screen-auth.jsx:600`, dieses Repository
`lib/features/identity/presentation/notifiers/username_check_notifier.dart:144`
über `supabase_auth_remote_data_source.dart:295`. Zu diesem Zeitpunkt gibt es
kein Konto und keine Sitzung, der Aufruf läuft als `anon`. Wer E-52 als
„revoke execute on all functions in schema public from anon" liest, nimmt
beiden Clients die Namensprüfung weg, und zwar **stillschweigend**: die PWA
fängt den Fehler ab und bleibt auf `idle` (`screen-auth.jsx:601`), dieses
Repository ebenso (`username_check_notifier.dart:142-151`, Kommentar „ein
Fehlschlag der Prüfung ist kein Fehler des Nutzers"). Der Nutzer bekommt dann
bei der Registrierung eine Unique-Verletzung statt eines Hinweises.
Migration 4 gibt `check_username` deshalb ausdrücklich an `anon` frei, statt
sich auf den Standard zu verlassen.

**5. Ein Trophäenschlüssel enthält einen Umlaut.** Die naheliegende Prüfung
einer Zeichenklasse auf `p_trophy_key` wäre falsch: `nachtschwärmer` ist ein
echter Schlüssel (`wallet-colors.jsx:133`, gerufen in `app.jsx:726`), und die
Stadt-Trophäen des Triggers heißen `<stadt>_first` mit `lower(city)` als
Präfix, also `münchen_first` (`supabase-schema.sql:275-279`). Migration 4 prüft
deshalb nur die **Länge**. Eine Schlüsselliste in der Datenbank wäre die
richtige Prüfung, ist aber eine neue Tabelle und damit eine Entscheidung, keine
Migration.

**6. E-55 macht die Schreibseite nicht zu, sondern kleiner.** Nach Migration 6
kann kein Client mehr in `user_trophies` und `user_city_scores` schreiben.
`unlock_trophy` bleibt aber der reguläre Weg der PWA (`api.jsx:243`), und der
Client entscheidet dort weiter, **welche** Trophäe er sich holt: `app.jsx:551`
schreibt jeden Schlüssel, den `rnkMaybeUnlock` bekommt, und die Aufrufer sind
clientseitige Bedingungen wie `rnkH >= 22` (`app.jsx:726`). Migration 6
verkleinert den Angriff also von „jeder Wert in jeder eigenen Zeile beider
Tabellen" auf „jeder Trophäenschlüssel für das eigene Konto". Für
`user_city_scores` ist die Behebung vollständig, weil dort **kein** Client
schreibt. Für `user_trophies` ist sie es nicht, und das ist E-49, nicht E-55.

**7. `_is_group_member` darf das Ausführrecht nicht verlieren.** Die Funktion
ist ein Definer-Helfer, sieht wie interner Kram aus und steckt in **drei
RLS-Policies** (`2026-06-04_group_sessions_rls_fix.sql:30-47`).
Policy-Ausdrücke werden mit den Rechten der **abfragenden** Rolle ausgewertet,
nicht mit denen des Tabelleneigentümers. Wer ihr das `EXECUTE` für
`authenticated` entzieht, macht jedes Lesen von `group_sessions`,
`group_participants` und `group_collects` zu einem „permission denied for
function _is_group_member". Der Gruppenmodus wäre tot. Migration 4 nimmt sie
darum ausdrücklich aus der Helfer-Liste heraus.

**8. Eine Zeilenangabe der Bestandsaufnahme stimmt nicht.** E-53 nennt
`api.jsx:167` für `is_approved: false`. Dort steht `kategorie`. Die Zuweisung
ist `api.jsx:176`, im selben `insert`-Objekt (`:165-177`). Der Befund selbst ist
richtig, nur der Zeiger nicht.

### 11.1 Ist-Zustand am echten SQL

#### E-52: `unlock_trophy` und die Ausführrechte

`03_Backend/supabase-schema.sql:514-519`

```sql
CREATE OR REPLACE FUNCTION public.unlock_trophy(p_user_id UUID, p_trophy_key TEXT)
RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
  INSERT INTO public.user_trophies (user_id, trophy_key)
    VALUES (p_user_id, p_trophy_key)
    ON CONFLICT DO NOTHING;
$$;
```

Vier Defekte in fünf Zeilen: die Kennung kommt vom Aufrufer und wird mit nichts
verglichen, der Schlüssel wird nicht geprüft, `search_path` ist nicht gesetzt,
und ein Ausführrecht wurde nie entzogen. Die fremde UUID liefert
`get_leaderboard` mit (`supabase-schema.sql:371`), und `get_leaderboard` ist
selbst ohne Anmeldung erreichbar.

Die Rechtelage ist nachgezählt: im gesamten `03_Backend/` gibt es **fünf**
`GRANT`- oder `REVOKE`-Zeilen, alle in `2026-06-20_ai_proxy.sql:51-54,61`, alle
für `ai_consume`, `ai_refund` und die zwei AI-Spalten. Für die anderen 28
Funktionen gilt der PostgreSQL-Standard, und der ist `EXECUTE` an `PUBLIC`.
`PUBLIC` ist jede Rolle der Datenbank, `anon` eingeschlossen. Die Aussage aus
E-52 ist damit aus den Dateien belegt; **in der Datenbank ist sie mit Abfrage K
in einer Sekunde zu bestätigen**, und nur die Datenbank zählt.

#### E-53: die Freigabespalte fehlt in der Insert-Policy

`03_Backend/supabase-schema.sql:148-150`

```sql
-- Facts: authenticated users insert user-created facts
create policy "insert own fact" on public.facts
  for insert with check (auth.uid() = created_by and is_user_created = true);
```

`is_approved` (`:33`, `boolean default false`, nullable) kommt nicht vor. Der
Kommentar in `api.jsx:161-163` beschreibt die Absicht („bleibt false bis ein
Admin den Fakt freigibt"), und `api.jsx:176` hält sie ein. Beides ist Client.

Gegenprobe, was ein selbst freigegebener Fakt bewirkt: die Lese-Policy
`read facts` (`:145-146`) gibt jede Zeile mit `is_approved = true` an **jeden**
heraus, auch an `anon`. Der Fakt steht damit in der Liste aller Nutzer
(`api.jsx:123`) und in diesem Repository ebenfalls, weil
`supabase_fact_remote_data_source.dart:48` genau auf `is_approved = true`
filtert. Unmoderierter Text in einer App, deren Inhalt das Produkt ist.

#### E-55: `FOR ALL` ohne `WITH CHECK` auf den beiden Wettbewerbstabellen

`03_Backend/supabase-schema.sql:212-214` und `:222-224`

```sql
ALTER TABLE public.user_city_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public read city scores" ON public.user_city_scores FOR SELECT USING (true);
CREATE POLICY "own city scores" ON public.user_city_scores FOR ALL USING (auth.uid() = user_id);

ALTER TABLE public.user_trophies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public read trophies" ON public.user_trophies FOR SELECT USING (true);
CREATE POLICY "own trophies" ON public.user_trophies FOR ALL USING (auth.uid() = user_id);
```

Dieselbe Mechanik wie E-24, nachzulesen in Abschnitt 0, Befund 1: ohne
`WITH CHECK` benutzt PostgreSQL den `USING`-Ausdruck auch für neue und
geänderte Zeilen. `FOR ALL` schließt `INSERT`, `UPDATE` und `DELETE` ein. Ein
Nutzer setzt seinen Punktestand je Stadt auf jeden Wert und trägt sich jede
Trophäe ein.

Anders als bei `profiles` braucht es hier **keine** Spaltenrechte. Der
Unterschied: auf `profiles` sind drei von zwölf Spalten legitim
clientschreibbar, die Grenze liegt also innerhalb der Zeile. Auf diesen beiden
Tabellen schreibt kein Client legitim **irgendetwas**, die Grenze liegt an der
Tabelle. Ein Entzug von `insert, update, delete` ist damit die vollständige und
die einfachere Antwort.

Wer schreibt heute wirklich hinein:

| Tabelle | Schreiber | Fundstelle |
|---|---|---|
| `user_city_scores` | nur Trigger `handle_fact_collected` | `supabase-schema.sql:261-265` |
| `user_trophies` | Trigger `handle_fact_collected` | `:268-334` |
| `user_trophies` | Trigger `handle_user_fact_created` | `:347-359` |
| `user_trophies` | RPC `unlock_trophy` | `:514-519`, gerufen aus `api.jsx:243` |

Vollständig gesucht in `02_Frontend/app/`, `02_Frontend/admin/`,
`04_Datenpipeline/scripts/`, `supabase/functions/`, `08_Flutter/lib/` und
`lib/`. **Kein direkter Schreibzugriff eines Clients auf eine der beiden
Tabellen existiert.** Der eingefrorene Port liest `user_trophies`
(`08_Flutter/lib/services/supabase_service.dart:66,238`) und schreibt über
`unlock_trophy` (`:245`), wie die PWA.

### 11.2 Ergänzung zu Abschnitt 2: die Ausführrechte je Funktion

Abschnitt 2 erhebt, wer wohin schreibt. Für E-52 fehlt die zweite Hälfte: wer
darf überhaupt rufen. Aus den Dateien abgeleitet, in der Datenbank mit Abfrage
K zu prüfen.

| Funktion | Ruft heute wer | Braucht `anon`? | Migration 4 |
|---|---|---|---|
| `check_username(text)` | `screen-auth.jsx:600`, `username_check_notifier.dart:144` | **ja, vor der Anmeldung** | ausdrücklich an `anon` und `authenticated` |
| `get_leaderboard(text,text)` | `screen-profil.jsx:20` | offen, gehört zu E-16 | **nicht angefasst** |
| `get_my_rank(uuid,text,text)` | `app.jsx:267`, nur mit Sitzung | nein | `anon` und `PUBLIC` weg |
| `unlock_trophy(uuid,text)` | `api.jsx:243` | nein | Konto-Bindung, `anon` weg |
| `increment_coins(uuid,int)` | `api.jsx:157` | nein | erledigt **Block 2a** |
| `collect_fact_validated(...)` | niemand in der PWA | nein | erledigt **Block 3b** |
| 12 Gruppen- und Team-RPCs | `api.jsx:337-446` | nein | `anon` und `PUBLIC` weg |
| `ai_consume()`, `ai_refund()` | `supabase/functions/llm/index.ts:62,84` | nein | schon zu, `ai_proxy.sql:51-54` |
| `_group_code_gen`, `_haversine_m`, `_city_default_meeting`, `_team_generate_orders`, `_slugify` | nur aus Definer-Funktionen | nein | `anon`, `PUBLIC` **und** `authenticated` weg |
| `_is_group_member(uuid,uuid)` | **drei RLS-Policies** | fraglich, siehe unten | **nicht angefasst**, Befund 7 |
| `handle_new_user`, `handle_fact_collected`, `handle_user_fact_created` | Trigger | nein | **nicht angefasst**, Begründung unten |
| `fact_i18n_langs(facts)` | niemand | nein | **nicht angefasst** |

**Warum die zwölf Gruppen-RPCs trotzdem in die Migration gehören, obwohl sie
heute schon scheitern.** Alle zwölf lesen `auth.uid()` selbst und brechen mit
`raise exception 'not_authenticated'` ab, wenn sie nichts bekommen
(`2026-06-04_group_sessions.sql:120-126` als Muster). Ein `anon`-Aufruf richtet
heute also keinen Schaden an. Er ist trotzdem einer zu viel: die Prüfung liegt
im Funktionsrumpf und damit an einer Stelle, die jede künftige Änderung
mitnehmen muss. Ein entzogenes Ausführrecht liegt außerhalb des Rumpfes und
übersteht jedes `create or replace`. Das ist der Unterschied zwischen einer
Zusicherung und einer Gewohnheit.

**Warum die Trigger-Funktionen nicht angefasst werden.** Sie geben `trigger`
zurück, können deshalb nicht über PostgREST gerufen werden und sind über eine
direkte SQL-Sitzung ohnehin nur mit `CREATE TRIGGER` nutzbar. Der Gewinn eines
Revoke ist damit null. Der Preis wäre eine Unsicherheit: ob PostgreSQL beim
**Auslösen** eines Triggers das `EXECUTE`-Recht erneut prüft oder nur bei
`CREATE TRIGGER`, ist ohne Test an einer echten Datenbank nicht zu behaupten,
und wenn die Antwort „beim Auslösen" wäre, stünden `score_total`,
`user_city_scores` und alle Trophäen still. Eine Ersparnis von null gegen ein
Risiko von allem ist keine Abwägung. Wer es sauber haben will, prüft es in einem
Testprojekt und macht daraus eine eigene Migration.

**Warum `_is_group_member` außen bleibt, obwohl `anon` sie nicht braucht.** Ein
`anon`-Lesezugriff auf `group_sessions` liefert heute nichts, weil die Policy
`host_id = auth.uid() or _is_group_member(id, auth.uid())` mit `auth.uid()`
gleich `null` für jede Zeile falsch ist. Fehlt `anon` das Ausführrecht, wird aus
dem leeren Ergebnis ein **Fehler**. Kein bekannter Ablauf liest die Tabelle als
`anon`, aber die Fehlerklasse wäre eine andere als vorher, und dieser Nachtrag
ändert keine Fehlerklasse, deren Aufrufer er nicht kennt. Der Zeilenschutz hängt
an der Policy, nicht am Ausführrecht des Helfers.

### 11.3 Reihenfolge, und wo die App dabei kaputtgeht

Die drei Migrationen sind untereinander und von den Migrationen 1 bis 3
unabhängig, mit **einer** Ausnahme.

| Schritt | Sicherheitsgewinn für sich allein | Bricht die PWA? | Bricht diese App? |
|---|---|---|---|
| 4. E-52, `unlock_trophy` und Ausführrechte | fremde Konten und `anon` sind aus allen schreibenden RPCs draußen | **nein**, Nachweis in 11.4 | **nein**, `lib/` ruft keine der Funktionen; `check_username` bleibt frei |
| 5. E-53, `facts` | ein selbst freigegebener Fakt ist nicht mehr möglich | **nein**, `api.jsx:176` schickt `false` | **nein**, `lib/` fügt keine Fakten ein |
| 6. E-55, `user_trophies` und `user_city_scores` | Punktestände sind serverbestimmt, Trophäen nur noch über die RPC | **nein**, die PWA schreibt beide Tabellen nie direkt | **nein**, `progression` hat keine Datenschicht |

**Die Ausnahme: Migration 4 gehört vor Migration 6.** Läuft 6 allein, ist der
direkte Tabellenweg zu, `unlock_trophy` nimmt aber weiter eine fremde Kennung
an. Der Angriff „schreib der Konkurrenz eine Trophäe" wäre dann nicht behoben,
sondern nur verlegt. Andersherum entsteht kein halber Zustand: nach 4 allein
schreibt der Client noch direkt in die Tabelle, also genau wie heute.

**Keine der drei hängt am PWA-Release**, der Migration 3a blockiert. Sie können
alle drei heute laufen, in der Reihenfolge 4, 5, 6.

**Was nach jeder Migration einmal passieren muss.** Migration 4 und der
optionale Block 4c ändern Funktionsrümpfe und Ausführrechte. PostgREST hält
dafür einen Schemacache. Supabase erneuert ihn per Event-Trigger nach DDL, aber
darauf muss sich niemand verlassen:

```sql
notify pgrst, 'reload schema';
```

Kostet nichts, ist beliebig oft wiederholbar, und ohne sie antwortet die API im
Zweifel mit `PGRST202` („could not find function") auf eine Funktion, die es
gibt. Dasselbe gilt für die Blöcke 2a, 2b und 3b oben.

### 11.4 Migration 4: `unlock_trophy` und die Ausführrechte (E-52)

Dateiname im Backend-Repo: `2026-09-02_e52_unlock_trophy_and_execute_grants.sql`

**Vorher laufen lassen und die Ausgabe sichern: Abfrage K und L** (11.7). K sagt,
welche Rolle heute welche Funktion rufen darf, L sagt, ob eine der doppelt
definierten Funktionen (E-21) unter zwei Signaturen in der Datenbank steht.

#### Die Entwurfsfrage: der Parameter bleibt in der Signatur

`unlock_trophy` bekommt die Nutzerkennung vom Aufrufer. Zwei Wege führen weg
davon, und sie schließen sich nicht aus:

| Weg | Bricht Aufrufer? | Was er kostet |
|---|---|---|
| **A**: Signatur bleibt, der Wert wird nicht mehr geglaubt | nein | die Signatur lügt weiter über das, was sie braucht |
| **B**: neue, parameterfreie Funktion, alte irgendwann weg | ja, ab dem Tag, an dem die alte fällt | ein Release je Client, bis dahin zwei Funktionen mit derselben Wirkung |

**Entschieden: A jetzt, B als vorbereiteter Block 4c, der nicht mitläuft.**
Begründung, in der Reihenfolge ihres Gewichts:

1. **Es gibt genau einen Aufrufer, und er liegt im anderen Repository.**
   `api.jsx:243` schickt `p_user_id` mit. Weg B ohne Übergangsfassung nimmt der
   Produktion die Trophäen weg, und zwar lautlos: `Api.unlockTrophy` hat kein
   `_apiCheck` und `app.jsx:551` fängt jeden Fehler mit `catch (e) { }` ab. Der
   Nutzer sieht die Konfetti-Animation, der Server hat nichts gespeichert. Das
   ist derselbe Fehlermodus, der Migration 3a blockiert.
2. **Weg A schließt die Lücke vollständig, nicht teilweise.** Der Schaden von
   E-52 ist der Schreibzugriff auf ein fremdes Konto. Der ist mit dem Vergleich
   gegen `auth.uid()` weg, ganz unabhängig davon, ob der Parameter noch da
   steht. Was bleibt, ist eine unschöne Signatur, kein Loch.
3. **Es ist die Entscheidung, die für `increment_coins` schon getroffen ist.**
   Block 2a hält den Parameter aus demselben Grund („damit alle bestehenden
   Aufrufer ohne Änderung weiterlaufen"). Zwei verschiedene Muster für dieselbe
   Klasse Fehler wären für den nächsten Leser teurer als die eine schiefe
   Signatur.
4. **Eine zweite Funktion ist eine zweite Rechtefläche.** Solange kein Client
   sie ruft, hat 4c nur Kosten: ein weiterer Name, an dem jemand ein Grant
   vergessen kann.

**Nicht entschieden und ausdrücklich offen:** wann Weg B kommt. Er gehört an
einen Client-Release, nicht an eine Migration. Der Reihenfolgeplan dafür steht
unter Block 4c.

#### Block 4a: `unlock_trophy`

```sql
-- ============================================================================
-- FACT — E-52: unlock_trophy nimmt die Nutzerkennung vom Aufrufer
-- ----------------------------------------------------------------------------
-- Ist-Zustand: supabase-schema.sql:514-519. LANGUAGE sql, SECURITY DEFINER,
-- kein Vergleich mit auth.uid(), keine Schlüsselprüfung, kein search_path,
-- kein entzogenes Ausführrecht. Wirkung heute: wer eine fremde UUID kennt,
-- schreibt dort jede Trophäe hin, und die UUIDs gibt get_leaderboard heraus
-- (supabase-schema.sql:371), auch ohne Anmeldung.
--
-- Der Parameter p_user_id BLEIBT in der Signatur und wird nicht mehr geglaubt.
-- Begründung in Abschnitt 11.4, Muster aus Block 2a.
--
-- Bricht heute nichts: einziger Aufrufer ist api.jsx:243, und er übergibt
-- immer die eigene userId (app.jsx:551, rnkMaybeUnlock).
-- ============================================================================

begin;

create or replace function public.unlock_trophy(p_user_id uuid, p_trophy_key text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unlock_trophy: not authenticated' using errcode = '42501';
  end if;

  -- Der Nullfall ist erlaubt und landet beim eigenen Konto, wie in Block 2a.
  -- Vorher schrieb `values (null, key)` in eine Spalte mit NOT NULL und
  -- Fremdschlüssel, war also ein Fehler; jetzt ist er eine gültige Kurzform.
  if p_user_id is not null and p_user_id <> v_uid then
    raise exception 'unlock_trophy: foreign account' using errcode = '42501';
  end if;

  -- KEINE Zeichenklasse, nur eine Länge. `nachtschwärmer`
  -- (wallet-colors.jsx:133, gerufen in app.jsx:726) und die Stadt-Trophäen des
  -- Triggers (`münchen_first`, supabase-schema.sql:275-279) enthalten Umlaute.
  -- Ein ^[a-z0-9_]+$ würde genau die Schlüssel abweisen, die es geben soll.
  -- Die Länge verhindert nur, dass jemand die Tabelle mit Müll füllt; welche
  -- Schlüssel es gibt, weiß heute nur der Client (window.WalletTrophies).
  if p_trophy_key is null or length(p_trophy_key) not between 1 and 64 then
    raise exception 'unlock_trophy: invalid trophy key' using errcode = '22023';
  end if;

  insert into public.user_trophies (user_id, trophy_key)
    values (v_uid, p_trophy_key)
    on conflict do nothing;
end;
$$;

commit;
```

#### Block 4b: die Ausführrechte, in einer Schleife statt in einer Liste

**Warum eine Schleife über `pg_proc` und keine Liste von Signaturen.** Drei
Gründe, und jeder einzelne reicht:

1. **Zwei Funktionen sind doppelt definiert** (`backend-inventory.md`, E-21:
   `start_group_session`, `_team_generate_orders`). Welche Fassung in der
   Datenbank steht und mit welcher Signatur, ist aus dem Repository nicht zu
   sehen. Eine Schleife über den Namen trifft alle Fassungen, eine Liste trifft
   die, die jemand erwartet hat.
2. **Ein Tippfehler in einer Signatur schlägt nicht fehl, er trifft nur
   nichts.** `revoke ... on function public.pick_team(uuid, text)` gegen eine
   Funktion, die `(uuid, varchar)` heißt, ist ein Fehler; `revoke` gegen eine
   nicht existierende Funktion ist ein Abbruch. Beides fällt in einem Block mit
   30 Zeilen leicht durch. Die Schleife baut die Signatur aus dem Katalog und
   kann sie nicht falsch schreiben.
3. **Sie ist selbstprüfend.** Jede angefasste Funktion und jeder Name, den es
   in dieser Datenbank nicht gibt, kommt als `NOTICE` zurück. Damit steht nach
   dem Lauf im Editor-Protokoll, was wirklich passiert ist, und nicht, was
   passieren sollte.

```sql
-- ============================================================================
-- FACT — E-52: EXECUTE steht per PostgreSQL-Standard an PUBLIC, und PUBLIC
--              schließt anon ein
-- ----------------------------------------------------------------------------
-- Im gesamten 03_Backend/ gibt es fünf GRANT/REVOKE-Zeilen, alle in
-- 2026-06-20_ai_proxy.sql:51-54,61. Alle anderen Funktionen sind ohne Konto
-- aufrufbar.
--
-- ABSICHTLICH NICHT IN DIESER MIGRATION:
--   check_username   -> wird VOR der Anmeldung gerufen (screen-auth.jsx:600,
--                       username_check_notifier.dart:144) und wird unten
--                       ausdrücklich an anon vergeben.
--   get_leaderboard  -> die Leseseite gehört zu E-16, das ist eine
--                       Produktentscheidung, keine Migration.
--   _is_group_member -> steckt in drei RLS-Policies
--                       (group_sessions_rls_fix.sql:30-47). Policy-Ausdrücke
--                       laufen mit den Rechten der ABFRAGENDEN Rolle. Ein
--                       Revoke gegen authenticated legt den Gruppenmodus still.
--   handle_new_user, handle_fact_collected, handle_user_fact_created
--                    -> Trigger-Funktionen, über PostgREST nicht rufbar. Der
--                       Gewinn ist null, das Risiko wäre die ganze Rangliste.
-- ============================================================================

begin;

-- 1. Schreibende RPCs: nur mit Konto. Die zwölf Gruppen- und Team-RPCs prüfen
--    auth.uid() schon selbst (group_sessions.sql:120-126 als Muster), das
--    Ausführrecht ist die zweite, äußere Grenze. get_my_rank liest nur, nimmt
--    aber eine fremde Kennung und hat keinen anon-Aufrufer (app.jsx:267).
do $do$
declare
  r record;
  c_names text[] := array[
    'unlock_trophy',
    'get_my_rank',
    'create_group_session',
    'join_group_session',
    'start_group_session',
    'end_group_session',
    'leave_group_session',
    'collect_group_fact',
    'create_team_session',
    'pick_team',
    'auto_balance_teams',
    'randomize_teams',
    'collect_team_fact',
    'tag_endpoint'
  ];
begin
  for r in
    select n.nspname as sch,
           p.proname as fn,
           pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and p.proname = any (c_names)
     order by 2, 3
  loop
    execute format('revoke all on function %I.%I(%s) from public, anon',
                   r.sch, r.fn, r.args);
    execute format('grant execute on function %I.%I(%s) to authenticated',
                   r.sch, r.fn, r.args);
    raise notice 'E-52 gesichert: %(%)', r.fn, r.args;
  end loop;

  -- Selbstprüfung: was in dieser Datenbank fehlt, muss man wissen, statt es zu
  -- unterstellen. Ein fehlender Name heißt entweder "Migration nie gelaufen"
  -- oder "anders benannt", und beides ist ein Befund.
  for r in
    select x.fn
      from unnest(c_names) as x(fn)
     where not exists (
       select 1
         from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = x.fn)
  loop
    raise notice 'E-52: % existiert in dieser Datenbank NICHT', r.fn;
  end loop;
end
$do$;

-- 2. Interne Helfer: gar kein Client. Sie werden ausschließlich aus
--    SECURITY-DEFINER-Funktionen gerufen (team_sessions.sql:130-250,300-325,
--    570,666; city_backfill.sql:64-108), und die laufen als Eigentümer, den
--    ein Revoke gegen anon oder authenticated nicht betrifft.
--    _is_group_member steht bewusst NICHT in dieser Liste.
do $do$
declare
  r record;
  c_names text[] := array[
    '_group_code_gen',
    '_haversine_m',
    '_city_default_meeting',
    '_team_generate_orders',
    '_slugify'
  ];
begin
  for r in
    select n.nspname as sch,
           p.proname as fn,
           pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and p.proname = any (c_names)
     order by 2, 3
  loop
    execute format('revoke all on function %I.%I(%s) from public, anon, authenticated',
                   r.sch, r.fn, r.args);
    raise notice 'E-52 intern: %(%)', r.fn, r.args;
  end loop;
end
$do$;

-- 3. Was ohne Konto erreichbar bleiben MUSS. Ausdrücklich vergeben und nicht
--    dem Standard überlassen: wäre der Standard hier einmal angefasst worden,
--    wäre die Namensprüfung in beiden Clients stumm kaputt.
grant execute on function public.check_username(text) to anon, authenticated;

commit;

-- 4. PostgREST-Schemacache erneuern. Ohne das antwortet die API im Zweifel mit
--    PGRST202 auf eine Funktion, die es gibt.
notify pgrst, 'reload schema';
```

**Was `service_role` angeht: nichts.** Supabase vergibt die Rechte für `anon`,
`authenticated` und `service_role` je Rolle einzeln, nicht über `PUBLIC`. Ein
`revoke ... from public, anon` nimmt `service_role` also nichts weg. Die
Datenpipeline und der Admin rufen ohnehin keine dieser Funktionen, geprüft über
`rpc(` in `04_Datenpipeline/scripts/` und `02_Frontend/admin/index.html`: der
einzige RPC-Aufruf außerhalb der PWA steht in
`supabase/functions/llm/index.ts:62,84` und betrifft `ai_consume`/`ai_refund`.

#### Block 4c: die parameterfreie Fassung. Läuft noch nicht

> **Nicht ausführen, solange kein Client sie ruft.** Dieser Block ist fertig,
> damit er bereitliegt, wie Migration 3.

```sql
-- Zweite Fassung ohne Nutzerkennung. PostgREST löst Überladungen über die
-- Menge der Parameternamen im JSON-Rumpf auf: {p_trophy_key} trifft diese
-- Fassung, {p_user_id, p_trophy_key} die alte.
--
-- ZWEI FALLEN, bevor jemand das für harmlos hält:
--   1. Sobald eine der beiden Fassungen einen DEFAULT-Parameter bekommt, wird
--      der Aufruf mehrdeutig und PostgreSQL antwortet mit 42725
--      ("function is not unique"). Keine der beiden darf je einen bekommen.
--   2. Ohne `notify pgrst, 'reload schema';` kennt die API die neue Fassung
--      nicht und antwortet mit PGRST202.
begin;

create or replace function public.unlock_trophy(p_trophy_key text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unlock_trophy: not authenticated' using errcode = '42501';
  end if;
  if p_trophy_key is null or length(p_trophy_key) not between 1 and 64 then
    raise exception 'unlock_trophy: invalid trophy key' using errcode = '22023';
  end if;

  insert into public.user_trophies (user_id, trophy_key)
    values (v_uid, p_trophy_key)
    on conflict do nothing;
end;
$$;

revoke all on function public.unlock_trophy(text) from public, anon;
grant execute on function public.unlock_trophy(text) to authenticated;

commit;

notify pgrst, 'reload schema';
```

**Und der letzte Schritt, der erst danach kommt.** Wenn jeder Client die
parameterfreie Fassung ruft, und nur dann:

```sql
drop function if exists public.unlock_trophy(uuid, text);
notify pgrst, 'reload schema';
```

`if exists` ist hier nicht Kosmetik: ohne es ist der zweite Lauf ein Abbruch,
und in einer Datenbank ohne Migrationsledger weiß niemand, ob es der zweite
Lauf ist.

Die Reihenfolge für Weg B, damit sie nicht in Vergessenheit gerät:

| Schritt | Wo | Bedingung |
|---|---|---|
| 1 | Block 4c im Backend | jederzeit, aber ohne Nutzen |
| 2 | PWA auf `{p_trophy_key}` umstellen | eigener Auftrag im PWA-Repository |
| 3 | diese App: ruft `unlock_trophy` nicht, also nichts zu tun | entfällt |
| 4 | `drop function ... (uuid, text)` | erst wenn Schritt 2 ausgeliefert **und** die alte Fassung nachweislich nicht mehr gerufen wird |

Für Schritt 4 fehlt heute die Grundlage: es gibt kein Zugriffsprotokoll, aus dem
hervorgeht, welche Fassung gerufen wird. Wer sichergehen will, baut vorher ein
`raise notice` oder eine Zählspalte in die alte Fassung ein. Das ist derselbe
Mangel wie das fehlende Buchungsjournal in Abschnitt 9.

**Dasselbe Muster gilt später für `increment_coins` und
`collect_fact_validated`.** Die beiden Blöcke oben bleiben unverändert; wenn
jemand deren Signaturen aufräumt, ist 4c die Vorlage, samt der beiden Fallen.

#### Rückabwicklung 4

Dateiname: `2026-09-02_e52_unlock_trophy_and_execute_grants_down.sql`

```sql
-- Stellt supabase-schema.sql:514-519 wörtlich her und gibt die Ausführrechte
-- an PUBLIC zurück, also den PostgreSQL-Standard.
-- ACHTUNG: damit ist E-52 wieder offen, in vollem Umfang. Vorher Abfrage K
-- laufen lassen und die Ausgabe sichern.
begin;

create or replace function public.unlock_trophy(p_user_id uuid, p_trophy_key text)
returns void language sql security definer as $$
  insert into public.user_trophies (user_id, trophy_key)
    values (p_user_id, p_trophy_key)
    on conflict do nothing;
$$;

do $do$
declare
  r record;
  c_names text[] := array[
    'unlock_trophy', 'get_my_rank',
    'create_group_session', 'join_group_session', 'start_group_session',
    'end_group_session', 'leave_group_session', 'collect_group_fact',
    'create_team_session', 'pick_team', 'auto_balance_teams',
    'randomize_teams', 'collect_team_fact', 'tag_endpoint',
    '_group_code_gen', '_haversine_m', '_city_default_meeting',
    '_team_generate_orders', '_slugify'
  ];
begin
  for r in
    select n.nspname as sch, p.proname as fn,
           pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
       and p.proname = any (c_names)
  loop
    execute format('grant execute on function %I.%I(%s) to public',
                   r.sch, r.fn, r.args);
  end loop;
end
$do$;

commit;

notify pgrst, 'reload schema';
```

Falls Block 4c gelaufen ist, zusätzlich
`drop function if exists public.unlock_trophy(text);`, sonst bleibt eine
Funktion stehen, die kein Dokument mehr erklärt.

---

### 11.5 Migration 5: die Freigabespalte gehört in die Policy (E-53)

Dateiname im Backend-Repo: `2026-09-02_e53_facts_approval.sql`

**Vorher laufen lassen: Abfrage M und O** (11.7). M zeigt die Policies auf
`facts` im Ist-Zustand, O zeigt, ob der Befund schon benutzt wurde.

```sql
-- ============================================================================
-- FACT — E-53: Nutzer-Fakten können sich selbst freigeben
-- ----------------------------------------------------------------------------
-- Ist-Zustand: supabase-schema.sql:149-150. Die Insert-Policy prüft created_by
-- und is_user_created, aber nicht is_approved. Dass api.jsx:176 dort `false`
-- schickt, ist eine Höflichkeit des Clients. Wer die Anfrage selbst
-- formuliert, veröffentlicht unmoderierten Text für alle Nutzer, inklusive
-- anon (Lese-Policy :145-146).
--
-- WARUM HIER KEINE SPALTENRECHTE, anders als in Migration 1: bei INSERT sieht
-- WITH CHECK die neue Zeile und kann den Wert der Spalte prüfen. Der Umweg aus
-- Abschnitt 3 ist für UPDATE nötig, wo es eine alte Zeile gibt. Er wäre hier
-- sogar schädlich: die PWA nennt is_approved namentlich (api.jsx:176), ein
-- `revoke insert (is_approved)` würde diesen richtigen Aufruf mit 42501
-- abweisen.
--
-- `is not true` statt `= false`: is_approved ist nullable
-- (supabase-schema.sql:33). Eine ausdrückliche NULL soll nicht abgewiesen
-- werden, denn sie ist harmlos. Die Lese-Policy verlangt `= true`, und der
-- Admin filtert in JavaScript mit `!f.is_approved` (admin/index.html:1164),
-- behandelt NULL also als "offen". Eine NULL-Zeile ist damit unsichtbar und
-- trotzdem moderierbar.
--
-- Bricht heute nichts: api.jsx:165-177 schickt created_by = eigene userId,
-- is_user_created = true, is_approved = false. Alle drei Bedingungen erfüllt.
-- ============================================================================

begin;

-- 1. Policy ersetzen. Gleicher Name, damit der Katalog danach eine Policy
--    dieses Namens hat und nicht zwei.
drop policy if exists "insert own fact" on public.facts;

create policy "insert own fact" on public.facts
  for insert with check (
    auth.uid() = created_by
    and is_user_created = true
    and is_approved is not true
  );

-- 2. Schreibrechte auf das reduzieren, was ein Client braucht. Reihenfolge wie
--    in Migration 1: erst tabellenweit entziehen, dann ausdrücklich
--    zurückgeben. Nicht auf einen vorhandenen Grant vertrauen, sonst hängt das
--    Ergebnis daran, ob authenticated sein INSERT einzeln oder über PUBLIC
--    hält, und das weiß aus dem Repository niemand.
revoke insert, update, delete on public.facts from authenticated, anon, public;
grant insert on public.facts to authenticated;

-- UPDATE und DELETE bleiben entzogen, und zwar für alle drei Empfänger. Sie
-- sind heute ohnehin wirkungslos, weil es auf facts keine UPDATE- und keine
-- DELETE-Policy gibt: ein Nutzer kann seinen Fakt nicht bearbeiten und nicht
-- löschen. Der Entzug hält den Zustand fest, statt ihn von der Abwesenheit
-- einer Policy abhängig zu machen. Wer später ein Bearbeiten baut, braucht
-- beides, und dann steht die Entscheidung ausdrücklich an, statt sich aus
-- einem alten Default zu ergeben.
--
-- SELECT bleibt unberührt: die PWA hängt an api.jsx:178 ein .select() an das
-- Insert und braucht es. Die Lese-Policy :145-146 deckt den eigenen, noch
-- nicht freigegebenen Fakt ab.

commit;
```

**Optionaler Block 5b: die drei anderen Spalten, die niemand mitschickt.**

Die Insert-Policy prüft die Freigabe, nicht den Rest der Zeile. Vier Spalten
bleiben frei setzbar, und zwei davon haben Wirkung über die Anzeige hinaus:

| Spalte | Was ein gesetzter Wert bewirkt | Schickt die PWA sie? |
|---|---|---|
| `rating`, `bewertungen` | der eigene Fakt sieht beliebt aus | nein (`api.jsx:165-177`) |
| `nr` | Präfix wie `MUC_` steuert den Rückfall des Stadtschlüssels im Trigger (`supabase-schema.sql:242-249`) | nein |
| `city` | steuert den Stadtschlüssel unmittelbar, also die Stadt-Rangliste | nein |

Weil kein Client sie schickt, ist die strengere Fassung heute kostenlos:

```sql
begin;

drop policy if exists "insert own fact" on public.facts;

create policy "insert own fact" on public.facts
  for insert with check (
    auth.uid() = created_by
    and is_user_created = true
    and is_approved is not true
    and coalesce(rating, 0) = 0
    and coalesce(bewertungen, 0) = 0
    and nr is null
    and city is null
  );

commit;
```

**Der Preis steht in der Zukunft, nicht heute.** Sobald ein Client beim
Erstellen eine Stadt mitgeben soll, und für den Neubau ist das plausibel, muss
diese Policy mitgeändert werden, sonst scheitert das Erstellen mit `42501` und
niemand sucht die Ursache in einer RLS-Policy von 2026. Deshalb ist 5b optional
und nicht Teil von Migration 5: E-53 ist die Freigabespalte, der Rest ist
Datenhygiene und gehört zu E-56 (Stadtschlüssel) beziehungsweise zur Frage, wer
`rating` überhaupt setzen darf.

**Was Migration 5 ausdrücklich nicht tut: das Bearbeiten öffnen.** Der Auftrag
nannte „der Eigentümer darf seine Zeile anlegen und bearbeiten". Bearbeiten gibt
es nicht, siehe Befund 2 in 11.0. Wenn es kommt, sieht es so aus, und dann ist
der Umweg aus Abschnitt 3 tatsächlich nötig, weil `WITH CHECK` bei `UPDATE`
nicht „`is_approved` darf sich nicht ändern" sagen kann:

```sql
-- NICHT AUSFÜHREN. Rezept für den Tag, an dem ein Fakt bearbeitbar wird.
grant update (titel, text, text2, kategorie, quelle, hero, lat, lng, ort)
  on public.facts to authenticated;

create policy "update own pending fact" on public.facts
  for update
  using (auth.uid() = created_by and is_approved is not true)
  with check (auth.uid() = created_by and is_approved is not true);
```

Zwei Dinge daran sind die eigentliche Arbeit und keine Migration: ob ein bereits
freigegebener Fakt weiter bearbeitbar sein soll (das `using` oben sagt nein, und
das ist eine Produktentscheidung), und ob eine Bearbeitung die Freigabe
zurücksetzen muss. Letzteres ist mit RLS allein nicht zu machen, weil die
`WITH CHECK`-Klausel den Wert nur prüfen, nicht setzen kann. Das wäre ein
`BEFORE UPDATE`-Trigger, also Schema.

#### Rückabwicklung 5

Dateiname: `2026-09-02_e53_facts_approval_down.sql`

```sql
-- Stellt supabase-schema.sql:149-150 wörtlich her.
-- ACHTUNG: danach kann sich jeder Nutzer seine Fakten wieder selbst freigeben.
begin;

drop policy if exists "insert own fact" on public.facts;

create policy "insert own fact" on public.facts
  for insert with check (auth.uid() = created_by and is_user_created = true);

grant insert, update, delete on public.facts to authenticated, anon;

-- Absichtlich KEIN "grant ... to public", gleiche Begründung wie in
-- Rückabwicklung 1: ein an PUBLIC vergebenes Recht wäre ein neues Loch, kein
-- wiederhergestellter Zustand. Ob im Ist-Zustand eines bestand, sagt Abfrage M
-- beziehungsweise B aus Abschnitt 7.

commit;
```

---

### 11.6 Migration 6: Rangliste und Trophäen sind nicht mehr clientschreibbar (E-55)

Dateiname im Backend-Repo: `2026-09-02_e55_ranking_tables.sql`

**Vorher laufen lassen: Abfrage M, N, P und Q** (11.7). N ist die
Voraussetzung, nicht die Nachkontrolle: sie bestätigt, dass Tabellen und
Definer-Funktionen derselben Rolle gehören und `FORCE ROW LEVEL SECURITY` aus
ist. P und Q zeigen, ob der Befund schon benutzt wurde.

```sql
-- ============================================================================
-- FACT — E-55: user_city_scores und user_trophies sind vom Client schreibbar
-- ----------------------------------------------------------------------------
-- Ist-Zustand: supabase-schema.sql:213-214 und :223-224. FOR ALL ohne
-- WITH CHECK, also gilt der USING-Ausdruck auch für neue und geänderte Zeilen.
-- Ein Nutzer setzt seinen Punktestand je Stadt auf jeden Wert und trägt sich
-- jede Trophäe ein. get_leaderboard liest im Modus "alltime, Stadt" direkt aus
-- user_city_scores (supabase-schema.sql:434).
--
-- Anders als bei profiles braucht es KEINE Spaltenrechte: auf diesen beiden
-- Tabellen schreibt kein Client legitim irgendetwas, die Grenze liegt an der
-- Tabelle und nicht in der Zeile.
--
-- WER WEITER DURCHKOMMT, und warum:
--   handle_fact_collected (:226-341) ist SECURITY DEFINER und gehört dem
--   Tabelleneigentümer. Eine Definer-Funktion läuft mit den Rechten ihres
--   Besitzers; für den Tabelleneigentümer greifen RLS-Policies nicht (solange
--   FORCE ROW LEVEL SECURITY aus ist) und ein GRANT/REVOKE gegen authenticated
--   betrifft ihn nicht. Der Trigger on_fact_collected (:343-345) hängt an
--   collected_facts, nicht an der aufrufenden Rolle, und feuert bei jedem
--   Insert, auch aus einer Definer-Funktion. Dasselbe gilt für
--   handle_user_fact_created (:347-363) und unlock_trophy (:514).
--   Bestätigt wird das mit Abfrage N, nicht geglaubt.
--
--   `alter table ... force row level security` darf auf keiner der beiden
--   Tabellen gesetzt werden. Es steht in keiner geprüften Datei und in keiner
--   Migration dieses Dokuments. Wer es setzt, legt den Trigger still, und
--   damit die Trophäen und die Stadtwertung.
--
-- Bricht heute nichts: kein Client schreibt in eine der beiden Tabellen.
-- Trophäen laufen über die RPC (api.jsx:243), Punktestände nur über den
-- Trigger. Vollständige Erhebung in Abschnitt 11.1.
--
-- WAS ES NICHT BEHEBT: unlock_trophy bleibt der reguläre Weg, und der Client
-- entscheidet weiter, welchen Schlüssel er sich holt (app.jsx:551,
-- :725-727, :804, :975). Für user_city_scores ist die Behebung vollständig,
-- für user_trophies ist sie eine Verkleinerung. Der Rest ist E-49.
-- ============================================================================

begin;

-- 1. Schreibrechte entziehen, alle drei Empfänger. `public` ist die
--    PUBLIC-Pseudorolle, nicht das Schema: ein an PUBLIC vergebenes Recht hält
--    jede Rolle, und ein Revoke gegen authenticated entfernt es nicht.
--    Gleiche Begründung wie in Migration 1, Schritt 1.
revoke insert, update, delete on public.user_city_scores
  from authenticated, anon, public;
revoke insert, update, delete on public.user_trophies
  from authenticated, anon, public;

-- Kein Gegen-Grant. Anders als bei profiles und facts gibt es hier keine
-- Spalte und keine Operation, die ein Client braucht.

-- 2. Die FOR-ALL-Policies durch ausdrückliche SELECT-Policies ersetzen, damit
--    im Katalog steht, was gilt. Ohne diesen Schritt bliebe eine Policy
--    stehen, die INSERT, UPDATE und DELETE erlaubt, während das Recht dafür
--    fehlt: zwei Aussagen, die sich widersprechen, und der nächste Leser muss
--    raten, welche zählt.
drop policy if exists "own city scores" on public.user_city_scores;
drop policy if exists "own trophies"    on public.user_trophies;

create policy "own city scores select" on public.user_city_scores
  for select using (auth.uid() = user_id);

create policy "own trophies select" on public.user_trophies
  for select using (auth.uid() = user_id);

-- Diese zwei Policies ändern HEUTE nichts. Die bestehenden Policies
-- "public read city scores" und "public read trophies" (:213, :223) erlauben
-- mit USING (true) ohnehin jedem das Lesen, und mehrere Policies für dieselbe
-- Operation werden mit ODER verknüpft. Sie stehen hier, weil sie am Tag der
-- E-16-Entscheidung gebraucht werden: wer dann die USING-(true)-Policies
-- löscht, nimmt sonst in derselben Sekunde jedem Nutzer den Blick auf die
-- eigenen Trophäen. Der eigene Zugriff soll nicht daran hängen, dass alle
-- alles sehen dürfen.
--
-- Die Leseseite selbst bleibt unverändert. E-16 ist eine Produktentscheidung,
-- Einordnung in Abschnitt 12.

commit;
```

#### Rückabwicklung 6

Dateiname: `2026-09-02_e55_ranking_tables_down.sql`

```sql
-- Stellt supabase-schema.sql:214 und :224 wörtlich her.
-- ACHTUNG: danach kann jeder Nutzer seinen Punktestand und seine Trophäen
-- wieder selbst setzen. Vorher Abfrage M laufen lassen und sichern.
begin;

drop policy if exists "own city scores select" on public.user_city_scores;
drop policy if exists "own trophies select"    on public.user_trophies;

create policy "own city scores" on public.user_city_scores
  for all using (auth.uid() = user_id);
create policy "own trophies" on public.user_trophies
  for all using (auth.uid() = user_id);

grant insert, update, delete on public.user_city_scores to authenticated, anon;
grant insert, update, delete on public.user_trophies    to authenticated, anon;

-- Absichtlich KEIN "grant ... to public", gleiche Begründung wie in
-- Rückabwicklung 1.

commit;
```

---

### 11.7 Diagnoseabfragen K bis T

Alle rein lesend, alle unausgeführt. **K bis Q vor den Migrationen laufen
lassen und die Ausgabe sichern**, R bis T danach zur Kontrolle. Die
Buchstaben laufen hinter Abschnitt 7 weiter, A bis J stehen dort.

```sql
-- K) Wer darf heute welche Funktion rufen? Die eine Abfrage, die E-52
--    beantwortet.
--    Bewusst mit has_function_privilege und NICHT mit
--    information_schema.role_routine_grants (so steht es als Prüfung in
--    backend-inventory.md, E-52): das information_schema zeigt Rechte, die an
--    PUBLIC vergeben sind, gar nicht an, und genau die sind hier der Befund.
--    has_function_privilege beantwortet die Frage über alle Wege: einzeln
--    vergeben, über PUBLIC, über Rollenmitgliedschaft.
select p.oid::regprocedure                                   as funktion,
       has_function_privilege('anon',          p.oid, 'EXECUTE') as anon_darf,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_darf,
       p.prosecdef                                           as security_definer,
       pg_get_userbyid(p.proowner)                           as owner,
       p.proconfig                                           as settings
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.prokind = 'f'
 order by 2 desc, 1;

-- L) Doppelt definierte Funktionen (E-21), zweistufig.
--    L1 findet nur die Fälle mit UNTERSCHIEDLICHEN Signaturen. Bei gleicher
--    Signatur ersetzt die zweite Ausführung die erste, es existiert also nur
--    eine Zeile, und L1 bleibt leer. Genau so liegt der Fall bei
--    start_group_session (beide Fassungen nehmen (p_session_id uuid)).
select p.proname,
       count(*)                                              as fassungen,
       array_agg(p.oid::regprocedure::text order by p.oid)   as signaturen
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prokind = 'f'
 group by 1
having count(*) > 1;

--    L2 ist deshalb die eigentliche Prüfung: den Rumpf ausgeben und mit den
--    beiden Dateien vergleichen. 2026-06-04_group_sessions.sql:193 gegen
--    2026-06-05_team_sessions.sql:473, und 2026-06-05:105 gegen
--    2026-06-07_city_backfill_and_slug_match.sql:41. Welche Fassung läuft,
--    entscheidet die Reihenfolge, in der jemand die Dateien in den Editor
--    kopiert hat.
select p.oid::regprocedure as funktion, pg_get_functiondef(p.oid) as rumpf
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('start_group_session', '_team_generate_orders');

-- M) Policies im Ist-Zustand für die Tabellen dieses Nachtrags.
--    Gleiche Form wie Abfrage A, andere Tabellen.
select tablename, policyname, cmd, qual, with_check
  from pg_policies
 where schemaname = 'public'
   and tablename in ('facts', 'user_trophies', 'user_city_scores')
 order by tablename, policyname;

-- N) Voraussetzung für Migration 6, nicht Nachkontrolle: gehören Tabellen und
--    Definer-Funktionen derselben Rolle, und ist FORCE RLS aus?
--    Liefert rls_forced = true, dann NICHT ausführen: der Trigger wäre
--    danach ausgesperrt.
select c.relname,
       pg_get_userbyid(c.relowner) as owner,
       c.relrowsecurity            as rls_enabled,
       c.relforcerowsecurity       as rls_forced
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('facts', 'user_trophies', 'user_city_scores');

select p.proname,
       pg_get_userbyid(p.proowner) as owner,
       p.prosecdef                 as security_definer,
       p.proconfig                 as settings
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('handle_fact_collected', 'handle_user_fact_created',
                     'unlock_trophy');

-- O) Ist E-53 schon benutzt worden?
select is_approved, count(*)
  from public.facts
 where is_user_created = true
 group by 1
 order by 1;

select id, titel, created_by, created_at
  from public.facts
 where is_user_created = true and is_approved = true
 order by created_at desc
 limit 50;

--    Zur Auslegung: eine Zeile hier bedeutet NICHT Missbrauch. Sie kann von
--    einem Admin freigegeben worden sein (admin/index.html:1426) oder vom
--    Client selbst. Die beiden Fälle sind in den Daten nicht unterscheidbar,
--    weil es kein Protokoll darüber gibt, wer wann freigegeben hat. Das ist
--    E-58, und es ist der Grund, warum diese Abfrage nur eine Liste zum
--    Durchsehen liefert und keine Antwort.

-- P) Ist E-55 schon benutzt worden? Trophäenschlüssel, die kein Serverpfad
--    und kein Client-Aufruf erzeugt haben kann.
--    Die Liste im Array sind die 19 Schlüssel der Trigger
--    (supabase-schema.sql:268-334, :347-359) und die 8, die der Client über
--    unlock_trophy holt (app.jsx:402,415,427,725-727,804,975).
--    Das NOT LIKE nimmt die Stadt-Trophäen `<stadt>_first` heraus (:275-279),
--    deren Namen von den Daten abhängen.
select trophy_key, count(*) as nutzer, min(unlocked_at), max(unlocked_at)
  from public.user_trophies
 where trophy_key <> all (array[
         'erster','entdecker','sammler','kenner','experte','legende',
         'stadtkenner','weltenbummler','grand_tour',
         'chronist','meister_hist','steinleser','meister_arch',
         'mythenjaeger','lacher','flussfischer',
         'tagesrekord','wochenend_held','geheimtipp',
         'fruehaufsteher','nachtschwärmer','nachtfalter','kommentator',
         'koop_first','koop_squad','team_first','team_victor'
       ])
   and trophy_key not like '%\_first'
 group by 1
 order by 2 desc;

--    Vollbild zum Vergleich, weil ein leeres Ergebnis oben nichts beweist:
select trophy_key, count(*) as nutzer
  from public.user_trophies group by 1 order by 2 desc;

-- Q) Stimmen die Punktestände mit dem Gesammelten überein?
--    score_total wird ausschließlich vom Trigger hochgezählt, je Insert um 1
--    (supabase-schema.sql:255-258), und collected_facts hat (user_id, fact_id)
--    als Primärschlüssel. Beide Zahlen müssen gleich sein.
select p.id, p.score_total, count(cf.fact_id) as gesammelt
  from public.profiles p
  left join public.collected_facts cf on cf.user_id = p.id
 group by 1, 2
having p.score_total <> count(cf.fact_id)
 order by p.score_total - count(cf.fact_id) desc;

--    Zur Auslegung, und das ist wichtig, sonst jagt jemand ein Phantom:
--    eine Abweichung nach OBEN heißt entweder gesetzt (E-24) oder gelöscht.
--    Die Policy "own collected" (:153) erlaubt heute FOR ALL, ein Nutzer darf
--    seine collected_facts also löschen, und score_total geht dabei nicht
--    zurück. Erst nach Migration 3a ist diese zweite Erklärung weg.

--    Dieselbe Probe je Stadt hat eine zusätzliche legitime Fehlerquelle und
--    ist deshalb schwächer: der Backfill vom 07.06.2026
--    (2026-06-07_city_backfill_and_slug_match.sql) hat facts.city NACH dem
--    Sammeln gesetzt. Alte Sammlungen liegen damit auf einem anderen
--    Stadtschlüssel als die Neuberechnung ergibt, ganz ohne Zutun eines
--    Nutzers. Das ist E-56. Eine Abweichung hier ist ein Hinweis, kein Befund.
select ucs.user_id, ucs.city_key, ucs.score, coalesce(c.ist, 0) as neu_gerechnet
  from public.user_city_scores ucs
  left join (
    select cf.user_id,
           lower(coalesce(f.city,
             case when f.nr like 'MUC%' then 'München'
                  when f.nr like 'REG%' then 'Regensburg'
                  when f.nr like 'ROM%' then 'Rom'
                  when f.nr like 'PAU%' then 'Passau'
                  else 'unknown' end)) as city_key,
           count(*) as ist
      from public.collected_facts cf
      join public.facts f on f.id = cf.fact_id
     group by 1, 2
  ) c on c.user_id = ucs.user_id and c.city_key = ucs.city_key
 where ucs.score <> coalesce(c.ist, 0)
 order by ucs.score - coalesce(c.ist, 0) desc;
```

Nachkontrolle. Diese müssen **nach** den jeweiligen Migrationen gelten:

```sql
-- R) nach Migration 4.
--    Erwartet: unlock_trophy anon = false, authenticated = true;
--              check_username anon = true (SONST IST DIE REGISTRIERUNG STUMM
--              KAPUTT); _is_group_member authenticated = true (sonst ist der
--              Gruppenmodus tot).
select has_function_privilege('anon',
         'public.unlock_trophy(uuid, text)', 'EXECUTE')       as unlock_anon,
       has_function_privilege('authenticated',
         'public.unlock_trophy(uuid, text)', 'EXECUTE')       as unlock_auth,
       has_function_privilege('anon',
         'public.check_username(text)', 'EXECUTE')            as username_anon,
       has_function_privilege('authenticated',
         'public._is_group_member(uuid, uuid)', 'EXECUTE')    as member_auth,
       has_function_privilege('anon',
         'public.tag_endpoint(uuid, numeric, numeric)', 'EXECUTE') as tag_anon;

--    Und die vollständige Gegenprobe: keine Funktion außer den drei bewusst
--    offenen darf für anon noch ausführbar sein.
--    Erwartet: genau check_username, get_leaderboard, fact_i18n_langs.
select p.oid::regprocedure as noch_fuer_anon_offen
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prokind = 'f'
   and has_function_privilege('anon', p.oid, 'EXECUTE')
 order by 1;

-- S) nach Migration 5.
--    Erwartet: insert = true, update = false, delete = false, select = true.
select has_table_privilege('authenticated', 'public.facts', 'INSERT') as ins,
       has_table_privilege('authenticated', 'public.facts', 'UPDATE') as upd,
       has_table_privilege('authenticated', 'public.facts', 'DELETE') as del,
       has_table_privilege('authenticated', 'public.facts', 'SELECT') as sel,
       has_table_privilege('anon',          'public.facts', 'INSERT') as ins_anon;

--    Und die Policy selbst: with_check muss is_approved nennen.
select policyname, cmd, with_check
  from pg_policies
 where schemaname = 'public' and tablename = 'facts';

-- T) nach Migration 6.
--    Erwartet: alle sechs Schreibrechte false, beide Leserechte true.
select has_table_privilege('authenticated', 'public.user_trophies',    'INSERT') as tr_ins,
       has_table_privilege('authenticated', 'public.user_trophies',    'UPDATE') as tr_upd,
       has_table_privilege('authenticated', 'public.user_trophies',    'DELETE') as tr_del,
       has_table_privilege('authenticated', 'public.user_city_scores', 'INSERT') as cs_ins,
       has_table_privilege('authenticated', 'public.user_city_scores', 'UPDATE') as cs_upd,
       has_table_privilege('authenticated', 'public.user_city_scores', 'DELETE') as cs_del,
       has_table_privilege('authenticated', 'public.user_trophies',    'SELECT') as tr_sel,
       has_table_privilege('authenticated', 'public.user_city_scores', 'SELECT') as cs_sel;
```

**R, S und T sind auch die Regressionsprobe.** Ein späteres, gut gemeintes
`grant all on all tables in schema public to authenticated` oder ein
`alter default privileges` macht in einer Zeile alles wieder auf. Wer das nicht
merken will, legt die drei Abfragen neben Abfrage F.

### 11.8 Negativtests 37 bis 63

Gleiche Bedingungen wie Abschnitt 8: **formuliert, nicht ausgeführt**, weil aus
diesem Repository keine Verbindung zu einem Supabase-Projekt aufgebaut wird. Sie
gehören in eine Testdatenbank. Zwei Testkonten `A` und `B`, Aufrufe mit deren
Session-Token, `anon`-Fälle mit dem öffentlichen Schlüssel und ohne Token. Die
Nummerierung läuft hinter Abschnitt 8 weiter.

Migration 4, E-52:

| # | Handlung | Vor der Migration | Danach erwartet | Prüft |
|---|---|---|---|---|
| 37 | `A` ruft `unlock_trophy(B, 'legende')` | **erlaubt, `B` hat die Trophäe** | Fehler `42501`, `foreign account` | Kernfall E-52 |
| 38 | `A` ruft `unlock_trophy(A, 'nachtschwärmer')` | erlaubt | **erlaubt** | Umlaut im Schlüssel bleibt zulässig |
| 39 | `A` ruft `unlock_trophy(null, 'kommentator')` | Fehler, `user_id` ist `NOT NULL` | **erlaubt**, landet bei `A` | Nullfall, wie Test 18 |
| 40 | `anon` ruft `unlock_trophy(A, 'legende')` | **erlaubt, `A` hat die Trophäe** | Fehler, kein `EXECUTE` | „ohne Konto darauf schreiben" |
| 41 | `A` ruft `unlock_trophy(A, <65 Zeichen>)` | erlaubt, Zeile wird geschrieben | Fehler `22023` | Längengrenze |
| 42 | `anon` ruft `check_username('irgendwas')` | erlaubt | **erlaubt** | **der wichtigste Nichtbruch-Test** |
| 43 | `A` liest `group_sessions` einer eigenen Sitzung | erlaubt | **erlaubt** | `_is_group_member` ist noch ausführbar |
| 44 | `A` fährt eine Gruppensitzung durch: anlegen, starten, sammeln | erlaubt | **erlaubt** | die Helfer sind aus Definer-Funktionen erreichbar |
| 45 | `anon` ruft `create_group_session(...)` | Fehler `not_authenticated` aus dem Rumpf | Fehler `42501`, kein `EXECUTE` | äußere Grenze statt Rumpfprüfung |
| 46 | `anon` ruft `get_my_rank(B, 'global', 'weekly')` | liefert eine Zahl | Fehler, kein `EXECUTE` | fremder Rang ohne Konto |
| 47 | `A` ruft `_haversine_m(48.5, 13.4, 48.6, 13.5)` | erlaubt | Fehler, kein `EXECUTE` | interne Helfer sind keine API |
| 48 | `anon` ruft `get_leaderboard('global','weekly')` | erlaubt | **erlaubt, unverändert** | E-16 bleibt bewusst offen |

Migration 5, E-53:

| # | Handlung | Vor der Migration | Danach erwartet | Prüft |
|---|---|---|---|---|
| 49 | `A` fügt einen Fakt genau wie `api.jsx:165-177` ein | erlaubt | **erlaubt** | Nichtbruch der PWA |
| 50 | `A` fügt einen Fakt mit `is_approved: true` ein | **erlaubt, sofort für alle sichtbar** | Fehler `42501` | Kernfall E-53 |
| 51 | `A` fügt einen Fakt ohne `is_approved` ein | erlaubt, Default `false` | **erlaubt** | Default greift weiter |
| 52 | `A` fügt einen Fakt mit `is_approved: null` ein | erlaubt | **erlaubt**, unsichtbar und moderierbar | `is not true` statt `= false` |
| 53 | `A` fügt einen Fakt mit `created_by: B` ein | abgelehnt | abgelehnt | unverändert |
| 54 | `A` ändert `titel` seines eigenen Fakts | abgelehnt, keine `UPDATE`-Policy | abgelehnt, jetzt zusätzlich ohne Recht | Bearbeiten gibt es nicht |
| 55 | `A` liest den eigenen, nicht freigegebenen Fakt (`.select()` am Insert) | erlaubt | **erlaubt** | `SELECT` unberührt |
| 56 | Nur wenn 5b lief: `A` fügt einen Fakt mit `rating: 5` ein | erlaubt | Fehler `42501` | optionale Verschärfung |

Migration 6, E-55:

| # | Handlung | Vor der Migration | Danach erwartet | Prüft |
|---|---|---|---|---|
| 57 | `A` setzt `user_city_scores.score = 9999` in der eigenen Zeile | **erlaubt** | Fehler `42501` | Kernfall E-55 |
| 58 | `A` fügt `user_city_scores(A, 'rom', 9999)` ein | **erlaubt** | Fehler `42501` | Insert statt Update |
| 59 | `A` fügt `user_trophies(A, 'legende')` direkt ein | **erlaubt** | Fehler `42501` | Tabellenweg zu |
| 60 | `A` löscht eine eigene `user_trophies`-Zeile | **erlaubt** | Fehler `42501` | `FOR ALL` schloss `DELETE` ein |
| 61 | `A` ruft `unlock_trophy(A, 'kommentator')` | erlaubt | **erlaubt** | der Definer-Weg bleibt offen |
| 62 | `A` sammelt einen Fakt in Reichweite; `score_total`, `user_city_scores` und `user_trophies` wachsen | ja | **ja** | **der Trigger ist nicht ausgesperrt** |
| 63 | `A` liest die Trophäen von `B` | erlaubt | **erlaubt, unverändert** | E-16 bleibt bewusst offen |

**Die vier Tests, an denen es hängt.** Test 42, weil ein Fehlschlag bedeutet,
dass die Registrierung in beiden Clients stumm beschädigt ist. Test 43 und 44,
weil ein Fehlschlag den Gruppenmodus tot bedeutet und weil er die einzige Probe
auf den Rechte-Trap aus Befund 7 ist. Test 62, weil ein Fehlschlag bedeutet,
dass die Eigentümer-Annahme aus Abfrage N falsch war und Migration 6
zurückgerollt werden muss. Die drei eigentlichen Sicherheitstests (37, 50, 57)
sind dagegen die einfachen: sie schlagen entweder fehl oder nicht.

### 11.9 Auswirkung auf diese App

**Keine.** Nach Migration 4, 5 und 6 scheitert in `lib/` keine Stelle. Das ist
nachgesehen und nicht angenommen, und der Weg dorthin hat einen Haken, der
weitergegeben gehört.

Die vollständige Liste der Supabase-Berührungen dieses Repositories, ermittelt
über

```
grep -rn --include=*.dart -E "\.(from|rpc)\s*(<[^>]*>)?\s*\(" lib/
```

| Stelle | Was | Betroffen von |
|---|---|---|
| `lib/features/facts/data/datasources/remote/supabase_fact_remote_data_source.dart:46-48` | `from('facts').select().eq('is_approved', true)` | Migration 5 berührt `SELECT` nicht |
| `.../supabase_fact_remote_data_source.dart:57` | `from('facts').select().eq('id', id)` | dito |
| `lib/features/identity/data/datasources/remote/supabase_auth_remote_data_source.dart:295-298` | `rpc('check_username')`, **ohne Anmeldung** | Migration 4 gibt die Funktion ausdrücklich an `anon` frei |
| `.../supabase_auth_remote_data_source.dart:330-332` | `from('profiles').update({username})` | keine der drei Migrationen; `username` bleibt in Migration 1 freigegeben |

**Der Haken: das Muster `.rpc(` findet den RPC-Aufruf dieses Repositories
nicht.** Er heißt `_client.rpc<Object?>(`
(`supabase_auth_remote_data_source.dart:295`), mit einem Typparameter zwischen
Name und Klammer. Abschnitt 10 nennt `.rpc(` als eines der fünf Suchmuster für
die dortige Erhebung. Deren **Ergebnis** ist trotzdem richtig, weil
`check_username` dort ausdrücklich genannt ist, die **Methode** hätte den
Aufruf aber verfehlt. Wer diese Erhebung später wiederholt, nimmt
`\.rpc\s*(<[^>]*>)?\s*\(` oder sucht nach den Funktionsnamen. Das ist der
Grund, warum in der Tabelle oben nach `from` **und** `rpc` gesucht wurde.

**Was künftige Schritte beachten müssen**, jeweils mit der Stelle, an der es
schiefgehen wird:

- **Fakt erstellen (Phase 7).** Der Insert muss `created_by` auf die eigene
  Kennung, `is_user_created` auf `true` und `is_approved` auf `false` setzen
  oder weglassen. Nach Migration 5 ist ein `true` dort keine stille Freigabe
  mehr, sondern ein `42501`, das in der Fehlerabbildung der Datenschicht
  ankommt. Wenn 5b läuft, gilt dasselbe für `rating`, `bewertungen`, `nr` und
  `city`.
- **Trophäen (`progression`).** Der Block hat heute keine Datenschicht, das ist
  ausdrücklich so entschieden
  (`lib/features/progression/presentation/widgets/trophy_list.dart:39-45`,
  `lib/features/progression/domain/entities/trophy.dart:17-19`). Wenn sie
  kommt, ist die Leserichtung unproblematisch, und die Schreibrichtung ist
  keine: `user_trophies` ist nach Migration 6 für den Client nicht schreibbar,
  und `unlock_trophy` zu rufen würde den Fehler der PWA wiederholen, den E-49
  beschreibt. Der Server entscheidet, welche Trophäe fällt.
- **Punktestände.** `user_city_scores` ist nach Migration 6 nur lesbar. Wer
  einen Stadtpunktestand anzeigen will, liest ihn oder ruft
  `get_leaderboard`; er rechnet ihn nicht nach. Das ist derselbe Fehler, den
  `wltDeriveTrophies` in der PWA macht (E-49).

### 11.10 Was nach Migration 4 bis 6 immer noch offen ist

Ergänzung zu Abschnitt 9, damit niemand die sechs Migrationen für eine
abgeschlossene Absicherung hält.

- **Der Client bestimmt weiter, welche Trophäe er bekommt.** `unlock_trophy`
  ist nach Migration 4 an das eigene Konto gebunden und nimmt jeden Schlüssel
  von höchstens 64 Zeichen. Ein Nutzer kann sich `legende` holen, ohne 250
  Fakten gesammelt zu haben. Behebung: die Trophäenlogik gehört vollständig auf
  den Server, `unlock_trophy` verschwindet als öffentliche Funktion. Das ist
  E-49 und eine Architekturentscheidung, siehe `backend-inventory.md`,
  Abschnitt 6.
- **Es gibt keine Schlüsselliste in der Datenbank.** Welche Trophäen existieren,
  weiß nur `wallet-colors.jsx:103`. Eine Tabelle `trophies(key, ...)` mit
  Fremdschlüssel aus `user_trophies` wäre die Prüfung, die Migration 4 nicht
  leisten kann. Neue Tabelle, also Entscheidung.
- **`facts.rating` und `facts.bewertungen` bleiben clientsetzbar**, solange 5b
  nicht läuft, und danach nur beim Einfügen. Wer sie später ändern darf, ist
  offen, weil es heute keinen Bewertungsweg gibt.
- **Ein Fakt kann weiterhin nicht bearbeitet werden**, auch nicht vom
  Verfasser. Das ist der Zustand von vorher, kein Ergebnis dieser Migration,
  aber es fällt jetzt auf, weil die Rechte ausdrücklich stehen.
- **Die Leseseite bleibt vollständig offen.** `user_trophies` und
  `user_city_scores` sind für jeden lesbar, `get_leaderboard` gibt die
  Nutzerkennungen an `anon` heraus. Das ist E-16, und es ist die einzige der
  vier Einordnungen unten, die eine Migration bräuchte, sobald die Entscheidung
  da ist.
- **Es gibt kein Protokoll darüber, wer freigegeben hat.** Abfrage O liefert
  eine Liste zum Durchsehen, keine Antwort. Nach einem Missbrauch von E-53 ist
  nicht rekonstruierbar, ob ein Admin oder der Verfasser den Fakt freigegeben
  hat. Dasselbe Loch wie das fehlende Buchungsjournal in Abschnitt 9, und
  derselbe Grund: E-58.
- **Alles hier steht unter dem Vorbehalt aus `backend-inventory.md`,
  Abschnitt 2.** Ohne Schema-Dump der laufenden Datenbank ist nicht bekannt, was
  von den acht bestehenden Migrationen tatsächlich gelaufen ist. Die Abfragen K
  bis Q sind die kleine Fassung dieses Dumps für den Ausschnitt, den dieser
  Nachtrag anfasst.

---

## 12. Vier Befunde, für die eine Migration die falsche Antwort ist

E-16, E-54, E-56 und E-57 aus `backend-inventory.md`, Abschnitt 3. Für jeden
davon **könnte** man SQL schreiben. Es wäre in allen vier Fällen eine
Entscheidung, die als Technik verkleidet daherkommt, und deshalb steht hier
statt einer Migration die Frage, die vorher zu beantworten ist, und wem sie
gehört.

Die Zuordnung benutzt drei Zuständigkeiten: **Produkt** (was der Nutzer sehen
und erleben soll), **Ökonomie** (was etwas kostet und was es wert ist),
**Architektur** (wo eine Regel lebt und welchem Vertrag sie folgt).

### E-16: Rangliste und Trophäen sind für jeden lesbar

> **Überholt am 02.09.2026. Die Entscheidung ist gefallen, die Migration steht
> in Abschnitt 14.** Was hier unten steht, ist die Begründung, warum es eine
> Entscheidung brauchte, und sie bleibt lesbar, weil Migration 6 im
> SQL-Kommentar darauf verweist. Der Zuschnitt der Umsetzung weicht in zwei
> Punkten von dem ab, was dieser Abschnitt erwartet hat: die Rangliste bricht
> **nicht** vollständig ohne Rückgabeänderung ab, und `show_real_name` ist nach
> der Entscheidung kein Schalter mehr, sondern eine Spalte ohne Leser. Beides in
> 14.0 und 14.8.

**Warum keine Migration reicht.** Die Migration wäre eine Zeile:
`drop policy "public read trophies"`, dazu dieselbe für `user_city_scores`, und
die beiden Policies aus Migration 6 tragen den eigenen Zugriff schon. Danach
sieht niemand mehr die Trophäen eines anderen. **Das bricht die Rangliste
nicht** (`get_leaderboard` ist `SECURITY DEFINER` und liest an RLS vorbei), aber
es bricht möglicherweise ein Produktversprechen, das niemand aufgeschrieben hat.

Die eigentliche Frage steht davor: **was darf ein fremder Nutzer sehen?** Es
gibt eine Teilantwort im Bestand, und sie ist schmaler als der Ist-Zustand.
`profiles` ist über die Policy `own profile` (`supabase-schema.sql:141`) nur für
den Eigentümer lesbar, und der Schalter `show_real_name` entscheidet, ob in der
Rangliste der echte Name oder das Pseudonym erscheint
(`get_leaderboard`, `:382`, `:395`, `:420`, `:431`). Der Bestand sagt also:
Identität ist geschützt, und über die Sichtbarkeit entscheidet der Nutzer.
`user_trophies` und `user_city_scores` widersprechen dem mit `USING (true)`.

Und sie widersprechen ihm auf eine Weise, die mehr freigibt als einen Namen:

- **`user_trophies` ist eine Verhaltensakte.** `fruehaufsteher`,
  `nachtschwärmer`, `wochenend_held`, `tagesrekord` sagen, zu welchen
  Tageszeiten jemand unterwegs war, `unlocked_at` sagt, wann.
- **`user_city_scores` ist Aufenthaltsdaten.** Die Tabelle sagt, in welchen
  Städten ein Nutzer wie viele Fakten gesammelt hat, und Fakten haben
  Koordinaten. Über `get_leaderboard` bekommt jeder ohne Konto die
  Nutzerkennungen der Top 10 (`:371`), und mit einer Kennung liest er dann
  beide Tabellen direkt aus.

Das ist der Punkt, an dem der Befund die Nummer E-16 verlässt: es geht nicht um
eine Policy, sondern um Standortdaten von identifizierbaren Personen.
`docs/engineering/security.md` verlangt für neue sensible Daten eine
Freigabe; hier sind sie nicht neu, sondern bereits offen, was die Freigabe nicht
ersetzt, sondern dringlicher macht.

**Wem sie gehört: Produkt**, mit einer Auflage. Die Entscheidung „was sieht ein
Fremder" ist eine Produktfrage (Janek). Die Umsetzung ist danach klein und
gehört zu Migration 6. Die Datenschutzseite ist keine Produktfrage und keine
Geschmacksfrage: solange sie offen ist, ist der Zustand nicht „unentschieden",
sondern „offen zugunsten der weitesten Auslegung". Wer die Entscheidung
verschiebt, verschiebt sie in diese Richtung.

### E-54: Coins sind über Gruppensitzungen unbegrenzt farmbar

**Warum keine Migration reicht.** Der Geltungsbereich der Sperre ließe sich
umschreiben, das ist ein Index:

```sql
-- NICHT AUSFÜHREN. Zwei mögliche Sperren, und keine ist ohne Entscheidung
-- richtig.
--   pro Nutzer und Fakt, einmalig:
create unique index ... on public.group_collects (user_id, fact_id);
--   pro Sitzung, wie heute (2026-06-05_team_sessions.sql:61-67):
create unique index ... on public.group_collects (session_id, fact_id) where team is null;
```

Die erste Zeile ist nicht einmal so baubar, denn `group_collects` hat gar keine
Spalte `user_id`: die Gutschrift geht an **alle** Teilnehmer der Sitzung
(`2026-06-04_group_sessions.sql:329-333`), und wer wann dabei war, steht in
`group_participants`. Die Sperre „einmal je Nutzer und Fakt" bräuchte also
zuerst ein anderes Datenmodell, und schon das ist keine Migration, sondern eine
Schemaänderung mit Backfill.

Die eigentliche Frage ist die Spielregel: **wofür gibt es 50 Coins?** Für ein
Fakt, das man noch nicht kannte? Dann ist die Sperre „einmal je Nutzer und
Fakt", und Wiederholung mit Freunden bringt nichts. Für das Erlebnis, gemeinsam
unterwegs zu sein? Dann ist die heutige Sperre richtig, und der Missbrauch ist
der Preis. Dazwischen liegen die Varianten, die man in einer Datenbank auch
bauen könnte, aber nur, wenn jemand sie will: ein Tageskontingent, ein
Mindestabstand zwischen zwei Sitzungen, eine geringere Gutschrift beim zweiten
Mal.

Dieselbe Frage stellt `tag_endpoint` noch einmal deutlicher. Die 100 Coins gehen
an das Team, das zuerst am **Endpunkt** ist
(`2026-06-05_team_sessions.sql:679-687`), und der Endpunkt ist der Treffpunkt,
den der Host beim Anlegen selbst setzt (`create_team_session`, `:277-278`). Wer
seine eigene Position als Treffpunkt einträgt, ist bereits am Ziel. Eine
serverseitige Prüfung dagegen ist nicht formulierbar, solange die Position vom
Client kommt (E-07). **Der Deckel aus Migration 2b greift hier übrigens nicht**,
weil `tag_endpoint` `profiles.coins` direkt schreibt und nicht über
`increment_coins` geht, siehe Abschnitt 4.1.

**Wem sie gehört: Ökonomie.** Und es ist die Frage, deren Antwort schon einmal
formuliert wurde: `backend-inventory.md`, E-54, letzter Absatz, „solange Beträge
und Anlass im Client bestimmbar sind, darf für Coins nichts zu haben sein, was
Geld wert ist". Das ist keine technische Aussage, das ist eine Produktzusage.
Solange sie gilt, ist E-54 ein Ärgernis und kein Schaden, und die Migration hat
Zeit. Sobald jemand für Coins etwas anbietet, ist sie zuerst zu klären und dann
zu bauen.

### E-56: Drei Stadtschlüssel-Normalisierungen, und Rom fällt durch alle

**Warum keine Migration reicht.** Eine kanonische Funktion ist schnell
geschrieben, `_slugify` (`2026-06-07_city_backfill_and_slug_match.sql:19`) ist
der Kandidat. Das Problem ist nicht die Funktion, sondern **was mit den Daten
passiert, die unter den alten Schlüsseln liegen**. `user_city_scores` hat
`city_key` im Primärschlüssel. Eine Umstellung von `münchen` auf `muenchen`
bedeutet: Zeilen umschreiben, Kollisionen zusammenrechnen (was, wenn ein Nutzer
Zeilen für `münchen` **und** `muenchen` hat?), und die Rangliste zeigt für die
Dauer der Umstellung falsche Zahlen. Das ist eine Datenmigration mit
Verhaltensänderung, kein `create or replace`.

Und es gibt eine Frage davor, die niemand aus dem Code lesen kann: **wie heißt
Rom?** `handle_fact_collected` bildet `nr LIKE 'ROM%'` auf `'Rom'` ab
(`supabase-schema.sql:245`), der Backfill vom 07.06. auf `'Rome'`, der
Ranglistenfilter schickt `rom` (`screen-profil.jsx:9,20`). Einer der drei Werte
ist der richtige, und die Antwort ist Inhalt, nicht Technik: sie hängt daran, in
welcher Sprache Städtenamen in `facts.city` stehen sollen und was der Nutzer
sieht. Multi-City ist eine Invariante dieses Projekts (`CLAUDE.md`), also ist
das keine Randnotiz zu einer Stadt, sondern der Datenvertrag für jede weitere.

Dazu der Zusatzverdacht aus dem Befund: wenn
`04_Datenpipeline/scripts/migrate_nr_codes.py:24-31` je über die ganze Tabelle
gelaufen ist, trägt jede Stadt nördlich von Passau ein `PAU`-Präfix. Das wäre
kein Anzeigefehler, sondern falsche Stammdaten, und dann ist die Reihenfolge
umgekehrt: erst die Daten prüfen (Abfrage aus dem Befund, `count(*)` je `city`
und je `split_part(nr,'_',1)`), dann entscheiden, dann eine Funktion.

**Wem sie gehört: Architektur**, mit einer Inhaltsfrage darin. Der Datenvertrag
für den Stadtschlüssel ist eine Architekturentscheidung (Dairen): eine Funktion,
ein Ort, ein Format, und der Neubau des Backends ist der natürliche Zeitpunkt
dafür, weil eine Datenmigration dann ohnehin ansteht
(`backend-inventory.md`, Abschnitt 5a). Der Name jeder Stadt ist Inhalt und
gehört zu Janek. Bis beides beantwortet ist, wäre eine kanonische Funktion nur
die vierte Normalisierung neben den drei bestehenden.

### E-57: Der Team-Ausgleich kann nicht wirken

**Warum keine Migration reicht.** Der Rechenfehler ist klar und wäre klein zu
beheben: `v_a` und `v_b` sind zwei Permutationen derselben Menge, `any()` ist
Mengenmitgliedschaft, also ist `v_dist_a` immer gleich `v_dist_b` und die
Schwelle immer erfüllt. Wer die Summe entlang der **Reihenfolge** rechnen will,
braucht eine Wegstrecke von Station zu Station, also `unnest ... with ordinality`
und `lag()`, nicht `sum(... where id = any(...))`.

Nur behebt das nichts, was jemandem auffällt, denn dahinter steht ein zweiter
Befund, und der ist der eigentliche: **beide Teams laufen denselben
Stationssatz.** Das ist kein Versehen, der Partial-Index trägt es im Kommentar
(`2026-06-05_team_sessions.sql:56-57`, „beide Teams dürfen denselben Fakt
unabhängig sammeln"). Wenn beide Teams dieselben Stationen haben, ist die
Wegstrecke beider Teams von der Reihenfolge abhängig und in der Summe gleich.
Ein korrekt gerechneter Ausgleich würde dann feststellen, dass es nichts
auszugleichen gibt, und das Resampling bliebe genauso unerreichbar wie heute,
nur mit mehr Code.

Die eigentliche Frage ist die Spielregel: **was unterscheidet die zwei Teams?**
Vier Antworten sind denkbar, und sie führen zu vier verschiedenen Funktionen:
verschiedene Stationen (dann ist der Ausgleich sinnvoll und nötig), dieselben
Stationen in verschiedener Reihenfolge (dann ist der Ausgleich gegenstandslos
und der Wettbewerb ist ein Rennen), dieselben Stationen in derselben Reihenfolge
(dann zählt nur die Zeit), oder gar kein Wettbewerb, sondern eine gemeinsame
Aufgabe. Die dritte Antwort ist die einzige, die heute im Code als Absicht
erkennbar ist, und sie widerspricht dem Namen `auto_balance_teams`.

Der Nebenbefund gehört mit derselben Begründung dazu: die Winkelnormalisierung
`abs(((x - y) + pi()) - pi())` kürzt sich zu `abs(x - y)`, gemeint war
offensichtlich ein Modulo. Sie repariert man mit, wenn man ohnehin an der
Funktion ist. Vorher lohnt es nicht, weil sie eine Auswahl beeinflusst, deren
Zweck offen ist.

**Wem sie gehört: Produkt.** Der Spielablauf im Team-Modus ist eine
Produktentscheidung (Janek), und Schritt 40 des Neubaus baut laut
`backend-inventory.md`, Abschnitt 6, ohnehin gegen diesen Zustand, ob er behoben
ist oder nicht. Solange die Regel offen ist, ist der wirkungslose Ausgleich
**kein Sicherheitsbefund und keine Dringlichkeit**: er ist ein Stück Code, das
verspricht, etwas zu tun, und nichts tut. Der Schaden daran ist, dass jemand ihn
für eine Vorkehrung hält, und dagegen hilft dieser Absatz, keine Migration.

---

## 13. Wo dieser Nachtrag von seinem Auftrag abweicht

Vollständig, weil eine stillschweigende Abweichung schlimmer ist als eine
gemeldete. Die Abweichungen betreffen alle die Wahl des Mittels, keine den
Zweck.

| # | Auftrag | Was daraus geworden ist | Warum |
|---|---|---|---|
| 1 | E-53 braucht den Spaltenrechte-Umweg aus Abschnitt 3 | `WITH CHECK` auf `is_approved`, keine Spaltenrechte | Bei `INSERT` sieht `WITH CHECK` die Spalte. Ein `revoke insert (is_approved)` würde `api.jsx:176` abweisen, obwohl der Aufruf richtig ist. Der Umweg gilt für `UPDATE`, und `UPDATE` ist auf `facts` nicht offen. |
| 2 | „der Eigentümer darf seine Zeile anlegen und **bearbeiten**" | Bearbeiten bleibt zu, das Rezept steht ungenutzt in 11.5 | Es gibt keine `UPDATE`-Policy auf `facts`. Bearbeiten wäre eine neue Fähigkeit, kein Sicherheitsfix. |
| 3 | E-52: „die Funktion nimmt die Kennung nicht mehr entgegen" | Signatur bleibt, Wert wird nicht mehr geglaubt; die parameterfreie Fassung liegt als Block 4c bereit und läuft nicht | Vier Gründe in 11.4, der schwerste: `app.jsx:551` verschluckt den Fehler, ein Bruch wäre unsichtbar. |
| 4 | E-52 betrifft drei Funktionen | Migration 4 behandelt nur `unlock_trophy`, plus die Ausführrechte des ganzen Bestands | `increment_coins` ist Block 2a, `collect_fact_validated` ist Block 3b. Beide existieren, beide dürfen nicht doppelt geschrieben werden. |
| 5 | E-55: „Schreibrechte weg" | zusätzlich zwei neue `SELECT`-Policies, die heute nichts ändern | Ohne sie nimmt die E-16-Entscheidung später jedem Nutzer den Blick auf die eigenen Trophäen. |
| 6 | Negativtest „vorher gelingt, nachher scheitert" | zusätzlich Tests, die **vorher und nachher gelingen müssen** (42, 43, 44, 48, 49, 61, 62, 63) | Ein Negativtest allein beweist nur, dass etwas zu ist, nicht dass die App noch läuft. Die Nichtbruch-Tests sind hier die riskanteren. |
| 7 | Prüfen, was in `lib/` bricht | zusätzlich gemeldet, dass das Suchmuster `.rpc(` aus Abschnitt 10 den einzigen RPC-Aufruf dieses Repositories nicht findet | `_client.rpc<Object?>(`, `supabase_auth_remote_data_source.dart:295`. Das Ergebnis von Abschnitt 10 bleibt richtig, die Methode nicht. |
| 8 | E-58 auslassen | ausgelassen, aber zweimal als Grund genannt (Abfrage O, 11.10) | Ohne Protokoll ist nach einem Missbrauch von E-53 nicht feststellbar, wer freigegeben hat. Das ist keine Behandlung von E-58, sondern die Wirkung seines Fehlens auf E-53. |

---

## 14. Nachtrag 02.09.2026: E-16 ist entschieden, und daraus wird Migration 7

Abschnitt 12 ordnet E-16 als Produktfrage ein und schreibt bewusst keine
Migration. Die Frage ist am 02.09.2026 beantwortet, `REBUILD_STATUS.md`,
Abschnitt „Janeks Antworten auf den dritten Block", Unterabschnitt J-B:

> ohne Anmeldung **nichts**. Mit Anmeldung **Rang, Punktestand und Anzahl der
> Städte**, keine Städtenamen. Und es gibt **nur einen Username**, keinen echten
> Namen.

Damit steht die Aussage, die in Abschnitt 12 gefehlt hat. Was jetzt folgt, ist
die Umsetzung. Format und Bedingungen wie in Abschnitt 11: die Buchstaben der
Diagnoseabfragen laufen hinter T weiter, die Negativtests hinter 63, und
**nichts davon wurde gegen eine Datenbank laufen gelassen**, auch nicht lesend.

### 14.0 Die Messung vor dem SQL, vier Fragen

Der Befund E-16 lautet: `user_city_scores` und `user_trophies` haben
`USING (true)` beim SELECT, und `get_leaderboard` gibt Nutzerkennungen ohne
Konto heraus. Beides ist bestätigt. Der Zuschnitt der Migration hängt aber an
Fragen, die der Befund nicht beantwortet.

#### Frage 1: Was gibt `get_leaderboard` heute tatsächlich zurück?

`03_Backend/supabase-schema.sql:365-441`. Vier Spalten, in dieser Reihenfolge
(`:369-374`):

| # | Spalte | Typ | Inhalt |
|---|---|---|---|
| 1 | `rank` | `bigint` | `row_number()` über der Sortierung, 1 bis 10 |
| 2 | `user_id` | `uuid` | `p.id`, die **Kontokennung**, in allen vier Zweigen (`:381`, `:394`, `:419`, `:430`) |
| 3 | `display_name` | `text` | `case when p.show_real_name then p.name else coalesce(p.username, 'Entdecker') end`, in allen vier Zweigen (`:382`, `:395`, `:420`, `:431`) |
| 4 | `score` | `bigint` | Wochenzweig `count(*)` über `collected_facts`, Gesamtzweig `p.score_total` bzw. `ucs.score` (`:421`, `:432`) |

**Die Antwort ist damit: sie liefert mehr als Rang, Punktestand und eine
Kennung.** Sie liefert eine Kennung **und** einen Namen, und der Name ist bei
gesetztem `show_real_name` der **echte Name** aus `profiles.name`. Das ist genau
die Unterscheidung, die J-B abschafft.

**Und sie liefert keine Städtezahl.** Der Wert existiert im ganzen Backend an
keiner Stelle als Rückgabe. Er ist neu, dazu Frage 4.

Ausführrechte: im gesamten `03_Backend/` gibt es fünf `grant`/`revoke`-Zeilen,
alle in `2026-06-20_ai_proxy.sql:51-54,61`, keine davon betrifft
`get_leaderboard`. PostgreSQL vergibt `EXECUTE` bei einer neuen Funktion per
Standard an `PUBLIC`, und `PUBLIC` schließt `anon` ein. **Der Teil des Befundes
„ohne Konto" ist damit aus den Dateien belegt** und mit Abfrage V in einer
Sekunde zu bestätigen. Migration 4 hat `get_leaderboard` ausdrücklich
ausgelassen und auf E-16 verwiesen (11.2 und Block 4b, „ABSICHTLICH NICHT IN
DIESER MIGRATION").

#### Frage 2: Wer ruft sie, und mit welchen Spalten rechnet der Aufrufer?

Vollständige Erhebung über `get_leaderboard`, `get_my_rank`, `getLeaderboard`
und `getMyRank` in `02_Frontend/app/`, `02_Frontend/admin/`,
`02_Frontend/landing/`, `fact-website/`, `04_Datenpipeline/`,
`supabase/functions/`, `08_Flutter/lib/` und `lib/`.

| Wo | Zeile | Was |
|---|---|---|
| PWA `api.jsx` | 220-224 (`getLeaderboard`) | `rpc('get_leaderboard', { p_city, p_period })`, gibt die Zeilen unverändert weiter |
| PWA `screen-profil.jsx` | 20 | der **einzige** Aufrufer in der PWA, in `RnkLeaderboard`, gerendert in `:472` |
| PWA `api.jsx` | 226-231 (`getMyRank`) | `rpc('get_my_rank', { p_user_id, p_city, p_period })` |
| PWA `app.jsx` | 267 | `getMyRank(session.user.id, 'global', 'weekly')`, also **die eigene Kennung** |
| alter Port `08_Flutter/lib/services/supabase_service.dart` | 229-234 | Definition ohne Aufrufer, wie `addCoins` in Abschnitt 2 |
| dieses Repo `lib/` | keine | keine |

**Welche Spalten `screen-profil.jsx` liest, einzeln:**

| Spalte | Zeile | Wofür |
|---|---|---|
| `rank` | 87, 101 | Schlüssel des Listenelements und die Medaille für 1 bis 3 |
| `user_id` | 88, 117 | `isMe`: die eigene Zeile wird hervorgehoben (`:88`), und der eigene Rang wird unten angehängt, **wenn** er nicht in den Top 10 steht (`:117`) |
| `display_name` | 103 | die Beschriftung der Zeile, direkt gerendert |
| `score` | 106 | die Zahl rechts |

**Alle vier Spalten werden gelesen. Das ist die teure Antwort dieser Aufgabe.**
Wer `user_id` aus der Rückgabe nimmt, bricht `screen-profil.jsx:88` und `:117`,
und zwar **still**: `String(undefined) === String(userId)` ist `false`, also
verschwindet die Hervorhebung, und der eigene Rang wird zusätzlich unten
angehängt, obwohl er in den Top 10 steht. Keine Fehlermeldung, kein Absturz, nur
eine Liste, die falsch aussieht. Wer `display_name` verkleinert, bricht `:103`
genauso still, dort steht dann nichts.

**Deshalb ist der Zuschnitt zweigeteilt**, dieselbe Trennung wie bei Migration
3a gegen 3b: 14.2 fasst die Rückgabe nicht an und kann heute laufen, 14.3
verkleinert sie und wartet auf einen PWA-Release.

#### Frage 3: Liest irgendwer die beiden Tabellen direkt?

| Wo | Zeile | Tabelle | Wessen Zeilen |
|---|---|---|---|
| PWA `api.jsx` | 80, in `loadUserData` | `user_trophies` | `.eq('user_id', userId)`, und `userId` ist `session.user.id` (`app.jsx:235`) |
| PWA `api.jsx` | 234-240 (`getTrophies`) | `user_trophies` | `.eq('user_id', userId)`, Aufrufer `app.jsx:573` in `refreshDbTrophies`, `userId` aus der Sitzung |
| alter Port `supabase_service.dart` | 66, 236-243 | `user_trophies` | eigene Kennung, `getTrophies` ohne Aufrufer |
| dieses Repo `lib/` | keine | keine | keine |
| **irgendwo** | keine | `user_city_scores` | **kein Client liest die Tabelle direkt** |

**Ergebnis: kein Client liest fremde Zeilen aus einer der beiden Tabellen.**
Beide PWA-Lesestellen filtern auf die eigene Kennung, und `user_city_scores`
wird ausschließlich innerhalb von `get_leaderboard` (`:434`) und
`handle_fact_collected` (`:288`) gelesen. Das `USING (true)` ist damit ein Recht,
das kein Ablauf braucht: es fällt, ohne dass etwas ausfällt.

Der Weg vom Recht zum Schaden ist trotzdem kurz und steht in Abschnitt 12: aus
`get_leaderboard` fällt die Kennung, mit der Kennung liest man beide Tabellen
aus, und dann steht da, in welchen Städten diese Person unterwegs war und zu
welchen Tageszeiten. Der Ist-Zustand braucht dafür **kein Konto**.

**Nebenbefund, der die Kennung entzaubert.** Sie ist heute auch ohne Rangliste
zu bekommen: `read comments` ist `USING (true)`
(`supabase-schema.sql:159-160`), und `comments.user_id` ist eine
`uuid`-Referenz auf `profiles` (`:51-57`). Wer einen Kommentar liest, hat eine
Kontokennung. Was die Rangliste zusätzlich liefert, ist die **Auswahl**: sie
sagt, welche zehn Kennungen die interessanten sind, und nennt ihren Punktestand
dazu. Das ist der Grund, warum das Entfernen von `user_id` aus der Rückgabe
(14.3) Hygiene ist und **nicht** das Loch schließt. Geschlossen wird es dadurch,
dass eine Kennung nichts mehr aufschließt, und das ist 14.2.

#### Frage 4: Geht die Städtezahl ohne Leserechte auf fremde Zeilen?

**Ja, und nur so.** Eine Policy kann es nicht: sie entscheidet je Zeile sichtbar
oder nicht, sie kann nicht „du darfst zählen, aber nicht lesen" sagen. Eine
`SECURITY DEFINER`-Funktion kann es, weil sie mit den Rechten ihres Eigentümers
läuft und für den Tabelleneigentümer keine Policy greift, solange
`FORCE ROW LEVEL SECURITY` aus ist. Genau darauf beruhen `get_leaderboard` schon
heute und die Migrationen 3, 4 und 6; bestätigt wird die Voraussetzung mit
Abfrage N (11.7), nicht geglaubt.

Der Wert ist aus `user_city_scores` zählbar, und `handle_fact_collected:288`
rechnet ihn bereits, für die Trophäen `weltenbummler` und `grand_tour`:

```sql
select count(distinct city_key) into v_city_count
  from public.user_city_scores where user_id = new.user_id and score > 0;
```

**Diese Zählung ist falsch, und wer sie abschreibt, übernimmt den Fehler.**
`handle_fact_collected:241-252` bildet den Schlüssel als
`lower(coalesce(f.city, <Präfix-Fall>))`, und der `else`-Zweig des Präfix-Falls
ist der Text **`'unknown'`**. Ein Fakt ohne `city` und ohne bekanntes
`nr`-Präfix legt damit eine Zeile `user_city_scores(user, 'unknown', n)` an, und
`count(distinct city_key)` zählt sie als Stadt mit. Zwei Folgen:

- Die Trophäe `weltenbummler` ist heute mit **zwei** echten Städten plus einem
  unzuordenbaren Fakt erreichbar. Das ist ein Befund an der Quelle, nicht Teil
  von E-16, und es gehört zu E-56.
- Der Trophäenschlüssel `v_city_key || '_first'` (`:279`) heißt bei diesen
  Fakten `unknown_first`. `wallet-colors.jsx` kennt ihn nicht, also ist das eine
  Trophäe ohne Namen.

**Migration 7 schließt `'unknown'` aus.** Damit weicht die angezeigte
Städtezahl von der Trophäenschwelle ab, und die Abweichung liegt richtig herum:
die Anzeige stimmt, die Trophäe nicht. `handle_fact_collected` mitzuändern wäre
eine Änderung an einer **Spielregel** (wann fällt `weltenbummler`) und keine
Sicherheitsbehebung. Der Punkt steht in 14.7 als offen.

**Die zweite Ungenauigkeit ist E-56 und bleibt.** Solange `münchen`,
`muenchen`, `rom` und `Rome` als verschiedene `city_key` in derselben Tabelle
liegen können (Abschnitt 12, E-56), zählt `count(distinct city_key)` dieselbe
Stadt unter zwei Schlüsseln zweimal. Migration 7 rechnet auf dem Bestand, wie er
ist, und **normalisiert nichts**: eine vierte Normalisierung neben den drei
bestehenden wäre die falsche Antwort. Wie groß die Abweichung wirklich ist, sagt
Abfrage X, und die läuft vor der Migration.

#### Was aus der Entscheidung ausdrücklich **nicht** folgt

**Der Username bleibt sichtbar.** J-B sagt „nur Rang und Punktestand und Anzahl
an Städten" und nennt den Username in dieser Aufzählung nicht. Der Satz danach
löst es auf: „es gibt immer nur ein Username und sonst nichts. Keinen echten
namen." Eine Rangliste ohne jede Beschriftung wäre keine Rangliste, und dieses
Repository sagt es selbst: der Schlüssel `username.hint` lautet „Sichtbar in der
Rangliste, später änderbar"
(`lib/app/localization/generated/app_strings_de.g.dart:509`). Der Username
**ist** die in der Rangliste sichtbare Identität, und er ist ein Pseudonym.
`display_name` bleibt deshalb in der Rückgabe, gespeist ausschließlich aus
`profiles.username`.

Das ist eine Auslegung und keine wörtliche Umsetzung. Sie steht hier, damit sie
widersprechbar ist.

### 14.1 Der Zuschnitt, und warum er zweigeteilt ist

| Block | Was | Bricht die PWA? | Läuft |
|---|---|---|---|
| **7a** | die beiden `USING (true)`-Policies fallen; `get_leaderboard` verlangt eine Sitzung, gibt nur noch den Username aus und ist nur noch für `authenticated` ausführbar; `get_my_rank` ist an das eigene Konto gebunden | **nein**, Nachweis in 14.2 | **heute** |
| **7b** | die Rückgabe von `get_leaderboard` wird umgebaut: `user_id` raus, `is_me` rein, `city_count` dazu, `'Entdecker'` raus | **ja**, `screen-profil.jsx:88`, `:103`, `:117` | **nach einem PWA-Release** |

**Die Sicherheitswirkung steckt vollständig in 7a.** Nach 7a schließt eine
Kontokennung nichts mehr auf: die beiden Tabellen antworten nur noch auf die
eigene Zeile, `profiles` tut das seit Migration 1, und schreibend war der Weg
seit den Migrationen 1, 2a, 4a und 6 schon zu. 7b nimmt die Kennung zusätzlich
aus der Rückgabe, weil sie dort nichts zu suchen hat, aber es schließt keine
Lücke mehr, siehe den Nebenbefund zu Frage 3. **Wer 7b für dringend hält,
priorisiert falsch.**

**Warum die Städtezahl in 7b liegt und nicht in 7a.** Sie ist für die PWA
harmlos: eine zusätzliche Spalte kommt als zusätzlicher Schlüssel im JSON an und
wird von niemandem gelesen. Sie steht trotzdem in 7b, weil eine neue Spalte in
`returns table(...)` den **Rückgabetyp** ändert, und `create or replace
function` kann den Rückgabetyp nicht ändern (`42P13`, „cannot change return type
of existing function"). Es braucht ein `drop function` mit anschließendem
`create`, und dabei fallen alle Ausführrechte weg und werden neu vergeben. Diese
Form gehört in den Block, der ohnehin ein abgestimmtes Zeitfenster braucht, und
nicht in den, der heute läuft. 7a ist deshalb ein reines
`create or replace`.

**Wenn ein Client die Städtezahl vor dem PWA-Release braucht**, etwa weil dieses
Repository eine Rangliste baut, dann wird aus 7b eine rein additive Fassung: in
der `returns table`-Liste `user_id uuid` stehen lassen, `is_me` weglassen, bei
`display_name` das `coalesce(..., 'Entdecker')` behalten und nur `city_count`
ergänzen. Das bricht die PWA nicht und kann sofort laufen. Der Rest von 7b
bleibt dann liegen. Es ist ausdrücklich **keine** dritte Migration, sondern
derselbe Block mit zwei Zeilen weniger.

**Reihenfolge zu den sechs bestehenden Migrationen.**

- **Migration 6 gehört vor 7a**, aber 7a hängt nicht daran. 7a braucht auf
  beiden Tabellen eine Policy für den eigenen Zugriff, und die gibt es in beiden
  Zuständen: vor Migration 6 als `own city scores` und `own trophies`
  (`FOR ALL`, deckt `SELECT` mit ab, `supabase-schema.sql:214`, `:224`), nach
  Migration 6 als die beiden `... select`-Policies. Der Block prüft das selbst,
  siehe die Wächter-Anweisung unten. Läuft 7a ohne 6, ist die Leseseite dicht
  und die Schreibseite offen, also E-55 weiter unbehoben.
- **Migration 4 gehört nicht davor und nicht danach.** Block 4b hat
  `get_my_rank` das Ausführrecht für `anon` und `PUBLIC` entzogen (11.2), 7a
  bindet den **Rumpf** an `auth.uid()`. Zwei verschiedene Grenzen, unabhängig
  voneinander. 7a wiederholt die Rechte-Anweisung aus 4b **nicht**: dieselbe
  Anweisung an zwei Stellen macht den Zustand nicht sicherer, sondern beim
  Rückabwickeln zu einem Halbzustand, Begründung in 6.1.
- **Migration 3a ist gleichgültig.** 7a und 7b hängen nicht am PWA-Release, der
  3a blockiert, und umgekehrt.

### 14.2 Migration 7a: die Leseseite schließt (E-16)

Dateiname im Backend-Repo: `2026-09-02_e16_read_side.sql`

**Vorher laufen lassen und die Ausgabe sichern: Abfrage U, V, W und X** (14.4).
U ist die Voraussetzung und nicht die Nachkontrolle: sie sagt, ob es auf beiden
Tabellen eine Policy für den eigenen Zugriff gibt. W sagt, wie viele Konten
ihren angezeigten Namen ändern. N aus 11.7 gilt weiter.

```sql
-- ============================================================================
-- FACT — E-16: Rangliste und Trophäen sind für jeden lesbar
-- ----------------------------------------------------------------------------
-- Ist-Zustand: supabase-schema.sql:213 und :223 (USING (true) beim SELECT),
-- dazu get_leaderboard (:365-441) ohne Sitzungsprüfung und mit EXECUTE für
-- PUBLIC, weil im ganzen 03_Backend/ keine Rechtezeile für sie existiert.
--
-- Entscheidung vom 02.09.2026 (REBUILD_STATUS.md, J-B): ohne Anmeldung nichts.
-- Mit Anmeldung Rang, Punktestand und Anzahl der Städte, keine Städtenamen.
-- Es gibt nur einen Username, keinen echten Namen.
--
-- Bricht heute nichts. Erhebung in 14.0, Frage 2 und 3:
--   kein Client liest fremde Zeilen aus einer der beiden Tabellen;
--   api.jsx:80 und :234-240 filtern auf die eigene Kennung;
--   user_city_scores liest überhaupt kein Client direkt;
--   die Rückgabe von get_leaderboard behält alle vier Spalten.
--
-- SICHTBARE VERHALTENSÄNDERUNG, und sie ist die Entscheidung, kein Fehler:
--   Die PWA hat keine Anmeldeschranke. route === 'profil' wird ohne Sitzung
--   gerendert (app.jsx:1059), requireAuth (app.jsx:541) sichert nur
--   schreibende Aktionen. Ein Besucher ohne Konto sieht heute auf dem
--   Profilbildschirm die vollständige Rangliste; danach sieht er
--   t('ranking.noData'), weil screen-profil.jsx:22 den Fehler abfängt.
--   Das ist "ohne Anmeldung nichts" und wird als Fehler gemeldet werden, wenn
--   es niemand vorher sagt.
--
-- WAS DIESER BLOCK NICHT ANFASST:
--   die Rückgabespalten von get_leaderboard -> Block 7b, weil
--     screen-profil.jsx:88, :103 und :117 alle vier Spalten lesen;
--   die Städtezahl -> Block 7b, weil eine neue Spalte den Rückgabetyp ändert;
--   die drei Stadtschlüssel-Normalisierungen -> E-56, Abschnitt 12;
--   handle_fact_collected -> die dortige Zählung ist falsch (14.0, Frage 4),
--     aber sie entscheidet über eine Trophäe und damit über eine Spielregel;
--   das SELECT-Recht der Rolle anon auf den beiden Tabellen, Begründung unten.
-- ============================================================================

begin;

-- 0. Wächter. Ohne eine Policy für den eigenen Zugriff nimmt Schritt 1 jedem
--    Nutzer den Blick auf seine eigenen Trophäen, und die PWA zeigt danach eine
--    leere Trophäenreihe (api.jsx:80, :234-240). Der Wächter bricht die
--    Transaktion ab, statt das zu tun. Er akzeptiert beide Zustände: die
--    FOR-ALL-Policy aus supabase-schema.sql:214/:224 und die
--    SELECT-Policy aus Migration 6.
do $guard$
declare
  v_missing text;
begin
  select string_agg(t.tab, ', ')
    into v_missing
    from (values ('user_city_scores', 'public read city scores'),
                 ('user_trophies',    'public read trophies')) as t(tab, pub)
   where not exists (
     select 1
       from pg_policies pol
      where pol.schemaname = 'public'
        and pol.tablename  = t.tab
        and pol.policyname <> t.pub
        and pol.cmd in ('ALL', 'SELECT')
        and pol.qual like '%auth.uid()%');

  if v_missing is not null then
    raise exception
      'Migration 7a abgebrochen: auf % fehlt eine Policy für den eigenen Zugriff. Erst Migration 6 laufen lassen, dann Abfrage U prüfen.',
      v_missing
      using errcode = '42501';
  end if;
end
$guard$;

-- 1. Die beiden USING-(true)-Policies fallen. Das ist der Kern von E-16.
--    Danach greift nur noch die Policy für die eigene Zeile, und mehrere
--    Policies für dieselbe Operation werden mit ODER verknüpft: es bleibt genau
--    der eigene Zugriff übrig.
drop policy if exists "public read city scores" on public.user_city_scores;
drop policy if exists "public read trophies"    on public.user_trophies;

-- Kein "revoke select ... from anon" dazu, und das ist eine Entscheidung.
-- anon hält das SELECT-Recht auf der Tabelle weiter, bekommt aber keine Zeile,
-- weil auth.uid() null ist und damit jede Policy-Bedingung falsch. Ein Revoke
-- würde aus einem leeren Ergebnis einen Fehler machen, also eine andere
-- Fehlerklasse für einen Aufrufer, den dieses Dokument nicht kennt. Dieselbe
-- Begründung wie bei _is_group_member in 11.2.

-- 2. get_leaderboard: Sitzung verlangen, echten Namen entfernen, search_path
--    setzen. Reines create or replace, der Rückgabetyp bleibt Wort für Wort
--    gleich (rank, user_id, display_name, score). Die vier Zweige und die
--    Sortierung sind unverändert aus supabase-schema.sql:365-441 übernommen,
--    einschließlich der Stadt-Normalisierung: E-56 ist hier nicht Gegenstand.
create or replace function public.get_leaderboard(
  p_city   text default 'global',
  p_period text default 'weekly'
)
returns table(
  rank         bigint,
  user_id      uuid,
  display_name text,
  score        bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Ohne Konto nichts. Die äußere Grenze ist das entzogene Ausführrecht in
  -- Schritt 3; diese Prüfung liegt im Rumpf und fängt den Fall, dass eine
  -- Rolle mit EXECUTE ohne "sub"-Claim ankommt.
  if auth.uid() is null then
    raise exception 'get_leaderboard: not authenticated' using errcode = '42501';
  end if;

  if p_period = 'weekly' then
    if p_city = 'global' then
      return query
        select
          row_number() over (order by count(*) desc)::bigint,
          p.id,
          -- Nur der Username. p.name und p.show_real_name kommen nicht mehr
          -- vor: J-B, "es gibt immer nur ein Username".
          coalesce(p.username, 'Entdecker'),
          count(*)::bigint
        from public.profiles p
        join public.collected_facts cf on cf.user_id = p.id
        where cf.collected_at >= date_trunc('week', now())
        group by p.id, p.username
        order by 4 desc
        limit 10;
    else
      return query
        select
          row_number() over (order by count(*) desc)::bigint,
          p.id,
          coalesce(p.username, 'Entdecker'),
          count(*)::bigint
        from public.profiles p
        join public.collected_facts cf on cf.user_id = p.id
        join public.facts f on f.id = cf.fact_id
        where cf.collected_at >= date_trunc('week', now())
          and lower(coalesce(f.city,
            case
              when f.nr like 'MUC%' then 'München'
              when f.nr like 'REG%' then 'Regensburg'
              when f.nr like 'ROM%' then 'Rom'
              when f.nr like 'PAU%' then 'Passau'
              else 'unknown'
            end
          )) = p_city
        group by p.id, p.username
        order by 4 desc
        limit 10;
    end if;
  else
    if p_city = 'global' then
      return query
        select
          row_number() over (order by p.score_total desc)::bigint,
          p.id,
          coalesce(p.username, 'Entdecker'),
          p.score_total::bigint
        from public.profiles p
        where p.score_total > 0
        order by p.score_total desc
        limit 10;
    else
      return query
        select
          row_number() over (order by ucs.score desc)::bigint,
          p.id,
          coalesce(p.username, 'Entdecker'),
          ucs.score::bigint
        from public.profiles p
        join public.user_city_scores ucs on ucs.user_id = p.id
        where ucs.city_key = p_city and ucs.score > 0
        order by ucs.score desc
        limit 10;
    end if;
  end if;
end;
$$;

-- 3. Ausführrechte. EXECUTE steht bei einer Funktion per PostgreSQL-Standard
--    an PUBLIC, und PUBLIC schließt anon ein. Genau das ist der Teil "ohne
--    Konto" des Befundes. Ein create or replace ändert bestehende Rechte
--    nicht, diese zwei Zeilen sind also die eigentliche Änderung.
revoke all    on function public.get_leaderboard(text, text) from public, anon;
grant  execute on function public.get_leaderboard(text, text) to authenticated;

-- 4. get_my_rank an das eigene Konto binden. Die Funktion nimmt heute eine
--    fremde Kennung und liefert deren Rang (supabase-schema.sql:443-512); das
--    ist derselbe Defekt wie E-06 Punkt 2 und E-52. Block 4b hat ihr das
--    Ausführrecht für anon und PUBLIC entzogen, den Rumpf aber nicht angefasst.
--    Die Signatur bleibt, damit api.jsx:227 unverändert weiterläuft; der Wert
--    von p_user_id wird nicht mehr geglaubt. Gleiche Bauform wie Block 2a.
--    Rumpf sonst unverändert, nur qualifiziert und mit v_uid statt p_user_id.
create or replace function public.get_my_rank(
  p_user_id uuid,
  p_city    text default 'global',
  p_period  text default 'weekly'
)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_my_score bigint;
  v_rank     int;
  v_uid      uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'get_my_rank: not authenticated' using errcode = '42501';
  end if;
  -- null ist zulässig und heißt "ich selbst", wie in Block 4a. Eine fremde
  -- Kennung ist ein Fehler und keine stille Umleitung: wer sie schickt, soll
  -- es merken.
  if p_user_id is not null and p_user_id <> v_uid then
    raise exception 'get_my_rank: foreign account' using errcode = '42501';
  end if;

  if p_period = 'weekly' then
    if p_city = 'global' then
      select count(*) into v_my_score
        from public.collected_facts cf
       where cf.user_id = v_uid
         and cf.collected_at >= date_trunc('week', now());
    else
      select count(*) into v_my_score
        from public.collected_facts cf
        join public.facts f on f.id = cf.fact_id
       where cf.user_id = v_uid
         and cf.collected_at >= date_trunc('week', now())
         and lower(coalesce(f.city,
           case when f.nr like 'MUC%' then 'München'
                when f.nr like 'REG%' then 'Regensburg'
                when f.nr like 'ROM%' then 'Rom'
                when f.nr like 'PAU%' then 'Passau'
                else 'unknown' end)) = p_city;
    end if;
  else
    if p_city = 'global' then
      select p.score_total into v_my_score
        from public.profiles p where p.id = v_uid;
    else
      select coalesce(ucs.score, 0) into v_my_score
        from public.user_city_scores ucs
       where ucs.user_id = v_uid and ucs.city_key = p_city;
    end if;
  end if;

  v_my_score := coalesce(v_my_score, 0);

  if p_period = 'weekly' then
    if p_city = 'global' then
      select count(*) + 1 into v_rank from (
        select cf.user_id
          from public.collected_facts cf
         where cf.collected_at >= date_trunc('week', now())
         group by cf.user_id having count(*) > v_my_score
      ) sub;
    else
      select count(*) + 1 into v_rank from (
        select cf.user_id
          from public.collected_facts cf
          join public.facts f on f.id = cf.fact_id
         where cf.collected_at >= date_trunc('week', now())
           and lower(coalesce(f.city,
             case when f.nr like 'MUC%' then 'München'
                  when f.nr like 'REG%' then 'Regensburg'
                  when f.nr like 'ROM%' then 'Rom'
                  when f.nr like 'PAU%' then 'Passau'
                  else 'unknown' end)) = p_city
         group by cf.user_id having count(*) > v_my_score
      ) sub;
    end if;
  else
    if p_city = 'global' then
      select count(*) + 1 into v_rank
        from public.profiles p where p.score_total > v_my_score;
    else
      select count(*) + 1 into v_rank
        from public.user_city_scores ucs
       where ucs.city_key = p_city and ucs.score > v_my_score;
    end if;
  end if;

  return coalesce(v_rank, 1);
end;
$$;

commit;

-- 5. PostgREST-Schemacache erneuern. Ausführrechte und zwei Funktionsrümpfe
--    haben sich geändert. Kostet nichts, ist beliebig oft wiederholbar.
notify pgrst, 'reload schema';
```

#### Rückabwicklung 7a

Dateiname: `2026-09-02_e16_read_side_down.sql`

Sie stellt den offenen Zustand her, und zwar vollständig. **Vorher Abfrage U und
V laufen lassen und die Ausgabe sichern**, sonst ist nach dem Rückrollen nicht
mehr feststellbar, ob die Rechte danach so stehen wie vorher.

```sql
-- ACHTUNG: danach ist jede Trophäe und jeder Stadtpunktestand jedes Nutzers
-- wieder ohne Konto lesbar, zusammen mit den Kontokennungen der Top 10. Das
-- ist der Zustand, den Abschnitt 12 als "offen zugunsten der weitesten
-- Auslegung" beschreibt.
begin;

create policy "public read city scores" on public.user_city_scores
  for select using (true);
create policy "public read trophies" on public.user_trophies
  for select using (true);

grant execute on function public.get_leaderboard(text, text) to public, anon, authenticated;

commit;

notify pgrst, 'reload schema';
```

Die beiden Funktionsrümpfe stehen damit **nicht** wieder auf dem Stand von
`supabase-schema.sql`. Das ist Absicht: die Sitzungsprüfung in
`get_leaderboard` und die Kontobindung in `get_my_rank` sind kein Teil der
Produktentscheidung, sondern Behebungen derselben Klasse wie E-06 und E-52. Wer
sie wirklich zurückdrehen will, nimmt die Rümpfe aus
`supabase-schema.sql:365-441` und `:443-512` wörtlich. Ohne diesen Schritt ist
der Zustand nach dem Rückrollen sicherer als vorher, und das ist der richtige
Ausgang.

### 14.3 Migration 7b: die Rückgabe wird umgebaut. Läuft noch nicht

Dateiname: `2026-09-02_e16_leaderboard_shape.sql`

> **Nicht ausführen, solange die PWA `screen-profil.jsx` in der heutigen Fassung
> ausliefert.** Der Block ist fertig, damit er bereitliegt, nicht damit er heute
> läuft. Was in der PWA zu ändern ist, steht in 14.6.

Drei Änderungen an der Rückgabe, jede mit ihrem eigenen Grund:

1. **`user_id` fällt, `is_me boolean` kommt.** Die Kennung ist in der Rangliste
   kein Anzeigewert, sie war nur der Weg zu `isMe`. `is_me` liefert genau die
   Aussage, die der Client braucht, und nichts darüber hinaus.
2. **`city_count bigint` kommt.** Der dritte Wert aus J-B, ohne Städtenamen.
   `'unknown'` ist ausgeschlossen, Begründung in 14.0, Frage 4.
3. **`'Entdecker'` fällt weg, `display_name` wird `null`.** Ein deutscher
   Anzeigetext in einer Datenbankfunktion erreicht jeden englischsprachigen
   Nutzer als deutsches Wort; es gibt keinen i18n-Schlüssel dafür. Derselbe
   Fehler wie E-63 in `CLAUDE.md`. Der Server liefert die Tatsache „kein
   Username gesetzt" als `null`, der Client übersetzt sie. **Der Wortlaut des
   Ersatztexts ist eine Inhaltsfrage** und steht in 14.7.

```sql
-- ============================================================================
-- FACT — E-16, zweiter Teil: die Rückgabe von get_leaderboard
-- ----------------------------------------------------------------------------
-- BRECHENDE ÄNDERUNG für 02_Frontend/app/screen-profil.jsx:88, :103 und :117.
-- Erst nach dem PWA-Release ausführen, der dort auf is_me umstellt.
--
-- VORAUSSETZUNG: Block 7a ist gelaufen. Dieser Block wiederholt die
-- Sitzungsprüfung, weil er den Rumpf ohnehin neu schreibt, aber er ersetzt
-- Schritt 1 aus 7a nicht: die beiden Policies sind dort gefallen, nicht hier.
--
-- WARUM DROP UND NICHT CREATE OR REPLACE: eine neue Spalte in returns table
-- ändert den Rückgabetyp, und den kann create or replace nicht ändern (42P13).
-- Ein drop function nimmt alle Ausführrechte mit, und ein frisch angelegtes
-- Funktionsobjekt trägt wieder EXECUTE für PUBLIC. Schritt 3 unten ist deshalb
-- nicht Wiederholung, sondern Pflicht.
-- ============================================================================

begin;

-- 1. Die alte Signatur weg. Ohne cascade: sollte die Funktion in einer View
--    oder einer anderen Funktion stecken, die dieses Dokument nicht kennt,
--    bricht der Block ab statt die Abhängigkeit mitzunehmen. Das ist der
--    gewünschte Ausgang.
drop function if exists public.get_leaderboard(text, text);

-- 2. Neu anlegen. Fünf Spalten, und user_id ist keine davon.
create function public.get_leaderboard(
  p_city   text default 'global',
  p_period text default 'weekly'
)
returns table(
  rank         bigint,
  is_me        boolean,
  display_name text,
  score        bigint,
  city_count   bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'get_leaderboard: not authenticated' using errcode = '42501';
  end if;

  if p_period = 'weekly' then
    if p_city = 'global' then
      return query
        select
          row_number() over (order by count(*) desc)::bigint,
          (p.id = v_uid),
          p.username,
          count(*)::bigint,
          public._city_count(p.id)
        from public.profiles p
        join public.collected_facts cf on cf.user_id = p.id
        where cf.collected_at >= date_trunc('week', now())
        group by p.id, p.username
        order by 4 desc
        limit 10;
    else
      return query
        select
          row_number() over (order by count(*) desc)::bigint,
          (p.id = v_uid),
          p.username,
          count(*)::bigint,
          public._city_count(p.id)
        from public.profiles p
        join public.collected_facts cf on cf.user_id = p.id
        join public.facts f on f.id = cf.fact_id
        where cf.collected_at >= date_trunc('week', now())
          and lower(coalesce(f.city,
            case
              when f.nr like 'MUC%' then 'München'
              when f.nr like 'REG%' then 'Regensburg'
              when f.nr like 'ROM%' then 'Rom'
              when f.nr like 'PAU%' then 'Passau'
              else 'unknown'
            end
          )) = p_city
        group by p.id, p.username
        order by 4 desc
        limit 10;
    end if;
  else
    if p_city = 'global' then
      return query
        select
          row_number() over (order by p.score_total desc)::bigint,
          (p.id = v_uid),
          p.username,
          p.score_total::bigint,
          public._city_count(p.id)
        from public.profiles p
        where p.score_total > 0
        order by p.score_total desc
        limit 10;
    else
      return query
        select
          row_number() over (order by ucs.score desc)::bigint,
          (p.id = v_uid),
          p.username,
          ucs.score::bigint,
          public._city_count(p.id)
        from public.profiles p
        join public.user_city_scores ucs on ucs.user_id = p.id
        where ucs.city_key = p_city and ucs.score > 0
        order by ucs.score desc
        limit 10;
    end if;
  end if;
end;
$$;

-- 3. Ausführrechte neu setzen. Der drop hat sie mitgenommen, und das create
--    hat EXECUTE wieder an PUBLIC vergeben. Ohne diese zwei Zeilen ist der
--    Befund "ohne Konto" wieder offen, obwohl 7a ihn geschlossen hatte. Das
--    ist die gefährlichste Stelle dieses Blocks, weil sie nichts bricht,
--    wenn man sie vergisst.
revoke all    on function public.get_leaderboard(text, text) from public, anon;
grant  execute on function public.get_leaderboard(text, text) to authenticated;

commit;

notify pgrst, 'reload schema';
```

**Die Städtezahl steckt in einem Helfer, und zwar aus einem Grund.**
`_city_count` wird in allen vier Zweigen gebraucht. Vierfach kopiert wäre sie
vierfach zu ändern, sobald E-56 beantwortet ist, und genau solche Kopien sind
der Grund, warum es heute drei Normalisierungen gibt. Der Helfer gehört in
denselben Block, **vor** die Funktion:

```sql
-- Vor Schritt 1 einfügen. stable, weil das Ergebnis innerhalb einer Anweisung
-- gleich bleibt; das erlaubt dem Planer, den Aufruf je Zeile einmal zu machen.
-- security invoker (der Standard, hier ausdrücklich), weil der einzige
-- Aufrufer get_leaderboard ist und der schon als Definer läuft: der Helfer
-- braucht keine eigenen Rechte, er erbt die des Aufrufers.
create or replace function public._city_count(p_user_id uuid)
returns bigint
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select count(distinct ucs.city_key)::bigint
    from public.user_city_scores ucs
   where ucs.user_id = p_user_id
     and ucs.score > 0
     -- 'unknown' ist keine Stadt, sondern der else-Zweig der
     -- Präfix-Zuordnung in handle_fact_collected:246-250. Ein Fakt ohne city
     -- und ohne bekanntes nr-Präfix darf die Städtezahl nicht erhöhen.
     and ucs.city_key <> 'unknown';
$$;

-- Kein Client ruft den Helfer. Gleiche Behandlung wie _haversine_m und
-- _slugify in Block 4b.
revoke all on function public._city_count(uuid) from public, anon, authenticated;
```

**Warum `security invoker` und nicht `definer`.** Der Helfer liest
`user_city_scores`, und auf der Tabelle steht nach 7a nur noch die Policy für
die eigene Zeile. Aufgerufen wird er ausschließlich aus `get_leaderboard`, und
die läuft als Eigentümer, für den keine Policy greift; der Helfer erbt diesen
Kontext. Ein `security definer` am Helfer wäre eine zweite, selbständig
aufrufbare Umgehung der Policy, und die will man nicht anlegen, wenn man sie
nicht braucht. Das entzogene Ausführrecht ist die zweite Grenze darum. **Wenn
Abfrage Z zeigt, dass `city_count` immer `0` liefert, ist die Eigentümerannahme
aus Abfrage N falsch**, und dann ist nicht der Helfer das Problem, sondern
Migration 6 und 3 stehen auf derselben falschen Annahme.

#### Rückabwicklung 7b

Dateiname: `2026-09-02_e16_leaderboard_shape_down.sql`

```sql
-- Stellt die Rückgabe von Block 7a her, nicht die von supabase-schema.sql.
begin;

drop function if exists public.get_leaderboard(text, text);

-- Hier den vollständigen Funktionsrumpf aus Block 7a, Schritt 2, einsetzen.
-- Er ist absichtlich nicht ein zweites Mal abgedruckt: zwei Kopien desselben
-- Rumpfes in einem Dokument driften auseinander, und beim Rückabwickeln
-- entsteht genau daraus ein Halbzustand.

revoke all    on function public.get_leaderboard(text, text) from public, anon;
grant  execute on function public.get_leaderboard(text, text) to authenticated;

drop function if exists public._city_count(uuid);

commit;

notify pgrst, 'reload schema';
```

### 14.4 Diagnoseabfragen U bis Z

Alle rein lesend, alle unausgeführt. **U bis X vor Block 7a laufen lassen und
die Ausgabe sichern**, Y danach, Z nach 7b. Die Buchstaben laufen hinter 11.7
weiter, A bis J stehen in Abschnitt 7, K bis T in 11.7. Abfrage N aus 11.7 gilt
für diesen Nachtrag unverändert und ist die Voraussetzung, nicht die
Nachkontrolle.

```sql
-- U) Voraussetzung für Block 7a, dieselbe Frage, die der Wächter im Block
--    stellt, nur lesbar. Erwartet: je Tabelle zwei Zeilen, eine mit
--    USING (true) und eine mit auth.uid(). Fehlt die zweite, NICHT ausführen:
--    Schritt 1 würde jedem Nutzer den Blick auf die eigenen Trophäen nehmen.
select tablename,
       policyname,
       cmd,
       qual,
       (qual like '%auth.uid()%') as ist_eigener_zugriff
  from pg_policies
 where schemaname = 'public'
   and tablename in ('user_trophies', 'user_city_scores')
 order by tablename, policyname;

-- V) Wer darf die beiden Leserfunktionen heute rufen, und welche Fassung steht
--    in der Datenbank? pg_get_function_result ist der Punkt: daran ist
--    ablesbar, ob 7a oder 7b schon gelaufen ist, ohne dass man es glauben muss.
--    Erwartet vor 7a: anon_darf = true für get_leaderboard.
--    Erwartet vor 7a: anon_darf = false für get_my_rank, WENN Migration 4
--    gelaufen ist. Steht dort true, ist Block 4b nie gelaufen, und das ist ein
--    eigener Befund.
select p.oid::regprocedure                                     as funktion,
       has_function_privilege('anon',          p.oid, 'EXECUTE') as anon_darf,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_darf,
       pg_get_function_result(p.oid)                            as rueckgabe,
       p.prosecdef                                              as security_definer,
       pg_get_userbyid(p.proowner)                              as owner,
       p.proconfig                                              as settings
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('get_leaderboard', 'get_my_rank', '_city_count')
 order by 1;

-- W) Wie viele Konten ändern ihren angezeigten Namen? Das ist die einzige
--    Zahl in diesem Nachtrag, die einen Nutzer sichtbar betrifft, ohne dass er
--    etwas getan hat. Wer sie nicht kennt, kann die Support-Anfrage nicht
--    beantworten.
--      mit_echtem_namen: sieht ab 7a den Username statt seines Namens.
--      wird_zu_entdecker: hat KEINEN Username und war bisher mit Namen
--        sichtbar. Diese Konten heißen ab 7a "Entdecker" (und ab 7b null),
--        und das ist der unangenehme Fall: ein Name verschwindet und es
--        kommt kein Pseudonym nach, weil keins existiert.
select count(*) filter (where show_real_name)                              as mit_echtem_namen,
       count(*) filter (where show_real_name and username is null)         as wird_zu_entdecker,
       count(*) filter (where username is null and score_total > 0)        as ohne_username_aber_im_ranking,
       count(*)                                                            as konten_gesamt
  from public.profiles;

-- X) Die Städtezahl, bevor sie eine Spalte wird. Drei Fragen in einer Abfrage:
--    wie viele Zeilen tragen 'unknown' (also keinen zuordenbaren Fakt),
--    welche Schlüssel gibt es überhaupt, und wie stark schlägt E-56 zu.
--    Zwei Schlüssel, die offensichtlich dieselbe Stadt meinen (muenchen und
--    münchen, rom und rome), sind der Beleg für E-56 in den Daten und nicht
--    nur im Code.
select ucs.city_key,
       count(*)                       as zeilen,
       count(distinct ucs.user_id)    as nutzer,
       sum(ucs.score)                 as punkte_gesamt
  from public.user_city_scores ucs
 where ucs.score > 0
 group by ucs.city_key
 order by 2 desc;

--    Und die Auswirkung auf die neue Spalte, je Nutzer, für die zehn mit den
--    meisten Städten. mit_unknown ist der Wert, den
--    handle_fact_collected:288 heute für weltenbummler benutzt,
--    ohne_unknown der Wert, den _city_count aus Block 7b liefern wird.
select ucs.user_id,
       count(distinct ucs.city_key)                                        as mit_unknown,
       count(distinct ucs.city_key) filter (where ucs.city_key <> 'unknown') as ohne_unknown
  from public.user_city_scores ucs
 where ucs.score > 0
 group by ucs.user_id
 order by 2 desc
 limit 10;

-- Y) nach Block 7a.
--    Erwartet: keine Zeile mit ist_public = true, und anon_darf = false für
--    beide Funktionen. Das ist zugleich die Regressionsprobe: ein späteres,
--    gut gemeintes "create policy ... using (true)" oder ein
--    "grant execute on all functions in schema public to anon" macht in einer
--    Zeile alles wieder auf.
select tablename, policyname, cmd, (qual = 'true') as ist_public
  from pg_policies
 where schemaname = 'public'
   and tablename in ('user_trophies', 'user_city_scores')
 order by tablename, policyname;

select p.oid::regprocedure                                     as funktion,
       has_function_privilege('anon',          p.oid, 'EXECUTE') as anon_darf,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_darf
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('get_leaderboard', 'get_my_rank');

-- Z) nach Block 7b. Stimmt die Städtezahl, und läuft der Helfer überhaupt?
--    Im SQL-Editor läuft die Abfrage als Eigentümer, also ohne Policy-Grenze:
--    hier steht der wahre Wert. Liefert get_leaderboard dagegen überall 0,
--    dann greift für den Funktionseigentümer doch eine Policy, und dann ist
--    die Annahme aus Abfrage N falsch. In dem Fall stehen Migration 3 und 6
--    auf derselben falschen Annahme, und das ist der größere Befund.
select l.rank, l.display_name, l.score, l.city_count
  from public.get_leaderboard('global', 'all') l;

select ucs.user_id,
       count(distinct ucs.city_key) filter (where ucs.city_key <> 'unknown') as erwartet
  from public.user_city_scores ucs
 where ucs.score > 0
 group by ucs.user_id
 order by 2 desc
 limit 10;
```

### 14.5 Negativtests 64 bis 82

Gleiche Bedingungen wie Abschnitt 8 und 11.8: **formuliert, nicht ausgeführt**,
weil aus diesem Repository keine Verbindung zu einem Supabase-Projekt aufgebaut
wird. Sie gehören in eine Testdatenbank. Zwei Testkonten `A` und `B`, Aufrufe
mit deren Session-Token, `anon`-Fälle mit dem öffentlichen Schlüssel und ohne
Token. Die Nummerierung läuft hinter 11.8 weiter.

**Eine Warnung vorweg, sonst wird die halbe Liste falsch gelesen.** Ein
Zugriff, den eine **Policy** abweist, liefert **null Zeilen und keinen Fehler**.
Nur ein fehlendes **Recht** liefert `42501`. Die Tests 66, 68 und 70 sind
deshalb erfolgreich, wenn nichts kommt, und nicht, wenn etwas fehlschlägt. Wer
dort eine Fehlermeldung erwartet, hält eine bestandene Prüfung für einen
Fehlschlag.

Block 7a:

| # | Handlung | Vor der Migration | Danach erwartet | Prüft |
|---|---|---|---|---|
| 64 | `anon` ruft `get_leaderboard('global','weekly')` | **erlaubt, zehn Zeilen mit Kennung und Namen** | Fehler, kein `EXECUTE` (`42501`, über PostgREST je nach Fassung auch `PGRST202`) | Kernfall „ohne Anmeldung nichts". **Ersetzt Test 48** |
| 65 | `A` ruft `get_leaderboard('global','weekly')` | erlaubt | **erlaubt, vier Spalten wie bisher** | Nichtbruch, `screen-profil.jsx:20` |
| 66 | `A` liest `user_trophies` von `B` | **erlaubt, alle Zeilen** | **null Zeilen, kein Fehler** | Kernfall E-16. **Ersetzt Test 63** |
| 67 | `A` liest die eigenen `user_trophies` genau wie `api.jsx:80` | erlaubt | **erlaubt** | **der riskanteste Nichtbruch-Test** |
| 68 | `A` liest `user_city_scores` von `B` | **erlaubt** | **null Zeilen, kein Fehler** | Kernfall E-16, Aufenthaltsdaten |
| 69 | `A` liest die eigenen `user_city_scores` | erlaubt | **erlaubt** | Nichtbruch, und die Grundlage dafür, dass ein Client seine eigene Städtezahl selbst zählen kann |
| 70 | `anon` liest `user_trophies` ohne Filter | **erlaubt, die ganze Tabelle** | **null Zeilen, kein Fehler** | ohne Konto nichts, und die Begründung dafür, dass `SELECT` für `anon` nicht entzogen wird |
| 71 | `A` ruft `get_my_rank(B, 'global', 'weekly')` | **liefert den Rang von `B`** | Fehler `42501`, `foreign account` | fremder Rang, derselbe Defekt wie E-06 Punkt 2 |
| 72 | `A` ruft `get_my_rank(A, 'global', 'weekly')` | erlaubt | **erlaubt** | Nichtbruch, `app.jsx:267` |
| 73 | `A` ruft `get_my_rank(null, 'global', 'weekly')` | liefert einen Rang, gerechnet auf Punktestand 0 | **erlaubt, liefert den Rang von `A`** | Nullfall, wie Test 39 |
| 74 | `B` setzt `show_real_name = true`, dann ruft `A` `get_leaderboard` | `A` sieht den **echten Namen** von `B` | `A` sieht den Username von `B` | „nur ein Username, keinen echten Namen" |
| 75 | `B` hat `show_real_name = true` und **keinen** Username, `A` ruft `get_leaderboard` | `A` sieht den echten Namen von `B` | `A` sieht `Entdecker` | der unangenehme Fall aus Abfrage W |
| 76 | `A` sammelt einen Fakt und die Trophäen wachsen | ja | **ja** | der Trigger schreibt weiter; Policies begrenzen den Client, nicht den Eigentümer |

Block 7b:

| # | Handlung | Vor 7b | Danach erwartet | Prüft |
|---|---|---|---|---|
| 77 | `A` ruft `get_leaderboard('global','weekly')` und sieht sich in den Top 10 | `row.user_id` ist die eigene Kennung | `row.user_id` **fehlt**, `row.is_me` ist `true` | Kernfall 7b |
| 78 | `A` ruft `get_leaderboard` und `B` steht darin | `row.user_id` ist die Kennung von `B` | `row.is_me` ist `false`, keine Kennung | die Kennung ist aus der Rückgabe |
| 79 | `A` hat Fakten in München, Regensburg und einen ohne `city` | Städtezahl gibt es nicht | `city_count` ist **2**, nicht 3 | `'unknown'` ist keine Stadt |
| 80 | `B` hat keinen Username und steht in den Top 10 | `display_name` ist `Entdecker` | `display_name` ist `null` | der deutsche Text fällt aus der Datenbank |
| 81 | `anon` ruft `get_leaderboard` | Fehler, kein `EXECUTE` (Zustand nach 7a) | **weiterhin Fehler** | das `drop function` hat die Rechte mitgenommen, Schritt 3 hat sie wieder gesetzt |
| 82 | `A` ruft `_city_count(B)` direkt | die Funktion existiert nicht | Fehler, kein `EXECUTE` | der Helfer ist keine API |

**Die vier Tests, an denen es hängt.** Test 67, weil ein Fehlschlag bedeutet,
dass jeder Nutzer in der PWA eine leere Trophäenreihe sieht und die
Trophäen-Nachprüfung in `app.jsx:573` stumm nichts mehr findet. Test 76, weil
ein Fehlschlag bedeutet, dass die Eigentümerannahme aus Abfrage N falsch ist und
dann auch Migration 3 und 6 zurückzurollen sind. Test 65, weil er die eine
Zusicherung von 7a prüft, nämlich dass die Rückgabe unangetastet bleibt. Test
81, weil das vergessene Schritt 3 in 7b nichts bricht und deshalb nicht
auffällt: der Befund wäre wieder offen, und alles würde weiter funktionieren.
Die eigentlichen Sicherheitstests 64, 66, 68 und 71 sind die einfachen.

### 14.6 Auswirkung auf diese App und auf die PWA

#### Auf `lib/`: keine, und das ist nachgesehen

Vollständige Liste der Supabase-Berührungen dieses Repositories, ermittelt über
das Muster aus 11.9, weil das naheliegende `\.rpc\(` den einzigen RPC-Aufruf
dieses Repositories nicht findet:

```
grep -rnE "\.(from|rpc)\s*(<[^>]*>)?\s*\(" lib/
```

| Stelle | Was | Von Migration 7 betroffen |
|---|---|---|
| `lib/features/facts/data/datasources/remote/supabase_fact_remote_data_source.dart:46` | `from('facts').select()` | nein |
| `.../supabase_fact_remote_data_source.dart:57` | `from('facts').select().eq('id', id)` | nein |
| `lib/features/identity/data/datasources/remote/supabase_auth_remote_data_source.dart:295` | `rpc<Object?>('check_username')` | nein, Migration 4 gibt sie ausdrücklich an `anon` |
| `.../supabase_auth_remote_data_source.dart:330` | `from('profiles').update({username})` | nein |

**Es gibt in `lib/` keinen Leseweg auf `user_trophies`, `user_city_scores`,
`get_leaderboard` oder `get_my_rank`.** Die Treffer auf „Trophäe", „Rangliste"
und „leaderboard" in `lib/` liegen ausschließlich in den generierten
i18n-Dateien und in `lib/features/progression/`, und dieser Block hat
ausdrücklich keine Datenschicht (11.9). Der Text
`lib/app/localization/generated/app_strings_de.g.dart:619` („Trophäen, Reise-Karte
und Ranking schaltest du mit einem kostenlosen Konto frei") sagt schon heute das,
was Migration 7a im Backend erzwingt.

**Was künftige Schritte beachten müssen:**

- **Eine Rangliste in diesem Repository liest `get_leaderboard` und rechnet
  nichts nach.** Nach 7b sind die Spalten `rank`, `is_me`, `display_name`,
  `score`, `city_count`. `display_name` ist `nullable`, und der Rückfalltext
  gehört in die i18n-Ergänzung, nicht in ein `?? 'Entdecker'` im Dart-Code. Wer
  dort ein deutsches Wort hinschreibt, wiederholt E-63.
- **Läuft nur 7a, heißt die Kennungsspalte weiter `user_id` und `city_count`
  fehlt.** Ein Datenmodell, das gegen 7b gebaut ist, bricht dann still: der
  fehlende Schlüssel kommt als `null` an. Die Datenschicht muss den Fall zu
  einem Fehlschlag machen und nicht zu einem `0`, gleiche Begründung wie beim
  Username-Check in `supabase_auth_remote_data_source.dart:288-291`.
- **Die eigene Städtezahl braucht keine RPC.** `user_city_scores` ist nach 7a
  für die eigene Zeile lesbar (Test 69). Wer nur den eigenen Wert zeigen will,
  zählt ihn selbst und muss `'unknown'` dabei ausschließen.
- **Fremde Trophäen sind nicht mehr lesbar.** Ein Profil eines anderen Nutzers
  kann seine Trophäen nicht anzeigen. Das ist die Entscheidung und keine Lücke
  im Backend, die man umgehen darf.

#### Auf die PWA: 7a nein, 7b ja

**7a bricht nichts**, aber es ändert für Besucher ohne Konto sichtbar das
Verhalten, siehe den Kommentarblock in 14.2. Dazu zwei Punkte, die in ein
PWA-Auftragspaket gehören und **nicht** in diese Migration:

1. **Der Schalter „Echten Namen zeigen" wird zu einer Lüge.**
   `screen-profil.jsx:693` schreibt weiter `show_real_name`, und die Spalte ist
   in Migration 1 ausdrücklich freigegeben. Nach 7a liest sie niemand mehr. Der
   Schalter speichert also einen Wert, der nichts bewirkt, und behauptet dem
   Nutzer gegenüber das Gegenteil. Das ist schlimmer als ein fehlender Schalter.
   **Er gehört aus der Oberfläche entfernt**, im PWA-Repository.
2. **Die Spalte `profiles.show_real_name` selbst bleibt stehen.** Sie zu
   löschen wäre eine Schemaänderung mit Datenverlust und laut Auftrag zu melden.
   Sie steht in 14.7.

**7b bricht `screen-profil.jsx` an drei Stellen**, und alle drei still:

| Zeile | Heute | Nach 7b | Änderung |
|---|---|---|---|
| 88 | `const isMe = String(row.user_id) === String(userId)` | immer `false`, keine Hervorhebung | `const isMe = row.is_me === true` |
| 117 | `!rows.some(r => String(r.user_id) === String(userId))` | immer `true`, der eigene Rang wird unten angehängt, obwohl er in der Liste steht | `!rows.some(r => r.is_me)` |
| 103 | `{row.display_name}` | leer bei Konten ohne Username | `{row.display_name || t('ranking.anonymous', lang)}`, und der Schlüssel muss erst existieren |

Die dritte Zeile ist der Grund, warum 7b nicht nur ein Suchen und Ersetzen ist:
`t()` gibt in der PWA bei fehlendem Schlüssel den Schlüssel selbst zurück, ein
`||`-Rückfall dahinter kann also nie feuern. Genau dieser Fehler ist in
`CLAUDE.md` als E-63 vermerkt. Der Schlüssel muss vor dem Release in beiden
Sprachen existieren, und **der Wortlaut ist eine Inhaltsfrage**, siehe 14.7.

`08_Flutter/lib/services/supabase_service.dart:229-234` ruft `get_leaderboard`
in einer Methode ohne Aufrufer. Der eingefrorene Port bricht durch 7b nicht,
weil er die Rückgabe nirgends auswertet. Gleiches Ergebnis wie bei `addCoins` in
Abschnitt 2.

### 14.7 Was nach Migration 7 offen bleibt

- **Die Städte-Ranglisten verraten Städtenamen, und zwar zwangsläufig.** Das ist
  der Punkt, an dem die Entscheidung nicht ganz durchträgt.
  `get_leaderboard('münchen', 'all')` liefert die Top 10 dieser Stadt. Wer in
  dieser Liste steht, war messbar in München, und der Aufrufer weiß es. Die
  Stadtfilter sind ein bestehendes Produktmerkmal
  (`screen-profil.jsx:9`, fünf Pillen), also ist „keine Städtenamen" für die
  Top 10 je Stadt nicht einhaltbar, solange es Stadt-Ranglisten gibt. Der
  Unterschied zum Ist-Zustand ist erheblich: heute geht es für **jeden** Nutzer
  und **ohne Konto**, danach für zehn je Stadt und nur mit Konto. **Das ist eine
  Produktfrage und bleibt offen:** entweder die Stadt-Ranglisten fallen, oder
  die Aussage lautet „keine Städtenamen, außer man steht in den besten zehn
  einer Stadt". Beides ist vertretbar, das eine ist nicht das andere. Nicht
  entschieden, nicht gebaut.
- **Der Wortlaut für ein Konto ohne Username.** Nach 7b liefert der Server
  `null`, und der Client braucht einen Text. Inhaltsfrage. Bis sie beantwortet
  ist, läuft 7b nicht, weil sonst eine leere Zeile in der Rangliste steht.
- **`profiles.show_real_name` und `profiles.name` sind nach der Entscheidung
  ohne Zweck.** `show_real_name` liest nach 7a niemand mehr, und `name` trägt im
  Neubau bereits den Username (`signup_notifier.dart:174`). Beide Spalten zu
  entfernen ist eine Schemaänderung mit Datenverlust und ein Bruch für
  `api.jsx:105` und `loadUserData`. **Melden, nicht bauen.** Der harmlose
  Zwischenschritt wäre, `show_real_name` das Schreibrecht zu nehmen, also die
  Spalte aus der `grant update`-Liste von Migration 1 zu streichen. Das ist eine
  Änderung an Migration 1 und deshalb nicht Teil dieses Nachtrags.
- **Die Trophäe `weltenbummler` zählt `'unknown'` als Stadt.**
  `handle_fact_collected:288`. Die Behebung ist eine Zeile, aber sie ändert,
  wann eine Trophäe fällt, also eine Spielregel. Dazu kommt: bereits vergebene
  Trophäen bleiben vergeben, ein Rückrechnen wäre ein eigener Auftrag mit
  Datenmigration. Gehört zu E-56 und zu Janek.
- **`unknown_first` ist eine Trophäe ohne Namen.** `handle_fact_collected:279`
  baut den Schlüssel als `v_city_key || '_first'`. `wallet-colors.jsx:103` kennt
  ihn nicht. Derselbe Befund wie `unknown` oben, nur an anderer Stelle sichtbar.
- **`_city_count` ist ein neues Funktionsobjekt.** Kein neue Tabelle, aber ein
  Objekt, das es vorher nicht gab. Wer das nicht will, setzt den
  `count(distinct ...)` als korrelierte Unterabfrage viermal in die vier Zweige
  von 7b ein; das Ergebnis ist identisch, und die vier Kopien sind dann bei der
  Beantwortung von E-56 viermal zu ändern. Der Helfer ist die Empfehlung, nicht
  die Vorgabe.
- **Der Client bestimmt weiter, welche Trophäe er bekommt.** `unlock_trophy` ist
  seit Migration 4 kontogebunden und nimmt jeden Schlüssel. E-16 ändert daran
  nichts: fremde Trophäen sind nicht mehr lesbar, die eigenen sind weiter
  erfindbar. Das ist E-49.
- **Alles hier steht unter dem Vorbehalt aus `backend-inventory.md`,
  Abschnitt 2.** Ohne Schema-Dump der laufenden Datenbank ist nicht bekannt, was
  von den Migrationen tatsächlich gelaufen ist. Die Abfragen U bis Z sind die
  kleine Fassung dieses Dumps für den Ausschnitt, den dieser Nachtrag anfasst.

### 14.8 Wo dieser Nachtrag von seinem Auftrag abweicht

Vollständig, weil eine stillschweigende Abweichung schlimmer ist als eine
gemeldete.

| # | Auftrag | Was daraus geworden ist | Warum |
|---|---|---|---|
| 1 | „Mit Anmeldung: Rang, Punktestand und die Anzahl der Städte" | `display_name` bleibt in der Rückgabe, gespeist aus `profiles.username` | Eine Rangliste ohne Beschriftung ist keine Rangliste, und J-B nennt den Username im Satz danach als **die** Identität. `app_strings_de.g.dart:509` sagt es aus diesem Repository heraus: „Sichtbar in der Rangliste". Auslegung, deshalb ausdrücklich in 14.0 als solche markiert |
| 2 | „Wenn sie mehr liefert, schreib zwei Blöcke" | zwei Blöcke, aber die Städtezahl liegt im **zweiten** | Eine neue Spalte in `returns table` ändert den Rückgabetyp, und `create or replace` kann das nicht (`42P13`). Das nötige `drop function` nimmt alle Ausführrechte mit; diese Form gehört in den Block mit Zeitfenster. Der Auftrag hätte sie in 7a erwartet. Wie 7b rein additiv wird, steht in 14.1 |
| 3 | Policies verschärfen | zusätzlich `get_my_rank` an das Konto gebunden | Die Funktion nimmt eine fremde Kennung und liefert deren Rang (`:443`). Nach dem Policy-Drop wäre sie der letzte Weg, der über eine fremde Kennung eine Auskunft gibt. Nicht Teil von E-16, aber dieselbe Klasse wie E-06 Punkt 2 und im selben Block kostenlos |
| 4 | „Prüfe, ob sich die Städtezahl aus `user_city_scores` zählen lässt" | ja, aber **nicht** so wie `handle_fact_collected:288` es tut | `'unknown'` ist ein `city_key` wie jeder andere. Der bestehende Zähler ist falsch, und die naheliegende Umsetzung hätte den Fehler übernommen. Ergebnis: die Anzeige weicht bewusst von der Trophäenschwelle ab |
| 5 | „Ein Direktzugriff auf fremde Zeilen fällt weg, sobald die Policy fällt" | er fällt weg, aber es gab **keinen** | Kein Client liest fremde Zeilen aus einer der beiden Tabellen (14.0, Frage 3). Das `USING (true)` war ein Recht ohne Aufrufer. Die Migration bricht deshalb weniger, als der Befund vermuten lässt |
| 6 | die Kennung aus der Rangliste nehmen schließt das Loch | es schließt es **nicht** | `read comments` ist `USING (true)` und `comments.user_id` verweist auf `profiles` (`:51-57`, `:159-160`). Kontokennungen sind ohne Rangliste zu bekommen. Was E-16 schließt, ist, dass eine Kennung etwas aufschließt, und das leistet 7a. 7b ist Hygiene, und in 14.1 steht ausdrücklich, dass wer sie für dringend hält, falsch priorisiert |
| 7 | Negativtest „vorher gelingt, nachher scheitert" | zusätzlich der Hinweis, dass eine Policy **null Zeilen** liefert und keinen Fehler | Ohne diesen Absatz werden die Tests 66, 68 und 70 als Fehlschlag gelesen, obwohl sie bestanden sind. Dazu Nichtbruch-Tests (65, 67, 69, 72, 73, 76, 81), und die sind hier wieder die riskanteren |
| 8 | „Keine neue Tabelle" | keine Tabelle, aber ein neues **Funktionsobjekt** `_city_count` in 7b | Es ist keine Tabelle und kein Datenvertrag nach außen, sondern ein interner Helfer ohne Ausführrecht für jeden Client, wie `_haversine_m` in Block 4b. Die Alternative ohne neues Objekt steht in 14.7, damit die Wahl beim Eigentümer liegt |
| 9 | E-16 ist eine Policy-Frage | die Stadt-Ranglisten verraten Städtenamen und können es nicht nicht tun | „Keine Städtenamen" und „es gibt Stadt-Ranglisten" sind nicht beide vollständig erfüllbar. Das ist eine offene Produktfrage und steht in 14.7, statt in der Migration entschieden zu werden |
| 10 | nur Migration schreiben | zusätzlich zwei PWA-Aufträge benannt (Schalter entfernen, i18n-Schlüssel anlegen) | Der Schalter „Echten Namen zeigen" speichert nach 7a einen Wert, den niemand liest. Ein Schalter, der lügt, ist schlechter als keiner, und die Migration allein erzeugt genau diesen Zustand |
