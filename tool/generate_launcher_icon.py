"""Erzeugt das Launcher-Symbol aus den Design-Tokens der App.

Aufruf aus dem Projektwurzelverzeichnis:

    python tool/generate_launcher_icon.py

Braucht Pillow. Das Skript ist bewusst kein Teil eines Builds: es laeuft von
Hand, wenn sich die Marke aendert, und schreibt seine Ergebnisse ins
Repository. Ein Icon bei jedem Build neu zu rechnen waere Aufwand ohne Nutzen.

## Warum erzeugt und nicht exportiert

Das aktuelle FACT-Zeichen existiert nirgends als Bilddatei. Das alte
Pin-Symbol im eingefrorenen Flutter-Port und in der PWA
(`02_Frontend/app/icon-512.png`) ist veraltet, das ist am 28.08.2026
ausdruecklich bestaetigt worden. Das gueltige Zeichen wird in
`lib/features/identity/presentation/widgets/auth_header.dart` gezeichnet, aus
Farbtokens und einer Schrift, die das Repository ohnehin ausliefert.

Also wird es hier aus denselben Werten erzeugt. Der Gewinn ist nicht Bequem-
lichkeit: ein exportiertes Bild driftet von der Code-Fassung weg, sobald
jemand einen Token aendert, und niemand merkt es. Wer hier etwas aendert, muss
die Werte unten mit `fact_colors.dart` und `auth_header.dart` abgleichen.

## Die eine bewusste Abweichung

`auth_header.dart` setzt den Glyphen auf 14 bei einer Kachel von 26, also
etwa 0,54. Dieses Verhaeltnis stammt aus der Kopfzeile, wo die Kachel **neben**
der Wortmarke steht. Ein App-Symbol ist ein Zeichen fuer sich und steht bei 48
Pixeln zwischen dutzenden anderen. Freigegeben am 28.08.2026: der Glyph ist
hier groesser, siehe `_glyphAnteil`. Farben, Verlaufswinkel und Eckradius
bleiben tokentreu.

## Adaptives Symbol

Ab Android 8 maskiert das System die Form selbst, runde Ecken im Bild waeren
doppelt. Deshalb zwei Ebenen: der Verlauf randlos als Hintergrund, der weisse
Glyph als Vordergrund mit Transparenz. Der Vordergrund haelt die
Sicherheitszone ein, also die inneren zwei Drittel von 108 dp, sonst
beschneidet eine runde Maske den Glyphen.
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

# --- Tokens, abgeglichen mit lib/app/theme/fact_colors.dart -----------------

ROT_HELL = (0xFF, 0x6B, 0x3D)  # --red-lt, FactColors.redLight
ROT = (0xE8, 0x38, 0x0D)  # --red, FactColors.red
WEISS = (0xFF, 0xFF, 0xFF)

# `cssLinearGradientEnds(angleDegrees: 145)` in auth_header.dart.
VERLAUF_WINKEL = 145

# `tileRadius / tileSize` aus auth_header.dart: 8 von 26.
RADIUS_ANTEIL = 8 / 26

# Bewusst groesser als die 14 von 26 der Kopfzeile, siehe Kopfkommentar.
GLYPH_ANTEIL = 0.72

# Die Sicherheitszone eines adaptiven Symbols: 72 dp Inhalt auf 108 dp Flaeche.
ADAPTIV_SICHER = 72 / 108

SCHRIFT = "assets/fonts/Nunito-Black.ttf"

# Android-Dichten. Links das Verzeichnis, rechts die Kantenlaenge in Pixeln.
LEGACY_DICHTEN = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# Adaptive Ebenen sind immer 108 dp gross.
ADAPTIV_DICHTEN = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}

RES = os.path.join("android", "app", "src", "main", "res")


def _verlauf(size: int) -> Image.Image:
    """Der Verlauf als quadratisches Bild.

    CSS zaehlt den Winkel von "nach oben" im Uhrzeigersinn, Pillow kennt keine
    Verlaeufe. Deshalb pro Pixel die Projektion auf die Verlaufsrichtung.
    """
    a = math.radians(VERLAUF_WINKEL)
    dx, dy = math.sin(a), -math.cos(a)
    bild = Image.new("RGB", (size, size))
    px = bild.load()
    laenge = abs(dx) * size + abs(dy) * size
    for y in range(size):
        for x in range(size):
            t = ((x - size / 2) * dx + (y - size / 2) * dy) / laenge + 0.5
            t = min(1.0, max(0.0, t))
            px[x, y] = tuple(
                round(ROT_HELL[i] + (ROT[i] - ROT_HELL[i]) * t) for i in range(3)
            )
    return bild


def _glyph(size: int, hoehe: float) -> Image.Image:
    """Das Ausrufezeichen als weisse Ebene mit Transparenz, optisch mittig.

    Mittig heisst hier: ueber die tatsaechliche Tinte zentriert, nicht ueber
    die Zeilenbox. Ein Ausrufezeichen hat keine Unterlaenge, die Zeilenbox
    saesse deutlich zu hoch.
    """
    f = ImageFont.truetype(SCHRIFT, max(1, int(round(hoehe))))
    maske = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(maske)
    links, oben, rechts, unten = d.textbbox((0, 0), "!", font=f)
    d.text(
        ((size - (rechts - links)) / 2 - links, (size - (unten - oben)) / 2 - oben),
        "!",
        font=f,
        fill=255,
    )
    ebene = Image.new("RGBA", (size, size), WEISS + (0,))
    ebene.putalpha(maske)
    return ebene


def kachel(size: int) -> Image.Image:
    """Das vollstaendige Zeichen mit runden Ecken, fuer Android 7 und aelter."""
    grund = _verlauf(size).convert("RGBA")
    ecken = Image.new("L", (size, size), 0)
    ImageDraw.Draw(ecken).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=round(size * RADIUS_ANTEIL), fill=255
    )
    grund.putalpha(ecken)
    return Image.alpha_composite(grund, _glyph(size, size * GLYPH_ANTEIL))


def adaptiv_hintergrund(size: int) -> Image.Image:
    """Randloser Verlauf. Die Form schneidet das System selbst."""
    return _verlauf(size).convert("RGBA")


def adaptiv_vordergrund(size: int) -> Image.Image:
    """Nur der Glyph, auf die Sicherheitszone bemessen."""
    return _glyph(size, size * ADAPTIV_SICHER * GLYPH_ANTEIL)


def main() -> int:
    if not os.path.isfile(SCHRIFT):
        print(f"Schrift nicht gefunden: {SCHRIFT}", file=sys.stderr)
        print("Aus dem Projektwurzelverzeichnis aufrufen.", file=sys.stderr)
        return 1

    for dichte, size in LEGACY_DICHTEN.items():
        ziel = os.path.join(RES, f"mipmap-{dichte}", "ic_launcher.png")
        os.makedirs(os.path.dirname(ziel), exist_ok=True)
        kachel(size).save(ziel)
        print(f"{ziel}  {size}x{size}")

    for dichte, size in ADAPTIV_DICHTEN.items():
        ordner = os.path.join(RES, f"drawable-{dichte}")
        os.makedirs(ordner, exist_ok=True)
        hg = os.path.join(ordner, "ic_launcher_background.png")
        vg = os.path.join(ordner, "ic_launcher_foreground.png")
        adaptiv_hintergrund(size).save(hg)
        adaptiv_vordergrund(size).save(vg)
        print(f"{hg}  {size}x{size}")
        print(f"{vg}  {size}x{size}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
