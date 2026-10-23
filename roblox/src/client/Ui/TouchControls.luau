--!strict
-- Controles táctiles multitoque: port de scripts/ui/touch_controls.gd. Entran por el
-- MISMO camino que teclado y mando (InputRouter):
--   · los tres botones (saltar, yo-yo, acción) son InputBinding.UIButton nativos;
--   · el joystick flotante hace Fire() de la acción move con su vector.
-- Izquierda: joystick que aparece donde se apoya el pulgar (45 % izquierdo, bajo el 30 %
-- superior). Derecha: botones y arrastre libre para girar la cámara. Modo zurdo en espejo.
-- Medidas en píxeles de diseño a 720 px de alto (Theme.root las escala).

local UserInputService = game:GetService("UserInputService")

local InputRouter = require(script.Parent.Parent:WaitForChild("InputRouter"))
local Settings = require(script.Parent.Parent:WaitForChild("Settings"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local JOY_RADIUS = 105
local DEAD_ZONE = 0.12
local MARGIN = 40
local BUTTONS = {
	{ name = "jump", radius = 88, color = Theme.ORANGE, icon = "▲" },
	{ name = "yoyo", radius = 64, color = Theme.CYAN, icon = "◎" },
	{ name = "action", radius = 60, color = Color3.new(0.75, 0.82, 0.95), icon = "»" },
}

type ButtonView = {
	name: string,
	radius: number,
	color: Color3,
	hit: TextButton,
	disc: Frame,
	stroke: UIStroke,
	icon: TextLabel,
}

type Readiness = { yoyo: boolean, action: boolean }

local TouchControls = {}
TouchControls.__index = TouchControls

export type TouchControls = typeof(setmetatable({} :: {
	gui: ScreenGui,
	root: Frame,
	scale: UIScale,
	joyBase: Frame,
	joyKnob: Frame,
	buttons: { [string]: ButtonView },
	readiness: () -> Readiness,
	onCameraDrag: (pixels: number) -> (),
	_joyTouch: InputObject?,
	_joyCenter: Vector2,
	_joyRest: Vector2,
	_joyVector: Vector2,
	_camTouch: InputObject?,
	_camLast: Vector2,
	_enabled: boolean,
	_connections: { RBXScriptConnection },
}, TouchControls))

local function circle(parent: Instance, radius: number, color: Color3, transparency: number): (Frame, UIStroke)
	local frame = Theme.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(radius * 2, radius * 2),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Parent = parent,
	}) :: Frame
	Theme.create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	local stroke = Theme.stroke(color, 4, 0.1)
	stroke.Parent = frame
	return frame, stroke
end

function TouchControls.new(parent: Instance): TouchControls
	local gui = Theme.screen("TouchControls", 5, parent)
	local root, scale = Theme.root(gui)
	local joyBase = circle(root, JOY_RADIUS, Color3.new(1, 1, 1), 0.82)
	local joyKnob = circle(root, JOY_RADIUS * 0.42, Color3.new(1, 1, 1), 0.55)
	-- Marcas de dirección: el joystick se lee aunque esté quieto.
	for i = 0, 3 do
		local angle = i * math.pi / 2
		Theme.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(angle) * JOY_RADIUS * 0.8, 0.5, math.sin(angle) * JOY_RADIUS * 0.8),
			Size = UDim2.fromOffset(if i % 2 == 0 then 16 else 4, if i % 2 == 0 then 4 else 16),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Parent = joyBase,
		})
	end
	local self = setmetatable({
		gui = gui,
		root = root,
		scale = scale,
		joyBase = joyBase,
		joyKnob = joyKnob,
		buttons = {},
		readiness = function(): Readiness
			return { yoyo = true, action = true }
		end,
		onCameraDrag = function(_pixels: number) end,
		_joyTouch = nil,
		_joyCenter = Vector2.zero,
		_joyRest = Vector2.zero,
		_joyVector = Vector2.zero,
		_camTouch = nil,
		_camLast = Vector2.zero,
		_enabled = true,
		_connections = {},
	}, TouchControls)

	for _, spec in BUTTONS do
		local hitRadius = spec.radius * 1.25
		local hit = Theme.create("TextButton", {
			Name = spec.name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(hitRadius * 2, hitRadius * 2),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = root,
		}) :: TextButton
		local disc, stroke = circle(hit, spec.radius, spec.color, 0.6)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		local icon = Theme.label(spec.icon, spec.radius * 0.8, Color3.new(1, 1, 1), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = disc,
		})
		InputRouter.bindTouchButton(spec.name :: any, hit)
		self.buttons[spec.name] = {
			name = spec.name,
			radius = spec.radius,
			color = spec.color,
			hit = hit,
			disc = disc,
			stroke = stroke,
			icon = icon,
		}
	end

	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		self:_onBegan(input, processed)
	end))
	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		self:_onChanged(input)
	end))
	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
		self:_onEnded(input)
	end))
	table.insert(self._connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:layout()
	end))
	Settings.changed:Connect(function()
		self:layout()
	end)
	self:layout()
	return self
