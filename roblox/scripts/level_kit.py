"""Kit para escribir niveles a mano (Fase 2, R18) en el esquema JSON v1
(roblox/levels_json/SCHEMA.md).

Un nivel es una cadena de piezas. Cada pieza se define por el hueco de borde a borde con
la anterior, la subida y, si hace falta, un giro o un desplazamiento lateral. Los huecos y
subidas se eligen con los escalones de roblox/ALCANCES_MOVIMIENTO.md (E0–E6, Y1–Y4) y
`report()` comprueba cada uno contra la tabla medida. El kit calcula las posiciones y
genera la ruta, las cámaras, las chispas guía, los avisos, los checkpoints y la meta.

Piezas de la cadena: plataformas fijas (`platform`) y elementos que se pisan
(`moving`, `timed`, `crumble`). Lo demás (trampolines, viento, peligros, gemas, decorado)
se coloca sobre una pieza con `t` (0 = borde delantero, 1 = borde trasero) y `x`
(desplazamiento lateral, + a la derecha del avance).

Unidades: metros, ejes de Godot (Y arriba; yaw 0 = adelante −Z, yaw + gira a la
izquierda); el origen de una plataforma es el centro de su cara caminable.
"""
import json
import math
from pathlib import Path

LEVELS_DIR = Path(__file__).resolve().parents[1] / "levels_json"


def r(value: float) -> float:
    return round(value, 3) + 0.0  # + 0.0 evita "-0.0" en el JSON


def heading(yaw: float):
    """Vectores (adelante, derecha) en el plano XZ para una yaw en grados."""
    a = math.radians(yaw)
    return (-math.sin(a), -math.cos(a)), (math.cos(a), -math.sin(a))


