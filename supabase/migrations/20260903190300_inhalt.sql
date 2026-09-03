-- FACT, Migration 4: Fakten, Texte, Medien, Rätsel.
--
-- Der Inhalt. Die einzige Tabelle, die der Flutter-Client heute schon liest.
--
-- Entscheidung: ADR-010.

-- ── Fakten ──────────────────────────────────────────────────────────────────
--
-- ## Was hier anders ist als im alten Schema
--
-- **Die Stadt ist ein Fremdschlüssel und kein Text.** Im alten Schema ist
-- `facts.city` eine Textspalte mit einem Anzeigenamen, nachträglich aus einem
-- Präfix der redaktionellen Nummer gefüllt, und für neue Datensätze darf sie
-- leer sein. Daraus folgt alles, was unter E-56 und E-66 steht, bis hin zu zwei
-- Trophäen, die zu früh erreichbar sind, weil ein Fakt ohne zuordenbare Stadt
-- als eigene Stadt zählt. Hier ist die Stadt `not null` und zeigt auf eine
-- Zeile. Ein Fakt ohne Stadt kann nicht entstehen.
--
-- **Die Kategorie ist ein Fremdschlüssel und kein Freitext.** Siehe Migration 2.
--
-- **Die Texte stehen nicht hier.** Sie stehen in `fact_texts`, eine Zeile je
-- Sprache. Das alte Schema hält Deutsch in flachen Spalten und alles andere in
-- einem `jsonb` namens `_i18n`, mit dem Kommentar „DO NOT reach into `_i18n`
-- directly anywhere else". Ein Feld, das eine Warnung braucht, ist die falsche
-- Form: eine Sprache mehr ist hier eine Zeile und keine Schemaänderung.
create table public.facts (
  id            bigint generated always as identity primary key,
  city_id       text not null references public.cities(id) on delete restrict,
  category_key  text not null references public.fact_categories(key)
                  on update cascade,
  -- Die redaktionelle Nummer, im alten Schema `nr`. Umbenannt, weil `nr` dort
  -- gleichzeitig als Notnagel diente, um die Stadt zu erraten. Sie ist eine
  -- Nummer und keine Herkunftsangabe.
  code          text,
  genre         text,
  zone          smallint,
  quality_score smallint,
  lat           double precision,
  lng           double precision,
  -- Der Farbverlauf des Kopfbereichs, zwei Hexwerte. Im alten Schema ein
  -- `text[]` mit Standardwert; als zwei Spalten kann eine Bedingung sie prüfen.
  hero_from     text not null default '#2C3E50',
  hero_to       text not null default '#4A6741',
  -- Der Radius in Metern, in dem der Fakt einsammelbar ist.
  collect_radius_m integer not null default 150,
  -- Veröffentlicht heißt: für Clients sichtbar. Standardwert falsch, siehe die
  -- Policy unten und E-53.
  is_published  boolean not null default false,
  -- Wer den Fakt eingereicht hat, falls es ein Nutzer war. NULL heißt
  -- redaktionell.
  author_id     uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Koordinaten entweder beide oder keine. Ein Fakt mit halber Koordinate ist
  -- im alten Bestand möglich und in jeder Rechnung ein Sonderfall.
  constraint facts_koordinate_vollstaendig
    check ((lat is null) = (lng is null)),
  constraint facts_lat_range check (lat is null or lat between -90 and 90),
  constraint facts_lng_range check (lng is null or lng between -180 and 180),
  constraint facts_hero_from_format check (hero_from ~ '^#[0-9A-Fa-f]{6}$'),
  constraint facts_hero_to_format check (hero_to ~ '^#[0-9A-Fa-f]{6}$'),
  constraint facts_zone_range check (zone is null or zone between 1 and 3),
  constraint facts_quality_range
    check (quality_score is null or quality_score between 1 and 3),
  constraint facts_radius_range check (collect_radius_m between 10 and 2000)
);

comment on table public.facts is
  'Der Inhalt. Stadt und Kategorie sind Fremdschlüssel, nicht Freitext.';

comment on column public.facts.collect_radius_m is
  'Radius in Metern für das Einsammeln. Der Server prüft ihn, nicht der '
  'Client, siehe Migration 7.';

create unique index facts_code_key on public.facts (code) where code is not null;
create index facts_city_id_idx on public.facts (city_id);
create index facts_category_key_idx on public.facts (category_key);
create index facts_author_id_idx on public.facts (author_id) where author_id is not null;
-- Die Karte fragt „alle veröffentlichten Fakten dieser Stadt". Genau das.
create index facts_stadt_veroeffentlicht_idx
  on public.facts (city_id) where is_published;

create trigger facts_set_updated_at
  before update on public.facts
  for each row execute function app.set_updated_at();

