--!strict
-- Controlador del protagonista: port de orbit_runner_game/scripts/player/player.gd.
-- Lee las acciones compartidas (InputRouter), mueve relativo a la yaw de la cámara y
-- no hay auto-run. Sobre el controlador nativo (CharacterRig, decisión R4):
--   · en suelo, el GroundController acelera/frena con los tiempos de Godot;
--   · en el aire, la velocidad horizontal se integra aquí (move_toward de Godot) y la
--     vertical con la gravedad asimétrica del VectorForce.
-- El orden de cada fotograma lo marca quien lo use: beginStep() → fuerzas externas
-- (props) → step(dt), igual que en Godot los props se procesan antes que el jugador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementTuning = require(Shared:WaitForChild("MovementTuning"))
local Signal = require(Shared:WaitForChild("Signal"))
local Units = require(Shared:WaitForChild("Units"))
local CharacterRig = require(script:WaitForChild("CharacterRig"))
local InputRouter = require(script.Parent:WaitForChild("InputRouter"))

local Tuning = MovementTuning.scaled()
local GROUND_TIME_CALIBRATION = 0.915 -- ver CharacterRig
local AIR_LOCK = 0.1 -- s sin detectar suelo tras un salto o rebote
local BOOST_GROUND_FACTOR = 2.5
local MIN_FACING_SPEED = Units.studs(0.6)

local PlayerController = {}
PlayerController.__index = PlayerController

export type YoyoLike = {
	isReady: (any) -> boolean,
	throw: (any, from: Vector3, to: Vector3) -> (),
	deployUnder: (any, feet: Vector3) -> (),
	recallInstant: (any) -> (),
}

export type PlayerController = typeof(setmetatable({} :: {
	rig: CharacterRig.CharacterRig,
	tuning: MovementTuning.Tuning,
	inputEnabled: boolean,
	getCameraYaw: () -> number,
	yoyo: YoyoLike?,
	velocity: Vector3, -- relativa al suelo que se pisa (como velocity en Godot)
	onFloor: boolean,
	groundVelocity: Vector3,
	dashAvailable: boolean,
	yoyoCharges: number,
	isSliding: boolean,
	isDashing: boolean,
	isDead: boolean,
	frozen: boolean,
	bounceTimer: number,
	throwTimer: number,
	facing: Vector3,
	jumped: Signal.Signal<>,
	landed: Signal.Signal<number>,
	died: Signal.Signal<>,
	dashed: Signal.Signal<>,
	slid: Signal.Signal<>,
	bounced: Signal.Signal<string>,
	yoyoThrown: Signal.Signal<>,
	_coyote: number,
	_buffer: number,
	_slideTimer: number,
	_slideCooldown: number,
	_slideDir: Vector3,
	_slideSpeed: number,
	_dashTimer: number,
	_dashDir: Vector3,
	_jumpHeldCut: boolean,
	_boost: number,
	_wasOnFloor: boolean,
	_fallSpeed: number,
	_windFrames: number,
	_spawnGrace: number,
	_airLock: number,
	_velocityDirty: boolean,
}, PlayerController))

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function moveToward(from: Vector3, to: Vector3, delta: number): Vector3
	local diff = to - from
	local length = diff.Magnitude
	if length <= delta or length < 1e-6 then
		return to
	end
	return from + diff / length * delta
end

local function moveTowardNumber(from: number, to: number, delta: number): number
	if math.abs(to - from) <= delta then
		return to
	end
	return from + math.sign(to - from) * delta
end

local function slerpFlat(from: Vector3, to: Vector3, weight: number): Vector3
	-- Interpolación esférica en el plano horizontal (los dos vectores son unitarios).
	local angleFrom = math.atan2(from.X, from.Z)
	local angleTo = math.atan2(to.X, to.Z)
	local diff = (angleTo - angleFrom + math.pi) % (2 * math.pi) - math.pi
	local angle = angleFrom + diff * weight
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

