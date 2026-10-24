--!strict
-- Vestíbulo social mínimo (R23): en el escenario de la plantilla, junto al spawn, un
-- portal por mundo con un ProximityPrompt (el cliente abre el panel de niveles de ese
-- mundo) y un cartel de ranking. VERSIÓN SENCILLA: el diseño real del hub queda
-- pendiente. La métrica del ranking es PROVISIONAL (estrellas de maestría totales).
-- Todo se construye en el servidor para que todos los jugadores vean lo mismo; los
-- textos llevan el atributo TextKey y cada cliente los traduce (Client/Game, Strings).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RANKING_STORE = "OrbitRunnerStarsTotal"
local RANKING_SIZE = 10
local RANKING_REFRESH = 60 -- s

-- Posiciones en el escenario de la plantilla (spawn en 1, 0, 2999 mirando a +Z); el
-- lado −X está libre. Los carteles miran hacia el spawn (+X).
local BOARD_POSITION = Vector3.new(-42, 0, 2988)
local PORTALS = {
	{ world = 1, titleKey = "WORLD_1", position = Vector3.new(-30, 0, 3022), color = Color3.fromRGB(255, 160, 50) },
}
local LAB_PORTAL = { world = 0, titleKey = "SELECT_LAB", position = Vector3.new(-30, 0, 2958), color = Color3.fromRGB(80, 220, 240) }

local HubService = {}

local rankingStore: OrderedDataStore? = nil
local rankingList: Frame? = nil
local names: { [number]: string } = {}

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function textLabel(text: string, size: number, color: Color3, parent: Instance, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 8)
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	label.Font = Enum.Font.FredokaOne
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

local function facingSpawn(position: Vector3, height: number): CFrame
	local center = position + Vector3.new(0, height, 0)
	return CFrame.lookAt(center, center + Vector3.new(1, 0, 0))
end

local function buildPortal(config: { [string]: any }, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. config.world
	local base: CFrame = facingSpawn(config.position, 0)
	local stone = { Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 78, 110) }
	for _, side in { -1, 1 } do
		part({ Name = "Pillar", Size = Vector3.new(2, 12, 2), CFrame = base * CFrame.new(side * 5, 6, 0),
			Material = stone.Material, Color = stone.Color }, model)
	end
	part({ Name = "Lintel", Size = Vector3.new(12, 2, 2), CFrame = base * CFrame.new(0, 13, 0),
		Material = stone.Material, Color = stone.Color }, model)
	local core = part({
		Name = "Core",
		Size = Vector3.new(8, 11, 0.4),
		CFrame = base * CFrame.new(0, 6.5, 0),
		Material = Enum.Material.Neon,
		Color = config.color,
		Transparency = 0.45,
		CanCollide = false,
	}, model)
	part({ Name = "Step", Size = Vector3.new(14, 0.6, 6), CFrame = base * CFrame.new(0, 0.3, 0),
		Material = stone.Material, Color = Color3.fromRGB(95, 105, 140) }, model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Levels"
	prompt.ObjectText = config.titleKey
	prompt:SetAttribute("ActionKey", "HUB_PORTAL_ACTION")
	prompt:SetAttribute("ObjectKey", config.titleKey)
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt:SetAttribute("World", config.world)
	prompt.Parent = core
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(300, 60)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	billboard.MaxDistance = 80
	billboard.Parent = core
	local label = textLabel(config.titleKey, 40, Color3.new(1, 1, 1), billboard, 1)
	label:SetAttribute("TextKey", config.titleKey)
	label.Size = UDim2.fromScale(1, 1)
	label.TextStrokeTransparency = 0.3
	model.Parent = parent
end

local function buildBoard(parent: Instance)
	local board = part({
		Name = "RankingBoard",
		Size = Vector3.new(24, 18, 1),
		CFrame = facingSpawn(BOARD_POSITION, 10),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(28, 34, 60),
	}, parent)
	for _, side in { -1, 1 } do
		part({ Name = "Leg", Size = Vector3.new(1.5, 2, 1.5), CFrame = facingSpawn(BOARD_POSITION, 0.5) * CFrame.new(side * 10, 0, 0),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 78, 110) }, parent)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 30)
	padding.PaddingLeft = UDim.new(0, 40)
	padding.PaddingRight = UDim.new(0, 40)
	padding.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame
	textLabel("Ranking", 120, Color3.fromRGB(255, 205, 60), frame, 1):SetAttribute("TextKey", "HUB_RANKING_TITLE")
	textLabel("Total stars", 44, Color3.fromRGB(170, 185, 220), frame, 2):SetAttribute("TextKey", "HUB_RANKING_METRIC")
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 1, -200)
	list.LayoutOrder = 3
	list.Parent = frame
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = list
	rankingList = list
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	local name: string
	if player then
		name = player.DisplayName
	else
		local ok, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok then result else "#" .. userId
	end
	names[userId] = name
	return name
end

local function refreshBoard()
	local list = rankingList
	local store = rankingStore
	if not list or not store then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, RANKING_SIZE):GetCurrentPage()
	end)
	if not ok then
		warn("[HubService] no se pudo leer el ranking: " .. tostring(page))
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for index, item in page :: { { key: string, value: number } } do
		local userId = tonumber(item.key) or 0
		local color = if index == 1 then Color3.fromRGB(255, 205, 60) else Color3.new(1, 1, 1)
		local label = textLabel(string.format("%d.  %s   ★ %d", index, nameFor(userId), item.value), 54, color, list, index)
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
end

-- Publica el total de estrellas del jugador (lo llama ProgressService al cambiar).
function HubService.submitStars(player: Player, total: number)
	local store = rankingStore
	if not store or total <= 0 then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), total)
	end)
	if not ok then
		warn("[HubService] no se pudo publicar el ranking de " .. player.Name .. ": " .. tostring(err))
	else
		print(string.format("[HubService] ranking: %s con %d estrellas", player.Name, total))
		task.delay(3, refreshBoard)
	end
end

function HubService.start()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(RANKING_STORE)
	end)
	if ok then
		rankingStore = result
	end
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	for _, config in PORTALS do
		buildPortal(config, hub)
	end
	if RunService:IsStudio() then
		buildPortal(LAB_PORTAL, hub)
	end
	buildBoard(hub)
	hub.Parent = workspace
	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(RANKING_REFRESH)
		end
	end)
end

return HubService
