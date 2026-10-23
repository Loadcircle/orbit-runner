--!strict
-- Ajustes (scripts/ui/settings_menu.gd), en memoria durante la Fase 1: volúmenes,
-- tamaño y opacidad táctiles, modo zurdo, vibración, sensibilidad de cámara, temblor,
-- cronómetro y fantasma. Sin idioma, calidad ni FPS: los gestiona Roblox.

local Settings = require(script.Parent.Parent:WaitForChild("Settings"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

export type SettingsPanel = typeof(setmetatable({} :: { gui: ScreenGui, onClose: () -> () }, SettingsPanel))

type Row = { key: Settings.Key, label: string, kind: "toggle" | "range", min: number?, max: number?, step: number? }

local ROWS: { Row } = {
	{ key = "masterVolume", label = "SETTINGS_MASTER", kind = "range", min = 0, max = 1, step = 0.1 },
	{ key = "musicVolume", label = "SETTINGS_MUSIC", kind = "range", min = 0, max = 1, step = 0.1 },
	{ key = "sfxVolume", label = "SETTINGS_SFX", kind = "range", min = 0, max = 1, step = 0.1 },
	{ key = "vibration", label = "SETTINGS_VIBRATION", kind = "toggle" },
	{ key = "screenShake", label = "SETTINGS_SHAKE", kind = "toggle" },
	{ key = "showTimer", label = "SETTINGS_TIMER", kind = "toggle" },
	{ key = "showGhost", label = "SETTINGS_GHOST", kind = "toggle" },
}

local function formatValue(row: Row, value: any): string
	if row.kind == "toggle" then
		return Strings.get(if value then "SETTINGS_ON" else "SETTINGS_OFF")
	end
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

function SettingsPanel.new(parent: Instance): SettingsPanel
	local gui = Theme.screen("SettingsPanel", 40, parent)
	gui.Enabled = false
	local root = Theme.root(gui)
	local self = setmetatable({ gui = gui, onClose = function() end }, SettingsPanel)
	Theme.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.DARK, BackgroundTransparency = 0.35, Parent = root })
	local panel = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 620),
		Parent = root,
	})
	Theme.label(Strings.get("SETTINGS_TITLE"), 38, Theme.WHITE, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Parent = panel,
	})
	local scroll = Theme.create("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 64),
		Size = UDim2.new(1, -40, 1, -150),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Vertical, 8).Parent = scroll
	for index, row in ROWS do
		local line = Theme.create("Frame", {
			Size = UDim2.new(1, -12, 0, 44),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = scroll,
		})
		Theme.label(Strings.get(row.label), 22, Theme.WHITE, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Font = Theme.FONT_REGULAR,
			Parent = line,
		})
		local valueLabel = Theme.label(formatValue(row, Settings.get(row.key)), 22, Theme.GOLD, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -110, 0.5, 0),
			Parent = line,
		})
		local function change(direction: number)
			local current = Settings.get(row.key)
			local value
			if row.kind == "toggle" then
				value = not current
			else
				local step = row.step :: number
				value = math.clamp(math.floor((current + direction * step) / step + 0.5) * step, row.min :: number, row.max :: number)
			end
			Settings.set(row.key, value)
			valueLabel.Text = formatValue(row, value)
		end
		if row.kind == "toggle" then
			Theme.button("⇄", Theme.CYAN, function()
				change(1)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(96, 40), Parent = line })
		else
			Theme.button("−", Theme.CYAN, function()
				change(-1)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(44, 40), Parent = line })
			Theme.button("+", Theme.CYAN, function()
				change(1)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(44, 40), Parent = line })
		end
	end
	Theme.label(Strings.get("SETTINGS_KEYS_HELP"), 15, Theme.DIM, {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -12, 0, 0),
		TextWrapped = true,
		Font = Theme.FONT_REGULAR,
		LayoutOrder = #ROWS + 1,
		Parent = scroll,
	})
	Theme.button(Strings.get("SETTINGS_BACK"), Theme.ORANGE, function()
		self:close()
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Parent = panel,
	})
	return self
end

function SettingsPanel.open(self: SettingsPanel)
	self.gui.Enabled = true
end

function SettingsPanel.close(self: SettingsPanel)
	self.gui.Enabled = false
	self.onClose()
end

return SettingsPanel
