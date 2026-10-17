class_name PlayerVisual
extends Node3D
## Animation selection, squash & stretch, cosmetics and small effects for the
## protagonist model. Reads the Player state; never changes gameplay.

const LOOPING := ["Idle", "Run", "Fall", "Slide", "Dash", "Bounce", "Victory"]
const BLEND := 0.12
const OUTLINE_COLOR := Color(0.09, 0.1, 0.16)

@export var player_path: NodePath = ^".."

var celebrating := false

var _player: Player
var _anim: AnimationPlayer
var _current := ""
var _squash := Vector3.ONE
var _flip := 0.0
var _hip_yoyo: Node3D
var _hand: Node3D
var _dust: CPUParticles3D

# Squash scales from the feet; Flip rotates around the body centre.
@onready var _squash_node: Node3D = $Squash
@onready var _flip_node: Node3D = $Squash/Flip
@onready var _model: Node3D = $Squash/Flip/Model
@onready var _trail: CPUParticles3D = $Trail


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for anim_name in LOOPING:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_hip_yoyo = _model.find_child("HipYoyo", true, false) as Node3D
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "hand.R"
		skeleton.add_child(attachment)
		_hand = attachment
	_apply_outline(_model)
	_dust = _make_dust()
	add_child(_dust)
	if _player:
		_player.jumped.connect(func():
			_squash = Vector3(0.85, 1.2, 0.85)
			AudioDirector.play_sfx(&"jump", -4.0, 1.0, 0.06))
		_player.landed.connect(_on_landed)
		_player.bounced.connect(_on_bounced)
		_player.dashed.connect(func(): AudioDirector.play_sfx(&"dash", -3.0, 1.0, 0.05))
		_player.slid.connect(func(): AudioDirector.play_sfx(&"slide", -5.0, 1.0, 0.05))


func _process(delta: float) -> void:
	if _player == null:
		return
	_choose_animation()
	_squash = _squash.lerp(Vector3.ONE, clampf(12.0 * delta, 0.0, 1.0))
	if _flip > 0.0:
		_flip = maxf(_flip - delta * 2.4, 0.0)
	_squash_node.scale = _squash
	_flip_node.rotation.x = -(1.0 - _flip) * TAU if _flip > 0.0 else 0.0
	_trail.emitting = _player.is_dashing or _player.is_sliding or _player.horizontal_speed() > _player.tuning.run_speed + 2.0


func _choose_animation() -> void:
	var p := _player
	var anim_name := "Idle"
	var speed_scale := 1.0
	if celebrating:
		anim_name = "Victory"
	elif p.is_dead:
		anim_name = "Hurt"
	elif p.is_dashing:
		anim_name = "Dash"
	elif p.is_sliding:
		anim_name = "Slide"
	elif not p.is_on_floor():
		if p.bounce_timer > 0.0:
			anim_name = "Bounce"
		elif p.velocity.y > 0.5:
			anim_name = "Jump"
		else:
			anim_name = "Fall"
	elif p.throw_timer > 0.0 and p.horizontal_speed() < 1.0:
		anim_name = "Throw"
	elif p.horizontal_speed() > 0.6:
		anim_name = "Run"
		speed_scale = clampf(p.horizontal_speed() / p.tuning.run_speed, 0.5, 1.6) * 1.15
	play(anim_name, speed_scale)


func play(anim_name: String, speed_scale := 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed_scale
	if anim_name != _current:
		_current = anim_name
		_anim.play(anim_name, BLEND)


## Animation being played (recorded by RunRecorder for ghosts).
func current_animation() -> String:
	return _current


func set_holster_visible(value: bool) -> void:
	if _hip_yoyo:
		_hip_yoyo.visible = value


func hand_position() -> Vector3:
	if _hand:
		return _hand.global_position
	return global_position + Vector3.UP


func apply_cosmetics(outfit: CosmeticInfo, yoyo_item: CosmeticInfo) -> void:
	if outfit:
		recolor(_model, outfit.colors)
	if yoyo_item:
		recolor(_model, yoyo_item.colors)
		var mat := _trail.mesh.surface_get_material(0) as StandardMaterial3D if _trail.mesh else null
		if mat:
			mat = mat.duplicate()
			mat.albedo_color = Color(yoyo_item.trail_color, 0.8)
			_trail.mesh = _trail.mesh.duplicate()
			_trail.mesh.surface_set_material(0, mat)


func _on_landed(impact: float) -> void:
	var k := clampf(impact / 25.0, 0.1, 0.35)
	_squash = Vector3(1.0 + k, 1.0 - k, 1.0 + k)
	if impact > 6.0:
		AudioDirector.play_sfx(&"land", linear_to_db(clampf(impact / 25.0, 0.2, 1.0)) - 4.0, 1.0, 0.08)
		_dust.amount = 8 if impact < 14.0 else 14
		_dust.restart()


func _on_bounced(source: StringName) -> void:
	_squash = Vector3(0.8, 1.3, 0.8)
	if source == &"yoyo" or source == &"trampoline":
		_flip = 1.0


## Replaces surface colours whose material name matches a key of `colors`.
static func recolor(root: Node, colors: Dictionary) -> void:
	if colors.is_empty():
		return
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var base := mesh_instance.mesh.surface_get_material(i)
			if base == null or not colors.has(base.resource_name):
				continue
			mesh_instance.set_surface_override_material(i, ToonMaterials.recolored(base, colors[base.resource_name]))


## Soft puff ring at the feet on hard landings.
func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "LandDust"
	p.emitting = false
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.35
	p.emission_ring_inner_radius = 0.25
	p.emission_ring_height = 0.0
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.6
	p.damping_min = 4.0
	p.damping_max = 6.0
	p.gravity = Vector3(0, 0.6, 0)
	p.position = Vector3(0, 0.08, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.2
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.98, 0.92)
	mat.disable_receive_shadows = true
	mesh.material = mat
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _apply_outline(root: Node) -> void:
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.012
	outline.albedo_color = OUTLINE_COLOR
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = outline
