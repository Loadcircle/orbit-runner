--!strict
-- Modelos visuales de los props (R15): assets nativos de la plantilla Platformer de
-- Roblox, copiados en el lugar a ReplicatedStorage.TemplateAssets (plantas, rocas,
-- columnas, plataforma móvil, plataforma de un solo sentido, moneda). Cada nombre de
-- asset de los niveles (PLAT_*, PROP_*, ENV_*) se traduce aquí a uno de ellos con su
-- encaje. Lo que no existe en Roblox (trampolín, viento, yo-yo, peligros, meta…) no está
-- en la tabla: `instantiate` devuelve nil y el prop usa su forma nativa propia.
-- Solo visual: sin colisión, consultas ni Touched; las colisiones son Parts aparte.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLibrary = {}

export type Instance_ = { model: Model, parts: { [string]: BasePart } }

-- fit = "footprint": se estira en X/Z hasta el tamaño pedido con la cara de arriba en el
--   origen (plataformas: origen = centro de la cara caminable).
-- fit = "ground": escala uniforme hasta `size` studs de alto con la base en el origen.
-- fit = "center": escala uniforme hasta `size` studs (lado mayor) centrado en el origen.
type Entry = { source: string, fit: "footprint" | "ground" | "center", size: number? }

local LIBRARY: { [string]: Entry } = {
	PLAT_Moving = { source = "MovingPlatformVisual", fit = "footprint" },
	PLAT_Timed = { source = "TimedPlatformVisual", fit = "footprint" },
	PROP_Spark = { source = "Coin", fit = "center", size = 1.8 },
	ENV_Tree = { source = "FernA", fit = "ground", size = 7 },
	ENV_Pine = { source = "FernB", fit = "ground", size = 5 },
	ENV_Palm = { source = "FernA", fit = "ground", size = 8 },
	ENV_Bush = { source = "HostasA", fit = "ground", size = 2.5 },
	ENV_Rock_A = { source = "RockSmall", fit = "ground", size = 3.5 },
	ENV_Rock_B = { source = "RockSmall", fit = "ground", size = 2.5 },
	ENV_LampPost = { source = "Illumin_Column", fit = "ground", size = 8 },
}

local function folder(): Instance?
	return ReplicatedStorage:FindFirstChild("TemplateAssets")
end

function AssetLibrary.has(name: string): boolean
	local entry = LIBRARY[name]
	local source = folder()
	return entry ~= nil and source ~= nil and source:FindFirstChild(entry.source) ~= nil
end

-- Copia del asset como Model (los MeshPart sueltos se envuelven en uno).
local function cloneSource(entry: Entry): Model?
	local source = folder()
	local original = source and source:FindFirstChild(entry.source)
	if not original then
		return nil
	end
	local copy = original:Clone()
	if copy:IsA("Model") then
		return copy
	end
	local model = Instance.new("Model")
	model.Name = entry.source
	copy.Parent = model
	model.PrimaryPart = if copy:IsA("BasePart") then copy else nil
	return model
end

-- Estira cada pieza en X/Z (el mismo factor para tamaño y posición respecto al centro).
local function stretch(model: Model, scaleX: number, scaleZ: number)
	local center = model:GetBoundingBox()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local offset = center:PointToObjectSpace(part.Position)
			local rotation = part.CFrame - part.Position
			part.Size = Vector3.new(part.Size.X * scaleX, part.Size.Y, part.Size.Z * scaleZ)
			part.CFrame = CFrame.new(center:PointToWorldSpace(Vector3.new(offset.X * scaleX, offset.Y, offset.Z * scaleZ)))
				* rotation
		end
	end
end

function AssetLibrary.instantiate(name: string?, parent: Instance, frame: CFrame, footprint: Vector3?): Instance_?
	if not name then
		return nil
	end
	local entry = LIBRARY[name]
	local model = entry and cloneSource(entry)
	if not entry or not model then
		return nil
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		elseif part:IsA("Light") then
			part:Destroy() -- sin luces dinámicas por pieza (rendimiento en móvil)
		end
	end
	local _, size = model:GetBoundingBox()
	if entry.fit == "footprint" and footprint then
		stretch(model, footprint.X / size.X, footprint.Z / size.Z)
	elseif entry.size then
		local reference = if entry.fit == "ground" then size.Y else math.max(size.X, size.Y, size.Z)
		model:ScaleTo(entry.size / reference)
	end
	local box, boxSize = model:GetBoundingBox()
	local pivotY = if entry.fit == "footprint"
		then boxSize.Y / 2
		elseif entry.fit == "ground" then -boxSize.Y / 2
		else 0
	model.WorldPivot = CFrame.new(box.Position + Vector3.new(0, pivotY, 0))
	model:PivotTo(frame)
	model.Parent = parent
	local parts = {}
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			parts[child.Name] = child
		end
	end
	return { model = model, parts = parts }
end

-- Pivote de una pieza animada relativo al Model.
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
