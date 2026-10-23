--!strict
-- Meta (scripts/props/goal.gd + goal.tscn): arco dorado con pilares sólidos. Al entrar,
-- la sesión termina el intento (congela al jugador y muestra resultados).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local AssetLibrary = require(script.Parent.Parent:WaitForChild("AssetLibrary"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local G = PropTuning.goal
local Goal = {}

function Goal.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local frame = Common.frame(entry)
	local model = Instance.new("Model")
	model.Name = "Goal"
	model.Parent = ctx.geometry
	local pillarSize = Common.size(G.pillarSize)
	for side = -1, 1, 2 do
		PartFactory.part(model, {
			Name = "Pillar",
			Size = pillarSize,
			CFrame = frame * CFrame.new(side * Units.studs(G.pillarX), pillarSize.Y / 2, 0),
			Color = Palette.gold,
			Material = Enum.Material.Metal,
		})
	end
	local span = Units.studs(G.pillarX * 2 + G.pillarSize[1])
	PartFactory.visual(model, {
		Name = "Lintel",
		Size = Vector3.new(span, Units.studs(0.5), pillarSize.Z),
		CFrame = frame * CFrame.new(0, pillarSize.Y + Units.studs(0.25), 0),
		Color = Palette.gold,
		Material = Enum.Material.Metal,
	})
	local haloSize, haloFrame = PartFactory.verticalCylinder(CFrame.identity, Units.studs(1.2), 0.3)
	local halo = PartFactory.visual(model, {
		Name = "Halo",
		Shape = Enum.PartType.Cylinder,
		Size = haloSize,
		Color = Palette.impulse,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	local haloCenter = frame * CFrame.new(0, Units.studs(2.2), 0)
	-- Malla migrada del arco con su halo girando (goal.gd: 0.8 rad/s sobre su eje local).
	local visual = AssetLibrary.instantiate("PROP_GoalGate", model, frame)
	local meshHalo: BasePart? = nil
	local haloPivot = CFrame.identity
	if visual then
		AssetLibrary.hide({ halo })
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and (child.Name == "Pillar" or child.Name == "Lintel") then
				child.Transparency = 1
			end
		end
		meshHalo = visual.parts.Halo_Glow or visual.parts.Halo
		haloPivot = AssetLibrary.localPivot(visual, if visual.parts.Halo_Glow then "Halo_Glow" else "Halo") or CFrame.identity
	end
	local area = PartFactory.trigger(ctx.triggerFolder, "GoalArea", {
		Size = Common.size(G.size),
		CFrame = frame * CFrame.new(0, Units.studs(G.centerY), 0),
	})
	local done = false
	ctx.triggers:register(area, {
		onEnter = function()
			if done or ctx.player.isDead then
				return
			end
			done = true
			ctx.session:finish()
		end,
	})
	local prop = {}
	function prop.step(_self, _dt: number, time: number)
		-- Halo vertical que gira (0.8 rad/s) para marcar la meta desde lejos.
		if meshHalo then
			meshHalo:PivotTo(frame * haloPivot * CFrame.Angles(0, time * 0.8, 0))
			return
		end
		halo.CFrame = haloCenter * CFrame.Angles(0, time * 0.8, 0) * CFrame.Angles(math.rad(90), 0, 0) * haloFrame
	end
	return prop
end

return Goal
