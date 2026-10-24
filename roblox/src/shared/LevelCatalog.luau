--!strict
-- Catálogo: laboratorio de mecánicas + tutorial + mundo 1 (Fase 2, R20; aprobado 2026-10-24). Los datos de
-- cada nivel son los ModuleScripts de ReplicatedStorage.Levels (JSON del esquema v1,
-- generados con roblox/scripts/build_*.py); el laboratorio se genera en código
-- (Shared/LabLevel). `pending` marca los niveles que el dueño aún no ha aprobado.
-- `world` agrupa los niveles por portal del vestíbulo (0 = laboratorio, R23).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Entry = {
	id: string,
	titleKey: string,
	hintKey: string,
	tutorial: boolean,
	lab: boolean,
	world: number,
	pending: boolean?,
}

local LevelCatalog = {}

LevelCatalog.entries = {
	{ id = "lab", titleKey = "SELECT_LAB", hintKey = "SELECT_LAB_HINT", tutorial = false, lab = true, world = 0 },
	{ id = "tutorial", titleKey = "LEVEL_TUTORIAL", hintKey = "LEVEL_TUTORIAL_HINT", tutorial = true, lab = false, world = 1 },
} :: { Entry }

for index = 1, 10 do
	local key = "LEVEL_W1_L" .. index
	table.insert(LevelCatalog.entries, {
		id = "w1_l" .. index,
		titleKey = key,
		hintKey = key .. "_HINT",
		tutorial = false,
		lab = false,
		world = 1,
	})
end

function LevelCatalog.get(id: string): Entry?
	for _, entry in LevelCatalog.entries do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Niveles de un mundo, en orden de campaña.
function LevelCatalog.world(world: number): { Entry }
	local list = {}
	for _, entry in LevelCatalog.entries do
		if entry.world == world then
			table.insert(list, entry)
		end
	end
	return list
end

-- Desbloqueo (progress.gd: is_unlocked, ampliado en R23): abiertos todos los niveles de
-- la campaña hasta el siguiente al más avanzado completado. Para un jugador nuevo es la
-- regla de Godot (el primero, y cada uno al completar el anterior); además no deja
-- huecos si se completó un nivel posterior (perfiles anteriores al bloqueo). El
-- laboratorio siempre está abierto.
function LevelCatalog.isUnlocked(id: string, isCompleted: (id: string) -> boolean): boolean
	local campaign = {}
	for _, entry in LevelCatalog.entries do
		if entry.lab then
			if entry.id == id then
				return true
			end
		else
			table.insert(campaign, entry.id)
		end
	end
	local highest = 0
	local target = 0
	for index, entryId in campaign do
		if isCompleted(entryId) then
			highest = index
		end
		if entryId == id then
			target = index
		end
	end
	return target > 0 and target <= highest + 1
end

-- Datos del nivel (tabla con el esquema JSON v1).
function LevelCatalog.data(id: string): { [string]: any }?
	if id == "lab" then
		return require(script.Parent:WaitForChild("LabLevel")) :: any
	end
	local levels = ReplicatedStorage:WaitForChild("Levels")
	local module = levels:FindFirstChild(id)
	if module and module:IsA("ModuleScript") then
		return require(module) :: any
	end
	return nil
end

-- Medalla por tiempo (progress.gd: medal_for_time). 0 = ninguna, 1 bronce, 2 plata, 3 oro.
function LevelCatalog.medalForTime(data: { [string]: any }, time: number): number
	local medals = data.medals
	if data.tutorial or not medals or medals.gold == nil then
		return 0
	end
	if time <= medals.gold then
		return 3
	elseif time <= medals.silver then
		return 2
	end
	return 1
end

return LevelCatalog
