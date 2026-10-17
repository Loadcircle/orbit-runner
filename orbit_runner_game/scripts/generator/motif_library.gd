class_name MotifLibrary
extends RefCounted
## The route sections the generator chains. Each motif asks one movement
## question and annotates the technique that answers it ("tech" in the route
## metadata), which the bot executes instead of guessing.
##
## families: technique families the level must demand for the motif to appear.
## mechanics: LevelSpec mechanics it needs. hazard: adds hazards.

const D := LevelSpec.Difficulty

const MOTIFS := {
	"stairs": {"question": "Saltos con subida, ritmo constante", "families": ["jump"], "mechanics": [],
			"hazard": false},
	"long_gap": {"question": "Elegir salto largo o impulso aéreo", "families": ["long|dash"], "mechanics": [],
			"hazard": false},
	"crumble_chain": {"question": "No detenerse", "families": ["jump"], "mechanics": ["crumble"], "hazard": false},
	"timed_windows": {"question": "Esperar y cruzar a tiempo", "families": ["timing"], "mechanics": ["timed"],
			"hazard": false},
	"mover_chain": {"question": "Leer trayectorias", "families": ["timing"], "mechanics": ["mover"],
			"hazard": false},
	"spinner_island": {"question": "Saltar el brazo en el momento justo", "families": ["timing"],
			"mechanics": ["spinner"], "hazard": true},
	"spike_corridor": {"question": "Precisión lateral", "families": ["jump"], "mechanics": ["spikes"],
			"hazard": true},
	"patrol_bots": {"question": "Leer patrón y pasar", "families": ["timing"], "mechanics": ["patrol"],
			"hazard": true},
	"laser_low": {"question": "Deslizar a tiempo", "families": ["slide"], "mechanics": ["laser"], "hazard": true},
	"wind_tower": {"question": "Subir y aterrizar arriba", "families": ["wind"], "mechanics": ["wind"],
			"hazard": false},
	"trampoline_high": {"question": "Calcular el bote", "families": ["trampoline"], "mechanics": ["trampoline"],
			"hazard": false},
	"yoyo_disc": {"question": "Hueco solo cruzable con el disco", "families": ["disc"], "mechanics": ["yoyo"],
			"hazard": false},
	"boost_run": {"question": "Velocidad y salto lejano", "families": ["boost"], "mechanics": ["boost"],
			"hazard": false},
	"combo": {"question": "Encadenar técnicas sin descanso", "families": ["long|dash|boost|disc"], "mechanics": [],
			"hazard": false},
	"turn": {"question": "Reorientar cámara", "families": ["jump"], "mechanics": [], "hazard": false},
}


## Motif ids the generator may place next.
static func available(g: LevelGenerator) -> Array[String]:
	var result: Array[String] = []
	for id in MOTIFS:
		var info: Dictionary = MOTIFS[id]
		var ok := true
		for mechanic in info["mechanics"]:
			if not g.spec.allows(mechanic):
				ok = false
		for family_option in info["families"]:
			var any := false
			for family in (family_option as String).split("|"):
				if g.has_family(family):
					any = true
			if not any:
				ok = false
		if id == "combo" and g.profile.combo_pieces < 2:
			ok = false
		if ok:
			result.append(id)
	if result.is_empty():
		result.append("stairs")
	return result


static func build(id: String, g: LevelGenerator) -> void:
	match id:
		"stairs":
			_stairs(g)
		"long_gap":
			_long_gap(g)
		"crumble_chain":
			_crumble_chain(g)
		"timed_windows":
			_timed_windows(g)
		"mover_chain":
			_mover_chain(g)
		"spinner_island":
			_spinner_island(g)
		"spike_corridor":
			_spike_corridor(g)
		"patrol_bots":
			_patrol_bots(g)
		"laser_low":
			_laser_low(g)
		"wind_tower":
			_wind_tower(g)
		"trampoline_high":
			_trampoline_high(g)
		"yoyo_disc":
			_yoyo_disc(g)
		"boost_run":
			_boost_run(g)
		"combo":
			_combo(g)
		"turn":
			_turn(g)
		_:
			_stairs(g)


# ------------------------------------------------------------------ motifs

static func _stairs(g: LevelGenerator) -> void:
	var count := g.rng.randi_range(2, 4)
	var dir := -1.0 if g.rng.randf() < 0.25 and g.spec.mode != LevelSpec.Mode.TOWER else 1.0
	for i in count:
		var top := minf(g.profile.max_rise, g.reach.max_rise("jump") - 0.2)
		var rise := g.rng.randf_range(0.4, top) * dir
		var side := g.rng.randf_range(-1.0, 1.0) if g.difficulty() >= D.HARD else 0.0
		g.place_plat(g.size_key(), "jump", g.gap_for("jump", rise), rise, side)
		g.b.decorate(1)


static func _long_gap(g: LevelGenerator) -> void:
	var tech := g.pick_tech(["long", "dash"])
	g.ensure_platform(6.0)
	var rise := 0.0 if tech == "long" else g.rng.randf_range(-1.0, 0.5)
	g.place_plat(g.landing_size(g.profile.landing_after_long_gap), tech, g.gap_for(tech, rise), rise)
	g.b.decorate(1)


