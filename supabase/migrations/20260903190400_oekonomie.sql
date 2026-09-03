-- FACT, Migration 5: Sammlung, Belohnungsregeln, Buchungsjournal.
--
-- Das Herzstück, und die Migration, in der die meisten Befunde des alten
-- Backends nicht behoben, sondern **unmöglich** werden.
--
-- Entscheidung: ADR-010, Eigenschaften drei, fünf und sechs.
-- Leitplanke: `security.md` §1, „Der Client bestimmt nie einen gutgeschriebenen
-- Betrag" und „Der Client rechnet keine Zeit, an der eine Belohnung hängt".

-- ── Belohnungsarten: die Beträge sind Zeilen, nicht Code ────────────────────
--
-- ## Warum eine Tabelle und kein Trigger mit Zahlen darin
--
-- Im alten Backend liegen Ökonomie und Trophäenlogik in einem Trigger von 120
-- Zeilen, mit fest verdrahteten Schwellen, Kategorie-Präfixen und Stadtnamen.
-- Eine Schwelle zu ändern heißt dort, eine Funktion neu zu schreiben, und
-- dabei ist am 14.05.2026 die Sammelbelohnung stillschweigend von 50 auf 10
-- gefallen, ohne dass es jemand gemerkt hat.
--
-- **Hier ist ein Betrag eine Zeile.** Ändern ist ein `update`, keine Migration.
-- Was dabei ausdrücklich **nicht** passiert: die Zahlen werden nicht neu
-- erfunden. Sie sind die des Bestands, bis jemand anders entscheidet.
create table public.reward_kinds (
  key           text primary key,
  coins         integer not null default 0,
  xp            integer not null default 0,
  -- Ob dieselbe Bezugsgröße mehrfach gutgeschrieben werden darf. Für fast alles
  -- falsch, und das ist der Sinn: siehe die Eindeutigkeit im Journal.
  is_repeatable boolean not null default false,
  description   text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint reward_kinds_key_format check (key ~ '^[a-z][a-z0-9_]{2,47}$'),
  constraint reward_kinds_coins_range check (coins between -10000 and 10000),
  constraint reward_kinds_xp_range check (xp between -10000 and 10000)
);

comment on table public.reward_kinds is
  'Was eine Belohnung wert ist. Der Client nennt nie einen Betrag, er nennt '
  'höchstens eine Art, siehe security.md §1.';

create trigger reward_kinds_set_updated_at
  before update on public.reward_kinds
  for each row execute function app.set_updated_at();

-- ── Das Buchungsjournal ─────────────────────────────────────────────────────
--
-- ## Die eine Eigenschaft, die drei Befunde erledigt
--
-- Münzen und Erfahrungspunkte sind **keine Zähler**. Sie sind die Summe der
-- Zeilen dieser Tabelle. Ein Zähler kann hochgesetzt werden, eine Summe nicht;
-- man kann nur eine Zeile hinzufügen, und die trägt ihren Grund mit.
--
-- Und dann die Zeile, auf die es ankommt:
--
--     unique (user_id, kind, ref)
--
-- Damit ist **dieselbe Belohnung für dieselbe Sache zweimal unmöglich**, nicht
-- unwahrscheinlich. Kein Vergleich, den jemand vergessen kann, keine Prüfung,
-- die unter Last durchrutscht. Die Datenbank lässt es nicht zu.
--
-- Was damit wegfällt:
--
-- * **E-69**, wiederholtes Antippen desselben Fakts schreibt jedes Mal 50
--   Münzen gut. Zweiter Versuch verletzt die Eindeutigkeit.
-- * **E-54**, Münzen sind über Gruppensitzungen unbegrenzt farmbar, weil
--   dieselbe Sammlung in mehreren Sitzungen zählt. Die Bezugsgröße ist der
--   Fakt, nicht die Sitzung.
-- * **E-06**, die Gutschrift ist vom Client aufrufbar. Es gibt kein `insert`
--   für Clients, siehe unten.
--
-- `ref` ist absichtlich Text und keine Fremdschlüsselspalte: eine Belohnung
-- kann sich auf einen Fakt, eine Jagd, eine Trophäe oder einen Tag beziehen,
-- und eine Spalte je Art wäre eine Tabelle mit lauter leeren Feldern. Die Form
-- ist `art:kennung`, etwa `fact:412`.
create table public.reward_ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null references public.reward_kinds(key) on update cascade,
  ref        text not null,
  coins      integer not null,
  xp         integer not null,
  -- Für die Rangliste je Stadt. Nullfähig, weil nicht jede Belohnung zu einer
  -- Stadt gehört.
  city_id    text references public.cities(id) on delete set null,
  -- Die Serverzeit. Kein Client schickt hier etwas.
  created_at timestamptz not null default now(),

  constraint reward_ledger_ref_form check (ref ~ '^[a-z_]+:[A-Za-z0-9_.:-]+$'),
  unique (user_id, kind, ref)
);