function PlayerController.new(character: Model): PlayerController
	local rig = CharacterRig.new(character)
	local self = setmetatable({
		rig = rig,
		tuning = Tuning,
		inputEnabled = true,
		getCameraYaw = function()
			return 0
		end,
		yoyo = nil,
		velocity = Vector3.zero,
		onFloor = true,
		groundVelocity = Vector3.zero,
		dashAvailable = true,
		yoyoCharges = 1,
		isSliding = false,
		isDashing = false,
		isDead = false,
		frozen = false,
		bounceTimer = 0,
		throwTimer = 0,
		facing = Vector3.new(0, 0, -1),
		jumped = Signal.new(),
		landed = Signal.new(),
		died = Signal.new(),
		dashed = Signal.new(),
		slid = Signal.new(),
		bounced = Signal.new(),
		yoyoThrown = Signal.new(),
		_coyote = 0,
		_buffer = 0,
		_slideTimer = 0,
		_slideCooldown = 0,
		_slideDir = Vector3.new(0, 0, -1),
		_slideSpeed = 0,
		_dashTimer = 0,
		_dashDir = Vector3.new(0, 0, -1),
		_jumpHeldCut = false,
		_boost = 0,
		_wasOnFloor = true,
		_fallSpeed = 0,
		_windFrames = 0,
		_spawnGrace = 0,
		_airLock = 0,
		_velocityDirty = false,
	}, PlayerController)
	return self
end

-- ------------------------------------------------------------------ fotograma

-- Lee el estado físico antes de que los props apliquen fuerzas externas.
function PlayerController.beginStep(self: PlayerController)
	local rig = self.rig
	if self.isDead or self.frozen then
		return
	end
	local hit = if self._airLock > 0 then nil else CharacterRig.probeGround(rig)
	local worldVelocity = rig.root.AssemblyLinearVelocity
	self.groundVelocity = if hit then hit.velocity else Vector3.zero
	-- Subiendo respecto al suelo (salto, rebote) no se cuenta como apoyado.
	local relative = worldVelocity - self.groundVelocity
	self.onFloor = hit ~= nil and relative.Y <= Units.studs(1.0)
	self.velocity = relative
	self._velocityDirty = false
end

function PlayerController.step(self: PlayerController, dt: number)
	local rig = self.rig
	if self.isDead or self.frozen then
		return
	end
	self._spawnGrace = math.max(self._spawnGrace - dt, 0)
	self._airLock = math.max(self._airLock - dt, 0)
	local onFloor = self.onFloor
	local jumpPressed = self:_pressed("jump")
	local actionPressed = self:_pressed("action")
	local yoyoPressed = self:_pressed("yoyo")

	self:_updateTimers(dt, onFloor, jumpPressed)
	if onFloor and not self._wasOnFloor then
		self:_onLanded()
	end
	local wish = self:_wishDirection()
	local h = flat(self.velocity)

	if self.isDashing then
		self:_processDash(dt)
	else
		h = self:_horizontal(h, wish, onFloor, dt)
		self.velocity = Vector3.new(h.X, self.velocity.Y, h.Z)
		self:_vertical(dt, onFloor)
		self:_handleActions(onFloor, h, wish, jumpPressed, actionPressed, yoyoPressed)
	end

	if not self.onFloor then
		self._fallSpeed = math.min(self._fallSpeed, self.velocity.Y)
	end
	self._wasOnFloor = self.onFloor
	self:_applyToRig(wish)
	self:_updateFacing(dt)
end

-- ------------------------------------------------------------------ entrada

function PlayerController._pressed(self: PlayerController, action: InputRouter.ActionName): boolean
	local pressed = InputRouter.consumePressed(action)
	return self.inputEnabled and pressed
end

function PlayerController._wishDirection(self: PlayerController): Vector3
	if not self.inputEnabled then
		return Vector3.zero
	end
	local move = InputRouter.getMove()
	-- Godot: Vector3(x, 0, -forward) rotado por la yaw de la cámara alrededor de Y.
	local local3 = Vector3.new(move.X, 0, -move.Y)
	return CFrame.Angles(0, self.getCameraYaw(), 0):VectorToWorldSpace(local3)
