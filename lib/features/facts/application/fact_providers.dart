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

import 'package:fact_app/features/facts/domain/repositories/fact_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Woher die App ihre Fakten bekommt.
///
/// Der Standard ist [unavailableFactRepository], also **kein Fakt und ein
/// sichtbarer Fehlschlag**. Die echte Fassung setzt `lib/app/bootstrap.dart`
/// per Override ein; ein Test dort ist das Netz darunter, denn ein fehlender
/// Override wäre sonst eine App mit leerer Karte und ohne jede Meldung.
final Provider<FactRepository> factRepositoryProvider =
    Provider<FactRepository>((ref) => unavailableFactRepository);
