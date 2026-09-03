-- FACT, Migration 6: die Schreibwege.
--
-- Die einzige Stelle, an der ein Client etwas auslöst, das Geld kostet. Jede
-- Funktion hier leitet den Handelnden und den Betrag **selbst** ab.
--
-- Entscheidung: ADR-010, Eigenschaften zwei, drei und sechs.
-- Leitplanke: `security.md` §1.
--
-- ## Die drei Regeln, die für jede Funktion in dieser Datei gelten
--
-- **1. Keine Nutzerkennung als Parameter.** Der Handelnde kommt aus
-- `auth.uid()`. Im alten Backend nehmen drei Funktionen die Kennung als
-- Argument und sind ohne Anmeldung erreichbar (E-52); wer den Aufruf selbst
-- formuliert, handelt als jemand anderes. Eine Funktion, die niemanden nennen
-- kann, hat dieses Problem nicht.
--
-- **2. `set search_path = ''` und schema-qualifizierte Namen.** Ohne
-- festgenagelten Suchpfad kann ein Aufrufer einen unqualifizierten Namen auf
-- ein eigenes Objekt zeigen lassen und es mit den Rechten des
-- Funktionseigentümers ausführen.
--
-- **3. Kein Betrag und keine Zeit vom Client.** Beträge stehen in
-- `reward_kinds`, Zeiten kommen aus `now()`.

-- ── Entfernung ──────────────────────────────────────────────────────────────
--
-- Haversine, in Metern. Der Erdradius ist 6371000 und damit derselbe Wert, mit
-- dem der Client rechnet; die Vorlage benutzt ihn ebenfalls. Zwei verschiedene
-- Radien wären ein Unterschied von einigen Metern genau an der Grenze, an der
-- entschieden wird, ob jemand nah genug dran ist.
create or replace function app.distance_m(
  lat_a double precision, lng_a double precision,
  lat_b double precision, lng_b double precision
)
returns double precision
language sql
immutable
security invoker
set search_path = ''
as $$
  select 2 * 6371000 * asin(sqrt(
      power(sin(radians(lat_b - lat_a) / 2), 2)
    + cos(radians(lat_a)) * cos(radians(lat_b))
    * power(sin(radians(lng_b - lng_a) / 2), 2)
  ));
$$;

comment on function app.distance_m(double precision, double precision,
                                   double precision, double precision) is
  'Entfernung in Metern, Haversine mit Erdradius 6371000 wie im Client.';

