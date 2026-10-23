--!strict
-- Plataforma segura (scenes/props/platforms/*.tscn): caja de colisión con el origen en el
-- centro de la cara caminable. Con el estilo de la plantilla Platformer (R15): la propia
-- caja de colisión es el bloque visible (material de muro de la plantilla y color del
-- bioma) con una losa superior del material de suelo. Lo que se ve es lo que se pisa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))
local Units = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Units"))

local Platform = {}

local TOP_THICKNESS = 1 -- studs, como las losas "Top" de la plantilla

function Platform.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local frame = Common.frame(entry)
	local collider = entry.collider or { size = { 4, 1, 6 }, offset = { 0, -0.5, 0 } }
	local size = Common.size(collider.size)
	local center = frame * CFrame.new(Units.vector(collider.offset))
	local body = PartFactory.part(ctx.geometry, {
		Name = entry.asset or "Platform",
		Size = size,
		CFrame = center,
		Color = ctx.biome.side,
		Material = Enum.Material.Plastic,
		MaterialVariant = Palette.wallVariant,
	})
	body:SetAttribute("Asset", entry.asset)
	local top = math.min(TOP_THICKNESS, size.Y)
	PartFactory.visual(body, {
		Name = "Top",
		Size = Vector3.new(size.X + 0.04, top, size.Z + 0.04),
		CFrame = center * CFrame.new(0, size.Y / 2 - top / 2 + 0.02, 0),
		Color = ctx.biome.top,
		Material = Enum.Material.Plastic,
		MaterialVariant = Palette.floorVariant,
	})
	return {}
end

return Platform
