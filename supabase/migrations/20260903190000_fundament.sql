-- FACT, Migration 1 von N: das Fundament.
--
-- Legt kein einziges Fachobjekt an. Sie stellt die Grundhaltung her, und zwar
-- **bevor** die erste Tabelle existiert. Das ist der Grund für ihre Reihenfolge:
-- wer Standardrechte erst nachträglich entzieht, hat jede Tabelle dazwischen
-- offen gehabt.
--
-- Entscheidung: ADR-010. Leitplanken: `docs/engineering/security.md` §1 und §4.
--
-- ## Was hier nicht passiert
--
-- Keine Erweiterung wird installiert. `gen_random_uuid()` gehört seit
-- PostgreSQL 13 zum Kern, und dieses Projekt läuft auf 17; `pgcrypto` wäre eine
-- Abhängigkeit für nichts. Groß- und Kleinschreibung von Namen lösen eindeutige
-- Indizes über `lower(...)` und nicht `citext`. Jede nicht installierte
-- Erweiterung ist eine, die nicht aktualisiert, nicht geprüft und nicht
-- verstanden werden muss.

-- ── Ein eigenes Schema für alles, was niemand von außen sehen soll ───────────
--
-- `public` ist über die Daten-API erreichbar, `app` ist es nicht. Hilfsfunktionen
-- und Nachschlagewerke, die kein Client braucht, gehören hierher. Der
-- Unterschied ist keine Kosmetik: was in `public` steht, ist eine öffentliche
-- Schnittstelle, auch wenn niemand es so gemeint hat.
create schema if not exists app;

comment on schema app is
  'Interna. Nicht über die Daten-API erreichbar, siehe ADR-010.';

revoke all on schema app from anon, authenticated;

-- ── Standardrechte entziehen ────────────────────────────────────────────────
--
-- Ohne diese vier Zeilen bekommt **jede künftig angelegte** Tabelle in `public`
-- automatisch Rechte für `anon` und `authenticated`, und die Absicherung
-- besteht dann allein aus RLS. Zwei Schlösser sind besser als eines: erst gibt
-- es kein Recht, dann erlaubt eine Policy einen bestimmten Zugriff.
--
-- Genau diese Doppelung fehlt im alten Backend. Dort ist `user_city_scores` für
-- jeden lesbar **und** vom Besitzer schreibbar (E-16, E-55), und beides hängt
-- an einer einzigen Policy mit `using (true)`.
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on tables from authenticated;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on sequences from authenticated;

-- Funktionen sind der unauffälligste Weg hinein: `execute` ist in PostgreSQL
-- standardmäßig für `public` erlaubt. Im alten Backend sind drei Funktionen
-- ohne Anmeldung erreichbar und nehmen die Nutzerkennung als Parameter (E-52),
-- also darf hier nichts von allein ausführbar sein.
alter default privileges in schema public revoke all on functions from anon;
alter default privileges in schema public revoke all on functions from authenticated;
alter default privileges in schema app revoke all on functions from anon;
alter default privileges in schema app revoke all on functions from authenticated;

-- ── `updated_at` pflegt sich selbst ─────────────────────────────────────────
--
-- Ein Zeitstempel, den der Client mitschickt, ist keiner. `security.md` §1
-- verbietet vertrauenswürdige Zeitstempel aus dem Client, und diese Funktion
-- ist die kleinste Form dieser Regel: der Wert entsteht in der Datenbank.
--
-- **`set search_path = ''` und schema-qualifizierte Namen.** Ohne festgenagelten
-- Suchpfad kann ein Aufrufer einen unqualifizierten Namen auf ein eigenes Objekt
-- zeigen lassen und es mit den Rechten des Funktionseigentümers ausführen. Der
-- Sicherheitsberater von Supabase meldet das als „Function Search Path
-- Mutable", und es gilt für **jede** Funktion in diesem Schema.
create or replace function app.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function app.set_updated_at() is
  'Trigger-Funktion: setzt updated_at auf die Serverzeit. Nie der Client.';
