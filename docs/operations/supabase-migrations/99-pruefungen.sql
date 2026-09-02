-- ##########################################################################
-- FACT-Backend: Diagnoseabfragen und Negativtests
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitte 7, 8, 11.7,
-- 11.8, 14.4 und 14.5. Die Abfragen sind wörtlich übernommen, die
-- Negativtests stehen im Dokument als Tabellen und sind hier zu Kommentaren
-- umgesetzt.
--
-- DIESE DATEI NICHT IN EINEM ZUG AUSFÜHREN.
-- Sie ist gegliedert. Jeder Abschnitt gehört einzeln markiert und einzeln
-- gelaufen, und zwar zu dem Zeitpunkt, der über ihm steht. Ein Negativtest
-- soll scheitern; in einer Migrationsdatei mitgeführt würde er die Migration
-- abbrechen. Deshalb liegt er hier und nicht dort.
--
-- Alle Abfragen sind rein lesend. Keine ändert Daten oder Rechte.
--
-- WIE EIN LEERES ERGEBNIS ZU LESEN IST, und das ist die Stelle, an der sich
-- am leichtesten jemand vertut (Abschnitt 14.5):
--   eine POLICY weist nicht ab, sie liefert NULL ZEILEN OHNE FEHLER;
--   nur ein fehlendes RECHT liefert 42501;
--   eine WITH-CHECK-Verletzung beim INSERT liefert dagegen einen Fehler, ein
--   nicht passendes USING beim UPDATE nur null betroffene Zeilen.
-- Wer bei den Tests 66, 68 und 70 eine Fehlermeldung erwartet, hält eine
-- bestandene Prüfung für einen Fehlschlag.
--
-- KÜRZEL IN DEN NEGATIVTESTS
--   [F] Ein Fehler ist das erwartete Ergebnis. Kommt kein Fehler, ist der
--       Test durchgefallen.
--   [E] Ein leeres Ergebnis ohne Fehler ist Erfolg. Die Policy weist ab.
--   [X] Es müssen Zeilen kommen. Ein leeres Ergebnis ist ein Fehlschlag.
--       Das sind die Nichtbruch-Tests, und sie sind die riskanteren.
--   [W] Schreibvorgang. Erfolg heißt "kein Fehler"; geprüft wird die Wirkung
--       in der Zeile, nicht die Zahl der Ergebniszeilen.
--
-- DER IST-ZUSTAND VOR ALLEM ("00")
--   Er steht nicht hier, sondern daneben:
--   docs/operations/backend-schema-probe.sql. Diese Datei hier ist die
--   Nachkontrolle je Migration, nicht die Aufnahme des Ausgangszustands.
--
-- Zwei Testkonten A und B, Aufrufe mit deren jeweiligem Session-Token,
-- anon-Fälle mit dem öffentlichen Schlüssel und ohne Token. Die Tests
-- gehören in eine Testdatenbank, nicht in die Produktion. Im Dokument sind
-- sie formuliert und nicht ausgeführt; hier auch nicht.
-- ##########################################################################

-- ==========================================================================
-- TEIL 1: Abfragen A bis E. VOR Datei 01, 02 und 03. Ausgabe sichern.
-- ==========================================================================

-- Was erwartet wird, je Abfrage:
--
-- A) Die Policies im Ist-Zustand: "own profile" auf profiles und
--    "own collected" auf collected_facts, beide mit cmd = ALL und leerem
--    with_check. Leeres Ergebnis wäre ein Befund gegen das Dokument: dann
--    gibt es gar keine Zeilengrenze. [X]
--
-- B) Tabellenweite Rechte. Steht hier UPDATE für authenticated, ist Befund 4
--    bestätigt und ai_proxy.sql:61 war wirkungslos. PUBLIC ist mitgeprüft.
--    Ein leeres Ergebnis ist gültig, aber unerwartet: dann war das
--    tabellenweite Schreibrecht nie vergeben. [X erwartet, leer = Befund]
--
-- C) Spaltenrechte auf profiles. Vor Datei 01 ist ein leeres Ergebnis der
--    Normalfall, weil Rechte tabellenweit und nicht spaltenweise vergeben
--    sind. Leer bedeutet hier also nicht "gesperrt". [leer = normal]
--
-- D) Genau eine Zeile, drei Wahrheitswerte. Wenn Befund 4 zutrifft, steht vor
--    Datei 01 überall true. Das ist eine Vermutung des Dokuments und keine
--    Messung: diese Abfrage ist die Stelle, an der sie entschieden wird.
--    Steht dort false, war das tabellenweite Recht nie vergeben, und das ist
--    ein eigener Befund. Leer ist unmöglich. [X]
--
-- E) Zwei Abfragen. Erste: zwei Zeilen, und rls_forced MUSS false sein, sonst
--    Datei 03 nicht ausführen. Dieselbe Frage für die Tabellen der Dateien
--    05, 06 und 07a stellt Abfrage N in Teil 3. Zweite: bis zu neun
--    Zeilen; jede Funktion, die hier fehlt, existiert in dieser Datenbank
--    nicht, und das ist ein eigener Befund. [X]

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

