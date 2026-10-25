# Party Games (Godot 4)

Modulare 3D-Party-Minispielsammlung in Godot 4 (Clean-Room, MIT-Lizenz), inspiriert von klassischen Minispiel-Hits (*Mario Party*, *SuperTuxParty*).

## Enthaltene Minispiele

1. **Bumper Balls / Knock Off:**
   - 4 Spieler auf Rollkugeln auf einer schwebenden, rutschigen Plattform.
   - Wer von der Plattform gestoßen wird, scheidet aus. Last Man Standing gewinnt!

## Architektur

- **Clean Architecture & Headless Simulation:**
  - `core/`: Deterministischer Spielkern (Kollisionen, Impulse, Rundenzeit, Siegbedingungen). Keine Abhängigkeit von Godot SceneTree; 100% testbar via GdUnit4.
  - `presentation/`: 3D-Präsentation (PBR-Kugeln, Arena, Partikeleffekte, dynamische Kamera, HUD).
- **Tests:** Vollständige Testsuite via `addons/gdUnit4/`.
