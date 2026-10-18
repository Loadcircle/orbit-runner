class_name AuthProvider
extends RefCounted
## Player account and social sign-in (Google, Facebook). The real provider
## (Firebase Authentication) replaces the simulated one. Children under 13 do
## not get social sign-in; the caller checks `Services.is_child()` first.

const PROVIDERS: Array[StringName] = [&"google", &"facebook"]

## The save section "account": provider, user_id, name, age_group...
var account: Dictionary


func _init(data: Dictionary) -> void:
	account = data


func is_signed_in() -> bool:
	return String(account.get("provider", "")) != ""


func provider() -> StringName:
	return StringName(account.get("provider", ""))


## Stable id for leaderboards, also before signing in (anonymous player).
func user_id() -> String:
	return String(account.get("user_id", ""))


func sign_in(_provider: StringName) -> bool:
	return false


func sign_out() -> void:
	account["provider"] = ""
	SaveService.request_save()
