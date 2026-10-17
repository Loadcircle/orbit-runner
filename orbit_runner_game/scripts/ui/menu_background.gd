class_name MenuBackground
extends Node3D
## Animated 3D backdrop for menus: the protagonist on a floating island with
## the yo-yo disc spinning nearby and a slowly orbiting camera.

const ISLE_THEME: BiomeTheme = preload("res://resources/biomes/isles.tres")
const CHARACTER := preload("res://art/models/CHR_Adventurer.glb")
const ISLAND := preload("res://art/models/PLAT_Isle_L.glb")
const SMALL_ISLAND := preload("res://art/models/PLAT_Isle_S.glb")
const TREE := preload("res://art/models/ENV_Tree.glb")
const PINE := preload("res://art/models/ENV_Pine.glb")
const DISC := preload("res://art/models/PROP_YoyoDisc.glb")
const TRAMPOLINE := preload("res://art/models/PROP_Trampoline.glb")
const GEM := preload("res://art/models/PROP_Gem.glb")
const ROCK := preload("res://art/models/ENV_Rock_A.glb")

@export var orbit_speed := 0.08
@export var camera_offset := Vector3(0, 2.3, 7.5)
## Shifts the framing so menus on the left leave the character visible.
@export var look_offset := Vector3(-1.6, 1.0, 0)

var _camera: Camera3D
var _pivot: Node3D
var _disc: Node3D
var _gem: Node3D
var _character: Node3D
var _time := 0.0


func _ready() -> void:
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	var island := ISLAND.instantiate() as Node3D
	geometry.add_child(island)
	for data in [[SMALL_ISLAND, Vector3(9, -2.5, -8)], [SMALL_ISLAND, Vector3(-10, 1.5, -12)], [ISLAND, Vector3(4, -6, -26)]]:
		var extra := (data[0] as PackedScene).instantiate() as Node3D
		extra.position = data[1]
		geometry.add_child(extra)
	_add(TREE, Vector3(-1.8, 0, -3.2), 0.4)
	_add(PINE, Vector3(2.0, 0, -3.8), 1.2)
	_add(TREE, Vector3(9, -2.5, -8), 2.0)
	_add(ROCK, Vector3(1.9, 0, 2.6), 0.7)
	_add(TRAMPOLINE, Vector3(-2.0, 0, 1.6), 0.0)
	_character = CHARACTER.instantiate() as Node3D
	_character.rotation.y = deg_to_rad(200)
	add_child(_character)
	var anim := _character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("Idle"):
		anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("Idle")
	_disc = DISC.instantiate() as Node3D
	_disc.position = Vector3(2.6, 1.6, -0.6)
	_disc.rotation_degrees = Vector3(12, 0, -8)
	add_child(_disc)
	_gem = GEM.instantiate() as Node3D
	_gem.position = Vector3(-10, 3.2, -12)
	add_child(_gem)
	LevelEnvironment.build(self, ISLE_THEME, -14.0)
	_pivot = Node3D.new()
	add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 55
	_camera.far = 500
	_pivot.add_child(_camera)
	_camera.position = camera_offset
	_camera.look_at_from_position(camera_offset, look_offset)
	_camera.current = true
	AudioDirector.play_music(&"menu")


func play_celebration() -> void:
	var anim := _character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("Victory"):
		anim.get_animation("Victory").loop_mode = Animation.LOOP_LINEAR
		anim.play("Victory", 0.2)


func _process(delta: float) -> void:
	_time += delta
	_pivot.rotation.y = sin(_time * orbit_speed) * 0.5
	var spin := _disc.find_child("Spin", true, false) as Node3D
	if spin:
		spin.rotate_y(2.5 * delta)
	_disc.position.y = 1.6 + sin(_time * 1.6) * 0.15
	_gem.rotate_y(delta)


func _add(scene: PackedScene, pos: Vector3, yaw: float) -> void:
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation.y = yaw
	$Geometry.add_child(node)
