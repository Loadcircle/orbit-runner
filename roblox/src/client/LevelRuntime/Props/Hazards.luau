--!strict
-- Peligros (scripts/props/hazard_area.gd y derivados): pinchos, spinner, robot patrulla y
-- puerta láser. Todos llaman a hurt() mientras la cápsula de juego se solapa con su área
-- activa (en Godot, HazardArea recorre los cuerpos solapados en cada fotograma).
-- Magenta/morado + forma y movimiento propios de peligro.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local Hazards = {}

local function hazardArea(ctx: Types.Context, name: string, props: PartFactory.PartProps): BasePart
	local area = PartFactory.trigger(ctx.triggerFolder, name, props)
	area:SetAttribute("Hazard", true)
	ctx.triggers:register(area, {
		onStay = function()
			if area.CanQuery and not ctx.player.isDead then
				ctx.player:hurt()
			end
		end,
	})
	return area
end

local function model(ctx: Types.Context, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = ctx.geometry
	return m
end

-- Pinchos: área 1.8 × 0.5 × 1.8 a 0.3 m. Visual: 3×3 pirámides de cuñas.
function Hazards.spikes(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local P = PropTuning.spikes
	local frame = Common.frame(entry)
	local size = Common.size(P.size)
	local m = model(ctx, "Spikes")
	PartFactory.visual(m, {
		Name = "Base",
		Size = Vector3.new(size.X, 0.25, size.Z),
		CFrame = frame * CFrame.new(0, 0.125, 0),
		Color = Palette.hazardDark,
	})
	local cell = size.X / 3
	local height = Units.studs(0.5)
	for ix = -1, 1 do
		for iz = -1, 1 do
			local base = frame * CFrame.new(ix * cell, 0.25 + height / 2, iz * cell)
			for half = 0, 1 do
				PartFactory.visual(m, {
					ClassName = "WedgePart",
					Name = "Spike",
					Size = Vector3.new(cell * 0.8, height, cell * 0.4),
					CFrame = base * CFrame.Angles(0, math.pi * half, 0) * CFrame.new(0, 0, cell * 0.2),
					Color = if half == 0 then Palette.hazard else Color3.fromHex("#ff6fc0"),
					Material = Enum.Material.SmoothPlastic,
				})
			end
		end
	end
	hazardArea(ctx, "SpikesArea", { Size = size, CFrame = frame * CFrame.new(0, Units.studs(P.centerY), 0) })
	return {}
end

-- Spinner: brazo de 6.6 m que gira alrededor de un eje sólido.
function Hazards.spinner(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local P = PropTuning.spinner
	local frame = Common.frame(entry)
	local speed = math.rad(Common.param(entry, "degrees_per_second", P.degreesPerSecond))
	local startAngle = math.rad(Common.param(entry, "start_angle", 0))
	local m = model(ctx, "Spinner")
	local hubSize, hubFrame = PartFactory.verticalCylinder(frame * CFrame.new(0, Units.studs(P.hubCenterY), 0),
		Units.studs(P.hubRadius), Units.studs(P.hubHeight))
	PartFactory.part(m, {
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = hubSize,
		CFrame = hubFrame,
		Color = Palette.hazardDark,
	})
	local armSize = Common.size(P.armSize)
	local arm = PartFactory.visual(m, {
		Name = "Arm",
		Size = armSize,
		Color = Palette.hazard,
		Material = Enum.Material.Neon,
	})
	local area = hazardArea(ctx, "SpinnerArea", { Size = armSize })
	local armCenter = frame * CFrame.new(0, Units.studs(P.armCenterY), 0)
	local prop = {}
	function prop.step(_self, _dt: number, time: number)
		local cf = armCenter * CFrame.Angles(0, startAngle + speed * time, 0)
		arm.CFrame = cf
		area.CFrame = cf
	end
	prop.step(prop, 0, 0)
	return prop
end

-- Robot patrulla: esfera r 0.75 que va y vuelve con smoothstep, flotando.
function Hazards.patrol(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local P = PropTuning.patrol
	local frame = Common.frame(entry)
	local travel = Units.vector(Common.param(entry, "travel", P.travel))
	local speed = Units.studs(Common.param(entry, "speed", P.speed))
	local phase = Common.param(entry, "phase", 0)
	local radius = Units.studs(P.radius)
	local m = model(ctx, "PatrolBot")
	local body = PartFactory.visual(m, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		Color = Palette.hazardDark,
	})
	local eye = PartFactory.visual(m, {
		Name = "Eye",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 0.7,
		Color = Palette.hazard,
		Material = Enum.Material.Neon,
	})
	local area = hazardArea(ctx, "PatrolArea", { Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 2 })
	local start = frame * CFrame.new(0, Units.studs(P.centerY), 0)
	local length = math.max(travel.Magnitude, 0.01)
	local prop = {}
	function prop.step(_self, _dt: number, time: number)
		local t = (phase + time * speed / (length * 2)) % 1
		local x = Common.smoothstep(1 - math.abs(1 - t * 2))
		local bob = math.sin(time * P.bobRate) * Units.studs(P.bobAmplitude)
		local cf = CFrame.new(start.Position + travel * x + Vector3.new(0, bob, 0)) * CFrame.Angles(0, time * P.spinRate, 0)
		body.CFrame = cf
		eye.CFrame = cf * CFrame.new(0, radius * 0.15, -radius * 0.75)
		area.CFrame = cf
	end
	prop.step(prop, 0, 0)
	return prop
end

-- Puerta láser: haz horizontal entre dos postes. Se pasa deslizando por debajo; con
-- `period` > 0 parpadea (encendido el 60 % del ciclo, aviso 0.4 s).
function Hazards.laser(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local P = PropTuning.laser
	local frame = Common.frame(entry)
	local widthM = Common.param(entry, "width", P.width)
	local width = Units.studs(widthM)
	local beamHeight = Units.studs(Common.param(entry, "beam_height", P.beamHeight))
	local period = Common.param(entry, "period", P.period)
	local onFraction = Common.param(entry, "on_fraction", P.onFraction)
	local phase = Common.param(entry, "phase", 0)
	local m = model(ctx, "LaserGate")
	local postHeight = beamHeight + Units.studs(0.5)
	local attachments = {}
	for side = -1, 1, 2 do
		local post = PartFactory.part(m, {
			Name = "Post",
			Size = Vector3.new(0.7, postHeight, 0.7),
			CFrame = frame * CFrame.new(side * width / 2, postHeight / 2, 0),
			Color = Palette.metalDark,
		})
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(-side * 0.35, beamHeight - postHeight / 2, 0)
		attachment.Parent = post
		table.insert(attachments, attachment)
	end
	local beam = Instance.new("Beam")
	beam.Attachment0 = attachments[1]
	beam.Attachment1 = attachments[2]
	beam.Color = ColorSequence.new(Palette.hazard)
	beam.LightEmission = 1
	beam.Width0 = Units.studs(0.12)
	beam.Width1 = Units.studs(0.12)
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = m
	local inner = math.max(widthM - 0.3, 0.1)
	local area = hazardArea(ctx, "LaserArea", {
		Size = Vector3.new(Units.studs(inner), Units.studs(P.hazardThickness[1]), Units.studs(P.hazardThickness[2])),
		CFrame = frame * CFrame.new(0, beamHeight, 0),
	})
	if period <= 0 then
		return {}
	end
	local prop = {}
	function prop.step(_self, _dt: number, time: number)
		local t = (time + phase * period) % period
		local on = t < period * onFraction
		local warn = on and t > period * onFraction - P.warning
		area.CanQuery = on
		beam.Enabled = on and (not warn or (t % 0.12) > 0.05)
	end
	return prop
end

return Hazards