-- ==========================================================================
-- TEIL 2: Abfragen F bis J. NACH Datei 01, 02 und 03.
-- ==========================================================================

-- F) nach Datei 01: muss (false, false, false) liefern. Steht irgendwo true,
--    gibt es einen Rechteweg, den das Dokument nicht kennt. Zugleich die
--    Regressionsprobe gegen ein späteres, gut gemeintes
--    "grant update on public.profiles to authenticated". [X]
--
-- G) nach Datei 01: muss (true, true, true) liefern. Steht hier false, ist
--    die Registrierung in beiden Clients stumm kaputt. [X]
--
-- H) nach Datei 03: muss false liefern. [X]
--
-- I) nach Datei 02: erste Abfrage genau eine Zeile. NULL ist ein gültiger
--    Wert, dann greift der eingebaute Ausfallwert 500. Zweite Abfrage:
--    leeres Ergebnis = nichts dauerhaft hinterlegt, und das ist Erfolg,
--    solange 500 gelten soll. [leer = Erfolg]
--
-- J) nach Datei 02: auth_darf true, anon_darf false. [X]

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

-- ==========================================================================
-- TEIL 3: Abfragen K bis Q. VOR Datei 04, 05 und 06. Ausgabe sichern.
-- ==========================================================================

-- K) Eine Zeile je Funktion im Schema public, absteigend nach anon_darf. Vor
--    Datei 04 steht bei fast allen anon_darf = true, weil EXECUTE per
--    PostgreSQL-Standard an PUBLIC hängt. Das ist der Befund E-52. [X]
--
-- L) Zwei Stufen, und die Falle steht in der ersten. L1 findet nur
--    Doppelungen mit UNTERSCHIEDLICHEN Signaturen; bei gleicher Signatur
--    ersetzt die zweite Ausführung die erste, es gibt nur eine Zeile, und L1
--    bleibt leer. EIN LEERES L1 IST DESHALB KEIN ERGEBNIS. L2 ist die
--    eigentliche Prüfung: den Rumpf ausgeben und mit den beiden Dateien
--    vergleichen. [L1 leer = kein Befund, L2 X]
--
-- M) Die Policies auf facts, user_trophies und user_city_scores im
--    Ist-Zustand. Leeres Ergebnis wäre ein Befund gegen das Dokument. [X]
--
-- N) Voraussetzung für Datei 06, nicht Nachkontrolle. Liefert sie
--    rls_forced = true, NICHT ausführen: der Trigger wäre danach
--    ausgesperrt, und damit Trophäen und Stadtwertung. Gilt für Datei 07a
--    und 07b unverändert weiter. [X]
--
-- O) Ist E-53 schon benutzt worden? Erste Abfrage zählt, zweite listet.
--    Leeres Ergebnis der zweiten = kein selbst freigegebener Fakt, also
--    Erfolg. Eine Zeile bedeutet NICHT Missbrauch: ob ein Admin oder der
--    Client freigegeben hat, ist in den Daten nicht unterscheidbar, weil es
--    kein Protokoll gibt. Das ist E-58. [leer = Erfolg, Zeilen = durchsehen]
--
-- P) Ist E-55 schon benutzt worden? Leeres Ergebnis der ersten Abfrage =
--    kein unbekannter Trophäenschlüssel, also Erfolg. Die zweite Abfrage ist
--    das Vollbild und gehört dazu, weil ein leeres Ergebnis oben allein
--    nichts beweist. [leer = Erfolg]
--
-- Q) Leeres Ergebnis = Erfolg: score_total stimmt überall mit der Zahl der
--    gesammelten Fakten überein. Eine Abweichung nach oben heißt entweder
--    gesetzt (E-24) oder gelöscht; die zweite Erklärung fällt erst mit Datei
--    03 weg. Bei der Probe je Stadt ist eine Abweichung ein Hinweis und kein
--    Befund, weil der Backfill vom 07.06.2026 facts.city nach dem Sammeln
--    gesetzt hat. Das ist E-56. [leer = Erfolg]

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

