--!strict
-- Mapa central de acciones de gameplay (equivalente al InputMap de Godot), sobre el
-- Input Action System nativo: un InputContext "Gameplay" con una InputAction por acción
-- y sus InputBindings de teclado y mando (project.godot [input] / guía §2.4).
-- Los controles táctiles entran por el MISMO camino: los botones se enlazan como
-- InputBinding.UIButton y el joystick llama a setTouchMove(), que hace Fire() de la acción.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

export type ActionName = "jump" | "yoyo" | "action" | "pause"

local InputRouter = {}

local MOVE_DEADZONE = 0.2 -- move_* en project.godot
local CAMERA_DEADZONE = 0.25 -- camera_*

local context: InputContext
local actions: { [string]: InputAction } = {}
local pressedQueue: { [string]: boolean } = {}
local listeners: { [string]: { (() -> ()) } } = {}
local touchMove = Vector2.zero
local touchMoveActive = false
local started = false
-- Entrada programada para las mediciones del laboratorio (Calibration, solo pruebas):
-- sustituye a la del jugador mientras está activa.
local scripted: { move: Vector2, held: { [string]: boolean } }? = nil

InputRouter.preferredDevice = "keyboard" :: "keyboard" | "gamepad" | "touch"
InputRouter.deviceChanged = Instance.new("BindableEvent")

local function binding(action: InputAction, props: { [string]: any })
	local inputBinding = Instance.new("InputBinding")
	for key, value in props do
		(inputBinding :: any)[key] = value
	end
	inputBinding.Parent = action
	return inputBinding
end

local function makeAction(name: string, actionType: Enum.InputActionType): InputAction
	local action = Instance.new("InputAction")
	action.Name = name
	action.Type = actionType
	action.Parent = context
	actions[name] = action
	return action
end

local function boolAction(name: string, keys: { Enum.KeyCode })
	local action = makeAction(name, Enum.InputActionType.Bool)
	for _, key in keys do
		binding(action, { KeyCode = key })
	end
	action.Pressed:Connect(function()
		pressedQueue[name] = true
		for _, callback in listeners[name] or {} do
			task.spawn(callback)
		end
	end)
end

-- Zona muerta circular con reescalado, como Input.get_vector de Godot.
local function applyDeadzone(value: Vector2, deadzone: number): Vector2
	local length = value.Magnitude
	if length < deadzone then
		return Vector2.zero
	end
	local scaled = math.clamp((length - deadzone) / (1 - deadzone), 0, 1)
	return value.Unit * scaled
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
	context = Instance.new("InputContext")
	context.Name = "Gameplay"
	context.Priority = 1000
	context.Sink = false

	local move = makeAction("move", Enum.InputActionType.Direction2D)
	binding(move, { Up = Enum.KeyCode.W, Down = Enum.KeyCode.S, Left = Enum.KeyCode.A, Right = Enum.KeyCode.D })
	binding(move, { Up = Enum.KeyCode.Up, Down = Enum.KeyCode.Down, Left = Enum.KeyCode.Left, Right = Enum.KeyCode.Right })
	binding(move, { KeyCode = Enum.KeyCode.Thumbstick1 })

	local camera = makeAction("camera", Enum.InputActionType.Direction2D)
	binding(camera, { Left = Enum.KeyCode.Q, Right = Enum.KeyCode.R })
	binding(camera, { KeyCode = Enum.KeyCode.Thumbstick2 })

	boolAction("jump", { Enum.KeyCode.Space, Enum.KeyCode.J, Enum.KeyCode.ButtonA })
	boolAction("yoyo", { Enum.KeyCode.E, Enum.KeyCode.K, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonR1 })
	boolAction("action", { Enum.KeyCode.LeftShift, Enum.KeyCode.L, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1 })
	-- Esc abre el menú de Roblox: la pausa principal en PC es P (guía §2.4).
	boolAction("pause", { Enum.KeyCode.P, Enum.KeyCode.ButtonStart })

	context.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")

	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updatePreferredDevice)
	updatePreferredDevice()
end

-- Vector de movimiento: x = derecha, y = adelante (+). Magnitud ≤ 1.
function InputRouter.getMove(): Vector2
	if scripted then
		return scripted.move
	end
	if touchMoveActive then
		return touchMove
	end
	local value = actions.move:GetState() :: Vector2
	return applyDeadzone(value, MOVE_DEADZONE)
end

-- Eje de cámara: −1 = Q / izquierda, +1 = R / derecha.
function InputRouter.getCameraAxis(): number
	local value = (actions.camera:GetState() :: Vector2).X
	return if math.abs(value) < CAMERA_DEADZONE then 0 else value
end

function InputRouter.isDown(name: ActionName): boolean
	if scripted then
		return scripted.held[name] == true
	end
	return actions[name]:GetState() == true
end

-- true si la acción se pulsó desde la última consulta (is_action_just_pressed).
function InputRouter.consumePressed(name: ActionName): boolean
	local pressed = pressedQueue[name] == true
	pressedQueue[name] = false
	return pressed
end

-- Descarta pulsaciones pendientes (reaparición, pausa).
function InputRouter.clearPressed()
	table.clear(pressedQueue)
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

-- Joystick táctil: el vector ya llega con su zona muerta (touch_controls.gd).
function InputRouter.setTouchMove(value: Vector2)
	touchMove = value
	touchMoveActive = value.Magnitude > 0
	actions.move:Fire(value)
end

-- Enlaza un botón táctil a una acción como InputBinding nativo.
function InputRouter.bindTouchButton(name: ActionName, button: GuiButton): InputBinding
	return binding(actions[name], { UIButton = button })
end

-- Solo pruebas: activa (tabla) o desactiva (nil) la entrada programada.
function InputRouter.setScripted(state: { move: Vector2, held: { [string]: boolean } }?)
	scripted = state
	InputRouter.clearPressed()
end

-- Solo pruebas: pulsa una acción programada (flanco + mantenida).
function InputRouter.scriptedPress(name: ActionName, hold: boolean)
	if scripted then
		pressedQueue[name] = true
		scripted.held[name] = hold
	end
end

function InputRouter.setEnabled(enabled: boolean)
	context.Enabled = enabled
	if not enabled then
		InputRouter.clearPressed()
		InputRouter.setTouchMove(Vector2.zero)
	end
end

return InputRouter
