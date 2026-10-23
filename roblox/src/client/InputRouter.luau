--!strict
-- Entrada propia del juego. Correr, saltar, doble salto, dash y rodar los leen los
-- controles por defecto de Roblox y la plantilla Platformer (joystick y botón de salto
-- táctiles nativos, teclado y mando). Aquí solo viven las acciones que añade Orbit Runner:
--   · yo-yo: con el ActionManager de la plantilla (E / Y del mando / botón táctil), que
--     lo muestra junto a "Dash/Roll" con el icono del dispositivo en uso;
--   · pausa: Input Action System nativo (P / Start). En táctil, el botón del HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

export type ActionName = "yoyo" | "pause"

local InputRouter = {}

local YOYO_ACTION = "Yo-yo"

local listeners: { [string]: { (() -> ()) } } = {}
local started = false

InputRouter.preferredDevice = "keyboard" :: "keyboard" | "gamepad" | "touch"
InputRouter.deviceChanged = Instance.new("BindableEvent")

local function fire(name: ActionName)
	for _, callback in listeners[name] or {} do
		task.spawn(callback)
	end
end

local function updatePreferredDevice()
	local preferred = UserInputService.PreferredInput
	local device = if preferred == Enum.PreferredInput.Touch
		then "touch"
		elseif preferred == Enum.PreferredInput.Gamepad then "gamepad"
		else "keyboard"
	if device ~= InputRouter.preferredDevice then
		InputRouter.preferredDevice = device :: any
		InputRouter.deviceChanged:Fire(device)
	end
end

function InputRouter.start()
	if started then
		return
	end
	started = true
	local context = Instance.new("InputContext")
	context.Name = "OrbitRunner"
	context.Sink = false
	local pause = Instance.new("InputAction")
	pause.Name = "pause"
	pause.Type = Enum.InputActionType.Bool
	pause.Parent = context
	for _, key in { Enum.KeyCode.P, Enum.KeyCode.ButtonStart } do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = pause
	end
	pause.Pressed:Connect(function()
		fire("pause")
	end)
	context.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")

	local ActionManager = require(ReplicatedStorage:WaitForChild("Utility"):WaitForChild("ActionManager")) :: any
	ActionManager.bindAction(YOYO_ACTION, function(_name: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			fire("yoyo")
		end
	end, Enum.KeyCode.E, Enum.KeyCode.ButtonY, 2)

	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updatePreferredDevice)
	updatePreferredDevice()
end

function InputRouter.onPressed(name: ActionName, callback: () -> ()): { Disconnect: (any) -> () }
	listeners[name] = listeners[name] or {}
	local list = listeners[name]
	table.insert(list, callback)
	return {
		Disconnect = function()
			local index = table.find(list, callback)
			if index then
				table.remove(list, index)
			end
		end,
	}
end

-- Compatibilidad: ya no hay cola de pulsaciones propia.
function InputRouter.clearPressed() end

-- Solo pruebas (MCP): dispara una acción como si se hubiera pulsado.
function InputRouter.scriptedPress(name: ActionName)
	fire(name)
end

return InputRouter