-- ── Texte, eine Zeile je Sprache ────────────────────────────────────────────
create table public.fact_texts (
  fact_id    bigint not null references public.facts(id) on delete cascade,
  lang       text not null,
  title      text not null,
  body       text not null,
  -- Die Vorlage hat bis zu vier Textblöcke je Fakt. Als Spalten und nicht als
  -- weitere Zeilen, weil sie eine Reihenfolge haben und zusammen einen Artikel
  -- bilden.
  body_2     text,
  body_3     text,
  body_4     text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (fact_id, lang),
  constraint fact_texts_lang_format check (lang ~ '^[a-z]{2}$'),
  constraint fact_texts_title_nicht_leer check (length(trim(title)) > 0),
  constraint fact_texts_body_nicht_leer check (length(trim(body)) > 0)
);

comment on table public.fact_texts is
  'Faktentexte je Sprache. Eine Sprache mehr ist eine Zeile, keine '
  'Schemaänderung. Ersetzt die Spalte _i18n des alten Schemas.';

create index fact_texts_lang_idx on public.fact_texts (lang);

create trigger fact_texts_set_updated_at
  before update on public.fact_texts
  for each row execute function app.set_updated_at();

-- ── Quellen ─────────────────────────────────────────────────────────────────
--
-- Im Text stehen Marken wie `[3]`, die auf eine Quelle zeigen. Die Vorlage baut
-- diese Liste an **zwei** Stellen verschieden zusammen, einmal für die Akte und
-- einmal für den Reiseführer. Als Tabelle gibt es sie einmal.
create table public.fact_sources (
  fact_id    bigint not null references public.facts(id) on delete cascade,
  ordinal    smallint not null,
  label      text not null,
  url        text,
  created_at timestamptz not null default now(),

  primary key (fact_id, ordinal),
  constraint fact_sources_ordinal_positiv check (ordinal > 0),
  constraint fact_sources_url_form check (url is null or url ~ '^https?://')
);

comment on table public.fact_sources is
  'Quellen je Fakt, nummeriert wie die Marken im Text.';

-- ── Medien ──────────────────────────────────────────────────────────────────
--
-- Historische Fotos für Damals/Heute und Bilder an Hinweisen. Im alten Schema
-- ist das eine Spalte `hint_media`, die im eingecheckten Schema gar nicht
-- vorkommt und nur existiert, weil die Pipeline sie über die API schreibt.
create table public.fact_media (
  id          bigint generated always as identity primary key,
  fact_id     bigint not null references public.facts(id) on delete cascade,
  kind        text not null,
  url         text not null,
  caption_de  text,
  caption_en  text,
  attribution text,
  source_url  text,
  -- Das Aufnahmejahr, falls bekannt. Damals/Heute zeigt es an.
  taken_year  smallint,
  created_at  timestamptz not null default now(),

  constraint fact_media_kind_erlaubt
    check (kind in ('historical_photo', 'hint_image')),
  constraint fact_media_url_form check (url ~ '^https?://'),
  constraint fact_media_taken_year_range
    check (taken_year is null or taken_year between 1500 and 2100)
);

comment on table public.fact_media is
  'Bilder je Fakt. historical_photo trägt Damals/Heute, hint_image einen '
  'Hinweis.';

create index fact_media_fact_id_idx on public.fact_media (fact_id);

-- ── Hinweise ────────────────────────────────────────────────────────────────
create table public.fact_hints (
  fact_id    bigint not null references public.facts(id) on delete cascade,
  lang       text not null,
  level      smallint not null,
  text       text not null,
  created_at timestamptz not null default now(),

  primary key (fact_id, lang, level),
  constraint fact_hints_lang_format check (lang ~ '^[a-z]{2}$'),
  -- Drei Stufen, wie die Hinweis-Ökonomie sie kennt: kostenlos, dann teurer.
  constraint fact_hints_level_range check (level between 1 and 3)
);

comment on table public.fact_hints is
  'Hinweise je Fakt, Sprache und Stufe. Was eine Stufe kostet, steht in den '
  'Belohnungsregeln und nicht hier.';

-- ── Rätsel, als Inhalt und ausdrücklich ohne Auswertung ─────────────────────
--
-- ## Diese Tabelle ist bewusst dumm
--
-- Am 03.09.2026 hat der Eigentümer das Rätselkonzept angehalten: „Lass den teil
-- erstmal ruhen." Der Grund ist gemessen und steht als E-79: von 1911 Rätseln
-- der Vorlage sind 247 überhaupt richtig zu beantworten. Die Auswertung
-- vergleicht Zeichenketten, und das Feld mit der erwarteten Antwort enthält
-- Lösungsnotizen für Menschen, bis zu einem Aufsatz von über 200 Zeichen. Die
-- 82 Zähl-Rätsel vergleichen gegen null, weil das Zahlenfeld in keiner
-- Datendatei vorkommt.
--
-- **Deshalb speichert diese Tabelle Rätsel als Inhalt und prüft keine Antwort.**
-- Kein `expected`, keine Auswertungsregel, keine Punktevergabe. Die heutige
-- Vergleichslogik einzubauen hieße, genau das festzuschreiben, was gerade neu
-- gedacht wird. Wenn der neue Zuschnitt da ist, ist das eine Migration.
--
-- Was mitkommt, ist die Frage und der Typ, weil das der Inhalt ist, den die
-- Redaktion pflegt.
create table public.fact_puzzles (
  id           bigint generated always as identity primary key,
  fact_id      bigint not null references public.facts(id) on delete cascade,
  kind         text not null,
  difficulty   text not null,
  -- Wie gut das Rätsel ist, aus der Redaktion. Der Jagd-Generator bevorzugt
  -- hohe Werte.
  quality      smallint,
  -- Ob es vor Ort überhaupt findbar ist. Der Generator schließt „nein" aus.
  findability  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint fact_puzzles_difficulty_erlaubt
    check (difficulty in ('leicht', 'mittel', 'schwer')),
  constraint fact_puzzles_quality_range
    check (quality is null or quality between 1 and 3),
  constraint fact_puzzles_findability_erlaubt
    check (findability is null
           or findability in ('gut', 'schwer', 'nicht-findbar'))
);

