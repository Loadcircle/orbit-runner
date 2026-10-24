"""Mundo 1 de la Fase 2 (R18/R20): diez niveles nuevos hechos con el kit, con los temas
de los nombres de Godot (LEVEL_W1_L1…L10). Huecos y subidas con los escalones de
roblox/ALCANCES_MOVIMIENTO.md; `report()` dice qué movimiento pide cada uno.

Estado: POR APROBAR (los marca `LevelCatalog` con `pending`). Medallas provisionales.

Uso: python build_world1.py [w1_l3 …]  → roblox/levels_json/w1_l*.json
"""
import math
import sys

from level_kit import Level, check_overlaps, report

# ---------------------------------------------------------------------- utilidades


def new_level(index: int, difficulty: str) -> Level:
    return Level(f"w1_l{index}", world=1, index=index, tutorial=False, biome="isles", difficulty=difficulty)


def corner_start(level: Level, prev, piece):
    """Punto de despegue hacia `piece`: el borde trasero de `prev`, o su lado si hay giro."""
    if piece["yaw"] == prev["yaw"]:
        return level.point2(prev, 1.0)
    half = prev["wid"] / 2
    bx, bz = level.point2(prev, 1.0 - half / prev["len"])
    fx, fz = piece["fwd"]
    return bx + fx * half, bz + fz * half


def arc_points(level: Level, start, end, y0: float, y1: float, apex: float, count: int):
    top = max(y0, y1) + apex
    for i in range(count):
        s = (i + 1) / (count + 1)
        base = y0 + (y1 - y0) * s
        lift = 4 * s * (1 - s) * (top - (y0 + y1) / 2)
        level.spark([start[0] + (end[0] - start[0]) * s, base + lift, start[1] + (end[1] - start[1]) * s])


def lift_prop(piece):
    for kind, t, x in piece.get("props", []):
        if kind in ("trampoline", "wind_column") and t >= 0.5:
            return t, x
    return None


def auto_sparks(level: Level, skip=()):
    """Chispas guía: fila sobre cada plataforma, arco sobre cada hueco y columna en las
    subidas con trampolín, viento o pared."""
    for i, piece in enumerate(level.pieces):
        if i in skip:
            continue
        busy = [t for _k, t, _x in piece.get("props", [])]
        if piece["kind"] == "platform":
            limit = min(busy) - 0.25 if busy else 0.85
            count = max(1, min(int(piece["len"] * (limit - 0.15) / 2.5), 5))
            if limit > 0.2 and count > 1:
                level.row(piece, 0.15, limit, count)
            elif limit > 0.2:
                level.spark(level.at(piece, 0.2, 1.0))
        else:
            level.spark(level.at(piece, 0.5 if piece["kind"] != "moving" else 1.5 / piece["len"], 1.0))
        if i == 0:
            continue
        prev = level.pieces[i - 1]
        gap, rise = piece["gap"], piece["rise"]
        lift = lift_prop(prev)
        if lift and rise > 3:
            t, x = lift
            level.column(prev, t, 2.0, rise + 0.5, 4, x=x)
        elif gap <= 0.5 and rise > 1.5:
            level.column(prev, 0.97, 1.5, rise + 1.0, max(3, int(rise / 1.5)))
        elif gap >= 1.5:
            count = max(2, min(round(gap / 1.8), 7))
            apex = 1.0 if rise > 2 else min(max(0.8 + 0.18 * gap, 1.0), 3.0)
            end = level.point2(piece, 0.0)
            arc_points(level, corner_start(level, prev, piece), end, prev["y"] + 1.0, piece["y"] + 1.0, apex, count)


def auto_decor(level: Level, assets):
    """Decorado en los bordes de las plataformas largas sin props."""
    n = 0
    for piece in level.pieces:
        if piece["kind"] != "platform" or piece["len"] < 8:
            continue
        side = 1 if n % 2 == 0 else -1
        x = side * (piece["wid"] / 2 - 0.6)
        level.decor(assets[n % len(assets)], piece, 0.25, x, 35 * n, 0.9)
        if not piece.get("props"):
            level.decor(assets[(n + 1) % len(assets)], piece, 0.7, -x, -50 * n, 0.8)
        n += 1


def finish(level: Level, decor=("ENV_Tree", "ENV_Bush", "ENV_Pine", "ENV_Rock_B")):
    auto_sparks(level)
    auto_decor(level, decor)
    waits = sum(1 for p in level.pieces if p["kind"] in ("moving", "timed"))
    gold = math.ceil(level.span() / 5.0 + 2.5 * waits)
    level.data["medals"] = {"gold": float(gold), "silver": float(math.ceil(gold * 1.6))}
    level.write()
    report(level)
    check_overlaps(level)
    print(f"  medallas provisionales: oro {gold} s, plata {math.ceil(gold * 1.6)} s")


