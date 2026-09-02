# Supabase-Migrationen zum Kopieren, in Reihenfolge

Diese Dateien sind ein **Auszug**, keine eigene Quelle. Sie sind Zeichen für
Zeichen aus `docs/operations/backend-security-fixes.md` geschnitten. Wo Dokument
und Datei sich unterscheiden würden, gilt das Dokument, und dann ist der Auszug
falsch geschnitten. Die einzige bewusste Ergänzung steht unten unter
„Was am SQL ergänzt wurde".

Jede Datei ist zum Öffnen, Kopieren, Einfügen und Ausführen in einem Zug
gedacht: Supabase-Dashboard, „SQL Editor", einfügen, „Run". Kein Negativtest und
keine Diagnoseabfrage steht darin, denn ein Negativtest **soll** scheitern und
würde die Migration abbrechen. Die liegen in `99-pruefungen.sql`.

## Der Ist-Zustand ist die Datei mit der Nummer 00, und sie liegt schon da

`docs/operations/backend-schema-probe.sql`, eine Ebene höher. Sie fragt ab, was
in der laufenden Datenbank tatsächlich steht, statt es aus dem Repository
abzuleiten. Sie gehört vor alles andere, weil ohne sie unbekannt ist, welche der
alten Migrationen überhaupt gelaufen sind.

## Reihenfolge

| Datei | Befund | Macht zu | Bricht die PWA |
|---|---|---|---|
| `01-e24-profiles-spalten.sql` | E-24 | `coins`, `score_total`, `ai_used`, `ai_limit` sind nicht mehr per `UPDATE` setzbar. Nimmt D-8 mit. | nein |
| `02-e06-increment-coins.sql` | E-06 | `increment_coins` schreibt nur noch das eigene Konto, und nur bis zum Deckel (500, verstellbar). | nein |
| `03-e23-collected-facts.sql` | E-23 | Der Client fügt nicht mehr direkt in `collected_facts` ein. Die 150-Meter-Prüfung ist nicht mehr umgehbar. **Ändert unbemerkt eine Spielregel, siehe den Kopf der Datei.** | **ja, vollständig** |
| `04-e52-ausfuehrrechte.sql` | E-52 | `unlock_trophy` ist kontogebunden; ohne Konto ist keine schreibende RPC mehr rufbar. | nein |
| `05-e53-fakt-freigabe.sql` | E-53 | Ein Nutzer kann seinen Fakt nicht mehr selbst freigeben. | nein |
| `06-e55-rangliste-schreibrechte.sql` | E-55 | Punktestände und Trophäen sind nicht mehr clientschreibbar. | nein |
| `07a-e16-leseseite.sql` | E-16 | Fremde Trophäen und fremde Stadtpunktestände sind nicht mehr lesbar; die Rangliste zeigt nur noch den Username. | nein |
| `07b-e16-rueckgabe.sql` | E-16 | `user_id` fällt aus der Rangliste, `is_me` und `city_count` kommen, `'Entdecker'` fällt weg. | **ja, an drei Stellen** |
| `99-pruefungen.sql` | keiner | Diagnoseabfragen A bis Z und die Negativtests 1 bis 82. Nicht in einem Zug ausführen. | nichts, sie ist rein lesend |

Zwei Zwänge in dieser Reihenfolge, der Rest ist frei:

- **04 gehört vor 06.** Läuft 06 allein, ist der Tabellenweg zu, `unlock_trophy`
  nimmt aber weiter eine fremde Kennung an: der Angriff wäre verlegt, nicht
  behoben.
- **07a gehört vor 07b.** 07b ersetzt Schritt 1 von 07a nicht; die beiden
  offenen Lese-Policies fallen in 07a.

01 vor 02 ist die Empfehlung des Dokuments, aber zwischen beiden entsteht kein
kaputter Zustand: nach 01 ist `coins` per `UPDATE` gesperrt und
`increment_coins` läuft als Definer weiter.

Das Dokument empfiehlt für jeden Block, ihn zuerst mit `rollback;` statt
`commit;` laufen zu lassen, die Diagnoseabfragen dazwischen anzusehen und dann
mit `commit;` zu wiederholen. Die Dateien hier enden mit `commit;`, weil das der
Endzustand ist; wer den Probelauf will, ändert die letzte Zeile von Hand.

