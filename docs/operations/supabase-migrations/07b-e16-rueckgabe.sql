-- ##########################################################################
-- FACT-Backend, Datei 07b von 8: E-16, die Rückgabe von get_leaderboard
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitt 14.3,
-- Migration 7b, samt dem Helfer _city_count aus demselben Abschnitt.
-- Wörtlich übernommen; der Helfer steht vor Schritt 1, so wie das Dokument
-- es anweist ("Vor Schritt 1 einfügen").
--
-- SCHLIESST
--   E-16, zweite Hälfte, und nach der Rücknahme vom 02.09.2026 ist das die
--   eigentliche Behebung: user_id fällt aus der Rückgabe, is_me kommt,
--   city_count kommt, und das deutsche 'Entdecker' fällt weg, display_name
--   wird für Konten ohne Username null. Ohne 7b sind Kontokennungen weiter
--   ohne Konto einsammelbar, zehn je Stadt und Zeitraum.
--
-- VORAUSSETZUNG
--   Datei 07a ist gelaufen. Dieser Block ersetzt deren Schritt 1 nicht, die
--   beiden Policies fallen dort und nicht hier.
--
-- PWA DANACH: BRICHT screen-profil.jsx AN DREI STELLEN, ALLE DREI STILL
--   Zeile 88:  String(row.user_id) === String(userId) ist immer false, die
--              eigene Zeile wird nicht mehr hervorgehoben. Nötig ist
--              row.is_me === true.
--   Zeile 103: {row.display_name} bleibt für Konten ohne Username leer, weil
--              der Server jetzt null liefert statt 'Entdecker'.
--   Zeile 117: !rows.some(r => String(r.user_id) === String(userId)) ist
--              immer true, der eigene Rang wird unten angehängt, obwohl er
--              in der Liste steht. Nötig ist !rows.some(r => r.is_me).
--   Die Sperre für diesen Block ist am 02.09.2026 gefallen, weil die PWA
--   nicht live läuft; der Bruch ist in Kauf genommen statt aufgeschoben. Das
--   Dokument hält die Aufhebung in 14.1, in der Überschrift von 14.3 und im
--   Blockkommentar unten fest.
--
-- OFFENE KLEINIGKEIT, HIER NICHT ERFUNDEN
--   Für Konten ohne Username braucht der Client einen Ersatztext. Der
--   Wortlaut ist eine Inhaltsfrage und im Dokument (14.7) offen. Der
--   i18n-Schlüssel dafür existiert in der PWA nicht, und ein ||-Rückfall
--   hinter t() kann nicht feuern, weil t() bei fehlendem Schlüssel den
--   Schlüssel selbst zurückgibt. Das ist E-63. Diese Frage blockiert seit
--   dem 02.09.2026 nicht mehr die Migration, sondern den PWA-Release: eine
--   leere Zeile in der Rangliste erreicht niemanden, solange die PWA nicht
--   live ist.
--
-- VORHER PRÜFEN (99-pruefungen.sql)
--   Abfrage V: pg_get_function_result sagt, welche Fassung in der Datenbank
--   steht, also ob 7a oder 7b schon gelaufen ist. Abfrage X zeigt, wie stark
--   'unknown' die neue Spalte betrifft.
--
-- NACHHER PRÜFEN
--   Abfrage Z. Liefert city_count überall 0, ist nicht der Helfer das
--   Problem, sondern die Eigentümer-Annahme aus Abfrage N, und dann stehen
--   die Dateien 03 und 06 auf derselben falschen Annahme. Negativtests 77
--   bis 82, dazu 81a: is_me muss false sein und nicht null.
--
-- IDEMPOTENZ
--   Ja. drop function if exists vor create function, create or replace beim
--   Helfer, wiederholbare revoke und grant. Der drop ohne cascade ist
--   Absicht: steckt get_leaderboard in einer unbekannten Abhängigkeit,
--   bricht der Block ab statt sie mitzunehmen. Das notify am Ende steht
--   schon im Dokument.
-- ##########################################################################

-- ============================================================================
-- FACT — E-16, zweiter Teil: die Rückgabe von get_leaderboard
-- ----------------------------------------------------------------------------
-- BRECHENDE ÄNDERUNG für 02_Frontend/app/screen-profil.jsx:88, :103 und :117,
-- und an allen drei Stellen still. Aufstellung in 14.6.
-- Bis zum 02.09.2026 galt deshalb "erst nach dem PWA-Release ausführen".
-- AUFGEHOBEN AM 02.09.2026: der Eigentümer hat festgestellt, dass die PWA
-- nicht live läuft und ein Ausfall dort in Kauf genommen ist. Der PWA-Release,
-- der auf is_me umstellt, bleibt nötig, blockiert diesen Block aber nicht mehr.
--
-- VORAUSSETZUNG: Block 7a ist gelaufen. Dieser Block ersetzt Schritt 1 aus 7a
-- nicht: die beiden Policies sind dort gefallen, nicht hier.
--
-- OHNE ANMELDUNG WEITER SICHTBAR, wie in 7a. Es gibt hier keine
-- Sitzungsprüfung, und anon behält das Ausführrecht.
--
-- WARUM DROP UND NICHT CREATE OR REPLACE: eine neue Spalte in returns table
-- ändert den Rückgabetyp, und den kann create or replace nicht ändern (42P13).
-- Ein drop function nimmt alle Ausführrechte mit, und ein frisch angelegtes
-- Funktionsobjekt trägt wieder EXECUTE für PUBLIC. Schritt 3 unten ist deshalb
-- nicht Wiederholung, sondern Pflicht: sonst hängt das Recht von anon wieder an
-- einem Standard statt an einem Beschluss, und das Recht von PUBLIC wäre
-- zurück.
-- ============================================================================

begin;

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
  -- Ohne Sitzung ist v_uid null. Das ist kein Fehlerfall, sondern der
  -- Normalfall eines Besuchers ohne Konto: er bekommt die Liste, und is_me ist
  -- für jede Zeile false. Siehe den Hinweis zum Dreiwerte-Vergleich unten.
  v_uid uuid := auth.uid();
begin
  if p_period = 'weekly' then
    if p_city = 'global' then
      return query
        select
          row_number() over (order by count(*) desc)::bigint,
          (p.id = v_uid) is true,
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
          (p.id = v_uid) is true,
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
          (p.id = v_uid) is true,
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
          (p.id = v_uid) is true,
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

-- 3. Ausführrechte neu setzen, identisch zu Schritt 3 in 7a. Der drop hat sie
--    mitgenommen, und das create hat EXECUTE wieder an PUBLIC vergeben. Wer
--    diese zwei Zeilen vergisst, bricht nichts: anon kommt über das
--    PUBLIC-Recht weiter durch, die Rangliste läuft, und niemand merkt es.
--    Genau deshalb stehen sie hier. Der Unterschied ist nicht das Ergebnis für
--    heute, sondern dass danach im Katalog steht, WER rufen darf, statt dass es
--    aus einem Standard folgt.
revoke all     on function public.get_leaderboard(text, text) from public;
grant  execute on function public.get_leaderboard(text, text) to anon, authenticated;

commit;

notify pgrst, 'reload schema';
