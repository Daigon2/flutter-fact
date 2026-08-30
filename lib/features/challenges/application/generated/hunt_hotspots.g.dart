// ERZEUGT von tool/generate_curated_data.dart aus
// 02_Frontend/app/hunt-hotspots.js. Nicht von Hand bearbeiten.
//
// Drift prüfen: dart run tool/generate_curated_data.dart --check
// Neu erzeugen: dart run tool/generate_curated_data.dart

/// Ein Hotspot, wörtlich wie in der Quelle.
///
/// `density` bleibt die rohe Zeichenkette (`sehr hoch`, `hoch`, `mittel`).
/// Ihre Abbildung auf eine Beschriftung steht in `hunt_start_options.dart`
/// und ist dort mit Tests festgenagelt.
typedef HuntHotspotRecord = ({
  String name,
  double latitude,
  double longitude,
  String density,
});

/// Die Hotspots je Stadt. Der Schlüssel ist **wörtlich der aus der Quelle**,
/// also der deutsche Anzeigename. Nicht normalisiert: das passiert an genau
/// einer Stelle in `hunt_hotspot.dart`, siehe E-11.
const Map<String, List<HuntHotspotRecord>>
huntHotspotRecordsByCityName = <String, List<HuntHotspotRecord>>{
  'München': <HuntHotspotRecord>[
    (
      name: 'Marienplatz',
      latitude: 48.1374,
      longitude: 11.5755,
      density: 'sehr hoch',
    ),
    (
      name: 'Viktualienmarkt',
      latitude: 48.1351,
      longitude: 11.5763,
      density: 'hoch',
    ),
    (
      name: 'Odeonsplatz',
      latitude: 48.1428,
      longitude: 11.5773,
      density: 'hoch',
    ),
    (
      name: 'Englischer Garten / Chinesischer Turm',
      latitude: 48.1421,
      longitude: 11.5919,
      density: 'mittel',
    ),
  ],
  'Rom': <HuntHotspotRecord>[
    (name: 'Kolosseum', latitude: 41.89, longitude: 12.492, density: 'hoch'),
    (
      name: 'Pantheon / Piazza Navona',
      latitude: 41.898,
      longitude: 12.477,
      density: 'hoch',
    ),
  ],
  'Regensburg': <HuntHotspotRecord>[
    (
      name: 'Altstadt / Dom',
      latitude: 49.019,
      longitude: 12.097,
      density: 'hoch',
    ),
  ],
  'Passau': <HuntHotspotRecord>[
    (
      name: 'Altstadt / Dom',
      latitude: 48.574,
      longitude: 13.466,
      density: 'mittel',
    ),
  ],
  'Piran': <HuntHotspotRecord>[
    (
      name: 'Tartiniplatz',
      latitude: 45.5285,
      longitude: 13.5686,
      density: 'hoch',
    ),
    (
      name: 'Hafenpromenade',
      latitude: 45.5276,
      longitude: 13.5681,
      density: 'mittel',
    ),
    (
      name: 'Georgskirche',
      latitude: 45.5293,
      longitude: 13.568,
      density: 'mittel',
    ),
  ],
  'Bologna': <HuntHotspotRecord>[
    (
      name: 'Piazza Maggiore',
      latitude: 44.4938,
      longitude: 11.3426,
      density: 'hoch',
    ),
    (name: 'Due Torri', latitude: 44.4946, longitude: 11.3466, density: 'hoch'),
  ],
  'Salzburg': <HuntHotspotRecord>[
    (
      name: 'Altstadt / Getreidegasse',
      latitude: 47.8004,
      longitude: 13.0432,
      density: 'hoch',
    ),
    (
      name: 'Festung Hohensalzburg',
      latitude: 47.795,
      longitude: 13.0476,
      density: 'mittel',
    ),
  ],
  'Weimar': <HuntHotspotRecord>[
    (
      name: 'Theaterplatz',
      latitude: 50.9793,
      longitude: 11.3261,
      density: 'hoch',
    ),
    (
      name: 'Marktplatz / Stadtschloss',
      latitude: 50.9795,
      longitude: 11.3294,
      density: 'mittel',
    ),
  ],
  'Heidelberg': <HuntHotspotRecord>[
    (
      name: 'Altstadt / Hauptstraße',
      latitude: 49.4129,
      longitude: 8.7106,
      density: 'hoch',
    ),
    (
      name: 'Schloss Heidelberg',
      latitude: 49.4106,
      longitude: 8.7156,
      density: 'mittel',
    ),
  ],
  'Nürnberg': <HuntHotspotRecord>[
    (name: 'Hauptmarkt', latitude: 49.454, longitude: 11.0775, density: 'hoch'),
    (
      name: 'Kaiserburg',
      latitude: 49.4577,
      longitude: 11.075,
      density: 'mittel',
    ),
  ],
};
