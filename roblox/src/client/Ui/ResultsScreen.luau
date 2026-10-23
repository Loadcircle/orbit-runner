--!strict
-- Pantalla de resultados (scripts/ui/results_screen.gd): tiempo, nuevo récord, medalla y
-- tiempos de medalla, gemas, chispas, sin caídas, estrellas de maestría y chispas
-- ganadas, con el veredicto del servidor (RunValidator). Reintentar / Siguiente / Niveles.

local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Theme = require(script.Parent:WaitForChild("Theme"))

export type Run = {
	time: number,
	gems: { boolean },
	sparks: number,
	sparksTotal: number,
	respawns: number,
	medals: { gold: number?, silver: number? }?,
	tutorial: boolean,
	hasNext: boolean,
}

export type Callbacks = { retry: () -> (), nextLevel: () -> (), levels: () -> () }

local ResultsScreen = {}
ResultsScreen.__index = ResultsScreen

export type ResultsScreen = typeof(setmetatable({} :: {
	gui: ScreenGui,
	content: Frame,
	nextButton: TextButton,
}, ResultsScreen))

function ResultsScreen.new(parent: Instance, callbacks: Callbacks): ResultsScreen
	local gui = Theme.screen("Results", 35, parent)
	gui.Enabled = false
	local root = Theme.root(gui)
	Theme.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.DARK, BackgroundTransparency = 0.4, Parent = root })
	local panel = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Theme.create("UIPadding", { PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 18), Parent = panel })
	Theme.list(Enum.FillDirection.Vertical, 10).Parent = panel
	local content = Theme.create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -40, 0, 0),
		LayoutOrder = 1,
		Parent = panel,
	}) :: Frame
	Theme.list(Enum.FillDirection.Vertical, 6).Parent = content
	local buttons = Theme.create("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 2,
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Horizontal, 12).Parent = buttons
	Theme.button(Strings.get("RESULTS_RETRY"), Theme.CYAN, callbacks.retry, { LayoutOrder = 1, Size = UDim2.fromOffset(180, 56), Parent = buttons })
	local nextButton = Theme.button(Strings.get("RESULTS_NEXT"), Theme.ORANGE, callbacks.nextLevel,
		{ LayoutOrder = 2, Size = UDim2.fromOffset(180, 56), Parent = buttons })
	Theme.button(Strings.get("RESULTS_LEVELS"), Color3.new(0.3, 0.38, 0.6), callbacks.levels,
		{ LayoutOrder = 3, Size = UDim2.fromOffset(180, 56), Parent = buttons })
	return setmetatable({ gui = gui, content = content, nextButton = nextButton }, ResultsScreen)
end

function ResultsScreen.open(self: ResultsScreen, run: Run, summary: { [string]: any }?)
	for _, child in self.content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local order = 0
	local function line(text: string, size: number, color: Color3?)
		order += 1
		Theme.label(text, size, color, { LayoutOrder = order, Parent = self.content, TextWrapped = true })
	end
	line(Strings.get("RESULTS_TITLE"), 42, Theme.GOLD)
	line(Strings.get("RESULTS_TIME") .. "  " .. Strings.formatTime(run.time), 36, Theme.WHITE)
	if summary and summary.accepted and summary.newBest then
		line(Strings.get("RESULTS_NEW_BEST"), 26, Theme.ORANGE)
	elseif summary and summary.bestTime and summary.bestTime > 0 then
		line(Strings.get("RESULTS_BEST") .. " " .. Strings.formatTime(summary.bestTime), 22, Theme.DIM)
	end
	local medal = if summary then summary.medal or 0 else 0
	if not run.tutorial and medal > 0 then
		line(Strings.get(Theme.MEDAL_KEYS[medal]), 30, Theme.MEDAL_COLORS[medal])
	end
	if not run.tutorial and run.medals and run.medals.gold then
		line(string.format("%s %s  ·  %s %s", Strings.get("MEDAL_GOLD"), Strings.formatTime(run.medals.gold),
			Strings.get("MEDAL_SILVER"), Strings.formatTime(run.medals.silver or 0)), 20, Theme.DIM)
	end
	local gems = 0
	for _, got in run.gems do
		if got then
			gems += 1
		end
	end
	line(string.format("%s %d/3   ·   %s %d/%d", Strings.get("RESULTS_GEMS"), gems, Strings.get("RESULTS_SPARKS"),
		run.sparks, run.sparksTotal), 24, Theme.WHITE)
	if run.respawns == 0 and not run.tutorial then
		line(Strings.get("RESULTS_FLAWLESS"), 24, Theme.CYAN)
	end
	if summary and summary.mastery and not run.tutorial then
		local keys = { "RESULTS_STAR_GOLD", "RESULTS_STAR_GEMS", "RESULTS_STAR_SPARKS", "RESULTS_STAR_FLAWLESS" }
		local parts = {}
		for i, star in summary.mastery do
			table.insert(parts, (if star then "★ " else "☆ ") .. Strings.get(keys[i]))
		end
		line(Strings.get("RESULTS_STARS") .. ":  " .. table.concat(parts, "   "), 18, Theme.GOLD)
	end
	if summary then
		if summary.accepted then
			line(string.format("+%d ✦   ·   %s", summary.sparksEarned or 0, Strings.get("RESULTS_SAVED")), 18, Theme.DIM)
		else
			line(Strings.get("RESULTS_REJECTED") .. " (" .. tostring(summary.reason) .. ")", 18, Theme.ORANGE)
		end
	end
	self.nextButton.Visible = run.hasNext
	self.gui.Enabled = true
end

function ResultsScreen.close(self: ResultsScreen)
	self.gui.Enabled = false
end

return ResultsScreen
