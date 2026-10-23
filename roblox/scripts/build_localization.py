"""Genera roblox/localization/GameStrings.csv (LocalizationTable de Roblox vía Rojo)
a partir de orbit_runner_game/localization/strings.csv (keys,es,en).

- Solo copia los prefijos que usa la versión de Roblox (FASE 1: HUD, tutorial, pausa,
  resultados, ajustes, nombres de nivel). Ampliar PREFIXES en fases siguientes.
- Formato de Roblox: Key,Source,Context,Example,es. Source = inglés (idioma de origen
  de la experiencia); la columna es = español. Los %d / %s de Godot pasan a {1}, {2}.
- ROBLOX_OVERRIDES corrige textos que en Roblox cambian (Esc abre el menú de Roblox:
  la pausa es P) y añade claves propias de Roblox.

Uso: python roblox/scripts/build_localization.py
"""
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "orbit_runner_game" / "localization" / "strings.csv"
TARGET = ROOT / "roblox" / "localization" / "GameStrings.csv"

PREFIXES = ("HUD_", "TUT_", "PAUSE_", "RESULTS_", "MEDAL_", "SETTINGS_", "LEVEL_TUTORIAL", "LEVEL_W1_L1",
            "WORLD_1", "MENU_PLAY", "MENU_SETTINGS", "MENU_LEVELS")
SKIP = {"SETTINGS_LANGUAGE", "SETTINGS_LANG_AUTO", "SETTINGS_QUALITY", "SETTINGS_Q_LOW", "SETTINGS_Q_MEDIUM",
        "SETTINGS_Q_HIGH", "SETTINGS_FPS", "SETTINGS_QUALITY_NOTE", "SETTINGS_NOTIFICATIONS"}

ROBLOX_OVERRIDES = {
    "SETTINGS_KEYS_HELP": (
        "Teclado: WASD/flechas mover · Espacio saltar · E yo-yo · Mayús deslizar/impulso · Q/R girar cámara · P pausa. "
        "Mando: stick izq. mover · A saltar · X/RB yo-yo · B/LB deslizar/impulso · stick dcho. cámara · Start pausa.",
        "Keyboard: WASD/arrows move · Space jump · E yo-yo · Shift slide/dash · Q/R turn camera · P pause. "
        "Gamepad: left stick move · A jump · X/RB yo-yo · B/LB slide/dash · right stick camera · Start pause.",
    ),
    "SELECT_TITLE": ("Elige una prueba", "Choose a run"),
    "SELECT_LAB": ("Laboratorio de mecánicas", "Mechanics lab"),
    "SELECT_LAB_HINT": ("Mide saltos, props y peligros", "Measure jumps, props and hazards"),
    "SELECT_PLAY": ("Jugar", "Play"),
    "SELECT_BEST": ("Mejor: {1}", "Best: {1}"),
    "HUD_PAUSE": ("Pausa", "Pause"),
    "RESULTS_TIME": ("Tiempo", "Time"),
    "RESULTS_SPARKS": ("Chispas", "Sparks"),
    "RESULTS_GEMS": ("Gemas", "Gems"),
    "RESULTS_STARS": ("Maestría", "Mastery"),
    "RESULTS_STAR_GOLD": ("Oro", "Gold"),
    "RESULTS_STAR_GEMS": ("3 gemas", "3 gems"),
    "RESULTS_STAR_SPARKS": ("Todas las chispas", "All sparks"),
    "RESULTS_STAR_FLAWLESS": ("Sin reapariciones", "No respawns"),
    "RESULTS_SAVED": ("Resultado registrado", "Result recorded"),
    "RESULTS_REJECTED": ("Resultado no válido: no se registra", "Invalid result: not recorded"),
    "SETTINGS_BACK": ("Volver", "Back"),
    "SETTINGS_ON": ("Sí", "On"),
    "SETTINGS_OFF": ("No", "Off"),
}


def convert(text: str) -> str:
    counter = iter(range(1, 10))
    return re.sub(r"%[ds]", lambda _m: "{%d}" % next(counter), text)


def main() -> None:
    rows = []
    with SOURCE.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            key = row["keys"]
            if key in SKIP or not key.startswith(PREFIXES):
                continue
            rows.append((key, convert(row["en"]), convert(row["es"])))
    keys = {key for key, _en, _es in rows}
    for key, (es, en) in ROBLOX_OVERRIDES.items():
        if key in keys:
            rows = [(k, en if k == key else e, es if k == key else s) for k, e, s in rows]
        else:
            rows.append((key, en, es))
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    with TARGET.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["Key", "Source", "Context", "Example", "es"])
        for key, en, es in sorted(rows):
            writer.writerow([key, en, "", "", es])
    print(f"{len(rows)} claves -> {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
