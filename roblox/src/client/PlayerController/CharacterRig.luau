--!strict
-- Capa física del personaje sobre el controlador nativo de Roblox (decisión R4):
-- Humanoid con EvaluateStateMachine = false + ControllerManager (GroundController y
-- AirController) + ControllerPartSensor para el suelo. La gravedad asimétrica se aplica
-- con un VectorForce que sustituye la gravedad del mundo mientras se está en el aire.
-- También mantiene la cápsula de juego (hitbox) que usan peligros y activadores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementTuning = require(Shared:WaitForChild("MovementTuning"))
local Units = require(Shared:WaitForChild("Units"))

local Tuning = MovementTuning.scaled()

-- Corrección medida en Studio (2026-10-22): el GroundController tarda ~9 % más que el
-- tiempo pedido en llegar a la velocidad (fricción). Se recalibra en el laboratorio (H3).
local GROUND_TIME_CALIBRATION = 0.915
local SENSOR_EXTRA = Units.studs(2.0)

export type CharacterRig = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	manager: ControllerManager,
	ground: GroundController,
	air: AirController,
	sensor: ControllerPartSensor,
	gravityForce: VectorForce,
	hitbox: Part,
	hitboxWeld: Weld,
	groundOffset: number,
	rootHalfHeight: number,
	queryParams: RaycastParams,
}

local CharacterRig = {}

local function makeHitbox(root: BasePart): (Part, Weld)
	-- Cilindro vertical (r 0.35 m, h 1.5 m) como cápsula de juego. Massless y sin
	-- colisión: solo es la forma que se consulta con GetPartsInPart.
	local hitbox = Instance.new("Part")
	hitbox.Name = "GameplayHitbox"
	hitbox.Shape = Enum.PartType.Cylinder
	hitbox.Massless = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = false
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = hitbox
	weld.Parent = hitbox
	hitbox.Parent = root
	return hitbox, weld
end

function CharacterRig.new(character: Model): CharacterRig
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- El Humanoid se queda para el avatar, la apariencia y la replicación; deja de
	-- mover el cuerpo y de cambiar de estado por su cuenta.
	humanoid.EvaluateStateMachine = false

	local manager = Instance.new("ControllerManager")
	manager.RootPart = root
	manager.BaseMoveSpeed = Tuning.runSpeed
	manager.BaseTurnSpeed = 40 -- el giro suave lo calcula el controlador (rotationSpeed)
	manager.FacingDirection = root.CFrame.LookVector * Vector3.new(1, 0, 1)

	local ground = Instance.new("GroundController")
	ground.GroundOffset = humanoid.HipHeight
	ground.Parent = manager

	local air = Instance.new("AirController")
	-- El movimiento horizontal en el aire lo integra el controlador (player.gd); el
	-- AirController solo mantiene equilibrio y orientación.
	air.MoveMaxForce = 0
	air.MaintainLinearMomentum = true
	air.Parent = manager

	local sensor = Instance.new("ControllerPartSensor")
	sensor.Name = "GroundSensor"
	sensor.SensorMode = Enum.SensorMode.Floor
	sensor.SearchDistance = humanoid.HipHeight + root.Size.Y / 2 + SENSOR_EXTRA
	sensor.Parent = root
	manager.GroundSensor = sensor
	manager.ActiveController = ground
	manager.Parent = character

	local attachment = Instance.new("Attachment")
	attachment.Name = "GravityAttachment"
	attachment.Parent = root
	local gravityForce = Instance.new("VectorForce")
	gravityForce.Name = "GameplayGravity"
	gravityForce.Attachment0 = attachment
	gravityForce.RelativeTo = Enum.ActuatorRelativeTo.World
	gravityForce.ApplyAtCenterOfMass = true
	gravityForce.Force = Vector3.zero
	gravityForce.Parent = root

	local hitbox, hitboxWeld = makeHitbox(root)

	local queryParams = RaycastParams.new()
	queryParams.FilterType = Enum.RaycastFilterType.Exclude
	queryParams.FilterDescendantsInstances = { character }
	queryParams.RespectCanCollide = true

	local rig: CharacterRig = {
		character = character,
		humanoid = humanoid,
		root = root,
		manager = manager,
		ground = ground,
		air = air,
		sensor = sensor,
		gravityForce = gravityForce,
		hitbox = hitbox,
		hitboxWeld = hitboxWeld,
		groundOffset = humanoid.HipHeight,
		rootHalfHeight = root.Size.Y / 2,
		queryParams = queryParams,
	}
	CharacterRig.setHitboxHeight(rig, Tuning.standHeight)
	-- Si el servidor normaliza la escala del avatar (AvatarService), cambia la altura de
	-- cadera: se recalculan la altura del GroundController, el sensor y la cápsula.
	humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
		rig.groundOffset = humanoid.HipHeight
		rig.rootHalfHeight = root.Size.Y / 2
		ground.GroundOffset = humanoid.HipHeight
		sensor.SearchDistance = humanoid.HipHeight + root.Size.Y / 2 + SENSOR_EXTRA
		CharacterRig.setHitboxHeight(rig, rig.hitbox.Size.X)
	end)
	return rig
