class_name SimulatedSocial
extends SocialProvider
## Stand-in social graph: a linked account "finds" a few simulated runners as
## friends, and any well-formed invitation code adds one more. All of them are
## RivalRoster runners, so they have season results.

const LINKED_FRIENDS := 4


func friends() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var indices: Array[int] = []
	if String(account.get("provider", "")) != "":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(account.get("user_id", "")) + String(account["provider"]))
		while indices.size() < LINKED_FRIENDS:
			var i := rng.randi_range(0, RivalRoster.COUNT - 1)
			if not i in indices:
				indices.append(i)
	for i in account["friends"]:
		if not int(i) in indices:
			indices.append(int(i))
	for i in indices:
		var rival := RivalRoster.get_rival(i)
		result.append({"id": rival["id"], "name": rival["name"], "outfit": rival["outfit"], "rival": i})
	return result


func redeem(code: String) -> Dictionary:
	code = code.strip_edges().to_upper()
	if not code.begins_with("ORB-") or code.length() < 6 or code == invite_code():
		return {}
	var index := absi(hash(code)) % RivalRoster.COUNT
	if not index in account["friends"]:
		account["friends"].append(index)
		SaveService.request_save()
	var rival := RivalRoster.get_rival(index)
	return {"id": rival["id"], "name": rival["name"], "outfit": rival["outfit"], "rival": index}
