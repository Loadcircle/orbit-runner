--!strict
-- Panel de niveles de un mundo (R23): se abre al usar el portal del mundo en el
-- vestíbulo. Cada tarjeta muestra SOLO los datos del jugador: mejor tiempo con el color
-- de su medalla, estrellas de maestría y gemas; los niveles sin desbloquear salen
-- bloqueados (progress.gd: is_unlocked). Avisa si el progreso no se está guardando
-- (DataStore no disponible, R22).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCatalog = require(Shared:WaitForChild("LevelCatalog"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local LevelSelect = {}
LevelSelect.__index = LevelSelect

export type LevelSelect = typeof(setmetatable({} :: {
	gui: ScreenGui,
	title: TextLabel,
	cards: ScrollingFrame,
	notice: TextLabel,
	world: number?,
	onPlay: (id: string) -> (),
	onSettings: () -> (),
	onClose: () -> (),
}, LevelSelect))

local function countTrue(values: { any }?): number
	local count = 0
	for _, value in values or {} do
		if value == true then
			count += 1
		end
	end
	return count
end

function LevelSelect.new(parent: Instance): LevelSelect
	local gui = Theme.screen("LevelSelect", 20, parent)
	gui.Enabled = false
	local root = Theme.root(gui)
	Theme.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.DARK, BackgroundTransparency = 0.3, Parent = root })
	local title = Theme.label("", 46, Theme.WHITE, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Parent = root,
	})
	local notice = Theme.label(Strings.get("PROGRESS_NOT_SAVED"), 20, Theme.ORANGE, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Visible = false,
		Parent = root,
	}) :: TextLabel
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
	local self = setmetatable({
		gui = gui,
		title = title,
		cards = cards,
		notice = notice,
		world = nil,
		onPlay = function(_id: string) end,
		onSettings = function() end,
		onClose = function() end,
	}, LevelSelect)
	local buttons = Theme.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Parent = root,
	})
	Theme.list(Enum.FillDirection.Horizontal, 16).Parent = buttons
	Theme.button(Strings.get("MENU_SETTINGS"), Color3.new(0.3, 0.38, 0.6), function()
		self.onSettings()
	end, { LayoutOrder = 1, Parent = buttons })
	Theme.button(Strings.get("SELECT_CLOSE"), Theme.CYAN, function()
		self:close()
		self.onClose()
	end, { LayoutOrder = 2, Parent = buttons })
	return self
end

local function addCard(self: LevelSelect, entry: LevelCatalog.Entry, index: number, record: { [string]: any }?, unlocked: boolean)
	local card = Theme.panel({
		Size = UDim2.fromOffset(270, 300),
		LayoutOrder = index,
		Parent = self.cards,
	})
	Theme.list(Enum.FillDirection.Vertical, 8).Parent = card
	Theme.label(Strings.get(entry.titleKey), 30, if unlocked then Theme.WHITE else Theme.DIM,
		{ LayoutOrder = 1, Parent = card, TextWrapped = true })
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
	if not unlocked then
		Theme.label(Strings.get("SELECT_LOCKED"), 20, Theme.DIM, {
			LayoutOrder = 4,
			Parent = card,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(240, 0),
		})
		return
	end
	if record and record.completed and record.bestTime and record.bestTime > 0 then
		local medal = record.medal or 0
		Theme.label(Strings.get("SELECT_BEST", Strings.formatTime(record.bestTime)), 22,
			if medal > 0 then Theme.MEDAL_COLORS[medal] else Theme.WHITE, { LayoutOrder = 4, Parent = card })
		if not entry.tutorial and not entry.lab then
			Theme.label(string.format("★ %d/4   ·   %s", countTrue(record.mastery),
				Strings.get("SELECT_GEMS", tostring(countTrue(record.gems)))), 20, Theme.GOLD, { LayoutOrder = 5, Parent = card })
		end
	end
	Theme.button(Strings.get("SELECT_PLAY"), if entry.lab then Theme.CYAN else Theme.ORANGE, function()
		self.onPlay(entry.id)
	end, { LayoutOrder = 6, Size = UDim2.fromOffset(220, 56), Parent = card })
end

function LevelSelect.open(self: LevelSelect, world: number, progress: { [string]: any }?)
	for _, child in self.cards:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	self.world = world
	self.title.Text = Strings.get(if world == 0 then "SELECT_LAB" else "WORLD_" .. world)
	self.notice.Visible = progress ~= nil and progress.persistent == false
	self.cards.CanvasPosition = Vector2.zero
	local levels = if progress then progress.levels or {} else {}
	local unlocked = if progress then progress.unlocked or {} else {}
	for index, entry in LevelCatalog.world(world) do
		-- Sin respuesta del servidor todo se muestra abierto; el servidor valida igualmente.
		local open = entry.lab or progress == nil or unlocked[entry.id] == true
		addCard(self, entry, index, levels[entry.id], open)
	end
	self.gui.Enabled = true
end

function LevelSelect.close(self: LevelSelect)
	self.gui.Enabled = false
end

return LevelSelect
