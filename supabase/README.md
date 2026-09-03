---
id: OPS-SUPABASE
status: accepted
owner: backend
scope:
  - backend
load_when:
  - implementation
  - review
---

# Das Datenbankschema

Hier wohnt das Schema. Nicht als Absichtserklärung, sondern als der Zustand,
aus dem sich die Datenbank von null wieder aufbauen lässt.

**Warum das ein eigener Satz ist:** genau das gab es vorher nicht. Das alte
Backend hatte acht SQL-Dateien mit dem Satz „Run manually in Supabase SQL
Editor" im Kopf, zwei Funktionen doppelt definiert, und niemand konnte sagen,
welche Fassung produktiv läuft. Die vollständige Aufnahme steht in
`docs/operations/backend-inventory.md`, die Entscheidung in
**ADR-010**.

## Die drei Regeln

**1. Jede Schemaänderung ist eine Migration in `migrations/`.** Kein SQL-Editor,
keine Handgriffe an der laufenden Datenbank, keine Ausnahme für „nur schnell
eine Spalte". Das ist Regel vier aus ADR-001 und gilt seit dem 19.07.2026; sie
war bis zum 03.09.2026 nur nicht durchsetzbar.

**2. Der Dateiname bestimmt die Reihenfolge.** Das Werkzeug wendet
`migrations/*.sql` alphabetisch an, deshalb tragen sie einen Zeitstempel als
Präfix. `npx supabase migration new <name>` setzt ihn richtig. Wer eine Datei
von Hand anlegt, riskiert genau den Fehler, an dem das alte Backend hängt: eine
Reihenfolge, die vom Zufall abhängt.

**3. Eine angewandte Migration wird nicht mehr bearbeitet.** Was schon einmal
auf einer Datenbank gelaufen ist, bleibt stehen; eine Korrektur ist eine neue
Migration. Sonst behauptet das Repository etwas anderes als die Datenbank
enthält, und das ist der Zustand, aus dem wir gerade herauskommen.

## Wie geprüft wird

Gate 5 in `.github/workflows/gates.yml` startet ein leeres Postgres und wendet
**alle** Migrationen von null an. Bricht eine, ist der Lauf rot.

**Das läuft nur in der CI, nicht auf dem Entwicklungsrechner.** Grund: die
Prüfung braucht Docker, und auf dem Rechner, auf dem dieses Repository gepflegt
wird, ist keines installiert (gemessen am 03.09.2026). Wer Docker hat, kann sie
lokal fahren:

```bash
npx supabase db start
npx supabase db lint --level warning
```

## Was hier noch nicht steht

`migrations/` ist leer, und das ist der richtige Zustand für heute. ADR-010 ist
**vorgeschlagen und nicht angenommen**; die sieben strukturellen Eigenschaften
darin sind die Entscheidung, und die trifft nicht dieses Verzeichnis.

Was hier schon steht, ist ausschließlich das Gerüst: die Projektdatei, das
Verzeichnis, die Prüfung. Fällt ADR-010 durch, kostet das Löschen dieses
Ordners nichts.

**Die inhaltlichen Zusicherungen stehen seit dem 03.09.2026** in
`tests/zusicherungen.sql` und laufen als Gate 5c. Es sind sechs geworden und
nicht vier:

1. kein Tisch in `public` ohne RLS;
2. keine Policy mit `USING (true)` auf einer Tabelle mit Personenbezug, wobei
   „Personenbezug" abgeleitet wird (Fremdschlüssel auf `auth.users`) und nicht
   aus einer Liste, die jemand pflegen müsste;
3. keine öffentliche Funktion mit einer Nutzerkennung, geprüft über den Typ
   (`uuid`) **und** über den Parameternamen, dazu 3c: jede eigene Funktion
   setzt `search_path`;
4. derselbe Bezug bucht genau einmal, mit einem Konto und zwei Aufrufen, die
   die Prüfung selbst anlegt;
5. jede Sicht hat `security_invoker = true`;
6. `anon` schreibt nirgends, und in Journal und Sammlung schreibt **kein**
   Client, auch nicht der Besitzer.

Der Einwand, der hier vorher stand, war richtig und gilt nur noch für die
vierte: an einer leeren Datenbank wäre sie grün, ohne etwas geprüft zu haben
(Muster 9 des Blindheits-Katalogs). Deshalb legt sie ihre Daten selbst an. Die
anderen fünf lesen den Katalog, und der ist auch ohne eine Zeile Nutzdaten
vollständig.

**Reines SQL statt pgTAP**, mit `psql -v ON_ERROR_STOP=1`. Das spart eine
Erweiterung in der Datenbank und eine zweite Werkzeugkette; wer pgTAP später
will, ersetzt die eine Datei.

## Zum `project_id`

Der steht auf `fact` und nicht auf dem Verzeichnisnamen. `supabase init` setzt
dort das Arbeitsverzeichnis ein, und das hieß beim Anlegen
`fact-flutter-splash-screen-a2bfc9`, weil dieses Repository in Arbeitsbäumen
gepflegt wird. Der Wert unterscheidet lokale Projekte auf demselben Rechner; ein
Arbeitsbaumname darin wäre nicht falsch, aber er würde bei jedem neuen Zweig
anders lauten.
