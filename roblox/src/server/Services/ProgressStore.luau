--!strict
-- Persistencia del progreso en DataStoreService (Fase 3, R22). Un documento por UserId
-- con bloqueo de sesión: el servidor que carga el perfil escribe su id en `lock` y solo
-- él puede guardarlo mientras lo tenga. Otro servidor espera a que se libere o, si el
-- bloqueo está caducado (servidor caído), lo toma. Si DataStore no responde (o Studio no
-- tiene acceso a las API), el perfil queda solo en memoria y NUNCA se escribe, para no
-- pisar datos buenos con un perfil vacío.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local STORE_NAME = "OrbitRunnerProgress"
local SCHEMA = 1
local AUTOSAVE_INTERVAL = 30 -- s: se guardan los perfiles con cambios
local LOCK_REFRESH = 120 -- s: se renueva el bloqueo aunque no haya cambios
local LOCK_STALE = 300 -- s: un bloqueo sin renovar más tiempo es de un servidor caído
local LOAD_LOCK_WAIT = 6 -- s entre intentos mientras otro servidor tiene el perfil
local LOAD_LOCK_TRIES = 4 -- tras ~20 s el perfil se toma (el otro ya no podrá guardar)
local REQUEST_TRIES = 3
local CLOSE_TIMEOUT = 25 -- s de margen en BindToClose (Roblox da 30)

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

type Session = {
	profile: Profile,
	persistent: boolean, -- false: DataStore no disponible, solo memoria
	lost: boolean, -- otro servidor tomó el bloqueo: ya no se guarda
	released: boolean, -- ya se liberó el bloqueo (salida o cierre): no más escrituras
	dirty: boolean,
	lastWrite: number,
	saving: boolean,
}

local ProgressStore = {}

local serverId = HttpService:GenerateGUID(false)
local store: GlobalDataStore? = nil
local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local closing = false
local activeSaves = 0 -- guardados en curso; BindToClose espera a que acaben

local function keyFor(userId: number): string
	return "player_" .. userId
end

function ProgressStore.newRecord(): LevelRecord
	return {
		completed = false,
		bestTime = 0,
		medal = 0,
		gems = { false, false, false },
		bestSparks = 0,
		sparksTotal = 0,
		flawless = false,
		allSparks = false,
	}
end

-- Copia los datos guardados en un perfil con la forma actual, ignorando lo que no
-- cuadre (versiones futuras o datos corruptos no rompen la carga).
local function sanitize(raw: any): Profile
	local profile: Profile = { sparks = 0, levels = {} }
	if typeof(raw) ~= "table" then
		return profile
	end
	if typeof(raw.sparks) == "number" then
		profile.sparks = math.max(0, math.floor(raw.sparks))
	end
	if typeof(raw.levels) == "table" then
		for id, saved in raw.levels do
			if typeof(id) == "string" and typeof(saved) == "table" then
				local record = ProgressStore.newRecord()
				for field, default in record :: any do
					local value = saved[field]
					if field == "gems" then
						if typeof(value) == "table" then
							for i = 1, 3 do
								record.gems[i] = value[i] == true
							end
						end
					elseif typeof(value) == typeof(default) then
						(record :: any)[field] = value
					end
				end
				profile.levels[id] = record
			end
		end
	end
	return profile
end

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local started = os.clock()
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and os.clock() - started < 10 do
		task.wait(1)
	end
end