# ---------------------------------------------------------------------- niveles


def w1_l1():
    """Islas de la Brisa: saltos, dobles saltos y los primeros trampolines."""
    L = new_level(1, "easy")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.platform(6, gap=2.5)
    p2 = L.platform(6, gap=2.5, rise=1.0)
    p3 = L.platform(8, gap=5.0)
    L.gem(L.at(L.extra(p3, 0.5, 6.5, up=0.5), 0.5))  # desvío lateral de un salto
    p4 = L.platform(6, gap=4.5, rise=2.0)
    p5 = L.platform(10, width=6, gap=2.0, rise=-1.0)
    L.checkpoint(p5, 0.2)
    L.trampoline(p5, 0.85)
    p6 = L.platform(8, gap=1.5, rise=5.0, note="trampolín")
    p7 = L.platform(6, gap=6.0, rise=-2.0)
    p8 = L.platform(5, gap=3.0)
    p9 = L.platform(8, gap=2.6, rise=1.0)
    L.checkpoint(p9, 0.2)
    p10 = L.platform(8, gap=5.5)
    L.trampoline(p10, 0.85)
    L.gem(L.at(p10, 0.85, 9.0))  # trampolín + doble salto
    p11 = L.platform(6, gap=1.0, rise=5.5, note="trampolín")
    p12 = L.platform(6, gap=5.0, rise=-1.0)
    p13 = L.platform(12, width=6, gap=5.5, rise=-2.0)
    L.gem(L.at(L.extra(p13, 0.4, 6.0), 0.5))
    L.goal(p13, 0.8)
    finish(L)


def w1_l2():
    """Saltos del Viento: columnas de viento y plataformas móviles."""
    L = new_level(2, "easy")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.platform(6, gap=3.0)
    p2 = L.platform(8, gap=5.0)
    L.wind(p2, 0.8)
    L.gem(L.at(p2, 0.8, 10.0))  # viento + doble salto
    p3 = L.platform(8, gap=1.0, rise=6.5, note="viento")
    p4 = L.moving(2.5, travel=5.0)
    p5 = L.platform(8, gap=2.5)
    L.checkpoint(p5, 0.3)
    L.gem(L.at(L.extra(p5, 0.5, -7.0, up=1.0), 0.5))
    p6 = L.platform(6, gap=4.5)
    L.wind(p6, 0.75)
    p7 = L.platform(6, gap=2.0, rise=6.0, note="viento")
    p8 = L.moving(3.0, rise=-1.0, travel=4.0, side=True)
    L.gem(L.at(p8, 0.5, 0.2, x=4.0))  # se recoge subido en la móvil
    p9 = L.platform(8, gap=3.0)
    p10 = L.platform(6, gap=5.5, rise=-1.0)
    L.checkpoint(p10, 0.3)
    p11 = L.moving(2.5, rise=1.0, travel=6.0)
    p12 = L.platform(6, gap=3.0)
    L.wind(p12, 0.75)
    p13 = L.platform(12, width=6, gap=1.5, rise=6.0, note="viento")
    L.goal(p13, 0.75)
    finish(L)


def w1_l3():
    """Puentes de Cristal: losas que se rompen y saltos largos."""
    L = new_level(3, "easy")
    p0 = L.platform(12, width=6, start=True)
    p1 = L.platform(10, gap=3.0)
    p2 = L.platform(10, gap=8.0, note="salto largo")
    L.gem(L.at(p1, 1.4, 2.6))  # sobre el hueco: largo + doble
    p3 = L.crumble(3.0)
    p4 = L.crumble(3.0)
    L.gem(L.at(L.extra(p4, 0.5, -6.0, up=1.0), 0.5))  # salto lateral desde una losa
    p5 = L.crumble(3.0, rise=0.5)
    p6 = L.platform(10, gap=3.0)
    L.checkpoint(p6, 0.3)
    p7 = L.platform(10, gap=9.0, rise=-1.5, note="salto largo")
    p8 = L.crumble(4.5)
    p9 = L.crumble(4.5, rise=1.0)
    p10 = L.platform(12, gap=5.0)
    L.checkpoint(p10, 0.25)
    p11 = L.platform(12, gap=10.5, note="largo + doble")
    L.gem(L.at(L.extra(p11, 0.6, 7.0, up=-1.0), 0.5))
    p12 = L.crumble(3.0)
    p13 = L.crumble(6.0)
    p14 = L.platform(12, width=6, gap=7.0)
    L.goal(p14, 0.75)
    finish(L, decor=("ENV_Crystal", "ENV_Rock_A", "ENV_Crystal", "ENV_Bush"))


