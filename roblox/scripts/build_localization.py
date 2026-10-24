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

PREFIXES = ("HUD_", "TUT_", "PAUSE_", "RESULTS_", "MEDAL_", "SETTINGS_", "LEVEL_TUTORIAL", "LEVEL_W1_",
            "WORLD_1", "MENU_PLAY", "MENU_SETTINGS", "MENU_LEVELS")
SKIP = {"SETTINGS_LANGUAGE", "SETTINGS_LANG_AUTO", "SETTINGS_QUALITY", "SETTINGS_Q_LOW", "SETTINGS_Q_MEDIUM",
        "SETTINGS_Q_HIGH", "SETTINGS_FPS", "SETTINGS_QUALITY_NOTE", "SETTINGS_NOTIFICATIONS"}

ROBLOX_OVERRIDES = {
    # Controles de la plantilla Platformer (R14): doble salto, Mayús = rodar en suelo /
    # dash en el aire, saltar justo después de rodar = salto largo, cámara nativa.
    "SETTINGS_KEYS_HELP": (
        "Teclado: WASD/flechas mover · Espacio saltar (otra vez en el aire: doble salto) · Mayús rodar / dash en el aire · "
        "E yo-yo · ratón cámara · P pausa. Mando: stick izq. mover · A saltar · X rodar/dash · Y yo-yo · stick dcho. cámara · Start pausa.",
        "Keyboard: WASD/arrows move · Space jump (again in the air: double jump) · Shift roll / air dash · "
        "E yo-yo · mouse camera · P pause. Gamepad: left stick move · A jump · X roll/dash · Y yo-yo · right stick camera · Start pause.",
    ),
    # Tutorial de la Fase 2 (R18, scripts/build_tutorial.py): una acción por aviso.
    "TUT_JUMP": ("Pulsa Espacio para saltar los huecos.", "Press Space to jump over the gaps."),
    "TUT_JUMP_TOUCH": ("Pulsa el botón de salto para saltar los huecos.", "Press the jump button to jump over the gaps."),
    "TUT_DOUBLE_JUMP": (
        "Hueco grande: salta y pulsa Espacio otra vez en el aire. ¡Doble salto!",
        "Big gap: jump, then press Space again in the air. Double jump!",
    ),
    "TUT_DOUBLE_JUMP_TOUCH": (
        "Hueco grande: salta y pulsa salto otra vez en el aire. ¡Doble salto!",
        "Big gap: jump, then press jump again in the air. Double jump!",
    ),
    "TUT_DOUBLE_JUMP_UP": (
        "El doble salto también sube: haz el segundo salto en lo más alto.",
        "Double jump to climb too: do the second jump at the top of the first.",
    ),
    "TUT_COMBO": (
        "Combina: salto, doble salto y dash al final para cruzar.",
        "Combine: jump, double jump and dash at the end to make it across.",
    ),
    "TUT_LONG_JUMP": (
        "Salto largo: corre, pulsa Mayús para rodar y salta enseguida.",
        "Long jump: run, press Shift to roll and jump right away.",
    ),
    "TUT_LONG_JUMP_TOUCH": (
        "Salto largo: corre, pulsa Dash/Roll para rodar y salta enseguida.",
        "Long jump: run, press Dash/Roll to roll and jump right away.",
    ),
    "TUT_YOYO_GROUND": (
        "Pulsa E: el yo-yo se convierte en un disco delante de ti. ¡Corre encima para rebotar!",
        "Press E: the yo-yo becomes a disc in front of you. Run onto it to bounce!",
    ),
    "TUT_YOYO_RECHARGE": (
        "Rebotar te devuelve el doble salto y el dash. Rebota en el disco y salta otra vez.",
        "Bouncing gives you back your double jump and dash. Bounce on the disc, then jump again.",
    ),
    "TUT_YOYO_AIR": (
        "Salta y pulsa E en el aire: el disco aparece debajo. Rebota y usa el doble salto para subir.",
        "Jump and press E in the air: the disc appears below. Bounce, then double jump to climb.",
    ),
    "TUT_FINAL": (
        "Último reto: encadénalo todo. Salto, doble salto, yo-yo, salto y dash.",
        "Final challenge: chain it all. Jump, double jump, yo-yo, jump and dash.",
    ),
    "TUT_FINAL_TOUCH": (
        "Último reto: encadénalo todo. Salto, doble salto, Yo-yo, salto y Dash.",
        "Final challenge: chain it all. Jump, double jump, Yo-yo, jump and Dash.",
    ),
    "TUT_MOVE_TOUCH": ("Usa el joystick de la izquierda para moverte.", "Use the joystick on the left to move."),
    "TUT_DASH": ("Salta y pulsa Mayús en el aire para hacer un dash.", "Jump and press Shift in the air to dash."),
    "TUT_DASH_TOUCH": ("Salta y pulsa Dash/Roll en el aire para hacer un dash.", "Jump and press Dash/Roll in the air to dash."),
    "TUT_SLIDE": ("Corre y pulsa Mayús para rodar bajo el láser.", "Run and press Shift to roll under the laser."),
    "TUT_SLIDE_TOUCH": ("Corre y pulsa Dash/Roll para rodar bajo el láser.", "Run and press Dash/Roll to roll under the laser."),
    "TUT_YOYO_AIR_TOUCH": (
        "Salta y pulsa Yo-yo en el aire: el disco aparece debajo. Rebota y usa el doble salto para subir.",
        "Jump and press Yo-yo in the air: the disc appears below. Bounce, then double jump to climb.",
    ),
    "TUT_YOYO_GROUND_TOUCH": (
        "Pulsa Yo-yo: aparece un disco delante. ¡Corre sobre él para rebotar hasta arriba!",
        "Press Yo-yo: a disc appears ahead. Run onto it to bounce up!",
    ),
    "SELECT_TITLE": ("Elige una prueba", "Choose a run"),
    "SELECT_LAB": ("Laboratorio de mecánicas", "Mechanics lab"),
    "SELECT_LAB_HINT": ("Mide saltos, props y peligros", "Measure jumps, props and hazards"),
    "SELECT_PLAY": ("Jugar", "Play"),
    "SELECT_PENDING": ("Por aprobar", "Pending approval"),
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
