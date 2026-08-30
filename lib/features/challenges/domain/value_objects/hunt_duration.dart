/// Die Dauer, die der Spieler für eine Schnitzeljagd wählt.
///
/// ## Warum die Stationszahl hier steht und nicht beim Assistenten
///
/// Die Zuordnung Dauer zu Stationszahl steht in der Quelle an **zwei**
/// Stellen, und beide müssen dieselbe Zahl zeigen:
///
/// * `02_Frontend/app/screen-challenge.jsx:1899-1902` beschriftet die drei
///   Dauer-Karten mit `{ val: 30, label: '30 min', stops: 5 }`,
///   `{ val: 60, …, stops: 7 }` und `{ val: 90, …, stops: 9 }`.
/// * `02_Frontend/app/screen-challenge.jsx:4332` rechnet unmittelbar vor dem
///   Aufruf des Generators `const stopCountByDuration = { 30: 5, 60: 7, 90: 9 }`
///   und übergibt das Ergebnis als `stopCount`.
///
/// Ein Nutzer, der „60 min · 7 Stationen" liest und danach eine Jagd über
/// fünf Stationen bekommt, sieht einen Fehler, den keine der beiden Stellen
/// für sich allein zeigt. Deshalb liegt die Zahl **einmal** hier, und beide
/// Seiten lesen sie.
///
/// ## Die Quelle hat einen vierten Fall, dieser Typ nicht
///
/// `:4333` schreibt `stopCountByDuration[duration] || 6`. Die 6 greift nur,
/// wenn `duration` etwas anderes als 30, 60 oder 90 ist, und das kann in der
/// Quelle nur passieren, wenn der Zustand `duration` noch `null` ist. Genau
/// das ist dort aber schon ausgeschlossen: `confirmStep2` (`:1614-1617`)
/// bricht ohne Dauer ab. Ein vierter Aufzählungswert „sonstiges" würde hier
/// also einen Zustand modellieren, den die Quelle verhindert.
///
/// ## Reine Domäne
///
/// Ohne Fremdimport und ohne Oberflächentext. Die Beschriftung „30 min" baut
/// der Assistent aus [minutes]; „5 Stationen" aus [stopCount] und einem
/// Sprachschlüssel.
enum HuntDuration {
  /// 30 Minuten, fünf Stationen.
  thirty(minutes: 30, stopCount: 5),

  /// 60 Minuten, sieben Stationen.
  sixty(minutes: 60, stopCount: 7),

  /// 90 Minuten, neun Stationen.
  ninety(minutes: 90, stopCount: 9);

  const HuntDuration({required this.minutes, required this.stopCount});

  /// Die gewählte Dauer in Minuten, wie sie auf der Karte steht.
  final int minutes;

  /// Wie viele Stationen der Generator dafür bauen soll.
  final int stopCount;
}
