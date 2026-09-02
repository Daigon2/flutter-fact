-- ##########################################################################
-- FACT-Backend, Datei 04 von 8: E-52, unlock_trophy und die Ausführrechte
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitt 11.4,
-- Blöcke 4a und 4b. Wörtlich übernommen.
--
-- SCHLIESST
--   E-52. Block 4a bindet unlock_trophy an das eigene Konto und prüft die
--   Schlüssellänge; die Signatur behält p_user_id, der Wert wird nur nicht
--   mehr geglaubt. Block 4b setzt die Ausführrechte für den ganzen Bestand:
--   schreibende RPCs nur für authenticated, interne Helfer für keinen
--   Client, check_username ausdrücklich auch für anon.
--
-- NICHT ENTHALTEN
--   Block 4c, die parameterfreie Fassung von unlock_trophy. Sie liegt bewusst
--   ungenutzt in Abschnitt 11.4 des Dokuments und läuft erst, wenn ein Client
--   sie ruft. Sie hier mitzuführen hieße, eine zweite Rechtefläche
--   anzulegen, die niemand braucht.
--
-- PWA DANACH
--   Nichts hört auf zu funktionieren: api.jsx:243 übergibt immer die eigene
--   userId. Was aufhört: ohne Konto (anon) ist keine der aufgeführten
--   Funktionen mehr rufbar, darunter get_my_rank, tag_endpoint und die
--   Gruppen- und Team-RPCs. Die internen Helfer (_haversine_m, _slugify und
--   die drei anderen) sind für keinen Client mehr rufbar. _is_group_member
--   bleibt bewusst frei, sonst stünde der Gruppenmodus still.
--
-- VORHER PRÜFEN (99-pruefungen.sql)
--   Abfragen K und L. K sagt, welche Rolle heute welche Funktion rufen darf.
--   L sagt, ob eine der doppelt definierten Funktionen (E-21) unter zwei
--   Signaturen in der Datenbank steht; L1 bleibt bei gleicher Signatur leer,
--   ein leeres L1 ist deshalb kein Ergebnis. L2 ist die eigentliche Prüfung.
--
-- NACHHER PRÜFEN
--   Abfrage R. Erwartet: unlock_trophy anon false und authenticated true,
--   check_username anon true, _is_group_member authenticated true. Die zweite
--   Abfrage in R muss genau check_username, get_leaderboard und
--   fact_i18n_langs zeigen. Negativtests 37 bis 48. Der wichtigste ist 42,
--   weil ein Fehlschlag die Registrierung in beiden Clients stumm beschädigt;
--   43 und 44 halten den Gruppenmodus.
--
-- IDEMPOTENZ
--   Ja. create or replace function, und die Rechte werden in Schleifen über
--   pg_proc gesetzt statt über eine Liste von Signaturen. Jeder angefasste
--   und jeder fehlende Name kommt als NOTICE zurück; das Editor-Protokoll ist
--   Teil des Ergebnisses. Das notify am Ende steht schon im Dokument.
-- ##########################################################################

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
