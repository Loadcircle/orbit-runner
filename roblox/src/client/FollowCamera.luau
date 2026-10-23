--!strict
-- Cámara en tercera persona detrás del protagonista: port de scripts/player/follow_camera.gd.
-- La yaw la fija la ruta (CameraZones), no la velocidad, para que la entrada relativa a
-- la cámara sea predecible. El jugador puede girarla un poco (Q/R, stick derecho o
-- arrastre táctil) y vuelve sola. Cámara nativa en modo Scriptable, actualizada con
-- BindToRenderStep en la prioridad de cámara.
-- El FOV de Godot (Camera3D, keep_aspect = KEEP_HEIGHT) es vertical, igual que
-- Camera.FieldOfView en Roblox: se usa el mismo valor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Units = require(Shared:WaitForChild("Units"))
local InputRouter = require(script.Parent:WaitForChild("InputRouter"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local CONFIG = {
	distance = Units.studs(6.6),
	focusHeight = Units.studs(1.4),
	pitchDegrees = -17.0,
	baseFov = 70.0,
	speedFov = 7.0,
	yawFollow = 3.0,
	horizontalFollow = 11.0,
	verticalFollowGround = 7.0,
	verticalFollowAir = 2.6,
	manualSpeed = 2.2,
	manualLimit = math.rad(75.0),
	manualReturnDelay = 1.2,
	focusBelow = Units.studs(1.6),
	focusAbove = Units.studs(1.2),
	lookAheadFactor = 0.16, -- s
	lookAheadMin = Units.studs(-0.6),
	lookAheadMax = Units.studs(2.0),
	fallPitchFactor = 0.5 / Units.K, -- grados por stud/s de caída (0.5 °/(m/s))
	fallPitchMax = 9.0,
	speedFovRange = Units.studs(7.0),
	springMargin = Units.studs(0.2),
	shakeDecay = 2.5,
	shakeOffset = Units.studs(0.25),
	touchRadiansPerPixel = 0.006,
}

local RENDER_STEP_NAME = "OrbitRunnerFollowCamera"

type Target = {
	feet: (any) -> Vector3,
	velocity: Vector3,
	onFloor: boolean,
	horizontalSpeed: (any) -> number,
	tuning: { runSpeed: number },
	rig: { character: Model },
}

local FollowCamera = {}
FollowCamera.__index = FollowCamera

export type FollowCamera = typeof(setmetatable({} :: {
	target: Target?,
	targetYaw: number,
	camera: Camera,
	_yaw: number,
	_manual: number,
	_manualIdle: number,
	_focus: Vector3,
	_lookAhead: number,
	_shake: number,
	_pitch: number,
	_fov: number,
	_params: RaycastParams,
	_active: boolean,
}, FollowCamera))

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpAngle(from: number, to: number, weight: number): number
	local diff = (to - from + math.pi) % (2 * math.pi) - math.pi
	return from + diff * weight
end

local function follow(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

function FollowCamera.new(): FollowCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local self = setmetatable({
		target = nil,
		targetYaw = 0,
		camera = Workspace.CurrentCamera,
		_yaw = 0,
		_manual = 0,
		_manualIdle = 0,
		_focus = Vector3.zero,
		_lookAhead = 0,
		_shake = 0,
		_pitch = math.rad(CONFIG.pitchDegrees),
		_fov = CONFIG.baseFov,
		_params = params,
		_active = false,
	}, FollowCamera)
	return self
end

function FollowCamera.setTarget(self: FollowCamera, target: Target?)
	self.target = target
	self._params.FilterDescendantsInstances = if target then { target.rig.character } else {}
end

function FollowCamera.start(self: FollowCamera)
	if self._active then
		return
	end
	self._active = true
	self.camera = Workspace.CurrentCamera
	self.camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, function(dt: number)
		self:update(dt)
	end)
end

function FollowCamera.stop(self: FollowCamera)
	if not self._active then
		return
	end
	self._active = false
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
end

function FollowCamera.getYaw(self: FollowCamera): number
	return self._yaw
end

-- Coloca la cámara detrás del objetivo al instante (aparición / reaparición).
function FollowCamera.snap(self: FollowCamera, yaw: number)
	self.targetYaw = yaw
	self._yaw = yaw
	self._manual = 0
	if self.target then
		self._focus = self.target:feet() + Vector3.new(0, CONFIG.focusHeight, 0)
	end
	self._lookAhead = 0
	self:_apply()
end

function FollowCamera.addManualYaw(self: FollowCamera, radians: number)
	local sensitivity = Settings.get("cameraSensitivity") :: number
	self._manual = math.clamp(self._manual + radians * sensitivity, -CONFIG.manualLimit, CONFIG.manualLimit)
	self._manualIdle = 0
end

-- Arrastre táctil en píxeles (touch_controls.gd → camera_drag).
function FollowCamera.addTouchDrag(self: FollowCamera, pixels: number)
	self:addManualYaw(-pixels * CONFIG.touchRadiansPerPixel)
end

function FollowCamera.shake(self: FollowCamera, strength: number)
	if Settings.get("screenShake") then
		self._shake = math.max(self._shake, strength)
	end
end

function FollowCamera.update(self: FollowCamera, dt: number)
	local target = self.target
	if target == nil then
		return
	end
	local axis = InputRouter.getCameraAxis()
	if math.abs(axis) > 0.05 then
		self:addManualYaw(-axis * CONFIG.manualSpeed * dt)
	else
		self._manualIdle += dt
		if self._manualIdle > CONFIG.manualReturnDelay then
			self._manual = lerp(self._manual, 0, follow(2.0, dt))
		end
	end
	self._yaw = lerpAngle(self._yaw, self.targetYaw + self._manual, follow(CONFIG.yawFollow, dt))

	local desired = target:feet() + Vector3.new(0, CONFIG.focusHeight, 0)
	local horizontal = follow(CONFIG.horizontalFollow, dt)
	local vertical = follow(if target.onFloor then CONFIG.verticalFollowGround else CONFIG.verticalFollowAir, dt)
	local focusY = lerp(self._focus.Y, desired.Y, vertical)
	-- Mantiene al protagonista dentro de una franja vertical cómoda en los saltos grandes.
	focusY = math.clamp(focusY, desired.Y - CONFIG.focusBelow, desired.Y + CONFIG.focusAbove)
	self._focus = Vector3.new(lerp(self._focus.X, desired.X, horizontal), focusY, lerp(self._focus.Z, desired.Z, horizontal))

	local forward = Vector3.new(-math.sin(self._yaw), 0, -math.cos(self._yaw))
	local velocity = target.velocity
	local along = Vector3.new(velocity.X, 0, velocity.Z):Dot(forward)
	local lookTarget = math.clamp(along * CONFIG.lookAheadFactor, CONFIG.lookAheadMin, CONFIG.lookAheadMax)
	self._lookAhead = lerp(self._lookAhead, lookTarget, follow(2.5, dt))

	local speed = target:horizontalSpeed()
	local fovTarget = CONFIG.baseFov
		+ CONFIG.speedFov * math.clamp((speed - target.tuning.runSpeed) / CONFIG.speedFovRange, 0, 1)
	self._fov = lerp(self._fov, fovTarget, follow(4.0, dt))
	-- Mira un poco más abajo al caer para que los aterrizajes se vean.
	local pitch = CONFIG.pitchDegrees - math.clamp(-velocity.Y * CONFIG.fallPitchFactor, 0, CONFIG.fallPitchMax)
	self._pitch = lerpAngle(self._pitch, math.rad(pitch), follow(4.0, dt))
	self._shake = math.max(self._shake - dt * CONFIG.shakeDecay, 0)
	self:_apply()
end

function FollowCamera._apply(self: FollowCamera)
	local forward = Vector3.new(-math.sin(self._yaw), 0, -math.cos(self._yaw))
	local pivot = self._focus + forward * self._lookAhead
	local armBasis = CFrame.Angles(0, self._yaw, 0) * CFrame.Angles(self._pitch, 0, 0)
	local armDirection = armBasis:VectorToWorldSpace(Vector3.new(0, 0, 1))
	-- Brazo con resorte: se acorta si algo sólido queda entre el foco y la cámara.
	local length = CONFIG.distance
	local hit = Workspace:Raycast(pivot, armDirection * CONFIG.distance, self._params)
	if hit then
		length = math.max(hit.Distance - CONFIG.springMargin, 0)
	end
	local cameraFrame = CFrame.new(pivot) * armBasis * CFrame.new(0, 0, length)
	if self._shake > 0 then
		local amount = self._shake * CONFIG.shakeOffset
		cameraFrame *= CFrame.new((math.random() * 2 - 1) * amount, (math.random() * 2 - 1) * amount, 0)
	end
	self.camera.CFrame = cameraFrame
	self.camera.Focus = CFrame.new(pivot)
	self.camera.FieldOfView = self._fov
end

return FollowCamera
