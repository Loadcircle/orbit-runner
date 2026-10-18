class_name Energy
extends RefCounted
## Energy for level attempts: one point per attempt, recharged over time up to
## the maximum. Purchases and ads may take it above the maximum; recharge only
## runs below it. State lives in the save as plain data.

signal changed

var config: EconomyConfig
var _data: Dictionary


## `data`: the save section for energy (filled with defaults when empty).
func _init(data: Dictionary, economy: EconomyConfig) -> void:
	_data = data
	config = economy
	if not _data.has("amount"):
		_data["amount"] = config.energy_max
		_data["last_tick"] = GameClock.now()
	for key in ["unlimited_until", "ads_today"]:
		if not _data.has(key):
			_data[key] = 0
	if not _data.has("ads_day"):
		_data["ads_day"] = ""


## Current energy after applying the recharge since the last check.
func amount() -> int:
	_recharge()
	return int(_data["amount"])


func maximum() -> int:
	return config.energy_max


func is_full() -> bool:
	return amount() >= config.energy_max


func is_unlimited() -> bool:
	return int(_data["unlimited_until"]) > GameClock.now()


func unlimited_seconds_left() -> int:
	return maxi(int(_data["unlimited_until"]) - GameClock.now(), 0)


func can_start(cost: int) -> bool:
	return cost <= 0 or is_unlimited() or amount() >= cost


## Spends the energy of one attempt. Returns false when there is not enough.
func spend(cost: int) -> bool:
	if cost <= 0 or is_unlimited():
		return true
	var current := amount()
	if current < cost:
		return false
	if current >= config.energy_max:
		# The recharge timer starts when the energy drops below the maximum.
		_data["last_tick"] = GameClock.now()
	_data["amount"] = current - cost
	_changed()
	return true


func add(points: int) -> void:
	_data["amount"] = amount() + points
	_changed()


func add_unlimited(minutes: int) -> void:
	_data["unlimited_until"] = maxi(int(_data["unlimited_until"]), GameClock.now()) + minutes * 60
	_changed()


## Seconds until the next point (0 when full).
func seconds_to_next() -> int:
	if amount() >= config.energy_max:
		return 0
	return maxi(int(_data["last_tick"]) + config.energy_recharge_seconds - GameClock.now(), 0)


## Seconds until the energy is full again (0 when full).
func seconds_to_full() -> int:
	var missing := config.energy_max - amount()
	if missing <= 0:
		return 0
	return seconds_to_next() + (missing - 1) * config.energy_recharge_seconds


func ads_left_today() -> int:
	if _data["ads_day"] != GameClock.today_key():
		return config.ads_per_day
	return maxi(config.ads_per_day - int(_data["ads_today"]), 0)


## Grants the energy of a watched rewarded ad.
func reward_ad() -> void:
	var today := GameClock.today_key()
	if _data["ads_day"] != today:
		_data["ads_day"] = today
		_data["ads_today"] = 0
	_data["ads_today"] = int(_data["ads_today"]) + 1
	add(config.ad_energy)


func _recharge() -> void:
	var current := int(_data["amount"])
	if current >= config.energy_max:
		return
	var now := GameClock.now()
	var last := int(_data["last_tick"])
	if now < last:
		# Clock moved backwards: restart the timer instead of freezing it.
		_data["last_tick"] = now
		return
	var gained := (now - last) / config.energy_recharge_seconds
	if gained <= 0:
		return
	current = mini(current + gained, config.energy_max)
	_data["amount"] = current
	_data["last_tick"] = now if current >= config.energy_max else last + gained * config.energy_recharge_seconds
	_changed()


func _changed() -> void:
	SaveService.request_save()
	changed.emit()
