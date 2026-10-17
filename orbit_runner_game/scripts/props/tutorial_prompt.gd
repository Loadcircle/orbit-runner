class_name TutorialPrompt
extends Area3D
## Shows a short contextual hint while the player is inside the area.
## `text_key` is a translation key; when `<key>_TOUCH` exists it is used on
## touch screens instead.

@export var text_key := ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body is Player and Level.current:
		Level.current.show_prompt(self)


func _on_body_exited(body: Node) -> void:
	if body is Player and Level.current:
		Level.current.hide_prompt(self)