-- ==========================================================================
-- TEIL 4: Abfragen R bis T. NACH Datei 04, 05 und 06.
-- ==========================================================================

-- R) nach Datei 04. Erwartet: unlock_anon false, unlock_auth true,
--    username_anon TRUE (sonst ist die Registrierung stumm kaputt),
--    member_auth true (sonst ist der Gruppenmodus tot), tag_anon false.
--    Zweite Abfrage: erwartet genau drei Zeilen, check_username,
--    get_leaderboard und fact_i18n_langs. Ein leeres Ergebnis dort wäre ein
--    Fehlschlag, weil check_username für anon offen bleiben muss. [X]
--
-- S) nach Datei 05. Erwartet: ins true, upd false, del false, sel true,
--    ins_anon false. Zweite Abfrage: with_check MUSS is_approved nennen.
--    Leeres Ergebnis dort = die Policy fehlt = Fehlschlag. [X]
--
-- T) nach Datei 06. Erwartet: alle sechs Schreibrechte false, beide
--    Leserechte true. [X]
--
-- R, S und T sind auch die Regressionsprobe. Ein späteres
-- "grant all on all tables in schema public to authenticated" macht in einer
-- Zeile alles wieder auf. Wer das merken will, legt sie neben Abfrage F.

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

-- ==========================================================================
-- TEIL 5: Abfragen U bis X. VOR Datei 07a. Ausgabe sichern.
-- ==========================================================================

-- U) Voraussetzung, dieselbe Frage, die der Wächter in Datei 07a stellt, nur
--    lesbar. Erwartet: je Tabelle zwei Zeilen, eine mit USING (true) und eine
--    mit auth.uid(). Fehlt die zweite, Datei 07a NICHT ausführen: Schritt 1
--    würde jedem Nutzer den Blick auf die eigenen Trophäen nehmen. [X]
--
-- V) Wer darf die Leserfunktionen rufen, und welche Fassung steht in der
--    Datenbank? pg_get_function_result ist der Punkt: daran ist ablesbar, ob
--    07a oder 07b schon gelaufen ist. Erwartet vor 07a: get_leaderboard
--    anon_darf = true, und das bleibt auch danach so. get_my_rank
--    anon_darf = false, WENN Datei 04 gelaufen ist; steht dort true, ist
--    Block 4b nie gelaufen, und das ist ein eigener Befund. _city_count fehlt
--    vor 07b, und dass es fehlt, ist der erwartete Zustand. [X]
--
-- W) Genau eine Zeile mit vier Zahlen. Kein Erfolgs- und kein
--    Fehlschlagkriterium, sondern die Zahl für die Support-Antwort:
--    wird_zu_entdecker sind die Konten, denen der angezeigte Name genommen
--    wird, ohne dass ein Pseudonym nachkommt. [Kenntnisnahme]
--
-- X) Die Städtezahl, bevor sie eine Spalte wird. Zwei Schlüssel, die
--    offensichtlich dieselbe Stadt meinen, sind der Beleg für E-56 in den
--    Daten. Ein leeres Ergebnis heißt nur, dass niemand eine Stadtwertung
--    hat. [Kenntnisnahme]

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
--    Erwartet vor 7a: anon_darf = true für get_leaderboard, und das bleibt
--    nach 7a auch so. Der Unterschied ist nicht der Wert, sondern woher er
--    kommt: vorher aus dem PUBLIC-Standard, nachher aus einem ausdrücklichen
--    Grant an anon. Ablesbar ist das nicht an dieser Abfrage, sondern an
--    proacl, deshalb steht sie unten mit dabei.
--    Erwartet vor 7a: anon_darf = false für get_my_rank, WENN Migration 4
--    gelaufen ist. Steht dort true, ist Block 4b nie gelaufen, und das ist ein
--    eigener Befund.
select p.oid::regprocedure                                     as funktion,
       has_function_privilege('anon',          p.oid, 'EXECUTE') as anon_darf,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_darf,
       -- Die Rechteliste im Rohzustand. Steht hier =X/ ohne Empfänger vor dem
       -- Schrägstrich, hält PUBLIC das Recht; steht anon=X/, ist es
       -- ausdrücklich vergeben. Ein null bedeutet "nie angefasst", also der
       -- Standard, also PUBLIC.
       p.proacl                                                 as rechte_roh,
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