comment on table public.fact_puzzles is
  'Rätsel als Inhalt. **Keine Auswertung, keine erwartete Antwort.** Das '
  'Konzept ruht seit dem 03.09.2026, siehe E-79 und ADR-010.';

create index fact_puzzles_fact_id_idx on public.fact_puzzles (fact_id);

create table public.fact_puzzle_texts (
  puzzle_id  bigint not null references public.fact_puzzles(id) on delete cascade,
  lang       text not null,
  question   text not null,
  -- Die Musterlösung. Sie wird **angezeigt**, nicht verglichen. Der Name sagt
  -- das, `expected` sagte das Gegenteil.
  solution   text,
  created_at timestamptz not null default now(),

  primary key (puzzle_id, lang),
  constraint fact_puzzle_texts_lang_format check (lang ~ '^[a-z]{2}$')
);

comment on column public.fact_puzzle_texts.solution is
  'Musterlösung zum Anzeigen. Wird nicht mit einer Eingabe verglichen, siehe '
  'E-79.';

-- ── Leserechte ──────────────────────────────────────────────────────────────
alter table public.facts enable row level security;
alter table public.fact_texts enable row level security;
alter table public.fact_sources enable row level security;
alter table public.fact_media enable row level security;
alter table public.fact_hints enable row level security;
alter table public.fact_puzzles enable row level security;
alter table public.fact_puzzle_texts enable row level security;

grant select on public.facts to anon, authenticated;
grant select on public.fact_texts to anon, authenticated;
grant select on public.fact_sources to anon, authenticated;
grant select on public.fact_media to anon, authenticated;
grant select on public.fact_hints to anon, authenticated;
grant select on public.fact_puzzles to anon, authenticated;
grant select on public.fact_puzzle_texts to anon, authenticated;

-- ## Nur Veröffentlichtes, und die Bedingung hängt am Fakt
--
-- Im alten Backend prüft die Einfügeregel für Nutzer-Fakten `created_by` und
-- `is_user_created`, **aber nicht** `is_approved`. Dass der Client `false`
-- setzt, ist Höflichkeit und keine Regel des Servers; wer die Anfrage selbst
-- formuliert, veröffentlicht unmoderierten Text für alle (E-53).
--
-- Hier ist die Freigabe eine Spalte, die kein Client schreiben darf, und jede
-- abhängige Tabelle erbt die Bedingung über den Fakt. Ein unveröffentlichter
-- Fakt hat damit auch keine sichtbaren Texte, Bilder oder Hinweise.
create policy facts_veroeffentlichte_lesbar on public.facts
  for select to anon, authenticated using (is_published);

create policy fact_texts_lesbar on public.fact_texts
  for select to anon, authenticated
  using (exists (select 1 from public.facts f
                 where f.id = fact_id and f.is_published));

create policy fact_sources_lesbar on public.fact_sources
  for select to anon, authenticated
  using (exists (select 1 from public.facts f
                 where f.id = fact_id and f.is_published));

create policy fact_media_lesbar on public.fact_media
  for select to anon, authenticated
  using (exists (select 1 from public.facts f
                 where f.id = fact_id and f.is_published));

create policy fact_hints_lesbar on public.fact_hints
  for select to anon, authenticated
  using (exists (select 1 from public.facts f
                 where f.id = fact_id and f.is_published));

create policy fact_puzzles_lesbar on public.fact_puzzles
  for select to anon, authenticated
  using (exists (select 1 from public.facts f
                 where f.id = fact_id and f.is_published));

create policy fact_puzzle_texts_lesbar on public.fact_puzzle_texts
  for select to anon, authenticated
  using (exists (select 1 from public.fact_puzzles p
                 join public.facts f on f.id = p.fact_id
                 where p.id = puzzle_id and f.is_published));

-- Kein Client schreibt in diese Tabellen. Nutzer-Fakten laufen über eine
-- Funktion, siehe Migration 8.
