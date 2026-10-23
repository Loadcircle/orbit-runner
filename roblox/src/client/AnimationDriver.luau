--!strict
-- Elige la animación a partir del estado del controlador, nunca al revés (guía §3.1).
-- R2: animaciones R15 por defecto de Roblox (las del script Animate del personaje:
-- idle, run, jump, fall) con retoques procedurales sobre los C0 de las articulaciones:
-- agachado al deslizar, inclinación en el dash y giro de brazo al lanzar el yo-yo.
-- Las animaciones propias sustituirán a las de `DEFAULT_SLOTS` sin tocar el controlador.

local AnimationDriver = {}
AnimationDriver.__index = AnimationDriver

-- Nombre de la animación → hijo del script Animate (Folder/StringValue) que la contiene.
local DEFAULT_SLOTS = {
	Idle = { "idle", "Animation1" },
	Run = { "run", "RunAnim" },
	Jump = { "jump", "JumpAnim" },
	Fall = { "fall", "FallAnim" },
}
local FADE = 0.12 -- player_visual.gd: BLEND
local K = 3.5 -- Units.K (studs por metro)
local RUN_THRESHOLD = 0.6 * K -- player_visual.gd: carrera desde 0.6 m/s
local JUMP_THRESHOLD = 0.5 * K -- salto si vy > 0.5 m/s; si no, caída
local RUN_SPEED = 8 * K -- MovementTuning.runSpeed

type Controller = {
	rig: { character: Model, humanoid: Humanoid, root: BasePart },
	onFloor: boolean,
	isSliding: boolean,
	isDashing: boolean,
	isDead: boolean,
	frozen: boolean,
	throwTimer: number,
	velocity: Vector3,
	horizontalSpeed: (any) -> number,
	landed: any,
}

export type AnimationDriver = typeof(setmetatable({} :: {
	controller: Controller,
	animator: Animator,
	tracks: { [string]: AnimationTrack },
	current: string?,
	rootJoint: Motor6D?,
	rootC0: CFrame,
	shoulder: Motor6D?,
	shoulderC0: CFrame,
	pose: { slide: number, dash: number, throw: number, land: number },
	celebrating: boolean,
}, AnimationDriver))

local function findAnimationId(animate: Instance?, slot: { string }): string?
	if not animate then
		return nil
	end
	local folder = animate:FindFirstChild(slot[1])
	local animation = folder and folder:FindFirstChild(slot[2])
	if animation and animation:IsA("Animation") then
		return animation.AnimationId
	end
	return nil
end

function AnimationDriver.new(controller: Controller): AnimationDriver
	local character = controller.rig.character
	local humanoid = controller.rig.humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animate = character:FindFirstChild("Animate")
	local self = setmetatable({
		controller = controller,
		animator = animator,
		tracks = {},
		current = nil,
		rootJoint = nil,
		rootC0 = CFrame.identity,
		shoulder = nil,
		shoulderC0 = CFrame.identity,
		pose = { slide = 0, dash = 0, throw = 0, land = 0 },
		celebrating = false,
	}, AnimationDriver)

	for name, slot in DEFAULT_SLOTS do
		local id = findAnimationId(animate, slot)
		if id then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local track = animator:LoadAnimation(animation)
			track.Priority = if name == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
			track.Looped = name ~= "Jump"
			self.tracks[name] = track
		end
	end
	-- El script Animate reacciona a estados del Humanoid que ya no se evalúan: se apaga y
	-- se detienen sus pistas para que no se mezclen con las nuestras.
	if animate and animate:IsA("LocalScript") then
		animate.Enabled = false
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
	end

	local lowerTorso = character:FindFirstChild("LowerTorso")
	local root = lowerTorso and lowerTorso:FindFirstChild("Root")
	if root and root:IsA("Motor6D") then
		self.rootJoint = root
		self.rootC0 = root.C0
	end
	local upperArm = character:FindFirstChild("RightUpperArm")
	local shoulder = upperArm and upperArm:FindFirstChild("RightShoulder")
	if shoulder and shoulder:IsA("Motor6D") then
		self.shoulder = shoulder
		self.shoulderC0 = shoulder.C0
	end
	controller.landed:Connect(function(impact: number)
		self.pose.land = math.clamp(impact / 40, 0, 1)
	end)
	return self
end

function AnimationDriver._play(self: AnimationDriver, name: string)
	if self.current == name then
		return
	end
	local previous = self.current and self.tracks[self.current]
	if previous then
		previous:Stop(FADE)
	end
	local track = self.tracks[name]
	if track then
		track:Play(FADE)
	end
	self.current = name
end

local function approach(value: number, target: number, rate: number, dt: number): number
	return value + (target - value) * (1 - math.exp(-rate * dt))
end

function AnimationDriver.update(self: AnimationDriver, dt: number)
	local c = self.controller
	local speed = c:horizontalSpeed()
	local state: string
	if c.isDead then
		state = "Fall"
	elseif self.celebrating or c.frozen then
		state = "Idle"
	elseif c.onFloor then
		state = if c.isSliding then "Fall" elseif speed > RUN_THRESHOLD then "Run" else "Idle"
	else
		state = if c.velocity.Y > JUMP_THRESHOLD then "Jump" else "Fall"
	end
	self:_play(state)
	local run = self.tracks.Run
	if run and state == "Run" then
		run:AdjustSpeed(math.clamp(speed / RUN_SPEED, 0.5, 1.6) * 1.15)
	end

	-- Retoques procedurales.
	local pose = self.pose
	pose.slide = approach(pose.slide, if c.isSliding then 1 else 0, 18, dt)
	pose.dash = approach(pose.dash, if c.isDashing then 1 else 0, 20, dt)
	pose.throw = approach(pose.throw, if c.throwTimer > 0 then 1 else 0, 22, dt)
	pose.land = approach(pose.land, 0, 9, dt)
	if self.rootJoint then
		-- Agachado y echado hacia atrás al deslizar; hacia delante en el dash; un poco
		-- de compresión al aterrizar.
		local lower = 1.6 * pose.slide + 0.6 * pose.land
		local pitch = math.rad(35) * pose.slide - math.rad(28) * pose.dash
		self.rootJoint.C0 = self.rootC0 * CFrame.new(0, -lower, 0) * CFrame.Angles(pitch, 0, 0)
	end
	if self.shoulder then
		self.shoulder.C0 = self.shoulderC0 * CFrame.Angles(math.rad(110) * pose.throw, 0, 0)
	end
end

function AnimationDriver.destroy(self: AnimationDriver)
	for _, track in self.tracks do
		track:Stop(0)
		track:Destroy()
	end
	if self.rootJoint then
		self.rootJoint.C0 = self.rootC0
	end
	if self.shoulder then
		self.shoulder.C0 = self.shoulderC0
	end
end

return AnimationDriver
