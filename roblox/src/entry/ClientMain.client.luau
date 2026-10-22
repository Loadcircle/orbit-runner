--!strict
-- Punto de entrada del cliente. Arranca los módulos de StarterPlayerScripts/Client
-- a medida que se implementan (H1+). Por ahora solo apaga los controles por defecto.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local player = Players.LocalPlayer

-- StarterPlayer ya pone DevComputer/DevTouchMovementMode = Scriptable (default.project.json),
-- lo que bloquea el movimiento y el salto de Roblox y oculta su joystick táctil.
-- Además se apaga el ControlModule por si el mando u otra vía siguen activos.
local function disableDefaultControls()
	-- PlayerModule actual: vive en StarterPlayer y expone ControlModule.Enabled.
	local modernModule = StarterPlayer:FindFirstChild("PlayerModule")
	if modernModule and modernModule:IsA("ModuleScript") then
		local api = require(modernModule) :: any
		if type(api.ControlModule) == "table" and api.ControlModule.Enabled ~= nil then
			api.ControlModule.Enabled = false
			return "StarterPlayer.PlayerModule"
		end
	end
	-- PlayerModule antiguo: se copia a PlayerScripts y expone GetControls().
	local legacyModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
	if legacyModule and legacyModule:IsA("ModuleScript") then
		(require(legacyModule) :: any):GetControls():Disable()
		return "PlayerScripts.PlayerModule"
	end
	return "ninguno (solo Scriptable)"
end

local source = disableDefaultControls()

-- La cámara por defecto se sustituye en H5: FollowCamera pone CameraType = Scriptable.

print("[OrbitRunner] Cliente iniciado; controles por defecto desactivados vía " .. source)
