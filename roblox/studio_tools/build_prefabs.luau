--[[
	Orbit Runner – crea los prefabs visuales en ReplicatedStorage.Assets a partir de las
	mallas subidas por el plugin OrbitRunnerAssetUploader (ServerScriptService.MeshData.
	UploadResult) y de sus datos (pivote, centro de la caja, colores).
	Se ejecuta en el DataModel de edición (MCP de Studio o barra de comandos) y devuelve
	el texto de Shared/AssetIds.luau con los IDs, para versionarlo.

	Reglas (guía §2.5 y §3.8):
	  · MeshParts sin colisión, sin consultas y sin Touched; sombras activadas.
	  · Pivote del Model = origen del asset en Godot; cada pieza con PivotOffset en su pivote.
	  · Grupo "Glow" (materiales emisivos en Blender): material Neon con el color medio si
	    sus colores son casi uniformes; si no, SmoothPlastic con su color por vértice.
]]

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GLOW_UNIFORM_SPREAD = 0.12

local meshData = ServerScriptService:WaitForChild("MeshData")
local uploads = HttpService:JSONDecode(meshData:WaitForChild("UploadResult").Value)

local assets = ReplicatedStorage:FindFirstChild("Assets")
if not assets then
	assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
end

local function bounds(positions)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min
	for _, p in positions do
		local v = Vector3.new(p[1], p[2], p[3])
		min = min:Min(v)
		max = max:Max(v)
	end
	return (min + max) / 2
end

local function colorStats(colors)
	local sum = Vector3.zero
	for _, c in colors do
		sum += Vector3.new(c[1], c[2], c[3])
	end
	local mean = sum / math.max(#colors, 1)
	local spread = 0
	for _, c in colors do
		spread = math.max(spread, (Vector3.new(c[1], c[2], c[3]) - mean).Magnitude)
	end
	return Color3.new(mean.X, mean.Y, mean.Z), spread
end

local lines = {}
local built, failed = 0, {}
for assetName, parts in uploads do
	local module = meshData:FindFirstChild(assetName)
	if not module then
		continue
	end
	local data = require(module)
	local existing = assets:FindFirstChild(assetName)
	if existing then
		existing:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = assetName
	local idLines = {}
	for partName, id in parts do
		local part = data.parts[partName]
		local ok, meshPart = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. tostring(id)))
		end)
		if not ok or not part then
			table.insert(failed, assetName .. "/" .. partName .. ": " .. tostring(meshPart))
			continue
		end
		local pivot = Vector3.new(part.pivot[1], part.pivot[2], part.pivot[3])
		local center = bounds(part.positions)
		meshPart.Name = partName
		meshPart.Anchored = true
		meshPart.CanCollide = false
		meshPart.CanQuery = false
		meshPart.CanTouch = false
		meshPart.CastShadow = true
		meshPart.Material = Enum.Material.SmoothPlastic
		meshPart.Color = Color3.new(1, 1, 1)
		if part.kind == "Glow" then
			local mean, spread = colorStats(part.colors)
			if spread <= GLOW_UNIFORM_SPREAD then
				meshPart.Material = Enum.Material.Neon
				meshPart.Color = mean
			end
		end
		meshPart.CFrame = CFrame.new(pivot + center)
		meshPart.PivotOffset = CFrame.new(-center)
		meshPart.Parent = model
		table.insert(idLines, string.format("\t\t%s = \"rbxassetid://%s\",", partName, tostring(id)))
	end
	model.WorldPivot = CFrame.identity
	model.Parent = assets
	built += 1
	table.sort(idLines)
	table.insert(lines, string.format("\t%s = {\n%s\n\t},", assetName, table.concat(idLines, "\n")))
end
table.sort(lines)

return string.format("built=%d failed=%s\n---\n%s", built, HttpService:JSONEncode(failed), table.concat(lines, "\n"))
