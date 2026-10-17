class_name PickupBurst
extends RefCounted
## Plays a pickup's one-shot particle burst after the pickup itself is freed.


static func release(burst: CPUParticles3D) -> void:
	if burst == null or burst.get_parent() == null:
		return
	var level := burst.get_parent().get_parent()
	if level == null:
		return
	burst.reparent(level)
	burst.restart()
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
