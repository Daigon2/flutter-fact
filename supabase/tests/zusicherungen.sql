-- FACT, die inhaltlichen Zusicherungen an das Schema.
--
-- Gate 5 prüft bisher nur, **dass** die Migrationen von null durchlaufen. Das
-- ist die halbe Antwort: ein Schema kann fehlerfrei entstehen und trotzdem
-- jedem alles zeigen. Diese Datei prüft, **was** dabei entstanden ist.
--
-- ADR-010 nennt vier Zusicherungen und den Grund, warum sie dort noch fehlten:
-- „An einer leeren Datenbank wären alle vier grün, ohne etwas geprüft zu
-- haben." Das gilt für die vierte, die Buchungen braucht; die legt sie hier
-- selbst an. Für die anderen drei gilt es nicht, sie lesen den Katalog, und
-- der ist auch ohne eine einzige Zeile Nutzdaten vollständig.
--
-- ## Warum reines SQL und nicht pgTAP
--
-- `supabase test db` bringt pgTAP mit, und pgTAP hat für genau diese Fragen
-- fertige Helfer. Der Preis ist eine Erweiterung, die installiert sein muss,
-- und eine zweite Werkzeugkette in der CI. Fünf `do`-Blöcke mit
-- `raise exception` brauchen nichts davon: `psql -v ON_ERROR_STOP=1` bricht
-- ab, und die Meldung nennt die verletzende Tabelle beim Namen. Wer pgTAP
-- später will, kann diese Datei ersetzen, ohne etwas anderes anzufassen.
--
-- ## Wie das läuft
--
--     psql "postgresql://postgres:postgres@localhost:54322/postgres" \
--       -v ON_ERROR_STOP=1 -f supabase/tests/zusicherungen.sql
--
-- Alles in **einer** Transaktion, die am Ende zurückgerollt wird: die vierte
-- Zusicherung legt ein Konto und zwei Buchungen an, und die haben in keiner
-- Datenbank etwas verloren, auch nicht in einer lokalen.

\set ON_ERROR_STOP on

begin;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Kein Tisch ohne Zeilenschutz
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Der teuerste einzelne Fehler, den ein Supabase-Schema machen kann. Ohne RLS
-- liest die Rolle `anon` die ganze Tabelle, und zwar über die öffentliche
-- REST-Schnittstelle, ohne Anmeldung und ohne Umweg.
--
-- Geprüft wird `public`, nicht `app`: das Schema `app` ist nicht über die API
-- erreichbar, und seine Tabellen (es gibt heute keine) wären damit ohnehin
-- unerreichbar. `relkind = 'r'` sind gewöhnliche Tabellen; Sichten haben
-- keinen Zeilenschutz und werden unter Punkt 5 geprüft.
do $$
declare
  v_offen text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
  into v_offen
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and not c.relrowsecurity;

  if v_offen is not null then
    raise exception 'Zusicherung 1 verletzt: Tabellen ohne RLS: %', v_offen;
  end if;

  raise notice 'Zusicherung 1 erfuellt: jede Tabelle in public hat RLS.';
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. Keine Policy, die Personendaten für jeden öffnet
-- ═══════════════════════════════════════════════════════════════════════════
--
-- RLS eingeschaltet und dann `using (true)` ist derselbe Zustand wie kein RLS,
-- nur schwerer zu sehen. Genau das ist E-55 im alten Backend.
--
-- **Welche Tabelle trägt Personenbezug?** Nicht nach einer Liste, die jemand
-- pflegen müsste, sondern abgeleitet: jede Tabelle in `public`, die über einen
-- Fremdschlüssel auf `auth.users` zeigt. Eine neue Tabelle mit `user_id` fällt
-- damit automatisch unter diese Prüfung, ohne dass jemand daran denken muss.
--
-- **Eine Ausnahme, und sie ist eine Entscheidung und kein Schlupfloch.**
-- `public.profiles` hat `for select ... using (true)`, absichtlich: die
-- Rangliste zeigt Nutzernamen, und sie ist laut Janeks Antwort vom 02.09.2026
-- auch ohne Anmeldung sichtbar. Ein Username ist der einzige Inhalt der
-- Tabelle, den jemand sehen kann; einen echten Namen gibt es im Neubau nicht.
-- Die Ausnahme steht hier namentlich, damit sie beim nächsten Lesen auffällt.
do $$
declare
  v_verletzer text;