-- ==========================================================================
-- TEIL 6: Abfrage Y. NACH Datei 07a.
-- ==========================================================================

-- Y) Die Erwartung ist an zwei Stellen bewusst NICHT "alles dicht", und wer
--    das nicht weiß, rollt eine korrekte Migration zurück.
--      Tabellen: keine Zeile mit ist_public = true. Die Zeilen selbst müssen
--        da sein, je Tabelle die Policy mit auth.uid(); ein leeres Ergebnis
--        wäre ein Fehlschlag.
--      get_leaderboard: anon_darf = true. ABSICHT, Rücknahme vom 02.09.2026.
--      get_my_rank: anon_darf = false, wenn Datei 04 gelaufen ist. Steht hier
--        true, ist das kein Fehlschlag von 07a: das Recht entzieht Block 4b,
--        07a bindet nur den Rumpf.
--    [X]

-- Y) nach Block 7a. Die Erwartung ist an zwei Stellen bewusst NICHT "alles
--    dicht", und wer das nicht weiß, rollt eine korrekte Migration zurück.
--    Erwartet:
--      Tabellen: keine Zeile mit ist_public = true. Beide USING-(true)-Policies
--        sind weg, je Tabelle bleibt genau die Policy mit auth.uid().
--      get_leaderboard: anon_darf = true. ABSICHT, Rücknahme vom 02.09.2026.
--      get_my_rank:     anon_darf = false, WENN Migration 4 gelaufen ist. Das
--        Recht entzieht Block 4b, nicht 7a; 7a bindet nur den Rumpf. Steht hier
--        true, ist das kein Fehlschlag von 7a, sondern der Befund aus Abfrage V.
--        Ohne Konto kommt trotzdem nichts heraus, die Rumpfprüfung wirft 42501.
--        Eine gezielte Frage nach dem Rang einer bestimmten Kennung ist ein
--        Auskunftsdienst über eine andere Person und keine Liste.
--    Zugleich die Regressionsprobe: ein späteres, gut gemeintes
--    "create policy ... using (true)" auf einer der beiden Tabellen macht in
--    einer Zeile die Leseseite wieder auf, und daran ändert die Rücknahme
--    nichts. Sie betrifft die Rangliste, nicht die Tabellen.
select tablename, policyname, cmd, (qual = 'true') as ist_public
  from pg_policies
 where schemaname = 'public'
   and tablename in ('user_trophies', 'user_city_scores')
 order by tablename, policyname;

select p.oid::regprocedure                                     as funktion,
       has_function_privilege('anon',          p.oid, 'EXECUTE') as anon_darf,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_darf,
       p.proacl                                                 as rechte_roh
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('get_leaderboard', 'get_my_rank');

-- ==========================================================================
-- TEIL 7: Abfrage Z. NACH Datei 07b.
-- ==========================================================================

-- Z) Stimmt die Städtezahl, und läuft der Helfer überhaupt? Im SQL-Editor
--    läuft die Abfrage als Eigentümer, also ohne Policy-Grenze: hier steht
--    der wahre Wert. Liefert city_count überall 0, greift für den
--    Funktionseigentümer doch eine Policy, und dann ist die Annahme aus
--    Abfrage N falsch. In dem Fall stehen Datei 03 und Datei 06 auf derselben
--    falschen Annahme, und das ist der größere Befund. Ein leeres Ergebnis
--    heißt nur, dass niemand Punkte hat. [X]

-- Z) nach Block 7b. Stimmt die Städtezahl, und läuft der Helfer überhaupt?
--    NEBENBEI: dass diese Abfrage überhaupt läuft, ist eine Folge der
--    Rücknahme. Im SQL-Editor gibt auth.uid() null zurück, weil kein JWT
--    anliegt; die erste Fassung von 7a hätte hier mit
--    'get_leaderboard: not authenticated' abgebrochen, und die eigene
--    Nachkontrolle wäre nicht ausführbar gewesen. Wer eine Funktion mit
--    Sitzungspflicht prüfen will, braucht dafür einen Client mit Token, nicht
--    den Editor.
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

