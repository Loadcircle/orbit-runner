--!strict
-- Textos del jugador desde la LocalizationTable nativa ReplicatedStorage.Localization.GameStrings
-- (generada de localization/strings.csv por roblox/scripts/build_localization.py), en el
-- idioma de Roblox del jugador; Source = inglés, columna es = español.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = {}

local translator: Translator? = nil

function Strings.start()
	-- GetTranslatorForPlayerAsync solo funciona con el juego publicado; la tabla se lee
	-- directamente con el idioma del jugador, igual en Studio y en producción.
	local localization = ReplicatedStorage:WaitForChild("Localization")
	local table_ = localization:WaitForChild("GameStrings") :: LocalizationTable
	local ok, result = pcall(function()
		return table_:GetTranslator(LocalizationService.RobloxLocaleId)
	end)
	if ok then
		translator = result
	end
end

-- Texto de una clave; los argumentos sustituyen {1}, {2}… Devuelve la clave si falta.
function Strings.get(key: string, ...: any): string
	if not translator then
		return key
	end
	local args = { ... }
	local ok, text = pcall(function()
		if #args > 0 then
			return translator:FormatByKey(key, args)
		end
		return translator:FormatByKey(key)
	end)
	return if ok then text else key
end

function Strings.has(key: string): boolean
	return Strings.get(key) ~= key
end

-- Formato del cronómetro (UiKit.format_time): mm:ss.cc
function Strings.formatTime(seconds: number): string
	if seconds <= 0 then
		return "--:--.--"
	end
	local minutes = math.floor(seconds / 60)
	return string.format("%02d:%05.2f", minutes, seconds % 60)
end

return Strings
