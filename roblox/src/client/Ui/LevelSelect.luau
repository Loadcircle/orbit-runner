--!strict
-- Selector mínimo: laboratorio, tutorial y mundo 1 en una fila desplazable (el hub real
-- es de la Fase 4). Muestra el mejor tiempo, la medalla que guarda el servidor, la
-- marca "Por aprobar" de los niveles que el dueño aún no ha aprobado y un aviso si el
-- progreso no se está guardando (DataStore no disponible, R22).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCatalog = require(Shared:WaitForChild("LevelCatalog"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local LevelSelect = {}
LevelSelect.__index = LevelSelect

export type LevelSelect = typeof(setmetatable({} :: {
	gui: ScreenGui,
	cards: ScrollingFrame,
	notice: TextLabel,
	onPlay: (id: string) -> (),
	onSettings: () -> (),
}, LevelSelect))

function LevelSelect.new(parent: Instance): LevelSelect
	local gui = Theme.screen("LevelSelect", 20, parent)
	gui.Enabled = false
	local root = Theme.root(gui)
	Theme.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.DARK, BackgroundTransparency = 0.3, Parent = root })
	Theme.label(Strings.get("SELECT_TITLE"), 46, Theme.WHITE, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Parent = root,
	})
	local cards = Theme.create("ScrollingFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(1, -60, 0, 340),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.CYAN,
		Parent = root,
	}) :: ScrollingFrame
	-- Alineada a la izquierda: centrada, la fila desborda por la izquierda fuera del scroll.
	Theme.list(Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Left).Parent = cards
	Theme.create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = cards,
	})
	local notice = Theme.label(Strings.get("PROGRESS_NOT_SAVED"), 20, Theme.ORANGE, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Visible = false,
		Parent = root,
	}) :: TextLabel
	local self = setmetatable({
		gui = gui,
		cards = cards,
		notice = notice,
		onPlay = function(_id: string) end,
		onSettings = function() end,
	}, LevelSelect)
	Theme.button(Strings.get("MENU_SETTINGS"), Color3.new(0.3, 0.38, 0.6), function()
		self.onSettings()
	end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Parent = root })
	return self
end

function LevelSelect.open(self: LevelSelect, progress: { [string]: any }?)
	for _, child in self.cards:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local levels = if progress then progress.levels or {} else {}
	self.notice.Visible = progress ~= nil and progress.persistent == false
	for index, entry in LevelCatalog.entries do
		local card = Theme.panel({
			Size = UDim2.fromOffset(270, 300),
			LayoutOrder = index,
			Parent = self.cards,
		})
		Theme.list(Enum.FillDirection.Vertical, 10).Parent = card
		Theme.label(Strings.get(entry.titleKey), 30, Theme.WHITE, { LayoutOrder = 1, Parent = card, TextWrapped = true })
		Theme.label(Strings.get(entry.hintKey), 20, Theme.DIM, {
			LayoutOrder = 2,
			Parent = card,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(240, 0),
			Font = Theme.FONT_REGULAR,
		})
		if entry.pending then
			Theme.label(Strings.get("SELECT_PENDING"), 20, Theme.ORANGE, { LayoutOrder = 3, Parent = card })
		end
		local record = levels[entry.id]
		if record and record.bestTime and record.bestTime > 0 then
			local medal = record.medal or 0
			Theme.label(Strings.get("SELECT_BEST", Strings.formatTime(record.bestTime)), 22,
				if medal > 0 then Theme.MEDAL_COLORS[medal] else Theme.WHITE, { LayoutOrder = 4, Parent = card })
		end
		Theme.button(Strings.get("SELECT_PLAY"), if entry.lab then Theme.CYAN else Theme.ORANGE, function()
			self.onPlay(entry.id)
		end, { LayoutOrder = 5, Size = UDim2.fromOffset(220, 56), Parent = card })
	end
	self.gui.Enabled = true
end

function LevelSelect.close(self: LevelSelect)
	self.gui.Enabled = false
end

return LevelSelect
