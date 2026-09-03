# Feature-Eigentümerschaft

Verbindlich ist `docs/architecture/domain-map.md`. Diese Datei hält fest, wie der
Ordnerbaum darauf abbildet, und markiert die drei Features, die über die
Domain-Map hinausgehen. Jedes Feature startet ohne Unterordner und wird nach
ADR-002 erst dann in `presentation/application/domain/data` aufgeteilt, wenn
Komplexität es verlangt.

## Direkt aus der Domain-Map

| Ordner | Besitzt | Besitzt ausdrücklich nicht |
|---|---|---|
| `identity` | Session, Login, Signup, Passwort-Reset, Kontolöschung | öffentliches Profil, Belohnungen |
| `city` | Stadt-Identität, Verfügbarkeit, Grenzen, aktive Stadtauswahl | Fakten-Inhalt |
| `facts` | Fakt-Inhalt, Kategorien, Medienreferenzen, Akte-Ansicht | ob ein Nutzer gesammelt hat |
| `discovery` | Karte, Umgebungssuche, Filter, Cluster, Entdecken-Modus | Fakt-Inhalt, Sammel-Regeln |
| `collection` | ob und wann gesammelt wurde, Sammel-Berechtigung, Verlauf | Fakt-Text, Belohnungshöhe |
| `progression` | XP, Level, Coins, Trophäen, Streak, Belohnungs-Ledger, Leaderboard | Sammel-Entscheidung |
| `challenges` | Schnitzeljagd solo, Gruppe, Team, Sessions, Lobby, Ergebnisse | Rätsel-Mechanik, Fakt-Inhalt |
| `tours` | Tour-Definition, Stopps, Route, Tour-Session, Fortschritt | Rätsel-Mechanik, Kartenrendering |
| `profile` | Anzeigename, Avatar, Reisepass-Ansicht, Lesemodelle | XP- und Coin-Regeln |
| `settings` | Sprache, Theme, Audio-Präferenzen, Benachrichtigungen, Privatsphäre | fachliche Regeln |

## Über die Domain-Map hinaus

Diese drei existieren, weil die Parity-Spec Verhalten fordert, für das die
Domain-Map keinen Eigentümer nennt.

**`puzzles` ist seit dem 31.08.2026 bestätigt**, siehe ADR-006, und steht
seitdem auch in `domain-map.md`, `architecture-overview.md` und
`project-structure.md`. `tours` und `challenges` dürfen davon abhängen, aber nur
von `puzzles/domain` und `puzzles/application`; umgekehrt nie.

> **Nachtrag 03.09.2026: der Bildschirm steht, und er steht in `collection`.**
> Schritt 45 hat die Bibliothek gebaut, also Kopfkarte, Bücherregal und
> Trophäenzeile, unter `collection/presentation/pages/collection_page.dart`.
> Die Produktfrage darunter ist damit auch praktisch beantwortet: es ist
> **ein** Bildschirm. Cover und Lesemodus (Schritt 46 und 47) kommen als
> weitere Zustände desselben Reiters dazu und nicht als eigenes Feature.
> Die Trophäen liest er über einen öffentlichen Application-Vertrag von
> `progression` (Regel 10), die Münzen fasst er nicht an.

**`library` ist am 31.08.2026 gestrichen.** Die Produktfrage ist entschieden:
alles kommt in den Wallet, also das Bücherregal mit den gesammelten Fakten, und
`collection` besitzt diesen Bildschirm. Die Coins gehen ins **Profil**, sie
gehören `progression`. Siehe ADR-006.

**`creator` bleibt Vorschlag**, und zwar bewusst: sie haben heute
keinen Inhalt und keinen Verbraucher, und für `library` ist zusätzlich ungeklärt,
was ihm überhaupt gehört. Der Bildschirm, den es beansprucht, ist derselbe, für
den `collection/presentation/pages/collection_page.dart` schon einen Platzhalter
trägt und dem `shell_tab.dart` den `wallet`-Tab zuweist. Ob das PWA-„Wallet" ein
Bildschirm ist (gesammelte Fakten, nach Städten als Reiseführer dargestellt) oder
zwei, ist eine Produktfrage und keine Architekturfrage. Sie gehört beantwortet,
bevor jemand in `library` baut, siehe ADR-006.

| Ordner | Besitzt | Begründung |
|---|---|---|
| `puzzles` | Rätsel-Definition, sechs Rätseltypen, Auswertungs-Policy, Hinweisstufen | Die Engine wird von `tours` **und** `challenges` genutzt. Läge sie in einem der beiden, müsste das andere Feature dessen Presentation importieren, was Regel 8 der Dependency-Rules verbietet. Rätsel bewerten, nicht belohnen: die Belohnung entsteht als Ereignis für `progression`. |
| `library` | Reiseführer-Regal, Cover, Kapitel, Reader | In der PWA heißt das „Wallet", enthält aber keine Währung. Coins gehören zu `progression`. Der Reader zeigt Fakten, besitzt sie nicht. |
| `creator` | Fakt einreichen, Kategorie-Vorschlag, Foto-Upload, Wikipedia-Suche | `facts` besitzt veröffentlichten Inhalt, die Erzeugungs-Pipeline gilt laut Domain-Map als externes System. Nutzer-Einreichung ist ein eigener Arbeitsablauf mit eigenem Zustand. |

## Was bewusst kein Feature ist

- **`map`**: Domain-Map §7 sagt ausdrücklich, dass Karte in v1 keine
  Geschäftsdomäne ist. Seit dem 28.08.2026 liegt der MapLibre-Host in
  **`lib/map/`** und nicht, wie hier vorher stand, unter `services/map`: er
  bringt eine eigene Oberfläche mit, und `services/` ist für Vendor-Adapter
  ohne Oberfläche gedacht. Der Host besitzt Kamera und Kartenfläche.
  `discovery` sagt, was auf der Karte zu sehen ist, `tours` und `challenges`
  liefern ihre Overlays über App-Komposition. Alle vier reden mit dem Host
  ausschließlich über `map/domain`; `map/presentation` und `map/data` sind
  intern, das prüft Regel 18 in `dependency-rules.md`.
- **`audio`**: TTS und Wiedergabe sind Transport und liegen später unter
  `services`. Wann welcher Fakt vorgelesen wird, ist eine Regel von
  `discovery` beziehungsweise `tours`.