end

-- Tamaño del marco raíz en píxeles de diseño.
function TouchControls._designSize(self: TouchControls): Vector2
	return self.root.AbsoluteSize / self.scale.Scale
end

-- Posición de un toque (píxeles de pantalla) en píxeles de diseño del marco raíz.
function TouchControls._toDesign(self: TouchControls, screen: Vector3): Vector2
	local absolute = Vector2.new(screen.X, screen.Y) + game:GetService("GuiService"):GetGuiInset()
	return (absolute - self.root.AbsolutePosition) / self.scale.Scale
end

function TouchControls.layout(self: TouchControls)
	local size = self:_designSize()
	local touchScale = Settings.get("touchScale") :: number
	local leftHanded = Settings.get("leftHanded") :: boolean
	local opacity = Settings.get("touchOpacity") :: number
	self._joyRest = Vector2.new(MARGIN + JOY_RADIUS * touchScale + 20, size.Y - MARGIN - JOY_RADIUS * touchScale - 10)
	local jumpRadius = 88 * touchScale
	local anchor = Vector2.new(size.X - MARGIN - jumpRadius, size.Y - MARGIN - jumpRadius)
	local centers = {
		jump = anchor,
		yoyo = anchor + Vector2.new(-30, -(jumpRadius + 80 * touchScale)),
		action = anchor + Vector2.new(-(jumpRadius + 78 * touchScale), 10),
	}
	if leftHanded then
		self._joyRest = Vector2.new(size.X - self._joyRest.X, self._joyRest.Y)
		for name, center in centers do
			centers[name] = Vector2.new(size.X - center.X, center.Y)
		end
	end
	for name, view in self.buttons do
		local center = centers[name]
		view.hit.Position = UDim2.fromOffset(center.X, center.Y)
		local hitRadius = view.radius * touchScale * 1.25
		view.hit.Size = UDim2.fromOffset(hitRadius * 2, hitRadius * 2)
		view.disc.Size = UDim2.fromOffset(view.radius * touchScale * 2, view.radius * touchScale * 2)
		view.icon.TextSize = view.radius * touchScale * 0.8
	end
	self.joyBase.Size = UDim2.fromOffset(JOY_RADIUS * 2 * touchScale, JOY_RADIUS * 2 * touchScale)
	self.joyKnob.Size = UDim2.fromOffset(JOY_RADIUS * 0.84 * touchScale, JOY_RADIUS * 0.84 * touchScale)
	if not self._joyTouch then
		self._joyCenter = self._joyRest
	end
	for _, view in self.buttons do
		view.disc.BackgroundTransparency = 1 - (0.35 * opacity + 0.1)
	end
	self.joyBase.BackgroundTransparency = 1 - (0.12 * opacity + 0.05)
	self:_drawJoystick()
end

function TouchControls._drawJoystick(self: TouchControls)
	local touchScale = Settings.get("touchScale") :: number
	local knob = self._joyCenter + self._joyVector * JOY_RADIUS * touchScale
	self.joyBase.Position = UDim2.fromOffset(self._joyCenter.X, self._joyCenter.Y)
	self.joyKnob.Position = UDim2.fromOffset(knob.X, knob.Y)