def w1_l4():
    """Cumbre de las Nubes: una gran escalada con yo-yo, dobles saltos y trampolín."""
    L = new_level(4, "medium")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.platform(6, gap=1.5, rise=3.2)
    p2 = L.platform(6, rise=3.5, depth=4.0, note="pared: doble salto o yo-yo")
    p3 = L.platform(8, gap=2.0, rise=1.5)
    p4 = L.platform(6, gap=4.0, rise=3.0)
    p5 = L.platform(8, rise=5.0, depth=6.0, note="pared: salto + yo-yo")
    L.checkpoint(p5, 0.25)
    L.gem(L.at(p5, 0.6, 8.0))  # vertical: salto, doble, yo-yo, doble
    p6 = L.platform(6, gap=6.0, rise=3.0, note="doble + dash o yo-yo")
    p7 = L.platform(8, gap=2.0, rise=2.0)
    L.trampoline(p7, 0.85)
    p8 = L.platform(8, gap=1.0, rise=5.5, note="trampolín")
    L.gem(L.at(L.extra(p8, 0.5, 7.0, up=2.0), 0.5))
    p9 = L.platform(6, gap=5.0, rise=2.5)
    L.checkpoint(p9, 0.3)
    p10 = L.platform(6, rise=6.0, depth=7.0, note="pared: salto + yo-yo + doble")
    p11 = L.platform(6, gap=7.0, rise=4.0, note="combo con yo-yo")
    L.gem(L.at(L.extra(p11, 0.5, -7.0, up=2.0), 0.5))
    p12 = L.platform(12, width=6, gap=4.0, rise=1.0)
    L.goal(p12, 0.75)
    finish(L, decor=("ENV_Pine", "ENV_Rock_A", "ENV_Pine", "ENV_Rock_B"))


def w1_l5():
    """Praderas Flotantes: plataformas temporizadas en ola y escalones frágiles."""
    L = new_level(5, "medium")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.platform(6, gap=2.6, rise=1.0)
    p2 = L.timed(3.0, phase=0.0)
    p3 = L.timed(3.0, phase=0.2)
    p4 = L.timed(3.0, phase=0.4)
    L.gem(L.at(L.extra(p4, 0.5, 5.5), 0.5))
    p5 = L.platform(8, gap=3.0)
    L.checkpoint(p5, 0.3)
    p6 = L.crumble(2.5, rise=1.0)
    p7 = L.crumble(2.5, rise=1.0)
    p8 = L.crumble(2.5, rise=1.0)
    L.gem(L.at(p8, 0.5, 3.6))  # doble salto en la losa que tiembla
    p9 = L.platform(6, gap=4.0, rise=1.5)
    p10 = L.timed(5.0, phase=0.0)
    p11 = L.timed(5.0, rise=1.0, phase=0.25)
    p12 = L.platform(8, gap=5.0, rise=-1.0)
    L.checkpoint(p12, 0.3)
    p13 = L.crumble(6.0)
    p14 = L.crumble(6.0, rise=1.0)
    L.gem(L.at(L.extra(p14, 0.5, -6.0, up=-2.0), 0.5))
    p15 = L.platform(12, width=6, gap=7.0)
    L.goal(p15, 0.75)
    finish(L, decor=("ENV_Bush", "ENV_Tree", "ENV_Bush", "ENV_Rock_B"))


