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
**Migration 1 schließt das als Nebenwirkung mit**.

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
| PWA `screen-challenge.jsx` | 4364 | `Math.floor(score / 8)`, nach oben nicht belegt |
| PWA `puzzle-sheet.jsx` | 585 | `netCoins`, Rätselgrundwert minus Hinweiskosten |
| alter Port `08_Flutter/lib/services/supabase_service.dart` | 155-156 | Durchreichung |
| dieses Repo `lib/` | keine | keine |

**Das ist der harte Teil des Befundes.** Die Coin-Ökonomie der PWA wird
vollständig im Client gerechnet, die Beträge sind nicht konstant, und **negative
Beträge sind ein regulärer Anwendungsfall** (`screen-map.jsx:3542`, Hinweis
kaufen). Eine Server-Prüfung der Form „Betrag muss positiv und klein sein"
bricht das Kaufen von Hinweisen. Eine Whitelist erlaubter Beträge ist nicht
aufstellbar, weil zwei der Beträge gerechnet und nach oben nicht belegt sind.

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
| 2. E-06, `increment_coins` | Fremdkonten-Manipulation ist dicht, Coins gedeckelt | **nein**, mit einer Einschränkung | nein, `lib/` ruft die RPC nicht |
| 3. E-23, `collected_facts` | Rangliste und Trophäen sind serverbestimmt | **ja, vollständig** | nein, `lib/` schreibt dort nicht |

**Zwischen Schritt 1 und 2 entsteht kein kaputter Zustand.** Nach Schritt 1 ist
`coins` per `UPDATE` gesperrt, `increment_coins` läuft als Definer weiter und
ist von Spaltenrechten nicht betroffen. Die PWA schreibt Coins ohnehin nur über
die RPC.

**Schritt 2 hat eine Einschränkung, die eine Entscheidung braucht.** Die
Betragsdeckelung ist die einzige Stelle, an der eine Zahl gewählt werden muss,
die nicht aus dem Code ableitbar ist, weil zwei Beträge gerechnet werden
(Abschnitt 2). Ein zu enger Deckel lässt einen Quiz-Abschluss oder einen
Rätselgewinn ins Leere laufen. Der Vorschlag in Migration 2 ist `1000`, also das
Zwanzigfache des größten konstanten Betrags (`50`). Wer die Deckelung nicht
verantworten will, lässt Block 2b weg: Block 2a allein (Konto-Bindung plus
Ausführrechte) ist rein additiv und bricht garantiert nichts.

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
-- Behebt nebenbei 2026-06-20_ai_proxy.sql:61: das dortige
-- "revoke update (ai_used, ai_limit)" ist wirkungslos, solange das
-- tabellenweite UPDATE-Recht steht (Rechte in PostgreSQL sind additiv).
--
-- Bricht heute nichts: die einzigen Client-Schreibzugriffe sind
--   02_Frontend/app/api.jsx:255           -> username, username_changed_at
--   02_Frontend/app/screen-profil.jsx:693 -> show_real_name
--   flutter-fact .../supabase_auth_remote_data_source.dart:331 -> username
-- ============================================================================

begin;

-- 1. Tabellenweite Schreibrechte entziehen. Erst danach greifen Spaltenrechte.
revoke insert, update, delete on public.profiles from authenticated, anon;

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

-- Der ursprüngliche, wirkungslose Versuch aus dem AI-Proxy, der
-- Vollständigkeit halber. Ohne diese Zeile ist der Zustand danach sicherer
-- als vorher.
revoke update (ai_used, ai_limit) on public.profiles from authenticated, anon;

commit;
```

---

### Migration 2: `increment_coins` (E-06)

Dateiname: `2026-08-28_e06_increment_coins.sql`

Zwei Blöcke, getrennt ausführbar. **2a bricht garantiert nichts. 2b enthält die
eine Zahl, die eine Entscheidung braucht.**

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
-- BLOCK 2b: Betragsdeckel. BRAUCHT EINE ENTSCHEIDUNG, siehe Abschnitt 4.
--
-- Warum kein enger Deckel: die PWA rechnet die Beträge im Client. Belegt sind
--   +50  app.jsx:714          (Sammeln)
--   +12 / +17  app.jsx:753    (eigener Fakt, mit/ohne Quelle)
--   +2   screen-fact.jsx:214  (Kommentar)
--   -10 / -20  screen-map.jsx:3542  (Hinweis kaufen — NEGATIV ist regulär)
--   Math.floor(score / 8)  screen-challenge.jsx:4364  (nach oben nicht belegt)
--   netCoins               puzzle-sheet.jsx:585       (nach oben nicht belegt)
-- Ein Deckel ist deshalb eine Wette. 1000 ist das Zwanzigfache des größten
-- konstanten Betrags. Wer die Wette nicht eingehen will, führt diesen Block
-- nicht aus; Block 2a allein ist bereits ein echter Gewinn.
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
  c_max constant integer := 1000;   -- <<< die Zahl, die freizugeben ist
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
  if abs(amount) > c_max then
    raise exception 'increment_coins: amount % out of range', amount
      using errcode = '22003';
  end if;

  update public.profiles
     set coins = greatest(coins + amount, 0)
   where id = v_uid;
end;
$$;

commit;
```