end

-- ------------------------------------------------------------------ movimiento

function PlayerController._updateTimers(self: PlayerController, dt: number, onFloor: boolean, jumpPressed: boolean)
	local t = self.tuning
	if onFloor then
		self._coyote = t.coyoteTime
		self.dashAvailable = true
		self.yoyoCharges = 1
		self.bounceTimer = 0
	else
		self._coyote -= dt
	end
	self._buffer = if jumpPressed then t.jumpBuffer else self._buffer - dt
	self._slideCooldown -= dt
	self.throwTimer -= dt
	self.bounceTimer = if self.velocity.Y > 0 then math.max(self.bounceTimer - dt, 0) else 0
	-- Los boosts duran en el aire (saltos largos con boost) y se apagan rápido en suelo.
	local decay = t.boostDecay * (if onFloor then BOOST_GROUND_FACTOR else 1)
	self._boost = moveTowardNumber(self._boost, 0, decay * dt)
	if self._windFrames > 0 then
		self._windFrames -= 1
	end
end

function PlayerController._horizontal(self: PlayerController, h: Vector3, wish: Vector3, onFloor: boolean, dt: number): Vector3
	local t = self.tuning
	local maxSpeed = t.runSpeed + self._boost
	if self.isSliding then
		self._slideTimer -= dt
		self._slideSpeed = math.max(self._slideSpeed - t.slideFriction * dt, t.runSpeed * t.slideSpeedFloor)
		-- Dirección ligeramente controlable mientras se desliza.
		if wish.Magnitude > 0.1 then
			self._slideDir = slerpFlat(self._slideDir, wish.Unit, math.clamp(t.slideSteering * dt, 0, 1))
		end
		if (self._slideTimer <= 0 or not onFloor) and CharacterRig.canStand(self.rig) then
			self:_endSlide()
		end
		return self._slideDir * self._slideSpeed
	end
	if onFloor then
		-- En suelo manda el GroundController (_applyToRig); aquí solo se predice el
		-- resultado para que las acciones de este fotograma vean la velocidad actual.
		return h
	end
	local hasInput = wish.Magnitude > 0.05
	local target = wish * maxSpeed
	local accel = if hasInput then t.airAcceleration else t.airDeceleration
	-- En el aire se conserva la inercia por encima de la velocidad de carrera.
	local speed = h.Magnitude
	if speed > maxSpeed then
		target = if hasInput then wish.Unit * speed else h
		if hasInput and h:Dot(wish) < 0 then
			target = wish * maxSpeed
		end
	end
	return moveToward(h, target, accel * dt)
end

function PlayerController._vertical(self: PlayerController, dt: number, onFloor: boolean)
	local t = self.tuning
	local vy = self.velocity.Y
	if self._jumpHeldCut and vy > 0 and not (self.inputEnabled and InputRouter.isDown("jump")) then
		vy *= t.jumpCut
		self._jumpHeldCut = false
		self._velocityDirty = true
	end
	if vy <= 0 then
		self._jumpHeldCut = false
	end
	if not onFloor and vy < -t.maxFallSpeed then
		vy = -t.maxFallSpeed
		self._velocityDirty = true
	end
	self.velocity = Vector3.new(self.velocity.X, vy, self.velocity.Z)
end

function PlayerController._gravity(self: PlayerController): number
	local t = self.tuning
	if self._windFrames > 0 then
		return t.gravityUp * 0.5
	end
	return if self.velocity.Y > 0 then t.gravityUp else t.gravityDown
end

