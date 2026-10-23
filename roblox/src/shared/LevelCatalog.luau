--!strict
-- Catálogo de la Fase 1: laboratorio de mecánicas + tutorial + w1_l1 (el catálogo
-- completo de 31 niveles llega en la Fase 2, §4.4). Los datos de cada nivel son los
-- ModuleScripts de ReplicatedStorage.Levels (JSON exportado desde Godot, esquema v1);
-- el laboratorio se genera en código (Shared/LabLevel).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Entry = {
	id: string,
	titleKey: string,
	hintKey: string,
	tutorial: boolean,
	lab: boolean,
}

local LevelCatalog = {}

LevelCatalog.entries = {
	{ id = "lab", titleKey = "SELECT_LAB", hintKey = "SELECT_LAB_HINT", tutorial = false, lab = true },
	{ id = "tutorial", titleKey = "LEVEL_TUTORIAL", hintKey = "LEVEL_TUTORIAL_HINT", tutorial = true, lab = false },
	{ id = "w1_l1", titleKey = "LEVEL_W1_L1", hintKey = "LEVEL_W1_L1_HINT", tutorial = false, lab = false },
} :: { Entry }

function LevelCatalog.get(id: string): Entry?
	for _, entry in LevelCatalog.entries do
		if entry.id == id then
			return entry
		end
	end
	return nil
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