-- ==========================================================================
-- TEIL 8: Negativtests 1 bis 36 (Dateien 01, 02, 03)
-- ==========================================================================

-- Aus Abschnitt 8 des Dokuments. Format: Nummer, Kürzel, Handlung, dann
-- vorher und danach.
--
-- Zu Datei 01, E-24:
--  1 [W] A setzt username im eigenen Profil
--        vorher: erlaubt                  danach: erlaubt
--  2 [W] A setzt show_real_name im eigenen Profil
--        vorher: erlaubt                  danach: erlaubt
--  3 [F] A setzt coins = 999999 im eigenen Profil
--        vorher: ERLAUBT                  danach: Fehler 42501
--  4 [F] A setzt score_total = 999 im eigenen Profil
--        vorher: ERLAUBT                  danach: Fehler 42501
--  5 [F] A setzt ai_used = 0 im eigenen Profil
--        vorher: vermutlich erlaubt (Befund 4, D-8)
--        danach: Fehler 42501
--  6 [E] A setzt username bei B
--        vorher: abgelehnt                danach: abgelehnt
--        Achtung: das ist ein UPDATE, dessen USING nicht passt. Es kommt
--        KEIN Fehler, sondern null betroffene Zeilen.
--  7 [W] Registrierung: neues Konto, dann username setzen
--        vorher: erlaubt                  danach: erlaubt
--
-- Zu Datei 02, E-06:
--  8 [W] A ruft increment_coins(A, 50)
--        vorher: erlaubt                  danach: erlaubt
--  9 [W] A ruft increment_coins(A, -10)
--        vorher: erlaubt                  danach: erlaubt
-- 10 [F] A ruft increment_coins(B, 5000)
--        vorher: ERLAUBT                  danach: Fehler, foreign account
-- 11 [F] A ruft increment_coins(A, 10000000)
--        vorher: ERLAUBT                  danach: 22003, credit ... exceeds cap
-- 12 [F] Nicht angemeldet, increment_coins
--        vorher: erlaubt, wirkungslos     danach: Fehler, kein EXECUTE
--
-- Zu Datei 03, E-23:
-- 13 [F] A fügt collected_facts(A, 1) ein
--        vorher: ERLAUBT                  danach: Fehler 42501
-- 14 [X] A ruft collect_fact_validated in Reichweite
--        vorher: erlaubt, Trigger feuert  danach: unverändert, Trigger feuert
-- 15 [W] Zu 14: score_total, user_city_scores und user_trophies gewachsen
--        vorher: ja                       danach: JA
--        Der wichtige Test. Läuft er rot, ist die Eigentümer-Annahme falsch
--        und Datei 03 muss zurückgerollt werden.
-- 16 [X] A liest die eigenen collected_facts
--        vorher: erlaubt                  danach: erlaubt
--
-- Zusätzliche Fälle aus D-7 (Deckel) und D-8 (Revoke). Der Ausfallwert 500
-- gilt, solange fact.coins_max_delta nicht gesetzt ist:
-- 17 [F] increment_coins(B, 50), B ist ein fremdes Konto
--        vorher: erlaubt, Coins landen bei B
--        danach: 42501, foreign account, B.coins unverändert
-- 18 [W] increment_coins(null, 50)
--        vorher: schreibt nirgends hin (where id = null)
--        danach: erlaubt, Coins landen bei A
-- 19 [W] increment_coins(A, 270), größter belegter Echtbetrag
--        vorher: erlaubt                  danach: ERLAUBT
-- 20 [W] increment_coins(A, 500), genau der Deckel
--        vorher: erlaubt                  danach: ERLAUBT, Grenze schließt ein
-- 21 [F] increment_coins(A, 501)
--        vorher: erlaubt                  danach: 22003, credit 501 exceeds cap 500
-- 22 [W] increment_coins(A, -20), dritter Kartenhinweis
--        vorher: erlaubt                  danach: ERLAUBT, Saldo sinkt um 20
-- 23 [W] increment_coins(A, -500)
--        vorher: erlaubt                  danach: ERLAUBT, Grenze schließt ein
-- 24 [F] increment_coins(A, -501)
--        vorher: erlaubt                  danach: 22003, debit -501 exceeds cap 500
-- 25 [W] increment_coins(A, -50) bei Saldo 10
--        vorher: Saldo wird -40           danach: Saldo wird 0
--        Das ist die Verhaltensänderung durch greatest(..., 0).
-- 26 [W] fact.coins_max_delta = '800', Projekt neu starten, increment_coins(A, 700)
--        vorher: entfällt                 danach: erlaubt
-- 27 [F] danach increment_coins(A, 801)
--        vorher: entfällt                 danach: 22003, exceeds cap 800
-- 28 [F] reset fact.coins_max_delta, Neustart, increment_coins(A, 700)
--        vorher: entfällt                 danach: 22003, exceeds cap 500
--        ENTSCHEIDEND: fehlende Einstellung heißt nicht "kein Deckel".
-- 29 [W] fact.coins_max_delta = 'abc', Neustart, increment_coins(A, 50)
--        vorher: entfällt                 danach: erlaubt, es gilt 500
-- 30 [F] zu 29: increment_coins(A, 700)
--        vorher: entfällt                 danach: 22003, exceeds cap 500
--        ENTSCHEIDEND: geht 28 oder 30 durch, existiert der Deckel nur auf
--        dem Papier.
-- 31 [F] A setzt ai_used = 0 per update profiles auf dem eigenen Profil
--        vorher: ERLAUBT, LLM-Kontingent zurückgesetzt   danach: 42501
-- 32 [F] A setzt ai_limit = 9999 auf dem eigenen Profil
--        vorher: ERLAUBT                  danach: 42501
-- 33 [F] A schreibt insert into profiles (id, ai_used) ... on conflict do update
--        vorher: erlaubt                  danach: 42501
-- 34 [F] A löscht die eigene profiles-Zeile
--        vorher: erlaubt                  danach: 42501
-- 35 [F] anon: update profiles set ai_used = 0
--        vorher: scheitert an der Policy, nicht am Recht   danach: 42501
-- 36 [W] A ruft die Edge Function llm elfmal, Limit ist 10
--        vorher: elfter Aufruf scheitert, danach per update zurücksetzbar
--        danach: elfter Aufruf scheitert und BLEIBT gescheitert
--        Kostet echte Anthropic-Aufrufe. Gehört in eine Testumgebung mit
--        eigenem Schlüssel oder ist bewusst auszulassen; 31 bis 35 decken den
--        Mechanismus ab.

