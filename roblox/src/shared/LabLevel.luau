--!strict
-- Laboratorio de mecánicas (guía §3.9): pista de pruebas con todas las plataformas,
-- props y peligros, y reglas con marcas cada metro (y cada 5 studs) para medir alcances.
-- Usa el mismo esquema JSON v1 que los niveles exportados (metros, ejes de Godot), más
-- dos extensiones solo del laboratorio que entiende el LevelBuilder:
--   rulers: { from = {x,y,z}, to = {x,y,z} }   → regla con marcas por metro y stud
--   labels: { pos = {x,y,z}, text = "..." }    → cartel flotante
-- Zonas (−Z es adelante):
--   A  x = 0     pista de calibración lisa de 12 × 150 m con regla
--   B  x = −30   huecos de diseño: salto 3.5/5.9, largo 6/7, dash 7.5/9, disco 9.5/13
--   C  x = +30   trampolines (20 y 24) con marcas de altura, viento, boost, plataformas
--                móvil/temporizada/desmoronable, peligros, checkpoint, gemas, chispas y meta

local function plat(list: { any }, x: number, y: number, z: number, wid: number, len: number, asset: string?)
	table.insert(list, {
		asset = asset or "PLAT_Isle_M",
		pos = { x, y, z },
		rot = { 0, 0, 0 },
		collider = { size = { wid, 1, len }, offset = { 0, -0.5, 0 } },
	})
end

local platforms = {}
local elements = {}
local hazards = {}
local sparks = {}
local rulers = {}
local labels = {}
local checkpoints = {}
local cameraZones = {}

-- Plataforma de salida que une las tres zonas.
plat(platforms, 0, 0, -6, 72, 12, "PLAT_Lab_Hub")

-- A: pista de calibración (empieza tras la salida).
plat(platforms, 0, 0, -87, 12, 150, "PLAT_Lab_Runway")
table.insert(rulers, { from = { 5.5, 0, 0 }, to = { 5.5, 0, -160 } })
table.insert(labels, { pos = { 0, 3, -2 }, text = "A · Pista de calibración (regla cada 1 m · marca fina cada 5 studs)" })
table.insert(cameraZones, { pos = { 0, 0, -6 }, rot = { 0, 0, 0 }, size = { 72, 30, 12 }, offset = { 0, 10, 0 }, yaw = 0 })
table.insert(cameraZones, { pos = { 0, 0, -87 }, rot = { 0, 0, 0 }, size = { 13, 30, 150 }, offset = { 0, 10, 0 }, yaw = 0 })

-- B: huecos de diseño (cómodo / máximo de la guía §3.9), con pistas de 8 m.
table.insert(cameraZones, { pos = { -30, 0, -100 }, rot = { 0, 0, 0 }, size = { 12, 40, 220 }, offset = { 0, 10, 0 }, yaw = 0 })
local gaps = {
	{ 3.5, "Salto 3.5 m (cómodo)" },
	{ 5.9, "Salto 5.9 m (máx.)" },
	{ 6.0, "Salto largo 6 m" },
	{ 7.0, "Salto largo 7 m (máx.)" },
	{ 7.5, "Salto + dash 7.5 m" },
	{ 9.0, "Salto + dash 9 m (máx.)" },
	{ 9.5, "Salto + disco 9.5 m" },
	{ 13.0, "Salto + disco 13 m (máx.)" },
}
local edge = -12 -- borde delantero de la plataforma anterior
for _, gap in gaps do
	local runway = 8 -- plataformas largas para coger carrerilla
	local nearEdge = edge - gap[1]
	local center = nearEdge - runway / 2
	plat(platforms, -30, 0, center, 4, runway)
	table.insert(labels, { pos = { -30, 2.6, edge - gap[1] / 2 }, text = gap[2] })
	table.insert(rulers, { from = { -27.6, 0, edge }, to = { -27.6, 0, nearEdge } })
	edge = nearEdge - runway
end

-- C: props y peligros.
local cx = 30
table.insert(cameraZones, { pos = { cx, 0, -90 }, rot = { 0, 0, 0 }, size = { 30, 40, 190 }, offset = { 0, 10, 0 }, yaw = 0 })
-- Trampolines con columnas de referencia de altura.
plat(platforms, cx, 0, -22, 14, 16)
table.insert(elements, { type = "trampoline", pos = { cx - 3.5, 0, -22 }, rot = { 0, 0, 0 }, params = { strength = 20 } })
table.insert(elements, { type = "trampoline", pos = { cx + 3.5, 0, -22 }, rot = { 0, 0, 0 }, params = { strength = 24 } })
table.insert(rulers, { from = { cx - 6, 0, -22 }, to = { cx - 6, 11, -22 } })
table.insert(rulers, { from = { cx + 6, 0, -22 }, to = { cx + 6, 11, -22 } })
table.insert(labels, { pos = { cx - 3.5, 3, -18 }, text = "Trampolín 20 (+5 / +7.1 m)" })
table.insert(labels, { pos = { cx + 3.5, 3, -18 }, text = "Trampolín 24 (+8 / +10.3 m)" })
-- Viento de 8 m con plataforma arriba (y un camino por abajo).
plat(platforms, cx, 0, -38, 8, 10)
table.insert(elements, { type = "wind_column", pos = { cx, 0, -38 }, rot = { 0, 0, 0 },
	params = { height = 8, lift = 62, max_up_speed = 10 } })
