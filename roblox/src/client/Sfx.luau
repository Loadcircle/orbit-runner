--!strict
-- Efectos de sonido (AudioDirector.play_sfx de Godot) y vibración (Settings.vibrate).
-- Los sonidos son los de la plantilla Platformer (R16): sus AudioPlayer de
-- ReplicatedStorage.Platformer.Sounds y ReplicatedStorage.Gameplay.Sounds, con un tono
-- distinto por evento, enrutados al bus "UI" de SoundService.Audio (API de audio nueva).
-- Si falta una fuente, no suena nada.
-- Vibración con HapticService nativo cuando el dispositivo la admite.

local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Settings = require(script.Parent:WaitForChild("Settings"))

local Sfx = {}

-- evento → { carpeta, AudioPlayer, tono (PlaybackSpeed relativo), volumen relativo }
type Cue = { folder: "Platformer" | "Gameplay", source: string, pitch: number, volume: number }

local CUES: { [string]: Cue } = {
	spark = { folder = "Gameplay", source = "PickupCoin", pitch = 1.0, volume = 0.7 },
	gem = { folder = "Gameplay", source = "PickupCoin", pitch = 1.35, volume = 1.0 },
	checkpoint = { folder = "Platformer", source = "DoubleJump", pitch = 1.25, volume = 1.2 },
	goal = { folder = "Platformer", source = "LongJump", pitch = 1.15, volume = 1.0 },
	fail = { folder = "Platformer", source = "WallImpact", pitch = 0.8, volume = 1.5 },
	boost = { folder = "Platformer", source = "Dash", pitch = 1.1, volume = 1.0 },
	trampoline = { folder = "Platformer", source = "DoubleJumpAlt", pitch = 0.8, volume = 1.4 },
	crumble = { folder = "Platformer", source = "FloorImpact", pitch = 0.7, volume = 1.0 },
	yoyo_throw = { folder = "Platformer", source = "Roll", pitch = 1.4, volume = 0.8 },
	yoyo_deploy = { folder = "Platformer", source = "FloorImpact", pitch = 1.6, volume = 0.8 },
	yoyo_return = { folder = "Platformer", source = "Dash", pitch = 1.6, volume = 0.4 },
	bounce_yoyo = { folder = "Platformer", source = "DoubleJumpAlt", pitch = 1.2, volume = 1.4 },
}

local function source(cue: Cue): AudioPlayer?
	local root = ReplicatedStorage:FindFirstChild(cue.folder)
	local folder = root and root:FindFirstChild("Sounds")
	local player = folder and folder:FindFirstChild(cue.source)
	return if player and player:IsA("AudioPlayer") then player else nil
end

local function bus(): Instance?
	local audio = SoundService:FindFirstChild("Audio")
	local busses = audio and audio:FindFirstChild("Busses")
	local ui = busses and busses:FindFirstChild("UI")
	return ui and ui:FindFirstChildOfClass("AudioCompressor")
end

function Sfx.play(name: string)
	local cue = CUES[name]
	local template = cue and source(cue)
	local target = bus()
	if not cue or not template or not target then
		return
	end
	local player = template:Clone()
	player.PlaybackSpeed *= cue.pitch
	player.Volume *= cue.volume * (Settings.get("masterVolume") :: number) * (Settings.get("sfxVolume") :: number)
	local wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = target
	wire.Parent = player
	player.Parent = SoundService
	player:Play()
	player.Ended:Once(function()
		player:Destroy()
	end)
end

function Sfx.vibrate(milliseconds: number)
	if not Settings.get("vibration") then
		return
	end
	local motor = Enum.VibrationMotor.Small
	local ok, supported = pcall(function()
		return HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1)
			and HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, motor)
	end)
	if not ok or not supported then
		return
	end
	HapticService:SetMotor(Enum.UserInputType.Gamepad1, motor, 0.8)
	task.delay(milliseconds / 1000, function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, motor, 0)
	end)
end

return Sfx
