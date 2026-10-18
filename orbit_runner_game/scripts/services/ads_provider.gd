class_name AdsProvider
extends RefCounted
## Rewarded ads. The game only asks for a rewarded ad and waits for the result;
## a real provider (AdMob through Firebase, family-safe mode) replaces the
## simulated one without touching the callers.

## Families policy: the audience includes children, so only family-safe,
## non-personalised ads may be requested.
var family_safe := true


func is_available() -> bool:
	return false


## Shows a rewarded ad. Returns true only if it was watched to the end.
func show_rewarded(_placement: StringName) -> bool:
	return false
