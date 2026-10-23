--!strict
-- Valida en el servidor que un intento tenga sentido antes de registrarlo (guía §2.3):
-- orden de checkpoints, tiempo mínimo plausible (≥ 0.6 × oro), duración real del
-- intento según el reloj del servidor, chispas ≤ total del nivel, gemas válidas y ritmo
-- de envío. Si algo no cuadra, el resultado no se registra (no se expulsa a nadie).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LevelCatalog"))

local MIN_GOLD_FRACTION = 0.6
local CLOCK_TOLERANCE = 2.0 -- s: el tiempo del cliente no puede superar el real + margen
local MAX_EVENTS_PER_SECOND = 20

export type Run = {
	levelId: string,
	data: { [string]: any },
	startedAt: number,
	checkpoints: { number },
	gems: { boolean },
	events: number,
	eventsWindow: number,
	finished: boolean,
}

export type Report = { time: number, sparks: number, gems: { boolean }, respawns: number }

local RunValidator = {}

local runs: { [Player]: Run } = {}

local function rateLimited(run: Run): boolean
	local now = os.clock()
	if now - run.eventsWindow > 1 then
		run.eventsWindow = now
		run.events = 0
	end
	run.events += 1
	return run.events > MAX_EVENTS_PER_SECOND
end

function RunValidator.start(player: Player, levelId: string): boolean
	local entry = LevelCatalog.get(levelId)
	if not entry or entry.lab then
		runs[player] = nil
		return false
	end
	local data = LevelCatalog.data(levelId)
	if not data then
		return false
	end
	runs[player] = {
		levelId = levelId,
		data = data,
		startedAt = os.clock(),
		checkpoints = {},
		gems = { false, false, false },
		events = 0,
		eventsWindow = os.clock(),
		finished = false,
	}
	return true
end

function RunValidator.checkpoint(player: Player, index: number)
	local run = runs[player]
	if not run or run.finished or rateLimited(run) or typeof(index) ~= "number" then
		return
	end
	table.insert(run.checkpoints, index)
end

function RunValidator.gem(player: Player, index: number)
	local run = runs[player]
	if not run or run.finished or rateLimited(run) or typeof(index) ~= "number" then
		return
	end
	if index >= 0 and index <= 2 then
		run.gems[index + 1] = true
	end
end

-- Devuelve (aceptado, motivo, run).
function RunValidator.finish(player: Player, report: Report): (boolean, string, Run?)
	local run = runs[player]
	if not run or run.finished then
		return false, "no_run", nil
	end
	run.finished = true
	if typeof(report) ~= "table" or typeof(report.time) ~= "number" or typeof(report.sparks) ~= "number" then
		return false, "bad_report", run
	end
	local data = run.data
	local elapsed = os.clock() - run.startedAt
	if report.time > elapsed + CLOCK_TOLERANCE then
		return false, "clock", run
	end
	local medals = data.medals
	if not data.tutorial and medals and medals.gold and report.time < medals.gold * MIN_GOLD_FRACTION then
		return false, "too_fast", run
	end
	local sparksTotal = #((data.collectibles or {}).sparks or {})
	if report.sparks < 0 or report.sparks > sparksTotal then
		return false, "sparks", run
	end
	-- Los checkpoints solo pueden activarse una vez y en orden de recorrido.
	local checkpointCount = #(data.checkpoints or {})
	local last = 0
	for _, index in run.checkpoints do
		if index <= last or index > checkpointCount then
			return false, "checkpoints", run
		end
		last = index
	end
	-- Las gemas del informe deben coincidir con las notificadas durante el intento.
	if typeof(report.gems) == "table" then
		for i = 1, 3 do
			if report.gems[i] == true and not run.gems[i] then
				return false, "gems", run
			end
		end
	end
	return true, "ok", run
end

function RunValidator.clear(player: Player)
	runs[player] = nil
end

return RunValidator
