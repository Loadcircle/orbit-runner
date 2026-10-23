--!strict
-- HUD del nivel: port de scripts/ui/hud.gd. Arriba a la izquierda: retrato (miniatura
-- del avatar del jugador), cronómetro, objetivo de oro y progreso de la ruta. Arriba en
-- el centro: gemas y chispas. Arriba a la derecha: pausa, bajo los botones de Roblox
-- (GuiService.TopbarInset). En el centro: mensajes e indicaciones del tutorial.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.Parent:WaitForChild("Settings"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Theme = require(script.Parent:WaitForChild("Theme"))

export type HudSource = {
	elapsed: number,
	gems: { boolean },
	sparks: number,
	sparksTotal: number,
	goldTime: number?,
	routeProgress: (any) -> number,
}

local Hud = {}
Hud.__index = Hud

export type Hud = typeof(setmetatable({} :: {
	gui: ScreenGui,
	root: Frame,
	timeLabel: TextLabel,
	medalHint: TextLabel,
	progressFill: Frame,
	gemIcons: { TextLabel },
	sparkLabel: TextLabel,
	message: TextLabel,
	messageScale: UIScale,
	promptPanel: Frame,
	promptLabel: TextLabel,
	flash: Frame,
	timerRow: Frame,
	source: HudSource?,
	onPause: () -> (),
	_gemState: { boolean },
}, Hud))

local function tween(instance: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, props)
	t:Play()
	return t
end

function Hud.new(parent: Instance): Hud
	local gui = Theme.screen("Hud", 10, parent)
	local root = Theme.root(gui)
	local topInset = GuiService.TopbarInset.Height

	-- Arriba a la izquierda.
	local info = Theme.panel({
		Name = "Info",
		Position = UDim2.fromOffset(14, topInset + 8),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = root,
	})
	Theme.create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = info,
	})
	local row = Theme.create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Parent = info })
	Theme.list(Enum.FillDirection.Horizontal, 12).Parent = row
	local portrait = Theme.create("ImageLabel", {
		Size = UDim2.fromOffset(68, 68),
		BackgroundColor3 = Theme.CYAN,
		BackgroundTransparency = 0.5,
		LayoutOrder = 1,
		Parent = row,
	}) :: ImageLabel
	Theme.create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = portrait })
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			portrait.Image = image
		end
	end)
	local column = Theme.create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 2,
		Parent = row,
	})
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left).Parent = column
	local timerRow = Theme.create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 1,
		Parent = column,
	}) :: Frame
	Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left).Parent = timerRow
	Theme.label("⏱", 28, Theme.ORANGE, { LayoutOrder = 1, Parent = timerRow })
	local timeLabel = Theme.label("00:00.00", 32, Theme.WHITE, {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(150, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = timerRow,
	})
	local medalHint = Theme.label("", 18, Theme.DIM, { LayoutOrder = 2, Parent = column })
	local bar = Theme.create("Frame", {
		Size = UDim2.fromOffset(210, 14),
		BackgroundColor3 = Color3.new(0.03, 0.08, 0.2),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = column,
	})
	Theme.create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = bar })
	local fill = Theme.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.ORANGE,
		BorderSizePixel = 0,
		Parent = bar,
	}) :: Frame
	Theme.create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = fill })

	-- Arriba en el centro.
	local center = Theme.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, topInset + 8),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Parent = root,
	})
	Theme.list(Enum.FillDirection.Horizontal, 10).Parent = center
	local gemIcons = {}
	for i = 1, 3 do
		table.insert(gemIcons, Theme.label("◇", 40, Color3.new(1, 1, 1), { LayoutOrder = i, Parent = center }))
	end
	Theme.label("✦", 34, Theme.GOLD, { LayoutOrder = 5, Parent = center })
	local sparkLabel = Theme.label("0/0", 30, Theme.WHITE, { LayoutOrder = 6, Parent = center })

	-- Mensajes y panel de indicaciones.
	local message = Theme.label("", 56, Theme.GOLD, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, topInset + 150),
		TextTransparency = 1,
		Parent = root,
	})
	local messageScale = Instance.new("UIScale")
	messageScale.Parent = message
	local promptPanel = Theme.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, topInset + 92),
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(660, 0),
		BackgroundColor3 = Color3.new(0.05, 0.1, 0.24),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = root,
	}) :: Frame
	Theme.corner(14).Parent = promptPanel
	Theme.create("UIPadding", {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = promptPanel,
	})
	local promptLabel = Theme.label("", 24, Theme.WHITE, {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextWrapped = true,
		Font = Theme.FONT_REGULAR,
		Parent = promptPanel,
	})
	local flash = Theme.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = root,
	}) :: Frame

	local self = setmetatable({
		gui = gui,
		root = root,
		timeLabel = timeLabel,
		medalHint = medalHint,
		progressFill = fill,
		gemIcons = gemIcons,
		sparkLabel = sparkLabel,
		message = message,
		messageScale = messageScale,
		promptPanel = promptPanel,
		promptLabel = promptLabel,
		flash = flash,
		timerRow = timerRow,
		source = nil,
		onPause = function() end,
		_gemState = { false, false, false },
	}, Hud)

	-- Arriba a la derecha: pausa.
	local pause = Theme.button("II", Theme.DARK, function()
		self.onPause()
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, topInset + 8),
		Size = UDim2.fromOffset(78, 78),
		TextSize = 34,
		BackgroundTransparency = 0.25,
		Parent = root,
	})
	pause.Name = "Pause"
	Settings.changed:Connect(function()
		self:_applySettings()
	end)
	self:_applySettings()
	return self
