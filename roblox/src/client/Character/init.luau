--!strict
-- Cuerpo del protagonista sobre el control de la plantilla Platformer de Roblox (R14).
-- El movimiento lo hacen el Humanoid nativo, los controles por defecto y
-- ReplicatedStorage.Platformer (ControlScript, Controller y Actions: salto, doble salto,
-- dash, rodar y salto largo). Este módulo no mueve al personaje: expone a la sesión de
-- nivel, a los props y al yo-yo lo que necesitan (pies, velocidad, suelo, rebotes,
-- impulsos, viento, muerte, reaparición y congelación) y lanza el yo-yo.
-- Orden de cada fotograma, como antes: beginStep() → props → step(dt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementTuning = require(Shared:WaitForChild("MovementTuning"))
local Signal = require(Shared:WaitForChild("Signal"))
local Units = require(Shared:WaitForChild("Units"))

local Tuning = MovementTuning.scaled()
-- Atributos y valores de la plantilla (ReplicatedStorage.Platformer.Constants).
local ACTION_ATTRIBUTE = "action"
local CAN_DASH_ATTRIBUTE = "canDash"
local CAN_DOUBLE_JUMP_ATTRIBUTE = "canDoubleJump"
local FORCE_FACTOR = 1500
local BOOST_TIME = 0.6
local THROW_POSE_TIME = 0.3
-- Gesto de lanzar el yo-yo: el golpe de herramienta del Animate estándar de Roblox
-- (toolslash, nativo y replicado). Si el avatar trae otro paquete se usa el suyo.
local THROW_ANIMATION_ID = "rbxassetid://522635514"
local THROW_ANIMATION_SPEED = 1.6

local Character = {}
Character.__index = Character

export type YoyoLike = {
	isReady: (any) -> boolean,
	throw: (any, from: Vector3, to: Vector3) -> (),
	deployUnder: (any, feet: Vector3) -> (),
	recallInstant: (any) -> (),
}

export type Rig = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	hitbox: Part,
	hitboxWeld: Weld,
}

export type Character = typeof(setmetatable({} :: {
	rig: Rig,
	tuning: MovementTuning.Tuning,
	inputEnabled: boolean,
	getCameraYaw: () -> number,
	yoyo: YoyoLike?,
	velocity: Vector3,
	onFloor: boolean,
	dashAvailable: boolean,
	yoyoCharges: number,
	isSliding: boolean,
	isDashing: boolean,
	isDead: boolean,
	frozen: boolean,
	throwTimer: number,
	facing: Vector3,
	died: Signal.Signal<>,
	bounced: Signal.Signal<string>,
	yoyoThrown: Signal.Signal<>,
	_queryParams: RaycastParams,
	_controlsEnabled: boolean?,
	_yoyoRequested: boolean,
	_spawnGrace: number,
	_boost: LinearVelocity?,
	_throwTrack: AnimationTrack?,
	_connections: { RBXScriptConnection },
}, Character))

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Controles por defecto de Roblox (joystick táctil, teclado, mando): se apagan en menús,
-- pausa y meta, y se encienden durante el juego.
local function setDefaultControls(enabled: boolean)
	local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if module and module:IsA("ModuleScript") then
		local ok, controls = pcall(function()
			return (require(module) :: any):GetControls()
		end)
		if ok and controls then
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end
end

local function makeHitbox(root: BasePart): (Part, Weld)
	-- Cilindro vertical (r 0.35 m) como cápsula de juego que consultan los activadores.
	local hitbox = Instance.new("Part")
	hitbox.Name = "GameplayHitbox"
	hitbox.Shape = Enum.PartType.Cylinder
	hitbox.Massless = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = false
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = hitbox
	weld.Parent = hitbox
	hitbox.Parent = root
	return hitbox, weld
end

