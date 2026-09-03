-- FACT, Migration 7: Stammdaten.
--
-- Kategorien, Aliasse, Städte, Belohnungsbeträge. Alles hier ist **abgeschrieben
-- und nicht erfunden**; jede Zeile hat eine Fundstelle, und wo eine Zahl
-- widersprüchlich belegt ist, steht der Widerspruch dabei.
--
-- Warum in einer Migration und nicht in `seed.sql`: `seed.sql` läuft nur beim
-- lokalen Zurücksetzen, nicht beim Deploy. Diese Zeilen sind aber
-- Voraussetzung dafür, dass ein Fakt überhaupt angelegt werden kann, denn
-- `facts.city_id` und `facts.category_key` sind Fremdschlüssel.

-- ── Kategorien ──────────────────────────────────────────────────────────────
--
-- Zeichen und Farben aus `02_Frontend/app/screen-map.jsx:195-208` (`CAT`), die
-- Namen aus `translations.jsx` über die erzeugten i18n-Tabellen. Die
-- Schriftzeichen der Spalte `glyph` aus `wallet-colors.jsx:75-85`
-- (`WalletCats`); nur sechs Kategorien haben eines, für die anderen hat die
-- Vorlage keines.
--
-- ## Eine Reihenfolge statt zwei, und das ändert etwas Sichtbares
--
-- Die Vorlage hat **zwei** Reihenfolgen für dasselbe: `CAT` ordnet zwölf
-- Kategorien für die Karte, `WalletCatOrder` ordnet sechs Kapitel für den
-- Reiseführer, und die beiden stimmen nicht überein. `sort_order` hier ist
-- **eine** Reihenfolge, die der Karte.
--
-- **Folge, und sie ist gewollt:** die Kapitel im Reiseführer stehen damit in
-- anderer Folge als bisher, und ihre römischen Zahlen verschieben sich. Bei
-- einer neuen Datenbank ohne Nutzer kostet das nichts, und es ist genau das,
-- was „eine einzige Wahrheit" bedeutet. Der Client hat dafür heute noch eine
-- eigene Liste; die zieht nach.
--
-- ## `nat` zeigt auf `geo`, alles andere auf sich selbst
--
-- Das ist die einzige Zeile, in der `chapter_key` nicht der eigene Schlüssel
-- ist, und sie ersetzt eine Präfixregel im Client
-- (`if (k.startsWith('natur')) return 'geo'`). Eine redaktionelle Entscheidung
-- der Vorlage, hier als Spalte statt als Programmzeile.
insert into public.fact_categories
  (key, name_de, name_en, colour, colour_dark, emoji, glyph, chapter_key, sort_order)
values
  ('hist',   'Historisch',         'Historical',      '#E8380D', '#A82508', '🏛',  '§',  'hist',   1),
  ('myth',   'Mythos',             'Myth',            '#A855F7', '#7C3AC0', '⚡',  '☾',  'myth',   2),
  ('fun',    'Fun-Fact',           'Fun Fact',        '#F5C518', '#C49A0A', '😄',  '✸',  'fun',    3),
  ('geo',    'Geografie',          'Geography',       '#00C2A8', '#007A6B', '🗺',  '△',  'geo',    4),
  ('arch',   'Architektur',        'Architecture',    '#3B82F6', '#1D4ED8', '🗼',  '⌂',  'arch',   5),
  ('kul',    'Kulinarik',          'Culinary',        '#F97316', '#C2410C', '🍺',  null, 'kul',    7),
  ('pers',   'Persönlichkeiten',   'People',          '#D946EF', '#A21CAF', '👤',  null, 'pers',   8),
  ('kult',   'Kunst & Kultur',     'Art & Culture',   '#F59E0B', '#B45309', '🎭',  null, 'kult',   9),
  ('dark',   'Dunkel & Kriminell', 'Dark & Criminal', '#64748B', '#1E293B', '☠️',  null, 'dark',  10),
  ('kirche', 'Kirche & Glaube',    'Church & Faith',  '#818CF8', '#4338CA', '⛪',  null, 'kirche',11),
  ('heute',  'Stadt heute',        'City Today',      '#EC4899', '#BE185D', '📸',  '◉',  'heute', 12);

-- `nat` gesondert, weil sein `chapter_key` auf `geo` zeigt und `geo` deshalb
-- vorher existieren muss.
insert into public.fact_categories
  (key, name_de, name_en, colour, colour_dark, emoji, glyph, chapter_key, sort_order)
values
  ('nat', 'Natur', 'Nature', '#22C55E', '#15803D', '🌿', null, 'geo', 6);

