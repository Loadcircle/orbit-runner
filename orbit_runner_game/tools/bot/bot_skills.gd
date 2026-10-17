extends RefCounted
## Skill profiles of the validation bot. All profiles play only through the
## InputMap; what changes is the simulated human error.
##   reaction: delay (s) between "the way is clear" and moving
##   timing: standard deviation (s) of button presses around the ideal moment
##   direction: standard deviation (degrees) of the steering error
##   rescue: chance of saving a short jump with a dash or the yo-yo
##   give_up: deaths on the same motif that end the attempt (a frustrated player)

const PROFILES := {
	"perfect": {"name": "perfect", "reaction": 0.0, "timing": 0.0, "direction": 0.0, "rescue": 1.0, "give_up": 6},
	"expert": {"name": "expert", "reaction": 0.12, "timing": 0.04, "direction": 3.0, "rescue": 0.8, "give_up": 3},
	"casual": {"name": "casual", "reaction": 0.22, "timing": 0.09, "direction": 7.0, "rescue": 0.4, "give_up": 3},
	"novice": {"name": "novice", "reaction": 0.32, "timing": 0.15, "direction": 12.0, "rescue": 0.1, "give_up": 3},
}
const ORDER := ["perfect", "expert", "casual", "novice"]


static func get_profile(profile_name: String) -> Dictionary:
	return PROFILES.get(profile_name, PROFILES["perfect"])
