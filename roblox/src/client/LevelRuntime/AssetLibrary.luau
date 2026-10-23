--!strict
-- Modelos visuales migrados desde Blender (H8). Cada asset es un Model en
-- ReplicatedStorage.Assets con MeshParts sin colisión (las colisiones de juego son Parts
-- invisibles aparte, guía §2.5). El pivote del Model es el origen del asset en Godot
-- (centro de la cara caminable en las plataformas); las piezas animadas (brazo del
-- spinner, parche del trampolín, bandera, halo, rotor, losetas) tienen su propio pivote.
-- Los MeshIds viven en las MeshParts y en Shared/AssetIds; si un asset no existe todavía,
-- `instantiate` devuelve nil y el prop usa su forma nativa provisional.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLibrary = {}

export type Instance_ = { model: Model, parts: { [string]: BasePart } }

function AssetLibrary.has(name: string): boolean
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

function AssetLibrary.instantiate(name: string?, parent: Instance, frame: CFrame): Instance_?
	if not name then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	local prefab = folder and folder:FindFirstChild(name)
	if not prefab or not prefab:IsA("Model") then
		return nil
	end
	local model = prefab:Clone()
	model:PivotTo(frame)
	model.Parent = parent
	local parts = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			parts[child.Name] = child
		end
	end
	return { model = model, parts = parts }
end

-- Pivote de una pieza animada relativo al Model (en el prefab).
function AssetLibrary.localPivot(instance: Instance_, partName: string): CFrame?
	local part = instance.parts[partName]
	if not part then
		return nil
	end
	return instance.model:GetPivot():ToObjectSpace(part:GetPivot())
end

-- Oculta formas provisionales (las de colisión siguen colisionando).
function AssetLibrary.hide(parts: { Instance })
	for _, item in parts do
		if item:IsA("BasePart") then
			item.Transparency = 1
		end
		for _, descendant in item:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 1
			end
		end
	end
end

return AssetLibrary
