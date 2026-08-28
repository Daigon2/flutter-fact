import 'package:fact_app/app/onboarding/onboarding_providers.dart';
import 'package:fact_app/app/onboarding/tour_overlay.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entscheidet, ob über [child] ein Tutorial liegt.
///
/// Das ist die ganze Aufgabe: die Bedingung aus `02_Frontend/app/app.jsx:1009`
/// und der Weg vom Ende des Tutorials zur gespeicherten Merkung. Alles Weitere
/// gehört [TourOverlay].
///
/// ## Ist die Tour aus, gibt es kein Overlay, aber den `Stack` weiterhin
///
/// Das Overlay verschwindet vollständig aus dem Baum. Ein "unsichtbares"
/// Overlay wäre der teurere Fehler: es nimmt weiter am Hit-Test teil und
/// verschluckt Tipps auf die Tab-Leiste, ohne dass man etwas sieht.
///
/// Der `Stack` selbst bleibt trotzdem stehen, und das ist keine Kosmetik,
/// sondern gemessen. Die naheliegende Fassung war `if (shown) return child;`,
/// also die Struktur je nach Zustand zu wechseln. Flutter kann ein Element
/// nicht wiederverwenden, wenn sich der Elterntyp ändert: beim Ende der Tour
/// wird die **ganze Shell** verworfen und neu aufgebaut, samt der vier
/// Zweig-Navigatoren, und der Nutzer verliert jeden Routenstapel.
///
/// Sichtbar geworden ist das an einer ganz anderen Stelle, und das ist der
/// Teil, den man sich merken sollte: der `assert` in `AnchorRegistry.register`
/// schlug an, weil die neue Tab-Leiste ihre Anker anmeldet, **bevor** die alte
/// entsorgt ist. Deaktivierte Elemente werden erst am Frame-Ende abgeräumt.
/// Ein doppelt angemeldeter Anker ist damit ein zuverlässiger Melder für einen
/// unbeabsichtigten Neuaufbau eines Teilbaums.
///
/// Ein `Stack` mit einem Kind fängt keine Zeiger ab: `RenderStack` hat kein
/// eigenes `hitTestSelf`. Ein Test sichert beides zu, die Bedienbarkeit der
/// Leiste und die Elementgleichheit der Shell über das Ende der Tour hinweg.
///
/// ## Warum das Tutorial keine eigene Route ist
///
/// E-25 nagelt sieben Routen fest, und eine achte wäre hier auch technisch
/// falsch: das Tutorial zeigt in Schritt 5 und 7 auf Knöpfe der Tab-Leiste.
/// Läge es außerhalb der Shell, wäre die Leiste nicht im Baum, ihre Anker wären
/// nicht angemeldet, und aus zwei voll baubaren Schritten würden zwei weitere
/// degradierende. Deshalb sitzt es an derselben Kompositionsstelle wie schon
/// der Audio-Dialog: in `lib/app/routing/app_routes.dart`.
///
/// ## Warum die Bedingung `route === 'map'` der Quelle hier fehlt
///
/// `app.jsx:1009` zeigt das Overlay nur über der Karte. Nachgebaut ist das
/// **nicht**, und zwar aus einem belegten Grund: die Bedingung kann sich in der
/// Quelle während des Tutorials gar nicht ändern. Das Overlay wird per Portal
/// in die `.app-frame` gehängt (`screen-tour.jsx:113-127`) und liegt dort mit
/// `zIndex: 5000` über der Tab-Leiste, die auf `zIndex: 50` sitzt
/// (`chrome.jsx:73`). Ein Klick auf einen Tab trifft das Overlay und schaltet
/// den Schritt weiter, statt den Bildschirm zu wechseln. `route` bleibt also
/// `'map'`, bis das Tutorial vorbei ist.
///
/// Die Bedingung ist damit kein Verhalten, sondern der Aufhängepunkt: sie sagt
/// "über der Karte", weil das Overlay im Karten-Wrapper steht. Hier hängt es an
/// der Shell, also über allen vier Tabs, und die beiden Anker, auf die es
/// zeigt, liegen ohnehin in der Leiste und nicht in einem Zweig.
///
/// Der einzige Fall, in dem das einen Unterschied macht, ist ein Deep Link auf
/// `/collection`, `/challenges` oder `/profile` beim allerersten Start. Den
/// kennt die PWA nicht, sie hat keine URLs. Gewählt ist "Tutorial zeigen", weil
/// die Absicht der Quelle "einmal beim ersten Start, bis der Nutzer durch ist"
/// lautet und nicht "nur wenn er zufällig auf der Karte landet". Ein Test
/// sichert zu, dass die Leiste währenddessen nicht bedienbar ist, der Nutzer
/// also auch hier nicht mitten im Tutorial den Tab wechseln kann.
///
/// **Nicht nachgebaut, weil es das noch nicht gibt:** das `!cityIntroFor` aus
/// derselben Zeile. Das Stadt-Intro ist eine eigene Überlagerung und kommt in
/// einem späteren Schritt; wenn sie kommt, gehört die Bedingung hierher.
class OnboardingHost extends ConsumerWidget {
  /// [child] ist die App, über der das Tutorial liegen kann.
  const OnboardingHost({required this.child, super.key});

  /// Die laufende App.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(tourShownProvider);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        if (!shown)
          TourOverlay(
            // Der Zustand liegt im Provider und nicht im Overlay: verschwinden
            // soll es, weil die Merkung gesetzt ist, nicht weil es sich selbst
            // ausblendet. Sonst gäbe es zwei Wahrheiten darüber, ob das Tutorial
            // erledigt ist.
            //
            // `reportDetached` und nicht `unawaited`, weil ENG-FLUTTER §7 zum
            // Helfer auch eine Fehlermeldung verlangt: scheitert das Speichern,
            // ist der Zustand im Speicher richtig und auf der Platte falsch, und
            // ohne Meldung merkt das niemand bis zum nächsten Start.
            onFinished: () => reportDetached(
              ref.read(tourShownProvider.notifier).markSeen(),
              origin: 'app.onboarding.tour_shown',
            ),
          ),
      ],
    );
  }
}
