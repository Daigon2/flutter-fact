-- ##########################################################################
-- FACT-Backend, Datei 07a von 8: E-16, die Leseseite
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitt 14.2,
-- Migration 7a. Wörtlich übernommen.
--
-- SCHLIESST
--   E-16, erste Hälfte. Die beiden USING-(true)-Policies auf
--   user_city_scores und user_trophies fallen, get_leaderboard gibt nur noch
--   den Username aus (kein echter Name mehr) und bekommt search_path,
--   get_my_rank wird an das eigene Konto gebunden. Eine Kontokennung
--   schließt danach nichts mehr auf. Die Rangliste bleibt ausdrücklich auch
--   ohne Anmeldung sichtbar, das ist die Rücknahme vom 02.09.2026.
--
-- PWA DANACH
--   Nichts hört auf zu funktionieren. Zwei sichtbare Änderungen:
--     bei einem Konto mit show_real_name = true steht in der Rangliste ab
--       jetzt der Username statt des echten Namens (Konten ohne Username
--       heißen dort 'Entdecker');
--     der Schalter "Echten Namen zeigen" (screen-profil.jsx:693) speichert
--       danach einen Wert, den niemand mehr liest. Ein Schalter, der lügt,
--       ist schlechter als keiner: er gehört im PWA-Repository aus der
--       Oberfläche, und das ist kein Migrationsauftrag.
--   Fremde Trophäen und fremde Stadtpunktestände liefern ab jetzt null
--   Zeilen ohne Fehler, weil eine Policy abweist und nicht ein fehlendes
--   Recht.
--
-- VORHER PRÜFEN (99-pruefungen.sql)
--   Abfragen U, V, W und X, dazu N. U ist die Voraussetzung: fehlt auf einer
--   der beiden Tabellen eine Policy für den eigenen Zugriff, nicht
--   ausführen. Der Block prüft das selbst und bricht mit eigener Meldung ab.
--   W sagt, wie viele Konten ihren angezeigten Namen verlieren;
--   wird_zu_entdecker ist der unangenehme Fall.
--
-- NACHHER PRÜFEN
--   Abfrage Y. Erwartet: keine Zeile mit ist_public = true, und
--   get_leaderboard anon_darf = true. Das true ist Absicht und kein Fehler.
--   Negativtests 64, 64a und 65 bis 76. 66, 68 und 70 sind bestanden, wenn
--   null Zeilen kommen und kein Fehler; 67 ist der riskanteste
--   Nichtbruch-Test, 64a der einzige, der die Wirkung für einen anonymen
--   Aufrufer überhaupt zeigt.
--
-- IDEMPOTENZ
--   Ja. Der Wächter am Anfang akzeptiert beide Policy-Zustände, drop policy
--   if exists und create or replace function sind wiederholbar. Das notify
--   am Ende steht schon im Dokument.
-- ##########################################################################

