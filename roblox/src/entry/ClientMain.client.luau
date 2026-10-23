--!strict
-- Punto de entrada del cliente: desactiva los controles por defecto, arranca el
-- InputRouter y crea el controlador del personaje en cada aparición. El orden de
-- cada fotograma (PreSimulation) es: estado del jugador → props → lógica del jugador.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Client = script.Parent:WaitForChild("Client")
local AnimationDriver = require(Client:WaitForChild("AnimationDriver"))
local DebugProbe = require(Client:WaitForChild("DebugProbe"))
local InputRouter = require(Client:WaitForChild("InputRouter"))
local PlayerController = require(Client:WaitForChild("PlayerController"))

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

local controller: PlayerController.PlayerController? = nil
local animation: AnimationDriver.AnimationDriver? = nil

local source = disableDefaultControls()
InputRouter.start()
DebugProbe.start()
DebugProbe.provide("player", function()
	local c = controller
	if not c then
		return nil
	end
	local feet = c:feet()
	return {
		feet = { feet.X, feet.Y, feet.Z },
		velocity = { c.velocity.X, c.velocity.Y, c.velocity.Z },
		onFloor = c.onFloor,
		sliding = c.isSliding,
		dashing = c.isDashing,
		dead = c.isDead,
		dashAvailable = c.dashAvailable,
		yoyoCharges = c.yoyoCharges,
		facing = { c.facing.X, c.facing.Z },
		move = { InputRouter.getMove().X, InputRouter.getMove().Y },
	}
end)
DebugProbe.command("teleport", function(x: number, y: number, z: number)
	if controller then
		controller:respawnAt(Vector3.new(x, y, z), Vector3.new(0, 0, -1))
	end
	return true
end)

local function onCharacterAdded(character: Model)
	if controller then
		controller:destroy()
	end
	if animation then
		animation:destroy()
	end
	controller = PlayerController.new(character)
	animation = AnimationDriver.new(controller :: any)
	local current = controller :: PlayerController.PlayerController
	current.getCameraYaw = function()
		local look = workspace.CurrentCamera.CFrame.LookVector
		return math.atan2(-look.X, -look.Z)
	end
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

RunService.PreSimulation:Connect(function(dt: number)
	local current = controller
	if not current or not current.rig.root.Parent then
		return
	end
	current:beginStep()
	current:step(dt)
end)

RunService.RenderStepped:Connect(function(dt: number)
	if animation then
		animation:update(dt)
	end
end)

print("[OrbitRunner] Cliente iniciado; controles por defecto desactivados vía " .. source)
