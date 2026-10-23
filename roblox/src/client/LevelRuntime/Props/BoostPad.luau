--!strict
-- Boost pad (scripts/props/boost_pad.gd): empuja hacia su frente (−Z local) y sube el
-- límite de velocidad un momento. Se puede volver a activar tras 0.3 s. Chevrones
-- animados como señal de forma además del color.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local B = PropTuning.boostPad
local BoostPad = {}

function BoostPad.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local frame = Common.frame(entry)
	local speed = Units.studs(Common.param(entry, "speed", B.speed))
	local size = Common.size(B.size)
	local model = Instance.new("Model")
	model.Name = "BoostPad"
	model.Parent = ctx.geometry
	PartFactory.visual(model, {
		Name = "Plate",
		Size = Vector3.new(size.X, 0.2, size.Z),
		CFrame = frame * CFrame.new(0, 0.1, 0),
		Color = Palette.impulseDark,
	})
	local chevrons = {}
	for i = 0, 2 do
		local z = (1 - i) * size.Z / 3.2
		for side = -1, 1, 2 do
			local bar = PartFactory.visual(model, {
				Name = "Chevron",
				Size = Vector3.new(size.X * 0.42, 0.12, 0.5),
				CFrame = frame * CFrame.new(side * size.X * 0.17, 0.24, z) * CFrame.Angles(0, side * math.rad(35), 0),
				Color = Palette.impulse,
				Material = Enum.Material.Neon,
			})
			table.insert(chevrons, { part = bar, index = i })
		end
	end
	local area = PartFactory.trigger(ctx.triggerFolder, "BoostArea", {
		Size = size,
		CFrame = frame * CFrame.new(0, Units.studs(B.centerY), 0),
	})
	local forward = frame.LookVector
	local cooldown = 0
	ctx.triggers:register(area, {
		onEnter = function()
			if cooldown > 0 then
				return
			end
			cooldown = B.cooldown
			ctx.player:applyBoost(forward, speed)
			ctx.session:playSfx("boost")
		end,
	})
	local prop = {}
	function prop.step(_self, dt: number, time: number)
		cooldown -= dt
		for _, chevron in chevrons do
			local wave = (time * 3 - chevron.index / 3) % 1
			chevron.part.Transparency = 0.6 * wave
		end
	end
	return prop
end

return BoostPad
