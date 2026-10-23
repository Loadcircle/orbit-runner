--!strict
-- Trampolín (scripts/props/trampoline.gd): impulso vertical fijo al entrar por arriba o a
-- la par (vy ≤ 1 m/s). Restaura el dash y la carga del yo-yo (PlayerController.bounce).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local T = PropTuning.trampoline
local Trampoline = {}

function Trampoline.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local frame = Common.frame(entry)
	local strength = Units.studs(Common.param(entry, "strength", T.strength))
	local model = Instance.new("Model")
	model.Name = "Trampoline"
	model.Parent = ctx.geometry
	local baseSize, baseFrame = PartFactory.verticalCylinder(
		frame * CFrame.new(0, Units.studs(T.baseCenterY), 0),
		Units.studs(T.baseRadius),
		Units.studs(T.baseHeight)
	)
	PartFactory.part(model, {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = baseSize,
		CFrame = baseFrame,
		Color = Palette.impulseDark,
	})
	local padSize, padFrame = PartFactory.verticalCylinder(
		frame * CFrame.new(0, Units.studs(T.baseHeight) + 0.15, 0),
		Units.studs(T.baseRadius * 0.85),
		0.3
	)
	local pad = PartFactory.visual(model, {
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = padSize,
		CFrame = padFrame,
		Color = Palette.impulse,
		Material = Enum.Material.Neon,
	})
	local areaSize, areaFrame = PartFactory.verticalCylinder(
		frame * CFrame.new(0, Units.studs(T.padCenterY), 0),
		Units.studs(T.padRadius),
		Units.studs(T.padHeight)
	)
	local area = PartFactory.trigger(ctx.triggerFolder, "TrampolineArea", {
		Shape = Enum.PartType.Cylinder,
		Size = areaSize,
		CFrame = areaFrame,
	})

	local squash = 0
	local function launch()
		local player = ctx.player
		if player.isDead or player.velocity.Y > Units.studs(T.maxEntrySpeed) then
			return
		end
		player:bounce(strength, "trampoline")
		ctx.session:playSfx("trampoline")
		ctx.session:vibrate(25)
		squash = 1
	end
	ctx.triggers:register(area, { onStay = launch })

	local prop = {}
	function prop.step(_self, dt: number)
		if squash > 0 then
			-- Rebote elástico del parche (TRANS_ELASTIC en Godot).
			squash = math.max(squash - dt / 0.35, 0)
			local wobble = 1 + 0.15 * squash * math.cos((1 - squash) * 12)
			pad.Size = Vector3.new(padSize.X * math.max(1 - 0.6 * squash, 0.4), padSize.Y * wobble, padSize.Z * wobble)
		end
	end
	return prop
end

return Trampoline