-- ── Gutschreiben ────────────────────────────────────────────────────────────
--
-- Intern, in `app`, also für keinen Client erreichbar. Sie ist der einzige Weg
-- in das Journal.
--
-- **Der Betrag ist ein Nachschlagevorgang und kein Parameter.** Wer die Funktion
-- aufruft, sagt *welche Art* Belohnung, nicht *wie viel*. Das ist die Umsetzung
-- der Regel aus `security.md` §1 in genau einer Zeile.
--
-- Der Rückgabewert sagt, ob gebucht wurde. `on conflict do nothing` und die
-- Eindeutigkeit im Journal machen den zweiten Aufruf zu einem Nicht-Ereignis,
-- und der Aufrufer erfährt das, statt es zu erraten.
create or replace function app.grant_reward(
  p_user_id uuid,
  p_kind    text,
  p_ref     text,
  p_city_id text default null
)
returns table (coins integer, xp integer, was_granted boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coins integer;
  v_xp    integer;
  v_rows  integer;
begin
  select k.coins, k.xp into v_coins, v_xp
  from public.reward_kinds k
  where k.key = p_kind;

  if not found then
    -- Eine unbekannte Belohnungsart ist ein Programmierfehler und keine
    -- Nullbuchung. Stillschweigend nichts zu tun wäre die schlechtere Antwort:
    -- der Nutzer bekäme nichts und niemand erführe, warum.
    raise exception 'Unbekannte Belohnungsart: %', p_kind
      using errcode = 'check_violation';
  end if;

  insert into public.reward_ledger (user_id, kind, ref, coins, xp, city_id)
  values (p_user_id, p_kind, p_ref, v_coins, v_xp, p_city_id)
  on conflict (user_id, kind, ref) do nothing;

  get diagnostics v_rows = row_count;

  return query select v_coins, v_xp, v_rows > 0;
end;
$$;

comment on function app.grant_reward(uuid, text, text, text) is
  'Der einzige Weg in das Journal. Der Betrag wird nachgeschlagen, nicht '
  'übergeben. Zweiter Aufruf für dieselbe Bezugsgröße bucht nichts.';

-- ── Einsammeln ──────────────────────────────────────────────────────────────
--
-- ## Die Prüfungen, in dieser Reihenfolge
--
-- 1. Es gibt eine Anmeldung.
-- 2. Der Fakt existiert, ist veröffentlicht und hat eine Koordinate.
-- 3. Die behauptete Position liegt im Radius des Fakts.
-- 4. Die behauptete Position ist plausibel, gemessen an der vorigen Sammlung.
--
-- ## Zu drei: der Radius wird hier geprüft und nicht im Client
--
-- Der Client prüft ihn auch, damit der Knopf grau ist. Aber `security.md` §1
-- sagt, dass Client-Prüfungen keine Autorisierung sind, und die 150 Meter
-- entscheiden über eine Gutschrift.
--
-- ## Zu vier: was gegen gefälschte Standorte geht und was nicht
--
-- `security.md` §6 verlangt, das Fälschungsrisiko für Sammel- und
-- Belohnungsaktionen zu prüfen. Ein Standort kommt vom Gerät, also ist er
-- **nicht beweisbar**; wer ihn fälscht, kann behaupten, überall zu sein. Das
-- ist eine Eigenschaft der Welt und nicht dieses Schemas.
--
-- Prüfbar ist die **Folge**: wer eben in München gesammelt hat und drei
-- Sekunden später in Rom, ist nicht gereist. Die Rechnung braucht dafür
-- ausdrücklich **keine** Positionsgeschichte des Nutzers, sondern nur die
-- Koordinaten der beiden Fakten, und die sind öffentliche Stammdaten. Damit
-- erfüllt die Abwehr gleichzeitig §6: „Avoid long-term location history."
--
-- **Die behauptete Position wird nicht gespeichert.** Sie wird geprüft und
-- verworfen.
--
-- Die Grenze von 30 Metern je Sekunde entspricht 108 km/h. Sie lässt Auto und
-- Zug zu und schließt aus, was kein Fahrzeug schafft. Sie ist gewählt und nicht
-- gemessen; wer sie ändert, ändert sie hier, und das ist der richtige Ort für
-- eine Abwehrschwelle.
create or replace function public.collect_fact(
  p_fact_id bigint,
  p_lat     double precision,
  p_lng     double precision
)
returns table (
  status        text,
  coins_granted integer,
  xp_granted    integer,
  collected_at  timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_speed_mps constant double precision := 30;
  v_user     uuid := auth.uid();
  v_fact     public.facts;
  v_distance double precision;
  v_prev_lat double precision;
  v_prev_lng double precision;
  v_prev_at  timestamptz;
  v_seconds  double precision;
  v_gap_m    double precision;
  v_when     timestamptz;
  v_rows     integer;
  v_reward   record;
begin
  if v_user is null then
    raise exception 'Nicht angemeldet.' using errcode = '42501';
  end if;

  select * into v_fact from public.facts f where f.id = p_fact_id;

  if not found or not v_fact.is_published then
    raise exception 'Fakt nicht vorhanden.' using errcode = 'no_data_found';
  end if;

  if v_fact.lat is null then
    raise exception 'Fakt ohne Koordinate ist nicht einsammelbar.'
      using errcode = 'check_violation';
  end if;

  if p_lat is null or p_lng is null then
    raise exception 'Ohne Position kann nicht gesammelt werden.'
      using errcode = 'check_violation';
  end if;

  v_distance := app.distance_m(p_lat, p_lng, v_fact.lat, v_fact.lng);

  if v_distance > v_fact.collect_radius_m then
    raise exception 'Zu weit entfernt: % Meter.', round(v_distance)
      using errcode = 'check_violation';
  end if;

  -- Plausibilität gegen die vorige Sammlung, nur über Fakt-Koordinaten.
  select f.lat, f.lng, c.collected_at
    into v_prev_lat, v_prev_lng, v_prev_at
  from public.collected_facts c
  join public.facts f on f.id = c.fact_id
  where c.user_id = v_user and f.lat is not null
  order by c.collected_at desc
  limit 1;

  if v_prev_at is not null then
    v_seconds := greatest(extract(epoch from (now() - v_prev_at)), 1);
    v_gap_m := app.distance_m(v_prev_lat, v_prev_lng, v_fact.lat, v_fact.lng);

    if v_gap_m / v_seconds > c_max_speed_mps then
      raise exception
        'Unplausibel: % Meter in % Sekunden.', round(v_gap_m), round(v_seconds)
        using errcode = 'check_violation';
    end if;
  end if;

  insert into public.collected_facts (user_id, fact_id)
  values (v_user, p_fact_id)
  on conflict (user_id, fact_id) do nothing;

  get diagnostics v_rows = row_count;

  select c.collected_at into v_when
  from public.collected_facts c
  where c.user_id = v_user and c.fact_id = p_fact_id;

  if v_rows = 0 then
    -- Schon gesammelt. Kein Fehler, aber auch keine zweite Gutschrift. Genau
    -- hier farmt E-69 im alten Backend 50 Münzen je Antippen.
    return query select 'already_collected'::text, 0, 0, v_when;
    return;
  end if;

  select * into v_reward from app.grant_reward(
    v_user, 'fact_collected', 'fact:' || p_fact_id::text, v_fact.city_id
  );

  return query select
    'collected'::text,
    case when v_reward.was_granted then v_reward.coins else 0 end,
    case when v_reward.was_granted then v_reward.xp else 0 end,
    v_when;
end;
$$;

comment on function public.collect_fact(bigint, double precision,
                                        double precision) is
  'Sammelt einen Fakt ein. Prüft Anmeldung, Veröffentlichung, Radius und '
  'Plausibilität, bucht die Belohnung und speichert die behauptete Position '
  'nicht. Siehe security.md §1 und §6.';

-- ── Einen Hinweis aufdecken ─────────────────────────────────────────────────
--
-- Ein Hinweis kostet, und damit ist es eine Belohnungsart mit negativem
-- Betrag. Dieselbe Buchführung, dasselbe Journal, dieselbe Eindeutigkeit:
-- derselbe Hinweis kostet einmal und nicht bei jedem Aufdecken.
--
-- Die erste Stufe ist kostenlos. Das steht als Betrag null in `reward_kinds`
-- und nicht als Sonderfall in dieser Funktion.
create or replace function public.reveal_hint(
  p_fact_id bigint,
  p_level   smallint
)
returns table (status text, coins_charged integer, hint_text text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user    uuid := auth.uid();
  v_kind    text;
  v_reward  record;
  v_balance integer;
  v_text    text;
begin
  if v_user is null then
    raise exception 'Nicht angemeldet.' using errcode = '42501';
  end if;

  if p_level is null or p_level not between 1 and 3 then
    raise exception 'Hinweisstufe muss 1 bis 3 sein.'
      using errcode = 'check_violation';
  end if;

  v_kind := 'hint_level_' || p_level::text;

  -- Reicht das Guthaben? Der Kontostand ist eine Summe, also wird er hier
  -- gerechnet und nicht gelesen.
  select coalesce(sum(l.coins), 0) into v_balance
  from public.reward_ledger l where l.user_id = v_user;

  if v_balance + (select k.coins from public.reward_kinds k
                  where k.key = v_kind) < 0 then
    -- Nur wenn dieser Hinweis noch nicht bezahlt ist, siehe unten.
    if not exists (select 1 from public.reward_ledger l
                   where l.user_id = v_user and l.kind = v_kind
                     and l.ref = 'fact:' || p_fact_id::text) then
      raise exception 'Nicht genug Münzen.' using errcode = 'check_violation';
    end if;
  end if;

  select * into v_reward from app.grant_reward(
    v_user, v_kind, 'fact:' || p_fact_id::text
  );

  select h.text into v_text
  from public.fact_hints h
  join public.facts f on f.id = h.fact_id
  where h.fact_id = p_fact_id and h.level = p_level and f.is_published
  order by case when h.lang = 'de' then 0 else 1 end
  limit 1;

  return query select
    case when v_reward.was_granted then 'revealed' else 'already_revealed' end,
    case when v_reward.was_granted then v_reward.coins else 0 end,
    v_text;
end;
$$;

comment on function public.reveal_hint(bigint, smallint) is
  'Deckt einen Hinweis auf und bucht seine Kosten. Derselbe Hinweis kostet '
  'einmal, weil das Journal eindeutig ist.';

-- ── Ausführungsrechte ───────────────────────────────────────────────────────
--
-- Migration 1 hat `execute` als Standardrecht entzogen. Hier wird es gezielt
-- vergeben, und zwar nur an Angemeldete. `anon` bekommt nichts: es gibt keine
-- Belohnung ohne Konto.
grant execute on function public.collect_fact(bigint, double precision,
                                              double precision)
  to authenticated;
grant execute on function public.reveal_hint(bigint, smallint)
  to authenticated;
