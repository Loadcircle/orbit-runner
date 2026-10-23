--!strict
-- Cámara nativa de Roblox (Classic: orbitar con ratón, dedo o stick; zoom; evita paredes)
-- con el suavizado de la plantilla Platformer (SmoothCameraScript). Este módulo solo
-- añade lo que pide la sesión de nivel: orientarla detrás del jugador al empezar y al
-- reaparecer (snap), una asistencia de yaw y una sacudida al morir.
-- Asistencia (follow_camera.gd de Godot): en un nivel, mientras el jugador corre, la
-- cámara gira poco a poco hacia la yaw de la zona de cámara actual (la dirección del
-- recorrido). Si el jugador la gira a mano, la asistencia espera MANUAL_RETURN_DELAY sin
-- tocarla; al entrar en una zona con otra dirección (un cruce) vuelve a corregir.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraRig = {}
CameraRig.__index = CameraRig

local SNAP_PITCH = math.rad(-18)
local ASSIST_BIND = "OrbitRunnerCameraAssist"
local ASSIST_RATE = 2.0 -- 1/s (Godot: vuelta tras giro manual a 2.0, seguimiento a 3.0)
local MANUAL_RETURN_DELAY = 1.2 -- s sin girar a mano antes de corregir (Godot: 1.2)
local MANUAL_THRESHOLD = math.rad(0.3) -- giro por fotograma que se considera manual
local MIN_ASSIST_SPEED = 4 -- studs/s: parado se puede mirar alrededor libremente

export type CameraRig = typeof(setmetatable({} :: {
	target: any?,
	targetYaw: number,
	_shake: number,
	_shakeTime: number,
	_bound: boolean,
	_assist: boolean,
	_lastYaw: number?,
	_manualIdle: number,
}, CameraRig))

function CameraRig.new(): CameraRig
	return setmetatable({
		target = nil,
		targetYaw = 0,
		_shake = 0,
		_shakeTime = 0,
		_bound = false,
		_assist = false,
		_lastYaw = nil,
		_manualIdle = MANUAL_RETURN_DELAY,
	}, CameraRig)
end

local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

-- Activa o apaga la asistencia de yaw (la sesión de nivel la enciende; en el vestíbulo
-- la cámara queda libre del todo).
function CameraRig.setAssist(self: CameraRig, enabled: boolean)
	if self._assist == enabled then
		return
	end
	self._assist = enabled
	self._lastYaw = nil
	if not enabled then
		RunService:UnbindFromRenderStep(ASSIST_BIND)
		return
	end
	-- Después de la cámara nativa (Camera) y junto al suavizado de la plantilla (Camera + 1).
	RunService:BindToRenderStep(ASSIST_BIND, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		self:_assistStep(dt)
	end)
end

-- Nueva dirección del recorrido (zona de cámara): en un cruce se corrige ya, aunque se
-- haya girado a mano hace poco.
function CameraRig.setTargetYaw(self: CameraRig, yaw: number)
	if math.abs(angleDelta(self.targetYaw, yaw)) > math.rad(10) then
		self._manualIdle = MANUAL_RETURN_DELAY
	end
	self.targetYaw = yaw
end

function CameraRig._assistStep(self: CameraRig, dt: number)
	local target = self.target
	local camera = Workspace.CurrentCamera
	if not target or camera.CameraType ~= Enum.CameraType.Custom then
		self._lastYaw = nil
		return
	end
	local yaw = self:getYaw()
	-- Lo que giró la cámara desde el último fotograma sin la asistencia es giro manual.
	if self._lastYaw and math.abs(angleDelta(self._lastYaw, yaw)) > MANUAL_THRESHOLD then
		self._manualIdle = 0
	else
		self._manualIdle += dt
	end
	local root: BasePart = target.rig.root
	local velocity = root.AssemblyLinearVelocity
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MIN_ASSIST_SPEED
	if moving and self._manualIdle >= MANUAL_RETURN_DELAY and not target.frozen and not target.isDead then
		local step = angleDelta(yaw, self.targetYaw) * (1 - math.exp(-ASSIST_RATE * dt))
		if math.abs(step) > 1e-4 then
			local pivot = root.Position
			camera.CFrame = CFrame.new(pivot) * CFrame.Angles(0, step, 0) * CFrame.new(-pivot) * camera.CFrame
			yaw += step
		end
	end
	self._lastYaw = yaw
end

function CameraRig.setTarget(self: CameraRig, target: any)
	self.target = target
end

-- Yaw actual de la cámara (radianes; 0 = mirando hacia −Z).
function CameraRig.getYaw(_self: CameraRig): number
	local look = Workspace.CurrentCamera.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- Coloca la cámara detrás del jugador mirando con `yaw`. La cámara Classic parte de su
-- CFrame actual en el siguiente fotograma, así que basta con fijarlo una vez.
function CameraRig.snap(self: CameraRig, yaw: number)
	self.targetYaw = yaw
	local target = self.target
	local camera = Workspace.CurrentCamera
	if not target or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local focus = target.rig.root.Position
	local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	if distance < 1 then
		distance = 16
	end
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(SNAP_PITCH, 0, 0)
	camera.CFrame = CFrame.new(focus) * rotation * CFrame.new(0, 0, distance)
	self._lastYaw = yaw
	self._manualIdle = MANUAL_RETURN_DELAY
end

function CameraRig.addTouchDrag(_self: CameraRig, _pixels: number) end

function CameraRig.shake(self: CameraRig, amount: number)
	self._shake = amount
	self._shakeTime = 0.25
	if self._bound then
		return
	end
	self._bound = true
	RunService:BindToRenderStep("OrbitRunnerCameraShake", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		if self._shakeTime <= 0 then
			RunService:UnbindFromRenderStep("OrbitRunnerCameraShake")
			self._bound = false
			return
		end
		self._shakeTime -= dt
		local strength = self._shake * math.max(self._shakeTime / 0.25, 0)
		local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 2 * strength
		local camera = Workspace.CurrentCamera
		camera.CFrame *= CFrame.new(offset)
	end)
end

return CameraRig