def w1_l6():
    """Arco de las Gaviotas: giros, pinchos y spinners."""
    L = new_level(6, "medium")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.platform(8, gap=3.0)
    L.hazard("spikes", p1, 0.5, x=-1.6)
    L.hazard("spikes", p1, 0.5, x=1.6)
    p2 = L.platform(8, width=6, gap=4.0, turn=90)
    L.hazard("spinner", p2, 0.5, degrees_per_second=70.0, start_angle=0.0)
    p3 = L.platform(6, gap=5.0)
    L.gem(L.at(L.extra(p3, 0.5, -6.5, up=1.0), 0.5))
    p4 = L.platform(10, gap=3.0, turn=-90)
    L.hazard("spikes", p4, 0.35, x=1.5)
    L.hazard("spikes", p4, 0.65, x=-1.5)
    p5 = L.platform(6, gap=6.0, rise=-1.0)
    L.checkpoint(p5, 0.3)
    p6 = L.platform(10, width=6, gap=2.0, rise=3.0, turn=-90)
    L.hazard("spinner", p6, 0.5, degrees_per_second=-80.0, start_angle=90.0)
    L.gem(L.at(p6, 0.5, 3.6))  # sobre el eje del spinner
    p7 = L.platform(6, gap=7.0, note="salto + dash")
    p8 = L.platform(10, gap=3.0, turn=90)
    L.hazard("spikes", p8, 0.3, x=-1.6)
    L.hazard("spikes", p8, 0.55, x=1.6)
    L.hazard("patrol", p8, 0.8, x=-1.8, travel=[3.6, 0.0, 0.0], speed=2.5)
    p9 = L.platform(8, gap=8.5, note="doble + dash")
    L.checkpoint(p9, 0.3)
    p10 = L.platform(6, gap=4.5, rise=2.0, turn=90)
    L.gem(L.at(L.extra(p10, 0.5, -6.5, up=2.0), 0.5))
    p11 = L.platform(12, width=6, gap=5.0, turn=-90)
    L.hazard("spinner", p11, 0.4, degrees_per_second=60.0, start_angle=45.0)
    L.goal(p11, 0.85)
    finish(L, decor=("ENV_Rock_A", "ENV_Bush", "ENV_Rock_B", "ENV_Tree"))


def w1_l7():
    """Colinas Saltarinas: trampolines altos encadenados."""
    L = new_level(7, "medium")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.platform(8, gap=3.0)
    L.trampoline(p1, 0.85)
    L.gem(L.at(p1, 0.85, 9.0))  # trampolín + doble salto
    p2 = L.platform(6, gap=1.0, rise=5.5, note="trampolín")
    p3 = L.platform(6, gap=6.0, rise=-2.0)
    L.trampoline(p3, 0.8, strength=24.0)
    p4 = L.platform(6, gap=1.5, rise=8.5, note="trampolín fuerte (≈10 m)")
    L.checkpoint(p4, 0.3)
    L.gem(L.at(L.extra(p4, 0.5, 6.5, up=3.0), 0.5))
    p5 = L.platform(6, gap=9.0, rise=-4.0)
    L.trampoline(p5, 0.8)
    p6 = L.platform(6, gap=2.0, rise=5.0, note="trampolín")
    L.trampoline(p6, 0.8)
    p7 = L.platform(8, gap=2.0, rise=4.5, note="trampolín")
    p8 = L.platform(6, gap=10.0, rise=-3.0)
    L.checkpoint(p8, 0.3)
    p9 = L.platform(6, gap=3.0)
    L.trampoline(p9, 0.8, strength=24.0)
    p10 = L.platform(6, gap=2.5, rise=8.0, note="trampolín fuerte")
    L.gem(L.at(L.extra(p10, 0.5, -6.5, up=2.0), 0.5))
    p11 = L.platform(12, width=6, gap=6.0, rise=-3.0)
    L.goal(p11, 0.75)
    finish(L)


def w1_l8():
    """Puente de Cometas: yo-yo en el aire y plataformas móviles."""
    L = new_level(8, "hard")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.platform(6, gap=3.0)
    p2 = L.platform(6, gap=5.0, rise=4.5, note="salto + yo-yo")
    p3 = L.moving(3.0, rise=-2.0, travel=5.0)
    L.gem(L.at(p3, 1.0, 4.0))  # en lo alto, al final del viaje de la móvil
    p4 = L.platform(6, gap=3.0)
    L.checkpoint(p4, 0.3)
    p5 = L.moving(6.0, rise=-1.0, travel=5.0, side=True)
    p6 = L.platform(6, gap=5.5, rise=4.2, note="salto + yo-yo")
    L.gem(L.at(L.extra(p6, 0.5, 7.0, up=3.0), 0.5))
    p7 = L.moving(4.0, rise=-1.0, travel=6.0, period=5.0)
    p8 = L.platform(10, gap=3.0)
    L.checkpoint(p8, 0.25)
    p9 = L.platform(6, gap=13.0, note="salto + yo-yo + doble + dash")
    L.gem(L.at(p8, 1.0 + 6.5 / 10, 5.0))  # alto sobre el hueco grande
    p10 = L.moving(5.0, rise=1.0, travel=-5.0, side=True)
    p11 = L.platform(6, gap=5.0, rise=5.0, note="combo con yo-yo desde la móvil")
    p12 = L.platform(12, width=6, gap=4.0)
    L.goal(p12, 0.75)
    finish(L)


