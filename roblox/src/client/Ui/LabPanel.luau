--!strict
-- Panel del laboratorio de mecánicas: ejecuta la batería de mediciones (Dev/Calibration)
-- y muestra cada alcance frente a la referencia de Godot (movement_reach.gd a 60 Hz) con
-- la desviación y los FPS reales. Sirve para comprobar en un teléfono (p. ej. a 120 FPS)
-- sin Studio.

local Theme = require(script.Parent:WaitForChild("Theme"))

-- Referencia de Godot 4.7.2 (tools/_reach_test.gd, 2026-10-22): hueco plano y altura (m).
local GODOT = {
	{ id = "jump", label = "Salto", gap = 6.13, apex = 2.27 },
	{ id = "long", label = "Salto largo", gap = 7.80, apex = 1.53 },
	{ id = "dash", label = "Salto + dash", gap = 9.34, apex = 2.51 },
	{ id = "yoyo_air", label = "Salto + disco", gap = 14.15, apex = 5.80 },
	{ id = "yoyo_ground", label = "Disco en suelo", gap = 8.44, apex = 4.44 },
	{ id = "trampoline", label = "Trampolín 20", gap = 10.46, apex = 6.98 },
	{ id = "trampoline_24", label = "Trampolín 24", gap = 12.53, apex = 10.09 },
}
local TOLERANCE = 0.05

local LabPanel = {}
LabPanel.__index = LabPanel

export type LabPanel = typeof(setmetatable({} :: {
	gui: ScreenGui,
	button: TextButton,
	panel: Frame,
	list: Frame,
	running: boolean,
	measure: (technique: string) -> { [string]: any }?,
}, LabPanel))

function LabPanel.new(parent: Instance): LabPanel
	local gui = Theme.screen("LabPanel", 12, parent, Enum.ScreenInsets.CoreUISafeInsets)
	gui.Enabled = false
	local root = Theme.root(gui)
	local self = setmetatable({
		gui = gui,
		button = nil :: any,
		panel = nil :: any,
		list = nil :: any,
		running = false,
		measure = function(_technique: string)
			return nil
		end,
	}, LabPanel)
	self.button = Theme.button("Medir alcances", Theme.CYAN, function()
		self:run()
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 150),
		Size = UDim2.fromOffset(220, 50),
		TextSize = 20,
		Parent = root,
	})
	local panel = Theme.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 210),
		Size = UDim2.fromOffset(470, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
	})
	Theme.create("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		Parent = panel,
	})
	local list = Theme.create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		Parent = panel,
	}) :: Frame
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left).Parent = list
	self.panel = panel
	self.list = list
	return self
end

function LabPanel._line(self: LabPanel, text: string, color: Color3?, order: number)
	Theme.label(text, 16, color or Theme.WHITE, {
		LayoutOrder = order,
		Font = Theme.FONT_REGULAR,
		Parent = self.list,
	})
end

function LabPanel.run(self: LabPanel)
	if self.running then
		return
	end
	self.running = true
	self.button.Text = "Midiendo…"
	for _, child in self.list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	self.panel.Visible = true
	self:_line("Técnica · hueco Roblox / Godot · altura Roblox / Godot", Theme.GOLD, 0)
	local fpsSum, fpsCount = 0, 0
	for index, reference in GODOT do
		local result = self.measure(reference.id)
		if result and result.gap0 then
			local gapError = result.gap0 / reference.gap - 1
			local apexError = result.apex / reference.apex - 1
			local ok = math.abs(gapError) <= TOLERANCE and math.abs(apexError) <= TOLERANCE
			fpsSum += result.fps or 0
			fpsCount += 1
			self:_line(string.format("%s %s · %.2f / %.2f m (%+.1f%%) · %.2f / %.2f m (%+.1f%%)", if ok then "✓" else "✗",
				reference.label, result.gap0, reference.gap, gapError * 100, result.apex, reference.apex, apexError * 100),
				if ok then Theme.WHITE else Theme.ORANGE, index)
		else
			self:_line("✗ " .. reference.label .. " · sin medida", Theme.ORANGE, index)
		end
	end
	self:_line(string.format("FPS medios durante la prueba: %.0f · tolerancia ±5 %%", fpsSum / math.max(fpsCount, 1)), Theme.DIM, 100)
	self.button.Text = "Medir alcances"
	self.running = false
end

function LabPanel.setVisible(self: LabPanel, visible: boolean)
	self.gui.Enabled = visible
	if not visible then
		self.panel.Visible = false
	end
end

return LabPanel