end

-- Altura de la cápsula de juego (de pie 1.5 m, deslizando 0.8 m), apoyada en los pies.
function CharacterRig.setHitboxHeight(rig: CharacterRig, height: number)
	local diameter = Tuning.capsuleRadius * 2
	-- El eje de un cilindro de Roblox es X: se gira 90° para dejarlo vertical.
	rig.hitbox.Size = Vector3.new(height, diameter, diameter)
	local feetOffset = -(rig.rootHalfHeight + rig.groundOffset)
	rig.hitboxWeld.C0 = CFrame.new(0, feetOffset + height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
end

-- Posición de los pies (el origen del jugador en Godot).
function CharacterRig.feet(rig: CharacterRig): Vector3
	return rig.root.Position - Vector3.new(0, rig.rootHalfHeight + rig.groundOffset, 0)
end

-- Coloca los pies en `feet` mirando hacia `facing` (horizontal).
function CharacterRig.placeAt(rig: CharacterRig, feet: Vector3, facing: Vector3)
	local rootPosition = feet + Vector3.new(0, rig.rootHalfHeight + rig.groundOffset, 0)
	rig.root.AssemblyLinearVelocity = Vector3.zero
	rig.root.AssemblyAngularVelocity = Vector3.zero
	rig.character:PivotTo(CFrame.lookAlong(rootPosition, facing))
	rig.manager.FacingDirection = facing
end

export type GroundHit = { part: BasePart, normal: Vector3, distance: number, velocity: Vector3 }

-- Suelo bajo los pies dentro del snap, o nil. `distance` > 0 si los pies están por encima.
function CharacterRig.probeGround(rig: CharacterRig): GroundHit?
	local part = rig.sensor.SensedPart
	if not part then
		return nil
	end
	local feetY = CharacterRig.feet(rig).Y
	local distance = feetY - rig.sensor.HitFrame.Position.Y
	if distance > Tuning.floorSnap then
		return nil
	end
	local normal = rig.sensor.HitNormal
	if normal.Y < math.cos(math.rad(Tuning.floorMaxAngle)) then
		return nil
	end
	return {
		part = part,
		normal = normal,
		distance = distance,
		velocity = part.AssemblyLinearVelocity,
	}
end

-- Gravedad propia (studs/s²) mientras está activo el AirController; nil = la del mundo.
function CharacterRig.setGravity(rig: CharacterRig, gravity: number?)
	if gravity == nil then
		rig.gravityForce.Force = Vector3.zero
		return
	end
	local mass = rig.root.AssemblyMass
	rig.gravityForce.Force = Vector3.new(0, mass * (Workspace.Gravity - gravity), 0)
end

-- Comprobación esférica hacia arriba antes de ponerse de pie (CeilingCheck de player.tscn:
-- esfera r 0.3 m desde 0.45 m sobre los pies, 0.95 m hacia arriba).
function CharacterRig.canStand(rig: CharacterRig): boolean
	local origin = CharacterRig.feet(rig) + Vector3.new(0, Units.studs(0.45), 0)
	local hit = Workspace:Spherecast(origin, Units.studs(0.3), Vector3.new(0, Units.studs(0.95), 0), rig.queryParams)
	return hit == nil
end

-- Rayo contra el mundo ignorando al personaje.
function CharacterRig.raycast(rig: CharacterRig, origin: Vector3, direction: Vector3): RaycastResult?
	return Workspace:Raycast(origin, direction, rig.queryParams)
end

function CharacterRig.setAnchored(rig: CharacterRig, anchored: boolean)
	rig.root.Anchored = anchored
	if anchored then
		rig.root.AssemblyLinearVelocity = Vector3.zero
	end
end

return CharacterRig
