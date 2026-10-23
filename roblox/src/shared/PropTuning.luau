--!strict
-- Valores de props, peligros y flujo de intento en METROS y segundos, transcritos de
-- orbit_runner_game/scripts/props/*.gd, scenes/props/*.tscn, scripts/player/kinetic_yoyo.gd
-- y scripts/level/level.gd. Las alturas (`centerY`) son el centro de la forma de colisión
-- sobre el origen del prop. Se convierten a studs donde se usan (Units).

return {
	trampoline = {
		strength = 20.0,
		maxEntrySpeed = 1.0, -- solo actúa si la velocidad vertical es ≤ 1
		padRadius = 1.35, padHeight = 1.0, padCenterY = 0.5,
		baseRadius = 1.15, baseHeight = 0.36, baseCenterY = 0.18,
	},
	boostPad = {
		speed = 17.0,
		cooldown = 0.3,
		size = { 2.2, 0.8, 3.2 }, centerY = 0.4,
	},
	windColumn = {
		height = 8.0,
		lift = 62.0,
		maxUpSpeed = 10.0,
		radius = 1.65,
		fadeRange = 2.5, -- la elevación se atenúa entre height+1−2.5 y height+1
		fadeTop = 1.0,
		drag = 2.8, -- arrastre horizontal ×(1 − 2.8·dt)
	},
	movingPlatform = {
		travel = { 0, 0, -6 },
		period = 4.0,
		pauseFraction = 0.25,
		size = { 3, 0.5, 3 }, centerY = -0.25,
	},
	timedPlatform = {
		onTime = 2.2,
		offTime = 1.4,
		warning = 0.6,
		radius = 1.55, height = 0.6, centerY = -0.3,
		popTime = 0.18,
	},
	crumblePlatform = {
		warningTime = 0.55,
		respawnTime = 3.0,
		fallTime = 0.7, fallDistance = 6.0,
		size = { 3, 0.4, 3 }, centerY = -0.2,
		sensorSize = { 2.8, 0.5, 2.8 }, sensorCenterY = 0.25,
	},
	checkpoint = {
		size = { 4, 3, 2 }, centerY = 1.5,
		spawnY = 0.1,
	},
	goal = {
		size = { 4.6, 4, 1.6 }, centerY = 2.0,
		pillarSize = { 0.7, 4, 0.7 }, pillarX = 2.6,
		resultsDelay = 1.4,
	},
	spikes = {
		size = { 1.8, 0.5, 1.8 }, centerY = 0.3,
	},
	spinner = {
		degreesPerSecond = 70.0,
		armSize = { 6.6, 0.5, 0.5 }, armCenterY = 0.7,
		hubRadius = 0.6, hubHeight = 1.2, hubCenterY = 0.6,
	},
	patrol = {
		travel = { 6, 0, 0 },
		speed = 3.0,
		radius = 0.75, centerY = 0.9,
		bobAmplitude = 0.12, bobRate = 6.0, spinRate = 2.5,
	},
	laser = {
		width = 4.0,
		beamHeight = 1.05,
		period = 0.0,
		onFraction = 0.6,
		warning = 0.4,
		hazardThickness = { 0.32, 0.4 }, -- alto × fondo; ancho = width − 0.3
	},
	gem = {
		radius = 0.9, centerY = 1.0,
		spinRate = 1.8, bobAmplitude = 0.15,
	},
	spark = {
		radius = 0.6,
		magnetRadius = 2.2,
		magnetSpeed = 14.0,
		targetHeight = 0.8, -- el imán apunta a los pies + 0.8 m
		spinRate = 3.0,
	},
	yoyo = {
		discRadius = 1.35,
		bounceHeight = 1.1, bounceCenterY = 0.35,
		blinkTime = 0.5,
		flightArc = 0.4,
		wallMargin = 1.3,
		maxBounceEntrySpeed = 2.0, -- rebota si vy ≤ 2 …
		belowTolerance = 0.45, -- … y los pies están a ≥ disco − 0.45 m
		returnHeight = 1.0,
		throwHeight = 1.0, -- el lanzamiento sale de los pies + 1 m
		throwRecover = 0.3,
	},
	level = {
		killHeight = -12.0,
		respawnDelay = 0.55,
		deathShake = 0.6,
	},
}
