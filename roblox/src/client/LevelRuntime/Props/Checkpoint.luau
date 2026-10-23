--!strict
-- Punto de control (scripts/props/checkpoint.gd): se activa una vez, cambia el color y
-- levanta la bandera, y guarda el punto de aparición (y la yaw de cámara, en la sesión).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local C = PropTuning.checkpoint
local Checkpoint = {}

local ACTIVE_COLOR = Color3.new(1.0, 0.6, 0.18)

function Checkpoint.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local frame = Common.frame(entry)
	local spawn = if entry.spawn then Units.vector(entry.spawn) else frame.Position + Vector3.new(0, Units.studs(C.spawnY), 0)
	local facing = frame.LookVector
	local model = Instance.new("Model")
	model.Name = "Checkpoint"
	model.Parent = ctx.geometry
	-- Mástil a la izquierda (el modelo de Godot está desplazado −1.4 m en X).
	local poleBase = frame * CFrame.new(Units.studs(-1.4), 0, 0)
	local poleHeight = Units.studs(2.6)
	PartFactory.part(model, {
		Name = "Pole",
		Size = Vector3.new(0.4, poleHeight, 0.4),
		CFrame = poleBase * CFrame.new(0, poleHeight / 2, 0),
		Color = Palette.metal,
	})
	local flagSize = Vector3.new(Units.studs(0.9), Units.studs(0.55), 0.15)
	local flag = PartFactory.visual(model, {
		Name = "Flag",
		Size = flagSize,
		CFrame = poleBase * CFrame.new(flagSize.X / 2 + 0.2, poleHeight - flagSize.Y / 2, 0),
		Color = Palette.metalDark,
	})
	local flagRest = flag.CFrame
	local area = PartFactory.trigger(ctx.triggerFolder, "CheckpointArea", {
		Size = Common.size(C.size),
		CFrame = frame * CFrame.new(0, Units.studs(C.centerY), 0),
	})

	local activated = false
	local raise = 0
	ctx.triggers:register(area, {
		onEnter = function()
			if activated or ctx.player.isDead then
				return
			end
			activated = true
			flag.Color = ACTIVE_COLOR
			flag.Material = Enum.Material.Neon
			raise = 0.4
			ctx.session:playSfx("checkpoint")
			ctx.session:onCheckpoint(spawn, facing)
		end,
	})
	local prop = {}
	function prop.step(_self, dt: number)
		if raise > 0 then
			raise = math.max(raise - dt, 0)
			local s = 0.2 + 0.8 * Common.backOut(1 - raise / 0.4)
			flag.Size = Vector3.new(flagSize.X, flagSize.Y * s, flagSize.Z)
			flag.CFrame = flagRest * CFrame.new(0, flagSize.Y * (s - 1) / 2, 0)
		end
	end
	return prop
end

return Checkpoint
