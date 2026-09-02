---
id: OPS-BACKEND-INVENTORY
status: proposed
owner: operations
scope:
  - backend
load_when:
  - backend_scope
  - migration
  - architecture_proposal
---

# Aufnahme des Backends: was liegt drin, und was davon weiß man wirklich

**Zweck.** Am 31.08.2026 ist der Auftrag erweitert worden: das Backend des
Monorepos gehört perspektivisch mit zum Neubau. Vorher stand die Frage im Raum,
was überhaupt dazugehört, denn eine Aufnahme existierte nicht. Dies ist sie.

**Wie gelesen wurde.** Rein lesend, aus dem Referenz-Repository, ohne eine
einzige Abfrage gegen die laufende Datenbank. Jede Aussage unten ist entweder
aus den Dateien belegt oder ausdrücklich als unbestätigte Vermutung markiert.
Die Trennung ist hier keine Formalie, siehe Abschnitt 2.

**Nicht doppelt.** E-06, E-23 und E-24 stehen mit fertiger Migrations-SQL in
`backend-security-fixes.md` und werden hier nicht wiederholt, nur an einer
Stelle geschärft (E-52).

---

## 1. Was existiert

Alles Serverseitige des Monorepos, vollständig aufgezählt.

| Ort | Was | Umfang |
|---|---|---|
| `03_Backend/supabase-schema.sql` | Grundschema, alles Weitere baut darauf auf | 526 Zeilen |
| `03_Backend/migrations/*.sql` | 8 handgefahrene Nachträge, 14.05. bis 20.06.2026 | 1480 Zeilen |
| `supabase/functions/llm/index.ts` | einzige Edge Function, Anthropic-Proxy mit Gratiskontingent | 94 Zeilen |
| `02_Frontend/admin/index.html` | Redaktions- und Freigabeoberfläche, statische Seite | 1952 Zeilen |
| `04_Datenpipeline/scripts/` | 39 Skripte, davon 11 mit Supabase-Zugriff über `service_role` | Python |
| `netlify.toml` | Auslieferung der PWA | 14 Zeilen |

In Zahlen: **11 Tabellen**, **30 Funktionen** (zwei davon zweimal definiert),
**3 Trigger**, **15 RLS-Policies**, **1 Edge Function**. Kein Storage-Bucket,
kein `pg_cron`, kein Webhook, kein `pg_net`, keine Vault-Nutzung. Danach ist
gezielt gesucht worden.

### Die 11 Tabellen und wer sie heute anfasst

| Tabelle | Geschrieben von | Gelesen von |
|---|---|---|
| `profiles` | Trigger bei Anmeldung, PWA direkt (`username`, `show_real_name`), 6 Funktionen | PWA, Neubau |
| `facts` | Pipeline und Admin über `service_role`, PWA bei Nutzer-Fakten | PWA, Neubau, alles |
| `collected_facts` | PWA direkt, `collect_group_fact`, `collect_team_fact` | PWA |
| `saved_facts` | PWA direkt | PWA |
| `user_trophies` | Trigger, `unlock_trophy`, PWA direkt möglich | PWA |
| `user_city_scores` | Trigger | nur über `get_leaderboard` |
| `group_sessions` | nur RPCs | PWA |
| `group_participants` | nur RPCs | PWA |
| `group_collects` | nur RPCs | PWA |
| `comments` | PWA schreibt | **niemand** |
| `upvotes` | **niemand** | **niemand** |

Die letzten beiden Zeilen sind belegt und nicht geschätzt: `Api.getComments`
und `Api.toggleUpvote` sind in `02_Frontend/app/` exportiert und haben **null**
Aufrufstellen, `Api.addComment` hat eine. Die Kommentarfunktion schreibt also
auf den Server und liest aus dem `localStorage`
(`screen-fact.jsx:82`, `storage.jsx:80`). Ein Kommentar von A erreicht B nie.
`upvotes` ist vollständig tot. Für den Neubau heißt das: zwei der elf Tabellen
tragen kein Migrationsrisiko, weil kein Nutzerwert darin steckt, den jemand
vermissen würde.

### Der Client-Vertrag der laufenden PWA

17 RPCs und 10 Tabellenzugriffe, alle in `02_Frontend/app/api.jsx` (487 Zeilen)
gebündelt. Das ist die gute Nachricht dieser Aufnahme: es gibt genau **eine**
Datei, die das Backend berührt, plus den Realtime-Kanal `group:<id>` auf drei
Tabellen. Wer den Vertrag umstellt, hat einen Ort dafür.

