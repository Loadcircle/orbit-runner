--!strict
-- Plataforma temporizada (scripts/props/timed_platform.gd): aparece y desaparece con un
-- ritmo fijo y parpadea antes de irse. `phase` es un retraso en fracción del ciclo: una
-- cadena con fases 0, 0.3, 0.6 aparece en ola. Forma hexagonal cian como señal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local T = PropTuning.timedPlatform
local TimedPlatform = {}

function TimedPlatform.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local frame = Common.frame(entry)
	local onTime = Common.param(entry, "on_time", T.onTime)
	local offTime = Common.param(entry, "off_time", T.offTime)
	local phase = Common.param(entry, "phase", 0)
	local warning = Common.param(entry, "warning", T.warning)
	local cycle = onTime + offTime
	local size, center = PartFactory.verticalCylinder(frame * CFrame.new(0, Units.studs(T.centerY), 0),
		Units.studs(T.radius), Units.studs(T.height))
	local body = PartFactory.part(ctx.geometry, {
		Name = "TimedPlatform",
		Shape = Enum.PartType.Cylinder,
		Size = size,
		CFrame = center,
		Color = Palette.temp,
	})
	local ringSize, ringFrame = PartFactory.verticalCylinder(frame * CFrame.new(0, 0.06, 0),
		Units.studs(T.radius * 0.7), 0.12)
	local ring = PartFactory.visual(body, {
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = ringSize,
		CFrame = ringFrame,
		Color = Palette.glow,
		Material = Enum.Material.Neon,
	})
	local solid = true
	local popTimer = 0
	local prop = {}
	function prop.step(_self, dt: number, time: number)
		local t = (time - phase * cycle) % cycle
		local nowSolid = t < onTime
		if nowSolid ~= solid then
			solid = nowSolid
			body.CanCollide = solid
			body.CanQuery = solid
			popTimer = if solid then T.popTime else 0
		end
		local visible = solid
		if solid then
			local remaining = onTime - t
			visible = remaining > warning or (remaining % 0.16) > 0.07
		end
		local transparency = if visible then 0 else 1
		body.Transparency = transparency
		ring.Transparency = transparency
		if popTimer > 0 then
			popTimer = math.max(popTimer - dt, 0)
			local s = 0.3 + 0.7 * Common.backOut(1 - popTimer / T.popTime)
			body.Size = Vector3.new(size.X, size.Y * s, size.Z * s)
		elseif body.Size ~= size then
			body.Size = size
		end
	end
	return prop
end

return TimedPlatform