-- UpdateAsync con reintentos. Devuelve ok y el valor que quedó guardado.
local function update(key: string, transform: (any) -> any): (boolean, any)
	local activeStore = store
	if not activeStore then
		return false, "no_store"
	end
	local lastError: any = nil
	for attempt = 1, REQUEST_TRIES do
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local ok, result = pcall(function()
			return activeStore:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		lastError = result
		local message = tostring(result)
		if string.find(message, "403", 1, true) or string.find(message, "StudioAccessToApis", 1, true) then
			-- Studio sin "Enable Studio Access to API Services": no tiene sentido reintentar.
			store = nil
			break
		end
		if attempt < REQUEST_TRIES then
			task.wait(2 ^ attempt)
		end
	end
	return false, lastError
end

-- Carga el perfil tomando el bloqueo. Devuelve el perfil y si se puede guardar.
local function loadProfile(player: Player): (Profile, boolean)
	if not store then
		return sanitize(nil), false
	end
	local key = keyFor(player.UserId)
	for attempt = 1, LOAD_LOCK_TRIES + 1 do
		local force = attempt > LOAD_LOCK_TRIES
		local blocked = false
		local ok, result = update(key, function(old: any)
			blocked = false
			local lock = if typeof(old) == "table" then old.lock else nil
			local now = os.time()
			if not force and typeof(lock) == "table" and lock.id ~= serverId
				and typeof(lock.at) == "number" and now - lock.at < LOCK_STALE then
				blocked = true
				return nil -- otro servidor lo tiene: no escribir y reintentar
			end
			local saved = if typeof(old) == "table" then old else {}
			saved.schema = SCHEMA
			saved.lock = { id = serverId, at = now }
			return saved
		end)
		if not ok then
			warn(string.format("[ProgressStore] no se pudo cargar a %s: %s (progreso solo en memoria)",
				player.Name, tostring(result)))
			return sanitize(nil), false
		end
		if not blocked then
			if force then
				warn(string.format("[ProgressStore] bloqueo de %s tomado tras esperar", player.Name))
			end
			return sanitize(if typeof(result) == "table" then result.data else nil), true
		end
		task.wait(LOAD_LOCK_WAIT)
	end
	return sanitize(nil), false -- no se llega: el último intento fuerza
end

local function save(player: Player, session: Session, release: boolean)
	if not session.persistent or session.lost or session.released then
		return
	end
	activeSaves += 1 -- desde aquí, también mientras espera a otro guardado del mismo perfil
	while session.saving do
		task.wait(0.1)
	end
	if session.released or session.lost then
		activeSaves -= 1
		return
	end
	session.released = release
	session.saving = true
	session.dirty = false
	local data = session.profile
	local lost = false
	local ok, err = update(keyFor(player.UserId), function(old: any)
		lost = false
		local lock = if typeof(old) == "table" then old.lock else nil
		if typeof(lock) == "table" and lock.id ~= serverId then
			lost = true
			return nil
		end
		return {
			schema = SCHEMA,
			data = data,
			lock = if release then nil else { id = serverId, at = os.time() },
			savedAt = os.time(),
		}
	end)
	session.saving = false
	activeSaves -= 1
	if not ok then
		session.dirty = true -- se reintenta en el siguiente autoguardado
		warn(string.format("[ProgressStore] fallo al guardar a %s: %s", player.Name, tostring(err)))
	elseif lost then
		session.lost = true
		warn(string.format("[ProgressStore] %s abrió el perfil en otro servidor; este deja de guardar", player.Name))
	else
		session.lastWrite = os.clock()
	end
end

-- Perfil del jugador; espera a que termine la carga (nil si se fue antes).
function ProgressStore.get(player: Player): Profile?
	while loading[player] do
		task.wait(0.1)
	end
	local session = sessions[player]
	return if session then session.profile else nil
end

function ProgressStore.isPersistent(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.persistent and not session.lost
end

function ProgressStore.markDirty(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = true
	end
end

local function onPlayerAdded(player: Player)
	loading[player] = true
	local profile, persistent = loadProfile(player)
	local session: Session = {
		profile = profile,
		persistent = persistent,
		lost = false,
		released = false,
		dirty = false,
		lastWrite = os.clock(),
		saving = false,
	}
	loading[player] = nil
	if player.Parent ~= Players then
		save(player, session, true) -- se fue durante la carga: libera el bloqueo
		return
	end
	sessions[player] = session
	local levelCount = 0
	for _ in profile.levels do
		levelCount += 1
	end
	print(string.format("[ProgressStore] %s cargado (%s, %d niveles)", player.Name,
		if persistent then "DataStore" else "solo memoria", levelCount))
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	save(player, session, true)
end

function ProgressStore.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[ProgressStore] DataStore no disponible: " .. tostring(result))
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	task.spawn(function()
		while not closing do
			task.wait(AUTOSAVE_INTERVAL)
			for player, session in sessions do
				if session.dirty or os.clock() - session.lastWrite > LOCK_REFRESH then
					task.spawn(save, player, session, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		closing = true
		for player, session in sessions do
			task.spawn(save, player, session, true)
		end
		task.wait() -- deja arrancar los guardados recién lanzados
		local started = os.clock()
		while (activeSaves > 0 or next(loading) ~= nil) and os.clock() - started < CLOSE_TIMEOUT do
			task.wait(0.1)
		end
	end)
end

return ProgressStore