### Was der Neubau heute berührt

Zwei Stellen, mehr nicht:

- `supabase_fact_remote_data_source.dart`: `facts` lesen.
- `supabase_auth_remote_data_source.dart`: Anmeldung, plus `profiles.username`.

Von den 17 RPCs ruft der Neubau **keinen einzigen** auf. Das ist für die
Richtungsentscheidung der wichtigste Satz dieses Dokuments: die Kopplung des
Flutter-Clients an das heutige Backend ist heute fast null, und jeder Tag, an
dem die Schritte 36 bis 45 gebaut werden, macht sie größer.

---

## 2. Der strukturelle Kern: es gibt kein Migrationssystem

Kein `supabase/config.toml`, kein Supabase-CLI-Projekt, keine Ledger-Tabelle,
kein Verzeichnis, das die Reihenfolge erzwingt. Jede der acht Dateien in
`03_Backend/migrations/` trägt im Kopf einen Satz der Form „Run manually in
Supabase SQL Editor". Zwei Folgen, und beide binden alles Weitere:

**1. Die Dateien sind eine Absichtserklärung, kein Zustand.** Ob eine Migration
gelaufen ist, ob sie ganz gelaufen ist, ob jemand danach im SQL-Editor etwas
von Hand nachgezogen hat: aus dem Repository ist nichts davon zu sehen. Alle
Befunde unten stehen deshalb unter demselben Vorbehalt.

**2. Die Reihenfolge entscheidet über das Ergebnis, und sie ist nicht
festgehalten.** `start_group_session` ist zweimal definiert
(`2026-06-04_group_sessions.sql:193` und `2026-06-05_team_sessions.sql:473`),
`_team_generate_orders` ebenfalls (`2026-06-05:...` und `2026-06-07:...`).
Welche Fassung produktiv läuft, hängt daran, in welcher Reihenfolge jemand die
Dateien in den Editor kopiert hat. Das ist als E-21 bekannt; neu ist, dass es
kein Einzelfall ist, sondern die Bauweise.

**Daraus folgt der erste Arbeitsschritt jeder Variante, egal wie entschieden
wird:** ein Schema-Dump der laufenden Datenbank. `pg_dump --schema-only`, dazu
`pg_policies`, `pg_proc` und `information_schema.role_routine_grants`. Ohne den
weiß niemand, wovon migriert wird, und die Diagnoseabfragen in
`backend-security-fixes.md`, Abschnitt 7, sind bereits die halbe Vorlage.

---

## 3. Neue Befunde

Alle aus den Dateien belegt, keiner an der laufenden Datenbank bestätigt. Zu
jedem steht, wie man ihn in einer Minute prüft.

### E-52: Zwei weitere Funktionen nehmen die Nutzerkennung als Parameter, und alle drei sind ohne Anmeldung erreichbar

E-06 beschreibt `increment_coins`. Es sind aber drei:

| Funktion | Kennung vom Aufrufer | Wirkung |
|---|---|---|
| `increment_coins(uid, amount)` | ja | Coins auf fremdem Konto |
| `unlock_trophy(p_user_id, p_trophy_key)` | ja | beliebige Trophäe auf fremdem Konto |
| `collect_fact_validated(p_user_id, …)` | ja | Sammlung und Coins auf fremdem Konto |

Keine der drei vergleicht mit `auth.uid()`. `collect_fact_validated` ist in der
PWA toter Code, in der Datenbank aber vorhanden und aufrufbar.

**Und sie sind vermutlich nicht einmal an eine Anmeldung gebunden.** Im
gesamten Backend stehen **fünf** `GRANT`- oder `REVOKE`-Zeilen, alle fünf in
`2026-06-20_ai_proxy.sql`, alle fünf für `ai_consume` und `ai_refund`. Für jede
andere Funktion gilt der PostgreSQL-Standard: `EXECUTE` an `PUBLIC`, und
`PUBLIC` schließt `anon` ein. `get_leaderboard` gibt die Nutzerkennungen mit
aus und ist ebenfalls ungeschützt. Die Kette lautet also: ohne Konto Kennungen
abholen, ohne Konto darauf schreiben.