-- ── Aliasse der Pipeline ────────────────────────────────────────────────────
--
-- Die zweiunddreißig Kategorietexte aus `screen-map.jsx:211-256` (`KAT_MAP`).
-- Vollständig, damit ein Import nicht stillschweigend auf „Historisch" fällt.
--
-- Die Schlüssel sind kleingeschrieben, und die Suche beim Import
-- kleinschreibend: `Stadt heute` und `Stadt Heute` sind derselbe Text, und zwei
-- Zeilen dafür wären zwei Wahrheiten.
insert into public.fact_category_aliases (alias, category_key) values
  ('historisch',         'hist'),
  ('historical',         'hist'),
  ('geschichte',         'hist'),
  ('historical figures', 'pers'),
  ('persönlichkeiten',   'pers'),
  ('personalities',      'pers'),
  ('architektur',        'arch'),
  ('architecture',       'arch'),
  ('fun-fact',           'fun'),
  ('fun fact',           'fun'),
  ('geografie',          'geo'),
  ('geographie',         'geo'),
  ('mythos',             'myth'),
  ('mythen',             'myth'),
  ('myth & legend',      'myth'),
  ('natur',              'nat'),
  ('nature',             'nat'),
  ('kulinarik',          'kul'),
  ('kulinarisch',        'kul'),
  ('food & drink',       'kul'),
  ('kultur',             'kult'),
  ('kunst & kultur',     'kult'),
  ('art & culture',      'kult'),
  ('dunkel & kriminell', 'dark'),
  ('dark & criminal',    'dark'),
  ('dark history',       'dark'),
  ('kirche & glaube',    'kirche'),
  ('church & faith',     'kirche'),
  ('stadt heute',        'heute'),
  ('city today',         'heute'),
  ('today',              'heute'),
  ('aktuell',            'heute');

-- ── Städte ──────────────────────────────────────────────────────────────────
--
-- Die fünf mit eigener Ausstattung aus `wallet-colors.jsx:4-56`
-- (`WalletCities`), die Mittelpunkte aus `screen-map.jsx:310-323` (`CITIES`).
--
-- **Alle fünf stehen auf `is_active = false`.** Eine Stadt wird sichtbar, weil
-- jemand sie freigibt, und die Fakten sind zum Zeitpunkt dieser Migration noch
-- nicht importiert. Eine aktive Stadt ohne Inhalt wäre ein leeres Regal mit
-- Namen.
--
-- Die Bandnummern sind die der Vorlage: München 1, Rom 2, Regensburg 3,
-- Passau 4, Weimar 5. Sie stimmen mit der Regalfolge nicht überein, und das
-- ist so belegt.
insert into public.cities
  (id, name_de, name_en, country, region_de, region_en,
   centre_lat, centre_lng, volume_no, is_active)
values
  ('muenchen',   'München',    'Munich',     'DE',
   'Bayern · Hauptstadt',    'Bavaria · Capital',        48.1351, 11.5820, 1, false),
  ('rom',        'Rom',        'Rome',       'IT',
   'Italien · Latium',       'Italy · Lazio',            41.8960, 12.4822, 2, false),
  ('regensburg', 'Regensburg', 'Regensburg', 'DE',
   'Bayern · Oberpfalz',     'Bavaria · Upper Palatinate', 49.0134, 12.1016, 3, false),
  ('passau',     'Passau',     'Passau',     'DE',
   'Bayern · Dreiflüsseeck', 'Bavaria · Three Rivers',   48.5736, 13.4319, 4, false),
  ('weimar',     'Weimar',     'Weimar',     'DE',
   'Thüringen · Klassik',    'Thuringia · Classicism',   50.9795, 11.3235, 5, false);

-- ── Belohnungsbeträge ───────────────────────────────────────────────────────
--
-- ## Woher die Zahlen kommen, und wo sie sich widersprechen
--
-- **Münzen fürs Sammeln: 50.** Belegt in `app.jsx:712-714`:
-- `Storage.addCoins(50)` und `Api.addCoins(userId, 50)`. Es gibt einen
-- **Widerspruch** dazu: die vorbereitete Migration
-- `docs/operations/supabase-migrations/03-e23-collected-facts.sql` trägt im
-- Kopf die Warnung, dass sie die Sammelbelohnung stillschweigend von 50 auf 10
-- senkt. Genommen ist der Wert, der **läuft**. Welcher gelten soll, ist eine
-- Produktentscheidung und keine Migrationsfrage.
--
-- **Erfahrung: abgeleitet und deshalb hier als Betrag.**
-- `storage.jsx:226-227`: `computeXP = collected * 10 + created * 50 +
-- streak * 5`. In der Vorlage ist das eine Formel über Zählwerte; im Journal
-- ist es dasselbe Ergebnis als Summe von Buchungen, weil jede Buchung ihren
-- Beitrag mitbringt. Der Vorteil: die Summe kann von ihren Ursachen nicht
-- abweichen.
--
-- **Hinweise: 0, 20, 30.** Aus der Hinweis-Ökonomie, negativ eingetragen, weil
-- ein Hinweis kostet. Die erste Stufe ist kostenlos, und das ist ein Betrag
-- von null und kein Sonderfall im Code.
insert into public.reward_kinds (key, coins, xp, is_repeatable, description) values
  ('fact_collected', 50,  10, false,
   'Einen Fakt eingesammelt. Bezug: fact:<id>.'),
  ('fact_created',    0,  50, false,
   'Einen eigenen Fakt eingereicht. Bezug: fact:<id>.'),
  ('streak_day',      0,   5, false,
   'Ein Tag Serie. Bezug: day:<datum>.'),
  ('hint_level_1',    0,   0, false,
   'Erste Hinweisstufe, kostenlos. Bezug: fact:<id>.'),
  ('hint_level_2',  -20,   0, false,
   'Zweite Hinweisstufe. Bezug: fact:<id>.'),
  ('hint_level_3',  -30,   0, false,
   'Dritte Hinweisstufe. Bezug: fact:<id>.');
