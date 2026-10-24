--!strict
-- Capa de juego del cliente: en cada aparición del personaje crea su cuerpo (Character,
-- sobre el control de la plantilla Platformer) y el yo-yo; monta la interfaz (HUD y
-- menús) y alterna entre el vestíbulo (el escenario de la plantilla, con un portal por
-- mundo que abre su panel de niveles, R23) y la sesión de nivel. Equivale al
-- SceneRouter + Level de Godot.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCatalog = require(Shared:WaitForChild("LevelCatalog"))
local Units = require(Shared:WaitForChild("Units"))
local Client = script.Parent
local CameraRig = require(Client:WaitForChild("CameraRig"))
local Character = require(Client:WaitForChild("Character"))
local DebugProbe = require(Client:WaitForChild("DebugProbe"))
local InputRouter = require(Client:WaitForChild("InputRouter"))
local LevelSession = require(Client:WaitForChild("LevelRuntime"))
local Strings = require(Client:WaitForChild("Strings"))
local YoyoController = require(Client:WaitForChild("YoyoController"))
local Ui = Client:WaitForChild("Ui")
local Hud = require(Ui:WaitForChild("Hud"))
local LevelSelect = require(Ui:WaitForChild("LevelSelect"))
local PauseMenu = require(Ui:WaitForChild("PauseMenu"))
local ResultsScreen = require(Ui:WaitForChild("ResultsScreen"))
local SettingsPanel = require(Ui:WaitForChild("SettingsPanel"))
local Sfx = require(Client:WaitForChild("Sfx"))

local Net = Shared:WaitForChild("Net")

local Game = {}

local player = Players.LocalPlayer
local controller: Character.Character? = nil
local yoyo: YoyoController.YoyoController? = nil
local camera = CameraRig.new()
local session: LevelSession.LevelSession? = nil
local currentId: string? = nil
local progress: { [string]: any }? = nil

local hud: Hud.Hud
local pauseMenu: PauseMenu.PauseMenu
local results: ResultsScreen.ResultsScreen
local settingsPanel: SettingsPanel.SettingsPanel
local levelSelect: LevelSelect.LevelSelect

local function isTouch(): boolean
	return InputRouter.preferredDevice == "touch"
end

local function refreshProgress()
	local ok, snapshot = pcall(function()
		return (Net:WaitForChild("GetProgress") :: RemoteFunction):InvokeServer()
	end)
	if ok then
		progress = snapshot
	end
end

local function closeSession()
	if session then
		session:destroy()
		session = nil
	end
	pauseMenu:close()
	results:close()
	hud:setVisible(false)
end

local panelOpening = false

-- Punto de aparición del vestíbulo. Con StreamingEnabled el SpawnLocation no existe en el
-- cliente mientras se juega un nivel (está a miles de studs), así que se usa el atributo
-- que publica HubService y, si falta, el SpawnLocation.
local function lobbyFeet(): Vector3?
	local published = workspace:GetAttribute("LobbySpawn")
	if typeof(published) == "Vector3" then
		return published
	end
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	return if spawn then spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0) else nil
end

-- Vuelve al vestíbulo: el escenario de la plantilla, lejos de la zona de niveles. Congela
-- al personaje mientras el streaming carga el suelo del vestíbulo y luego lo coloca.
local function returnToLobby(current: Character.Character)
	local feet = lobbyFeet()
	if not feet then
		current:unfreeze()
		return
	end
	current:freeze()
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(feet, 10)
		end)
		if controller ~= current or session then
			return -- el personaje cambió o empezó un nivel mientras cargaba
		end
		current:unfreeze()
		current:respawnAt(feet, Vector3.new(0, 0, -1))
		camera:snap(0)
		current.inputEnabled = not (levelSelect.gui.Enabled or panelOpening)
	end)
end

-- Panel de niveles de un mundo (portal del vestíbulo); 0 = laboratorio.
local function openWorld(world: number)
	local current = controller
	if current then
		current.inputEnabled = false
	end
	panelOpening = true
	task.spawn(function()
		refreshProgress()
		panelOpening = false
		levelSelect:open(world, progress)
	end)
end