**Jede Datei ist idempotent.** Ein zweiter Lauf macht nichts kaputt: vor jedem
`create policy` steht ein `drop policy if exists`, Funktionen entstehen per
`create or replace` beziehungsweise nach einem `drop function if exists`, und
`grant` und `revoke` sind wiederholbar. Der Kopf jeder Datei sagt das noch
einmal für sich.

## Was danach in der PWA nicht mehr geht

**Nach 03 bricht das Sammeln, und zwar still.** `api.jsx:145` ist der einzige
Weg, auf dem in der PWA ein Fakt gesammelt wird. Mit ihm fallen das normale
Sammeln (`app.jsx:714`), das Sammeln in der Schnitzeljagd (`app.jsx:738`), über
den Trigger die Zählung `score_total`, die Stadtwertung `user_city_scores` und
sämtliche Trophäen, und die Wochen-Rangliste. `_apiCheck`
(`api.jsx:139-146`) verschluckt den Fehler: die Oberfläche zeigt weiter
„gesammelt". Der Gruppenmodus bleibt der einzige funktionierende Sammelweg, weil
er schon heute über eine RPC geht.

**Nach 07b bricht `screen-profil.jsx` an drei Stellen, alle drei still.**
Zeile 88 (`String(row.user_id) === String(userId)`) ist immer falsch, die eigene
Zeile wird nicht mehr hervorgehoben. Zeile 117
(`!rows.some(r => String(r.user_id) === String(userId))`) ist immer wahr, der
eigene Rang wird unten angehängt, obwohl er in der Liste steht. Zeile 103
(`{row.display_name}`) bleibt für Konten ohne Username leer, weil der Server
`null` liefert statt `'Entdecker'`.

**Nach 07a wird der Schalter „Echten Namen zeigen" zu einer Lüge.**
`screen-profil.jsx:693` schreibt `show_real_name` weiter, aber niemand liest die
Spalte noch. Der Schalter gehört im PWA-Repository aus der Oberfläche. Das ist
ein Client-Auftrag, keine Migration.

**Kleinere Wirkungen:** nach 04 ist ohne Konto keine schreibende RPC mehr rufbar
(`check_username` bleibt ausdrücklich offen), nach 05 wird ein Insert mit
`is_approved: true` mit `42501` abgewiesen, nach 02 wird ein negativer
Kontostand still auf 0 gekappt statt zugelassen.

### Warum 03 und 07b laufen, obwohl sie die PWA brechen

Beide waren gesperrt, und die Sperre war richtig. Am 02.09.2026 hat der
Eigentümer festgestellt, dass die PWA derzeit nicht live läuft und ein Ausfall
dort in Kauf genommen ist. Damit fällt die Sperre für beide. Das Dokument hält
die Aufhebung an seinen eigenen Fundstellen fest: im Entscheidungsstand, in
Abschnitt 4, in 11.3, in 14.1, in 14.3 und in den beiden Blockkommentaren
selbst. Quelle und Auszug sagen also dasselbe; wer nur eine von beiden liest,
liest nichts Falsches.

Aufgehoben ist die Sperre, nicht der Bruch. E-23 ist der Befund mit der
höchsten Stufe in diesem Satz: die 150-Meter-Prüfung beim Sammeln ist heute
nicht nur fälschbar, sondern vollständig umgehbar.

Eine Kleinigkeit bleibt offen, und sie hat mit der Aufhebung die Seite
gewechselt: nach 07b liefert der Server für Konten ohne Username `null`, und die
Anzeige braucht dafür einen Text. Der Wortlaut ist eine Inhaltsfrage (Dokument,
14.7). Solange die PWA nicht live ist, erreicht die leere Zeile niemanden, also
blockiert die Frage nicht mehr die Migration, sondern den PWA-Release. Hier wird
kein Wortlaut erfunden.

## Was am SQL ergänzt wurde, und nur das

`notify pgrst, 'reload schema';` als letzte Zeile von **`01`**, **`02`**,
**`03`**, **`05`** und **`06`**, jeweils mit einer Kommentarzeile darüber, die
die Ergänzung als solche kennzeichnet. In `04`, `07a` und `07b` steht die Zeile
schon im Dokument.

