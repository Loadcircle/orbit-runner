--!strict
-- Volúmenes invisibles de recorrido: zonas de cámara (scripts/props/camera_zone.gd) e
-- indicaciones del tutorial (scripts/props/tutorial_prompt.gd).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Units"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local Volumes = {}

local function box(entry: Types.Entry, ctx: Types.Context, name: string): BasePart
	local frame = Common.frame(entry)
	local offset = entry.offset or { 0, 0, 0 }
	return PartFactory.trigger(ctx.triggerFolder, name, {
		Size = Common.size(entry.size or { 1, 1, 1 }),
		CFrame = frame * CFrame.new(Units.vector(offset)),
	})
end

-- Mientras el jugador está dentro, la cámara mira hacia `yaw` grados (0 = hacia −Z).
function Volumes.cameraZone(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local area = box(entry, ctx, "CameraZone")
	local yaw = math.rad(entry.yaw or 0)
	ctx.triggers:register(area, {
		onEnter = function()
			ctx.session:setCameraYaw(yaw)
		end,
	})
	return {}
end

-- Muestra una indicación mientras el jugador está dentro. `key` es una clave de
-- traducción; si existe `<key>_TOUCH` se usa en pantallas táctiles.
function Volumes.prompt(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local area = box(entry, ctx, "TutorialPrompt")
	local owner = {}
	ctx.triggers:register(area, {
		onEnter = function()
			ctx.session:showPrompt(owner, entry.key)
		end,
		onExit = function()
			ctx.session:hidePrompt(owner)
		end,
	})
	return {}
end

return Volumes
