--!strict
-- Activadores por solapamiento contra la cápsula de juego (guía §3.5): en cada fotograma
-- se consulta workspace:GetPartsInPart(hitbox) con OverlapParams filtrados a las carpetas
-- de activadores, en lugar de Touched (poco fiable a alta velocidad).
-- Reproduce las señales de Area3D de Godot: onEnter (body_entered), onStay (las que en
-- Godot recorren get_overlapping_bodies cada fotograma) y onExit (body_exited).

local Workspace = game:GetService("Workspace")

export type Handler = {
	onEnter: ((part: BasePart) -> ())?,
	onStay: ((part: BasePart, dt: number) -> ())?,
	onExit: ((part: BasePart) -> ())?,
}

local Triggers = {}
Triggers.__index = Triggers

export type Triggers = typeof(setmetatable({} :: {
	handlers: { [BasePart]: Handler },
	inside: { [BasePart]: boolean },
	params: OverlapParams,
	roots: { Instance },
}, Triggers))

function Triggers.new(): Triggers
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.RespectCanCollide = false
	return setmetatable({ handlers = {}, inside = {}, params = params, roots = {} }, Triggers)
end

function Triggers.addRoot(self: Triggers, root: Instance)
	table.insert(self.roots, root)
	self.params.FilterDescendantsInstances = self.roots
end

function Triggers.register(self: Triggers, part: BasePart, handler: Handler)
	self.handlers[part] = handler
end

function Triggers.unregister(self: Triggers, part: BasePart)
	self.handlers[part] = nil
	self.inside[part] = nil
end

-- Olvida los solapamientos actuales sin disparar onExit (reaparición: en Godot el
-- jugador se teletransporta y las áreas vuelven a detectar la entrada).
function Triggers.reset(self: Triggers)
	table.clear(self.inside)
end

function Triggers.step(self: Triggers, hitbox: BasePart, dt: number)
	local touching: { [BasePart]: boolean } = {}
	for _, part in Workspace:GetPartsInPart(hitbox, self.params) do
		if self.handlers[part] then
			touching[part] = true
		end
	end
	for part in touching do
		local handler = self.handlers[part]
		if not handler then
			continue -- un handler anterior pudo retirar el activador
		end
		if not self.inside[part] then
			self.inside[part] = true
			if handler.onEnter then
				handler.onEnter(part)
			end
		end
		if self.handlers[part] and handler.onStay then
			handler.onStay(part, dt)
		end
	end
	for part in self.inside do
		if not touching[part] then
			self.inside[part] = nil
			local handler = self.handlers[part]
			if handler and handler.onExit then
				handler.onExit(part)
			end
		end
	end
end

return Triggers
