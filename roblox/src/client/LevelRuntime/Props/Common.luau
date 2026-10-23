--!strict
-- Utilidades de los props: transformaciones de las entradas JSON (metros, ejes de
-- Godot) y curvas de animación.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Units"))

local Common = {}

-- CFrame del origen del prop en studs.
function Common.frame(entry: { pos: { number }, rot: { number }? }): CFrame
	return CFrame.new(Units.vector(entry.pos)) * Units.rotation(entry.rot)
end

function Common.param(entry: { params: { [string]: any }? }, key: string, default: any): any
	local params = entry.params
	if params and params[key] ~= nil then
		return params[key]
	end
	return default
end

-- Tamaño {x, y, z} en metros → Vector3 en studs.
function Common.size(list: { number }): Vector3
	return Units.vector(list)
end

-- Curva de los tweens TRANS_BACK / EASE_OUT de Godot (0..1).
function Common.backOut(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	t = math.clamp(t, 0, 1)
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

function Common.smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

return Common