Zwei verschiedene Gründe, und beide stehen im Dokument:

- `02` und `03` ändern **Funktionsrümpfe und Ausführrechte**. Ohne die Zeile
  antwortet die API im Zweifel mit `PGRST202` auf eine Funktion, die es gibt.
  Abschnitt 11.3 hält fest, dass die Blöcke 2a, 2b und 3b sie brauchen und im
  Dokument nicht haben.
- `01`, `05` und `06` ändern **Tabellen- und Spaltenrechte**. PostgREST leitet
  daraus ab, welche Spalten eine Anfrage schreiben darf, und hält auch das im
  Schemacache: eine entzogene Spalte kann für die API weiter als schreibbar
  gelten, und der Fehler zeigt sich dann nicht als Rechtefehler, sondern als
  Schreibvorgang, der durchgeht und nichts tut. Am 02.09.2026 entschieden,
  nachgezogen in Abschnitt 11.3 und als Eintrag 9 in Abschnitt 13.

Die Zeile ist idempotent und kostet nichts. Ein veralteter Cache kostet eine
halbe Stunde Fehlersuche an einer Stelle, die niemand verdächtigt.

## Was bewusst nicht mitgeschnitten wurde

| Nicht enthalten | Wo es steht | Warum |
|---|---|---|
| Block **4c**, die parameterfreie Fassung von `unlock_trophy` | Dokument 11.4 | Liegt bewusst ungenutzt da und läuft erst, wenn ein Client sie ruft. Eine zweite Funktion ist eine zweite Rechtefläche. |
| Block **5b**, die strengere Insert-Policy auf `facts` | Dokument 11.5 | Dort ausdrücklich nicht Teil von Migration 5. Sie verteuert den Tag, an dem ein Client eine Stadt mitgeben soll. |
| Das Rezept für ein späteres **Bearbeiten** eines Fakts | Dokument 11.5 | Im Dokument mit „NICHT AUSFÜHREN" überschrieben. |
| `alter database postgres set fact.coins_max_delta = ...` | Dokument, nach Block 2b | Eigene Anweisung, gehört nicht in die Migrationsdatei, weil ohne sie bereits 500 gilt. |
| `drop function if exists public.unlock_trophy(uuid, text);` | Dokument 11.4 | Der letzte Schritt von Weg B, erst nach einem Client-Release. |
| **Alle Rückabwicklungen** | Dokument, je Block direkt unter dem Block | Sie sind der Notausgang und kein Teil des Vorwärtsschritts. Wer eine braucht, holt sie aus dem Dokument, wo auch die Warnung dazu steht. |
| Die Negativtests und Diagnoseabfragen | `99-pruefungen.sql` | Ein Negativtest soll scheitern. In einer Migration mitgeführt bricht er sie ab. |

## `99-pruefungen.sql` lesen, bevor man sie ausführt

Die Datei ist gegliedert und **nicht** in einem Zug auszuführen. Je Abfrage steht
darin, was erwartet wird und ob ein leeres Ergebnis Erfolg oder Fehlschlag
bedeutet. Das ist die Stelle, an der sich am leichtesten jemand vertut:

- Eine **Policy** weist nicht ab, sie liefert **null Zeilen ohne Fehler**.
- Nur ein fehlendes **Recht** liefert `42501`.
- Eine `WITH CHECK`-Verletzung beim `INSERT` gibt dagegen einen Fehler, ein nicht
  passendes `USING` beim `UPDATE` nur null betroffene Zeilen.

Die Tests 66, 68 und 70 sind deshalb bestanden, wenn **nichts** kommt. Und
Abfrage L1 bleibt leer, wenn zwei Fassungen derselben Funktion dieselbe Signatur
haben: ein leeres L1 ist kein Ergebnis, L2 ist die eigentliche Prüfung.

Die riskanteren Tests sind nicht die Sicherheitstests, sondern die
Nichtbruch-Tests. Test 42 (`check_username` ohne Konto), Test 62 und Test 76
(der Trigger schreibt weiter) und Test 67 (die eigenen Trophäen bleiben lesbar)
sind die vier, bei denen ein Fehlschlag Produktion bedeutet und nicht eine offene
Lücke.