def w1_l9():
    """Acantilados Celestes: plataformas móviles sobre el vacío, patrullas y láseres."""
    L = new_level(9, "hard")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.moving(3.0, travel=6.0)
    p2 = L.platform(8, gap=3.0)
    L.hazard("patrol", p2, 0.5, x=-2.0, travel=[4.0, 0.0, 0.0], speed=2.5)
    p3 = L.moving(5.0, rise=-1.0, travel=5.0, side=True)
    L.gem(L.at(p3, 0.5, 0.2, x=5.0))
    p4 = L.moving(4.0, travel=6.0, phase=0.5)
    p5 = L.platform(10, gap=3.0)
    L.checkpoint(p5, 0.25)
    L.hazard("laser", p5, 0.65, width=5.0, beam_height=1.05, period=2.4, on_fraction=0.5, phase=0.0)
    p6 = L.moving(6.0, rise=-1.0, travel=-6.0, side=True, period=5.0)
    p7 = L.timed(5.0, phase=0.0)
    L.gem(L.at(L.extra(p7, 0.5, 6.0, up=-2.0), 0.5))
    p8 = L.moving(4.0, rise=1.0, travel=8.0, period=5.0)
    p9 = L.platform(8, gap=3.0)
    L.checkpoint(p9, 0.3)
    L.hazard("patrol", p9, 0.6, x=2.0, travel=[-4.0, 0.0, 0.0], speed=3.0)
    p10 = L.platform(6, gap=9.0, rise=-1.0, note="doble + dash")
    p11 = L.moving(5.0, rise=2.0, travel=6.0, side=True)
    L.gem(L.at(p11, 0.5, 4.0, x=3.0))
    p12 = L.moving(5.0, travel=6.0, phase=0.25)
    p13 = L.platform(12, width=6, gap=4.0)
    L.hazard("laser", p13, 0.4, width=6.0, beam_height=1.05, period=2.4, on_fraction=0.5, phase=0.5)
    L.goal(p13, 0.8)
    finish(L, decor=("ENV_Rock_A", "ENV_Pine", "ENV_Rock_B", "ENV_Bush"))


def w1_l10():
    """Ojo del Huracán: viento, rebotes y precisión con giros en espiral."""
    L = new_level(10, "hard")
    p0 = L.platform(10, width=6, start=True)
    p1 = L.platform(6, gap=5.0)
    L.wind(p1, 0.8)
    L.gem(L.at(p1, 0.8, 10.0))  # viento + doble salto
    p2 = L.platform(6, gap=1.5, rise=6.5, turn=90, note="viento")
    p3 = L.platform(5, gap=8.5, rise=-1.0, note="doble + dash")
    L.trampoline(p3, 0.75)
    p4 = L.platform(6, gap=1.0, rise=5.5, note="trampolín")
    p5 = L.crumble(5.0, turn=90)
    p6 = L.crumble(5.0, rise=1.0)
    L.gem(L.at(L.extra(p6, 0.5, -6.0, up=1.0), 0.5))
    p7 = L.platform(8, gap=6.0)
    L.checkpoint(p7, 0.25)
    L.hazard("spikes", p7, 0.6, x=1.6)
    p8 = L.platform(6, gap=12.0, turn=90, note="salto + yo-yo + doble + dash")
    p9 = L.timed(4.0, phase=0.0)
    p10 = L.timed(4.0, rise=1.0, phase=0.25)
    p11 = L.platform(6, gap=5.0)
    L.checkpoint(p11, 0.25)
    L.wind(p11, 0.8, height=9.0)
    p12 = L.platform(6, gap=1.5, rise=7.0, note="viento alto")
    p13 = L.moving(6.0, rise=-2.0, travel=5.0, side=True)
    p14 = L.platform(6, gap=5.0, rise=4.5, note="salto + yo-yo")
    p15 = L.platform(14, width=6, gap=14.0, rise=-2.0, note="combo final")
    L.gem(L.at(p14, 1.0 + 7.0 / 6, 5.0))  # sobre el hueco final, alto
    L.hazard("laser", p15, 0.5, width=6.0, beam_height=1.05, period=0.0)
    L.goal(p15, 0.85)
    finish(L)


LEVELS = {f.__name__: f for f in (w1_l1, w1_l2, w1_l3, w1_l4, w1_l5, w1_l6, w1_l7, w1_l8, w1_l9, w1_l10)}

if __name__ == "__main__":
    for name in sys.argv[1:] or LEVELS:
        LEVELS[name]()
