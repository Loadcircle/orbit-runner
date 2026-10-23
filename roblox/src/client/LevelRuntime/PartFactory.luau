--!strict
-- Creación de Parts nativas para geometría, props y volúmenes de activación.
-- Las colisiones de juego son Parts sencillas. Por defecto llevan el material de muro de
-- la plantilla Platformer (R16) para que los props propios encajen con sus niveles; las
-- piezas que lo indican (Neon de impulso o peligro, metal…) conservan el suyo.

local Palette = require(script.Parent:WaitForChild("Palette"))

local PartFactory = {}

export type PartProps = { [string]: any }

function PartFactory.part(parent: Instance, props: PartProps): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.Plastic
	part.MaterialVariant = Palette.wallVariant
	if props.Material ~= nil and props.MaterialVariant == nil then
		part.MaterialVariant = ""
	end
	for key, value in props do
		if key ~= "ClassName" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Pieza decorativa: sin colisión ni consultas (no estorba a cámara ni a sensores).
function PartFactory.visual(parent: Instance, props: PartProps): BasePart
	local part = PartFactory.part(parent, props)
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = props.CastShadow ~= false
	return part
end

-- Volumen de activación invisible: solo responde a GetPartsInPart.
function PartFactory.trigger(parent: Instance, name: string, props: PartProps): BasePart
	local part = PartFactory.part(parent, props)
	part.Name = name
	part.CanCollide = false
	part.CanQuery = true
	part.CastShadow = false
	part.Transparency = 1
	return part
end

-- Cilindro vertical (el eje de los cilindros de Roblox es X).
function PartFactory.verticalCylinder(center: CFrame, radius: number, height: number): (Vector3, CFrame)
	return Vector3.new(height, radius * 2, radius * 2), center * CFrame.Angles(0, 0, math.rad(90))
end

return PartFactory
