--!strict
-- Yo-yo cinético: port de orbit_runner_game/scripts/player/kinetic_yoyo.gd (D2).
-- Vuela a un punto, se despliega como disco de rebote temporal, y luego se pliega y
-- vuelve a la mano. Es una herramienta de locomoción, nunca un arma.
-- Estados: Guardado → Volando → Desplegado → Regresando.
-- Visual provisional nativo (Parts + Beam para el hilo); los MeshParts PROP_Yoyo y
-- PROP_YoyoDisc llegan en H8 y solo sustituyen a `_buildVisuals`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Signal = require(Shared:WaitForChild("Signal"))
local Units = require(Shared:WaitForChild("Units"))

local Y = PropTuning.yoyo
local GODOT_TICK_RATE = 60
local COLOR = Color3.fromHex("#22e0f0")
local ACCENT = Color3.fromHex("#ff8a1e")
local CORE = Color3.fromHex("#f4fbff")

export type State = "holstered" | "flying" | "deployed" | "returning"

type Owner = {
	tuning: { [string]: number },
	isDead: boolean,
	velocity: Vector3,
	feet: (any) -> Vector3,
	bounce: (any, number, string, boolean?) -> (),
	rig: { character: Model, root: BasePart },
}

local YoyoController = {}
YoyoController.__index = YoyoController

export type YoyoController = typeof(setmetatable({} :: {
	owner: Owner,
	state: State,
	folder: Folder,
	yoyo: BasePart,
	disc: BasePart,
	discRing: BasePart,
	holster: BasePart?,
	beam: Beam,
	handAttachment: Attachment,
	yoyoAttachment: Attachment,
	deployed: Signal.Signal<>,
	consumed: Signal.Signal<>,
	returned: Signal.Signal<>,
	playSfx: (string) -> (),
	_from: Vector3,
	_to: Vector3,
	_t: number,
	_life: number,
	_spin: number,
	_discScale: number,
	_position: Vector3,
	_flightElapsed: number,
}, YoyoController))

local function makePart(parent: Instance, props: { [string]: any }): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

function YoyoController.new(owner: Owner): YoyoController
	local folder = Instance.new("Folder")
	folder.Name = "KineticYoyo"
	folder.Parent = Workspace
	local self = setmetatable({
		owner = owner,
		state = "holstered" :: State,
		folder = folder,
		deployed = Signal.new(),
		consumed = Signal.new(),
		returned = Signal.new(),
		playSfx = function(_name: string) end,
		_from = Vector3.zero,
		_to = Vector3.zero,
		_t = 0,
		_life = 0,
		_spin = 0,
		_discScale = 1,
		_position = Vector3.zero,
		_flightElapsed = 0,
	} :: any, YoyoController)
	self:_buildVisuals()
	self:_hideAll()
	self:_setHolsterVisible(true)
	return self
end

