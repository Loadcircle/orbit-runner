--!strict
-- Capa de juego del cliente: crea el controlador, la animación, el yo-yo y la cámara en
-- cada aparición del personaje, la interfaz (HUD, táctil, menús) y alterna entre el
-- selector y la sesión de nivel. Equivale al SceneRouter + Level de Godot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCatalog = require(Shared:WaitForChild("LevelCatalog"))
local Units = require(Shared:WaitForChild("Units"))
local Client = script.Parent
local AnimationDriver = require(Client:WaitForChild("AnimationDriver"))
local Calibration = require(Client:WaitForChild("Dev"):WaitForChild("Calibration"))
local DebugProbe = require(Client:WaitForChild("DebugProbe"))
local FollowCamera = require(Client:WaitForChild("FollowCamera"))
local InputRouter = require(Client:WaitForChild("InputRouter"))
local LevelSession = require(Client:WaitForChild("LevelRuntime"))
local PlayerController = require(Client:WaitForChild("PlayerController"))
local Strings = require(Client:WaitForChild("Strings"))
local YoyoController = require(Client:WaitForChild("YoyoController"))
local Ui = Client:WaitForChild("Ui")
local Hud = require(Ui:WaitForChild("Hud"))
local LabPanel = require(Ui:WaitForChild("LabPanel"))
local LevelSelect = require(Ui:WaitForChild("LevelSelect"))
local PauseMenu = require(Ui:WaitForChild("PauseMenu"))
local ResultsScreen = require(Ui:WaitForChild("ResultsScreen"))
local SettingsPanel = require(Ui:WaitForChild("SettingsPanel"))
local Sfx = require(Client:WaitForChild("Sfx"))
local TouchControls = require(Ui:WaitForChild("TouchControls"))

local Net = Shared:WaitForChild("Net")

local Game = {}

local player = Players.LocalPlayer
local controller: PlayerController.PlayerController? = nil
local animation: AnimationDriver.AnimationDriver? = nil
local yoyo: YoyoController.YoyoController? = nil
local camera = FollowCamera.new()
local session: LevelSession.LevelSession? = nil
local currentId: string? = nil
local progress: { [string]: any }? = nil

local hud: Hud.Hud
local touch: TouchControls.TouchControls
local pauseMenu: PauseMenu.PauseMenu
local results: ResultsScreen.ResultsScreen
local settingsPanel: SettingsPanel.SettingsPanel
local levelSelect: LevelSelect.LevelSelect
local labPanel: LabPanel.LabPanel

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

local function updateTouchVisibility()
	touch:setVisible(isTouch() and session ~= nil and not session.paused and not session.finished)
end

local function closeSession()
	if session then
		session:destroy()
		session = nil
	end
	pauseMenu:close()
	results:close()
	labPanel:setVisible(false)
	hud:setVisible(false)
	updateTouchVisibility()
end

local function showSelect()
	closeSession()
	currentId = nil
	local current = controller
	if current then
		-- De vuelta al vestíbulo (Workspace.Lobby), lejos de la zona de niveles.
		local lobby = workspace:FindFirstChild("Lobby")
		local spawn = lobby and lobby:FindFirstChild("LobbySpawn") :: BasePart?
		current:unfreeze()
		if spawn then
			current:respawnAt(spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0), Vector3.new(0, 0, -1))
			camera:snap(0)
		end
		current.inputEnabled = false
	end
	task.spawn(function()
		refreshProgress()
		levelSelect:open(progress)
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
		touch = touch,
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
			updateTouchVisibility()
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
		end,
	});
	(newSession :: any).onEvent = function(event: string)
		if event == "pause" then
			pauseMenu:open()
		elseif event == "resume" then
			pauseMenu:close()
			settingsPanel.gui.Enabled = false
		end
		updateTouchVisibility()
	end
	session = newSession
	labPanel:setVisible(id == "lab")
	hud:setVisible(true)
	updateTouchVisibility()
end

