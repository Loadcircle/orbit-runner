--!strict
-- Reloj común del nivel: segundos desde que se construyó, sin contar las pausas.
-- Todos los props animados derivan su estado de este tiempo + su `phase`, igual que en
-- Godot cada prop acumula su propio delta desde _ready (todos empiezan a la vez), así
-- que la sincronización no cambia al morir y reaparecer.

local LevelClock = {}
LevelClock.__index = LevelClock

export type LevelClock = typeof(setmetatable({} :: { time: number, paused: boolean }, LevelClock))

function LevelClock.new(): LevelClock
	return setmetatable({ time = 0, paused = false }, LevelClock)
end

function LevelClock.advance(self: LevelClock, dt: number): number
	if self.paused then
		return 0
	end
	self.time += dt
	return dt
end

return LevelClock