-- Vuelve al vestíbulo caminando; con `world`, reabre el panel de ese mundo.
local function goToLobby(world: number?)
	closeSession()
	currentId = nil
	levelSelect:close()
	local current = controller
	if current then
		returnToLobby(current)
	end
	if world then
		openWorld(world)
	else
		task.spawn(refreshProgress)
	end
end

local function worldOf(id: string?): number?
	local entry = if id then LevelCatalog.get(id) else nil
	return if entry then entry.world else nil
end

-- Textos del vestíbulo (los construye HubService con atributos TextKey/ActionKey).
local function localizeHub(instance: Instance)
	local key = instance:GetAttribute("TextKey")
	if typeof(key) == "string" and instance:IsA("TextLabel") then
		instance.Text = Strings.get(key)
	end
	if instance:IsA("ProximityPrompt") then
		local action, object = instance:GetAttribute("ActionKey"), instance:GetAttribute("ObjectKey")
		if typeof(action) == "string" then
			instance.ActionText = Strings.get(action)
		end
		if typeof(object) == "string" then
			instance.ObjectText = Strings.get(object)
		end
	end
end

local function watchHub()
	task.spawn(function()
		local hub = workspace:WaitForChild("Hub", 30)
		if not hub then
			return
		end
		for _, descendant in hub:GetDescendants() do
			localizeHub(descendant)
		end
		hub.DescendantAdded:Connect(function(descendant)
			task.defer(localizeHub, descendant)
		end)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		local world = prompt:GetAttribute("World")
		if who == player and typeof(world) == "number" and not session and not levelSelect.gui.Enabled then
			openWorld(world)
		end
	end)
end

function Game.play(id: string)
	local current = controller
	if not current or not yoyo then
		return
	end
	closeSession()
	levelSelect:close()
	currentId = id
	current:unfreeze()
	local newSession = LevelSession.new(id, {
		player = current,
		camera = camera,
		yoyo = yoyo,
		hud = hud,
		isTouch = isTouch,
		progress = progress,
		onFinished = function(finishedSession: any, summary: { [string]: any }?)
			local data = finishedSession.data
			local index = 0
			for i, entry in LevelCatalog.entries do
				if entry.id == finishedSession.id then
					index = i
				end
			end
			results:open({
				time = finishedSession.elapsed,
				gems = finishedSession.gems,
				sparks = finishedSession.sparks,
				sparksTotal = finishedSession.sparksTotal,
				respawns = finishedSession.respawns,
				medals = data.medals,
				tutorial = data.tutorial == true or data.lab == true,
				hasNext = LevelCatalog.entries[index + 1] ~= nil,
			}, summary)
			if data.tutorial ~= true and data.lab ~= true then
				local levelId = finishedSession.id
				task.spawn(function()
					task.wait(1.5) -- da tiempo a que el servidor publique el récord
					local ok, entries = pcall(function()
						return (Net:WaitForChild("GetLeaderboard") :: RemoteFunction):InvokeServer(levelId)
					end)
					if ok and typeof(entries) == "table" and currentId == levelId then
						results:showLeaderboard(entries, player.UserId)
					end
				end)
			end
		end,
	});
	(newSession :: any).onEvent = function(event: string)
		if event == "pause" then
			pauseMenu:open()
		elseif event == "resume" then
			pauseMenu:close()
			settingsPanel.gui.Enabled = false
		end
	end
	session = newSession
	hud:setVisible(true)
end

local function onCharacterAdded(model: Model)
	if yoyo then
		yoyo:destroy()
	end
	if controller then
		controller:destroy()
	end
	local current = Character.new(model)
	controller = current
	local newYoyo = YoyoController.new(current :: any)
	newYoyo.playSfx = Sfx.play
	yoyo = newYoyo
	current.yoyo = newYoyo :: any
	camera:setTarget(current)
	if currentId then
		Game.play(currentId)
	elseif levelSelect.gui.Enabled then
		current.inputEnabled = false
	end
end

local function step(dt: number)
	local current = controller
	if not current or not current.rig.root.Parent then
		return
	end
	if session then
		session:step(dt)
	else
		current:beginStep()
		current:step(dt)
		if yoyo then
			yoyo:step(dt)
		end
	end
