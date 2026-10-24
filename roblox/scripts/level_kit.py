"""Kit para escribir niveles a mano (Fase 2, R18) en el esquema JSON v1
(roblox/levels_json/SCHEMA.md).

Un nivel es una secuencia de plataformas en línea recta hacia −Z. Cada una se define
por el hueco de borde a borde con la anterior y por la subida. Los huecos y subidas se
eligen con los escalones de roblox/ALCANCES_MOVIMIENTO.md (E0–E6, Y1–Y4). El kit calcula
las posiciones y genera la ruta, las cámaras, las chispas guía, los avisos, los
checkpoints y la meta.

Unidades: metros, ejes de Godot (Y arriba, adelante −Z); el origen de una plataforma es
el centro de su cara caminable.
"""
import json
from pathlib import Path

LEVELS_DIR = Path(__file__).resolve().parents[1] / "levels_json"


def r(value: float) -> float:
    return round(value, 3)


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
        self.pieces = []  # plataformas en orden: {front, back, y, x, wid, len}

    # ------------------------------------------------------------------ geometría

    def platform(self, length: float, width: float = 5.0, gap: float = 0.0, rise: float = 0.0,
                 x: float = 0.0, depth: float = 1.0, start: bool = False):
        """Añade una plataforma tras la anterior: `gap` de borde a borde, `rise` en altura.
        `depth` es el grosor del bloque: con `gap` 0 y `depth` mayor que la subida, su cara
        delantera es una pared (repisa a la que se sube con el yo-yo)."""
        if start or not self.pieces:
            front, y = 2.0, 0.0  # la salida queda 2 m por detrás del jugador
        else:
            last = self.pieces[-1]
            front, y = last["back"] - gap, last["y"] + rise
        back = front - length
        piece = {"front": front, "back": back, "y": y, "x": x, "wid": width, "len": length}
        self.pieces.append(piece)
        center = (front + back) / 2
        pos = [r(x), r(y), r(center)]
        self.data["platforms"].append({
            "pos": pos,
            "rot": [0.0, 0.0, 0.0],
            "asset": "PLAT_Isle_L" if length >= 8 else "PLAT_Isle_M",
            "collider": {"size": [r(width), r(depth), r(length)], "offset": [0.0, r(-depth / 2), 0.0]},
        })
        self.data["route"].append({
            "kind": "plat", "pos": pos, "yaw": 0.0, "len": r(length), "wid": r(width),
            "gap": r(gap), "rise": r(rise), "node": f"Geometry/P{len(self.pieces) - 1}",
        })
        self.data["camera_zones"].append({
            "pos": pos, "rot": [0.0, 0.0, 0.0], "size": [r(width + 1), 14.0, r(length + gap)],
            "offset": [0.0, 5.0, r(gap / 2)], "yaw": 0.0,
        })
        return piece

    @staticmethod
    def at(piece, t: float, up: float = 0.0, x: float | None = None):
        """Punto de la cara caminable: t = 0 borde delantero, 1 borde trasero."""
        z = piece["front"] + (piece["back"] - piece["front"]) * t
        return [r(piece["x"] if x is None else x), r(piece["y"] + up), r(z)]

    # ------------------------------------------------------------------ contenido

    def prompt(self, piece, key: str, t0: float = 0.0, t1: float = 1.0):
        """Aviso del tutorial mientras el jugador está sobre el tramo [t0, t1] de `piece`."""
        a, b = self.at(piece, t0), self.at(piece, t1)
        length = abs(b[2] - a[2])
        self.data["prompts"].append({
            "pos": [a[0], a[1], r((a[2] + b[2]) / 2)], "rot": [0.0, 0.0, 0.0], "key": key,
            "size": [r(piece["wid"] + 1), 6.0, r(max(length, 1.0))], "offset": [0.0, 2.5, 0.0],
        })

    def checkpoint(self, piece, t: float = 0.3):
        pos = self.at(piece, t)
        self.data["checkpoints"].append({
            "pos": pos, "rot": [0.0, 0.0, 0.0], "spawn": [pos[0], r(pos[1] + 0.1), pos[2]],
        })

    def hazard(self, kind: str, piece, t: float, **params):
        self.data["hazards"].append({"pos": self.at(piece, t), "rot": [0.0, 0.0, 0.0], "type": kind,
                                     "params": params})

    def element(self, kind: str, piece, t: float, **params):
        self.data["elements"].append({"pos": self.at(piece, t), "rot": [0.0, 0.0, 0.0], "type": kind,
                                      "params": params})

    def decor(self, asset: str, piece, t: float, x: float, yaw: float = 0.0, scale: float = 1.0):
        self.data["decor"].append({"pos": self.at(piece, t, x=x), "rot": [0.0, r(yaw), 0.0],
                                   "scale": [scale, scale, scale], "asset": asset})

    def goal(self, piece, t: float = 0.8):
        self.data["goal"] = {"pos": self.at(piece, t), "rot": [0.0, 0.0, 0.0]}

    # ------------------------------------------------------------------ chispas

    def spark(self, pos):
        self.data["collectibles"]["sparks"].append([r(v) for v in pos])

    def row(self, piece, t0: float, t1: float, count: int, up: float = 1.0):
        """Fila de chispas sobre la plataforma."""
        for i in range(count):
            t = t0 + (t1 - t0) * (i / max(count - 1, 1))
            self.spark(self.at(piece, t, up))

    def arc(self, a, b, apex: float, count: int, up: float = 1.0, skip_ends: bool = True):
        """Arco de chispas sobre el hueco entre `a` (borde trasero) y `b` (borde delantero de la
        siguiente): parábola de altura `apex` sobre la más alta de las dos caras."""
        z0, z1 = a["back"], b["front"]
        y0, y1 = a["y"] + up, b["y"] + up
        top = max(y0, y1) + apex
        steps = count + 1 if skip_ends else count - 1
        for i in range(count):
            s = (i + 1) / steps if skip_ends else i / steps
            base = y0 + (y1 - y0) * s
            # Parábola que pasa por y0, top y y1.
            lift = 4 * s * (1 - s) * (top - (y0 + y1) / 2)
            self.spark([a["x"] + (b["x"] - a["x"]) * s, base + lift, z0 + (z1 - z0) * s])

    def column(self, piece, t: float, bottom: float, top: float, count: int):
        """Columna vertical de chispas (subidas con yo-yo)."""
        for i in range(count):
            y = bottom + (top - bottom) * i / max(count - 1, 1)
            self.spark(self.at(piece, t, y))

    # ------------------------------------------------------------------ salida

    def write(self):
        lowest = min(p["y"] for p in self.pieces)
        self.data.setdefault("kill_height", r(lowest - 8.0))
        path = LEVELS_DIR / f"{self.data['id']}.json"
        path.write_text(json.dumps(self.data, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
        total = sum(p["len"] for p in self.pieces)
        span = self.pieces[0]["front"] - self.pieces[-1]["back"]
        print(f"{path.name}: {len(self.pieces)} plataformas, {len(self.data['collectibles']['sparks'])} chispas, "
              f"{span:.1f} m de recorrido ({total:.1f} m de suelo)")
        return path


def report(level: Level):
    """Lista de huecos y subidas para revisar los escalones."""
    for i, piece in enumerate(level.pieces[1:], 1):
        prev = level.pieces[i - 1]
        gap = prev["back"] - piece["front"]
        print(f"  P{i - 1}->P{i}: hueco {gap:5.1f} m, subida {piece['y'] - prev['y']:+5.1f} m, "
              f"plataforma {piece["len"]:.0f}x{piece['wid']:.0f} m a y={piece['y']:.1f}")

