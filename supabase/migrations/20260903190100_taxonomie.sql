-- FACT, Migration 2: Städte und Kategorien.
--
-- Die zwei Nachschlagewerke, auf die alles Weitere zeigt. Sie stehen zusammen in
-- einer Migration, weil sie zusammen **eine** Entscheidung umsetzen: dass
-- niemand mehr eine Stadt oder eine Kategorie aus einem Text errät.
--
-- Entscheidung: ADR-010, Eigenschaft vier. Beantwortet D-22 und entfernt die
-- Ursache von E-11, E-56, E-66, E-75, E-78 und E-81.

-- ── Städte ──────────────────────────────────────────────────────────────────
--
-- ## Warum diese Tabelle die teuerste Zeile des ganzen Umbaus einspart
--
-- Im alten Backend wird die Frage „zu welcher Stadt gehört dieser Fakt?" an
-- **fünf** Stellen verschieden beantwortet, alle gemessen: `lower(city)` im
-- Trigger und in beiden Ranglisten-Funktionen, `_slugify(city)` in
-- `_team_generate_orders`, eine feste Liste in `_city_default_meeting`, das
-- Frontend schickt `rom`, und der Reiseführer rechnet die Luftlinie zur
-- nächsten von zwölf Stadtmitten, ohne Entfernungsgrenze.
--
-- Die Folge ist nicht theoretisch: derselbe Fakt kann für die Rangliste zu
-- einer Stadt gehören, für die Trophäe zu einer anderen, und im Reiseführer im
-- Buch einer dritten stehen.
--
-- **Hier gibt es nichts mehr zu erraten.** Die Stadt ist eine Zeile, ihre
-- Kennung ist der Fremdschlüssel, und `facts.city_id` zeigt darauf. Kein
-- Anzeigename, keine Umschrift, keine Koordinatenrechnung. Die Kennung ist
-- lesbar (`muenchen`) und nicht eine UUID, weil sie in Protokollen, Adressen
-- und Gesprächen vorkommt und dort eine UUID nichts sagt.
create table public.cities (
  id          text primary key,
  name_de     text not null,
  name_en     text not null,
  country     text not null,
  region_de   text,
  region_en   text,
  centre_lat  double precision not null,
  centre_lng  double precision not null,
  -- Ob die Stadt in der App auftaucht. Standardwert falsch: eine Stadt wird
  -- sichtbar, weil jemand sie freigibt, und nicht weil jemand sie anlegt.
  is_active   boolean not null default false,
  -- Die Bandnummer im Reiseführer. Nullfähig, weil eine Stadt ohne Nummer ein
  -- gültiger Zustand ist; im alten Reiseregal bedeutete die 0 „keine Nummer"
  -- und wurde durch die Gitterposition ersetzt, die sich mit den Nachbarn
  -- verschiebt.
  volume_no   smallint,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  -- **Die Bedingung, die E-56 unmöglich macht.** `Rom` und `Rome` können hier
  -- nicht beide als Kennung entstehen, weil eine Kennung kleingeschrieben,
  -- ohne Leerzeichen und ohne Umlaut ist und die Tabelle nur eine davon
  -- annimmt. Der Anzeigename daneben darf jede Schreibweise haben, in beiden
  -- Sprachen, und trägt keine Bedeutung für die Zuordnung.
  constraint cities_id_format check (id ~ '^[a-z][a-z0-9-]{1,63}$'),
  constraint cities_country_format check (country ~ '^[A-Z]{2}$'),
  constraint cities_lat_range check (centre_lat between -90 and 90),
  constraint cities_lng_range check (centre_lng between -180 and 180),
  constraint cities_volume_positive check (volume_no is null or volume_no > 0)
);

comment on table public.cities is
  'Städte. Die Kennung ist der einzige Stadtschlüssel des Systems, siehe '
  'ADR-010 und D-22. Niemand leitet eine Stadt aus einem Namen oder einer '
  'Koordinate ab.';

comment on column public.cities.id is
  'Stabile, lesbare Kennung, etwa muenchen. Wird nie geändert.';

comment on column public.cities.volume_no is
  'Bandnummer im Reiseführer. NULL heißt: keine Nummer, nicht Band null.';

create unique index cities_volume_no_key
  on public.cities (volume_no)
  where volume_no is not null;

create trigger cities_set_updated_at
  before update on public.cities
  for each row execute function app.set_updated_at();