*Prüfung:* **die hier zuerst genannte Abfrage taugt nicht**, am 02.09.2026
gemessen. `information_schema.role_routine_grants` zeigt Rechte, die an die
Pseudorolle `PUBLIC` vergeben sind, **gar nicht an**, und genau die sind der
Befund. Wer sie laufen lässt, bekommt eine leere Liste und hält den Befund für
behoben. Richtig ist `has_function_privilege`, ausgeschrieben als Abfrage K in
`backend-security-fixes.md`.

*Nachtrag vom 02.09.2026:* es sind **vier** Funktionen mit fremder Kennung, nicht
drei. `get_my_rank(p_user_id, …)` liest nur, ist aber ohne Konto erreichbar.

### E-53: Nutzer-Fakten können sich selbst freigeben

```sql
create policy "insert own fact" on public.facts
  for insert with check (auth.uid() = created_by and is_user_created = true);
```

`is_approved` kommt in der Bedingung nicht vor. Dass `api.jsx:176` beim
Einfügen `is_approved: false` setzt, ist eine Höflichkeit des Clients, keine
Regel des Servers. (Bis zum 02.09.2026 stand hier `:167`, dort steht
`text: factData.text`. Nachgesehen und richtiggestellt.) Der Kommentar darüber („bleibt false bis ein Admin den Fakt
freigibt") beschreibt eine Absicht, die im Schema nicht steht. Wer die Anfrage
selbst formuliert, veröffentlicht unmoderierten Text für alle Nutzer, in einer
App, deren Inhalt das Produkt ist. Der Trigger `on_user_fact_created` legt
obendrein die Trophäen `autor` und `viel_autor` mit an.

*Prüfung:* als normaler Nutzer einen Fakt mit `is_approved: true` einfügen.

### E-54: Coins sind über Gruppensitzungen unbegrenzt farmbar

`collect_group_fact` schreibt nach erfolgreichem Sammeln
`update public.profiles set coins = coins + 50` für alle Teilnehmer,
bedingungslos.

**Die Sperre ist nicht die, die hier bis zum 02.09.2026 stand.** Das
`UNIQUE (session_id, fact_id)` ist am 05.06.2026 gedroppt und durch **zwei
partielle Indizes** ersetzt worden (`2026-06-05_team_sessions.sql:54-67`): einer
für den Koop-Modus über `(session_id, fact_id) where team is null`, einer für
den Team-Modus über `(session_id, team, fact_id) where team is not null`. Am
Befund ändert das nichts, der Geltungsbereich bleibt **pro Sitzung**; eine neue
Sitzung ist eine neue Zeile und damit erneut 50 Coins für denselben Fakt. Im
Team-Modus ist es sogar eine Sperre weniger, weil beide Teams denselben Fakt
ausdrücklich unabhängig sammeln dürfen.

**Und die naheliegende Behebung ist keine Änderung eines Indexbereichs.**
„Einmal je Nutzer und Fakt" lässt sich so nicht schreiben: `group_collects` hat
keine Spalte `user_id`, die Gutschrift geht an **alle** Teilnehmer der Sitzung.
Wer die Sperre am Nutzer festmachen will, braucht ein anderes Datenmodell. Das
ist der Grund, warum dieser Befund keine Migration ist, sondern eine
Entscheidung.

Sitzungen anzulegen kostet nichts, und der Client bestimmt dabei alles:
`create_group_session` nimmt `p_fact_ids` entgegen, `create_team_session`
zusätzlich `p_meeting_lat` und `p_meeting_lng`. Der Ablauf: an einem beliebigen
Fakt stehen, Sitzung mit genau diesem Fakt anlegen, starten, sammeln, 50 Coins,
wiederholen. Im Team-Modus kommen über `tag_endpoint` noch einmal 100 dazu,
und der Endpunkt ist der selbst gesetzte Treffpunkt, also die eigene Position.
Rund 150 Coins pro Durchlauf, ohne einen Schritt zu gehen.

`collected_facts` bleibt dabei sauber, dort steht `on conflict do nothing`.
Betroffen ist die Währung, nicht die Rangliste. Das macht es kleiner als es
klingt, hat aber eine Folge für die Ökonomie insgesamt: solange Beträge und
Anlass im Client bestimmbar sind, darf für Coins nichts zu haben sein, was
Geld wert ist.

*Prüfung:* zweimal dieselbe Sitzungsschleife fahren und `coins` vergleichen.

### E-55: Rangliste und Trophäen sind vom Client direkt schreibbar

```sql
CREATE POLICY "own city scores" ON public.user_city_scores FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own trophies"    ON public.user_trophies    FOR ALL USING (auth.uid() = user_id);
```

`FOR ALL` schließt `INSERT` und `UPDATE` ein, und ohne `WITH CHECK` gilt der
`USING`-Ausdruck auch für neue Zeilen. Ein Nutzer darf also seinen eigenen
Punktestand je Stadt auf jeden Wert setzen und sich jede Trophäe eintragen. Das
ist dieselbe Lücke wie E-24 auf `profiles`, nur auf den beiden Tabellen, die
ausdrücklich für den Wettbewerb da sind. `get_leaderboard` liest im Modus
„alltime, Stadt" direkt aus `user_city_scores`.

E-16 beschreibt an diesen beiden Tabellen die **Lesbarkeit**. Das hier ist die
Schreibseite, und sie ist die teurere.

*Prüfung:* `update user_city_scores set score = 9999 where user_id = auth.uid()`
als normaler Nutzer.

### E-56: Drei verschiedene Stadtschlüssel, und Rom fällt durch alle

Für dieselbe Sache gibt es drei Normalisierungen:

| Ort | Verfahren | Ergebnis für München |
|---|---|---|
| `handle_fact_collected`, `get_leaderboard`, `get_my_rank` | `lower(city)` | `münchen` |
| `_team_generate_orders` (seit 07.06.) | `_slugify(city)` | `muenchen` |
| `_city_default_meeting` | `lower(p_city)` gegen feste Liste | Liste führt `muenchen` |

Für München geht das gut, weil die Rangliste `münchen` schickt
(`screen-profil.jsx:9`) und das Team-Formular `muenchen`
(`screen-challenge.jsx:3670`). Jede Funktion wird von genau einer Stelle
gerufen, und deshalb fällt es nicht auf. Es ist Glück, keine Konstruktion.

**Rom fällt durch.** Der Rückfall-Zweig im Trigger bildet `nr LIKE 'ROM%'` auf
`'Rom'` ab, der Backfill vom 07.06. bildet dasselbe Präfix auf `'Rome'` ab. Der
Ranglisten-Filter schickt `rom`. Steht in `facts.city` das Wort `Rome`, ist der
Stadtschlüssel `rome`, und die Rom-Rangliste bleibt leer, wöchentlich wie
gesamt. Ist `facts.city` für Rom noch leer, greift der Rückfall, und die
Punkte alter und neuer Sammlungen liegen auf zwei verschiedenen Schlüsseln.

**Zusatzverdacht, unbestätigt und leicht zu prüfen:**
`04_Datenpipeline/scripts/migrate_nr_codes.py:24-31` vergibt die Präfixe nach
Breitengrad, mit `lat > 48.5 → PAU`. Regensburg (49,02), Nürnberg (49,45) und
Weimar (50,98) liegen alle darüber. Wenn dieses Skript je über die ganze
Tabelle gelaufen ist, trägt jede Stadt nördlich von Passau ein `PAU`-Präfix,
und der Backfill hat sie danach als Passau eingetragen. Das wäre kein
Anzeigefehler, sondern falsche Stammdaten.

*Prüfung:* `select coalesce(city,'(null)'), count(*) from facts group by 1
order by 2 desc;` und dasselbe über `split_part(nr,'_',1)`.

### E-57: Der Team-Ausgleich kann nicht wirken, und beide Teams laufen denselben Stationssatz

`_team_generate_orders` sampelt Stationen, baut daraus zwei Reihenfolgen und
prüft dann, ob die Wegstrecken auseinanderliegen:

```sql
select sum(_haversine_m(meeting, f)) into v_dist_a from facts f where f.id = any(v_a);
select sum(_haversine_m(meeting, f)) into v_dist_b from facts f where f.id = any(v_b);
v_balance := abs(v_dist_a - v_dist_b) / greatest(v_dist_a, v_dist_b);
```

`v_a` und `v_b` sind zwei **Permutationen derselben Menge**, in beiden Zweigen
der Verzweigung darüber. `any()` ist Mengenmitgliedschaft, die Reihenfolge geht
nicht ein. Also ist `v_dist_a` immer gleich `v_dist_b`, `v_balance` immer 0,
die Schwelle `<= 0.20` immer erfüllt, und die Schleife bricht nach dem ersten
von drei Versuchen ab. Der ganze Resampling-Apparat ist unerreichbar.

Das ist derselbe Fund wie die dreistufige Auswahl mit dem Kommentar „FIX
(Daniel-Feedback)" aus Schritt 33: eine Vorkehrung, die aussieht als würde sie
wirken, und die ihr Ergebnis nicht ändern kann.

Zwei Anschlussbefunde:

- Beide Teams bekommen **dieselben Stationen**, nur in anderer Reihenfolge. Der
  Partial-Index dazu trägt es im Kommentar („beide Teams dürfen denselben Fakt
  unabhängig sammeln"), es ist also gewollt. Dann ist der Ausgleich aber von
  vornherein gegenstandslos, und die Frage, was die zwei Teams unterscheiden
  soll, ist eine Produktfrage und keine Rechenaufgabe.
- Die Winkelnormalisierung in derselben Funktion ist wirkungslos:
  `abs(((x - y) + pi()) - pi())` kürzt sich zu `abs(x - y)`, gemeint war
  offensichtlich ein Modulo. Bei Winkeln nahe dem Sprung von `atan2` fällt der
  Vergleich damit falsch aus.

*Prüfung:* im Testprojekt eine Team-Sitzung anlegen und `team_a_order` mit
`team_b_order` als Menge vergleichen.

### E-58: Der Admin ist eine statische Seite mit einem Generalschlüssel im Browser

`02_Frontend/admin/index.html` fragt den **`service_role`-Schlüssel** ab, legt
ihn in `localStorage` (`fact_admin_service_key`) und spricht damit direkt gegen
`https://ftpxpqeombdqodphnptk.supabase.co`. Daneben liegt ein
Anthropic-Schlüssel im selben Speicher. Der `service_role`-Schlüssel umgeht
**jede** RLS-Policy: Freigabe, Löschung, Fremdprofile, alles.

Es gibt also keinen Admin-Server, keine Rollenprüfung, kein Protokoll darüber,
wer wann was freigegeben hat. Wer den Schlüssel hat, ist das Backend. Dieselbe
Bauart hat die Pipeline: 11 Python-Skripte lesen `service_role_key` aus
`04_Datenpipeline/scripts/import_config.json`. Die Datei steht in `.gitignore`,
liegt aber im Klartext in einem OneDrive-Ordner.

Das ist kein Fehler in einer Zeile, sondern der Grund, warum der erweiterte
Auftrag Sinn ergibt. Wenn das Backend neu gebaut wird, ist der Adminweg der
Teil, der nicht mitgenommen werden kann.

*Prüfung:* entfällt, es steht wörtlich in der Datei. Zu klären ist nur, ob
`/admin` öffentlich ausgeliefert wird. `netlify.toml` veröffentlicht
`02_Frontend/dist`, dort liegt kein `admin/`. Ob es getrennt deployed ist,
weiß nur das Netlify-Konto.

---

## 4. Zwei Nebenbefunde ohne eigene Nummer

**Die Auslieferung der PWA ist nicht das, was `netlify.toml` sagt.** Dort steht
`base = 02_Frontend`, `command = npm install && npm run build`,
`publish = 02_Frontend/dist`. In `02_Frontend/` gibt es **keine**
`package.json` und keine Vite-Konfiguration. Daneben liegen fünf ZIP-Dateien
mit Namen bis `FACT_app_deploy_v351.zip`. Wie die laufende Seite entsteht, ist
aus dem Repository nicht ablesbar. Das ist Auslieferung, nicht Backend, gehört
aber in dieselbe Antwort, wenn jemand fragt, was „daneben stellen" praktisch
bedeuten würde.

**Drei von 30 Funktionen setzen `search_path`.** Der Standardbefund jedes
Supabase-Linters. Über PostgREST praktisch nicht ausnutzbar,
`backend-security-fixes.md` ordnet das bereits ein, und die Blöcke dort
schreiben `public, pg_temp`.

---

## 5. Was die Richtungsentscheidung jetzt noch braucht

Die Richtung steht seit dem 31.08.2026: neu bauen, mit denselben Leitplanken
wie der Client. Offen sind drei Dinge, und keines davon ist ohne Janek oder
Dairen zu klären.

**a) Umzug in einem Schritt oder Nebeneinander.** Die PWA ist der einzige echte
Nutzer des heutigen Backends, und sie hängt an genau einer Datei. Das spricht
für ein zweites Projekt neben dem laufenden, mit einem Umschaltpunkt in
`api.jsx`, statt für eine Umbaustelle unter Betrieb. Es setzt aber voraus, dass
die Daten migrierbar sind, und das hängt an dem Schema-Dump aus Abschnitt 2.

**b) Was mitkommt.** Die Ökonomie und die Trophäenlogik liegen heute in einem
Trigger von 120 Zeilen mit fest verdrahteten Schwellen, Kategorie-Präfixen und
Stadtnamen. Ob das im Neubau wieder Datenbanklogik wird oder Anwendungslogik,
ist eine Architekturfrage und keine Portierungsfrage. Sie berührt E-49 direkt.

