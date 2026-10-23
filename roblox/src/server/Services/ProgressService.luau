--!strict
-- Progreso del jugador en el servidor (port de progress.gd: submit_run, mastery). En la
-- Fase 1 se guarda EN MEMORIA; la persistencia con DataStore llega en la Fase 3.
-- Conecta los RemoteEvents de Shared/Net con RunValidator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCatalog = require(Shared:WaitForChild("LevelCatalog"))
local RunValidator = require(script.Parent:WaitForChild("RunValidator"))

local Net = Shared:WaitForChild("Net")

export type LevelRecord = {
	completed: boolean,
	bestTime: number,
	medal: number,
	gems: { boolean },
	bestSparks: number,
	sparksTotal: number,
	flawless: boolean,
	allSparks: boolean,
}

export type Profile = { sparks: number, levels: { [string]: LevelRecord } }

local ProgressService = {}

local profiles: { [Player]: Profile } = {}

local function profileFor(player: Player): Profile
	local profile = profiles[player]
	if not profile then
		profile = { sparks = 0, levels = {} }
		profiles[player] = profile
	end
	return profile
end

local function recordFor(profile: Profile, levelId: string): LevelRecord
	local record = profile.levels[levelId]
	if not record then
		record = {
			completed = false,
			bestTime = 0,
			medal = 0,
			gems = { false, false, false },
			bestSparks = 0,
			sparksTotal = 0,
			flawless = false,
			allSparks = false,
		}
		profile.levels[levelId] = record
	end
	return record
end

-- Estrellas de maestría (D18): oro, las 3 gemas, todas las chispas en un intento y sin
-- reapariciones. Acumulativas entre intentos, como en Godot.
function ProgressService.mastery(record: LevelRecord): { boolean }
	local gemsAll = record.gems[1] and record.gems[2] and record.gems[3]
	return { record.medal >= 3, gemsAll, record.allSparks, record.flawless }
end

local function countStars(stars: { boolean }): number
	local count = 0
	for _, star in stars do
		if star then
			count += 1
		end
	end
	return count
end

function ProgressService.submit(player: Player, report: RunValidator.Report): { [string]: any }
	local accepted, reason, run = RunValidator.finish(player, report)
	if not accepted or not run then
		warn(string.format("[ProgressService] intento de %s rechazado: %s", player.Name, reason))
		return { accepted = false, reason = reason }
	end
	local data = run.data
	local profile = profileFor(player)
	local record = recordFor(profile, run.levelId)
	local tutorial = data.tutorial == true
	local wasCompleted = record.completed
	local time = report.time
	local summary: { [string]: any } = {
		accepted = true,
		firstClear = not wasCompleted,
		newBest = record.bestTime <= 0 or time < record.bestTime,
		previousBest = record.bestTime,
		medal = 0,
		medalImproved = false,
		newGems = 0,
		sparksEarned = report.sparks,
	}
	record.completed = true
	if summary.newBest then
		record.bestTime = time
	end
	if not tutorial then
		local medal = LevelCatalog.medalForTime(data, time)
		summary.medal = medal
		if medal > record.medal then
			record.medal = medal
			summary.medalImproved = wasCompleted
		end
	end
	for i = 1, 3 do
		if run.gems[i] and not record.gems[i] then
			record.gems[i] = true
			summary.newGems += 1
		end
	end
	record.bestSparks = math.max(record.bestSparks, report.sparks)
	local starsBefore = if tutorial then 0 else countStars(ProgressService.mastery(record))
	local sparksTotal = #((data.collectibles or {}).sparks or {})
	record.sparksTotal = sparksTotal
	if not tutorial then
		record.flawless = record.flawless or report.respawns == 0
		record.allSparks = record.allSparks or (report.sparks >= sparksTotal and sparksTotal > 0)
	end
	summary.mastery = ProgressService.mastery(record)
	summary.masteryNew = (if tutorial then 0 else countStars(summary.mastery)) - starsBefore
	profile.sparks += report.sparks
	summary.wallet = profile.sparks
	summary.bestTime = record.bestTime
	print(string.format("[ProgressService] %s terminó %s en %.2f s (medalla %d, chispas %d/%d)", player.Name,
		run.levelId, time, summary.medal, report.sparks, sparksTotal))
	return summary
end

-- Resumen para el selector y para las gemas fantasma.
function ProgressService.snapshot(player: Player): { [string]: any }
	local profile = profileFor(player)
	local levels = {}
	for id, record in profile.levels do
		levels[id] = {
			bestTime = record.bestTime,
			medal = record.medal,
			gems = table.clone(record.gems),
			mastery = ProgressService.mastery(record),
		}
	end
	return { sparks = profile.sparks, levels = levels }
end

function ProgressService.start()
	local runStart = Net:WaitForChild("RunStart") :: RemoteEvent
	local runCheckpoint = Net:WaitForChild("RunCheckpoint") :: RemoteEvent
	local runGem = Net:WaitForChild("RunGem") :: RemoteEvent
	local runFinish = Net:WaitForChild("RunFinish") :: RemoteFunction
	local getProgress = Net:WaitForChild("GetProgress") :: RemoteFunction
	runStart.OnServerEvent:Connect(function(player: Player, levelId: any)
		if typeof(levelId) == "string" then
			RunValidator.start(player, levelId)
		end
	end)
	runCheckpoint.OnServerEvent:Connect(function(player: Player, index: any)
		RunValidator.checkpoint(player, index)
	end)
	runGem.OnServerEvent:Connect(function(player: Player, index: any)
		RunValidator.gem(player, index)
	end)
	runFinish.OnServerInvoke = function(player: Player, report: any)
		return ProgressService.submit(player, report)
	end
	getProgress.OnServerInvoke = function(player: Player)
		return ProgressService.snapshot(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
		RunValidator.clear(player)
	end)
end

return ProgressService