class Level:
    def __init__(self, level_id: str, **header):
        self.data = {
            "schema": 1,
            "id": level_id,
            "name_key": f"LEVEL_{level_id.upper()}",
            "hint_key": f"LEVEL_{level_id.upper()}_HINT",
            **header,
            "source": {"kind": "handmade"},
            "player_start": {"pos": [0.0, 0.1, 0.0], "yaw": 0.0},
            "route": [],
            "platforms": [],
            "elements": [],
            "hazards": [],
            "collectibles": {"gems": [], "sparks": []},
            "checkpoints": [],
            "camera_zones": [],
            "prompts": [],
            "decor": [],
        }
        # Piezas en orden: {x0, z0 (centro del borde delantero), yaw, fwd, right, y, len,
        # wid, kind, note}.
        self.pieces = []

    # ------------------------------------------------------------------ geometría

    def _place(self, length, width, gap, rise, x, turn, start, kind, note):
        if start or not self.pieces:
            yaw = 0.0
            fwd, right = heading(yaw)
            x0, z0, y = 0.0, 2.0, 0.0  # la salida queda 2 m por detrás del jugador
        else:
            last = self.pieces[-1]
            yaw = last["yaw"] + turn
            fwd, right = heading(yaw)
            bx, bz = self.point2(last, 1.0)
            if turn:
                # El giro pivota en el cuadrado final de la pieza anterior: se sale por
                # su lado, a `gap` de su borde.
                half = last["wid"] / 2
                bx -= last["fwd"][0] * half
                bz -= last["fwd"][1] * half
                x0, z0 = bx + fwd[0] * (half + gap), bz + fwd[1] * (half + gap)
            else:
                x0, z0 = bx + fwd[0] * gap, bz + fwd[1] * gap
            y = last["y"] + rise
        x0 += right[0] * x
        z0 += right[1] * x
        piece = {"x0": x0, "z0": z0, "yaw": yaw, "fwd": fwd, "right": right, "y": y, "len": length,
                 "wid": width, "gap": gap, "rise": rise, "kind": kind, "note": note}
        self.pieces.append(piece)
        center = self.at(piece, 0.5)
        self.data["route"].append({
            "kind": "plat" if kind == "platform" else kind, "pos": center, "yaw": r(yaw), "len": r(length),
            "wid": r(width), "gap": r(gap), "rise": r(rise), "node": f"Geometry/P{len(self.pieces) - 1}",
        })
        self.data["camera_zones"].append({
            "pos": center, "rot": [0.0, r(yaw), 0.0], "size": [r(width + 1), 14.0, r(length + gap)],
            "offset": [0.0, 5.0, r(gap / 2)], "yaw": r(yaw),
        })
        return piece, center

    def platform(self, length: float, width: float = 5.0, gap: float = 0.0, rise: float = 0.0,
                 x: float = 0.0, depth: float = 1.0, turn: float = 0.0, start: bool = False, note: str = ""):
        """Añade una plataforma tras la anterior: `gap` de borde a borde, `rise` en altura,
        `turn` grados de giro (pivota al final de la anterior) y `x` de desplazamiento
        lateral. `depth` es el grosor del bloque: con `gap` 0 y `depth` mayor que la
        subida, su cara delantera es una pared (repisa a la que se sube con el yo-yo)."""
        piece, center = self._place(length, width, gap, rise, x, turn, start, "platform", note)
        self.data["platforms"].append({
            "pos": center,
            "rot": [0.0, r(piece["yaw"]), 0.0],
            "asset": "PLAT_Isle_L" if length >= 8 else "PLAT_Isle_M",
            "collider": {"size": [r(width), r(depth), r(length)], "offset": [0.0, r(-depth / 2), 0.0]},
        })
        return piece

    def moving(self, gap: float, rise: float = 0.0, size: float = 3.0, travel: float = 6.0,
               side: bool = False, period: float = 4.0, phase: float = 0.0, pause: float = 0.25,
               x: float = 0.0, turn: float = 0.0, note: str = "plataforma móvil"):
        """Plataforma móvil en la cadena. Hacia delante: va de su sitio a `travel` m más
        allá (la pieza ocupa `size + travel`; el hueco siguiente se mide desde el extremo
        lejano). De lado (`side`): va `travel` m a la derecha (negativo, a la izquierda)."""
        length = size if side else size + travel
        piece, _center = self._place(length, size, gap, rise, x, turn, False, "moving", note)
        start = self.at(piece, size / 2 / length)
        vec = piece["right"] if side else piece["fwd"]
        self.data["elements"].append({
            "pos": start, "rot": [0.0, r(piece["yaw"]), 0.0], "type": "moving_platform",
            "params": {"travel": [r(vec[0] * travel), 0.0, r(vec[1] * travel)], "period": period,
                       "phase": phase, "pause_fraction": pause},
            "collider": {"size": [r(size), 0.5, r(size)], "offset": [0.0, -0.25, 0.0]},
        })
        return piece

    def timed(self, gap: float, rise: float = 0.0, on_time: float = 2.2, off_time: float = 1.4,
              phase: float = 0.0, x: float = 0.0, turn: float = 0.0, note: str = "plataforma temporizada"):
        """Plataforma temporizada (círculo de 3,1 m) en la cadena."""
        piece, center = self._place(3.1, 3.1, gap, rise, x, turn, False, "timed", note)
        self.data["elements"].append({
            "pos": center, "rot": [0.0, r(piece["yaw"]), 0.0], "type": "timed_platform",
            "params": {"on_time": on_time, "off_time": off_time, "phase": phase, "warning": 0.6},
        })
        return piece

    def crumble(self, gap: float, rise: float = 0.0, x: float = 0.0, turn: float = 0.0,
                note: str = "losa que se rompe"):
        """Losa de 3 × 3 m que se desmorona 0,55 s después de pisarla."""
        piece, center = self._place(3.0, 3.0, gap, rise, x, turn, False, "crumble", note)
        self.data["elements"].append({
            "pos": center, "rot": [0.0, r(piece["yaw"]), 0.0], "type": "crumble_platform",
            "params": {"warning_time": 0.55, "respawn_time": 3.0},
        })
        return piece

    def extra(self, piece, t: float, x: float, up: float = 0.0, length: float = 3.0, width: float = 3.0,
              depth: float = 1.0):
        """Plataforma fuera de la cadena (desvío opcional con gema): su centro queda en el
        punto (t, x) de `piece`, `up` metros más arriba. Devuelve una pieza para `at()`."""
        cx, cz = self.point2(piece, t, x)
        fx, fz = piece["fwd"]
        side = {"x0": cx - fx * length / 2, "z0": cz - fz * length / 2, "yaw": piece["yaw"], "fwd": piece["fwd"],
                "right": piece["right"], "y": piece["y"] + up, "len": length, "wid": width}
        self.data["platforms"].append({
            "pos": self.at(side, 0.5), "rot": self.rot(piece), "asset": "PLAT_Isle_M",
            "collider": {"size": [r(width), r(depth), r(length)], "offset": [0.0, r(-depth / 2), 0.0]},
        })
        return side

    @staticmethod
    def point2(piece, t: float, x: float = 0.0):
        fx, fz = piece["fwd"]
        rx, rz = piece["right"]
        d = piece["len"] * t
        return piece["x0"] + fx * d + rx * x, piece["z0"] + fz * d + rz * x

    @classmethod
    def at(cls, piece, t: float, up: float = 0.0, x: float = 0.0):
        """Punto de la cara caminable: t = 0 borde delantero, 1 borde trasero; `x` lateral."""
        px, pz = cls.point2(piece, t, x)
        return [r(px), r(piece["y"] + up), r(pz)]

    @staticmethod
    def rot(piece, extra: float = 0.0):
        return [0.0, r(piece["yaw"] + extra), 0.0]

    # ------------------------------------------------------------------ contenido

    def prompt(self, piece, key: str, t0: float = 0.0, t1: float = 1.0):
        """Aviso mientras el jugador está sobre el tramo [t0, t1] de `piece`."""
        mid = self.at(piece, (t0 + t1) / 2)
        length = abs(t1 - t0) * piece["len"]
        self.data["prompts"].append({
            "pos": mid, "rot": self.rot(piece), "key": key,
            "size": [r(piece["wid"] + 1), 6.0, r(max(length, 1.0))], "offset": [0.0, 2.5, 0.0],
        })

    def checkpoint(self, piece, t: float = 0.3):
        pos = self.at(piece, t)
        self.data["checkpoints"].append({
            "pos": pos, "rot": self.rot(piece), "spawn": [pos[0], r(pos[1] + 0.1), pos[2]],
        })

    def hazard(self, kind: str, piece, t: float, x: float = 0.0, **params):
        """Peligro sobre la pieza. Los láseres cruzan la pieza de lado a lado. `travel` de
        las patrullas va en coordenadas de la pieza ([lateral, 0, adelante])."""
        if "travel" in params:
            lateral, up, ahead = params["travel"]
            fx, fz = piece["fwd"]
            rx, rz = piece["right"]
            params["travel"] = [r(rx * lateral + fx * ahead), r(up), r(rz * lateral + fz * ahead)]
        self.data["hazards"].append({"pos": self.at(piece, t, x=x), "rot": self.rot(piece), "type": kind,
                                     "params": params})
        piece.setdefault("props", []).append((kind, t, x))

    def element(self, kind: str, piece, t: float, x: float = 0.0, **params):
        self.data["elements"].append({"pos": self.at(piece, t, x=x), "rot": self.rot(piece), "type": kind,
                                      "params": params})
        piece.setdefault("props", []).append((kind, t, x))

    def trampoline(self, piece, t: float, x: float = 0.0, strength: float = 20.0):
        """Trampolín: 20 → unos 7 m de subida (v² / 2 · 28); devuelve el doble salto y el dash."""
        self.element("trampoline", piece, t, x, strength=strength)

    def wind(self, piece, t: float, x: float = 0.0, height: float = 8.0):
        """Columna de viento: sube hasta flotar cerca de `height` sobre su base."""
        self.element("wind_column", piece, t, x, height=height, lift=62.0, max_up_speed=10.0)

    def boost(self, piece, t: float, x: float = 0.0, speed: float = 17.0):
        self.element("boost_pad", piece, t, x, speed=speed)

    def gem(self, pos):
        gems = self.data["collectibles"]["gems"]
        gems.append({"index": len(gems), "pos": [r(v) for v in pos]})

    def decor(self, asset: str, piece, t: float, x: float, yaw: float = 0.0, scale: float = 1.0):
        self.data["decor"].append({"pos": self.at(piece, t, x=x), "rot": self.rot(piece, yaw),
                                   "scale": [scale, scale, scale], "asset": asset})

    def goal(self, piece, t: float = 0.8):
        self.data["goal"] = {"pos": self.at(piece, t), "rot": self.rot(piece)}

    # ------------------------------------------------------------------ chispas

    def spark(self, pos):
        self.data["collectibles"]["sparks"].append([r(v) for v in pos])

    def row(self, piece, t0: float, t1: float, count: int, up: float = 1.0, x: float = 0.0):
        """Fila de chispas sobre la pieza."""
        for i in range(count):
            t = t0 + (t1 - t0) * (i / max(count - 1, 1))
            self.spark(self.at(piece, t, up, x))

    def arc(self, a, b, apex: float, count: int, up: float = 1.0, skip_ends: bool = True):
        """Arco de chispas sobre el hueco entre `a` (borde trasero) y `b` (borde delantero de la
        siguiente): parábola de altura `apex` sobre la más alta de las dos caras."""
        x0, z0 = self.point2(a, 1.0)
        x1, z1 = self.point2(b, 0.0)
        y0, y1 = a["y"] + up, b["y"] + up
        top = max(y0, y1) + apex
        steps = count + 1 if skip_ends else count - 1
        for i in range(count):
            s = (i + 1) / steps if skip_ends else i / steps
            base = y0 + (y1 - y0) * s
            # Parábola que pasa por y0, top y y1.
            lift = 4 * s * (1 - s) * (top - (y0 + y1) / 2)
            self.spark([x0 + (x1 - x0) * s, base + lift, z0 + (z1 - z0) * s])

    def column(self, piece, t: float, bottom: float, top: float, count: int, x: float = 0.0):
        """Columna vertical de chispas (subidas con yo-yo, trampolín o viento)."""
        for i in range(count):
            y = bottom + (top - bottom) * i / max(count - 1, 1)
            self.spark(self.at(piece, t, y, x))

    # ------------------------------------------------------------------ salida

    def span(self) -> float:
        """Longitud del recorrido siguiendo la cadena (suelo + huecos)."""
        return sum(p["len"] + p["gap"] for p in self.pieces)

    def write(self):
        lowest = min(p["y"] for p in self.pieces)
        self.data.setdefault("kill_height", r(lowest - 8.0))
        path = LEVELS_DIR / f"{self.data['id']}.json"
        path.write_text(json.dumps(self.data, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"{path.name}: {len(self.pieces)} piezas, {len(self.data['collectibles']['sparks'])} chispas, "
              f"{len(self.data['collectibles']['gems'])} gemas, {len(self.data['checkpoints'])} checkpoints, "
              f"{self.span():.1f} m de recorrido")
        return path


# ---------------------------------------------------------------------- comprobación

# Tabla medida (ALCANCES_MOVIMIENTO.md): nombre, altura máxima y alcance por subida.
MOVES = [
    ("salto", 2.31, {0: 3.87, 1: 3.35, 2: 2.61, -1: 4.19, -3: 4.92, -6: 5.65}),
    ("doble salto", 4.56, {0: 7.75, 1: 7.33, 2: 6.81, 3: 5.55, 4: 4.95, -1: 8.09, -3: 8.69, -6: 9.42}),
    ("salto + dash", 2.31, {0: 8.89, 1: 8.32, 2: 6.86, -1: 9.31, -3: 9.94, -6: 10.67}),
    ("doble + dash", 4.56, {0: 11.58, 1: 11.27, 2: 10.85, 3: 10.30, 4: 9.35, -1: 11.87, -3: 12.31, -6: 13.05}),
    ("salto largo", 1.91, {0: 9.71, 1: 8.29, -1: 10.85, -3: 12.54, -6: 14.80}),
    ("largo + doble", 3.31, {0: 13.95, 1: 13.50, 2: 13.08, 3: 12.27, -1: 14.26, -3: 14.89, -6: 15.60}),
    ("largo + doble + dash", 3.41, {0: 18.85, 1: 18.41, 2: 17.97, 3: 16.65, -1: 19.16, -3: 19.66, -6: 20.42}),
    ("yo-yo suelo", 4.52, {0: 5.55, 1: 5.23, 2: 4.81, 3: 4.39, 4: 3.66, -1: 5.86, -3: 6.38, -6: 7.01}),
    ("salto + yo-yo", 6.22, {0: 9.01, 1: 8.69, 2: 8.38, 3: 8.06, 4: 7.64, -1: 9.21, -3: 9.63, -6: 10.26}),
    ("salto + yo-yo + doble + dash", 7.80,
     {0: 17.48, 1: 17.27, 2: 16.95, 3: 16.64, 4: 16.33, -1: 17.69, -3: 18.11, -6: 18.74}),
    ("combo completo", 7.99, {0: 32.58, 1: 32.37, 2: 32.16, 3: 31.85, 4: 31.53, -1: 32.90, -3: 33.31, -6: 33.84}),
]
MARGIN = 0.85


def reach(table: dict, top: float, rise: float) -> float:
    """Alcance a una subida dada, interpolando la tabla; por encima de la última columna
    medida baja en línea recta hasta 1 m a la altura máxima."""
    keys = sorted(table)
    if rise > top:
        return -1.0
    if rise <= keys[0]:
        return table[keys[0]]
    for a, b in zip(keys, keys[1:]):
        if a <= rise <= b:
            return table[a] + (table[b] - table[a]) * (rise - a) / (b - a)
    last = keys[-1]
    return table[last] + (1.0 - table[last]) * (rise - last) / max(top - last, 0.01)


def needed(gap: float, rise: float):
    """Primer movimiento de la tabla (más simple primero) que cubre el hueco con margen."""
    for name, top, table in MOVES:
        if rise <= top * MARGIN and gap <= reach(table, top, rise) * MARGIN:
            return name
    return None


def _solids(level: Level):
    """Cajas sólidas del nivel: (nombre, centro xz, yaw, medio ancho, medio fondo, y0, y1)."""
    out = []
    for i, p in enumerate(level.data["platforms"]):
        (w, d, ln), oy = p["collider"]["size"], p["collider"]["offset"][1]
        out.append((f"plataforma {i}", p["pos"][0], p["pos"][2], p["rot"][1], w / 2, ln / 2,
                    p["pos"][1] + oy - d / 2, p["pos"][1] + oy + d / 2))
    for i, e in enumerate(level.data["elements"]):
        kind, (x, y, z), yaw = e["type"], e["pos"], e["rot"][1]
        if kind == "moving_platform":
            s = e["collider"]["size"][0]
            tx, _ty, tz = e["params"]["travel"]
            # Caja que cubre todo el recorrido (en ejes del mundo).
            out.append((f"móvil {i}", x + tx / 2, z + tz / 2, 0.0, s / 2 + abs(tx) / 2, s / 2 + abs(tz) / 2, y - 0.5, y))
        elif kind in ("timed_platform", "crumble_platform"):
            out.append((f"{kind} {i}", x, z, yaw, 1.5, 1.5, y - 0.6, y))
    return out


def _overlap_2d(a, b, shrink=0.05):
    """Prueba de ejes separados entre dos rectángulos orientados en XZ."""
    def corners(s):
        _n, cx, cz, yaw, hw, hd = s[:6]
        (fx, fz), (rx, rz) = heading(yaw)
        hw, hd = hw - shrink, hd - shrink
        return [(cx + rx * sx * hw + fx * sd * hd, cz + rz * sx * hw + fz * sd * hd) for sx in (-1, 1) for sd in (-1, 1)]

    ca, cb = corners(a), corners(b)
    for s in (a, b):
        for axis in heading(s[3]):
            pa = [c[0] * axis[0] + c[1] * axis[1] for c in ca]
            pb = [c[0] * axis[0] + c[1] * axis[1] for c in cb]
            if max(pa) <= min(pb) or max(pb) <= min(pa):
                return False
    return True


def check_overlaps(level: Level, headroom: float = 2.5):
    """Avisa de bloques que se cruzan o que dejan menos de `headroom` m de hueco encima de
    una cara caminable (cabezazos, techos que tapan un salto)."""
    solids = _solids(level)
    problems = []
    for i, a in enumerate(solids):
        for b in solids[i + 1:]:
            if not _overlap_2d(a, b):
                continue
            low, high = (a, b) if a[7] <= b[7] else (b, a)
            if high[6] < low[7] - 0.01 or high[6] - low[7] < headroom:
                problems.append(f"{a[0]} / {b[0]}: hueco vertical {high[6] - low[7]:+.1f} m")
    for line in problems:
        print("  !! solape:", line)
    return problems


def report(level: Level):
    """Lista de huecos y subidas con el movimiento mínimo que pide cada uno (85 % de lo
    medido). Las piezas con `note` dicen qué ayuda hay (trampolín, viento…)."""
    for i, piece in enumerate(level.pieces[1:], 1):
        gap, rise = piece["gap"], piece["rise"]
        if gap <= 0.01 and rise <= 0.01:
            move = "andar"
        else:
            move = needed(gap, rise) or ("solo con la ayuda de la nota" if piece["note"] else "!! FUERA DE ALCANCE sin ayuda")
        turn = f", giro {piece['yaw'] - level.pieces[i - 1]['yaw']:+.0f}" if piece["yaw"] != level.pieces[i - 1]["yaw"] else ""
        note = f"  [{piece['note']}]" if piece["note"] else ""
        print(f"  P{i - 1}->P{i}: hueco {gap:5.1f} m, subida {rise:+5.1f} m{turn} -> {move}{note}")
