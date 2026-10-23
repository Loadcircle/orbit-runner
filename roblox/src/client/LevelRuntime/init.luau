--!strict
-- Sesión de un nivel: port de orbit_runner_game/scripts/level/level.gd. Construye la
-- copia local del nivel, coloca al jugador y la cámara, lleva el tiempo, las gemas, las
-- chispas y los checkpoints, gestiona reapariciones, pausa y meta, y habla con el
-- servidor (RunValidator) por Shared/Net.
-- Orden de cada fotograma (PreSimulation), como en Godot: reloj → estado del jugador →
-- props (animación y activadores) → lógica del jugador → yo-yo → caída.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCatalog = require(Shared:WaitForChild("LevelCatalog"))
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local LevelBuilder = require(script:WaitForChild("LevelBuilder"))
local LevelClock = require(script:WaitForChild("LevelClock"))
local Palette = require(script:WaitForChild("Palette"))
local Triggers = require(script:WaitForChild("Triggers"))
local Client = script.Parent
local InputRouter = require(Client:WaitForChild("InputRouter"))
local Sfx = require(Client:WaitForChild("Sfx"))
local Strings = require(Client:WaitForChild("Strings"))

local Net = Shared:WaitForChild("Net")
local L = PropTuning.level

export type Deps = {
	player: any, -- PlayerController
	camera: any, -- FollowCamera
	yoyo: any, -- YoyoController
	hud: any, -- Hud
	touch: any, -- TouchControls
	isTouch: () -> boolean,
	progress: { [string]: any }?, -- instantánea del servidor (gemas ya conseguidas)
	onFinished: (session: any, summary: { [string]: any }?) -> (),
}

local LevelSession = {}
LevelSession.__index = LevelSession

export type LevelSession = typeof(setmetatable({} :: {
	id: string,
	data: { [string]: any },
	deps: Deps,
	clock: LevelClock.LevelClock,
	triggers: Triggers.Triggers,
	props: { any },
	folder: Folder,
	elapsed: number,
	timerRunning: boolean,
	finished: boolean,
	paused: boolean,
	respawns: number,
	gems: { boolean },
	sparks: number,
	sparksTotal: number,
	goldTime: number?,
	checkpointIndex: number,
	_respawnFeet: Vector3,
	_respawnFacing: Vector3,
	_respawnYaw: number,
	_promptOwner: any,
	_route: { Vector3 },
	_routeCumulative: { number },
	_connections: { any },
	_ownedGems: { boolean },
	_tutorial: boolean,
	_lab: boolean,
}, LevelSession))