local function onCharacterAdded(character: Model)
	if animation then
		animation:destroy()
	end
	if yoyo then
		yoyo:destroy()
	end
	if controller then
		controller:destroy()
	end
	local current = PlayerController.new(character)
	controller = current
	animation = AnimationDriver.new(current :: any)
	local newYoyo = YoyoController.new(current :: any)
	newYoyo.playSfx = Sfx.play
	yoyo = newYoyo
	current.yoyo = newYoyo :: any
	current.getCameraYaw = function()
		return camera:getYaw()
	end
	camera:setTarget(current :: any)
	camera:snap(0)
	camera:start()
	if currentId then
		Game.play(currentId)
	else
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
	if animation then
		animation:update(dt)
	end
	if session then
		session:render(dt)
	end
end

-- Mide una técnica en el laboratorio (Dev/Calibration). Salidas en metros: pista A
-- para los saltos y zona C para los trampolines.
local function measureTechnique(technique: string): { [string]: any }?
	local c = controller
	if not c then
		return nil
	end
	return Calibration.measure(c, technique, function(tech: string)
		local starts = {
			trampoline = { 30 - 3.5, 0.1, -16 },
			trampoline_24 = { 30 + 3.5, 0.1, -16 },
			yoyo_ground = { 0, 0.1, -20 },
		}
		local start = starts[tech] or { 0, 0.1, -20 }
		c:respawnAt(Vector3.new(start[1], start[2], start[3]) * Units.K, Vector3.new(0, 0, -1))
		camera.targetYaw = 0
		camera:snap(0)
	end)
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
	DebugProbe.command("select", function()
		showSelect()
		return true
	end)
	DebugProbe.command("teleport", function(x: number, y: number, z: number, yawDegrees: number?)
		local c = controller
		if c then
			local yaw = math.rad(yawDegrees or 0)
			c:respawnAt(Vector3.new(x, y, z) * Units.K, Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)))
			camera.targetYaw = yaw
			camera:snap(yaw)
		end
		return true
	end)
	-- Entrada programada para pruebas desde Studio (MCP): mover, pulsar y soltar.
	local scriptedState: { move: Vector2, held: { [string]: boolean } }? = nil
	DebugProbe.command("input", function(moveX: number?, moveY: number?)
		if moveX == nil then
			scriptedState = nil
			InputRouter.setScripted(nil)
			return true
		end
		if not scriptedState then
			scriptedState = { move = Vector2.zero, held = {} }
			InputRouter.setScripted(scriptedState)
		end
		(scriptedState :: any).move = Vector2.new(moveX, moveY or 0)
		return true
	end)
	DebugProbe.command("press", function(name: string, hold: boolean?)
		InputRouter.scriptedPress(name :: any, hold == true)
		return true
	end)
	DebugProbe.command("release", function(name: string)
		if scriptedState then
			scriptedState.held[name] = false
		end
		return true
	end)
	DebugProbe.command("forceDevice", function(device: string)
		InputRouter.preferredDevice = device :: any
		InputRouter.deviceChanged:Fire(device)
		return true
	end)
	DebugProbe.provide("touch", function()
		local buttons = {}
		for name, view in touch.buttons do
			buttons[name] = {
				position = { view.hit.AbsolutePosition.X, view.hit.AbsolutePosition.Y },
				size = { view.hit.AbsoluteSize.X, view.hit.AbsoluteSize.Y },
				dimmed = view.icon.TextTransparency > 0.3,
			}
		end
		return { visible = touch.gui.Enabled, buttons = buttons }
	end)
	DebugProbe.command("frameCap", function(fps: number?)
		Calibration.setFrameCap(fps)
		return true
	end)
	DebugProbe.command("measure", measureTechnique)
end

function Game.start()
	Strings.start()
	InputRouter.start()
	local gui = player:WaitForChild("PlayerGui")
	hud = Hud.new(gui)
	hud:setVisible(false)
	touch = TouchControls.new(gui)
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
		quit = showSelect,
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
			showSelect()
		end,
		levels = showSelect,
	})
	labPanel = LabPanel.new(gui)
	labPanel.measure = measureTechnique
	levelSelect = LevelSelect.new(gui)
	levelSelect.onPlay = Game.play
	levelSelect.onSettings = function()
		settingsPanel:open()
	end
	InputRouter.deviceChanged.Event:Connect(updateTouchVisibility)
	-- "Reiniciar personaje" del menú de Roblox = volver al último checkpoint (sin
	-- reconstruir el avatar).
	local reset = Instance.new("BindableEvent")
	reset.Event:Connect(function()
		if controller and session and not session.finished then
			controller:hurt()
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
	showSelect()
end

return Game