function Character.new(model: Model): Character
	local humanoid = model:WaitForChild("Humanoid") :: Humanoid
	local root = model:WaitForChild("HumanoidRootPart") :: BasePart
	local hitbox, hitboxWeld = makeHitbox(root)
	local queryParams = RaycastParams.new()
	queryParams.FilterType = Enum.RaycastFilterType.Exclude
	queryParams.FilterDescendantsInstances = { model }
	queryParams.RespectCanCollide = true
	local self = setmetatable({
		rig = {
			character = model,
			humanoid = humanoid,
			root = root,
			hitbox = hitbox,
			hitboxWeld = hitboxWeld,
		},
		tuning = Tuning,
		inputEnabled = true,
		getCameraYaw = function()
			return 0
		end,
		yoyo = nil,
		velocity = Vector3.zero,
		onFloor = true,
		dashAvailable = true,
		yoyoCharges = 1,
		isSliding = false,
		isDashing = false,
		isDead = false,
		frozen = false,
		throwTimer = 0,
		facing = Vector3.new(0, 0, -1),
		died = Signal.new(),
		bounced = Signal.new(),
		yoyoThrown = Signal.new(),
		_queryParams = queryParams,
		_controlsEnabled = nil,
		_yoyoRequested = false,
		_spawnGrace = 0,
		_boost = nil,
		_throwTrack = nil,
		_connections = {},
	}, Character)
	self:_setHitboxHeight(Tuning.standHeight)
	-- AvatarService normaliza la escala al cargar la apariencia: cambia la altura de cadera.
	table.insert(self._connections, humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
		self:_setHitboxHeight(hitbox.Size.X)
	end))
	-- La muerte nativa (caer al vacío, reiniciar) no se usa en los niveles: la gestiona la
	-- sesión con hurt(); fuera de ellos Roblox reaparece al personaje como siempre.
	return self
end

-- ------------------------------------------------------------------ fotograma

function Character.beginStep(self: Character)
	local rig = self.rig
	if self._controlsEnabled ~= self.inputEnabled then
		self._controlsEnabled = self.inputEnabled
		setDefaultControls(self.inputEnabled)
	end
	if self.isDead or self.frozen then
		return
	end
	self.velocity = rig.root.AssemblyLinearVelocity
	self.onFloor = rig.humanoid.FloorMaterial ~= Enum.Material.Air
	local action = rig.character:GetAttribute(ACTION_ATTRIBUTE)
	self.isSliding = action == "Roll"
	self.isDashing = action == "Dash" or action == "LongJump"
	self.dashAvailable = self.onFloor or rig.character:GetAttribute(CAN_DASH_ATTRIBUTE) ~= false
	if self.onFloor then
		self.yoyoCharges = 1
	end
	local look = flat(rig.root.CFrame.LookVector)
	if look.Magnitude > 0.1 then
		self.facing = look.Unit
	end
	-- Rodar = deslizarse: la cápsula baja para pasar bajo los láseres.
	local height = if self.isSliding then Tuning.slideHeight else Tuning.standHeight
	if math.abs(rig.hitbox.Size.X - height) > 0.01 then
		self:_setHitboxHeight(height)
	end
end

function Character.step(self: Character, dt: number)
	self._spawnGrace = math.max(self._spawnGrace - dt, 0)
	self.throwTimer -= dt
	if self._yoyoRequested then
		self._yoyoRequested = false
		if self.inputEnabled and not self.isDead and not self.frozen then
			self:_tryThrowYoyo()
		end
	end
end

-- Lo llama la acción "Yo-yo" (ActionManager de la plantilla: tecla, mando y botón táctil).
function Character.requestYoyo(self: Character)
	self._yoyoRequested = true
end

function Character.horizontalSpeed(self: Character): number
	return flat(self.velocity).Magnitude
end

-- Posición de los pies (el origen del jugador en Godot).
function Character.feet(self: Character): Vector3
	local rig = self.rig
	return rig.root.Position - Vector3.new(0, rig.root.Size.Y / 2 + rig.humanoid.HipHeight, 0)
end