function YoyoController._buildVisuals(self: YoyoController)
	local radius = Units.studs(Y.discRadius)
	self.yoyo = makePart(self.folder, {
		Name = "Yoyo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Units.studs(0.14), Units.studs(0.32), Units.studs(0.32)),
		Color = COLOR,
		Material = Enum.Material.Neon,
	})
	self.disc = makePart(self.folder, {
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Units.studs(0.12), radius * 2, radius * 2),
		Color = COLOR,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	self.discRing = makePart(self.folder, {
		Name = "DiscCore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Units.studs(0.16), radius * 0.8, radius * 0.8),
		Color = ACCENT,
	})
	-- Hilo: Beam nativo entre la mano y el yo-yo.
	local hand = self.owner.rig.character:FindFirstChild("RightHand") :: BasePart?
	local handAttachment = Instance.new("Attachment")
	handAttachment.Name = "YoyoString"
	handAttachment.Parent = hand or self.owner.rig.root
	self.handAttachment = handAttachment
	local yoyoAttachment = Instance.new("Attachment")
	yoyoAttachment.Parent = self.yoyo
	self.yoyoAttachment = yoyoAttachment
	local beam = Instance.new("Beam")
	beam.Attachment0 = handAttachment
	beam.Attachment1 = yoyoAttachment
	beam.Color = ColorSequence.new(COLOR)
	beam.LightEmission = 0.8
	beam.Width0 = Units.studs(0.028)
	beam.Width1 = Units.studs(0.028)
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = self.yoyo
	self.beam = beam
	-- Yo-yo guardado en la mano derecha.
	if hand then
		local holster = Instance.new("Part")
		holster.Name = "HolsteredYoyo"
		holster.Shape = Enum.PartType.Cylinder
		holster.Size = Vector3.new(Units.studs(0.1), Units.studs(0.24), Units.studs(0.24))
		holster.Color = COLOR
		holster.Material = Enum.Material.Neon
		holster.CanCollide = false
		holster.CanQuery = false
		holster.CanTouch = false
		holster.Massless = true
		holster.CastShadow = false
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = holster
		weld.C0 = CFrame.new(0, -hand.Size.Y / 2 - 0.15, 0)
		weld.Parent = holster
		holster.Parent = hand
		self.holster = holster
	end
end

function YoyoController.isReady(self: YoyoController): boolean
	return self.state == "holstered"
end

function YoyoController.throw(self: YoyoController, from: Vector3, to: Vector3)
	self._from = from
	self._to = to
	self._t = 0
	self._flightElapsed = 0
	self.state = "flying"
	self._position = from
	self.yoyo.Transparency = 0
	self.beam.Enabled = true
	self:_setHolsterVisible(false)
	self.playSfx("yoyo_throw")
end

-- Lanzamiento cayendo: se despliega justo bajo los pies y rebota en el acto.
function YoyoController.deployUnder(self: YoyoController, feet: Vector3)
	self._from = feet
	self._to = feet
	self:_setHolsterVisible(false)
	self.playSfx("yoyo_throw")
	self:_deploy()
	self:_tryBounce(true)
end

function YoyoController.recallInstant(self: YoyoController)
	self.state = "holstered"
	self:_hideAll()
	self:_setHolsterVisible(true)
end

function YoyoController.step(self: YoyoController, dt: number)
	local tuning = self.owner.tuning
	if self.state == "flying" then
		self._t += dt / tuning.yoyoFlightTime
		self._flightElapsed += dt
		local t = math.min(self._t, 1)
		local p = self._from:Lerp(self._to, t) + Vector3.new(0, math.sin(t * math.pi) * Units.studs(Y.flightArc), 0)
		self._position = p
		self._spin += 40 * dt
		-- En Godot (60 Hz) el disco se despliega en el tick en que el vuelo llega a 1:
		-- ceil(0.14 · 60) = 9 ticks = 0.15 s. Se despliega en el fotograma más cercano a ese
		-- instante para que el alcance no dependa del framerate.
		local deployAt = math.ceil(tuning.yoyoFlightTime * GODOT_TICK_RATE - 1e-6) / GODOT_TICK_RATE
		if self._flightElapsed >= deployAt - dt / 2 then
			self:_deploy()
		end
	elseif self.state == "deployed" then
		self._life -= dt
		self._spin += 6 * dt
		self._discScale = math.min(self._discScale + dt / 0.12, 1)
		-- Parpadea antes de plegarse para que el tiempo restante se lea.
		local visible = self._life >= Y.blinkTime or (self._life % 0.12) > 0.05
		local transparency = if visible then 0.15 else 1
		self.disc.Transparency = transparency
		self.discRing.Transparency = if visible then 0 else 1
		self:_checkOverlap()
		if self.state == "deployed" and self._life <= 0 then
			self:_startReturn()
		end
	elseif self.state == "returning" then
		self._t += dt / tuning.yoyoReturnTime
		local target = self.owner:feet() + Vector3.new(0, Units.studs(Y.returnHeight), 0)
		self._position = self._from:Lerp(target, math.min(self._t * self._t, 1))
		self._spin -= 40 * dt
		if self._t >= 1 then
			self.state = "holstered"
			self:_hideAll()
			self:_setHolsterVisible(true)
			self.returned:Fire()
		end
	end
	self:_render()
end

function YoyoController._render(self: YoyoController)
	if self.state == "flying" or self.state == "returning" then
		local look = (self._to - self._from)
		local yaw = if look.Magnitude > 0.01 then math.atan2(-look.X, -look.Z) else 0
		self.yoyo.CFrame = CFrame.new(self._position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(self._spin, 0, 0)
	elseif self.state == "deployed" then
		local scale = 0.1 + 0.9 * self._discScale
		local radius = Units.studs(Y.discRadius) * scale
		local base = CFrame.new(self._position) * CFrame.Angles(0, self._spin, 0) * CFrame.Angles(0, 0, math.rad(90))
		self.disc.Size = Vector3.new(self.disc.Size.X, radius * 2, radius * 2)
		self.disc.CFrame = base
		self.discRing.Size = Vector3.new(self.discRing.Size.X, radius * 0.8, radius * 0.8)
		self.discRing.CFrame = base
		self.yoyo.CFrame = CFrame.new(self._position)
	end
end

function YoyoController._deploy(self: YoyoController)
	self.state = "deployed"
	self._position = self._to
	self._life = self.owner.tuning.yoyoDiscLifetime
	self._discScale = 0
	self.yoyo.Transparency = 1
	self.disc.Transparency = 0.15
	self.discRing.Transparency = 0
	self.beam.Enabled = true
	self.playSfx("yoyo_deploy")
	self:_render()
	self.deployed:Fire()
end

function YoyoController._startReturn(self: YoyoController)
	self.state = "returning"
	self._from = self._position
	self._t = 0
	self.disc.Transparency = 1
	self.discRing.Transparency = 1
	self.yoyo.Transparency = 0
	self.playSfx("yoyo_return")
end

-- Solapamiento cilindro del disco (r 1.35 m, h 1.1 m centrado 0.35 m por encima) con la
-- cápsula de juego del jugador (r 0.35 m desde los pies hasta su altura actual).
function YoyoController._checkOverlap(self: YoyoController)
	local owner = self.owner
	local feet = owner:feet()
	local disc = self._position
	local offset = Vector3.new(feet.X - disc.X, 0, feet.Z - disc.Z)
	local reach = Units.studs(Y.discRadius + 0.35)
	if offset.Magnitude > reach then
		return
	end
	local bottom = disc.Y + Units.studs(Y.bounceCenterY - Y.bounceHeight / 2)
	local top = disc.Y + Units.studs(Y.bounceCenterY + Y.bounceHeight / 2)
	local height = (owner :: any).rig.hitbox.Size.X -- altura del cilindro de juego
	if feet.Y > top or feet.Y + height < bottom then
		return
	end
	self:_tryBounce()
end

function YoyoController._tryBounce(self: YoyoController, immediate: boolean?)
	local owner = self.owner
	if self.state ~= "deployed" or owner.isDead then
		return
	end
	-- Rebota al llegar desde arriba o a la par del disco, no desde abajo.
	if owner.velocity.Y > Units.studs(Y.maxBounceEntrySpeed) or owner:feet().Y < self._position.Y - Units.studs(Y.belowTolerance) then
		return
	end
	owner:bounce(owner.tuning.yoyoBounceVelocity, "yoyo", immediate)
	self.playSfx("bounce_yoyo")
	self.consumed:Fire()
	self:_startReturn()
end

function YoyoController._hideAll(self: YoyoController)
	self.yoyo.Transparency = 1
	self.disc.Transparency = 1
	self.discRing.Transparency = 1
	self.beam.Enabled = false
end

function YoyoController._setHolsterVisible(self: YoyoController, visible: boolean)
	if self.holster then
		self.holster.Transparency = if visible then 0 else 1
	end
end

function YoyoController.destroy(self: YoyoController)
	self.folder:Destroy()
	self.handAttachment:Destroy()
	if self.holster then
		self.holster:Destroy()
	end
end

return YoyoController
