extends Node
## Freemium and online-facing services: energy, ads, shop, account, friends
## and reminders. Each external service is an interface with a simulated
## provider for now; the Firebase providers will be swapped in here.

signal account_changed

const ECONOMY: EconomyConfig = preload("res://resources/economy/economy_config.tres")
## Seconds between checks for due reminders and season changes.
const TICK := 30.0

enum AgeGroup { UNKNOWN, CHILD, TEEN_OR_ADULT }

var economy: EconomyConfig = ECONOMY
var energy: Energy
var ads: AdsProvider
var store: StoreProvider
var auth: AuthProvider
var social: SocialProvider
var notifications: NotificationCenter

var _data: Dictionary
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("clock_hours="):
			GameClock.offset_seconds = roundi(float(arg.get_slice("=", 1)) * 3600.0)
	_timer = Timer.new()
	_timer.wait_time = TICK
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	Settings.changed.connect(func():
		if notifications:
			notifications.set_enabled(bool(Settings.get_value("notifications"))))
	reload()


## Rebuilds every service from the save (also after resetting progress).
func reload() -> void:
	_data = SaveService.section("services")
	for key in ["energy", "account", "notifications"]:
		if typeof(_data.get(key)) != TYPE_DICTIONARY:
			_data[key] = {}
	var account: Dictionary = _data["account"]
	if String(account.get("user_id", "")) == "":
		# Anonymous id until a real account exists (leaderboards, invitations).
		account["user_id"] = "local-%d-%d" % [Time.get_unix_time_from_system(), randi()]
		SaveService.request_save()
	energy = Energy.new(_data["energy"], economy)
	energy.changed.connect(_schedule_energy)
	ads = SimulatedAds.new(economy.simulated_ad_seconds)
	store = SimulatedStore.new()
	auth = SimulatedAuth.new(account)
	social = SimulatedSocial.new(account)
	notifications = NotificationCenter.new(_data["notifications"])
	notifications.enabled = bool(Settings.get_value("notifications"))
	refresh()


## Delivers due reminders, pays out finished seasons and reschedules.
func refresh() -> void:
	for message in notifications.deliver_due():
		AchievementToast.show_message(IconGlyph.Icon.BELL, NotificationCenter.title_of(message),
				NotificationCenter.body_of(message))
	_settle_seasons()
	_schedule_energy()
	_schedule_seasons()
	_schedule_daily()


# ------------------------------------------------------------------ account & age

func age_group() -> AgeGroup:
	return int(_data["account"].get("age_group", AgeGroup.UNKNOWN)) as AgeGroup


## Under 13: no social sign-in, generated names only, family-safe ads, and
## purchases or invitations behind the parental gate.
func is_child() -> bool:
	return age_group() != AgeGroup.TEEN_OR_ADULT


## Only the age group is kept, never the birth year.
func set_age_group(group: AgeGroup) -> void:
	_data["account"]["age_group"] = group
	if group == AgeGroup.CHILD:
		auth.sign_out()
		if String(_data["account"].get("name", "")) != "" and not bool(_data["account"].get("name_generated", true)):
			_data["account"]["name"] = ""
	SaveService.request_save()
	account_changed.emit()


func display_name() -> String:
	var name := String(_data["account"].get("name", ""))
	if name == "":
		name = random_safe_name(String(_data["account"]["user_id"]))
		_data["account"]["name"] = name
		_data["account"]["name_generated"] = true
	return name


## `generated`: picked from the safe list (the only option for children).
func set_display_name(name: String, generated: bool) -> void:
	name = name.strip_edges().left(16)
	if name == "" or (is_child() and not generated):
		return
	_data["account"]["name"] = name
	_data["account"]["name_generated"] = generated
	SaveService.request_save()
	account_changed.emit()


