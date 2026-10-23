--!strict
-- Conversión metros (Godot) → studs (Roblox). Único sitio donde vive K (guía §2.1).
-- Distancias, velocidades, aceleraciones y gravedades se multiplican por K;
-- tiempos, ángulos y fracciones no cambian.

local Units = {}

Units.K = 3.5

function Units.studs(meters: number): number
	return meters * Units.K
end

function Units.meters(studs: number): number
	return studs / Units.K
end

-- Vector en metros (tabla {x, y, z} o Vector3) → Vector3 en studs. Godot y Roblox
-- comparten ejes (Y arriba, adelante −Z), así que solo se escala.
function Units.vector(value: { number } | Vector3): Vector3
	if typeof(value) == "Vector3" then
		return (value :: Vector3) * Units.K
	end
	local list = value :: { number }
	return Vector3.new(list[1], list[2], list[3]) * Units.K
end

-- Rotación Euler en grados y orden YXZ de Godot → CFrame de rotación.
function Units.rotation(degrees: { number }?): CFrame
	if not degrees then
		return CFrame.identity
	end
	return CFrame.fromEulerAnglesYXZ(math.rad(degrees[1]), math.rad(degrees[2]), math.rad(degrees[3]))
end

return Units