end

function TouchControls._onBegan(self: TouchControls, input: InputObject, processed: boolean)
	if not self._enabled or input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if processed then
		return -- el toque empezó sobre un botón (InputBinding.UIButton)
	end
	local pos = self:_toDesign(input.Position)
	local size = self:_designSize()
	local leftHanded = Settings.get("leftHanded") :: boolean
	local inJoyZone = if leftHanded then pos.X > size.X * 0.55 else pos.X < size.X * 0.45
	if self._joyTouch == nil and inJoyZone and pos.Y > size.Y * 0.3 then
		self._joyTouch = input
		self._joyCenter = pos
		self:_updateJoystick(pos)
		return
	end
	if self._camTouch == nil and pos.Y > size.Y * 0.15 then
		self._camTouch = input
		self._camLast = pos
	end
end

function TouchControls._onChanged(self: TouchControls, input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if input == self._joyTouch then
		self:_updateJoystick(self:_toDesign(input.Position))
	elseif input == self._camTouch then
		local pos = self:_toDesign(input.Position)
		self.onCameraDrag(pos.X - self._camLast.X)
		self._camLast = pos
	end
end

function TouchControls._onEnded(self: TouchControls, input: InputObject)
	if input == self._joyTouch then
		self._joyTouch = nil
		self._joyVector = Vector2.zero
		self._joyCenter = self._joyRest
		self:_applyJoystick()
	elseif input == self._camTouch then
		self._camTouch = nil
	end
end

function TouchControls._updateJoystick(self: TouchControls, pos: Vector2)
	local radius = JOY_RADIUS * (Settings.get("touchScale") :: number)
	local offset = pos - self._joyCenter
	-- La base sigue al pulgar cuando este se aleja más allá del borde.
	if offset.Magnitude > radius * 1.3 then
		self._joyCenter = pos - offset.Unit * radius * 1.3
		offset = pos - self._joyCenter
	end
	local vector = offset / radius
	if vector.Magnitude > 1 then
		vector = vector.Unit
	end
	self._joyVector = vector
	self:_applyJoystick()
end

function TouchControls._applyJoystick(self: TouchControls)
	local v = self._joyVector
	local length = v.Magnitude
	if length < DEAD_ZONE then
		v = Vector2.zero
	else
		v = v.Unit * math.clamp((length - DEAD_ZONE) / (1 - DEAD_ZONE), 0, 1)
	end
	-- Pantalla: y hacia abajo; acción move: y = adelante.
	InputRouter.setTouchMove(Vector2.new(v.X, -v.Y))
	self:_drawJoystick()
end

-- Atenúa el yo-yo y la acción cuando no están disponibles; resalta lo pulsado.
function TouchControls.update(self: TouchControls)
	if not self.gui.Enabled then
		return
	end
	local ready = self.readiness()
	local opacity = Settings.get("touchOpacity") :: number
	for name, view in self.buttons do
		local available = if name == "yoyo" then ready.yoyo elseif name == "action" then ready.action else true
		local pressed = InputRouter.isDown(name :: any)
		view.icon.TextTransparency = if available then 0 else 0.65
		view.stroke.Transparency = if available then 0.1 else 0.65
		view.disc.BackgroundTransparency = 1 - ((if pressed then 0.55 else 0.35) * opacity + 0.1)
	end
end

function TouchControls.setVisible(self: TouchControls, visible: boolean)
	self.gui.Enabled = visible and self._enabled
	if not visible then
		self:releaseAll()
	end
end

function TouchControls.setEnabled(self: TouchControls, enabled: boolean)
	self._enabled = enabled
	self:setVisible(enabled and InputRouter.preferredDevice == "touch")
end

-- Suelta todo (pausa, ocultar, salir del nivel).
function TouchControls.releaseAll(self: TouchControls)
	self._joyTouch = nil
	self._camTouch = nil
	self._joyVector = Vector2.zero
	self._joyCenter = self._joyRest
	InputRouter.setTouchMove(Vector2.zero)
	self:_drawJoystick()
end

function TouchControls.destroy(self: TouchControls)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.gui:Destroy()
end

return TouchControls