comment on table public.reward_ledger is
  'Append-only. Münzen und Erfahrung sind die Summe dieser Zeilen. Die '
  'Eindeutigkeit über (user_id, kind, ref) macht doppeltes Gutschreiben '
  'unmöglich, siehe E-06, E-54, E-69.';

comment on column public.reward_ledger.ref is
  'Worauf sich die Buchung bezieht, in der Form art:kennung, etwa fact:412.';

create index reward_ledger_user_id_idx on public.reward_ledger (user_id);
create index reward_ledger_user_city_idx
  on public.reward_ledger (user_id, city_id) where city_id is not null;

-- ── Der Kontostand ──────────────────────────────────────────────────────────
--
-- Eine Sicht und keine Spalte. Damit kann kein Kontostand von der Summe seiner
-- Buchungen abweichen, und das ist eine Eigenschaft, die man sonst mit einem
-- nächtlichen Abgleich erkauft.
--
-- **`security_invoker = true` ist die wichtige Hälfte dieser Anweisung.** Ohne
-- sie läuft eine Sicht mit den Rechten ihres Eigentümers, umgeht also die
-- Zeilenregeln der darunterliegenden Tabelle, und jeder sähe jeden Kontostand.
-- Genau diese Voreinstellung ist eine bekannte Falle, und sie ist einer der
-- Punkte, die das deklarative Schema von Supabase ausdrücklich **nicht**
-- mitzieht.
create view public.user_balances
with (security_invoker = true)
as
select
  l.user_id,
  coalesce(sum(l.coins), 0)::integer as coins,
  coalesce(sum(l.xp), 0)::integer    as xp
from public.reward_ledger l
group by l.user_id;

comment on view public.user_balances is
  'Kontostand als Summe des Journals. security_invoker, damit die '
  'Zeilenregeln des Journals gelten.';

create view public.user_city_scores
with (security_invoker = true)
as
select
  l.user_id,
  l.city_id,
  coalesce(sum(l.xp), 0)::integer as score
from public.reward_ledger l
where l.city_id is not null
group by l.user_id, l.city_id;

comment on view public.user_city_scores is
  'Punktestand je Stadt, abgeleitet. Im alten Backend eine Tabelle, die vom '
  'Besitzer schreibbar war (E-55).';

-- ── Die Sammlung ────────────────────────────────────────────────────────────
--
-- ## Der Primärschlüssel ist die Abwehr
--
-- `primary key (user_id, fact_id)`: derselbe Fakt kann von derselben Person
-- nicht zweimal gesammelt werden. Das ist dieselbe Idee wie die Eindeutigkeit
-- im Journal, eine Ebene früher.
--
-- ## Gesammelt ist gelesen
--
-- Am 03.09.2026 entschieden: „Ja, gesammelt ist gelesen! man sammelt etwas und
-- fertig." Deshalb gibt es **eine** Zeit und nicht zwei Listen. Die Vorlage
-- führt `collected` und `readHistory` getrennt, ohne das irgendwo als Absicht
-- zu benennen. Siehe E-80.
--
-- `collected_at` ist die Serverzeit, nicht die des Geräts.
create table public.collected_facts (
  user_id      uuid not null references auth.users(id) on delete cascade,
  fact_id      bigint not null references public.facts(id) on delete cascade,
  collected_at timestamptz not null default now(),

  primary key (user_id, fact_id)
);

