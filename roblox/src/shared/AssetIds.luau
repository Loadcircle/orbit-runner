--!strict
-- ÚNICO sitio con IDs de assets subidos a Roblox (rbxassetid://…). Nunca se escriben a
-- mano en otro módulo (guía §3.8). Los módulos que los usan caen a formas nativas o a
-- silencio si falta un ID.
-- No inventar IDs: solo se rellenan con los que devuelva la subida real.
-- meshes: asset → pieza → ID, subidos el 2026-10-23 con studio_tools/OrbitRunnerAssetUploader
-- al lugar 103224184916710. Los prefabs de ReplicatedStorage.Assets se montan desde aquí
-- con studio_tools/build_prefabs.luau.

return {
	meshes = {
		ENV_Pine = {
			Body = "rbxassetid://123690931133081",
		},
		ENV_Tree = {
			Body = "rbxassetid://117265884468521",
		},
		HAZ_LaserPost = {
			Body = "rbxassetid://110765729365204",
			Body_Glow = "rbxassetid://100600816235757",
		},
		HAZ_PatrolBot = {
			Body = "rbxassetid://99852476910237",
			Body_Glow = "rbxassetid://102192609420916",
		},
		HAZ_Spinner = {
			Arm = "rbxassetid://86004983850859",
			Arm_Glow = "rbxassetid://100602515711566",
			Body = "rbxassetid://80339421137288",
		},
		PLAT_Crumble = {
			Tile_LB = "rbxassetid://83719014962871",
			Tile_LF = "rbxassetid://106202827842021",
			Tile_RB = "rbxassetid://76457190516477",
			Tile_RF = "rbxassetid://102000185277059",
		},
		PLAT_Isle_L = {
			Body = "rbxassetid://90759483267864",
			Body_Glow = "rbxassetid://101343157129313",
		},
		PLAT_Isle_M = {
			Body = "rbxassetid://87771454588271",
			Body_Glow = "rbxassetid://81665552515391",
		},
		PLAT_Isle_S = {
			Body = "rbxassetid://120931986346518",
			Body_Glow = "rbxassetid://107335594553348",
		},
		PLAT_Isle_Strip = {
			Body = "rbxassetid://138350738364080",
			Body_Glow = "rbxassetid://80446896561419",
		},
		PLAT_Isle_Wide = {
			Body = "rbxassetid://79390817445883",
			Body_Glow = "rbxassetid://78221979817757",
		},
		PLAT_Isle_XL = {
			Body = "rbxassetid://75521146603091",
			Body_Glow = "rbxassetid://75806177812793",
		},
		PLAT_Moving = {
			Body = "rbxassetid://106760217045877",
			Body_Glow = "rbxassetid://116625896534613",
		},
		PLAT_Timed = {
			Body = "rbxassetid://121527784098736",
			Body_Glow = "rbxassetid://106004658071538",
		},
		PROP_BoostPad = {
			Body = "rbxassetid://137511098211622",
			Body_Glow = "rbxassetid://99387236788547",
		},
		PROP_Checkpoint = {
			Body = "rbxassetid://129467310257223",
			Body_Glow = "rbxassetid://106261907111271",
			Flag = "rbxassetid://72543627139720",
		},
		PROP_Gem = {
			Body_Glow = "rbxassetid://82914090668982",
		},
		PROP_GoalGate = {
			Body = "rbxassetid://117574773420987",
			Halo_Glow = "rbxassetid://119159750200968",
		},
		PROP_Spark = {
			Body_Glow = "rbxassetid://83438773780865",
		},
		PROP_Trampoline = {
			Body = "rbxassetid://71199880669504",
			Pad = "rbxassetid://104337018909842",
			Pad_Glow = "rbxassetid://140236960527605",
		},
		PROP_WindRing = {
			Body = "rbxassetid://80511234855068",
			Body_Glow = "rbxassetid://112730344027590",
			Rotor = "rbxassetid://114176194860657",
		},
		PROP_Yoyo = {
			Body = "rbxassetid://85385916926541",
			Body_Glow = "rbxassetid://84507633004503",
		},
		PROP_YoyoDisc = {
			Body = "rbxassetid://97367655909939",
			Body_Glow = "rbxassetid://74192172984724",
		},
	} :: { [string]: { [string]: string } },
	sounds = {} :: { [string]: string }, -- p. ej. jump = "rbxassetid://…"
	music = {} :: { [string]: string }, -- p. ej. isles = "rbxassetid://…"
}