function PlayerController._handleActions(
	self: PlayerController,
	onFloor: boolean,
	h: Vector3,
	wish: Vector3,
	_jumpPressed: boolean,
	actionPressed: boolean,
	yoyoPressed: boolean
)
	if self._buffer > 0 and self._coyote > 0 then
		if self.isSliding and CharacterRig.canStand(self.rig) then
			self:_longJump()
		elseif not self.isSliding then
			self:_jump()
		end
	end
	if actionPressed then
		if onFloor and not self.isSliding and h.Magnitude > self.tuning.slideMinSpeed and self._slideCooldown <= 0 then
			self:_startSlide(h)
		elseif not onFloor and self.dashAvailable then
			self:_startDash(wish)
		end
	end
	if yoyoPressed then
		self:_tryThrowYoyo(self.onFloor, flat(self.velocity))
	end
end

function PlayerController._leaveGround(self: PlayerController)
	self.onFloor = false
	self._airLock = AIR_LOCK
end

function PlayerController._jump(self: PlayerController)
	self.velocity = Vector3.new(self.velocity.X, self.tuning.jumpVelocity, self.velocity.Z)
	self._velocityDirty = true
	self._buffer = 0
	self._coyote = 0
	self._jumpHeldCut = true
	self:_leaveGround()
	self.jumped:Fire()
end

function PlayerController._longJump(self: PlayerController)
	self:_endSlide()
	local t = self.tuning
	local dir = self._slideDir
	self.velocity = Vector3.new(dir.X * t.longJumpSpeed, t.longJumpVelocity, dir.Z * t.longJumpSpeed)
	self._velocityDirty = true
	self._buffer = 0
	self._coyote = 0
	self._jumpHeldCut = false
	self:_leaveGround()
	self.jumped:Fire()
end

function PlayerController._startSlide(self: PlayerController, h: Vector3)
	self.isSliding = true
	self._slideTimer = self.tuning.slideDuration
	self._slideDir = h.Unit
	self._slideSpeed = math.max(h.Magnitude, self.tuning.slideSpeed)
	-- El arranque es instantáneo, como en Godot; luego el GroundController lo sigue.
	self.velocity = Vector3.new(self._slideDir.X * self._slideSpeed, self.velocity.Y, self._slideDir.Z * self._slideSpeed)
	self._velocityDirty = true
	CharacterRig.setHitboxHeight(self.rig, self.tuning.slideHeight)
	self.slid:Fire()
end

function PlayerController._endSlide(self: PlayerController)
	if not self.isSliding then
		return
	end
	self.isSliding = false
	self._slideCooldown = self.tuning.slideCooldown
	CharacterRig.setHitboxHeight(self.rig, self.tuning.standHeight)
end

function PlayerController._startDash(self: PlayerController, wish: Vector3)
	self.dashAvailable = false
	self.isDashing = true
	self._dashTimer = self.tuning.dashDuration
	local dir = if wish.Magnitude > 0.2 then wish.Unit else self.facing
	self._dashDir = flat(dir).Unit
	self.dashed:Fire()
end

function PlayerController._processDash(self: PlayerController, dt: number)
	local t = self.tuning
	self._dashTimer -= dt
	self.velocity = self._dashDir * t.dashSpeed + Vector3.new(0, t.dashLift, 0)
	if self._dashTimer <= 0 then
		self.isDashing = false
		self.velocity = self._dashDir * t.dashExitSpeed
	end
	self._velocityDirty = true
end

function PlayerController._tryThrowYoyo(self: PlayerController, onFloor: boolean, h: Vector3)
	local yoyo = self.yoyo
	if yoyo == nil or not yoyo:isReady() or (not onFloor and self.yoyoCharges <= 0) then
		return
	end
	local t = self.tuning
	local feet = CharacterRig.feet(self.rig)
	local up = Vector3.yAxis
	local origin = feet + up * Units.studs(1.0)
	local target: Vector3
	if onFloor then
		target = feet + self.facing * t.yoyoGroundDistance + up * Units.studs(0.1)
		-- Se detiene delante de las paredes.
		local aim = target + up * Units.studs(0.5)
		local hit = CharacterRig.raycast(self.rig, origin, aim - origin)
		if hit then
			target = hit.Position - self.facing * Units.studs(1.3) - up * Units.studs(0.5)
		end
	else
		self.yoyoCharges -= 1
		if self.velocity.Y < -t.yoyoFallingSpeed then
			-- Ya cae: un disco lanzado quedaría arriba. Se despliega bajo los pies y
			-- funciona como un salto aéreo.
			yoyo:deployUnder(feet - up * Units.studs(0.1))
			self.throwTimer = 0.3
			self.yoyoThrown:Fire()
			return
		end
		target = feet + h * t.yoyoAirLead - up * t.yoyoAirDrop
	end
	yoyo:throw(origin, target)
	self.throwTimer = 0.3
	self.yoyoThrown:Fire()