static func _crumble_chain(g: LevelGenerator) -> void:
	g.ensure_platform(3.0)
	var count := g.rng.randi_range(g.profile.crumble_chain.x, g.profile.crumble_chain.y)
	var hard := g.difficulty() >= D.HARD
	for i in count:
		var rise := g.rng.randf_range(0.0, 0.8) if hard and g.rng.randf() < 0.5 else 0.0
		var side := g.rng.randf_range(-1.8, 1.8) if hard else 0.0
		g.b.crumble(clampf(g.gap_for("jump", rise), 1.5, 3.2), rise, side)
		g.tag_piece("jump", {"no_wait": true})
	g.place_plat(g.landing_size(4.0), "jump", clampf(g.gap_for("jump", 0.0), 1.5, 3.2), 0.0)


static func _timed_windows(g: LevelGenerator) -> void:
	g.ensure_platform(3.0)
	var count := clampi(g.rng.randi_range(2, 2 + g.difficulty()), 2, 4)
	var on := g.profile.timed_on_time
	var off := g.profile.timed_off_time
	# Each platform appears ~0.8 s after the previous one: keep moving and ride the wave.
	var step := 0.8 / (on + off)
	for i in count:
		var rise := 0.5 if g.difficulty() >= D.MEDIUM and g.rng.randf() < 0.3 else 0.0
		g.b.timed(g.rng.randf_range(2.2, 2.8), rise, fmod(i * step, 1.0), on, off)
		g.tag_piece("jump", {"wait": "timed"})
	g.place_plat(g.landing_size(6.0), "jump", 2.5, 0.0)
	g.extra_time += 0.5


static func _mover_chain(g: LevelGenerator) -> void:
	g.ensure_platform(3.0)
	var count := 1 if g.difficulty() < D.HARD else g.rng.randi_range(1, 2 if g.difficulty() == D.HARD else 3)
	var period := g.rng.randf_range(4.0, 5.0) if g.difficulty() < D.HARD else g.rng.randf_range(3.5, 4.5)
	var side_sign := 1.0 if g.rng.randf() < 0.5 else -1.0
	var last_axis := ""
	for i in count:
		var axes := ["fwd", "side", "up"]
		axes.erase(last_axis)
		var axis: String = axes[g.rng.randi() % axes.size()]
		var travel := g.rng.randf_range(6.0, 8.0)
		if axis == "side":
			travel = g.rng.randf_range(5.0, 7.0) * side_sign
			side_sign = -side_sign
		elif axis == "up":
			travel = g.rng.randf_range(4.0, 6.0)
		# Alternate phases so each platform waits at its start while the previous one arrives.
		g.b.mover(2.5, travel, axis, period, 0.0, 0.5 if i % 2 == 1 else 0.0)
		g.tag_piece("ride", {"wait": "mover"})
		last_axis = axis
	g.place_plat(g.landing_size(6.0), "jump", 2.0, 0.0)
	g.extra_time += period * 0.3


static func _spinner_island(g: LevelGenerator) -> void:
	g.place_plat("XL", "jump", g.gap_for("jump", 0.0), 0.0)
	var speed := g.profile.spinner_speed * (1.0 if g.rng.randf() < 0.5 else -1.0)
	g.b.spinner(0.0, 0.0, speed, g.rng.randf() * 360.0)
	g.tag_piece("jump", {"hazard": "spinner"})
	g.add_hazards(1)
	g.extra_time += 180.0 / absf(speed) * 0.4


static func _spike_corridor(g: LevelGenerator) -> void:
	var size := "L" if g.rng.randf() < 0.5 else "XL"
	g.place_plat(size, "jump", g.gap_for("jump", 0.0), 0.0)
	var length := g.b.last_size.y
	var width := g.b.last_size.x
	var count := g.rng.randi_range(1, 2) + g.difficulty()
	var z := -length * 0.5 + 4.0
	var side := 1.0 if g.rng.randf() < 0.5 else -1.0
	var placed := 0
	for i in count:
		if z > length * 0.5 - 2.5:
			break
		if g.difficulty() >= D.HARD and i % 3 == 2:
			# Centre spike: lanes stay open on both sides.
			g.b.spikes(0.0, z)
		else:
			g.b.spikes(side * (width * 0.5 - 1.1), z)
			side = -side
		placed += 1
		z += g.rng.randf_range(2.4, 3.2)
	g.tag_piece("jump", {"hazard": "spikes"})
	g.add_hazards(placed)