-- ==========================================================================
-- TEIL 9: Negativtests 37 bis 63 (Dateien 04, 05, 06)
-- ==========================================================================

-- Aus Abschnitt 11.8 des Dokuments.
--
-- Zu Datei 04, E-52:
-- 37 [F] A ruft unlock_trophy(B, 'legende')
--        vorher: ERLAUBT, B hat die Trophäe   danach: 42501, foreign account
-- 38 [W] A ruft unlock_trophy(A, 'nachtschwärmer')
--        vorher: erlaubt                  danach: ERLAUBT, Umlaut bleibt zulässig
-- 39 [W] A ruft unlock_trophy(null, 'kommentator')
--        vorher: Fehler, user_id ist NOT NULL   danach: erlaubt, landet bei A
-- 40 [F] anon ruft unlock_trophy(A, 'legende')
--        vorher: ERLAUBT, A hat die Trophäe     danach: Fehler, kein EXECUTE
-- 41 [F] A ruft unlock_trophy(A, <65 Zeichen>)
--        vorher: erlaubt, Zeile wird geschrieben  danach: Fehler 22023
-- 42 [X] anon ruft check_username('irgendwas')
--        vorher: erlaubt                  danach: ERLAUBT
--        DER WICHTIGSTE NICHTBRUCH-TEST. Ein Fehlschlag heißt: die
--        Registrierung ist in beiden Clients stumm beschädigt.
-- 43 [X] A liest group_sessions einer eigenen Sitzung
--        vorher: erlaubt                  danach: ERLAUBT
--        Belegt, dass _is_group_member noch ausführbar ist.
-- 44 [W] A fährt eine Gruppensitzung durch: anlegen, starten, sammeln
--        vorher: erlaubt                  danach: ERLAUBT
-- 45 [F] anon ruft create_group_session(...)
--        vorher: Fehler not_authenticated aus dem Rumpf
--        danach: 42501, kein EXECUTE (äußere Grenze statt Rumpfprüfung)
-- 46 [F] anon ruft get_my_rank(B, 'global', 'weekly')
--        vorher: liefert eine Zahl        danach: Fehler, kein EXECUTE
-- 47 [F] A ruft _haversine_m(48.5, 13.4, 48.6, 13.5)
--        vorher: erlaubt                  danach: Fehler, kein EXECUTE
-- 48 [X] anon ruft get_leaderboard('global','weekly')
--        vorher: erlaubt                  danach: ERLAUBT, unverändert
--        Bleibt auch nach Datei 07a gültig, nur die Begründung ändert sich:
--        nicht mehr "E-16 bleibt offen", sondern "die Rangliste ist ohne
--        Konto sichtbar, so entschieden".
--
-- Zu Datei 05, E-53:
-- 49 [W] A fügt einen Fakt genau wie api.jsx:165-177 ein
--        vorher: erlaubt                  danach: ERLAUBT (Nichtbruch)
-- 50 [F] A fügt einen Fakt mit is_approved: true ein
--        vorher: ERLAUBT, sofort für alle sichtbar   danach: Fehler 42501
--        WITH-CHECK-Verletzung beim INSERT, also ein Fehler und nicht null
--        Zeilen.
-- 51 [W] A fügt einen Fakt ohne is_approved ein
--        vorher: erlaubt, Default false   danach: ERLAUBT
-- 52 [W] A fügt einen Fakt mit is_approved: null ein
--        vorher: erlaubt   danach: ERLAUBT, unsichtbar und moderierbar
-- 53 [F] A fügt einen Fakt mit created_by: B ein
--        vorher: abgelehnt                danach: abgelehnt
-- 54 A ändert titel seines eigenen Fakts
--        vorher [E]: abgelehnt, keine UPDATE-Policy, also null Zeilen ohne
--                    Fehler
--        danach [F]: abgelehnt, jetzt zusätzlich ohne Recht, also 42501
--        Die Fehlerklasse wechselt. Das ist der Unterschied aus 14.5 in einem
--        einzigen Test.
-- 55 [X] A liest den eigenen, nicht freigegebenen Fakt (.select() am Insert)
--        vorher: erlaubt                  danach: ERLAUBT
-- 56 [F] Nur wenn Block 5b lief: A fügt einen Fakt mit rating: 5 ein
--        vorher: erlaubt                  danach: Fehler 42501
--        5b ist in Datei 05 NICHT enthalten, dieser Test entfällt also.
--
-- Zu Datei 06, E-55:
-- 57 [F] A setzt user_city_scores.score = 9999 in der eigenen Zeile
--        vorher: ERLAUBT                  danach: Fehler 42501
-- 58 [F] A fügt user_city_scores(A, 'rom', 9999) ein
--        vorher: ERLAUBT                  danach: Fehler 42501
-- 59 [F] A fügt user_trophies(A, 'legende') direkt ein
--        vorher: ERLAUBT                  danach: Fehler 42501
-- 60 [F] A löscht eine eigene user_trophies-Zeile
--        vorher: ERLAUBT                  danach: Fehler 42501
-- 61 [W] A ruft unlock_trophy(A, 'kommentator')
--        vorher: erlaubt                  danach: ERLAUBT, Definer-Weg bleibt
-- 62 [W] A sammelt einen Fakt; score_total, user_city_scores und
--        user_trophies wachsen
--        vorher: ja                       danach: JA
--        ENTSCHEIDEND: ein Fehlschlag heißt, die Eigentümer-Annahme aus
--        Abfrage N war falsch und Datei 06 ist zurückzurollen.
-- 63 [X] A liest die Trophäen von B
--        vorher: erlaubt                  danach: ERLAUBT, unverändert
--        Gilt nur bis Datei 07a. Danach ersetzt Test 66 ihn, und die
--        Erwartung dreht sich auf null Zeilen.

