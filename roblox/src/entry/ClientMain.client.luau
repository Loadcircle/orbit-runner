--!strict
-- Punto de entrada del cliente: arranca la capa de juego (Client/Game). El movimiento, la
-- cámara y los controles táctiles son los nativos de Roblox con la plantilla Platformer
-- (ReplicatedStorage.Platformer, R14); Game solo los apaga en menús, pausa y meta.

local Client = script.Parent:WaitForChild("Client")
local Game = require(Client:WaitForChild("Game"))

Game.start()

print("[OrbitRunner] Cliente iniciado sobre la plantilla Platformer")