local function yawToFacing(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

function LevelSession.new(id: string, deps: Deps): LevelSession
	local data = LevelCatalog.data(id)
	assert(data, "nivel desconocido: " .. id)
	local entry = LevelCatalog.get(id)
	local owned = { false, false, false }
	local progressLevels = deps.progress and deps.progress.levels
	if progressLevels and progressLevels[id] and progressLevels[id].gems then
		owned = progressLevels[id].gems
	end
	local self = setmetatable({
		id = id,
		data = data,
		deps = deps,
		clock = LevelClock.new(),
		triggers = Triggers.new(),
		props = {},
		folder = nil :: any,
		elapsed = 0,
		timerRunning = false,
		finished = false,
		paused = false,
		respawns = 0,
		gems = { false, false, false },
		sparks = 0,
		sparksTotal = 0,
		goldTime = if data.medals and not data.tutorial then data.medals.gold else nil,
		checkpointIndex = 0,
		_respawnFeet = Vector3.zero,
		_respawnFacing = Vector3.new(0, 0, -1),
		_respawnYaw = 0,
		_promptOwner = nil,
		_route = {},
		_routeCumulative = {},
		_connections = {},
		_ownedGems = owned,
		_tutorial = data.tutorial == true,
		_lab = entry ~= nil and entry.lab,
	}, LevelSession)
	self:_build()
	return self
end

function LevelSession._build(self: LevelSession)
	local data = self.data
	local deps = self.deps
	local biome = Palette.biome(data.biome)
	Palette.applyLighting(biome)
	local root, geometry, triggerFolder, decor = LevelBuilder.prepare()
	self.folder = root
	self.triggers:addRoot(triggerFolder)
	local ctx = {
		player = deps.player,
		session = self,
		triggers = self.triggers,
		folder = root,
		geometry = geometry,
		triggerFolder = triggerFolder,
		decor = decor,
		biome = biome,
	}
	local built = LevelBuilder.build(data, ctx :: any)
	self.props = built.props
	self.sparksTotal = #((data.collectibles or {}).sparks or {})

	local start = data.player_start or { pos = { 0, 0, 0 }, yaw = 0 }
	self._respawnFeet = Units.vector(start.pos)
	self._respawnYaw = math.rad(start.yaw or 0)
	self._respawnFacing = yawToFacing(self._respawnYaw)
	self:_buildRoute()

	local player = deps.player
	player.inputEnabled = true
	player.frozen = false
	player.getCameraYaw = function()
		return deps.camera:getYaw()
	end
	table.insert(self._connections, player.died:Connect(function()
		self:_onPlayerDied()
	end))
	player:respawnAt(self._respawnFeet, self._respawnFacing)
	deps.camera:setTarget(player)
	deps.camera:snap(self._respawnYaw)
	deps.hud:setup(self)
	deps.hud.onPause = function()
		self:pause()
	end
	deps.touch.readiness = function()
		return {
			yoyo = deps.yoyo:isReady() and (player.onFloor or player.yoyoCharges > 0),
			action = player.onFloor or player.dashAvailable,
		}
	end
	deps.touch.onCameraDrag = function(pixels: number)
		deps.camera:addTouchDrag(pixels)
	end
	table.insert(self._connections, InputRouter.onPressed("pause", function()
		if not self.finished then
			if self.paused then
				self:resume()
			else
				self:pause()
			end
		end
	end))
	if not self._lab then
		(Net:WaitForChild("RunStart") :: RemoteEvent):FireServer(self.id)
	end
end

-- ------------------------------------------------------------------ fotograma

function LevelSession.step(self: LevelSession, dt: number)
	if self.paused then
		return
	end
	local player = self.deps.player
	self.clock:advance(dt)
	local time = self.clock.time
	player:beginStep()
	for _, prop in self.props do
		if prop.step then
			prop:step(dt, time)
		end
	end
	if not player.isDead and not player.frozen then
		self.triggers:step(player.rig.hitbox, dt)
	end
	player:step(dt)
	self.deps.yoyo:step(dt)

	if self.finished then
		return
	end
	if not self.timerRunning and self:_playerStarted() then
		self.timerRunning = true
	end
	if self.timerRunning then
		self.elapsed += dt
	end
	local killHeight = Units.studs(self.data.kill_height or L.killHeight)
	if player:feet().Y < killHeight and not player.isDead then
		player:hurt()
	end
end

function LevelSession.render(self: LevelSession, _dt: number)
	self.deps.hud:update()
	self.deps.touch:update()
end

function LevelSession._playerStarted(self: LevelSession): boolean
	return InputRouter.getMove().Magnitude > 0.2
		or InputRouter.isDown("jump")
		or InputRouter.isDown("yoyo")
		or InputRouter.isDown("action")
end

-- ------------------------------------------------------------------ flujo

function LevelSession.pause(self: LevelSession)
	if self.finished or self.paused then
		return
	end
	self.paused = true
	self.clock.paused = true
	self.deps.player.rig.root.Anchored = true
	self.deps.touch:releaseAll()
	InputRouter.clearPressed()
	self:_fire("pause")
end

function LevelSession.resume(self: LevelSession)
	if not self.paused then
		return
	end
	self.paused = false
	self.clock.paused = false
	local player = self.deps.player
	player.rig.root.Anchored = player.isDead or player.frozen
	InputRouter.clearPressed()
	self:_fire("resume")
end

-- Avisos a la capa de juego (menús); la asigna Game.
function LevelSession._fire(self: LevelSession, event: string)
	local handler = (self :: any).onEvent
	if handler then
		handler(event)
	end
end

function LevelSession.finish(self: LevelSession)
	if self.finished then
		return
	end
	self.finished = true
	self.timerRunning = false
	local player = self.deps.player
	player:freeze()
	self.deps.hud:onFinished()
	self.deps.touch:releaseAll()
	Sfx.play("goal")
	Sfx.vibrate(60)
	local report = {
		time = self.elapsed,
		sparks = self.sparks,
		gems = table.clone(self.gems),
		respawns = self.respawns,
	}
	task.spawn(function()
		local summary = nil
		if not self._lab then
			local ok, result = pcall(function()
				return (Net:WaitForChild("RunFinish") :: RemoteFunction):InvokeServer(report)
			end)
			summary = if ok then result else { accepted = false, reason = "network" }
		end
		task.wait(PropTuning.goal.resultsDelay)
		if self.folder.Parent then
			self.deps.onFinished(self, summary)
		end
	end)
end

-- ------------------------------------------------------------------ eventos de los props

function LevelSession.onCheckpoint(self: LevelSession, spawnFeet: Vector3, facing: Vector3)
	self._respawnFeet = spawnFeet
	self._respawnFacing = facing
	self._respawnYaw = self.deps.camera.targetYaw
	self.deps.hud:flashMessage(Strings.get("HUD_CHECKPOINT"))
	self.checkpointIndex += 1
	if not self._lab then
		(Net:WaitForChild("RunCheckpoint") :: RemoteEvent):FireServer(self:_checkpointNumber(spawnFeet))
	end
end

-- Número (1..n) del checkpoint en el orden del nivel, a partir de su punto de aparición.
function LevelSession._checkpointNumber(self: LevelSession, spawnFeet: Vector3): number
	for index, entry in self.data.checkpoints or {} do
		local spawn = Units.vector(entry.spawn or entry.pos)
		if (spawn - spawnFeet).Magnitude < 0.5 then
			return index
		end
	end
	return 0
end

function LevelSession.onGem(self: LevelSession, index: number)
	self.gems[index + 1] = true
	if not self._lab then
		(Net:WaitForChild("RunGem") :: RemoteEvent):FireServer(index)
	end
end

function LevelSession.onSpark(self: LevelSession)
	self.sparks += 1
end

function LevelSession.gemAlreadyOwned(self: LevelSession, index: number): boolean
	return self._ownedGems[index + 1] == true
end

function LevelSession.setCameraYaw(self: LevelSession, yaw: number)
	self.deps.camera.targetYaw = yaw
end

function LevelSession.showPrompt(self: LevelSession, owner: any, key: string)
	self._promptOwner = owner
	local touchKey = key .. "_TOUCH"
	if self.deps.isTouch() and Strings.has(touchKey) then
		key = touchKey
	end
	self.deps.hud:showPrompt(Strings.get(key))
end

function LevelSession.hidePrompt(self: LevelSession, owner: any)
	if self._promptOwner == owner then
		self._promptOwner = nil
		self.deps.hud:hidePrompt()
	end
end

function LevelSession.playSfx(_self: LevelSession, name: string)
	Sfx.play(name)
end

function LevelSession.vibrate(_self: LevelSession, milliseconds: number)
	Sfx.vibrate(milliseconds)
end

function LevelSession._onPlayerDied(self: LevelSession)
	self.respawns += 1
	self.deps.camera:shake(L.deathShake)
	Sfx.play("fail")
	Sfx.vibrate(80)
	self.deps.hud:fadeFlash()
	task.delay(L.respawnDelay, function()
		while self.paused and self.folder.Parent do
			task.wait()
		end
		if self.finished or not self.folder.Parent then
			return
		end
		self.triggers:reset()
		self.deps.player:respawnAt(self._respawnFeet, self._respawnFacing)
		self.deps.camera:snap(self._respawnYaw)
	end)
end

-- ------------------------------------------------------------------ progreso de la ruta

function LevelSession._buildRoute(self: LevelSession)
	local points = { self._respawnFeet }
	for _, piece in self.data.route or {} do
		table.insert(points, Units.vector(piece.pos))
	end
	local goal = self.data.goal
	if goal and goal.pos then
		table.insert(points, Units.vector(goal.pos))
	end
	local cumulative = { 0 }
	for i = 2, #points do
		cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	self._route = points
	self._routeCumulative = cumulative
end

-- 0..1 a lo largo de la ruta (salida → piezas → meta).
function LevelSession.routeProgress(self: LevelSession): number
	local points = self._route
	if #points < 2 then
		return 0
	end
	local p = self.deps.player:feet()
	local bestDistance = math.huge
	local best = 0
	for i = 1, #points - 1 do
		local a = points[i]
		local ab = points[i + 1] - a
		local lengthSquared = math.max(ab:Dot(ab), 0.001)
		local t = math.clamp((p - a):Dot(ab) / lengthSquared, 0, 1)
		local d = (a + ab * t - p).Magnitude
		if d < bestDistance then
			bestDistance = d
			best = self._routeCumulative[i] + ab.Magnitude * t
		end
	end
	return math.clamp(best / self._routeCumulative[#self._routeCumulative], 0, 1)
end

function LevelSession.destroy(self: LevelSession)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, prop in self.props do
		if prop.destroy then
			prop:destroy()
		end
	end
	self.deps.hud:hidePrompt()
	self.folder:Destroy()
end

return LevelSession
