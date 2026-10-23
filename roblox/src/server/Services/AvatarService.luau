--!strict
-- Escala del avatar fija (guía §2.1): el alcance no puede depender del avatar de cada
-- jugador. Las Avatar Settings del juego no se pueden fijar por script, así que al cargar
-- la apariencia se aplica una HumanoidDescription con las escalas estándar R15 (nativo,
-- solo en el servidor). La cápsula de juego es propia y no depende del avatar; esto
-- mantiene además la proporción visual (≈ 1.57 alturas de personaje por salto).

local Players = game:GetService("Players")

local SCALES = {
	HeightScale = 1,
	WidthScale = 1,
	DepthScale = 1,
	HeadScale = 1,
	BodyTypeScale = 0,
	ProportionScale = 0,
}

local AvatarService = {}

local function normalize(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok or not description then
		return
	end
	local changed = false
	for property, value in SCALES do
		if (description :: any)[property] ~= value then
			(description :: any)[property] = value
			changed = true
		end
	end
	if changed then
		pcall(function()
			humanoid:ApplyDescription(description)
		end)
	end
end

function AvatarService.start()
	local function onPlayer(player: Player)
		player.CharacterAppearanceLoaded:Connect(normalize)
		if player.Character and player:HasAppearanceLoaded() then
			normalize(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return AvatarService
