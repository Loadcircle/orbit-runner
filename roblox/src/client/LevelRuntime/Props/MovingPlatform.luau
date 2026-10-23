--!strict
-- Plataforma móvil (scripts/props/moving_platform.gd): va y vuelve entre su inicio e
-- inicio + travel con smoothstep y pausas en los extremos (pause_fraction del ciclo).
-- Se mueve con CFrame en PreSimulation y publica su velocidad en AssemblyLinearVelocity,
-- que el GroundController y el controlador usan para arrastrar al jugador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local M = PropTuning.movingPlatform
local MovingPlatform = {}

-- Posición 0..1..0 del ciclo con pausas en los dos extremos.
function MovingPlatform.progress(time: number, period: number, phase: number, pause: number): number
	local t = ((time + phase * period) % period) / period
	local x
	if t < 0.5 then
		x = math.clamp((t - pause * 0.5) / (0.5 - pause), 0, 1)
	else
		x = 1 - math.clamp((t - 0.5 - pause * 0.5) / (0.5 - pause), 0, 1)
	end
	return Common.smoothstep(x)
end

function MovingPlatform.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local start = Common.frame(entry)
	local travel = Units.vector(Common.param(entry, "travel", M.travel))
	local period = Common.param(entry, "period", M.period)
	local phase = Common.param(entry, "phase", 0)
	local pause = Common.param(entry, "pause_fraction", M.pauseFraction)
	local collider = entry.collider or { size = M.size, offset = { 0, M.centerY, 0 } }
	local offset = CFrame.new(Units.vector(collider.offset))
	local size = Common.size(collider.size)

	local body = PartFactory.part(ctx.geometry, {
		Name = "MovingPlatform",
		Size = size,
		CFrame = start * offset,
		Color = Palette.tempDark,
	})
	-- Chevrones en la dirección del recorrido: la función se lee por forma, no solo color.
	local direction = if travel.Magnitude > 0 then start:VectorToObjectSpace(travel.Unit) else Vector3.zAxis
	local arrowYaw = math.atan2(-direction.X, -direction.Z)
	local decorations = {}
	for i = -1, 1, 2 do
		local arrow = PartFactory.visual(body, {
			Name = "Chevron",
			Size = Vector3.new(size.X * 0.5, 0.1, 0.45),
			Color = Palette.temp,
			Material = Enum.Material.Neon,
		})
		table.insert(decorations, { part = arrow, local_ = CFrame.Angles(0, arrowYaw, 0)
			* CFrame.new(0, size.Y / 2 + 0.05, i * size.Z * 0.18) * CFrame.Angles(0, math.rad(35) * i, 0) })
	end

	local prop = {}
	function prop.step(_self, dt: number, time: number)
		local frame = start * offset + travel * MovingPlatform.progress(time, period, phase, pause)
		local previous = body.Position
		body.CFrame = frame
		body.AssemblyLinearVelocity = if dt > 0 then (frame.Position - previous) / dt else Vector3.zero
		for _, decoration in decorations do
			decoration.part.CFrame = frame * decoration.local_
		end
	end
	return prop
end

return MovingPlatform
