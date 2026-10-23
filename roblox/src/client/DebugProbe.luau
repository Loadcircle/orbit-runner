--!strict
-- Sonda de depuración para inspeccionar el estado desde Studio (MCP / barra de comandos),
-- que no comparten _G ni la caché de require con los scripts del juego.
-- Player.OrbitRunnerProbe (BindableFunction): Invoke("state") devuelve una instantánea;
-- Invoke("command", nombre, ...) ejecuta un comando registrado (solo pruebas).

local Players = game:GetService("Players")

local DebugProbe = {}

local providers: { [string]: () -> any } = {}
local commands: { [string]: (...any) -> any } = {}

function DebugProbe.provide(name: string, provider: () -> any)
	providers[name] = provider
end

function DebugProbe.command(name: string, handler: (...any) -> any)
	commands[name] = handler
end

function DebugProbe.start()
	local probe = Instance.new("BindableFunction")
	probe.Name = "OrbitRunnerProbe"
	probe.OnInvoke = function(kind: string, name: string?, ...: any): any
		if kind == "state" then
			local snapshot = {}
			for key, provider in providers do
				if name == nil or name == key then
					local ok, value = pcall(provider)
					snapshot[key] = if ok then value else ("error: " .. tostring(value))
				end
			end
			return snapshot
		elseif kind == "command" and name and commands[name] then
			return commands[name](...)
		end
		return nil
	end
	probe.Parent = Players.LocalPlayer
end

return DebugProbe