-- ============================================================================
-- FACT — E-16: Rangliste und Trophäen sind für jeden lesbar
-- ----------------------------------------------------------------------------
-- Ist-Zustand: supabase-schema.sql:213 und :223 (USING (true) beim SELECT),
-- dazu get_leaderboard (:365-441) ohne Sitzungsprüfung und mit EXECUTE für
-- PUBLIC, weil im ganzen 03_Backend/ keine Rechtezeile für sie existiert.
--
-- Entscheidung vom 02.09.2026 (REBUILD_STATUS.md, J-B), einschließlich der
-- Rücknahme vom selben Tag:
--   Rang, Punktestand und Anzahl der Städte, keine Städtenamen;
--   nur ein Username, kein echter Name;
--   die Rangliste bleibt AUCH OHNE ANMELDUNG sichtbar. Der Eigentümer:
--   "dann sieht man halt doch die Rangfolge und die Coins etc. passt schon
--   auch wenn man nicht angemeldet ist. bevor das aussieht wie ein Fehler."
--
-- Bricht heute nichts, und zwar für niemanden. Erhebung in 14.0, Frage 2 und 3:
--   kein Client liest fremde Zeilen aus einer der beiden Tabellen;
--   api.jsx:80 und :234-240 filtern auf die eigene Kennung;
--   user_city_scores liest überhaupt kein Client direkt;
--   die Rückgabe von get_leaderboard behält alle vier Spalten;
--   ein Besucher ohne Konto sieht die Rangliste weiter. Das ist der Punkt der
--   Rücknahme: die PWA hat vor dem Profilbildschirm keine Anmeldeschranke
--   (route === 'profil' wird ohne Sitzung gerendert, app.jsx:1059; requireAuth
--   in app.jsx:541 sichert nur schreibende Aktionen), eine leere Rangliste
--   hätte dort wie ein Fehler ausgesehen.
--
-- WAS DIESER BLOCK NICHT ANFASST:
--   die Rückgabespalten von get_leaderboard -> Block 7b, weil
--     screen-profil.jsx:88, :103 und :117 alle vier Spalten lesen;
--   die Städtezahl -> Block 7b, weil eine neue Spalte den Rückgabetyp ändert;
--   die drei Stadtschlüssel-Normalisierungen -> E-56, Abschnitt 12;
--   handle_fact_collected -> die dortige Zählung ist falsch (14.0, Frage 4),
--     aber sie entscheidet über eine Trophäe und damit über eine Spielregel;
--   das SELECT-Recht der Rolle anon auf den beiden Tabellen, Begründung unten;
--   das Ausführrecht von anon auf get_leaderboard. Es BLEIBT, siehe Schritt 3.
--
-- WAS OFFEN BLEIBT, WEIL DIE RANGLISTE OHNE KONTO LESBAR IST:
--   Solange nur dieser Block gelaufen ist, gibt get_leaderboard weiter
--   Kontokennungen an anon heraus, bis zu zehn je Stadt und Zeitraum. Diese
--   Kennungen schließen danach nichts mehr auf, aber sie sind einsammelbar.
--   Deshalb ist Block 7b nach der Rücknahme kein Nachklapp mehr, sondern die
--   zweite Hälfte der Behebung. Einordnung in 14.1.
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

-- 2. get_leaderboard: echten Namen entfernen, search_path setzen. KEINE
--    Sitzungsprüfung, das ist die Rücknahme vom 02.09.2026. Reines
--    create or replace, der Rückgabetyp bleibt Wort für Wort gleich
--    (rank, user_id, display_name, score). Die vier Zweige und die Sortierung
--    sind unverändert aus supabase-schema.sql:365-441 übernommen,
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
  -- Hier stand in der ersten Fassung eine Prüfung auf auth.uid(). Sie ist mit
  -- der Rücknahme vom 02.09.2026 weg, und zwar bewusst ohne Ersatz: die
  -- Rangliste ist eine Top-10-Liste und keine Auskunft über eine bestimmte
  -- Person. Die gezielte Frage nach dem Rang EINER Kennung ist get_my_rank,
  -- und die bleibt an das Konto gebunden, siehe Schritt 4.
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

-- 3. Ausführrechte: anon behält sie. Das ist die Rücknahme, und es ist die
--    einzige Stelle des Blocks, die sie berührt.
--    Trotzdem nicht "nichts tun": EXECUTE steht heute per PostgreSQL-Standard
--    an PUBLIC, weil im ganzen 03_Backend/ keine Rechtezeile für diese
--    Funktion existiert. Ein Recht an PUBLIC ist kein Beschluss, sondern ein
--    Standard, den niemand gewählt hat, und es gilt auch für jede Rolle, die
--    diese Datenbank künftig bekommt. Die zwei Empfänger, die es geben soll,
--    stehen deshalb ausdrücklich da. Gleiche Bauform wie
--    check_username in Block 4b, Schritt 3, und aus demselben Grund: wäre der
--    Standard hier je angefasst worden, wäre die Rangliste stumm leer.
--    service_role ist davon nicht betroffen, Supabase vergibt dessen Rechte je
--    Rolle und nicht über PUBLIC (siehe Block 4b).
revoke all     on function public.get_leaderboard(text, text) from public;
grant  execute on function public.get_leaderboard(text, text) to anon, authenticated;

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
