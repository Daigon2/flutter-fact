-- ##########################################################################
-- FACT-Backend, Datei 05 von 8: E-53, die Freigabespalte auf facts
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitt 11.5,
-- Migration 5. Wörtlich übernommen, mit einer Ergänzung: siehe unten.
--
-- SCHLIESST
--   E-53. Die Insert-Policy auf facts prüfte created_by und is_user_created,
--   aber nicht is_approved. Dass api.jsx:176 dort false schickt, war eine
--   Höflichkeit des Clients: wer die Anfrage selbst formuliert,
--   veröffentlicht unmoderierten Text für alle Nutzer, auch für anon. Dazu
--   werden die Schreibrechte auf facts auf INSERT für authenticated
--   reduziert.
--
-- NICHT ENTHALTEN
--   Der optionale Block 5b (rating, bewertungen, nr und city zusätzlich
--   sperren) und das Rezept für ein späteres Bearbeiten. Beides steht in
--   Abschnitt 11.5; 5b ist dort ausdrücklich nicht Teil von Migration 5, weil
--   es den Tag verteuert, an dem ein Client eine Stadt mitgeben soll.
--
-- PWA DANACH
--   Nichts hört auf zu funktionieren: api.jsx:165-177 schickt created_by =
--   eigene userId, is_user_created = true, is_approved = false. Was aufhört:
--   ein Insert mit is_approved = true wird mit 42501 abgewiesen. UPDATE und
--   DELETE auf facts sind danach für authenticated, anon und PUBLIC entzogen;
--   sie waren ohne passende Policy schon vorher wirkungslos. SELECT bleibt
--   unberührt, die PWA hängt an api.jsx:178 ein .select() an das Insert.
--
-- VORHER PRÜFEN (99-pruefungen.sql)
--   Abfragen M und O. O liefert bewusst nur eine Liste zum Durchsehen: ob ein
--   Admin oder der Client selbst freigegeben hat, ist in den Daten nicht
--   unterscheidbar, weil kein Protokoll darüber existiert (E-58). Eine Zeile
--   dort bedeutet also nicht Missbrauch.
--
-- NACHHER PRÜFEN
--   Abfrage S. Erwartet: insert true, update false, delete false, select
--   true, ins_anon false, und die with_check-Klausel der Policy muss
--   is_approved nennen. Negativtests 49 bis 55; 50 ist der Kernfall, 49 und
--   55 sind die Nichtbruch-Tests. Test 56 gilt nur, wenn 5b lief, und 5b ist
--   hier nicht dabei.
--
-- ERGÄNZT GEGENÜBER DEM DOKUMENT
--   notify pgrst, 'reload schema'; am Ende. Diese Datei ändert Tabellen- und
--   Spaltenrechte, und PostgREST leitet daraus ab, welche Spalten eine Anfrage
--   schreiben darf; auch das steht im Schemacache. Ohne die Zeile kann eine
--   entzogene Spalte für die API weiter als schreibbar gelten. Am 02.09.2026
--   entschieden, festgehalten in Abschnitt 11.3 und in Eintrag 9 von
--   Abschnitt 13 des Dokuments.
--
-- IDEMPOTENZ
--   Ja. drop policy if exists vor create policy, wiederholbare revoke und
--   grant.
-- ##########################################################################

-- ============================================================================
-- FACT — E-53: Nutzer-Fakten können sich selbst freigeben
-- ----------------------------------------------------------------------------
-- Ist-Zustand: supabase-schema.sql:149-150. Die Insert-Policy prüft created_by
-- und is_user_created, aber nicht is_approved. Dass api.jsx:176 dort `false`
-- schickt, ist eine Höflichkeit des Clients. Wer die Anfrage selbst
-- formuliert, veröffentlicht unmoderierten Text für alle Nutzer, inklusive
-- anon (Lese-Policy :145-146).
--
-- WARUM HIER KEINE SPALTENRECHTE, anders als in Migration 1: bei INSERT sieht
-- WITH CHECK die neue Zeile und kann den Wert der Spalte prüfen. Der Umweg aus
-- Abschnitt 3 ist für UPDATE nötig, wo es eine alte Zeile gibt. Er wäre hier
-- sogar schädlich: die PWA nennt is_approved namentlich (api.jsx:176), ein
-- `revoke insert (is_approved)` würde diesen richtigen Aufruf mit 42501
-- abweisen.
--
-- `is not true` statt `= false`: is_approved ist nullable
-- (supabase-schema.sql:33). Eine ausdrückliche NULL soll nicht abgewiesen
-- werden, denn sie ist harmlos. Die Lese-Policy verlangt `= true`, und der
-- Admin filtert in JavaScript mit `!f.is_approved` (admin/index.html:1164),
-- behandelt NULL also als "offen". Eine NULL-Zeile ist damit unsichtbar und
-- trotzdem moderierbar.
--
-- Bricht heute nichts: api.jsx:165-177 schickt created_by = eigene userId,
-- is_user_created = true, is_approved = false. Alle drei Bedingungen erfüllt.
-- ============================================================================

begin;

-- 1. Policy ersetzen. Gleicher Name, damit der Katalog danach eine Policy
--    dieses Namens hat und nicht zwei.
drop policy if exists "insert own fact" on public.facts;

create policy "insert own fact" on public.facts
  for insert with check (
    auth.uid() = created_by
    and is_user_created = true
    and is_approved is not true
  );

-- 2. Schreibrechte auf das reduzieren, was ein Client braucht. Reihenfolge wie
--    in Migration 1: erst tabellenweit entziehen, dann ausdrücklich
--    zurückgeben. Nicht auf einen vorhandenen Grant vertrauen, sonst hängt das
--    Ergebnis daran, ob authenticated sein INSERT einzeln oder über PUBLIC
--    hält, und das weiß aus dem Repository niemand.
revoke insert, update, delete on public.facts from authenticated, anon, public;
grant insert on public.facts to authenticated;

-- UPDATE und DELETE bleiben entzogen, und zwar für alle drei Empfänger. Sie
-- sind heute ohnehin wirkungslos, weil es auf facts keine UPDATE- und keine
-- DELETE-Policy gibt: ein Nutzer kann seinen Fakt nicht bearbeiten und nicht
-- löschen. Der Entzug hält den Zustand fest, statt ihn von der Abwesenheit
-- einer Policy abhängig zu machen. Wer später ein Bearbeiten baut, braucht
-- beides, und dann steht die Entscheidung ausdrücklich an, statt sich aus
-- einem alten Default zu ergeben.
--
-- SELECT bleibt unberührt: die PWA hängt an api.jsx:178 ein .select() an das
-- Insert und braucht es. Die Lese-Policy :145-146 deckt den eigenen, noch
-- nicht freigegebenen Fakt ab.

commit;

-- Ergänzt gegenüber dem Dokument, Begründung im Kopf und in Abschnitt 11.3.
notify pgrst, 'reload schema';
