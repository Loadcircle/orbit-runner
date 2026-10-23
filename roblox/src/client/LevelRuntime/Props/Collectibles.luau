--!strict
-- Coleccionables: gemas (scripts/props/gem.gd) y chispas (scripts/props/spark.gd).
-- Las gemas ya conseguidas en otro intento se ven como fantasma y se pueden volver a
-- recoger. Las chispas se acercan al jugador cuando está cerca (imán).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local AssetLibrary = require(script.Parent.Parent:WaitForChild("AssetLibrary"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Types = require(script.Parent:WaitForChild("Types"))

local Collectibles = {}

local function burst(parent: Instance, position: Vector3, color: Color3, count: number)
	-- Destello nativo de recogida (PickupBurst en Godot).
	local anchor = PartFactory.visual(parent, {
		Name = "Burst",
		Size = Vector3.one * 0.2,
		CFrame = CFrame.new(position),
		Transparency = 1,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.3, 0.45)
	emitter.Speed = NumberRange.new(Units.studs(3), Units.studs(6))
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(count)
	task.delay(0.6, function()
		anchor:Destroy()
	end)
end

function Collectibles.gem(entry: { index: number, pos: { number } }, ctx: Types.Context): Types.Prop
	local G = PropTuning.gem
	local origin = Units.vector(entry.pos)
	local index = entry.index
	local owned = ctx.session:gemAlreadyOwned(index)
	local center = origin + Vector3.new(0, Units.studs(G.centerY), 0)
	local size = Units.studs(0.75)
	local gem = PartFactory.visual(ctx.geometry, {
		Name = "Gem" .. index,
		Size = Vector3.one * size,
		Color = if owned then Palette.white else Palette.turquoise,
		Material = if owned then Enum.Material.ForceField else Enum.Material.Neon,
		Transparency = if owned then 0.35 else 0,
	})
	-- Malla migrada (modelo a +1 m en gem.tscn); las gemas ya conseguidas, translúcidas.
	local visual = AssetLibrary.instantiate("PROP_Gem", ctx.geometry, CFrame.new(center))
	if visual then
		gem.Transparency = 1
		if owned then
			for _, part in visual.parts do
				part.Transparency = 0.55
			end
		end
	end
	local area = PartFactory.trigger(ctx.triggerFolder, "GemArea", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * Units.studs(G.radius) * 2,
		CFrame = CFrame.new(center),
	})
	local collected = false
	local pop = 0
	ctx.triggers:register(area, {
		onEnter = function()
			if collected then
				return
			end
			collected = true
			ctx.triggers:unregister(area)
			area:Destroy()
			ctx.session:playSfx("gem")
			ctx.session:vibrate(20)
			ctx.session:onGem(index)
			burst(ctx.geometry, gem.Position, Palette.turquoise, 20)
			pop = 0.3
		end,
	})
	local prop = {}
	function prop.step(_self, dt: number, time: number)
		if collected then
			if pop > 0 then
				pop = math.max(pop - dt, 0)
				local t = 1 - pop / 0.3
				local s = if t < 0.4 then 1 + 0.6 * (t / 0.4) else 1.6 * (1 - (t - 0.4) / 0.6)
				gem.Size = Vector3.one * size * math.max(s, 0.01)
				if visual then
					visual.model:ScaleTo(math.max(s, 0.01))
				end
				if pop <= 0 then
					gem:Destroy()
					if visual then
						visual.model:Destroy()
					end
				end
			end
			return
		end
		local bob = math.sin(time * 3) * Units.studs(G.bobAmplitude)
		gem.CFrame = CFrame.new(center + Vector3.new(0, bob, 0))
			* CFrame.Angles(0, time * G.spinRate, 0)
			* CFrame.Angles(math.rad(45), 0, math.rad(45))
		if visual then
			visual.model:PivotTo(CFrame.new(center + Vector3.new(0, bob, 0)) * CFrame.Angles(0, time * G.spinRate, 0))
		end
	end
	return prop
end

function Collectibles.spark(position: { number }, ctx: Types.Context): Types.Prop
	local S = PropTuning.spark
	local pos = Units.vector(position)
	local spin = math.random() * math.pi * 2
	local spark = PartFactory.visual(ctx.geometry, {
		Name = "Spark",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * Units.studs(0.32),
		Color = Palette.impulse,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	-- Malla migrada (escala 1.1 en spark.tscn).
	local visual = AssetLibrary.instantiate("PROP_Spark", ctx.geometry, CFrame.new(pos))
	if visual then
		visual.model:ScaleTo(1.1)
		spark.Transparency = 1
	end
	local area = PartFactory.trigger(ctx.triggerFolder, "SparkArea", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * Units.studs(S.radius) * 2,
		CFrame = CFrame.new(pos),
	})
	local collected = false
	ctx.triggers:register(area, {
		onEnter = function()
			if collected then
				return
			end
			collected = true
			ctx.triggers:unregister(area)
			area:Destroy()
			ctx.session:playSfx("spark")
			ctx.session:onSpark()
			burst(ctx.geometry, pos, Palette.impulse, 8)
			spark:Destroy()
			if visual then
				visual.model:Destroy()
			end
		end,
	})
	local magnetRadius = Units.studs(S.magnetRadius)
	local magnetSpeed = Units.studs(S.magnetSpeed)
	local targetHeight = Units.studs(S.targetHeight)
	local prop = {}
	function prop.step(_self, dt: number)
		if collected then
			return
		end
		spin += S.spinRate * dt
		local player = ctx.player
		if not player.isDead then
			local to = player:feet() + Vector3.new(0, targetHeight, 0) - pos
			local distance = to.Magnitude
			if distance < magnetRadius and distance > 1e-3 then
				pos += to.Unit * math.min(distance, magnetSpeed * dt)
				area.CFrame = CFrame.new(pos)
			end
		end
		spark.CFrame = CFrame.new(pos) * CFrame.Angles(0, spin, 0)
		if visual then
			visual.model:PivotTo(spark.CFrame)
		end
	end
	return prop
end

return Collectibles
