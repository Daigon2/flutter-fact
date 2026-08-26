/// Rohzeilen, wie PostgREST sie für `public.facts` liefert.
///
/// Die Werte sind aus dem echten Bestand abgeleitet, nicht erfunden: der
/// Grundfall ist `MUC_004` aus `02_Frontend/app/muenchen-data.jsx:25`, die
/// Rätsel stammen aus demselben Datensatz und aus `piran-data.jsx:43` (der
/// einzige Kombi-Fall im Bestand). Deshalb ist [Map] hier bewusst
/// `Map<String, dynamic>`: genau diesen Typ liefert `PostgrestList`, und die
/// Tests sollen an derselben Form arbeiten wie die Produktion.
library;

/// Eine vollständige, heile Rohzeile.
///
/// [overrides] ersetzt oder ergänzt einzelne Spalten, [without] entfernt sie.
/// So bleibt jeder Testfall eine Zeile lang und die Abweichung vom Normalfall
/// steht direkt im Test.
Map<String, dynamic> factRow({
  Map<String, Object?> overrides = const <String, Object?>{},
  Set<String> without = const <String>{},
}) {
  final row = <String, dynamic>{
    'id': 1004,
    'nr': 'MUC_004',
    'titel':
        'Die Glyptothek war eines der ersten Museumsgebäude der Welt – '
        'geplant für Kriegsbeute',
    'text':
        'Als König Ludwig I. 1816 entschied, die Maxvorstadt zum '
        'Kulturzentrum Bayerns zu machen, holte er Leo von Klenze.',
    'text2': null,
    'text3': null,
    'text4': null,
    'kategorie': 'Architektur',
    'genre': 'Architektur',
    'quality_score': 2,
    'lat': 48.14682,
    'lng': 11.56476,
    'ort': 'Glyptothek · Königsplatz',
    'city': 'München',
    'zone': 1,
    'quelle': 'Wikipedia · Stadtarchiv München',
    'caption': '[ Glyptothek · Königsplatz ]',
    '_i18n': <String, dynamic>{},
    'hero': <dynamic>['#1A2030', '#0D1018'],
    'rating': 0,
    'bewertungen': 0,
    'is_user_created': false,
    'is_approved': true,
    'created_by': null,
    'created_at': '2026-05-12T08:14:00+00:00',
    'hint_media': null,
    'next_hints': <dynamic>[
      'Wo antike Träume in Stein erstarrt sind.',
      'Im Herzen der Maxvorstadt.',
      'Am Königsplatz, an der Glyptothek mit der Treppenfassade.',
    ],
    'next_station_hint': null,
    'puzzle_fit': <dynamic>[puzzleRow(), puzzleRowKombi()],
  };
  row.addAll(overrides);
  for (final key in without) {
    row.remove(key);
  }
  return row;
}

/// Ein Rätselobjekt in der Form, die im Bestand überwiegt.
///
/// Aus `muenchen-data.jsx:41`. Enthält das Generierungs-Artefakt
/// `→ ANTWORT_KURZ: 18` in der Frage, weil der echte Bestand es enthält.
Map<String, dynamic> puzzleRow({
  Map<String, Object?> overrides = const <String, Object?>{},
  Set<String> without = const <String>{},
}) {
  final row = <String, dynamic>{
    'type': 'vor-ort',
    'question':
        'Fotografiere die Treppenfassade der Glyptothek frontal – wie viele '
        'breite Stufen führen hinauf zum Eingang?\n\n→ ANTWORT_KURZ: 18',
    'expected': '18',
    'explanation':
        'Die Treppenfassade der Glyptothek hat 18 breite Stufen, die zum '
        'Haupteingang hinaufführen.',
    'hint': null,
    'hints': null,
    'difficulty': 'leicht',
    'gpsRadius': 150,
    'confidence': 'curated',
    'source': 'cowork',
  };
  row.addAll(overrides);
  for (final key in without) {
    row.remove(key);
  }
  return row;
}

/// Das Kombi-Rätsel aus `piran-data.jsx:43`.
///
/// Der einzige Datensatz im Bestand mit `operandA`, `operandB`, `formula` und
/// `expectedResult`. Genau die Felder, die der alte Port verloren hat.
Map<String, dynamic> puzzleRowKombi({
  Map<String, Object?> overrides = const <String, Object?>{},
}) {
  final row = <String, dynamic>{
    'type': 'kombi',
    'question':
        'Am Sockel der Statue sind Reliefs eingraviert. Kombiniere Geburts- '
        'und Sterbejahr: Wie viele Jahre lebte Tartini?',
    'expected': '78 Jahre',
    'explanation': 'Tartini wurde 1692 in Piran geboren und starb 1770.',
    'hint': null,
    'hints': null,
    'difficulty': 'mittel',
    'gpsRadius': 150,
    'confidence': 'curated',
    'source': 'cowork',
    'operandA': <String, dynamic>{
      'hint': 'Geburtsjahr',
      'description': 'Geburtsjahr von der Sockelinschrift',
    },
    'operandB': <String, dynamic>{
      'hint': 'Sterbejahr',
      'description': 'Sterbejahr von der Sockelinschrift',
    },
    'formula': 'b - a',
    'expectedResult': 78,
  };
  row.addAll(overrides);
  return row;
}

/// Ein Auswahlrätsel aus `salzburg-data.jsx`.
///
/// Zeigt zwei Dinge: `choices` als Liste, und dass `type` im Bestand Werte
/// trägt, die `PSZ_TYPE_META` in `puzzle-sheet.jsx:36` nicht kennt.
Map<String, dynamic> puzzleRowMcq() {
  return <String, dynamic>{
    'type': 'mcq',
    'question': 'Welches Ereignis erzwang einen kompletten Neubau?',
    'expected': 'Ein Brand 1818 erzwang Neubau im Klassizismus',
    'hint': 'Vergleiche die schlichte Fassade mit dem Marmorsaal im Inneren',
    'hints': <dynamic>[
      'Vergleiche die schlichte Fassade mit dem Marmorsaal im Inneren',
      'Ein Feuer nach 1800 veränderte das Äußere grundlegend',
    ],
    'difficulty': 'schwer',
    'gpsRadius': 150,
    'confidence': 'curated',
    'source': 'cowork',
    'choices': <dynamic>[
      'Das Schloss ist originaler Barockbau von 1606 ✗',
      'Ein Brand 1818 erzwang Neubau im Klassizismus',
      'Napoleon ließ das Schloss 1810 abreißen ✗',
    ],
  };
}

/// Das `hint_media`-Objekt, wie `enrich_hint_media.py:406` es schreibt.
Map<String, dynamic> hintMediaRow() {
  return <String, dynamic>{
    'url': 'https://upload.wikimedia.org/glyptothek.jpg',
    'thumb_url': 'https://upload.wikimedia.org/glyptothek_800.jpg',
    'width': 3000,
    'height': 2000,
    'caption': 'Glyptothek am Königsplatz, Aufnahme von 1900',
    'source_url': 'https://commons.wikimedia.org/wiki/File:Glyptothek.jpg',
    'license': 'PD-old-70',
    'attribution': 'Unbekannter Fotograf',
    'year': 1900,
    'source': 'wikipedia-source',
  };
}
