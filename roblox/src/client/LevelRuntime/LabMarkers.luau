--!strict
-- Extensiones del laboratorio de mecánicas: reglas con marcas cada metro (gruesas, con
-- número cada 5 m) y cada 5 studs (finas), y carteles flotantes (BillboardGui nativo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Units"))
local Palette = require(script.Parent:WaitForChild("Palette"))
local PartFactory = require(script.Parent:WaitForChild("PartFactory"))

local LabMarkers = {}

local function billboard(parent: BasePart, text: string, size: UDim2, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
end

function LabMarkers.ruler(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.01 then
		return
	end
	local direction = (to - from).Unit
	local vertical = math.abs(direction.Y) > 0.9
	local frame = CFrame.lookAt(from, to, if vertical then Vector3.xAxis else Vector3.yAxis)
	PartFactory.visual(parent, {
		Name = "Ruler",
		Size = Vector3.new(0.25, 0.08, length),
		CFrame = frame * CFrame.new(0, 0.05, -length / 2),
		Color = Palette.white,
	})
	local meters = math.floor(Units.meters(length) + 1e-6)
	for m = 0, meters do
		local tick = PartFactory.visual(parent, {
			Name = "Meter",
			Size = Vector3.new(if m % 5 == 0 then 1.4 else 0.9, 0.1, 0.18),
			CFrame = frame * CFrame.new(0, 0.06, -Units.studs(m)),
			Color = if m % 5 == 0 then Palette.dark else Palette.metalDark,
		})
		if m % 5 == 0 or vertical then
			billboard(tick, tostring(m) .. " m", UDim2.fromOffset(46, 20), Palette.white)
		end
	end
	for s = 0, math.floor(length / 5) do
		PartFactory.visual(parent, {
			Name = "Stud5",
			Size = Vector3.new(0.5, 0.09, 0.08),
			CFrame = frame * CFrame.new(-0.55, 0.06, -s * 5),
			Color = Palette.impulseDark,
		})
	end
end

function LabMarkers.label(parent: Instance, position: Vector3, text: string)
	local anchor = PartFactory.visual(parent, {
		Name = "Label",
		Size = Vector3.one * 0.2,
		CFrame = CFrame.new(position),
		Transparency = 1,
	})
	billboard(anchor, text, UDim2.fromOffset(320, 34), Palette.cream)
end

function LabMarkers.build(data: { [string]: any }, parent: Instance)
	for _, ruler in data.rulers or {} do
		LabMarkers.ruler(parent, Units.vector(ruler.from), Units.vector(ruler.to))
	end
	for _, label in data.labels or {} do
		LabMarkers.label(parent, Units.vector(label.pos), label.text)
	end
end

return LabMarkers
