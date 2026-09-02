-- ##########################################################################
-- FACT-Backend, Datei 02 von 8: E-06, increment_coins
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitt 6, Migration 2,
-- Blöcke 2a und 2b. Wörtlich übernommen, mit einer Ergänzung: siehe unten.
--
-- SCHLIESST
--   E-06. Block 2a bindet increment_coins an das eigene Konto: bisher konnte
--   jeder angemeldete Nutzer jedem beliebigen Konto Coins schreiben, und die
--   fremde UUID liefert get_leaderboard frei Haus. Dazu search_path und
--   Ausführrechte. Block 2b setzt den Betragsdeckel, Vorgabewert 500,
--   verstellbar über die Datenbank-Einstellung fact.coins_max_delta. 2b
--   ersetzt die Funktion aus 2a vollständig, es ist kein Zusatz.
--
-- PWA DANACH
--   Kein Ablauf hört auf zu funktionieren, Nachweis je Aufrufer in
--   Abschnitt 4.1: der größte heute belegte legitime Betrag ist 270, der
--   kleinste -20, negative Buchungen bleiben zulässig. Eine
--   Verhaltensänderung gibt es trotzdem: greatest(coins + amount, 0) kappt
--   einen negativen Kontostand still auf 0, statt ihn zuzulassen.
--
-- VORHER PRÜFEN (99-pruefungen.sql)
--   Abfrage E, zweiter Teil (Eigentümer, security_definer und settings der
--   Funktionen), dazu Abfrage B.
--
-- NACHHER PRÜFEN
--   Abfrage J: authenticated true, anon false. Abfrage I sagt, welcher Deckel
--   gilt; ein leeres Ergebnis im zweiten Teil heißt "nichts hinterlegt", und
--   das ist ein gültiger Zustand, dann greift der eingebaute Wert 500.
--   Negativtests 8 bis 12 und 17 bis 30. Die entscheidenden sind 28 und 30:
--   nur sie unterscheiden "Ausfallwert greift" von "Prüfung fällt lautlos
--   aus".
--
-- ERGÄNZT GEGENÜBER DEM DOKUMENT
--   notify pgrst, 'reload schema'; am Ende. Das Dokument hat die Zeile bei 2a
--   und 2b nicht, Abschnitt 11.3 hält fest, dass sie dort gebraucht wird.
--
-- IDEMPOTENZ
--   Ja. create or replace function, dazu wiederholbare revoke und grant.
-- ##########################################################################

-- ============================================================================
-- FACT — E-06: increment_coins prüft weder Konto noch Betrag
-- ----------------------------------------------------------------------------
-- BLOCK 2a: Konto-Bindung, Ausführrechte, search_path.
-- Bricht nichts: die PWA übergibt in api.jsx:157 immer die eigene userId
-- (app.jsx:714, :761, :769 reichen `userId` aus der Session durch).
-- ============================================================================

begin;

create or replace function public.increment_coins(uid uuid, amount integer)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'increment_coins: not authenticated' using errcode = '42501';
  end if;

  -- `uid` bleibt in der Signatur, damit alle bestehenden Aufrufer ohne
  -- Änderung weiterlaufen. Der Wert wird nicht mehr geglaubt: bisher konnte
  -- jeder angemeldete Nutzer jedem beliebigen Konto Coins schreiben, und die
  -- fremde UUID liefert get_leaderboard frei Haus (supabase-schema.sql:371).
  if uid is not null and uid <> v_uid then
    raise exception 'increment_coins: foreign account' using errcode = '42501';
  end if;

  if amount is null or amount = 0 then
    return;
  end if;

  update public.profiles
     set coins = coins + amount
   where id = v_uid;
end;
$$;

-- Nur angemeldete Nutzer dürfen rufen. Muster aus ai_proxy.sql:51-54.
revoke all on function public.increment_coins(uuid, integer) from public, anon;
grant execute on function public.increment_coins(uuid, integer) to authenticated;

commit;