function Character._setHitboxHeight(self: Character, height: number)
	local rig = self.rig
	local diameter = Tuning.capsuleRadius * 2
	-- El eje de un cilindro de Roblox es X: se gira 90° para dejarlo vertical.
	rig.hitbox.Size = Vector3.new(height, diameter, diameter)
	local feetOffset = -(rig.root.Size.Y / 2 + rig.humanoid.HipHeight)
	rig.hitboxWeld.C0 = CFrame.new(0, feetOffset + height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
end

-- ------------------------------------------------------------------ yo-yo

function Character._tryThrowYoyo(self: Character)
	local yoyo = self.yoyo
	local onFloor = self.onFloor
	if yoyo == nil or not yoyo:isReady() or (not onFloor and self.yoyoCharges <= 0) then
		return
	end
	local t = self.tuning
	local feet = self:feet()
	local up = Vector3.yAxis
	local origin = feet + up * Units.studs(1.0)
	local target: Vector3
	if onFloor then
		target = feet + self.facing * t.yoyoGroundDistance + up * Units.studs(0.1)
		-- Se detiene delante de las paredes.
		local aim = target + up * Units.studs(0.5)
		local hit = Workspace:Raycast(origin, aim - origin, self._queryParams)
		if hit then
			target = hit.Position - self.facing * Units.studs(1.3) - up * Units.studs(0.5)
		end
	else
		self.yoyoCharges -= 1
		if self.velocity.Y < -t.yoyoFallingSpeed then
			-- Ya cae: un disco lanzado quedaría arriba. Se despliega bajo los pies y
			-- funciona como un salto aéreo.
			yoyo:deployUnder(feet - up * Units.studs(0.1))
			self:_playThrow()
			return
		end
		target = feet + flat(self.velocity) * t.yoyoAirLead - up * t.yoyoAirDrop
	end
	yoyo:throw(origin, target)
	self:_playThrow()
end

function Character._playThrow(self: Character)
	self.throwTimer = THROW_POSE_TIME
	local track = self._throwTrack
	if not track then
		local animator = self.rig.humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			self.yoyoThrown:Fire()
			return
		end
		local animate = self.rig.character:FindFirstChild("Animate")
		local slash = animate and animate:FindFirstChild("toolslash")
		local source = slash and slash:FindFirstChildOfClass("Animation")
		local animation = Instance.new("Animation")
		animation.AnimationId = if source then source.AnimationId else THROW_ANIMATION_ID
		local loaded = animator:LoadAnimation(animation)
		loaded.Priority = Enum.AnimationPriority.Action2
		loaded.Looped = false
		self._throwTrack = loaded
		track = loaded
	end
	assert(track, "pista de lanzamiento")
	track:Play(0.05, 1, THROW_ANIMATION_SPEED)
	self.yoyoThrown:Fire()
end

-- ------------------------------------------------------------------ fuerzas externas

-- Quita los impulsos activos de las acciones de la plantilla (dash, rodar, salto largo)
-- y de los boost pads, y vuelve la acción a "None".
function Character._clearActions(self: Character)
	local rig = self.rig
	for _, child in rig.root:GetChildren() do
		if child:IsA("LinearVelocity") then
			child:Destroy()
		end
	end
	self._boost = nil
	rig.character:SetAttribute(ACTION_ATTRIBUTE, "None")
end

-- Velocidad vertical de Godot → la de Roblox que alcanza la misma altura con la gravedad
-- del mundo (los valores de PropTuning se calcularon con la gravedad de subida de Godot).
local function equivalentLaunch(speed: number): number
	return speed * math.sqrt(Workspace.Gravity / Tuning.gravityUp)
end

-- Lanzamiento vertical de trampolines y del disco. Restaura el dash y el doble salto.
function Character.bounce(self: Character, verticalSpeed: number, source: string, _immediate: boolean?)
	if self.isDead or self.frozen or self:isSpawnProtected() then
		return
	end
	local rig = self.rig
	self:_clearActions()
	rig.character:SetAttribute(CAN_DASH_ATTRIBUTE, true)
	rig.character:SetAttribute(CAN_DOUBLE_JUMP_ATTRIBUTE, true)
	if source ~= "yoyo" then
		self.yoyoCharges = 1
	end
	local vy = equivalentLaunch(verticalSpeed)
	rig.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local v = rig.root.AssemblyLinearVelocity
	rig.root.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
	self.velocity = rig.root.AssemblyLinearVelocity
	self.onFloor = false
	self.bounced:Fire(source)
end

-- Boost pads: empuje horizontal con LinearVelocity (como el rodar de la plantilla) que se
-- apaga en BOOST_TIME.
function Character.applyBoost(self: Character, direction: Vector3, speed: number)
	if self.frozen or self.isDead then
		return
	end
	local rig = self.rig
	local dir = flat(direction).Unit
	if self._boost then
		self._boost:Destroy()
	end
	local attachment = rig.root:FindFirstChild("BoostAttachment") :: Attachment?
	if not attachment then
		local created = Instance.new("Attachment")
		created.Name = "BoostAttachment"
		created.Parent = rig.root
		attachment = created
	end
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "BoostVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.MaxForce = FORCE_FACTOR * rig.root.AssemblyMass
	velocity.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
	velocity.Parent = rig.root
	self._boost = velocity
	local walk = rig.humanoid.WalkSpeed
	local tween = TweenService:Create(velocity, TweenInfo.new(BOOST_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		PlaneVelocity = Vector2.new(dir.X, dir.Z) * walk,
	})
	tween.Completed:Once(function()
		velocity:Destroy()
		if self._boost == velocity then
			self._boost = nil
		end
	end)
	tween:Play()
end

-- Columnas de viento: se llama en cada fotograma mientras se está dentro. En Godot la
-- corriente empuja con `lift` y deja la gravedad a la mitad; aquí se suma a la gravedad
-- del mundo la diferencia para obtener la misma aceleración neta.
function Character.applyWind(self: Character, lift: number, maxUpSpeed: number, dt: number)
	if self.frozen or self.isDead then
		return
	end
	local rig = self.rig
	rig.character:SetAttribute(CAN_DASH_ATTRIBUTE, true)
	local net = lift - Tuning.gravityUp * 0.5
	local v = rig.root.AssemblyLinearVelocity
	local maxUp = equivalentLaunch(maxUpSpeed)
	local vy = v.Y
	if vy < maxUp then
		vy = math.min(vy + (net + Workspace.Gravity) * dt, maxUp)
	end
	if self.onFloor and vy > Units.studs(1.0) then
		rig.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		self.onFloor = false
	end
	rig.root.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
	self.velocity = rig.root.AssemblyLinearVelocity
end

function Character.isSpawnProtected(self: Character): boolean
	return self._spawnGrace > 0
end

function Character._setAnchored(self: Character, anchored: boolean)
	local root = self.rig.root
	root.Anchored = anchored
	if anchored then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function Character.hurt(self: Character)
	if self.isDead or self.frozen or self:isSpawnProtected() then
		return
	end
	self.isDead = true
	self:_clearActions()
	self.velocity = Vector3.zero
	self:_setAnchored(true)
	self.died:Fire()
end

-- Reaparece con los pies en `feet` mirando a `facing`.
function Character.respawnAt(self: Character, feet: Vector3, facing: Vector3)
	local rig = self.rig
	local flatFacing = flat(facing)
	self.facing = if flatFacing.Magnitude > 0.1 then flatFacing.Unit else Vector3.new(0, 0, -1)
	self:_clearActions()
	rig.character:SetAttribute(CAN_DASH_ATTRIBUTE, true)
	rig.character:SetAttribute(CAN_DOUBLE_JUMP_ATTRIBUTE, true)
	self:_setAnchored(false)
	local rootPosition = feet + Vector3.new(0, rig.root.Size.Y / 2 + rig.humanoid.HipHeight, 0)
	rig.root.AssemblyLinearVelocity = Vector3.zero
	rig.root.AssemblyAngularVelocity = Vector3.zero
	rig.character:PivotTo(CFrame.lookAlong(rootPosition, self.facing))
	rig.humanoid:ChangeState(Enum.HumanoidStateType.Landed)
	self.velocity = Vector3.zero
	self.isDead = false
	self.isDashing = false
	self.isSliding = false
	self.dashAvailable = true
	self.yoyoCharges = 1
	self.onFloor = true
	self._yoyoRequested = false
	self._spawnGrace = self.tuning.spawnGrace
	if self.yoyo then
		self.yoyo:recallInstant()
	end
end

-- Meta alcanzada: se queda quieto e ignora peligros, pads y gravedad.
function Character.freeze(self: Character)
	self.frozen = true
	self.inputEnabled = false
	self:_clearActions()
	self.velocity = Vector3.zero
	self:_setAnchored(true)
end

function Character.unfreeze(self: Character)
	self.frozen = false
	self.inputEnabled = true
	self:_setAnchored(false)
end

function Character.destroy(self: Character)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.rig.hitbox:Destroy()
end

return Character
