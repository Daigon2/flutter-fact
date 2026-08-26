/// Die sprachabhängigen Textfelder eines Fakts.
///
/// ## Woher die Felder kommen
///
/// Die Spalten der Standardsprache (Deutsch) liegen flach auf `public.facts`.
/// Übersetzungen liegen in `facts._i18n` als `{"en": {…}, "it": {…}}`. Welche
/// Felder dazugehören, steht nicht im Schema, sondern im Lesepfad der PWA:
/// `window.pickFact` in `02_Frontend/app/api.jsx:25` nennt exakt neun Felder.
/// Die Migration `2026-06-06_i18n_facts.sql` dokumentiert dieselbe Form.
///
/// | Spalte / `_i18n`-Schlüssel | Feld hier | Was es ist |
/// |---|---|---|
/// | `titel` | [title] | Überschrift des Fakts |
/// | `text` | [body] | Haupttext, die Belohnung nach dem Rätsel |
/// | `text2` | [bodyExtra] | zweiter Absatz |
/// | `text3` | [bodyBackground] | Hintergrund, in `api.jsx:316` als „Tiefe" |
/// | `text4` | [bodyToday] | Bezug auf das Jetzt, „Heute" |
/// | `ort` | [place] | Stadtteil- oder Ortsangabe, nicht die Stadt |
/// | `kategorie` | [category] | Anzeigename der Kategorie |
/// | `quelle` | [source] | Quellenangabe |
/// | `caption` | [caption] | Bildunterschrift |
///
/// Alle Felder sind nullbar, weil eine Übersetzung nur einzelne davon
/// überschreiben darf. `text3` und `text4` sind selbst in der Standardsprache
/// nur für einen Teil des Bestands gefüllt.
///
/// ## Warum hier keine Sprache ausgewählt wird
///
/// Dieses Objekt ist ein Textbündel für **eine** Sprachebene, nicht die
/// Auswahl. Die Auflösung passiert in `Fact.contentFor`, und die aktive Sprache
/// gibt die Präsentation vor. Begründung steht dort.
library;

import 'package:fact_app/features/facts/domain/structural_equality.dart';

/// Ein Satz Textfelder für eine Sprachebene.
class FactText {
  /// Alle Felder sind optional. Fehlt eines, gilt die Ebene darunter.
  const FactText({
    this.title,
    this.body,
    this.bodyExtra,
    this.bodyBackground,
    this.bodyToday,
    this.place,
    this.category,
    this.source,
    this.caption,
  });

  /// Nichts gesetzt.
  static const FactText empty = FactText();

  /// Die Schlüssel in `_i18n`, in der Reihenfolge aus `api.jsx:25`.
  ///
  /// Steht hier, damit der Mapper und die Tests dieselbe Liste benutzen und
  /// ein vergessenes Feld auffällt.
  static const List<String> sourceKeys = <String>[
    'titel',
    'text',
    'text2',
    'text3',
    'text4',
    'ort',
    'kategorie',
    'quelle',
    'caption',
  ];

  /// `titel`
  final String? title;

  /// `text`
  final String? body;

  /// `text2`
  final String? bodyExtra;

  /// `text3`
  final String? bodyBackground;

  /// `text4`
  final String? bodyToday;

  /// `ort`
  final String? place;

  /// `kategorie`
  final String? category;

  /// `quelle`
  final String? source;

  /// `caption`
  final String? caption;

  /// Ist kein einziges Feld gesetzt?
  bool get isEmpty =>
      title == null &&
      body == null &&
      bodyExtra == null &&
      bodyBackground == null &&
      bodyToday == null &&
      place == null &&
      category == null &&
      source == null &&
      caption == null;

  /// Legt [override] über dieses Bündel.
  ///
  /// Ein Feld aus [override] gewinnt nur, wenn es gesetzt **und nicht leer**
  /// ist. Der leere String zählt also als „nicht übersetzt", genau wie in
  /// `pickFact` (`api.jsx:33`: `picked[f] !== undefined && picked[f] !== ''`).
  /// Ohne diese Regel würde ein leerer Eintrag aus einem abgebrochenen
  /// Übersetzungslauf den deutschen Text löschen.
  FactText overriddenBy(FactText? override) {
    if (override == null || override.isEmpty) {
      return this;
    }
    return FactText(
      title: _pick(override.title, title),
      body: _pick(override.body, body),
      bodyExtra: _pick(override.bodyExtra, bodyExtra),
      bodyBackground: _pick(override.bodyBackground, bodyBackground),
      bodyToday: _pick(override.bodyToday, bodyToday),
      place: _pick(override.place, place),
      category: _pick(override.category, category),
      source: _pick(override.source, source),
      caption: _pick(override.caption, caption),
    );
  }

  static String? _pick(String? candidate, String? fallback) {
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return fallback;
  }

  /// Kopie mit einzelnen geänderten Feldern.
  ///
  /// Bewusst ohne Möglichkeit, ein Feld auf `null` zurückzusetzen. Wer das
  /// braucht, baut ein neues Objekt; die Alternative wäre für jedes Feld ein
  /// Sentinel, und das trägt bei neun Feldern mehr Verwirrung als Nutzen.
  FactText copyWith({
    String? title,
    String? body,
    String? bodyExtra,
    String? bodyBackground,
    String? bodyToday,
    String? place,
    String? category,
    String? source,
    String? caption,
  }) {
    return FactText(
      title: title ?? this.title,
      body: body ?? this.body,
      bodyExtra: bodyExtra ?? this.bodyExtra,
      bodyBackground: bodyBackground ?? this.bodyBackground,
      bodyToday: bodyToday ?? this.bodyToday,
      place: place ?? this.place,
      category: category ?? this.category,
      source: source ?? this.source,
      caption: caption ?? this.caption,
    );
  }

  /// Die Felder in der Reihenfolge von [sourceKeys]. Grundlage für
  /// Gleichheit und Hash, damit ein neues Feld nicht vergessen werden kann.
  List<String?> get _fields => <String?>[
    title,
    body,
    bodyExtra,
    bodyBackground,
    bodyToday,
    place,
    category,
    source,
    caption,
  ];

  @override
  bool operator ==(Object other) =>
      other is FactText && listsEqual(other._fields, _fields);

  @override
  int get hashCode => hashList(_fields);

  @override
  String toString() {
    final set = <String>[];
    for (var i = 0; i < sourceKeys.length; i++) {
      if (_fields[i] != null) {
        set.add(sourceKeys[i]);
      }
    }
    return 'FactText(${set.join(', ')})';
  }
}
