-- FACT, Migration 3: Profile.
--
-- Ein Profil je Konto. Der Name, den andere sehen, und sonst so wenig wie
-- möglich.
--
-- Entscheidung: ADR-010. Leitplanken: `security.md` §3 und §4.

-- ── Profile ─────────────────────────────────────────────────────────────────
--
-- ## Es gibt nur einen Namen
--
-- Das alte Backend führt `profiles.name` und `profiles.username` getrennt, dazu
-- einen Schalter `show_real_name`. Am 02.09.2026 ist entschieden worden, dass
-- es **nur einen Username** gibt und keinen echten Namen. Damit verschwindet
-- der Schalter als Begriff und mit ihm der Grund für die zweite Spalte. Ein
-- Feld, das es nicht gibt, kann nicht versehentlich veröffentlicht werden.
--
-- ## Der Fremdschlüssel ist Absicht, nicht Zierde
--
-- `references auth.users(id) on delete cascade`: löscht jemand sein Konto, ist
-- das Profil weg, und zwar ohne dass irgendwer daran denken muss. Dasselbe gilt
-- weiter unten für Sammlung und Journal. Die Auskunfts- und Löschpflicht wird
-- damit eine Eigenschaft des Schemas und nicht eine Aufgabe auf einer Liste.
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text not null,
  -- Die Heimatstadt aus der Registrierung. `on delete set null`, damit das
  -- Entfernen einer Stadt kein Konto beschädigt.
  home_city_id text references public.cities(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- Die Form ist eine Bedingung und keine Bitte an den Client. `security.md` §5
  -- verlangt Prüfung an jeder Vertrauensgrenze, und die Datenbank ist die
  -- letzte davon.
  constraint profiles_username_format
    check (username ~ '^[A-Za-z0-9_.-]{3,24}$')
);

comment on table public.profiles is
  'Ein Profil je Konto. Nur ein Username, kein echter Name, siehe E-16.';

-- Eindeutig ohne Rücksicht auf Groß- und Kleinschreibung, über einen Index auf
-- `lower(...)` statt über die Erweiterung `citext`. Zwei Konten `Janek` und
-- `janek` wären für jeden Leser dasselbe und für die Datenbank nicht.
create unique index profiles_username_lower_key
  on public.profiles (lower(username));

create index profiles_home_city_id_idx
  on public.profiles (home_city_id)
  where home_city_id is not null;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function app.set_updated_at();

-- ── Das Profil entsteht mit dem Konto ───────────────────────────────────────
--
-- ## Warum als Trigger und nicht im Client
--
-- Ein Client, der nach der Registrierung eine Zeile anlegt, kann dabei
-- abbrechen, und dann existiert ein Konto ohne Profil. Der Trigger macht daraus
-- einen Vorgang: entweder es gibt beides oder keins.
--
-- **`security definer` ist hier nötig und nicht bequem.** Die Rolle, die
-- Anmeldungen ausführt, hat außerhalb des `auth`-Schemas keine Rechte; ein
-- Trigger, der ohne erhöhte Rechte in `public.profiles` schreiben will, endet
-- in einem Rechtefehler. Das ist ein bekannter Stolperstein und der Grund für
-- diese Zeile.
--
-- **Der Username kommt aus den Metadaten der Registrierung**, und wenn er fehlt
-- oder die Form verletzt, entsteht ein Ersatzname aus der Kennung. Ein
-- Registrierungsversuch soll nicht an einem Namen scheitern, aber auch kein
-- Profil ohne Namen hinterlassen.
create or replace function app.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wunsch text := nullif(trim(new.raw_user_meta_data ->> 'username'), '');
  v_name   text;
begin
  if v_wunsch is not null and v_wunsch ~ '^[A-Za-z0-9_.-]{3,24}$' then
    v_name := v_wunsch;
  else
    -- `fact_` plus die ersten acht Zeichen der Kennung. Kollisionsfrei genug
    -- für einen Ersatznamen und kurz genug, um ihn vorzulesen.
    v_name := 'fact_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  insert into public.profiles (id, username)
  values (new.id, v_name)
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function app.handle_new_user() is
  'Legt beim Anlegen eines Kontos das Profil an. security definer, weil die '
  'Auth-Rolle außerhalb von auth keine Rechte hat.';

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function app.handle_new_user();

-- ── Wer welches Profil sehen und ändern darf ────────────────────────────────
alter table public.profiles enable row level security;

grant select on public.profiles to anon, authenticated;
grant update (username, home_city_id) on public.profiles to authenticated;

-- ## Lesbar für alle, und das ist eine Entscheidung
--
-- Der Username erscheint in der Rangliste, und die ist am 02.09.2026
-- ausdrücklich **auch ohne Anmeldung** sichtbar geblieben. Ein Username ist
-- damit öffentlich, und das ist der Zweck eines Usernames. Was hier
-- ausdrücklich **nicht** steht, ist alles andere: kein echter Name, keine
-- E-Mail, keine Städteliste. Der Personenbezug ist ein selbstgewählter Name.
create policy profiles_lesbar on public.profiles
  for select to anon, authenticated using (true);

-- ## Ändern darf nur der Besitzer, und nur zwei Spalten
--
-- `(select auth.uid())` und nicht `auth.uid()`: die Klammer lässt den Planer
-- den Wert einmal auswerten statt je Zeile. Auf kleinen Tabellen ist das
-- gleichgültig, auf großen ist es der Unterschied zwischen Millisekunden und
-- Minuten, und es kostet nichts, es überall gleich zu machen.
--
-- Welche Spalten geändert werden dürfen, steht oben im `grant update (...)`.
-- Eine Policy erlaubt den Zugriff auf die **Zeile**, das Recht erlaubt ihn auf
-- die **Spalte**. Genau diese Trennung fehlt im alten Backend, wo E-24 die
-- ganze Profilzeile schreibbar lässt.
create policy profiles_eigenes_aendern on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Kein `insert` und kein `delete` für Clients. Angelegt wird über den Trigger,
-- gelöscht über das Konto.