comment on table public.collected_facts is
  'Was jemand gesammelt hat, mit Serverzeit. Gesammelt ist gelesen (E-80). '
  'Der Primärschlüssel macht doppeltes Sammeln unmöglich.';

-- Für „meine Sammlung, neueste zuerst" und für die Plausibilitätsprüfung beim
-- Einsammeln, die den vorigen Zeitpunkt braucht.
create index collected_facts_user_zeit_idx
  on public.collected_facts (user_id, collected_at desc);
create index collected_facts_fact_id_idx on public.collected_facts (fact_id);

-- ── Merkliste ───────────────────────────────────────────────────────────────
--
-- Die einzige Tabelle dieser Migration, in die ein Client direkt schreiben
-- darf, und der Grund dafür ist, dass an ihr keine Belohnung hängt. Merken ist
-- eine Vorliebe und kein Anspruch.
create table public.saved_facts (
  user_id  uuid not null references auth.users(id) on delete cascade,
  fact_id  bigint not null references public.facts(id) on delete cascade,
  saved_at timestamptz not null default now(),

  primary key (user_id, fact_id)
);

comment on table public.saved_facts is
  'Merkliste. Direkt schreibbar, weil daran keine Belohnung hängt.';

create index saved_facts_user_zeit_idx
  on public.saved_facts (user_id, saved_at desc);

-- ── Rechte und Regeln ───────────────────────────────────────────────────────
alter table public.reward_kinds enable row level security;
alter table public.reward_ledger enable row level security;
alter table public.collected_facts enable row level security;
alter table public.saved_facts enable row level security;

-- Die Regeln darf jeder lesen. Was ein Fakt wert ist, ist kein Geheimnis, und
-- die App zeigt es an, bevor jemand sammelt.
grant select on public.reward_kinds to anon, authenticated;
create policy reward_kinds_lesbar on public.reward_kinds
  for select to anon, authenticated using (true);

-- ## Das Journal: lesen ja, schreiben nein
--
-- **Kein `insert`, kein `update`, kein `delete` für irgendeinen Client.** Auch
-- nicht für den Besitzer. Gebucht wird ausschließlich über die Funktionen in
-- Migration 6, und die leiten den Betrag selbst ab.
--
-- Das ist der Unterschied zu E-55, wo `user_city_scores` und `user_trophies`
-- vom Besitzer schreibbar sind: wer seinen eigenen Punktestand schreiben darf,
-- hat keinen Punktestand, sondern ein Textfeld.
grant select on public.reward_ledger to authenticated;
create policy reward_ledger_eigenes_lesbar on public.reward_ledger
  for select to authenticated using ((select auth.uid()) = user_id);

grant select on public.user_balances to authenticated;
grant select on public.user_city_scores to authenticated;

-- Die Sammlung: lesen darf der Besitzer, schreiben niemand direkt.
grant select on public.collected_facts to authenticated;
create policy collected_facts_eigenes_lesbar on public.collected_facts
  for select to authenticated using ((select auth.uid()) = user_id);

-- Die Merkliste: der Besitzer darf alles vier.
grant select, insert, delete on public.saved_facts to authenticated;
create policy saved_facts_eigenes_lesbar on public.saved_facts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy saved_facts_eigenes_anlegen on public.saved_facts
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy saved_facts_eigenes_loeschen on public.saved_facts
  for delete to authenticated using ((select auth.uid()) = user_id);