-- ============================================================================
-- BLOCK 2b: Betragsdeckel, ohne Migration verstellbar.
--
-- ENTSCHEIDUNG D-7: Deckel ja, Höhe frei gewählt, Auflage "leicht anpassbar".
-- Gewählt: 500. Herleitung, Aufrufer-Nachweis und Bedienanleitung in
-- Abschnitt 4.1. Kurzfassung: der größte heute belegte legitime Betrag ist 270
-- (perfekter Quizlauf auf schwer, screen-challenge.jsx:4364), der kleinste -20
-- (dritter Kartenhinweis, screen-map.jsx:3542).
--
-- Die Höhe steht NICHT im Rumpf, sondern in der Datenbank-Einstellung
-- fact.coins_max_delta. Verstellen ohne Codeänderung:
--     alter database postgres set fact.coins_max_delta = '800';
-- Zurück auf den eingebauten Wert:
--     alter database postgres reset fact.coins_max_delta;
-- In beiden Fällen greift der neue Wert erst für neu aufgebaute Verbindungen,
-- also nach einem Neustart des Projekts (Poolbetrieb, Abschnitt 4.1).
--
-- NICHT GESETZT HEISST NICHT "KEIN DECKEL": current_setting(..., true) liefert
-- dann NULL, und "amount > NULL" ist NULL, also weder wahr noch falsch. Ein IF
-- auf NULL nimmt den ELSE-Zweig, die Prüfung fiele lautlos aus. Deshalb wird
-- der Wert als Text gelesen, validiert und sonst durch c_default_max ersetzt.
-- ============================================================================

begin;

create or replace function public.increment_coins(uid uuid, amount integer)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  -- Die einzige Zahl, die eine Migration braucht. Sie ist die Untergrenze der
  -- Verlässlichkeit, nicht der Betriebswert: sie greift, wenn die Einstellung
  -- fehlt oder Unsinn enthält.
  c_default_max constant integer := 500;

  v_uid uuid := auth.uid();
  v_raw text;
  v_max integer;
begin
  if v_uid is null then
    raise exception 'increment_coins: not authenticated' using errcode = '42501';
  end if;

  if uid is not null and uid <> v_uid then
    raise exception 'increment_coins: foreign account' using errcode = '42501';
  end if;

  if amount is null or amount = 0 then
    return;
  end if;

  -- Deckel lesen. Bewusst kein Cast auf ungeprüften Text: ein Tippfehler in
  -- der Einstellung würde sonst JEDE Coin-Buchung mit 22P02 abbrechen. Eine
  -- Verstellschraube darf die Anwendung nicht anhalten können.
  -- Die Regel erlaubt höchstens neun Ziffern, damit der Cast nicht überläuft.
  v_raw := coalesce(current_setting('fact.coins_max_delta', true), '');
  if v_raw ~ '^[0-9]{1,9}$' then
    v_max := v_raw::integer;
  else
    v_max := c_default_max;
  end if;
  if v_max < 1 then
    v_max := c_default_max;   -- '0' wäre ein Ausfall, kein Schutz
  end if;

  -- Richtung ausdrücklich in zwei Vergleichen, nicht über abs(). Zwei Gründe:
  --   1. Sicherheitsrelevant ist nur die obere Seite. Negative Beträge sind
  --      regulär (Hinweiskauf -10/-20, screen-map.jsx:3542) und müssen bleiben.
  --      Getrennte Zweige verhindern, dass jemand später "positiv und klein"
  --      daraus macht und den Hinweiskauf zerstört.
  --   2. abs(-2147483648) ist in PostgreSQL "integer out of range", also ein
  --      Fehler statt einer Ablehnung.
  if amount > v_max then
    raise exception 'increment_coins: credit % exceeds cap %', amount, v_max
      using errcode = '22003';
  end if;
  if amount < -v_max then
    raise exception 'increment_coins: debit % exceeds cap %', amount, v_max
      using errcode = '22003';
  end if;

  update public.profiles
     set coins = greatest(coins + amount, 0)
   where id = v_uid;
end;
$$;

commit;

-- Ergänzt gegenüber dem Dokument, Begründung im Kopf und in Abschnitt 11.3.
notify pgrst, 'reload schema';