static func random_safe_name(seed_text: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	return RivalRoster.NAME_HEADS[rng.randi_range(0, RivalRoster.NAME_HEADS.size() - 1)] \
		+ RivalRoster.NAME_TAILS[rng.randi_range(0, RivalRoster.NAME_TAILS.size() - 1)] + str(rng.randi_range(10, 99))


func sign_in(provider: StringName) -> bool:
	if is_child():
		return false
	var ok: bool = await auth.sign_in(provider)
	if ok:
		account_changed.emit()
	return ok


func sign_out() -> void:
	auth.sign_out()
	account_changed.emit()


# ------------------------------------------------------------------ energy, ads and shop

## Plays a rewarded ad for energy. Returns true when the reward was granted.
func watch_ad_for_energy() -> bool:
	if energy.ads_left_today() <= 0 or not ads.is_available():
		return false
	var watched: bool = await ads.show_rewarded(&"energy")
	if not watched:
		return false
	energy.reward_ad()
	AchievementToast.show_message(IconGlyph.Icon.BOLT, tr("TOAST_ENERGY"), tr("ENERGY_GAINED") % economy.ad_energy)
	return true


## Parental gate, store purchase and delivery. Returns true when granted.
func buy(product: StoreProduct) -> bool:
	if not await ParentalGate.check():
		return false
	var paid: bool = await store.purchase(product)
	if not paid:
		return false
	match product.kind:
		StoreProduct.Kind.ENERGY:
			energy.add(product.amount)
		StoreProduct.Kind.UNLIMITED_ENERGY:
			energy.add_unlimited(product.amount)
		StoreProduct.Kind.SPARKS:
			Progress.add_sparks(product.amount)
		_:
			return false
	AudioDirector.play_sfx(&"purchase")
	AchievementToast.show_message(IconGlyph.Icon.CART, tr("TOAST_PURCHASE"), tr(product.title_key))
	return true


# ------------------------------------------------------------------ reminders

func _schedule_energy() -> void:
	if energy == null or notifications == null:
		return
	var left := energy.seconds_to_full()
	if left > 0:
		notifications.schedule("energy_full", GameClock.now() + left, "NOTIF_ENERGY_TITLE", "NOTIF_ENERGY_BODY",
				[economy.energy_max])
	else:
		notifications.cancel("energy_full")


func _schedule_seasons() -> void:
	var now := GameClock.now()
	for s in Season.all():
		var id := "season_start_%s" % s["id"]
		if Season.starts_at(s) > now and Season.starts_at(s) - now < 30 * 86400:
			notifications.schedule(id, Season.starts_at(s), "NOTIF_SEASON_TITLE", "NOTIF_SEASON_BODY",
					[int(s["number"]), Season.level_count(s)], Season.ends_at(s))
		var last := "season_last_%s" % s["id"]
		var last_at := Season.ends_at(s) - Season.LAST_CALL
		if last_at > now and Progress.season_totals(String(s["id"]))["levels"] > 0:
			notifications.schedule(last, last_at, "NOTIF_SEASON_LAST_TITLE", "NOTIF_SEASON_LAST_BODY", [int(s["number"])],
					Season.ends_at(s))


func _schedule_daily() -> void:
	# Only for players who did today's challenge: a nudge when the next one opens.
	var today := DailyChallenge.today_key()
	if bool(Progress.daily_record(today)["completed"]):
		notifications.schedule("daily_next", GameClock.now() + DailyChallenge.seconds_until_tomorrow() + 60,
				"NOTIF_DAILY_TITLE", "NOTIF_DAILY_BODY")


## Final position and reward for seasons that ended while the player was in them.
func _settle_seasons() -> void:
	var now := GameClock.now()
	for s in Season.finished(now):
		var state := Progress.season_state(String(s["id"]))
		if bool(state["rewarded"]) or Progress.season_totals(String(s["id"]))["levels"] == 0:
			continue
		var rank := Leaderboard.player_rank(s, Season.ends_at(s))
		state["final_rank"] = rank.x
		state["final_size"] = rank.y
		state["rewarded"] = true
		var reward := season_reward(rank)
		Progress.add_sparks(reward)
		notifications.post("NOTIF_SEASON_END_TITLE", "NOTIF_SEASON_END_BODY", [int(s["number"]), rank.x, rank.y, reward])
		SaveService.request_save()


## Sparks for a final position: top 1, top 3, top 10, top half, the rest.
func season_reward(rank: Vector2i) -> int:
	var r := economy.season_rewards
	if rank.x <= 1:
		return r[0]
	if rank.x <= 3:
		return r[1]
	if rank.x <= 10:
		return r[2]
	if rank.x <= maxi(rank.y / 2, 1):
		return r[3]
	return r[4]