begin
  with personenbezogen as (
    select distinct c.relname
    from pg_constraint k
    join pg_class c on c.oid = k.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_class ref on ref.oid = k.confrelid
    join pg_namespace rn on rn.oid = ref.relnamespace
    where k.contype = 'f'
      and n.nspname = 'public'
      and rn.nspname = 'auth'
      and ref.relname = 'users'
  )
  select string_agg(p.tablename || '.' || p.policyname, ', ' order by
                    p.tablename || '.' || p.policyname)
  into v_verletzer
  from pg_policies p
  join personenbezogen pb on pb.relname = p.tablename
  where p.schemaname = 'public'
    -- Absichtlich öffentlich, siehe der Kommentar darüber.
    and p.tablename <> 'profiles'
    and (
      coalesce(p.qual, '') = 'true'
      or coalesce(p.with_check, '') = 'true'
    );

  if v_verletzer is not null then
    raise exception
      'Zusicherung 2 verletzt: Personendaten mit using(true): %', v_verletzer;
  end if;

  raise notice
    'Zusicherung 2 erfuellt: keine offene Policy auf Personendaten.';
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. Keine öffentliche Funktion nimmt eine Nutzerkennung
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Das ist E-52 als Klasse. Eine Funktion, die die Kennung als Argument nimmt,
-- handelt als jemand anderes, und bei `security definer` heißt das: jeder
-- Aufrufer handelt als jeder.
--
-- Zwei Prüfungen übereinander, weil eine allein zu leicht zu umgehen ist:
--
-- **a) Kein `uuid`-Parameter.** Das ist die scharfe Regel. In diesem Schema
-- ist jede Kennung eine `uuid`, und keine der vier öffentlichen Funktionen
-- braucht eine; sie nehmen Fakt-Kennungen (`bigint`), Stadtschlüssel (`text`),
-- Koordinaten und Stufen. Ein `uuid`-Parameter in `public` ist deshalb fast
-- sicher eine Identität, und wer wirklich einen braucht, muss diesen Test
-- ändern und dabei begründen, warum.
--
-- **b) Kein Parametername, der nach Identität klingt.** Fängt den Fall, dass
-- jemand die Kennung als `text` durchschleift.
--
-- **Der erste Entwurf von (b) hat sich selbst ins Knie geschossen**, und der
-- Fehler ist lehrreich genug, um ihn hinzuschreiben: `pg_proc.proargnames`
-- enthält auch die **Ausgabe**-Parameter, und `get_leaderboard` gibt
-- `username` heraus. Darin steckt das Wort `user`, also hätte die Prüfung
-- genau die Funktion angeschwärzt, die E-16b behebt. Ein Test, der das
-- Richtige meldet, ist schlimmer als keiner: der Nächste hängt eine Ausnahme
-- dran und hat damit die Regel entschärft. Deshalb filtert (b) über
-- `proargmodes` auf die Eingaben.
--
-- `app.grant_reward` nimmt sehr wohl eine `uuid`, und das ist der Kern des
-- Aufbaus: die Funktion liegt in `app`, ist für keinen Client erreichbar, und
-- die öffentlichen Funktionen füllen den Parameter selbst mit `auth.uid()`.
-- Deshalb prüft dieser Block ausschließlich `public`.
do $$
declare
  v_uuid  text;
  v_namen text;
