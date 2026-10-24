--!strict
-- Punto de entrada del servidor: arranca los servicios de ServerScriptService/Services.

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")
local AvatarService = require(Services:WaitForChild("AvatarService"))
local HubService = require(Services:WaitForChild("HubService"))
local ProgressService = require(Services:WaitForChild("ProgressService"))

AvatarService.start()
HubService.start()
ProgressService.start()

print("[OrbitRunner] Servidor iniciado")
