--!strict
-- Columna de viento (scripts/props/wind_column.gd): eleva al jugador mientras está dentro
-- y restaura el dash. Empuje completo hasta 1.5 m bajo el final, que se atenúa justo
-- por encima, para que el jugador flote donde está la siguiente plataforma.
-- Visual nativo: cilindro translúcido + ParticleEmitter de corrientes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local AssetLibrary = require(script.Parent.Parent:WaitForChild("AssetLibrary"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local W = PropTuning.windColumn
local WindColumn = {}

function WindColumn.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local frame = Common.frame(entry)
	local height = Units.studs(Common.param(entry, "height", W.height))
	local lift = Units.studs(Common.param(entry, "lift", W.lift))
	local maxUp = Units.studs(Common.param(entry, "max_up_speed", W.maxUpSpeed))
	local radius = Units.studs(W.radius)
	local model = Instance.new("Model")
	model.Name = "WindColumn"
	model.Parent = ctx.geometry

	local baseSize, baseFrame = PartFactory.verticalCylinder(frame * CFrame.new(0, 0.3, 0), radius * 0.9, 0.6)
	PartFactory.part(model, {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = baseSize,
		CFrame = baseFrame,
		Color = Palette.metal,
	})
	local columnSize, columnFrame = PartFactory.verticalCylinder(frame * CFrame.new(0, height / 2, 0), radius, height)
	local column = PartFactory.visual(model, {
		Name = "Column",
		Shape = Enum.PartType.Cylinder,
		Size = columnSize,
		CFrame = columnFrame,
		Color = Palette.glow,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CastShadow = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Palette.white)
	emitter.LightEmission = 0.6
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(0.35)
	emitter.Lifetime = NumberRange.new(height / Units.studs(6))
	emitter.Speed = NumberRange.new(Units.studs(6))
	emitter.Rate = 18
	emitter.EmissionDirection = Enum.NormalId.Right -- +X local del cilindro = arriba
	emitter.Parent = column

	-- Malla migrada del anillo con su rotor girando (9 rad/s, wind_column.gd).
	local visual = AssetLibrary.instantiate("PROP_WindRing", model, frame)
	local rotor: BasePart? = nil
	local rotorPivot = CFrame.identity
	if visual then
		AssetLibrary.hide({ model:FindFirstChild("Base") :: Instance })
		rotor = visual.parts.Rotor
		rotorPivot = AssetLibrary.localPivot(visual, "Rotor") or CFrame.identity
	end
	local area = PartFactory.trigger(ctx.triggerFolder, "WindArea", {
		Shape = Enum.PartType.Cylinder,
		Size = columnSize,
		CFrame = columnFrame,
	})
	local baseY = frame.Position.Y
	ctx.triggers:register(area, {
		onStay = function(_part, dt: number)
			local player = ctx.player
			if player.isDead then
				return
			end
			local above = player:feet().Y - baseY
			local k = math.clamp((height + Units.studs(W.fadeTop) - above) / Units.studs(W.fadeRange), 0, 1)
			player:applyWind(lift * k, maxUp, dt)
		end,
	})
	if not rotor then
		return {}
	end
	local prop = {}
	function prop.step(_self, _dt: number, time: number)
		(rotor :: BasePart):PivotTo(frame * rotorPivot * CFrame.Angles(0, time * 9, 0))
	end
	return prop
end

return WindColumn