end

function Hud._applySettings(self: Hud)
	self.timerRow.Visible = Settings.get("showTimer") == true
end

function Hud.setup(self: Hud, source: HudSource)
	self.source = source
	self._gemState = { false, false, false }
	self.medalHint.Text = if source.goldTime then Strings.get("HUD_GOLD") .. " " .. Strings.formatTime(source.goldTime) else ""
	self:hidePrompt()
	self.gui.Enabled = true
	self:update()
end

function Hud.update(self: Hud)
	local source = self.source
	if not source then
		return
	end
	self.timeLabel.Text = if source.elapsed > 0 then Strings.formatTime(source.elapsed) else "00:00.00"
	self.progressFill.Size = UDim2.fromScale(math.clamp(source:routeProgress(), 0, 1), 1)
	if source.goldTime then
		self.medalHint.TextColor3 = if source.elapsed <= source.goldTime then Theme.GOLD else Theme.DIM
	end
	for i, icon in self.gemIcons do
		local got = source.gems[i] == true
		icon.Text = if got then "◆" else "◇"
		icon.TextColor3 = if got then Theme.GEM else Color3.new(1, 1, 1)
		if got and not self._gemState[i] then
			local scale = icon:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", icon)
			scale.Scale = 1.6
			tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		self._gemState[i] = got
	end
	self.sparkLabel.Text = string.format("%d/%d", source.sparks, source.sparksTotal)
end

function Hud.flashMessage(self: Hud, text: string)
	local message = self.message
	message.Text = text
	message.TextTransparency = 0
	self.messageScale.Scale = 0.6
	tween(self.messageScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.25, function()
		if message.Text == text then
			tween(message, 0.4, { TextTransparency = 1 })
		end
	end)
end

function Hud.showPrompt(self: Hud, text: string)
	self.promptLabel.Text = text
	self.promptPanel.Visible = true
	self.promptPanel.BackgroundTransparency = 1
	self.promptLabel.TextTransparency = 1
	tween(self.promptPanel, 0.2, { BackgroundTransparency = 0.45 })
	tween(self.promptLabel, 0.2, { TextTransparency = 0 })
end

function Hud.hidePrompt(self: Hud)
	self.promptPanel.Visible = false
end

function Hud.fadeFlash(self: Hud)
	self.flash.BackgroundTransparency = 1
	tween(self.flash, 0.25, { BackgroundTransparency = 0.3 }).Completed:Once(function()
		tween(self.flash, 0.35, { BackgroundTransparency = 1 })
	end)
end

function Hud.onFinished(self: Hud)
	self:hidePrompt()
	self:flashMessage(Strings.get("HUD_GOAL"))
end

function Hud.setVisible(self: Hud, visible: boolean)
	self.gui.Enabled = visible
end

return Hud
