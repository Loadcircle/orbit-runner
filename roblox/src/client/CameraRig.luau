--!strict
-- Cámara nativa de Roblox (Classic: orbitar con ratón, dedo o stick; zoom; evita paredes)
-- con el suavizado de la plantilla Platformer (SmoothCameraScript). Este módulo solo
-- añade lo que pide la sesión de nivel: orientarla detrás del jugador al empezar y al
-- reaparecer (snap), recordar la yaw de las zonas de cámara y una sacudida al morir.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraRig = {}
CameraRig.__index = CameraRig

local SNAP_PITCH = math.rad(-18)

export type CameraRig = typeof(setmetatable({} :: {
	target: any?,
	targetYaw: number,
	_shake: number,
	_shakeTime: number,
	_bound: boolean,
}, CameraRig))

function CameraRig.new(): CameraRig
	return setmetatable({
		target = nil,
		targetYaw = 0,
		_shake = 0,
		_shakeTime = 0,
		_bound = false,
	}, CameraRig)
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
end

-- Las zonas de cámara de los niveles guardan su yaw para orientar las reapariciones; la
-- cámara la controla el jugador.
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
