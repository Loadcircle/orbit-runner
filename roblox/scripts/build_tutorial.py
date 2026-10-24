"""Tutorial de la Fase 2 (R18): enseña el moveset de la plantilla de uno en uno y termina
con un combo. Los huecos y las subidas salen de los escalones de
roblox/ALCANCES_MOVIMIENTO.md (indicados en cada tramo).

Uso: python roblox/scripts/build_tutorial.py  → roblox/levels_json/tutorial.json
"""
from level_kit import Level, report

level = Level(
    "tutorial",
    world=1,
    index=0,
    tutorial=True,
    biome="isles",
    difficulty="",
    medals={"gold": 40.0, "silver": 70.0},
)

# 1. Moverse y saltar (E1)
p0 = level.platform(10, width=6, start=True)
level.prompt(p0, "TUT_MOVE", 0.0, 0.55)
level.prompt(p0, "TUT_JUMP", 0.55, 1.0)
p1 = level.platform(5, width=6, gap=2.5)
p2 = level.platform(6, width=6, gap=2.3, rise=1.0)

# 2. Doble salto: hueco E2 y subida E2
level.prompt(p2, "TUT_DOUBLE_JUMP")
p3 = level.platform(6, width=6, gap=5.0)
level.prompt(p3, "TUT_DOUBLE_JUMP_UP")
p4 = level.platform(14, width=6, gap=1.5, rise=3.2)

# 3. Rodar bajo el láser (siempre encendido) y checkpoint
level.prompt(p4, "TUT_SLIDE", 0.0, 0.42)
level.hazard("laser", p4, 0.5, width=5.8, beam_height=1.05, period=0.0, on_fraction=0.6, phase=0.0)
level.checkpoint(p4, 0.7)

# 4. Dash: salto + dash (E3)
level.prompt(p4, "TUT_DASH", 0.62, 1.0)
p5 = level.platform(6, width=5, gap=7.0)

# 5. Primer combo: doble salto + dash (E4)
level.prompt(p5, "TUT_COMBO")
p6 = level.platform(12, width=5, gap=9.0)
level.checkpoint(p6, 0.15)

# 6. Salto largo hacia abajo (E5, bajada de 2 m), con carrerilla recta
level.prompt(p6, "TUT_LONG_JUMP", 0.25, 1.0)
p7 = level.platform(12, width=6, gap=10.0, rise=-2.0)

# 7. Yo-yo desde el suelo: repisa de 3,5 m (Y1) y luego pared de 5,5 m (rebote + salto)
level.prompt(p7, "TUT_YOYO_GROUND", 0.2, 1.0)
p8 = level.platform(6, width=6, rise=3.5, depth=5.0)
level.prompt(p8, "TUT_YOYO_RECHARGE")
p9 = level.platform(10, width=6, rise=5.5, depth=6.5)
level.checkpoint(p9, 0.2)

# 8. Yo-yo en el aire: subida de 5 m con hueco de 7 m (Y3, sin yo-yo no se llega)
level.prompt(p9, "TUT_YOYO_AIR", 0.3, 1.0)
p10 = level.platform(10, width=5, gap=7.0, rise=5.0)
level.checkpoint(p10, 0.15)

# 9. Reto final: hueco de 14 m (Y3 o E6), hay que encadenar
level.prompt(p10, "TUT_FINAL", 0.25, 1.0)
p11 = level.platform(12, width=6, gap=14.0)
level.prompt(p11, "TUT_GOAL", 0.2, 1.0)
level.goal(p11, 0.75)

# Chispas guía: marcan la trayectoria de cada lección.
level.row(p0, 0.3, 0.9, 4)
level.arc(p0, p1, 1.2, 2)
level.row(p1, 0.3, 0.7, 2)
level.arc(p1, p2, 1.2, 2)
level.row(p2, 0.3, 0.7, 2)
level.arc(p2, p3, 2.5, 3)
level.row(p3, 0.3, 0.7, 2)
level.arc(p3, p4, 1.0, 2)
level.row(p4, 0.08, 0.32, 3)
level.spark(level.at(p4, 0.5, 0.5))  # bajo el láser: premio por rodar
level.row(p4, 0.66, 0.92, 3)
level.arc(p4, p5, 1.2, 4)
level.row(p5, 0.3, 0.7, 2)
level.arc(p5, p6, 2.5, 5)
level.row(p6, 0.3, 0.9, 4)
level.arc(p6, p7, 1.0, 5)
level.row(p7, 0.2, 0.6, 3)
level.column(p7, 0.93, 1.5, 4.0, 3)
level.column(p8, 0.9, 1.5, 6.0, 4)
level.row(p9, 0.3, 0.9, 3)
level.arc(p9, p10, 2.0, 4)
level.row(p10, 0.3, 0.9, 3)
level.arc(p10, p11, 2.5, 7)
level.row(p11, 0.2, 0.55, 3)

# Decorado a los lados del camino (plantas y rocas de la plantilla).
level.decor("ENV_Tree", p0, 0.15, -2.4, 30, 1.1)
level.decor("ENV_Pine", p0, 0.45, 2.4, -20, 0.85)
level.decor("ENV_Bush", p4, 0.85, -2.4, 160, 1.0)
level.decor("ENV_Rock_B", p6, 0.6, 2.0, -120, 1.0)
level.decor("ENV_Bush", p7, 0.4, -2.4, 10, 0.9)
level.decor("ENV_Pine", p9, 0.6, 2.4, 50, 0.85)
level.decor("ENV_Bush", p11, 0.3, 2.4, -15, 0.85)
level.decor("ENV_Tree", p11, 0.6, -2.4, 70, 1.0)

level.write()
report(level)
