--!strict
-- Estilo de la interfaz (scripts/ui/ui_kit.gd) con componentes nativos: UICorner,
-- UIStroke, UIListLayout, UIScale. Toda la UI se crea desde código, como en Godot.

local Theme = {}

Theme.ORANGE = Color3.new(1.0, 0.6, 0.18)
Theme.CYAN = Color3.new(0.13, 0.83, 0.93)
Theme.GOLD = Color3.new(1.0, 0.8, 0.25)
Theme.SILVER = Color3.new(0.82, 0.86, 0.92)
Theme.BRONZE = Color3.new(0.85, 0.52, 0.28)
Theme.DIM = Color3.new(0.62, 0.7, 0.82)
Theme.GEM = Color3.new(0.44, 0.86, 1.0)
Theme.DARK = Color3.new(0.05, 0.1, 0.22)
Theme.WHITE = Color3.new(1, 1, 1)
Theme.FONT = Enum.Font.GothamBold
Theme.FONT_REGULAR = Enum.Font.GothamMedium

Theme.MEDAL_COLORS = { [1] = Theme.BRONZE, [2] = Theme.SILVER, [3] = Theme.GOLD }
Theme.MEDAL_KEYS = { [1] = "MEDAL_BRONZE", [2] = "MEDAL_SILVER", [3] = "MEDAL_GOLD" }

export type Props = { [string]: any }

function Theme.create(className: string, props: Props, children: { Instance }?): Instance
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Theme.corner(radius: number): UICorner
	return Theme.create("UICorner", { CornerRadius = UDim.new(0, radius) }) :: UICorner
end

function Theme.stroke(color: Color3, thickness: number, transparency: number?): UIStroke
	return Theme.create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}) :: UIStroke
end

function Theme.label(text: string, size: number, color: Color3?, props: Props?): TextLabel
	local label = Theme.create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		Font = Theme.FONT,
		TextColor3 = color or Theme.WHITE,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
	}) :: TextLabel
	Theme.create("UIStroke", { Color = Theme.DARK, Thickness = 2, Transparency = 0.25, Parent = label })
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

function Theme.panel(props: Props): Frame
	local frame = Theme.create("Frame", {
		BackgroundColor3 = Theme.DARK,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}) :: Frame
	Theme.corner(14).Parent = frame
	Theme.stroke(Theme.CYAN, 2, 0.6).Parent = frame
	for key, value in props do
		(frame :: any)[key] = value
	end
	return frame
end

function Theme.button(text: string, color: Color3, onActivated: () -> (), props: Props?): TextButton
	local button = Theme.create("TextButton", {
		Text = text,
		Font = Theme.FONT,
		TextSize = 24,
		TextColor3 = Theme.WHITE,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(240, 56),
	}) :: TextButton
	Theme.corner(14).Parent = button
	Theme.stroke(Theme.DARK, 2, 0.3).Parent = button
	for key, value in props or {} do
		(button :: any)[key] = value
	end
	button.Activated:Connect(onActivated)
	return button
end

function Theme.list(direction: Enum.FillDirection, padding: number, align: Enum.HorizontalAlignment?): UIListLayout
	return Theme.create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}) :: UIListLayout
end

-- Icono de chispa: rombo dorado (la fuente de Roblox no tiene ✦).
function Theme.sparkIcon(size: number, props: Props?): Frame
	local holder = Theme.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	}) :: Frame
	local diamond = Theme.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45,
		BackgroundColor3 = Theme.GOLD,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Theme.create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = diamond })
	Theme.stroke(Theme.DARK, 2, 0.25).Parent = diamond
	for key, value in props or {} do
		(holder :: any)[key] = value
	end
	return holder
end

-- ScreenGui a pantalla completa dentro de las zonas seguras del dispositivo. Las capas
-- que viven en las esquinas superiores (HUD, panel del laboratorio) piden además
-- CoreUISafeInsets para no quedar bajo los botones de la barra superior de Roblox.
function Theme.screen(name: string, order: number, parent: Instance, insets: Enum.ScreenInsets?): ScreenGui
	return Theme.create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = insets or Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		AutoLocalize = false,
		Parent = parent,
	}) :: ScreenGui
end

-- Marco raíz de una pantalla: la UI se diseña a 720 px de alto (como en Godot) y un
-- UIScale la adapta al tamaño real; el marco se agranda en proporción inversa para
-- seguir ocupando toda la zona segura.
function Theme.root(gui: ScreenGui): (Frame, UIScale)
	local root = Theme.create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}) :: Frame
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function update()
		local height = gui.AbsoluteSize.Y
		if height <= 0 then
			height = workspace.CurrentCamera.ViewportSize.Y
		end
		local value = math.clamp(height / 720, 0.45, 2)
		scale.Scale = value
		root.Size = UDim2.fromScale(1 / value, 1 / value)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	return root, scale
end

return Theme
