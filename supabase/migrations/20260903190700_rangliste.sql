-- FACT, Migration 8: die Rangliste.
--
-- Eine Funktion und keine Tabelle, und sie gibt **keine Kontokennung** heraus.
--
-- Entscheidung: ADR-010. Setzt die Antworten zu E-16 vom 02.09.2026 um.

-- ── Was hier umgesetzt wird, im Wortlaut der Entscheidung ───────────────────
--
-- **Die Rangliste ist auch ohne Anmeldung sichtbar**, mit Rang und
-- Punktestand. Das war zunächst anders entschieden und am 02.09.2026
-- zurückgenommen: die PWA hat dort keine Anmeldeschranke, und der Verlust sähe
-- wie ein Fehler aus.
--
-- **Keine Städtenamen, außer für die besten zehn je Stadt.** Ein Nutzername in
-- einer Stadt-Top-10 heißt „hat dort gesammelt": kein Zeitpunkt, kein Ort
-- innerhalb der Stadt, keine Häufigkeit. Eine vollständige Städteliste je
-- Person wäre ein Bewegungsprofil, und deshalb gibt es sie nicht.
--
-- **Es gibt nur einen Username.** Kein echter Name, kein Schalter dafür. Der
-- Schalter „Echten Namen zeigen" existiert im Neubau nicht, siehe Migration 3.
--
-- **`is_me` statt `user_id`.** Das ist die eigentliche Behebung von E-16b: die
-- alte Rangliste gibt Konto-UUIDs heraus, ohne jede Hürde, damit ein
-- Verzeichnis aller Konten. Der Client braucht die Kennung nicht, er braucht
-- die Antwort auf „bin das ich".

create or replace function public.get_leaderboard(
  p_city_id text default null,
  p_limit   integer default 50
)
returns table (
  rank     integer,
  username text,
  score    integer,
  is_me    boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with punkte as (
    select
      l.user_id,
      sum(l.xp)::integer as score
    from public.reward_ledger l
    where p_city_id is null or l.city_id = p_city_id
    group by l.user_id
    having sum(l.xp) > 0
  )
  select
    (row_number() over (order by p.score desc, pr.username asc))::integer,
    pr.username,
    p.score,
    p.user_id = auth.uid()
  from punkte p
  join public.profiles pr on pr.id = p.user_id
  order by p.score desc, pr.username asc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

comment on function public.get_leaderboard(text, integer) is
  'Rangliste, gesamt oder je Stadt. Gibt Rang, Username, Punktestand und '
  'is_me heraus, aber **keine Kontokennung**, siehe E-16.';

-- ## `having sum(l.xp) > 0`
--
-- Wer nichts gesammelt hat, steht nicht in der Liste. Im alten Backend zählt
-- `where score > 0` an anderer Stelle den Schlüssel `unknown` als eigene Stadt
-- mit (E-66); dieses Schema hat kein `unknown`, weil `facts.city_id` nicht
-- leer sein kann.

-- ## Warum `security definer` und trotzdem sicher
--
-- Die Funktion liest `reward_ledger`, und dessen Zeilenregel lässt jeden nur
-- die eigenen Buchungen sehen. Eine Rangliste braucht die Summen aller, also
-- muss sie mehr dürfen als ihr Aufrufer.
--
-- Das ist genau der Fall, für den `security definer` gedacht ist, und er ist
-- hier sicher, weil die Funktion **keine Parameter hat, mit denen man Zeilen
-- auswählen könnte**. Sie nimmt eine Stadt und eine Länge, keine
-- Nutzerkennung. Wer sie aufruft, kann nichts erfragen, was sie nicht ohnehin
-- allen zeigt.
--
-- Der Unterschied zu E-52 liegt genau dort: die alten Funktionen nehmen die
-- Kennung als Argument und handeln damit als jemand anderes.

grant execute on function public.get_leaderboard(text, integer)
  to anon, authenticated;

-- ── Die Städte, in denen jemand gesammelt hat, für ihn selbst ───────────────
--
-- Der Reisepass im Profil zeigt die eigene Städtezahl. Für **sich selbst** darf
-- man alles sehen, für andere nur die Zahl. Deshalb ist das eine eigene
-- Funktion und keine Spalte in der Rangliste.
create or replace function public.get_my_cities()
returns table (city_id text, score integer, collected integer)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    l.city_id,
    sum(l.xp)::integer as score,
    count(*) filter (where l.kind = 'fact_collected')::integer as collected
  from public.reward_ledger l
  where l.user_id = auth.uid() and l.city_id is not null
  group by l.city_id
  order by sum(l.xp) desc;
$$;

comment on function public.get_my_cities() is
  'Die eigenen Städte. security invoker, damit die Zeilenregel des Journals '
  'gilt und niemand die Städte eines anderen erfragen kann.';

grant execute on function public.get_my_cities() to authenticated;
