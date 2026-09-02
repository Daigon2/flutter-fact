-- ##########################################################################
-- FACT-Backend, Datei 03 von 8: E-23, collected_facts
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitt 6, Migration 3,
-- Blöcke 3a und 3b. Wörtlich übernommen, mit einer Ergänzung: siehe unten.
--
-- SCHLIESST
--   E-23, der Befund mit der höchsten Stufe in diesem Satz. Der Client fügt
--   heute direkt in collected_facts ein; die 150-Meter-Prüfung aus
--   collect_fact_validated ist damit nicht nur fälschbar, sondern
--   vollständig umgehbar. Block 3b härtet die RPC selbst: p_user_id wird
--   nicht mehr geglaubt, search_path gesetzt, Ausführrechte gesetzt. Die
--   150-Meter-Logik selbst bleibt unverändert, E-07 bleibt offen.
--
-- PWA DANACH: BRICHT VOLLSTÄNDIG, UND STILL
--   api.jsx:145 ist der einzige Weg, auf dem in der PWA ein Fakt gesammelt
--   wird. Mit ihm fallen:
--     das Sammeln selbst (app.jsx:714) und das Sammeln in der Schnitzeljagd
--       (app.jsx:738);
--     über den Trigger on_fact_collected die Zählung score_total, die
--       Stadtwertung user_city_scores und sämtliche Trophäen;
--     die Wochen-Rangliste, weil get_leaderboard im weekly-Zweig auf
--       collected_facts zählt.
--   Der Fehler ist nicht sichtbar: _apiCheck (api.jsx:139-146) schreibt eine
--   Konsolenwarnung und meldet an Sentry, die Oberfläche zeigt weiter
--   "gesammelt". Der Gruppenmodus (collect_group_fact, collect_team_fact)
--   bleibt der einzige funktionierende Sammelweg.
--   Die Sperre für diesen Block ist am 02.09.2026 gefallen, weil die PWA
--   nicht live läuft; der Ausfall ist in Kauf genommen statt aufgeschoben.
--   Das Dokument hält die Aufhebung im Entscheidungsstand, in Abschnitt 4
--   und im Blockkommentar unten fest.
--
-- VORHER PRÜFEN (99-pruefungen.sql)
--   Abfrage E, und zwar als Voraussetzung und nicht als Kontrolle: gehören
--   Tabelle und Definer-Funktionen derselben Rolle, und ist FORCE ROW LEVEL
--   SECURITY aus? Steht rls_forced = true, diesen Block NICHT ausführen,
--   sonst ist der Trigger ausgesperrt. Dazu Abfrage A.
--
-- NACHHER PRÜFEN
--   Abfrage H muss false liefern. Negativtest 13 muss 42501 geben. Test 15
--   ist der wichtige: nach einem Sammeln über die RPC müssen score_total,
--   user_city_scores und user_trophies weiter wachsen. Läuft er rot, ist die
--   Eigentümer-Annahme falsch und dieser Block ist zurückzurollen.
--
-- ERGÄNZT GEGENÜBER DEM DOKUMENT
--   notify pgrst, 'reload schema'; am Ende. Das Dokument hat die Zeile bei 3b
--   nicht, Abschnitt 11.3 hält fest, dass sie dort gebraucht wird.
--
-- IDEMPOTENZ
--   Ja. drop policy if exists vor create policy, create or replace function,
--   wiederholbare revoke und grant.
-- ##########################################################################

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
-- BRECHENDE ÄNDERUNG für 02_Frontend/app/api.jsx:145: danach sammelt die PWA
-- nichts mehr, und der Fehler ist still (_apiCheck, api.jsx:139-146).
-- Bis zum 02.09.2026 galt deshalb "erst nach dem PWA-Release ausführen".
-- AUFGEHOBEN AM 02.09.2026: der Eigentümer hat festgestellt, dass die PWA
-- nicht live läuft und ein Ausfall dort in Kauf genommen ist. Der PWA-Release,
-- der auf collect_fact_validated umstellt, bleibt nötig, blockiert diesen
-- Block aber nicht mehr.
--
-- ############################################################################
-- ACHTUNG, EINE SPIELREGEL AENDERT SICH MIT, UND ZWAR UNBEMERKT
-- ############################################################################
--
-- Am 02.09.2026 beim Bau von Schritt 20 gemessen, drei Fundstellen:
--
--   * 02_Frontend/app/app.jsx:712-714 bucht im Solo-Sammelweg **50** Coins,
--     client-seitig (`Storage.addCoins(50)`, `Api.addCoins(userId, 50)`). Das
--     ist der Weg, der heute laeuft.
--   * 03_Backend/supabase-schema.sql:125-127, also `collect_fact_validated`,
--     bucht **10**. Und diese Funktion hat in der **ganzen Referenz keinen
--     einzigen Aufrufer**, geprueft ueber 02_Frontend und 03_Backend: nur die
--     Definition und ein Kommentarverweis. Sie ist heute toter Code.
--   * 02_Frontend/app/screen-map.jsx:1196 zeigt in der Animation **12**.
--
-- Diese Migration schliesst den direkten Insert und zwingt damit auf
-- `collect_fact_validated`. **Sobald die PWA dorthin umgestellt wird, faellt
-- die Belohnung von 50 auf 10**, ohne dass es jemand entschieden hat. Das ist
-- eine Balance-Aenderung, versteckt in einer Sicherheitsmigration.
--
-- **Sie blockiert diese Migration nicht.** Bis die PWA umgestellt ist, sammelt
-- dort ohnehin niemand mehr. Aber sie muss **vor** dem PWA-Release entschieden
-- sein, sonst entscheidet sie der Zufall. Gehoert zu E-06 und zu Janeks
-- Belohnungsregel vom 02.09.2026 (J-C in REBUILD_STATUS.md): je Nutzer und
-- Fakt zwei Anlaesse, jeder genau einmal fuer immer.
--
-- ############################################################################
--
-- ============================================================================

begin;

revoke insert, update, delete on public.collected_facts from authenticated, anon;

drop policy if exists "own collected" on public.collected_facts;

create policy "own collected select" on public.collected_facts
  for select using (auth.uid() = user_id);

commit;

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

-- Ergänzt gegenüber dem Dokument, Begründung im Kopf und in Abschnitt 11.3.
notify pgrst, 'reload schema';