plat(platforms, cx, 8, -46, 4, 4)
table.insert(labels, { pos = { cx, 3, -34 }, text = "Viento 8 m" })
-- Boost pad en una pista (huecos de ≤ 3 m entre piezas para recorrer la zona andando).
plat(platforms, cx, 0, -54, 6, 16)
table.insert(elements, { type = "boost_pad", pos = { cx, 0, -50 }, rot = { 0, 0, 0 }, params = { speed = 17 } })
table.insert(labels, { pos = { cx, 3, -47 }, text = "Boost 17 m/s" })
-- Plataforma móvil (recorrido 0,0,−6 en 4 s), cadena temporizada y una que se desmorona.
table.insert(elements, { type = "moving_platform", pos = { cx, 0, -64 }, rot = { 0, 0, 0 },
	params = { travel = { 0, 0, -6 }, period = 4, phase = 0, pause_fraction = 0.25 },
	collider = { size = { 3, 0.5, 3 }, offset = { 0, -0.25, 0 } } })
plat(platforms, cx, 0, -75, 6, 4)
for i, phase in { 0, 0.3, 0.6 } do
	table.insert(elements, { type = "timed_platform", pos = { cx, 0, -80.6 - (i - 1) * 3.6 }, rot = { 0, 0, 0 },
		params = { on_time = 2.2, off_time = 1.4, phase = phase, warning = 0.6 } })
end
table.insert(elements, { type = "crumble_platform", pos = { cx, 0, -92.5 }, rot = { 0, 0, 0 },
	params = { warning_time = 0.55, respawn_time = 3 } })
table.insert(labels, { pos = { cx, 3, -66 }, text = "Móvil · temporizadas (fases 0/0.3/0.6) · desmoronable" })
-- Peligros: láser para pasar deslizando, pinchos, spinner y robot patrulla.
plat(platforms, cx, 0, -110, 10, 30)
table.insert(checkpoints, { pos = { cx, 0, -97.5 }, rot = { 0, 0, 0 }, spawn = { cx, 0.1, -97.5 } })
table.insert(hazards, { type = "laser", pos = { cx, 0, -101 }, rot = { 0, 0, 0 },
	params = { width = 5.8, beam_height = 1.05, period = 0, on_fraction = 0.6, phase = 0 } })
table.insert(hazards, { type = "laser", pos = { cx, 0, -105 }, rot = { 0, 0, 0 },
	params = { width = 5.8, beam_height = 1.05, period = 2.0, on_fraction = 0.6, phase = 0 } })
table.insert(hazards, { type = "spikes", pos = { cx - 3, 0, -109 }, rot = { 0, 0, 0 }, params = {} })
table.insert(hazards, { type = "spinner", pos = { cx + 2.5, 0, -113 }, rot = { 0, 0, 0 },
	params = { degrees_per_second = 70, start_angle = 0 } })
table.insert(hazards, { type = "patrol", pos = { cx - 3, 0, -119 }, rot = { 0, 0, 0 },
	params = { travel = { 6, 0, 0 }, speed = 3, phase = 0 } })
table.insert(labels, { pos = { cx, 3, -98.5 }, text = "Láser fijo (desliza) · láser 2 s · pinchos · spinner · patrulla" })
for i = 0, 9 do
	table.insert(sparks, { cx + 3.5, 0.8 + math.sin(i / 9 * math.pi) * 1.6, -100 - i * 1.6 })
end

local gems = {
	{ index = 0, pos = { cx - 3, 6.6, -22 } },
	{ index = 1, pos = { cx, 8.3, -46 } },
	{ index = 2, pos = { -30, 0.2, -6 } },
}

return {
	schema = 1,
	id = "lab",
	name_key = "SELECT_LAB",
	world = 0,
	index = 0,
	tutorial = false,
	lab = true,
	biome = "isles",
	medals = {},
	kill_height = -12,
	source = { kind = "lab" },
	player_start = { pos = { 0, 0.1, -1 }, yaw = 0 },
	route = {},
	platforms = platforms,
	elements = elements,
	hazards = hazards,
	collectibles = { gems = gems, sparks = sparks },
	checkpoints = checkpoints,
	camera_zones = cameraZones,
	prompts = {},
	decor = {},
	goal = { pos = { cx, 0, -123 }, rot = { 0, 0, 0 } },
	rulers = rulers,
	labels = labels,
}
