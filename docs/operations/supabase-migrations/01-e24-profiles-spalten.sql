-- ##########################################################################
-- FACT-Backend, Datei 01 von 8: E-24, Spaltenrechte auf profiles
--
-- Quelle: docs/operations/backend-security-fixes.md, Abschnitt 6, Migration 1.
-- Wörtlich übernommen, mit einer Ergänzung: siehe unten.
--
-- SCHLIESST
--   E-24: coins und score_total sind vom Client direkt setzbar. Die Policy
--   "own profile" begrenzt die Zeile, nicht die Spalte, und ein WITH CHECK
--   ändert daran nichts. Nimmt D-8 mit: das wirkungslose
--   revoke update (ai_used, ai_limit) aus 2026-06-20_ai_proxy.sql:61 greift
--   erst, wenn das tabellenweite UPDATE weg ist.
--
-- PWA DANACH
--   Nichts hört auf zu funktionieren. Die drei Spalten, die Clients heute
--   schreiben, bleiben freigegeben: username und username_changed_at
--   (api.jsx:255), show_real_name (screen-profil.jsx:693). Gesperrt sind ab
--   jetzt id, name, hometown, coins, join_date, created_at, score_total,
--   ai_used und ai_limit.
--
-- VORHER PRÜFEN (99-pruefungen.sql)
--   Abfragen A, B, C und D. D ist die eine Frage aus Befund 4: liefert sie
--   ai_used_updatable = true, war das LLM-Kontingent bis heute per UPDATE
--   zurücksetzbar.
--
-- NACHHER PRÜFEN
--   Abfrage F muss (false, false, false) liefern, Abfrage G muss
--   (true, true, true) liefern. Läuft G rot, ist die Registrierung in beiden
--   Clients stumm kaputt. Negativtests 3, 4, 5 und 31 bis 35 müssen 42501
--   geben, 1, 2 und 7 müssen weiter gelingen.
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
--   Ja. Vor jedem create policy steht ein drop policy if exists, revoke und
--   grant sind wiederholbar. Ein zweiter Lauf macht nichts kaputt.
-- ##########################################################################

-- ============================================================================
-- FACT — E-24: coins und score_total sind vom Client direkt setzbar
-- ----------------------------------------------------------------------------
-- Die Policy "own profile" (supabase-schema.sql:141) begrenzt die ZEILE, nicht
-- die SPALTE. Ein WITH CHECK hilft nicht: PostgreSQL benutzt bei fehlendem
-- WITH CHECK ohnehin den USING-Ausdruck als Prüfung, und WITH CHECK sieht bei
-- UPDATE nur die neue Zeile, kann also "coins darf sich nicht ändern" gar
-- nicht ausdrücken. Spaltenschutz geht über Spaltenrechte.
--
-- Behebt zugleich D-8 (2026-06-20_ai_proxy.sql:61): das dortige
-- "revoke update (ai_used, ai_limit)" ist wirkungslos, solange das
-- tabellenweite UPDATE-Recht steht (Rechte in PostgreSQL sind additiv).
-- Es braucht dafür KEINE eigene Migration, Begründung in Abschnitt 6.1.
--
-- Bricht heute nichts: die einzigen Client-Schreibzugriffe sind
--   02_Frontend/app/api.jsx:255           -> username, username_changed_at
--   02_Frontend/app/screen-profil.jsx:693 -> show_real_name
--   flutter-fact .../supabase_auth_remote_data_source.dart:331 -> username
-- ============================================================================

begin;

-- 1. Tabellenweite Schreibrechte entziehen. Erst danach greifen Spaltenrechte.
--    Das dritte Ziel `public` ist die PUBLIC-Pseudorolle, NICHT das Schema.
--    Ein an PUBLIC vergebenes Recht hält jede Rolle der Datenbank, und ein
--    revoke gegen authenticated und anon entfernt es nicht. Ohne diese Zeile
--    bliebe die Lücke aus D-8 offen, falls im Projekt jemals
--    `grant all on all tables in schema public to public` gelaufen ist.
--    Kostenlos, weil kein Ablauf ein PUBLIC-Schreibrecht auf profiles braucht.
revoke insert, update, delete on public.profiles from authenticated, anon, public;

-- 2. Genau die drei Spalten zurückgeben, die ein Nutzer heute selbst setzt.
grant update (username, username_changed_at, show_real_name)
  on public.profiles to authenticated;

-- Nicht freigegeben und damit nur noch über SECURITY-DEFINER-Funktionen
-- schreibbar: id, name, hometown, coins, join_date, created_at, score_total,
-- ai_used, ai_limit.
--
-- Sobald ein Profil-Bearbeiten-Bildschirm entsteht, hier ergänzen:
--   grant update (name, hometown) on public.profiles to authenticated;

-- 3. Zeilengrenze weiterhin über RLS. Die FOR-ALL-Policy wird durch zwei
--    ausdrückliche ersetzt, damit im Katalog steht, was gilt. Der Insert- und
--    der Delete-Zweig entfallen bewusst: die Zeile legt der Trigger
--    on_auth_user_created an, gelöscht wird sie per ON DELETE CASCADE.
drop policy if exists "own profile" on public.profiles;

create policy "own profile select" on public.profiles
  for select using (auth.uid() = id);

create policy "own profile update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

commit;

-- Ergänzt gegenüber dem Dokument, Begründung im Kopf und in Abschnitt 11.3.
notify pgrst, 'reload schema';
