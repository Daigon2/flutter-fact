-- ##########################################################################
-- FACT-Backend, Datei 06 von 8: E-55, Schreibrechte auf Rangliste und
-- Trophäen
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitt 11.6,
-- Migration 6. Wörtlich übernommen, mit einer Ergänzung: siehe unten.
--
-- SCHLIESST
--   E-55. user_city_scores und user_trophies hatten FOR ALL ohne WITH CHECK,
--   also galt der USING-Ausdruck auch für neue und geänderte Zeilen: ein
--   Nutzer setzt seinen Punktestand je Stadt auf jeden Wert und trägt sich
--   jede Trophäe ein. Die Schreibrechte fallen für authenticated, anon und
--   PUBLIC, die FOR-ALL-Policies werden durch ausdrückliche SELECT-Policies
--   ersetzt. Für user_city_scores ist die Behebung vollständig, für
--   user_trophies eine Verkleinerung: welchen Schlüssel er über unlock_trophy
--   holt, entscheidet der Client weiter. Das ist E-49.
--
-- REIHENFOLGE
--   Datei 04 gehört davor. Läuft 06 allein, ist der Tabellenweg zu,
--   unlock_trophy nimmt aber weiter eine fremde Kennung an: der Angriff wäre
--   nicht behoben, sondern verlegt.
--
-- PWA DANACH
--   Nichts hört auf zu funktionieren. Kein Client schreibt in eine der
--   beiden Tabellen: Trophäen laufen über die RPC (api.jsx:243),
--   Punktestände nur über den Trigger. Die Leseseite bleibt hier
--   unverändert offen, die schließt erst Datei 07a.
--
-- VORHER PRÜFEN (99-pruefungen.sql)
--   Abfragen M, N, P und Q. N ist die Voraussetzung und nicht die
--   Nachkontrolle: liefert sie rls_forced = true, diesen Block NICHT
--   ausführen, sonst ist der Trigger ausgesperrt und Trophäen und
--   Stadtwertung sind still. P und Q sagen, ob der Befund schon benutzt
--   wurde; bei Q ist eine Abweichung nach oben vor Datei 03 auch durch
--   gelöschte collected_facts erklärbar.
--
-- NACHHER PRÜFEN
--   Abfrage T: alle sechs Schreibrechte false, beide Leserechte true.
--   Negativtests 57 bis 63. Test 62 ist der entscheidende: nach einem
--   Sammeln müssen score_total, user_city_scores und user_trophies weiter
--   wachsen.
--
-- ERGÄNZT GEGENÜBER DEM DOKUMENT
--   notify pgrst, 'reload schema'; am Ende. Diese Datei ändert Tabellen- und
--   Spaltenrechte, und PostgREST leitet daraus ab, welche Spalten eine Anfrage
--   schreiben darf; auch das steht im Schemacache. Ohne die Zeile kann eine
--   entzogene Spalte für die API weiter als schreibbar gelten. Am 02.09.2026
--   entschieden, festgehalten in Abschnitt 11.3 und in Eintrag 9 von
--   Abschnitt 13 des Dokuments.
--
-- IDEMPOTENZ
--   Ja. drop policy if exists vor create policy, wiederholbare revoke.
-- ##########################################################################

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

-- Ergänzt gegenüber dem Dokument, Begründung im Kopf und in Abschnitt 11.3.
notify pgrst, 'reload schema';
