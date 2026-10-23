--!strict
-- Valores de movimiento en METROS, transcritos de orbit_runner_game/scripts/data/movement_tuning.gd
-- (resources/player/movement_tuning.tres usa los valores por defecto) y de player.gd.
-- Son hipótesis de prototipo ajustadas en Godot. Se convierten a studs con `scaled()`.

local Units = require(script.Parent.Units)

local MovementTuning = {
	-- Suelo
	runSpeed = 8.0,
	groundAcceleration = 38.0,
	groundDeceleration = 48.0,
	turnAcceleration = 70.0,
	-- Aire
	airAcceleration = 20.0,
	airDeceleration = 6.0,
	gravityUp = 28.0,
	gravityDown = 45.0,
	maxFallSpeed = 32.0,
	jumpVelocity = 11.5,
	jumpCut = 0.45, -- fracción de la velocidad vertical que queda al soltar pronto
	coyoteTime = 0.12,
	jumpBuffer = 0.13,
	-- Deslizamiento / salto largo
	slideSpeed = 11.0,
	slideDuration = 0.6,
	slideFriction = 9.0,
	slideCooldown = 0.25,
	slideMinSpeed = 2.5, -- velocidad horizontal mínima para empezar (player.gd)
	slideSpeedFloor = 0.6, -- fracción de runSpeed por debajo de la que no baja
	slideSteering = 2.5, -- giro ligero durante el deslizamiento (1/s)
	longJumpSpeed = 12.5,
	longJumpVelocity = 9.5,
	-- Dash aéreo
	dashSpeed = 15.0,
	dashDuration = 0.18,
	dashLift = 1.5,
	dashExitSpeed = 10.0,
	-- Yo-yo cinético
	yoyoBounceVelocity = 16.0,
	yoyoDiscLifetime = 1.5,
	yoyoGroundDistance = 4.0,
	yoyoAirDrop = 1.4,
	yoyoAirLead = 0.32, -- segundos de velocidad horizontal
	yoyoFlightTime = 0.14,
	yoyoReturnTime = 0.3,
	yoyoFallingSpeed = 3.0, -- FALLING_YOYO_SPEED: por debajo, el disco se despliega bajo los pies
	-- Sensación
	rotationSpeed = 14.0,
	boostDecay = 4.0, -- en el aire; en suelo ×2.5
	-- Cuerpo (player.gd / player.tscn)
	floorSnap = 0.35,
	floorMaxAngle = 48.0, -- grados
	capsuleRadius = 0.35,
	standHeight = 1.5,
	slideHeight = 0.8,
	spawnGrace = 0.35,
}

-- Claves que no son distancias (tiempos, fracciones, ángulos, 1/s): no se escalan.
local UNITLESS = {
	jumpCut = true,
	coyoteTime = true,
	jumpBuffer = true,
	slideDuration = true,
	slideCooldown = true,
	slideSpeedFloor = true,
	slideSteering = true,
	dashDuration = true,
	yoyoDiscLifetime = true,
	yoyoAirLead = true,
	yoyoFlightTime = true,
	yoyoReturnTime = true,
	rotationSpeed = true,
	floorMaxAngle = true,
	spawnGrace = true,
}

export type Tuning = typeof(MovementTuning)

-- Copia de la tabla con las distancias en studs.
function MovementTuning.scaled(): Tuning
	local result = {}
	for key, value in MovementTuning :: any do
		if type(value) == "number" then
			result[key] = if UNITLESS[key] then value else Units.studs(value)
		end
	end
	return (result :: any) :: Tuning
end

return MovementTuning
