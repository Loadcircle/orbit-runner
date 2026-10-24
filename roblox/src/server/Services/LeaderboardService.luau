--!strict
-- Tablas de récords por nivel en OrderedDataStore (Fase 3, R22). Una tabla por nivel
-- con medallas; clave = UserId, valor = mejor tiempo en milisegundos (orden ascendente:
-- menos es mejor). Solo se escribe al batir el récord propio y solo si mejora lo
-- guardado. La lectura del top se cachea para no gastar presupuesto.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_PREFIX = "OrbitRunnerTimes_"
local TOP_SIZE = 10
local CACHE_SECONDS = 60
local MIN_REQUEST_GAP = 2 -- s entre consultas del mismo jugador

export type Entry = { rank: number, userId: number, name: string, time: number }

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: { at: number, entries: { Entry } } } = {}
local names: { [number]: string } = {}
local lastRequest: { [Player]: number } = {}
local available = true

local function storeFor(levelId: string): OrderedDataStore?
	if not available then
		return nil
	end
	local existing = stores[levelId]
	if existing then
		return existing
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_PREFIX .. levelId)
	end)
	if not ok then
		available = false
		warn("[LeaderboardService] OrderedDataStore no disponible: " .. tostring(result))
		return nil
	end
	stores[levelId] = result
	return result
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then player.DisplayName else nil
	if not name then
		local ok, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok then result else "#" .. userId
	end
	names[userId] = name :: string
	return name :: string
end

-- Publica un tiempo si mejora el guardado. Se llama en segundo plano tras un récord.
function LeaderboardService.submit(player: Player, levelId: string, time: number)
	local store = storeFor(levelId)
	if not store then
		return
	end
	local millis = math.max(1, math.round(time * 1000))
	local improved = false
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(old: any)
			if typeof(old) == "number" and old <= millis then
				improved = false
				return nil
			end
			improved = true
			return millis
		end)
	end)
	if not ok then
		warn(string.format("[LeaderboardService] no se pudo publicar %s de %s: %s", levelId, player.Name, tostring(err)))
	elseif improved then
		cache[levelId] = nil
	end
end

-- Top del nivel (cacheado). Lista vacía si no hay datos o no hay acceso.
function LeaderboardService.top(levelId: string): { Entry }
	local cached = cache[levelId]
	if cached and os.clock() - cached.at < CACHE_SECONDS then
		return cached.entries
	end
	local store = storeFor(levelId)
	if not store then
		return {}
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(true, TOP_SIZE):GetCurrentPage()
	end)
	if not ok then
		warn(string.format("[LeaderboardService] no se pudo leer %s: %s", levelId, tostring(page)))
		return if cached then cached.entries else {}
	end
	local entries: { Entry } = {}
	for index, item in page :: { { key: string, value: number } } do
		local userId = tonumber(item.key) or 0
		table.insert(entries, { rank = index, userId = userId, name = nameFor(userId), time = item.value / 1000 })
	end
	cache[levelId] = { at = os.clock(), entries = entries }
	return entries
end

-- Petición del cliente, con límite de ritmo por jugador.
function LeaderboardService.request(player: Player, levelId: string): { Entry }
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < MIN_REQUEST_GAP then
		local cached = cache[levelId]
		return if cached then cached.entries else {}
	end
	lastRequest[player] = now
	return LeaderboardService.top(levelId)
end

function LeaderboardService.clear(player: Player)
	lastRequest[player] = nil
end

return LeaderboardService
