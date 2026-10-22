--!strict
-- Punto de entrada del cliente. Arranca los módulos de StarterPlayerScripts/Client
-- a medida que se implementan (H1+). Por ahora solo apaga los controles por defecto.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")

-- StarterPlayer ya pone DevComputer/DevTouchMovementMode = Scriptable (default.project.json),
-- lo que oculta el joystick táctil de Roblox. Esto cubre también el mando.
local playerModule = require(playerScripts:WaitForChild("PlayerModule") :: any)
playerModule:GetControls():Disable()

-- La cámara por defecto se sustituye en H5: FollowCamera pone CameraType = Scriptable.

print("[OrbitRunner] Cliente iniciado; controles por defecto desactivados")
