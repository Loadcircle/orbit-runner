--!strict
-- ÚNICO sitio con IDs de assets subidos a Roblox (rbxassetid://…). Nunca se escriben a
-- mano en otro módulo (guía §3.8). Vacío hasta que se suban mallas y audio (H8): los
-- módulos que los usan caen a formas nativas o a silencio si falta un ID.
-- No inventar IDs: solo se rellenan con los que devuelva la subida real.

return {
	meshes = {} :: { [string]: string }, -- p. ej. PROP_Yoyo = "rbxassetid://…"
	sounds = {} :: { [string]: string }, -- p. ej. jump = "rbxassetid://…"
	music = {} :: { [string]: string }, -- p. ej. isles = "rbxassetid://…"
}
