class_name GhostRunner
extends Node3D
## Draws a recorded run as a translucent protagonist that follows the level
## timer, so the player races their best time.

const MODEL := preload("res://art/models/CHR_Adventurer.glb")

var level: Level
var replay: RunReplay

var _model: Node3D
var _anim: AnimationPlayer
var _current := ""


func _ready() -> void:
	top_level = true
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	ToonMaterials.apply_variant(_model, ToonMaterials.GHOST)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Outline shells stay opaque: hide them so the ghost reads as see-through.
		for i in (mesh.mesh.get_surface_count() if mesh.mesh else 0):
			var mat := mesh.get_active_material(i) as ShaderMaterial
			if mat and mat.shader == ToonMaterials.OUTLINE:
				mesh.visible = false
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for anim_name in ["Idle", "Run", "Fall", "Slide", "Dash", "Bounce"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	if level == null or replay == null:
		return
	var pose := replay.pose_at(level.elapsed)
	if pose.is_empty() or pose["finished"]:
		visible = false
		return
	visible = true
	global_position = pose["position"]
	rotation.y = pose["yaw"]
	var state := int(pose["state"])
	var anim_name: String = RunReplay.ANIMATIONS[state] if state < RunReplay.ANIMATIONS.size() else "Idle"
	if _anim and anim_name != _current and _anim.has_animation(anim_name):
		_current = anim_name
		_anim.play(anim_name, 0.12)