end

function PlayerController._onLanded(self: PlayerController)
	self.isDashing = false
	self.landed:Fire(-self._fallSpeed)
	self._fallSpeed = 0
end

function PlayerController._updateFacing(self: PlayerController, dt: number)
	local h = flat(self.velocity)
	if self.isSliding then
		h = self._slideDir
	end
	if h.Magnitude > MIN_FACING_SPEED then
		local target = h.Unit
		if self.facing:Dot(target) > 0.9995 then
			self.facing = target
		else
			self.facing = slerpFlat(self.facing, target, math.clamp(self.tuning.rotationSpeed * dt, 0, 1))
		end
	end
	if self.facing.Magnitude < 0.5 then
		self.facing = Vector3.new(0, 0, -1)
	end
	self.rig.manager.FacingDirection = self.facing
end

-- Traslada el estado al controlador nativo.
function PlayerController._applyToRig(self: PlayerController, wish: Vector3)
	local rig = self.rig
	local t = self.tuning
	local manager = rig.manager
	local grounded = self.onFloor and not self.isDashing and self._airLock <= 0
	if grounded then
		manager.ActiveController = rig.ground
		CharacterRig.setGravity(rig, nil)
		local ground = rig.ground
		if self.isSliding then
			manager.MovingDirection = self._slideDir
			manager.BaseMoveSpeed = self._slideSpeed
			ground.AccelerationTime = 0
			ground.DecelerationTime = 0
		else
			local maxSpeed = t.runSpeed + self._boost
			local amount = math.min(wish.Magnitude, 1)
			local h = flat(self.velocity)
			if amount > 0.05 then
				local reversing = h:Dot(wish) < 0
				local accel = if reversing then t.turnAcceleration else t.groundAcceleration
				manager.MovingDirection = wish.Unit
				manager.BaseMoveSpeed = maxSpeed * amount
				ground.AccelerationTime = manager.BaseMoveSpeed / accel * GROUND_TIME_CALIBRATION
				ground.DecelerationTime = manager.BaseMoveSpeed
					/ (if reversing then t.turnAcceleration else t.groundDeceleration)
					* GROUND_TIME_CALIBRATION
			else
				manager.MovingDirection = Vector3.zero
				manager.BaseMoveSpeed = maxSpeed
				ground.DecelerationTime = maxSpeed / t.groundDeceleration * GROUND_TIME_CALIBRATION
			end
		end
	else
		manager.ActiveController = rig.air
		manager.MovingDirection = Vector3.zero
		CharacterRig.setGravity(rig, if self.isDashing then 0 else self:_gravity())
		-- La horizontal del aire se integra en _horizontal y se escribe siempre.
		self._velocityDirty = true
	end
	if self._velocityDirty then
		rig.root.AssemblyLinearVelocity = self.velocity + (if grounded then self.groundVelocity else Vector3.zero)
		self._velocityDirty = false
	end
end

-- ------------------------------------------------------------------ fuerzas externas

-- Lanzamiento vertical de trampolines y del disco. Restaura las acciones aéreas.
function PlayerController.bounce(self: PlayerController, verticalSpeed: number, source: string)
	if self.isDead or self.frozen or self:isSpawnProtected() then
		return
	end
	self:_endSlide()
	self.isDashing = false
	self.velocity = Vector3.new(self.velocity.X, verticalSpeed, self.velocity.Z)
	self._velocityDirty = true
	self.dashAvailable = true
	if source ~= "yoyo" then
		self.yoyoCharges = 1
	end
	self._coyote = 0
	self._jumpHeldCut = false
	self.bounceTimer = 0.6
	self:_leaveGround()
	self.bounced:Fire(source)
