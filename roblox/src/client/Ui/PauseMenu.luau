--!strict
-- Menú de pausa (scripts/ui/pause_menu.gd): Continuar, Reiniciar, Ajustes y Salir al
-- selector.

local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Theme = require(script.Parent:WaitForChild("Theme"))

export type Callbacks = {
	resume: () -> (),
	restart: () -> (),
	settings: () -> (),
	quit: () -> (),
}

local PauseMenu = {}
PauseMenu.__index = PauseMenu

export type PauseMenu = typeof(setmetatable({} :: { gui: ScreenGui }, PauseMenu))

function PauseMenu.new(parent: Instance, callbacks: Callbacks): PauseMenu
	local gui = Theme.screen("PauseMenu", 30, parent)
	gui.Enabled = false
	local root = Theme.root(gui)
	Theme.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.DARK,
		BackgroundTransparency = 0.45,
		Parent = root,
	})
	local panel = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Theme.create("UIPadding", { PaddingTop = UDim.new(0, 22), PaddingBottom = UDim.new(0, 22), Parent = panel })
	Theme.list(Enum.FillDirection.Vertical, 14).Parent = panel
	Theme.label(Strings.get("PAUSE_TITLE"), 44, Theme.WHITE, { LayoutOrder = 1, Parent = panel })
	local order = 2
	local function add(key: string, color: Color3, action: () -> ())
		Theme.button(Strings.get(key), color, action, { LayoutOrder = order, Parent = panel, Size = UDim2.fromOffset(300, 58) })
		order += 1
	end
	add("PAUSE_RESUME", Theme.ORANGE, callbacks.resume)
	add("PAUSE_RESTART", Theme.CYAN, callbacks.restart)
	add("MENU_SETTINGS", Color3.new(0.3, 0.38, 0.6), callbacks.settings)
	add("PAUSE_QUIT", Color3.new(0.3, 0.38, 0.6), callbacks.quit)
	return setmetatable({ gui = gui }, PauseMenu)
end

function PauseMenu.open(self: PauseMenu)
	self.gui.Enabled = true
end

function PauseMenu.close(self: PauseMenu)
	self.gui.Enabled = false
end

function PauseMenu.isOpen(self: PauseMenu): boolean
	return self.gui.Enabled
end

return PauseMenu