-- ==========================================================================
-- TEIL 10: Negativtests 64 bis 82 (Dateien 07a und 07b)
-- ==========================================================================

-- Aus Abschnitt 14.5 des Dokuments. Die Warnung von oben gilt hier am
-- stärksten: 66, 68 und 70 sind erfolgreich, wenn NICHTS kommt.
--
-- Zu Datei 07a:
--  64 [X] anon ruft get_leaderboard('global','weekly')
--         vorher: erlaubt, zehn Zeilen    danach: ERLAUBT, zehn Zeilen
--         Der Test zur Rücknahme vom 02.09.2026. Ein Fehlschlag stellt genau
--         den Zustand her, den sie verhindern soll: eine leere Rangliste für
--         jeden Besucher ohne Konto, die wie ein Fehler aussieht.
--  64a[X] anon ruft get_leaderboard, B hat show_real_name = true
--         vorher: anon sieht den ECHTEN NAMEN von B
--         danach: anon sieht den Username von B
--         Der einzige Test, der die Wirkung von 07a für einen anonymen
--         Aufrufer überhaupt zeigt.
--  65 [X] A ruft get_leaderboard('global','weekly')
--         vorher: erlaubt   danach: ERLAUBT, vier Spalten wie bisher
--  66 [E] A liest user_trophies von B
--         vorher: erlaubt, alle Zeilen    danach: NULL ZEILEN, KEIN FEHLER
--         Kernfall E-16. Ersetzt Test 63.
--  67 [X] A liest die eigenen user_trophies genau wie api.jsx:80
--         vorher: erlaubt                 danach: ERLAUBT
--         Der riskanteste Nichtbruch-Test: ein Fehlschlag heißt, jeder Nutzer
--         sieht eine leere Trophäenreihe.
--  68 [E] A liest user_city_scores von B
--         vorher: erlaubt                 danach: NULL ZEILEN, KEIN FEHLER
--  69 [X] A liest die eigenen user_city_scores
--         vorher: erlaubt                 danach: ERLAUBT
--  70 [E] anon liest user_trophies ohne Filter
--         vorher: erlaubt, die ganze Tabelle   danach: NULL ZEILEN, KEIN FEHLER
--         Das ist die Begründung dafür, dass SELECT für anon nicht entzogen
--         wird: ein Revoke machte aus dem leeren Ergebnis einen Fehler.
--  71 [F] A ruft get_my_rank(B, 'global', 'weekly')
--         vorher: LIEFERT DEN RANG VON B  danach: 42501, foreign account
--  72 [X] A ruft get_my_rank(A, 'global', 'weekly')
--         vorher: erlaubt                 danach: ERLAUBT
--  73 [X] A ruft get_my_rank(null, 'global', 'weekly')
--         vorher: liefert einen Rang, gerechnet auf Punktestand 0
--         danach: erlaubt, liefert den Rang von A
--  74 [X] B setzt show_real_name = true, dann ruft A get_leaderboard
--         vorher: A sieht den echten Namen von B
--         danach: A sieht den Username von B
--  75 [X] B hat show_real_name = true und KEINEN Username, A ruft get_leaderboard
--         vorher: A sieht den echten Namen von B   danach: A sieht 'Entdecker'
--         Der unangenehme Fall aus Abfrage W.
--  76 [W] A sammelt einen Fakt und die Trophäen wachsen
--         vorher: ja                      danach: JA
--         Ein Fehlschlag heißt: die Eigentümer-Annahme aus Abfrage N ist
--         falsch, und dann sind auch Datei 03 und Datei 06 zurückzurollen.
--
-- Zu Datei 07b:
--  77 [X] A ruft get_leaderboard und sieht sich in den Top 10
--         vor 7b: row.user_id ist die eigene Kennung
--         danach: row.user_id FEHLT, row.is_me ist true
--  78 [X] A ruft get_leaderboard und B steht darin
--         vor 7b: row.user_id ist die Kennung von B
--         danach: row.is_me ist false, keine Kennung
--  79 [X] A hat Fakten in München, Regensburg und einen ohne city
--         vor 7b: Städtezahl gibt es nicht
--         danach: city_count ist 2, nicht 3 ('unknown' ist keine Stadt)
--  80 [X] B hat keinen Username und steht in den Top 10
--         vor 7b: display_name ist 'Entdecker'
--         danach: display_name ist null, der Client übersetzt
--  81 [X] anon ruft get_leaderboard
--         vor 7b: erlaubt (Zustand nach 07a)
--         danach: erlaubt, mit den fünf neuen Spalten
--         Dieser Test SCHEITERT NICHT, wenn Schritt 3 fehlt, weil dann das
--         PUBLIC-Recht greift. Ob das Recht aus einem Beschluss oder einem
--         Standard kommt, sagt proacl in Abfrage Y.
--  81a[X] anon ruft get_leaderboard und liest is_me
--         vor 7b: die Spalte existiert nicht
--         danach: is_me ist FALSE in jeder Zeile, nicht null
--         Ohne das (p.id = v_uid) is true käme null, und ein Dart-as-bool
--         würde werfen.
--  82 [F] A ruft _city_count(B) direkt
--         vor 7b: die Funktion existiert nicht  danach: Fehler, kein EXECUTE
