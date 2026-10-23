--!strict
-- Punto de entrada del servidor: arranca los servicios de ServerScriptService/Services.

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")
local AvatarService = require(Services:WaitForChild("AvatarService"))
local ProgressService = require(Services:WaitForChild("ProgressService"))

AvatarService.start()
ProgressService.start()

print("[OrbitRunner] Servidor iniciado")
