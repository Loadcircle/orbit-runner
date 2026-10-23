--!strict
-- Construye la copia local del nivel en Workspace.ActiveLevel a partir de una tabla con
-- el esquema JSON v1 (roblox/levels_json/SCHEMA.md): metros y ejes de Godot; la
-- conversión a studs la hace cada prop con Units (guía §4.3). Las piezas son locales
-- del cliente y no se replican (guía §2.3).

local Workspace = game:GetService("Workspace")

local LabMarkers = require(script.Parent:WaitForChild("LabMarkers"))

local Props = script.Parent:WaitForChild("Props")
local BoostPad = require(Props:WaitForChild("BoostPad"))
local Checkpoint = require(Props:WaitForChild("Checkpoint"))
local Collectibles = require(Props:WaitForChild("Collectibles"))
local CrumblePlatform = require(Props:WaitForChild("CrumblePlatform"))
local Decor = require(Props:WaitForChild("Decor"))
local Goal = require(Props:WaitForChild("Goal"))
local Hazards = require(Props:WaitForChild("Hazards"))
local MovingPlatform = require(Props:WaitForChild("MovingPlatform"))
local Platform = require(Props:WaitForChild("Platform"))
local TimedPlatform = require(Props:WaitForChild("TimedPlatform"))
local Trampoline = require(Props:WaitForChild("Trampoline"))
local Types = require(Props:WaitForChild("Types"))
local Volumes = require(Props:WaitForChild("Volumes"))
local WindColumn = require(Props:WaitForChild("WindColumn"))

local LevelBuilder = {}

local ELEMENTS: { [string]: (Types.Entry, Types.Context) -> Types.Prop } = {
	trampoline = Trampoline.build,
	wind_column = WindColumn.build,
	boost_pad = BoostPad.build,
	moving_platform = MovingPlatform.build,
	timed_platform = TimedPlatform.build,
	crumble_platform = CrumblePlatform.build,
}

local HAZARDS: { [string]: (Types.Entry, Types.Context) -> Types.Prop } = {
	spikes = Hazards.spikes,
	spinner = Hazards.spinner,
	patrol = Hazards.patrol,
	laser = Hazards.laser,
}

export type BuiltLevel = {
	folder: Folder,
	props: { Types.Prop },
	data: { [string]: any },
}

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Prepara Workspace.ActiveLevel vacío con sus subcarpetas y devuelve el contexto base.
function LevelBuilder.prepare(): (Folder, Folder, Folder, Folder)
	local existing = Workspace:FindFirstChild("ActiveLevel")
	if existing then
		existing:Destroy()
	end
	local root = folder("ActiveLevel", Workspace)
	return root, folder("Geometry", root), folder("Triggers", root), folder("Decor", root)
end

function LevelBuilder.build(data: { [string]: any }, ctx: Types.Context): BuiltLevel
	local props: { Types.Prop } = {}
	local function add(prop: Types.Prop?)
		if prop then
			table.insert(props, prop)
		end
	end
	for _, entry in data.platforms or {} do
		add(Platform.build(entry, ctx))
	end
	for _, entry in data.elements or {} do
		local builder = ELEMENTS[entry.type]
		if builder then
			add(builder(entry, ctx))
		else
			warn("[LevelBuilder] elemento desconocido: " .. tostring(entry.type))
		end
	end
	for _, entry in data.hazards or {} do
		local builder = HAZARDS[entry.type]
		if builder then
			add(builder(entry, ctx))
		else
			warn("[LevelBuilder] peligro desconocido: " .. tostring(entry.type))
		end
	end
	local collectibles = data.collectibles or {}
	for _, entry in collectibles.gems or {} do
		add(Collectibles.gem(entry, ctx))
	end
	for _, position in collectibles.sparks or {} do
		add(Collectibles.spark(position, ctx))
	end
	for _, entry in data.checkpoints or {} do
		add(Checkpoint.build(entry, ctx))
	end
	for _, entry in data.camera_zones or {} do
		add(Volumes.cameraZone(entry, ctx))
	end
	for _, entry in data.prompts or {} do
		add(Volumes.prompt(entry, ctx))
	end
	for _, entry in data.decor or {} do
		add(Decor.build(entry, ctx))
	end
	if data.goal and data.goal.pos then
		add(Goal.build(data.goal, ctx))
	end
	if data.rulers or data.labels then
		LabMarkers.build(data, ctx.decor)
	end
	return { folder = ctx.folder :: Folder, props = props, data = data }
end

return LevelBuilder