end

local function render(dt: number)
	if session then
		session:render(dt)
	end
end

local function registerProbe()
	DebugProbe.start()
	DebugProbe.provide("player", function()
		local c = controller
		if not c then
			return nil
		end
		local feet = c:feet()
		return {
			feet = { feet.X, feet.Y, feet.Z },
			velocity = { c.velocity.X, c.velocity.Y, c.velocity.Z },
			onFloor = c.onFloor,
			sliding = c.isSliding,
			dashing = c.isDashing,
			dead = c.isDead,
			frozen = c.frozen,
			dashAvailable = c.dashAvailable,
			yoyoCharges = c.yoyoCharges,
			yoyoState = if yoyo then yoyo.state else nil,
			action = c.rig.character:GetAttribute("action"),
			facing = { c.facing.X, c.facing.Z },
		}
	end)
	DebugProbe.provide("session", function()
		local s = session
		if not s then
			return nil
		end
		return {
			id = s.id,
			elapsed = s.elapsed,
			timerRunning = s.timerRunning,
			finished = s.finished,
			paused = s.paused,
			respawns = s.respawns,
			gems = s.gems,
			sparks = s.sparks,
			sparksTotal = s.sparksTotal,
			clock = s.clock.time,
			cameraYaw = camera.targetYaw,
			progress = s:routeProgress(),
		}
	end)
	DebugProbe.command("play", function(id: string)
		Game.play(id)
		return true
	end)
	DebugProbe.command("select", function(world: number?)
		goToLobby(world or 1)
		return true
	end)
	DebugProbe.command("teleport", function(x: number, y: number, z: number, yawDegrees: number?)
		local c = controller
		if c then
			local yaw = math.rad(yawDegrees or 0)
			c:respawnAt(Vector3.new(x, y, z) * Units.K, Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)))
			camera:snap(yaw)
		end
		return true
	end)
	DebugProbe.command("press", function(name: string)
		InputRouter.scriptedPress(name :: any)
		return true
	end)
end

function Game.start()
	Strings.start()
	InputRouter.start()
	local gui = player:WaitForChild("PlayerGui")
	hud = Hud.new(gui)
	hud:setVisible(false)
	settingsPanel = SettingsPanel.new(gui)
	pauseMenu = PauseMenu.new(gui, {
		resume = function()
			if session then
				session:resume()
			end
		end,
		restart = function()
			if currentId then
				Game.play(currentId)
			end
		end,
		settings = function()
			settingsPanel:open()
		end,
		quit = function()
			goToLobby(nil)
		end,
	})
	results = ResultsScreen.new(gui, {
		retry = function()
			if currentId then
				Game.play(currentId)
			end
		end,
		nextLevel = function()
			for i, entry in LevelCatalog.entries do
				if entry.id == currentId and LevelCatalog.entries[i + 1] then
					Game.play(LevelCatalog.entries[i + 1].id)
					return
				end
			end
			goToLobby(worldOf(currentId))
		end,
		levels = function()
			goToLobby(worldOf(currentId))
		end,
	})
	levelSelect = LevelSelect.new(gui)
	levelSelect.onPlay = Game.play
	levelSelect.onSettings = function()
		settingsPanel:open()
	end
	levelSelect.onClose = function()
		if controller and not session then
			controller.inputEnabled = true
		end
	end
	watchHub()
	InputRouter.onPressed("yoyo", function()
		if controller then
			controller:requestYoyo()
		end
	end)
	-- "Reiniciar personaje" del menú de Roblox: en un nivel vuelve al último checkpoint;
	-- en el vestíbulo, a la salida.
	local reset = Instance.new("BindableEvent")
	reset.Event:Connect(function()
		local current = controller
		if not current then
			return
		end
		if session and not session.finished then
			current:hurt()
		elseif not session then
			returnToLobby(current)
		end
	end)
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(function()
				StarterGui:SetCore("ResetButtonCallback", reset)
			end) then
				break
			end
			task.wait(0.5)
		end
	end)
	registerProbe()

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService.PreSimulation:Connect(step)
	RunService.RenderStepped:Connect(render)
	goToLobby(nil)
end

return Game