end

-- Boost pads: empuja en `direction` y sube el límite de velocidad un momento.
function PlayerController.applyBoost(self: PlayerController, direction: Vector3, speed: number)
	if self.frozen then
		return
	end
	local dir = flat(direction).Unit
	self._boost = math.max(self._boost, speed - self.tuning.runSpeed)
	local along = flat(self.velocity):Dot(dir)
	local add = dir * math.max(speed - along, 0)
	self.velocity += add
	self._velocityDirty = true
	if self.isSliding then
		self._slideSpeed = math.max(self._slideSpeed, speed)
	end
end

-- Columnas de viento: se llama en cada fotograma mientras se está dentro.
function PlayerController.applyWind(self: PlayerController, lift: number, maxUpSpeed: number, dt: number)
	if self.frozen then
		return
	end
	self._windFrames = 2
	self.dashAvailable = true
	-- El arrastre dentro de la corriente mantiene al jugador en la columna.
	local drag = math.clamp(1 - 2.8 * dt, 0, 1)
	local vy = self.velocity.Y
	if vy < maxUpSpeed then
		vy = math.min(vy + lift * dt, maxUpSpeed)
	end
	self.velocity = Vector3.new(self.velocity.X * drag, vy, self.velocity.Z * drag)
	self._velocityDirty = true
	self._jumpHeldCut = false
	if vy > Units.studs(1.0) then
		self:_leaveGround()
	end
end

function PlayerController.isSpawnProtected(self: PlayerController): boolean
	return self._spawnGrace > 0
end

function PlayerController.hurt(self: PlayerController)
	if self.isDead or self.frozen or self:isSpawnProtected() then
		return
	end
	self.isDead = true
	self:_endSlide()
	self.isDashing = false
	self.velocity = Vector3.zero
	CharacterRig.setAnchored(self.rig, true)
	self.died:Fire()
end

-- Reaparece con los pies en `feet` mirando a `facing`.
function PlayerController.respawnAt(self: PlayerController, feet: Vector3, facing: Vector3)
	local flatFacing = flat(facing)
	self.facing = if flatFacing.Magnitude > 0.1 then flatFacing.Unit else Vector3.new(0, 0, -1)
	CharacterRig.setAnchored(self.rig, false)
	CharacterRig.placeAt(self.rig, feet, self.facing)
	self.velocity = Vector3.zero
	self.isDead = false
	self.isDashing = false
	self:_endSlide()
	self.dashAvailable = true
	self.yoyoCharges = 1
	self._boost = 0
	self._buffer = 0
	self._wasOnFloor = true
	self.onFloor = true
	self._airLock = 0
	self._spawnGrace = self.tuning.spawnGrace
	InputRouter.clearPressed()
	if self.yoyo then
		self.yoyo:recallInstant()
	end
end

-- Meta alcanzada: se queda quieto e ignora peligros, pads y gravedad.
function PlayerController.freeze(self: PlayerController)
	self.frozen = true
	self.inputEnabled = false
	self:_endSlide()
	self.isDashing = false
	self.velocity = Vector3.zero
	CharacterRig.setAnchored(self.rig, true)
end

function PlayerController.unfreeze(self: PlayerController)
	self.frozen = false
	self.inputEnabled = true
	CharacterRig.setAnchored(self.rig, false)
end

function PlayerController.horizontalSpeed(self: PlayerController): number
	return flat(self.velocity).Magnitude
end

function PlayerController.feet(self: PlayerController): Vector3
	return CharacterRig.feet(self.rig)
end

function PlayerController.destroy(self: PlayerController)
	self.rig.manager:Destroy()
	self.rig.gravityForce:Destroy()
	self.rig.hitbox:Destroy()
end

return PlayerController