**Zur Klammer `greatest(..., 0)` in Block 2b:** sie verhindert einen negativen
Kontostand. Das ist eine **Verhaltensänderung**, keine reine Absicherung. Heute
prüft die PWA die Deckung eines Hinweiskaufs im Client
(`puzzle-sheet.jsx:573` rechnet netto, `screen-map.jsx:3542` prüft nicht) und
könnte den Saldo theoretisch unter Null drücken. Nach der Änderung wird das
still auf 0 gekappt statt zu scheitern. Wer das nicht will, lässt `greatest` weg
und schreibt `set coins = coins + amount`.

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

---

### Migration 3: `collected_facts` (E-23)

Dateiname: `2026-08-28_e23_collected_facts.sql`

> **Nicht ausführen, solange die PWA `api.jsx:145` benutzt.** Siehe Abschnitt 4.
> Dieser Block ist fertig, damit er bereitliegt, nicht damit er heute läuft.

```sql
-- ============================================================================
-- FACT — E-23: der Client fuegt direkt in collected_facts ein
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
sichern**, sie ist die Grundlage jeder Rückabwicklung. F bis H danach zur
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
select table_name, grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema = 'public'
   and table_name in ('profiles', 'collected_facts')
   and grantee in ('anon', 'authenticated')
 order by table_name, grantee, privilege_type;

-- C) Spaltenrechte
select grantee, column_name, privilege_type
  from information_schema.column_privileges
 where table_schema = 'public' and table_name = 'profiles'
   and grantee in ('anon', 'authenticated')
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
| 5 | `A` setzt `ai_used = 0` im eigenen Profil | **vermutlich erlaubt** (Befund 4) | Fehler `42501` |
| 6 | `A` setzt `username` bei `B` | abgelehnt | abgelehnt |
| 7 | Registrierung: neues Konto, dann `username` setzen | erlaubt | erlaubt |
| 8 | `A` ruft `increment_coins(A, 50)` | erlaubt | erlaubt |
| 9 | `A` ruft `increment_coins(A, -10)` | erlaubt | erlaubt |
| 10 | `A` ruft `increment_coins(B, 5000)` | **erlaubt** | Fehler `foreign account` |
| 11 | `A` ruft `increment_coins(A, 10000000)` | **erlaubt** | Fehler `22003`, nur mit Block 2b |
| 12 | Nicht angemeldet, `increment_coins` | erlaubt, wirkungslos | Fehler, kein `EXECUTE` |
| 13 | `A` fügt `collected_facts(A, 1)` ein | **erlaubt** | Fehler `42501`, Migration 3 |
| 14 | `A` ruft `collect_fact_validated` in Reichweite | erlaubt, Trigger feuert | unverändert, Trigger feuert |
| 15 | Zu 14: `score_total`, `user_city_scores`, `user_trophies` gewachsen | ja | **ja** |
| 16 | `A` liest die eigenen `collected_facts` | erlaubt | erlaubt |

Test 15 ist der wichtige: er belegt Abschnitt 5 empirisch. Läuft er rot, ist die
Eigentümer-Annahme falsch und Migration 3 muss zurückgerollt werden.

---

## 9. Was danach immer noch offen ist

Damit niemand die drei Migrationen für eine abgeschlossene Absicherung hält:

- **E-07 bleibt offen.** `collect_fact_validated` prüft die 150 Meter gegen eine
  Position, die der Client schickt. Ein gefälschtes GPS reicht weiter aus.
  Gleiches gilt für `collect_group_fact` und `collect_team_fact`.
- **Die Coin-Ökonomie bleibt clientbestimmt.** Nach Migration 2 kann ein Nutzer
  nur noch für das eigene Konto und nur noch bis zum Deckel buchen. Er bestimmt
  die Höhe innerhalb dieses Rahmens weiterhin selbst, weil die PWA sie im Client
  rechnet. Eine echte Behebung heißt: Server berechnet den Betrag, Client meldet
  nur das Ereignis. Das ist ein Umbau der PWA und der Rätsel- und Quiz-Logik,
  keine Migration.
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
