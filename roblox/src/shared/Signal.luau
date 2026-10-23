--!strict
-- Señal mínima en Luau puro (equivalente a las señales de Godot) para eventos locales
-- del cliente. Los eventos entre cliente y servidor usan RemoteEvents (Shared/Net).

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return (setmetatable({ _callbacks = {} }, Signal) :: any) :: Signal<T...>
end

function Signal:Connect(callback)
	local callbacks = self._callbacks
	table.insert(callbacks, callback)
	return {
		Disconnect = function()
			local index = table.find(callbacks, callback)
			if index then
				table.remove(callbacks, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, callback in table.clone(self._callbacks) do
		callback(...)
	end
end

function Signal:DisconnectAll()
	table.clear(self._callbacks)
end

return Signal
