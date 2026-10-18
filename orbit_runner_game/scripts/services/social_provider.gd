class_name SocialProvider
extends RefCounted
## Friends who play the game and invitations. The real provider reads friends
## from the linked Google/Facebook account through the online service.
## A friend is {id, name, outfit, rival (index in RivalRoster or -1)}.

var account: Dictionary


func _init(data: Dictionary) -> void:
	account = data
	if typeof(account.get("friends")) != TYPE_ARRAY:
		account["friends"] = []


func friends() -> Array[Dictionary]:
	return []


## Short code a friend types (or opens as a link) to add this player.
func invite_code() -> String:
	var id := String(account.get("user_id", ""))
	var h := absi(hash(id)) % 1679616
	return "ORB-%s" % String.num_int64(h, 36).to_upper().lpad(4, "0")


func invite_text() -> String:
	return TranslationServer.translate("INVITE_TEXT") % invite_code()


## Adds the player behind `code`. Returns the friend, or {} if not found.
func redeem(_code: String) -> Dictionary:
	return {}
