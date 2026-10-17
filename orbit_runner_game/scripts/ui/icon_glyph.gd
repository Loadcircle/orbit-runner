@tool
class_name IconGlyph
extends Control
## Vector icons drawn in code so the UI stays crisp at any scale without
## external image assets. Shapes back up colour (accessibility).

enum Icon { NONE, JUMP, YOYO, ACTION, PAUSE, GEM, SPARK, MEDAL, LOCK, GEAR, TROPHY, STAR, CHECK, BACK, PLAY, SHIRT, CLOCK, RESTART, HOME, ARROW_RIGHT, ARROW_LEFT }

@export var icon := Icon.NONE:
	set(value):
		icon = value
		queue_redraw()
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()
@export var outline := Color(0.05, 0.1, 0.22, 0.9):
	set(value):
		outline = value
		queue_redraw()
@export var filled := true:
	set(value):
		filled = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var w := maxf(s * 0.07, 2.0)
	match icon:
		Icon.JUMP:
			# Spring zig-zag with an up arrow.
			var pts := PackedVector2Array()
			for i in 7:
				var x := c.x + (s * 0.22 if i % 2 == 0 else -s * 0.22)
				pts.append(Vector2(x, c.y + s * 0.35 - i * s * 0.08))
			draw_polyline(pts, outline, w + 3.0)
			draw_polyline(pts, color, w)
			_arrow_up(Vector2(c.x, c.y - s * 0.32), s * 0.18, w)
		Icon.YOYO:
			draw_circle(c, s * 0.36, outline)
			draw_circle(c, s * 0.32, color)
			draw_arc(c, s * 0.2, 0, TAU, 32, Color(outline, 0.8), w * 0.8)
			draw_circle(c, s * 0.08, Color.WHITE)
		Icon.ACTION:
			# Speed lines + chevron (slide on ground, dash in the air).
			for i in 3:
				var y := c.y - s * 0.18 + i * s * 0.18
				draw_line(Vector2(c.x - s * 0.38, y), Vector2(c.x - s * 0.05, y), outline, w + 3.0)
				draw_line(Vector2(c.x - s * 0.38, y), Vector2(c.x - s * 0.05, y), color, w)
			var chev := PackedVector2Array([Vector2(c.x + 0.02 * s, c.y - s * 0.28), Vector2(c.x + s * 0.32, c.y),
					Vector2(c.x + 0.02 * s, c.y + s * 0.28)])
			draw_polyline(chev, outline, w * 1.4 + 3.0)
			draw_polyline(chev, color, w * 1.4)
		Icon.PAUSE:
			for dx in [-0.14, 0.14]:
				var r := Rect2(c.x + dx * s - s * 0.07, c.y - s * 0.26, s * 0.14, s * 0.52)
				draw_rect(r.grow(2.0), outline)
				draw_rect(r, color)
		Icon.GEM:
			var gem := PackedVector2Array([Vector2(c.x, c.y - s * 0.4), Vector2(c.x + s * 0.3, c.y - s * 0.08),
					Vector2(c.x, c.y + s * 0.42), Vector2(c.x - s * 0.3, c.y - s * 0.08)])
			_poly(gem, w)
			draw_line(Vector2(c.x - s * 0.3, c.y - s * 0.08), Vector2(c.x + s * 0.3, c.y - s * 0.08), Color(outline, 0.6), w * 0.6)
		Icon.SPARK, Icon.STAR:
			var pts := PackedVector2Array()
			var points := 4 if icon == Icon.SPARK else 5
			for i in points * 2:
				var r := s * (0.42 if i % 2 == 0 else (0.15 if icon == Icon.SPARK else 0.19))
				var a := -PI / 2 + i * PI / points
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			_poly(pts, w)
		Icon.MEDAL:
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - s * 0.2, c.y - s * 0.45), Vector2(c.x - s * 0.02, c.y - s * 0.45),
					Vector2(c.x + s * 0.06, c.y - s * 0.05), Vector2(c.x - s * 0.1, c.y - s * 0.05)]), Color(0.86, 0.25, 0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(c.x + s * 0.2, c.y - s * 0.45), Vector2(c.x + s * 0.02, c.y - s * 0.45),
					Vector2(c.x - s * 0.06, c.y - s * 0.05), Vector2(c.x + s * 0.1, c.y - s * 0.05)]), Color(0.2, 0.45, 0.85))
			draw_circle(Vector2(c.x, c.y + s * 0.12), s * 0.29, outline)
			draw_circle(Vector2(c.x, c.y + s * 0.12), s * 0.25, color)
			draw_circle(Vector2(c.x, c.y + s * 0.12), s * 0.14, color.lightened(0.35))
		Icon.LOCK:
			draw_arc(Vector2(c.x, c.y - s * 0.08), s * 0.18, PI, TAU, 16, outline, w * 1.6 + 3.0)
			draw_arc(Vector2(c.x, c.y - s * 0.08), s * 0.18, PI, TAU, 16, color, w * 1.6)
			var body := Rect2(c.x - s * 0.28, c.y - s * 0.08, s * 0.56, s * 0.44)
			draw_rect(body.grow(2.0), outline)
			draw_rect(body, color)
			draw_circle(Vector2(c.x, c.y + s * 0.12), s * 0.06, outline)
		Icon.GEAR:
			var pts := PackedVector2Array()
			for i in 24:
				var r := s * (0.44 if i % 4 < 2 else 0.31)
				var a := (i - 0.5) * TAU / 24.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			_poly(pts, w)
			draw_circle(c, s * 0.12, outline)
		Icon.TROPHY:
			var cup := PackedVector2Array([Vector2(c.x - s * 0.3, c.y - s * 0.38), Vector2(c.x + s * 0.3, c.y - s * 0.38),
					Vector2(c.x + s * 0.22, c.y + s * 0.02), Vector2(c.x + s * 0.06, c.y + s * 0.12), Vector2(c.x + s * 0.06, c.y + s * 0.26),
					Vector2(c.x + s * 0.2, c.y + s * 0.4), Vector2(c.x - s * 0.2, c.y + s * 0.4), Vector2(c.x - s * 0.06, c.y + s * 0.26),
					Vector2(c.x - s * 0.06, c.y + s * 0.12), Vector2(c.x - s * 0.22, c.y + s * 0.02)])
			_poly(cup, w)
			draw_arc(Vector2(c.x - s * 0.3, c.y - s * 0.2), s * 0.12, PI * 0.5, PI * 1.5, 10, color, w)
			draw_arc(Vector2(c.x + s * 0.3, c.y - s * 0.2), s * 0.12, -PI * 0.5, PI * 0.5, 10, color, w)
		Icon.CHECK:
			var pts := PackedVector2Array([Vector2(c.x - s * 0.3, c.y), Vector2(c.x - s * 0.08, c.y + s * 0.24), Vector2(c.x + s * 0.34, c.y - s * 0.26)])
			draw_polyline(pts, outline, w * 1.6 + 3.0)
			draw_polyline(pts, color, w * 1.6)
		Icon.BACK, Icon.ARROW_LEFT:
			_chevron(c, s, -1.0, w)
		Icon.ARROW_RIGHT, Icon.PLAY:
			if icon == Icon.PLAY:
				_poly(PackedVector2Array([Vector2(c.x - s * 0.22, c.y - s * 0.32), Vector2(c.x + s * 0.32, c.y),
						Vector2(c.x - s * 0.22, c.y + s * 0.32)]), w)
			else:
				_chevron(c, s, 1.0, w)
		Icon.SHIRT:
			var shirt := PackedVector2Array([Vector2(c.x - s * 0.14, c.y - s * 0.36), Vector2(c.x - s * 0.4, c.y - s * 0.2),
					Vector2(c.x - s * 0.3, c.y - s * 0.02), Vector2(c.x - s * 0.22, c.y - s * 0.08), Vector2(c.x - s * 0.22, c.y + s * 0.38),
					Vector2(c.x + s * 0.22, c.y + s * 0.38), Vector2(c.x + s * 0.22, c.y - s * 0.08), Vector2(c.x + s * 0.3, c.y - s * 0.02),
					Vector2(c.x + s * 0.4, c.y - s * 0.2), Vector2(c.x + s * 0.14, c.y - s * 0.36), Vector2(c.x, c.y - s * 0.26)])
			_poly(shirt, w)
		Icon.CLOCK:
			draw_circle(c, s * 0.4, outline)
			draw_circle(c, s * 0.35, color)
			draw_line(c, c + Vector2(0, -s * 0.24), outline, w)
			draw_line(c, c + Vector2(s * 0.16, 0), outline, w)
		Icon.RESTART:
			draw_arc(c, s * 0.28, -PI * 0.2, PI * 1.5, 24, outline, w * 1.4 + 3.0)
			draw_arc(c, s * 0.28, -PI * 0.2, PI * 1.5, 24, color, w * 1.4)
			var tip := c + Vector2(cos(-PI * 0.2), sin(-PI * 0.2)) * s * 0.28
			_poly(PackedVector2Array([tip + Vector2(-s * 0.14, -s * 0.02), tip + Vector2(s * 0.1, -s * 0.12), tip + Vector2(s * 0.06, s * 0.14)]), w * 0.5)
		Icon.HOME:
			var house := PackedVector2Array([Vector2(c.x, c.y - s * 0.38), Vector2(c.x + s * 0.38, c.y - s * 0.02),
					Vector2(c.x + s * 0.26, c.y - s * 0.02), Vector2(c.x + s * 0.26, c.y + s * 0.36), Vector2(c.x - s * 0.26, c.y + s * 0.36),
					Vector2(c.x - s * 0.26, c.y - s * 0.02), Vector2(c.x - s * 0.38, c.y - s * 0.02)])
			_poly(house, w)


func _poly(points: PackedVector2Array, w: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, outline, w + 3.0)
	if filled:
		draw_colored_polygon(points, color)
	else:
		draw_polyline(closed, color, w)


func _arrow_up(tip: Vector2, size_px: float, w: float) -> void:
	_poly(PackedVector2Array([tip, tip + Vector2(size_px, size_px), tip + Vector2(-size_px, size_px)]), w * 0.6)


func _chevron(c: Vector2, s: float, dir: float, w: float) -> void:
	var pts := PackedVector2Array([Vector2(c.x - dir * s * 0.12, c.y - s * 0.3), Vector2(c.x + dir * s * 0.18, c.y),
			Vector2(c.x - dir * s * 0.12, c.y + s * 0.3)])
	draw_polyline(pts, outline, w * 1.6 + 3.0)
	draw_polyline(pts, color, w * 1.6)
