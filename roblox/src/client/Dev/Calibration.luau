--!strict
-- Mediciones del laboratorio (H3, solo pruebas): ejecuta cada técnica con entrada
-- programada y mide alcance, altura y tiempo en el aire con los criterios de
-- orbit_runner_game/scripts/generator/movement_reach.gd:
--   gap0 = distancia horizontal hasta volver a la altura de despegue + radio de cápsula;
--   apex = altura máxima sobre el despegue; air = tiempo hasta volver a esa altura.
-- Se lanza por DebugProbe: Invoke("command", "measure", técnica[, fps]).
-- `fps` limita los fotogramas con una espera activa en RenderStepped para comprobar
-- que el resultado no depende del framerate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Units = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Units"))
local InputRouter = require(script.Parent.Parent:WaitForChild("InputRouter"))

local CAPSULE_RADIUS = 0.35
local RUN_UP = 1.4 -- s de carrera antes de la técnica

local Calibration = {}

type Sample = { t: number, feet: Vector3, vy: number, onFloor: boolean, velocity: Vector3 }

local frameCap: RBXScriptConnection? = nil

function Calibration.setFrameCap(fps: number?)
	if frameCap then
		frameCap:Disconnect()
		frameCap = nil
	end
	if not fps or fps <= 0 then
		return
	end
	local budget = 1 / fps
	local last = os.clock()
	frameCap = RunService.RenderStepped:Connect(function()
		while os.clock() - last < budget do
			-- espera activa: alarga el fotograma hasta el presupuesto
		end
		last = os.clock()
	end)
end

-- Ejecuta una técnica. `player` es el PlayerController; `place` coloca al jugador en la
-- salida de la prueba. Devuelve las medidas en metros y segundos.
function Calibration.measure(player: any, technique: string, place: (string) -> ()): { [string]: any }
	-- Si la prueba anterior acabó cayendo, se espera a su reaparición antes de colocar.
	local deadline = os.clock() + 5
	while (player.isDead or not player.onFloor) and os.clock() < deadline do
		task.wait()
	end
	task.wait(0.3)
	place(technique)
	task.wait(0.4)
	local state = { move = Vector2.new(0, 1), held = {} :: { [string]: boolean } }
	InputRouter.setScripted(state)
	local samples: { Sample } = {}
	local frames = 0
	local startClock = os.clock()
	local phase = "runup"
	local takeoff: Vector3? = nil
	local takeoffTime = 0
	local triggered = false
	local done = false
	local airborne = false
	local result: { [string]: any } = { technique = technique }

	-- En las técnicas de rebote, el origen es la posición de los pies en el instante del
	-- rebote (señal bounced), no el fotograma siguiente.
	local bounceFeet: Vector3? = nil
	local bounceTime = 0
	local bounceConnection = player.bounced:Connect(function()
		if bounceFeet == nil then
			bounceFeet = player:feet()
			bounceTime = os.clock() - startClock
		end
	end)
	-- En los saltos, el origen es la posición en el instante del salto (señal jumped).
	local jumpConnection = player.jumped:Connect(function()
		if phase == "air" then
			takeoff = player:feet()
			takeoffTime = os.clock() - startClock
		end
	end)

	local connection = RunService.PostSimulation:Connect(function()
		if done then
			return
		end
		frames += 1
		local now = os.clock() - startClock
		local feet = player:feet()
		local vy = player.velocity.Y
		if phase == "runup" then
			if technique == "yoyo_ground" and now >= 0.5 and not triggered then
				triggered = true
				InputRouter.scriptedPress("yoyo", false)
			end
			if technique == "trampoline" or technique == "trampoline_24" or technique == "yoyo_ground" then
				-- Despegue = rebote.
				if bounceFeet then
					phase = "air"
					takeoff = bounceFeet
					takeoffTime = bounceTime
				end
			elseif now >= RUN_UP then
				phase = "air"
				takeoff = feet
				takeoffTime = now
				if technique == "long" then
					InputRouter.scriptedPress("action", false)
				else
					InputRouter.scriptedPress("jump", true)
				end
			end
		elseif phase == "air" then
			local origin = takeoff :: Vector3
			table.insert(samples, { t = now - takeoffTime, feet = feet, vy = vy, onFloor = player.onFloor,
				velocity = player.rig.root.AssemblyLinearVelocity })
			if technique == "long" and not triggered and player.isSliding then
				triggered = true
				InputRouter.scriptedPress("jump", false)
				table.clear(samples)
			elseif technique == "dash" and not triggered and vy < Units.studs(1.0) and #samples > 2 then
				triggered = true
				InputRouter.scriptedPress("action", false)
			elseif technique == "yoyo_air" and not triggered and vy <= 0 and #samples > 2 then
				triggered = true
				InputRouter.scriptedPress("yoyo", false)
			end
			if not player.onFloor then
				airborne = true
			end
			local below = feet.Y <= origin.Y - Units.studs(0.02)
			if (airborne and player.onFloor) or below or now - takeoffTime > 4 then
				done = true
			end
		end
	end)
	local timeout = os.clock() + 10
	while not done and os.clock() < timeout do
		task.wait()
	end
	connection:Disconnect()
	bounceConnection:Disconnect()
	jumpConnection:Disconnect()
	InputRouter.setScripted(nil)

	local origin = takeoff or player:feet()
	local apex = 0
	local crossing: { horizontal: number, t: number }? = nil
	local gravity = Units.studs(45)
	for i, sample in samples do
		apex = math.max(apex, sample.feet.Y - origin.Y)
		-- Último cruce de la altura de despegue bajando. Se calcula balísticamente desde
		-- la muestra anterior (la siguiente puede estar ya apoyada en la pista), como la
		-- interpolación de movement_reach.gd.
		local previous = samples[i - 1]
		local landed = sample.onFloor or sample.feet.Y <= origin.Y + 0.05
		if previous and not previous.onFloor and previous.feet.Y > origin.Y + 0.05 and landed then
			local height = previous.feet.Y - origin.Y
			local vy = previous.velocity.Y
			local t = (vy + math.sqrt(math.max(vy * vy + 2 * gravity * height, 0))) / gravity
			local flatVelocity = Vector3.new(previous.velocity.X, 0, previous.velocity.Z)
			local at = Vector3.new(previous.feet.X, 0, previous.feet.Z) + flatVelocity * t
			crossing = {
				horizontal = (at - Vector3.new(origin.X, 0, origin.Z)).Magnitude,
				t = previous.t + t,
			}
		end
	end
	if crossing then
		result.gap0 = Units.meters(crossing.horizontal) + CAPSULE_RADIUS
		result.air = crossing.t
	end
	result.apex = Units.meters(apex)
	result.frames = frames
	result.fps = frames / math.max(os.clock() - startClock, 1e-3)
	return result
end

return Calibration