-- ── Kategorien ──────────────────────────────────────────────────────────────
--
-- ## Drei Tabellen, drei Antworten, und das war der Fehler
--
-- Gemessen am 03.09.2026: derselbe Fakt trägt an drei Stellen drei verschiedene
-- Kategorienamen. Die Karte kennt zwölf Kategorien mit Emoji und Farbe, die
-- Fakt-Akte kennt acht und fällt für den Rest auf „Historisch" zurück, der
-- Reiseführer kannte sechs und faltete fünf davon still in „Historisch"
-- hinein. Ein Fakt über ein Restaurant stand unter Geschichte (E-78, E-81).
--
-- **Hier ist die Kategorie eine Zeile**, und alle drei Bildschirme lesen sie.
-- Damit verschwindet nicht ein Fehler, sondern die Möglichkeit, ihn zu machen.
--
-- Die Spalte `chapter_key` ist der Kern davon. Der Reiseführer gruppiert nach
-- Kapiteln, und ein Kapitel ist eine Kategorie oder eine andere Kategorie:
-- `natur` gehört redaktionell zu `geo`, und das ist eine Absicht der Vorlage,
-- kein Rückfall. Diese Absicht ist jetzt **eine Spalte** und nicht eine von
-- fünf Präfixregeln in einer Programmiersprache.
create table public.fact_categories (
  key          text primary key,
  name_de      text not null,
  name_en      text not null,
  -- Die Kategoriefarbe der Karte und ihre dunkle Schwester, als Hex.
  colour       text not null,
  colour_dark  text not null,
  -- Das Zeichen auf dem Kartenballon.
  emoji        text not null,
  -- Das Schriftzeichen im Reiseführer. Nullfähig: die Vorlage hat für sechs
  -- Kategorien ein eigenes Zeichen und für die anderen keines.
  glyph        text,
  -- In welchem Kapitel des Reiseführers die Kategorie erscheint. Zeigt in der
  -- Regel auf sich selbst.
  chapter_key  text not null references public.fact_categories(key)
                 on update cascade,
  sort_order   smallint not null,
  created_at   timestamptz not null default now(),

  constraint fact_categories_key_format check (key ~ '^[a-z][a-z0-9_]{1,31}$'),
  constraint fact_categories_colour_format check (colour ~ '^#[0-9A-Fa-f]{6}$'),
  constraint fact_categories_colour_dark_format
    check (colour_dark ~ '^#[0-9A-Fa-f]{6}$')
);

comment on table public.fact_categories is
  'Kategorien. Eine Zeile je Kategorie, gelesen von Karte, Akte und '
  'Reiseführer. Ersetzt drei Tabellen im Code, siehe E-78 und E-81.';

comment on column public.fact_categories.chapter_key is
  'Kapitel im Reiseführer. Zeigt meist auf sich selbst; natur zeigt auf geo, '
  'weil das eine redaktionelle Entscheidung der Vorlage ist.';

create unique index fact_categories_sort_order_key
  on public.fact_categories (sort_order);

create index fact_categories_chapter_key_idx
  on public.fact_categories (chapter_key);

-- ── Aliasse der Datenpipeline ───────────────────────────────────────────────
--
-- Die Pipeline liefert Kategorien als deutschen oder englischen Freitext:
-- `Historisch`, `Fun-Fact`, `Kunst & Kultur`, `Historical Figures`. Im alten
-- Aufbau übersetzte das eine Präfixregel-Kette im Client, mit drei heiklen
-- Stellen: `historical figures` muss vor `hist` geprüft werden, `arch` vor
-- `art`, `kulinar` vor `kultur`. Wer die Zeilen sortiert, verschiebt Fakten.
--
-- **Als Tabelle gibt es keine Reihenfolge**, nur eine Zuordnung. Ein Text ist
-- eindeutig oder er ist unbekannt, und unbekannt ist ein Importfehler und kein
-- stiller Rückfall auf „Historisch".
create table public.fact_category_aliases (
  alias        text primary key,
  category_key text not null references public.fact_categories(key)
                 on update cascade,
  created_at   timestamptz not null default now()
);

comment on table public.fact_category_aliases is
  'Kategorietexte der Pipeline auf Kategorien. Ersetzt eine Kette von '
  'Präfixregeln, deren Reihenfolge über das Ergebnis entschied.';

create index fact_category_aliases_category_key_idx
  on public.fact_category_aliases (category_key);

-- ── Leserechte ──────────────────────────────────────────────────────────────
--
-- Beide Tabellen sind Stammdaten und öffentlich lesbar, auch ohne Anmeldung:
-- die Karte zeigt Ballons, bevor sich jemand anmeldet. Geschrieben wird
-- ausschließlich redaktionell, und dafür gibt es keine Policy. Kein Client
-- schreibt hier, auch nicht der angemeldete.
alter table public.cities enable row level security;
alter table public.fact_categories enable row level security;
alter table public.fact_category_aliases enable row level security;

grant select on public.cities to anon, authenticated;
grant select on public.fact_categories to anon, authenticated;
grant select on public.fact_category_aliases to anon, authenticated;

-- `using (true)` ist hier **richtig** und an anderer Stelle der Fehler. Der
-- Unterschied: das sind Stammdaten ohne Personenbezug. E-16 kritisiert
-- `using (true)` auf `user_city_scores`, wo jede Zeile einem Menschen gehört.
create policy cities_lesbar on public.cities
  for select to anon, authenticated using (true);

create policy fact_categories_lesbar on public.fact_categories
  for select to anon, authenticated using (true);

create policy fact_category_aliases_lesbar on public.fact_category_aliases
  for select to anon, authenticated using (true);
