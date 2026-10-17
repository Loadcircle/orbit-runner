extends Node3D
## Dev tool: renders the protagonist and a few props under a biome's lighting.
## Args after "--": <out.png> [biome id] [animation]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var biome_id := args[1] if args.size() > 1 else "isles"
	var anim_name := args[2] if args.size() > 2 else "Idle"
	var biome: BiomeTheme = load("res://resources/biomes/%s.tres" % biome_id)
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	var plat := (load("res://art/models/PLAT_Isle_M.glb" if biome_id == "isles" else ("res://art/models/PLAT_Toy_M.glb" if biome_id == "toyworks" else "res://art/models/PLAT_Ruin_M.glb")) as PackedScene).instantiate()
	geometry.add_child(plat)
	LevelEnvironment.build(self, biome, -20.0)
	var positions := [Vector3(0, 0, 0), Vector3(1.4, 0, -0.6), Vector3(-1.4, 0, -0.6)]
	var yaws := [0.0, 0.7, -0.7]
	for i in 3:
		var c := (load("res://art/models/CHR_Adventurer.glb") as PackedScene).instantiate() as Node3D
		c.position = positions[i]
		c.rotation.y = yaws[i]
		add_child(c)
		var anim := c.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim:
			var n: String = anim_name if i == 0 else (["Run", "Jump"][i - 1])
			if anim.has_animation(n):
				anim.play(n)
				anim.seek(0.3, true)
				anim.pause()
	for data in [["PROP_Spark", Vector3(0.9, 1.1, 0.8)], ["PROP_Gem", Vector3(-0.9, 1.1, 0.8)]]:
		var p := (load("res://art/models/%s.glb" % data[0]) as PackedScene).instantiate() as Node3D
		p.position = data[1]
		add_child(p)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.look_at_from_position(Vector3(0.6, 1.5, -4.2), Vector3(0, 0.85, 0))
	cam.current = true
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	cam.look_at_from_position(Vector3(0.25, 1.25, -1.3), Vector3(0, 1.15, 0))
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.replace(".png", "_face.png"))
	get_tree().quit()
