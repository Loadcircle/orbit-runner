--!strict
-- Paleta v2 "vivid" de los assets (assets_source/blender/scripts/or_common.py) y ambiente
-- por bioma (resources/biomes/*.tres), traducido a Lighting/Atmosphere nativos.
-- Lenguaje visual (guía §3.5): seguro = cálido/verde, impulso = amarillo/naranja,
-- temporal o móvil = cian/azul, peligro = magenta/morado; siempre con forma o animación.

local Lighting = game:GetService("Lighting")

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Palette = {
	grass = hex("#4cb83a"),
	grassLight = hex("#86d24a"),
	grassDark = hex("#25863a"),
	stone = hex("#efe0c4"),
	stoneDark = hex("#b49577"),
	cliff = hex("#f0a35e"),
	cliffDark = hex("#b8603a"),
	rock = hex("#9a5236"),
	wood = hex("#a8642e"),
	leaf = hex("#38b048"),
	impulse = hex("#ffd21f"),
	impulseDark = hex("#ff7a1a"),
	temp = hex("#29d4ff"),
	tempDark = hex("#2a5cff"),
	hazard = hex("#ff2d9a"),
	hazardDark = hex("#8a1fe0"),
	yoyo = hex("#22e0f0"),
	yoyoAccent = hex("#ff8a1e"),
	yoyoCore = hex("#f4fbff"),
	metal = hex("#9fb2c8"),
	metalDark = hex("#4b5a73"),
	cream = hex("#fff3d6"),
	toyRed = hex("#ff4646"),
	toyYellow = hex("#ffc61a"),
	toyBlue = hex("#2f7bff"),
	toyTeal = hex("#16c9b4"),
	toyPurple = hex("#9b5cff"),
	sand = hex("#f4e3c6"),
	sandstone = hex("#e0814e"),
	sandstoneDark = hex("#a64a30"),
	gold = hex("#ffbf2e"),
	turquoise = hex("#1fd6c4"),
	white = hex("#f6f7f9"),
	dark = hex("#262b45"),
	glow = hex("#5ff4ff"),
}

export type Biome = {
	id: string,
	top: Color3, -- cara caminable de las plataformas
	side: Color3, -- laterales
	under: Color3, -- base
	skyTop: Color3,
	skyHorizon: Color3,
	sun: Color3,
	sunEnergy: number,
	sunRotation: { number }, -- grados (x, y) de Godot
	ambient: Color3,
	fog: Color3,
	cloud: Color3,
}

Palette.biomes = {
	isles = {
		id = "isles",
		top = Palette.grass,
		side = Palette.cliff,
		under = Palette.cliffDark,
		skyTop = Color3.new(0.05, 0.30, 0.85),
		skyHorizon = Color3.new(0.78, 0.93, 1.0),
		sun = Color3.new(1.0, 0.96, 0.86),
		sunEnergy = 0.9,
		sunRotation = { -48, -35 },
		ambient = Color3.new(0.55, 0.68, 1.0),
		fog = Color3.new(0.70, 0.86, 1.0),
		cloud = Color3.new(1, 1, 1),
	},
	toyworks = {
		id = "toyworks",
		top = Palette.toyYellow,
		side = Palette.toyRed,
		under = Palette.toyBlue,
		skyTop = Color3.new(0.22, 0.12, 0.62),
		skyHorizon = Color3.new(1.0, 0.72, 0.62),
		sun = Color3.new(1.0, 0.92, 0.82),
		sunEnergy = 0.92,
		sunRotation = { -42, 25 },
		ambient = Color3.new(0.62, 0.52, 0.95),
		fog = Color3.new(0.78, 0.58, 0.88),
		cloud = Color3.new(1.0, 0.90, 0.96),
	},
	ruins = {
		id = "ruins",
		top = Palette.sand,
		side = Palette.sandstone,
		under = Palette.sandstoneDark,
		skyTop = Color3.new(0.04, 0.26, 0.70),
		skyHorizon = Color3.new(1.0, 0.80, 0.55),
		sun = Color3.new(1.0, 0.90, 0.72),
		sunEnergy = 0.95,
		sunRotation = { -38, -18 },
		ambient = Color3.new(0.55, 0.62, 0.95),
		fog = Color3.new(0.98, 0.80, 0.62),
		cloud = Color3.new(1.0, 0.95, 0.88),
	},
} :: { [string]: Biome }

function Palette.biome(id: string?): Biome
	return Palette.biomes[id or "isles"] or Palette.biomes.isles
end

-- Ambiente nativo del bioma: sol (dirección de la DirectionalLight de Godot),
-- ambiente coloreado y una Atmosphere que tiñe el horizonte y la niebla lejana.
function Palette.applyLighting(biome: Biome)
	Lighting.Ambient = biome.ambient:Lerp(Color3.new(0, 0, 0), 0.55)
	Lighting.OutdoorAmbient = biome.ambient
	Lighting.Brightness = 2 * biome.sunEnergy
	Lighting.ColorShift_Top = biome.sun
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	-- Godot: rotación X = elevación negativa del sol, Y = acimut. Roblox calcula la
	-- dirección del sol con ClockTime/GeographicLatitude; se aproxima la elevación.
	local elevation = -biome.sunRotation[1]
	Lighting.ClockTime = 6 + elevation / 15
	Lighting.GeographicLatitude = biome.sunRotation[2]
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = biome.skyHorizon
	atmosphere.Decay = biome.skyTop
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
end

return Palette
