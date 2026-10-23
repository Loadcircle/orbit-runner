--!strict
-- Decoración del bioma (assets ENV_*). Solo visual: sin colisión ni consultas, para no
-- tapar la cámara ni interferir con sensores. Formas nativas provisionales hasta que
-- lleguen los MeshParts (H8); ENV_Bush, ENV_Rock y ENV_Cloud se quedan nativos (§3.8).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local AssetLibrary = require(script.Parent.Parent:WaitForChild("AssetLibrary"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local Decor = {}

local m = Units.studs

local function ball(parent: Instance, frame: CFrame, diameter: number, color: Color3)
	PartFactory.visual(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, CFrame = frame, Color = color })
end

local function column(parent: Instance, base: CFrame, radius: number, height: number, color: Color3)
	local size, frame = PartFactory.verticalCylinder(base * CFrame.new(0, height / 2, 0), radius, height)
	PartFactory.visual(parent, { Shape = Enum.PartType.Cylinder, Size = size, CFrame = frame, Color = color })
end

local BUILDERS: { [string]: (Instance, CFrame, number) -> () } = {
	ENV_Tree = function(parent, base, s)
		column(parent, base, m(0.18) * s, m(1.6) * s, Palette.wood)
		ball(parent, base * CFrame.new(0, m(2.2) * s, 0), m(1.9) * s, Palette.leaf)
	end,
	ENV_Pine = function(parent, base, s)
		column(parent, base, m(0.15) * s, m(1.0) * s, Palette.wood)
		for i = 0, 2 do
			local size = m(1.6 - i * 0.4) * s
			PartFactory.visual(parent, {
				Size = Vector3.new(size, m(0.7) * s, size),
				CFrame = base * CFrame.new(0, m(1.2 + i * 0.6) * s, 0) * CFrame.Angles(0, math.rad(45), 0),
				Color = Palette.grassDark,
			})
		end
	end,
	ENV_Palm = function(parent, base, s)
		column(parent, base, m(0.16) * s, m(2.6) * s, Palette.sandstone)
		for i = 0, 4 do
			PartFactory.visual(parent, {
				Size = Vector3.new(m(1.4) * s, m(0.1) * s, m(0.45) * s),
				CFrame = base * CFrame.new(0, m(2.6) * s, 0) * CFrame.Angles(0, i * math.pi * 0.4, math.rad(-20))
					* CFrame.new(m(0.6) * s, 0, 0),
				Color = Palette.leaf,
			})
		end
	end,
	ENV_Bush = function(parent, base, s)
		ball(parent, base * CFrame.new(0, m(0.35) * s, 0), m(0.9) * s, Palette.leaf)
		ball(parent, base * CFrame.new(m(0.35) * s, m(0.25) * s, 0), m(0.6) * s, Palette.grassLight)
	end,
	ENV_Rock_A = function(parent, base, s)
		PartFactory.visual(parent, { Size = Vector3.new(m(0.9), m(0.6), m(0.7)) * s,
			CFrame = base * CFrame.new(0, m(0.25) * s, 0) * CFrame.Angles(0.2, 0.5, 0.1), Color = Palette.stoneDark })
	end,
	ENV_Rock_B = function(parent, base, s)
		PartFactory.visual(parent, { Size = Vector3.new(m(0.6), m(0.45), m(0.55)) * s,
			CFrame = base * CFrame.new(0, m(0.2) * s, 0) * CFrame.Angles(0.3, 0.2, 0.2), Color = Palette.cliffDark })
	end,
	ENV_Crystal = function(parent, base, s)
		PartFactory.visual(parent, { Size = Vector3.new(m(0.4), m(1.2), m(0.4)) * s,
			CFrame = base * CFrame.new(0, m(0.5) * s, 0) * CFrame.Angles(0.2, 0.7, 0.15), Color = Palette.glow,
			Material = Enum.Material.Glass })
	end,
	ENV_Gear = function(parent, base, s)
		local size, frame = PartFactory.verticalCylinder(base * CFrame.new(0, m(1.0) * s, 0) * CFrame.Angles(math.rad(90), 0, 0),
			m(0.9) * s, m(0.3) * s)
		PartFactory.visual(parent, { Shape = Enum.PartType.Cylinder, Size = size, CFrame = frame, Color = Palette.toyYellow })
	end,
	ENV_ToyBlocks = function(parent, base, s)
		local colors = { Palette.toyRed, Palette.toyBlue, Palette.toyTeal }
		for i, color in colors do
			PartFactory.visual(parent, { Size = Vector3.one * m(0.5) * s,
				CFrame = base * CFrame.new(m((i - 2) * 0.3) * s, m(0.25 + (i % 2) * 0.5) * s, 0), Color = color })
		end
	end,
	ENV_LampPost = function(parent, base, s)
		column(parent, base, m(0.08) * s, m(2.4) * s, Palette.metalDark)
		ball(parent, base * CFrame.new(0, m(2.5) * s, 0), m(0.4) * s, Palette.impulse)
	end,
	ENV_Obelisk = function(parent, base, s)
		PartFactory.visual(parent, { Size = Vector3.new(m(0.6), m(3.0), m(0.6)) * s,
			CFrame = base * CFrame.new(0, m(1.5) * s, 0), Color = Palette.sandstone })
	end,
	ENV_RuinPillar = function(parent, base, s)
		column(parent, base, m(0.35) * s, m(2.4) * s, Palette.sand)
	end,
	ENV_RuinArch = function(parent, base, s)
		for side = -1, 1, 2 do
			PartFactory.visual(parent, { Size = Vector3.new(m(0.5), m(2.4), m(0.5)) * s,
				CFrame = base * CFrame.new(side * m(1.0) * s, m(1.2) * s, 0), Color = Palette.sand })
		end
		PartFactory.visual(parent, { Size = Vector3.new(m(2.6), m(0.4), m(0.5)) * s,
			CFrame = base * CFrame.new(0, m(2.6) * s, 0), Color = Palette.sandstone })
	end,
}

function Decor.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	-- Malla migrada si existe (ENV_Tree, ENV_Pine…); si no, forma nativa.
	local visual = AssetLibrary.instantiate(entry.asset, ctx.decor, Common.frame(entry))
	if visual then
		if entry.scale then
			visual.model:ScaleTo(entry.scale[1])
		end
		return {}
	end
	local builder = BUILDERS[entry.asset or ""]
	if not builder then
		return {}
	end
	local model = Instance.new("Model")
	model.Name = entry.asset or "Decor"
	model.Parent = ctx.decor
	local scale = if entry.scale then entry.scale[1] else 1
	builder(model, Common.frame(entry), scale)
	return {}
end

return Decor
