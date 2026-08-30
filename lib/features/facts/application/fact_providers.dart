/// Der Zugang zu Fakten für alle höheren Schichten, als Riverpod-Komposition
/// (ADR-005).
///
/// ## Warum es diesen Provider zusätzlich gibt
///
/// `features/facts/data/repositories/supabase_fact_repository.dart` hat schon
/// einen, `supabaseFactRepositoryProvider`. Der ist für alles außer der
/// App-Komposition **unerreichbar**: Regel 17 verbietet `presentation` jeden
/// Import aus `data`, auch aus dem eigenen Feature, und Regel 9 verbietet ihn
/// jedem anderen Feature ohnehin. `dependency-rules.md` benennt das seit E-32
/// ausdrücklich als offenen Punkt und schreibt dazu: „the fix belongs to the
/// step that connects `facts` to the map". Das ist dieser Schritt.
///
/// Die Aufteilung folgt damit genau der Regel aus `dependency-rules.md`,
/// Abschnitt „Providers that construct dependencies": der Provider **neben der
/// Implementierung** baut sie und wird nur von `lib/app/` gelesen, der
/// Provider **auf dem Vertrag** steht hier und ist der einzige Weg für höhere
/// Schichten.
///
/// ## Warum in `application/` und nicht in `presentation/`
///
/// E-32 nennt als zu kopierendes Muster `authRepositoryProvider`, und der liegt
/// in `identity/presentation/notifiers/`. Das geht hier nicht: der Verbraucher
/// ist `features/discovery`, und Regel 8 verbietet jedem Feature den Import aus
/// dem `presentation` eines anderen. Der Vertrag selbst kann den Provider auch
/// nicht tragen, `features/facts/domain/` darf Riverpod nicht kennen (Regel 2).
/// Bleibt `application/`, und Regel 10 nennt genau das als erlaubten Weg über
/// die Feature-Grenze: „a public domain/application contract".
///
/// Das ist derselbe Zwang, aus dem `map/application/` entstanden ist, siehe
/// dort.
library;

import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_batch.dart';
import 'package:fact_app/features/facts/domain/repositories/fact_repository.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Woher die App ihre Fakten bekommt.
///
/// Der Standard ist [unavailableFactRepository], also **kein Fakt und ein
/// sichtbarer Fehlschlag**. Die echte Fassung setzt `lib/app/bootstrap.dart`
/// per Override ein; ein Test dort ist das Netz darunter, denn ein fehlender
/// Override wäre sonst eine App mit leerer Karte und ohne jede Meldung.
final Provider<FactRepository> factRepositoryProvider =
    Provider<FactRepository>((ref) => unavailableFactRepository);

/// Alle veröffentlichten Fakten, einmal geladen und von allen Features geteilt.
///
/// ## Warum es diesen Provider ab Schritt 35 gibt
///
/// Bis dahin gab es genau einen Verbraucher der vollständigen Liste,
/// `factOverlayProvider` in `discovery`, und der lud sie selbst. Der
/// Startpunkt-Picker ist der zweite: er zählt die Fakten im Umkreis von 600
/// Metern (`screen-challenge.jsx:2995-3001`) und übergibt dem Routengenerator
/// seinen Kandidatenpool. Regel 8 lässt ihn nicht an den Provider von
/// `discovery`, und ein zweiter eigener Ladevorgang wären zwei vollständige
/// Abrufe derselben Tabelle beim ersten Öffnen des Reiters.
///
/// Deshalb steht das Laden hier, in der Application-Schicht des Features, dem
/// die Daten gehören, und beide Verbraucher hängen daran. Das ist derselbe
/// Zwang, aus dem [factRepositoryProvider] entstanden ist, siehe Kopf dieser
/// Datei.
///
/// ## Ohne Stadtfilter, und das ist kein Versäumnis
///
/// [FactQuery.all], wie `api.jsx:119` in der Quelle. Die Stadtauswahl gehört
/// `features/city`, das es nicht gibt; eine hier verdrahtete Stadt wäre genau
/// die Annahme, die die Mehrstadt-Invariante verbietet. Wer eine Stadt
/// braucht, filtert selbst über [FactCity.matchesSlug], und der
/// Startpunkt-Picker tut genau das.
///
/// **Eine leere Liste ist hier nicht dasselbe wie ein Fehlschlag.**
/// `FactRepository` wirft bei Infrastrukturproblemen, und der `AsyncError`
/// bleibt sichtbar; eine Stadt ohne Fakten sähe sonst aus wie ein Netzfehler.
final FutureProvider<List<Fact>> allFactsProvider = FutureProvider<List<Fact>>((
  ref,
) async {
  // Vor dem `await` gelesen, aus demselben Grund wie unten.
  final FactRepository repository = ref.watch(factRepositoryProvider);
  final FactBatch batch = await repository.fetchFacts(query: FactQuery.all);
  return batch.facts;
});

/// Ein einzelner Fakt, für die Akte-Ansicht.
///
/// `null` heißt **nicht gefunden oder nicht sichtbar** und ist kein Fehlschlag:
/// die RLS-Policy „read facts" verbirgt unveröffentlichte Fakten
/// erwartungsgemäß, siehe [FactRepository.fetchFactById]. Ein
/// Infrastrukturfehlschlag kommt dagegen als `AsyncError` heraus, weil
/// `fetchFactById` dann eine `FactFailure` wirft.
///
/// ## Warum `FactId` und nicht `int`
///
/// Weil der Parameter einer Familie der Schlüssel des Caches ist. Ein nacktes
/// `int` träfe hier auf `zone`, `bewertungen` und `quality_score`, und
/// vertauschte Zahlen sähen im Aufruf gleich aus. `FactId` hat Wertgleichheit
/// (`fact_id.dart:20`), taugt also als Schlüssel.
///
/// ## Riverpod wiederholt einen Fehlschlag von selbst
///
/// Zehnmal über rund 38 Sekunden, und ausgenommen sind nur `Error` und
/// `ProviderException`. `FactFailure implements Exception` und wird deshalb
/// wiederholt, genau wie bei `factOverlayProvider`. Für Tests heißt das: **wer
/// diesen Provider werfen lässt, statt ihn zu überschreiben, hinterlässt einen
/// Zeitgeber, der den Widget-Baum überlebt** („A Timer is still pending").
///
/// ## Warum der Typ hier nicht ausgeschrieben steht
///
/// `FutureProviderFamily` liegt in `package:flutter_riverpod/misc.dart` und
/// nicht in der Hauptbibliothek. Ein zweiter Import nur für eine Annotation
/// wäre der teurere Weg, und die Inferenz liefert exakt denselben Typ.
// ignore: strict_top_level_inference
final factByIdProvider = FutureProvider.family<Fact?, FactId>((
  Ref ref,
  FactId id,
) async {
  // Vor dem `await` gelesen, aus demselben Grund wie in
  // `fact_overlay_providers.dart`: nach einer Unterbrechung ist ein
  // `ref.watch` nicht mehr dasselbe wie davor.
  final FactRepository repository = ref.watch(factRepositoryProvider);
  final FactBatch batch = await repository.fetchFactById(id);
  return batch.singleOrNull;
});
