-- Der Ist-Zustand der laufenden Datenbank, abgefragt statt gedumpt.
--
-- ## Warum diese Datei existiert
--
-- `docs/operations/backend-inventory.md`, Abschnitt 2, hält fest: es gibt kein
-- Migrationssystem. Kein Supabase-CLI-Projekt, keine Ledger-Tabelle, jede
-- Migrationsdatei traegt im Kopf "Run manually in Supabase SQL Editor", und
-- zwei Funktionen sind doppelt definiert. **Aus dem Repository ist deshalb
-- nicht zu sehen, was in der Datenbank steht.** Jede Migration, die vorher
-- keinen Ist-Zustand kennt, flickt eine Vermutung.
--
-- Der erste Vorschlag dafuer war `pg_dump --schema-only`. Das ist am
-- 02.09.2026 an der Wirklichkeit gescheitert: `pg_dump` ist auf dem Rechner
-- des Eigentuemers nicht installiert, und die Befehlszeile war ausserdem in
-- Bash-Syntax geschrieben, waehrend dort PowerShell laeuft.
--
-- Diese Datei ist der Ersatz und in zwei Punkten besser. Sie braucht **keine
-- Installation**, weil sie im SQL-Editor von Supabase laeuft. Und sie verlangt
-- **kein Passwort und keine Verbindungszeichenfolge**, weil der Editor bereits
-- angemeldet ist.
--
-- ## Wie du sie benutzt
--
-- Jede Abfrage einzeln in den SQL-Editor, ausfuehren, Ergebnis ueber
-- "Download CSV" sichern. Acht Dateien, danach ist der Stand bekannt.
--
-- **Alle Abfragen sind rein lesend.** Kein `insert`, kein `update`, kein
-- `alter`, kein `drop`. Sie fassen ausschliesslich Systemkataloge an.
--
-- **Schick keine Zugangsdaten mit.** Die Ergebnisse enthalten Schema und
-- Rechte, das ist genau das Gewuenschte. Die Verbindungszeichenfolge, den
-- `service_role`-Schluessel und das Datenbankpasswort braucht niemand, und sie
-- gehoeren in keine Datei und in keinen Chat.
--
-- ## Was jede Abfrage klaert
--
-- 1 und 2 sagen, welche Tabellen und Spalten es gibt und wo RLS ueberhaupt
--   eingeschaltet ist. Ohne 1 ist bei Migration 6 nicht entscheidbar, ob die
--   Vorbedingung haelt.
-- 3 ist die Wahrheit ueber die Policies. Die Befunde E-24, E-23, E-53 und E-55
--   haengen alle daran, und die Migrationsdateien im Monorepo sind dafuer nur
--   eine Absichtserklaerung.
-- 4 loest E-21: welche Fassung der doppelt definierten Funktionen laeuft
--   wirklich. Das ist die Abfrage mit dem groessten Ertrag.
-- 5 loest E-52. Sie ersetzt die Anweisung, die in der Bestandsaufnahme stand:
--   `information_schema.role_routine_grants` zeigt Rechte, die an die
--   Pseudorolle PUBLIC vergeben sind, **gar nicht an**, und genau die sind der
--   Befund. `has_function_privilege` sieht sie.
-- 6 dasselbe fuer Tabellenrechte, aus demselben Grund ueber
--   `has_table_privilege` statt ueber `information_schema`.
-- 7 loest den korrigierten Teil von E-54: das `UNIQUE (session_id, fact_id)`
--   ist am 05.06.2026 gedroppt und durch zwei partielle Indizes ersetzt worden.
--   Was davon wirklich steht, sagt nur diese Abfrage.
-- 8 zeigt die Trigger. `handle_fact_collected` bucht Punkte, Stadtwertung und
--   Trophaeen, und Migration 6 darf ihn nicht aussperren.


-- ── 1. Tabellen, und wo RLS an ist ──────────────────────────────────────────
select c.relname                as tabelle,
       c.relrowsecurity         as rls_an,
       c.relforcerowsecurity    as rls_erzwungen
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
order by c.relname;


-- ── 2. Spalten ──────────────────────────────────────────────────────────────
select table_name   as tabelle,
       ordinal_position as position,
       column_name  as spalte,
       data_type    as typ,
       is_nullable  as nullbar,
       column_default as vorgabe
from information_schema.columns
where table_schema = 'public'
order by table_name, ordinal_position;


-- ── 3. Policies, im Wortlaut ────────────────────────────────────────────────
-- `qual` ist die USING-Bedingung, `with_check` die WITH CHECK-Bedingung. Eine
-- Policy mit `with_check` gleich null bei cmd ALL oder INSERT ist der Befund
-- aus E-24 und E-53.
select tablename  as tabelle,
       policyname as policy,
       cmd        as befehl,
       roles      as rollen,
       qual       as using_bedingung,
       with_check as with_check_bedingung
from pg_policies
where schemaname = 'public'
order by tablename, policyname;


-- ── 4. Funktionen samt Definition, loest E-21 ───────────────────────────────
-- `prokind = 'f'` grenzt auf normale Funktionen ein; fuer Aggregate und
-- Fensterfunktionen wuerde `pg_get_functiondef` scheitern.
--
-- Zwei Funktionen sind im Monorepo doppelt definiert (`start_group_session`,
-- `_team_generate_orders`). Kommt ein Name hier zweimal mit **derselben**
-- Argumentliste vor, ist das unmoeglich, dann steht in der Datenbank genau
-- eine Fassung, und diese Abfrage sagt welche.
select p.proname                                       as funktion,
       pg_get_function_identity_arguments(p.oid)        as argumente,
       p.prosecdef                                      as security_definer,
       p.proconfig                                      as konfiguration,
       pg_get_functiondef(p.oid)                        as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
order by p.proname, pg_get_function_identity_arguments(p.oid);


-- ── 5. Ausfuehrrechte je Rolle, loest E-52 ──────────────────────────────────
-- Ueber `has_function_privilege` und nicht ueber `information_schema`, weil
-- das an PUBLIC vergebene Rechte verschweigt. `anon` gleich true bei einer
-- schreibenden Funktion ist der Befund.
select p.proname                                as funktion,
       pg_get_function_identity_arguments(p.oid) as argumente,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_role
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
order by p.proname, pg_get_function_identity_arguments(p.oid);


-- ── 6. Tabellenrechte je Rolle ──────────────────────────────────────────────
-- Aus demselben Grund ueber `has_table_privilege`. Ein `insert` oder `update`
-- fuer `anon` oder `authenticated` auf `user_trophies` oder
-- `user_city_scores` ist der Befund aus E-55.
select c.relname                                        as tabelle,
       r.rolname                                        as rolle,
       pr.recht,
       has_table_privilege(r.rolname, c.oid, pr.recht)  as erlaubt
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE')) as pr(recht)
cross join (
  select rolname from pg_roles where rolname in ('anon', 'authenticated')
) r
where n.nspname = 'public'
  and c.relkind = 'r'
order by c.relname, r.rolname, pr.recht;


-- ── 7. Indizes und Zwaenge, loest den Teil von E-54 ─────────────────────────
select tablename as tabelle,
       indexname as index,
       indexdef  as definition
from pg_indexes
where schemaname = 'public'
order by tablename, indexname;


-- ── 8. Trigger ──────────────────────────────────────────────────────────────
select c.relname                    as tabelle,
       tg.tgname                    as trigger,
       pg_get_triggerdef(tg.oid)    as definition
from pg_trigger tg
join pg_class c on c.oid = tg.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and not tg.tgisinternal
order by c.relname, tg.tgname;