**c) Wer redigiert.** Ohne eine Antwort auf E-58 ist jeder Neubau nach einem
Tag wieder da, wo er angefangen hat, weil jemand die Fakten freigeben können
muss.

**Und eine Vorarbeit, die keine Entscheidung braucht:** der Schema-Dump. Er
kostet eine Minute Zugriff, er ist die Grundlage für alle drei Fragen oben, und
solange er fehlt, ist jeder Satz in diesem Dokument mit „laut Dateien"
eingeschränkt.

---

## 6. Was am Backend schon entschieden ist, bevor es dran ist

Am 31.08.2026 sind fünf technische Fragen beantwortet worden, und drei der
Antworten sind **Backend-Arbeit**. Sie stehen hier, weil sie sonst im
Entscheidungsdokument versauern, bis jemand sie sucht. Reihenfolge und Zuschnitt
gehören in den Backend-Auftrag, nicht in den Client.

| Auftrag | Kommt aus | Was zu tun ist |
|---|---|---|
| **Zeit serverseitig rechnen** | E-19, Antwort (a) | Sitzungsende und Bonusfaktor entstehen aus serverseitigen Größen. Der Client zeigt einen Ablauf, er verbucht ihn nicht. |
| **Trophäen und Punktestände dichtmachen** | E-49 plus E-16 plus E-55 | Der Server ist die einzige Wahrheit. `user_trophies` und `user_city_scores` sind heute für jeden lesbar **und** vom Besitzer schreibbar; die Leseseite braucht eine Entscheidung zum Schalter „Echten Namen zeigen", die Schreibseite braucht dieselbe Behandlung wie `profiles` in Migration 1. |
| **Die defekte Ableitung in der PWA entfernen** | E-49 | `wltDeriveTrophies` (`screen-wallet.jsx:114-128`) rechnet den Trophäenstand clientseitig neu und liegt dabei für Stadt-, Rang- und Geheim-Trophäen dauerhaft falsch. Das ist PWA-Arbeit, nicht Datenbank. |
| **Gruppen-Jagd: Realtime bleibt, drei Löcher nicht** | ADR-009 | E-21 (`start_group_session` doppelt definiert), E-54 (Coins über Sitzungen farmbar), E-57 (Team-Ausgleich wirkungslos). Schritt 40 baut gegen diese drei, ob sie behoben sind oder nicht. |