begin
  select string_agg(p.proname, ', ' order by p.proname)
  into v_uuid
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and 'uuid'::regtype::oid = any (p.proargtypes::oid[]);

  if v_uuid is not null then
    raise exception
      'Zusicherung 3a verletzt: oeffentliche Funktion mit uuid-Parameter: %',
      v_uuid;
  end if;

  select string_agg(p.proname, ', ' order by p.proname)
  into v_namen
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proargnames is not null
    and exists (
      select 1
      from unnest(p.proargnames) with ordinality as a(name, ord)
      -- Nur **Eingabe**-Parameter. `proargnames` führt auch die Ausgaben, und
      -- `get_leaderboard` gibt `username` heraus: darin steckt das Wort
      -- `user`, und ohne diese Zeile meldet die Prüfung genau die Funktion,
      -- die E-16b behebt. `proargmodes` ist `null`, wenn alles Eingabe ist.
      where coalesce(p.proargmodes[a.ord], 'i') in ('i', 'b', 'v')
        and a.name ~* '(user|uid|account|konto|owner|besitzer)'
    );

  if v_namen is not null then
    raise exception
      'Zusicherung 3b verletzt: Parametername nach Identitaet: %', v_namen;
  end if;

  raise notice
    'Zusicherung 3 erfuellt: keine oeffentliche Funktion nimmt eine Kennung.';
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3c. Jede eigene Funktion setzt den Suchpfad
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Nicht in ADR-010 aufgezählt und trotzdem hier, weil es dieselbe Familie ist:
-- eine `security definer`-Funktion ohne festen `search_path` kann von einem
-- Aufrufer umgelenkt werden, der ein Schema vor `public` schiebt. Der Aufwand
-- dafür ist eine Zeile je Funktion, das Versäumnis ist eine
-- Rechteausweitung.
do $$
declare
  v_ohne text;
begin
  select string_agg(n.nspname || '.' || p.proname, ', '
                    order by n.nspname || '.' || p.proname)
  into v_ohne
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'app')
    and p.prokind = 'f'
    and not exists (
      select 1
      from unnest(coalesce(p.proconfig, array[]::text[])) as c(setting)
      where c.setting like 'search\_path=%'
    );

  if v_ohne is not null then
    raise exception
      'Zusicherung 3c verletzt: Funktion ohne search_path: %', v_ohne;
  end if;

  raise notice 'Zusicherung 3c erfuellt: jede Funktion setzt search_path.';
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. Doppeltes Gutschreiben ist unmöglich
-- ═══════════════════════════════════════════════════════════════════════════
--
-- E-06, E-54 und E-69 in einem. Die Prüfung braucht Daten, und sie legt sie
-- selbst an: ein Konto, zweimal derselbe Aufruf, und danach muss genau **eine**
-- Zeile im Journal stehen.
--
-- **Der zweite Aufruf wirft nicht**, und das ist die eigentliche Zusicherung:
-- `on conflict do nothing` macht ihn zu einem Nicht-Ereignis, und
-- `was_granted` sagt dem Aufrufer, dass nichts gebucht wurde, statt es ihn
-- raten zu lassen. Ein Fehler wäre die schlechtere Antwort — ein zweites
-- Antippen desselben Ballons ist kein Programmierfehler, sondern ein Nutzer,
-- der zweimal tippt.
do $$
declare
  v_user  uuid := gen_random_uuid();
  v_erst  boolean;
  v_zweit boolean;
  v_zeilen integer;
  v_muenzen integer;
