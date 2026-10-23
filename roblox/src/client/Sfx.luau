--!strict
-- Efectos de sonido (AudioDirector.play_sfx de Godot) y vibración (Settings.vibrate).
-- Los sonidos salen de Shared/AssetIds.sounds; si un ID falta, no suena nada.
-- Vibración con HapticService nativo cuando el dispositivo la admite.

local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AssetIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetIds"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local Sfx = {}

local sounds: { [string]: Sound } = {}

function Sfx.play(name: string)
	local id = AssetIds.sounds[name]
	if not id then
		return
	end
	local sound = sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Parent = SoundService
		sounds[name] = sound
	end
	sound.Volume = 0.5 * (Settings.get("masterVolume") :: number) * (Settings.get("sfxVolume") :: number)
	SoundService:PlayLocalSound(sound)
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