**Zwei Dinge, die diese Liste nicht sagt und die dazugehören.**

Erstens: **nichts davon ist eine Reihenfolge.** E-06 und E-24 haben eine
entschiedene Reihenfolge (Abschnitt „Entscheidungsstand" in
`backend-security-fixes.md`), diese vier haben keine. Wer sie plant, plant sie
zusammen mit dem Schema-Dump aus Abschnitt 2.

Zweitens: **die Reihenfolge Frontend zuerst hat eine Kante, und sie liegt bei
E-19.** Das Sitzungsende in Phase 5 ist bis zur serverseitigen Zeit nicht
parität-treu baubar. Anzeigen ja, verbuchen nein. Wer Phase 5 abschließen will,
ohne das Backend anzufassen, baut entweder einen clientseitigen Timer, und das
ist genau die Ausnahme, die am 31.08.2026 abgelehnt wurde, oder er lässt den
Moment offen, in dem aus Zeit Punkte werden.

**OD-002 gehört ausdrücklich nicht auf diese Liste.** Die lokale
Datenbanktechnologie ist am 31.08.2026 offen geblieben, mit Begründung: sie wird
entschieden, wenn ein echtes Offline-Ticket die Abfragen und die Datenmenge
liefert, und nicht, weil ADR-007 ein paar Werte persistieren musste.