static func _patrol_bots(g: LevelGenerator) -> void:
	var size := "L" if g.rng.randf() < 0.5 else "XL"
	g.place_plat(size, "jump", g.gap_for("jump", 0.0), 0.0)
	var length := g.b.last_size.y
	var width := g.b.last_size.x
	var count := 1 if g.difficulty() < D.HARD or length < 12.0 else 2
	var z := -length * 0.5 + 5.0
	for i in count:
		var dir := 1.0 if i % 2 == 0 else -1.0
		g.b.patrol(-dir * (width * 0.5 - 0.6), z, dir * (width * 0.5 - 0.6), z, g.profile.patrol_speed, i * 0.5)
		z += 3.5
	g.tag_piece("jump", {"hazard": "patrol"})
	g.add_hazards(count)
	g.extra_time += 0.8 * count


static func _laser_low(g: LevelGenerator) -> void:
	var size := "L" if g.rng.randf() < 0.5 else "XL"
	g.place_plat(size, "jump", g.gap_for("jump", 0.0), 0.0)
	var length := g.b.last_size.y
	var count := clampi(1 + g.rng.randi_range(0, g.difficulty()), 1, 3)
	var z := -length * 0.5 + 4.0
	var placed := 0
	for i in count:
		if z > length * 0.5 - 2.0:
			break
		var blink := g.difficulty() >= D.MEDIUM and g.rng.randf() < 0.5
		g.b.laser(z, g.rng.randf_range(1.4, 2.0) if blink else 0.0, i * 0.33)
		placed += 1
		z += 2.5
	g.tag_piece("jump", {"hazard": "laser"})
	g.add_hazards(placed)


static func _wind_tower(g: LevelGenerator) -> void:
	g.ensure_platform(3.0)
	var height := clampf(g.rng.randf_range(7.0, 8.0 + 1.5 * g.difficulty()), 7.0, 12.0)
	g.b.wind(g.rng.randf_range(1.0, 1.5), height, -2.0)
	g.tag_piece("wind")
	g.place_plat(g.landing_size(6.0), "air", 1.5, -0.5)
	g.extra_time += height / 9.0


static func _trampoline_high(g: LevelGenerator) -> void:
	g.ensure_platform(6.0)
	var strong := g.difficulty() >= D.MEDIUM and g.rng.randf() < 0.4
	var strength := 24.0 if strong else 20.0
	g.b.trampoline(0.0, g.b.last_size.y * 0.5 - 1.5, strength)
	g.last_clean = false
	var rise := g.rng.randf_range(7.0, 8.0) if strong else g.rng.randf_range(4.0, 5.0)
	g.place_plat(g.landing_size(6.0), "trampoline", g.rng.randf_range(2.0, 3.0), rise)
	g.tag_piece("trampoline", {"strength": strength})
	g.extra_time += 0.8


static func _yoyo_disc(g: LevelGenerator) -> void:
	g.ensure_platform(6.0)
	if g.rng.randf() < 0.6:
		var rise := g.rng.randf_range(-1.0, 1.0)
		g.place_plat(g.landing_size(g.profile.landing_after_long_gap), "yoyo_air", g.gap_for("yoyo_air", rise), rise)
	else:
		var rise := g.rng.randf_range(2.6, 3.4)
		g.place_plat("M" if g.rng.randf() < 0.5 else "L", "yoyo_ground", g.rng.randf_range(1.0, 1.5), rise)
		g.extra_time += 0.5
	g.b.decorate(1)


static func _boost_run(g: LevelGenerator) -> void:
	g.ensure_platform(6.0)
	g.b.boost(0.0, g.b.last_size.y * 0.5 - MovementReach.BOOST_RUNWAY)
	g.last_clean = false
	var rise := g.rng.randf_range(-1.0, 0.0)
	g.place_plat(g.landing_size(g.profile.landing_after_long_gap), "boost", g.gap_for("boost", rise), rise)


static func _combo(g: LevelGenerator) -> void:
	var options: Array = []
	for tech in ["long", "dash", "boost", "yoyo_air"]:
		var family: String = "disc" if tech == "yoyo_air" else tech
		if g.has_family(family):
			options.append(tech)
	var previous := ""
	for i in g.profile.combo_pieces:
		var choices := options.duplicate()
		if choices.size() > 1:
			choices.erase(previous)
		var tech: String = choices[g.rng.randi() % choices.size()]
		g.ensure_platform(6.0)
		if tech == "boost":
			g.b.boost(0.0, g.b.last_size.y * 0.5 - MovementReach.BOOST_RUNWAY)
			g.last_clean = false
		var rise := 0.0 if tech == "long" else g.rng.randf_range(-0.5, 0.5)
		var landing := g.landing_size(maxf(g.profile.landing_after_long_gap, 6.0))
		g.place_plat(landing, tech, g.gap_for(tech, rise), rise)
		previous = tech


static func _turn(g: LevelGenerator) -> void:
	g.place_plat("Wide" if g.rng.randf() < 0.6 else "L", "jump", g.gap_for("jump", 0.0) * 0.8, 0.0)
	# Keep the heading within ±90° of the start so the route never folds back.
	var degrees := 90.0 if g.rng.randf() < 0.5 else -90.0
	if g.b.yaw >= 89.0:
		degrees = -90.0
	elif g.b.yaw <= -89.0:
		degrees = 90.0
	g.b.turn(degrees)
	g.b.decorate(1)
