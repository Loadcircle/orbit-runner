--!strict
-- Progreso del jugador en el servidor (port de progress.gd: submit_run, mastery). Desde
-- la Fase 3 (R22) el perfil se guarda en DataStore (ProgressStore) y los récords se
-- publican en tablas por nivel (LeaderboardService). Conecta los RemoteEvents de
-- Shared/Net con RunValidator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCatalog = require(Shared:WaitForChild("LevelCatalog"))
local HubService = require(script.Parent:WaitForChild("HubService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local ProgressStore = require(script.Parent:WaitForChild("ProgressStore"))
local RunValidator = require(script.Parent:WaitForChild("RunValidator"))

local Net = Shared:WaitForChild("Net")

export type LevelRecord = ProgressStore.LevelRecord
export type Profile = ProgressStore.Profile

local ProgressService = {}

local function recordFor(profile: Profile, levelId: string): LevelRecord
	local record = profile.levels[levelId]
	if not record then
		record = ProgressStore.newRecord()
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

-- Estrellas de maestría de toda la campaña: métrica PROVISIONAL del ranking (R23).
local function totalStars(profile: Profile): number
	local total = 0
	for id, record in profile.levels do
		local entry = LevelCatalog.get(id)
		if entry and not entry.tutorial and not entry.lab then
			total += countStars(ProgressService.mastery(record))
		end
	end
	return total
end

local function isCompletedFor(profile: Profile): (id: string) -> boolean
	return function(id: string): boolean
		local record = profile.levels[id]
		return record ~= nil and record.completed
	end
end

function ProgressService.submit(player: Player, report: RunValidator.Report): { [string]: any }
	local accepted, reason, run = RunValidator.finish(player, report)
	if not accepted or not run then
		warn(string.format("[ProgressService] intento de %s en %s rechazado: %s (%.2f s)", player.Name,
			if run then run.levelId else "?", reason, if typeof(report) == "table" and typeof(report.time) == "number" then report.time else -1))
		return { accepted = false, reason = reason }
	end
	local data = run.data
	local profile = ProgressStore.get(player)
	if not profile then
		return { accepted = false, reason = "no_profile" }
	end
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
	summary.persistent = ProgressStore.isPersistent(player)
	ProgressStore.markDirty(player)
	if summary.newBest and not tutorial then
		task.spawn(LeaderboardService.submit, player, run.levelId, time)
	end
	if summary.masteryNew > 0 then
		task.spawn(HubService.submitStars, player, totalStars(profile))
	end
	print(string.format("[ProgressService] %s terminó %s en %.2f s (medalla %d, chispas %d/%d)", player.Name,
		run.levelId, time, summary.medal, report.sparks, sparksTotal))
	return summary
end

-- Resumen para el selector y para las gemas fantasma.
function ProgressService.snapshot(player: Player): { [string]: any }
	local profile = ProgressStore.get(player)
	if not profile then
		return { sparks = 0, levels = {}, persistent = false }
	end
	local levels = {}
	for id, record in profile.levels do
		levels[id] = {
			completed = record.completed,
			bestTime = record.bestTime,
			medal = record.medal,
			gems = table.clone(record.gems),
			mastery = ProgressService.mastery(record),
		}
	end
	local unlocked = {}
	local isCompleted = isCompletedFor(profile)
	for _, entry in LevelCatalog.entries do
		unlocked[entry.id] = LevelCatalog.isUnlocked(entry.id, isCompleted)
	end
	return {
		sparks = profile.sparks,
		stars = totalStars(profile),
		levels = levels,
		unlocked = unlocked,
		persistent = ProgressStore.isPersistent(player),
	}
end

function ProgressService.start()
	local runStart = Net:WaitForChild("RunStart") :: RemoteEvent
	local runCheckpoint = Net:WaitForChild("RunCheckpoint") :: RemoteEvent
	local runGem = Net:WaitForChild("RunGem") :: RemoteEvent
	local runFinish = Net:WaitForChild("RunFinish") :: RemoteFunction
	local getProgress = Net:WaitForChild("GetProgress") :: RemoteFunction
	local getLeaderboard = Net:WaitForChild("GetLeaderboard") :: RemoteFunction
	ProgressStore.start()
	runStart.OnServerEvent:Connect(function(player: Player, levelId: any)
		if typeof(levelId) ~= "string" then
			return
		end
		local profile = ProgressStore.get(player)
		if profile and not LevelCatalog.isUnlocked(levelId, isCompletedFor(profile)) then
			warn(string.format("[ProgressService] %s intentó empezar %s sin desbloquear", player.Name, levelId))
			RunValidator.clear(player)
			return
		end
		RunValidator.start(player, levelId)
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
	getLeaderboard.OnServerInvoke = function(player: Player, levelId: any)
		if typeof(levelId) ~= "string" then
			return {}
		end
		local entry = LevelCatalog.get(levelId)
		if not entry or entry.lab or entry.tutorial then
			return {}
		end
		return LeaderboardService.request(player, levelId)
	end
	-- Publica en el ranking las estrellas que ya trae el perfil (ProgressStore conecta
	-- antes su PlayerAdded, así que get() espera a la carga).
	local function publishStars(player: Player)
		local profile = ProgressStore.get(player)
		if profile then
			HubService.submitStars(player, totalStars(profile))
		end
	end
	Players.PlayerAdded:Connect(publishStars)
	for _, player in Players:GetPlayers() do
		task.spawn(publishStars, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		RunValidator.clear(player)
		LeaderboardService.clear(player)
	end)
end

return ProgressService
