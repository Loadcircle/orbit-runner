--!strict
-- Plataforma que se desmorona (scripts/props/crumble_platform.gd): al pisarla tiembla
-- 0.55 s, cae en losetas y se reconstruye a los 3 s. Las grietas entre losetas son la
-- señal de forma.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropTuning = require(Shared:WaitForChild("PropTuning"))
local Units = require(Shared:WaitForChild("Units"))
local Palette = require(script.Parent.Parent:WaitForChild("Palette"))
local AssetLibrary = require(script.Parent.Parent:WaitForChild("AssetLibrary"))
local PartFactory = require(script.Parent.Parent:WaitForChild("PartFactory"))
local Common = require(script.Parent:WaitForChild("Common"))
local Types = require(script.Parent:WaitForChild("Types"))

local C = PropTuning.crumblePlatform
local CrumblePlatform = {}

function CrumblePlatform.build(entry: Types.Entry, ctx: Types.Context): Types.Prop
	local frame = Common.frame(entry)
	local warningTime = Common.param(entry, "warning_time", C.warningTime)
	local respawnTime = Common.param(entry, "respawn_time", C.respawnTime)
	local size = Common.size(C.size)
	local center = frame * CFrame.new(0, Units.studs(C.centerY), 0)
	local collider = PartFactory.part(ctx.geometry, {
		Name = "CrumblePlatform",
		Size = size,
		CFrame = center,
		Transparency = 1,
	})
	-- 2×2 losetas visuales con una ranura entre ellas.
	local tiles = {}
	local gap = 0.25
	for ix = -1, 1, 2 do
		for iz = -1, 1, 2 do
			local rest = center * CFrame.new(ix * size.X / 4, 0, iz * size.Z / 4)
			local tile = PartFactory.visual(ctx.geometry, {
				Name = "Tile",
				Size = Vector3.new(size.X / 2 - gap, size.Y, size.Z / 2 - gap),
				CFrame = rest,
				Color = if (ix + iz) == 0 then Palette.stone else Palette.stoneDark,
			})
			table.insert(tiles, { part = tile, rest = rest })
		end
	end
	-- Malla migrada: sus losetas (Tile_*) sustituyen a las provisionales.
	local visual = AssetLibrary.instantiate("PLAT_Crumble", ctx.geometry, frame)
	if visual then
		for _, tile in tiles do
			tile.part:Destroy()
		end
		table.clear(tiles)
		for name, part in visual.parts do
			if name:sub(1, 5) == "Tile_" then
				table.insert(tiles, { part = part, rest = part.CFrame })
			end
		end
	end
	local sensor = PartFactory.trigger(ctx.triggerFolder, "CrumbleSensor", {
		Size = Common.size(C.sensorSize),
		CFrame = frame * CFrame.new(0, Units.studs(C.sensorCenterY), 0),
	})

	local state: "idle" | "shaking" | "falling" | "gone" | "rebuilding" = "idle"
	local timer = 0
	ctx.triggers:register(sensor, {
		onEnter = function()
			if state ~= "idle" then
				return
			end
			state = "shaking"
			timer = 0
			ctx.session:playSfx("crumble")
		end,
	})

	local prop = {}
	function prop.step(_self, dt: number)
		if state == "idle" then
			return
		end
		timer += dt
		if state == "shaking" then
			for _, tile in tiles do
				tile.part.CFrame = tile.rest * CFrame.new((math.random() * 2 - 1) * 0.14, 0, (math.random() * 2 - 1) * 0.14)
			end
			if timer >= warningTime then
				state = "falling"
				timer = 0
				collider.CanCollide = false
				collider.CanQuery = false
			end
		elseif state == "falling" then
			local done = true
			for i, tile in tiles do
				local t = math.clamp((timer - (i - 1) * 0.05) / C.fallTime, 0, 1)
				done = done and t >= 1
				tile.part.CFrame = tile.rest * CFrame.new(0, -Units.studs(C.fallDistance) * t * t, 0)
			end
			if done then
				state = "gone"
				timer = 0
				for _, tile in tiles do
					tile.part.Transparency = 1
				end
			end
		elseif state == "gone" then
			if timer >= respawnTime then
				state = "rebuilding"
				timer = 0
				for _, tile in tiles do
					tile.part.CFrame = tile.rest
					tile.part.Transparency = 0
				end
				collider.CanCollide = true
				collider.CanQuery = true
			end
		elseif state == "rebuilding" then
			local s = 0.2 + 0.8 * Common.backOut(timer / 0.25)
			for _, tile in tiles do
				tile.part.CFrame = tile.rest * CFrame.new(0, (s - 1) * size.Y, 0)
			end
			if timer >= 0.25 then
				state = "idle"
			end
		end
	end
	return prop
end

return CrumblePlatform
