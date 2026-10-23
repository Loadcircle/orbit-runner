--!strict
-- Ajustes del jugador (settings.gd). En la Fase 1 viven en memoria; la persistencia en
-- DataStore llega en la Fase 3. Sin idioma (Roblox lo da) ni calidad/FPS (los gestiona
-- Roblox) ni notificaciones. Tampoco controles táctiles ni sensibilidad de cámara: son
-- los nativos de Roblox (R14) y se ajustan en su menú.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local DEFAULTS = {
	masterVolume = 0.9,
	musicVolume = 0.7,
	sfxVolume = 0.9,
	vibration = true,
	screenShake = true,
	showTimer = true,
	showGhost = true,
}

export type Key =
	"masterVolume"
	| "musicVolume"
	| "sfxVolume"
	| "vibration"
	| "screenShake"
	| "showTimer"
	| "showGhost"

local Settings = {}
Settings.changed = Signal.new() :: Signal.Signal<string, any>

local values: { [string]: any } = table.clone(DEFAULTS)

function Settings.get(key: Key): any
	return values[key]
end

function Settings.set(key: Key, value: any)
	if values[key] == value then
		return
	end
	values[key] = value
	Settings.changed:Fire(key, value)
end

function Settings.defaults(): { [string]: any }
	return table.clone(DEFAULTS)
end

return Settings