begin
  insert into auth.users (
    id, instance_id, aud, role, email,
    encrypted_password, created_at, updated_at
  ) values (
    v_user, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'zusicherung@fact.test',
    '', now(), now()
  );

  select was_granted into v_erst
  from app.grant_reward(v_user, 'fact_collected', 'fact:4711');

  select was_granted into v_zweit
  from app.grant_reward(v_user, 'fact_collected', 'fact:4711');

  if not v_erst then
    raise exception
      'Zusicherung 4 verletzt: die erste Buchung hat nicht gegriffen.';
  end if;

  if v_zweit then
    raise exception
      'Zusicherung 4 verletzt: die zweite Buchung meldet Erfolg.';
  end if;

  select count(*), coalesce(sum(coins), 0)
  into v_zeilen, v_muenzen
  from public.reward_ledger
  where user_id = v_user;

  if v_zeilen <> 1 then
    raise exception
      'Zusicherung 4 verletzt: % Zeilen im Journal statt einer.', v_zeilen;
  end if;

  -- Der Betrag stammt aus `reward_kinds` und nicht aus dem Aufruf. 50 steht
  -- hier ausgeschrieben und wird nicht aus der Tabelle gelesen: ein Test, der
  -- dieselbe Zeile liest, die er prueft, haelt jede Aenderung fuer richtig.
  if v_muenzen <> 50 then
    raise exception
      'Zusicherung 4 verletzt: % Muenzen gebucht statt 50.', v_muenzen;
  end if;

  raise notice
    'Zusicherung 4 erfuellt: derselbe Bezug bucht genau einmal.';
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. Jede Sicht läuft mit den Rechten ihres Aufrufers
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Die Falle, die das deklarative Schema von Supabase ausdrücklich nicht
-- mitzieht, und der Grund, aus dem ADR-010 es abgelehnt hat. Ohne
-- `security_invoker = true` läuft eine Sicht mit den Rechten ihres Eigentümers
-- und umgeht damit den Zeilenschutz der Tabelle darunter: jeder sähe jeden
-- Kontostand.
--
-- Die Voreinstellung ist `false`. Eine Sicht, bei der jemand die Option
-- vergisst, sieht völlig unauffällig aus.
do $$
declare
  v_ohne text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
  into v_ohne
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'v'
    and not exists (
      select 1
      from unnest(coalesce(c.reloptions, array[]::text[])) as o(setting)
      where o.setting = 'security_invoker=true'
    );

  if v_ohne is not null then
    raise exception
      'Zusicherung 5 verletzt: Sicht ohne security_invoker: %', v_ohne;
  end if;

  raise notice 'Zusicherung 5 erfuellt: jede Sicht laeuft als Aufrufer.';
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. Wo eine Belohnung hängt, schreibt kein Client
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Der Satz, auf den das ganze Schema hinausläuft, hier als Abfrage. Zwei
-- Hälften:
--
-- **a) `anon` schreibt nirgends.** Wer nicht angemeldet ist, liest. Es gibt
-- keine Tabelle, in die er etwas legen dürfte, und es soll auch keine geben.
--
-- **b) Journal und Sammlung sind für **keinen** Client beschreibbar**, auch
-- nicht für den Besitzer der Zeile. Das ist der Unterschied zu E-55, wo
-- `user_city_scores` und `user_trophies` vom Besitzer beschreibbar waren: wer
-- seinen eigenen Punktestand schreiben darf, hat keinen Punktestand, sondern
-- ein Textfeld. Geschrieben wird nur über `collect_fact`, `reveal_hint` und
-- `app.grant_reward`.
--
-- Gelesen wird `information_schema.column_privileges` und nicht
-- `role_table_grants`: das erste führt **beides**, die Rechte auf der Tabelle
-- und die auf einzelnen Spalten. `profiles` hat ein Spaltenrecht
-- (`grant update (username, home_city_id)`), und ein Spaltenrecht auf dem
-- Journal wäre genauso ein Loch wie ein Tabellenrecht.
do $$
declare
  v_anon    text;
  v_journal text;
begin
  select string_agg(distinct g.table_name || ':' || g.privilege_type, ', ')
  into v_anon
  from information_schema.column_privileges g
  where g.table_schema = 'public'
    and g.grantee = 'anon'
    and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE');

  if v_anon is not null then
    raise exception
      'Zusicherung 6a verletzt: anon darf schreiben: %', v_anon;
  end if;

  select string_agg(distinct g.table_name || ':' || g.grantee || ':'
                    || g.privilege_type, ', ')
  into v_journal
  from information_schema.column_privileges g
  where g.table_schema = 'public'
    and g.table_name in ('reward_ledger', 'collected_facts')
    and g.grantee in ('anon', 'authenticated')
    and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE');

  if v_journal is not null then
    raise exception
      'Zusicherung 6b verletzt: Client darf ins Journal schreiben: %',
      v_journal;
  end if;

  raise notice
    'Zusicherung 6 erfuellt: kein Client schreibt, wo eine Belohnung haengt.';
end $$;

-- Nichts bleibt zurück, auch nicht das Testkonto.
rollback;
