--!strict
-- Plataforma segura (scenes/props/platforms/*.tscn): caja de colisión con el origen en el
-- centro de la cara caminable. Visual provisional nativo: cuerpo del color del lateral
-- del bioma y una capa superior del color de la cara caminable (los MeshParts de los
-- GLB llegan en H8).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Units"))
local AssetLibrary = require(script.Parent.Parent:WaitForChild("AssetLibrary"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local Platform = {}

local TOP_THICKNESS = Units.studs(0.18)

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
	})
	body:SetAttribute("Asset", entry.asset)
	if AssetLibrary.instantiate(entry.asset, ctx.geometry, frame) then
		body.Transparency = 1
		return {}
	end
	PartFactory.visual(body, {
		Name = "Top",
		Size = Vector3.new(size.X + 0.05, TOP_THICKNESS, size.Z + 0.05),
		CFrame = center * CFrame.new(0, size.Y / 2 - TOP_THICKNESS / 2 + 0.02, 0),
		Color = ctx.biome.top,
		Material = if ctx.biome.id == "isles" then Enum.Material.Grass else Enum.Material.SmoothPlastic,
	})
	return {}
end

return Platform
