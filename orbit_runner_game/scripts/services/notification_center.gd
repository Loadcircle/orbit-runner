class_name NotificationCenter
extends RefCounted
## Reminders (energy full, new season, last day of a season, new daily
## challenge). Each one is scheduled by id; when its time comes it lands in the
## in-game inbox. On Android the OrbitNotifications plugin (see
## docs/LIVE_SERVICE.md) also shows it as a system notification while the game
## is closed. Push messages from the online service (FCM) will arrive here too.
##
## Texts are stored as translation keys + arguments and translated on display.

signal inbox_changed

const PLUGIN := "OrbitNotifications"
const INBOX_LIMIT := 30

var enabled := true
var _data: Dictionary
var _android: Object


func _init(data: Dictionary) -> void:
	_data = data
	if typeof(_data.get("scheduled")) != TYPE_DICTIONARY:
		_data["scheduled"] = {}
	if typeof(_data.get("inbox")) != TYPE_ARRAY:
		_data["inbox"] = []
	if Engine.has_singleton(PLUGIN):
		_android = Engine.get_singleton(PLUGIN)


func has_system_notifications() -> bool:
	return _android != null


## Asks Android 13+ for the notification permission (no-op elsewhere).
func request_permission() -> void:
	if _android:
		_android.requestPermission()


## Schedules (or moves) reminder `id` for the unix time `at`. Past `expires`
## (if given) it is dropped instead of reaching the inbox late.
func schedule(id: String, at: int, title_key: String, body_key: String, args: Array = [], expires := 0) -> void:
	var current: Dictionary = _data["scheduled"].get(id, {})
	if int(current.get("at", -1)) == at and current.get("body", "") == body_key and current.get("args", []) == args:
		return
	_data["scheduled"][id] = {"at": at, "title": title_key, "body": body_key, "args": args, "expires": expires}
	if _android and enabled:
		var delay := maxi(at - GameClock.now(), 1)
		_android.schedule(_android_id(id), delay, TranslationServer.translate(title_key),
				_format(body_key, args))
	SaveService.request_save()


func cancel(id: String) -> void:
	if not _data["scheduled"].has(id):
		return
	_data["scheduled"].erase(id)
	if _android:
		_android.cancel(_android_id(id))
	SaveService.request_save()


func is_scheduled(id: String) -> bool:
	return _data["scheduled"].has(id)


## Moves every reminder whose time has passed into the inbox. Returns them.
func deliver_due() -> Array[Dictionary]:
	var now := GameClock.now()
	var delivered: Array[Dictionary] = []
	for id in _data["scheduled"].keys():
		var item: Dictionary = _data["scheduled"][id]
		if int(item["at"]) <= now:
			_data["scheduled"].erase(id)
			var expires := int(item.get("expires", 0))
			if enabled and (expires <= 0 or now < expires):
				delivered.append(post(item["title"], item["body"], item.get("args", []), int(item["at"])))
	return delivered


## Adds a message to the inbox right away.
func post(title_key: String, body_key: String, args: Array = [], at := -1) -> Dictionary:
	var message := {"title": title_key, "body": body_key, "args": args, "at": at if at >= 0 else GameClock.now(),
			"read": false}
	var inbox: Array = _data["inbox"]
	inbox.push_front(message)
	while inbox.size() > INBOX_LIMIT:
		inbox.pop_back()
	SaveService.request_save()
	inbox_changed.emit()
	return message


func inbox() -> Array:
	return _data["inbox"]


func unread_count() -> int:
	var count := 0
	for m in _data["inbox"]:
		if not m["read"]:
			count += 1
	return count


func mark_all_read() -> void:
	for m in _data["inbox"]:
		m["read"] = true
	SaveService.request_save()
	inbox_changed.emit()


## Turning reminders off cancels the system ones; the inbox keeps working.
func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if _android:
		for id in _data["scheduled"]:
			if value:
				var item: Dictionary = _data["scheduled"][id]
				_android.schedule(_android_id(id), maxi(int(item["at"]) - GameClock.now(), 1),
						TranslationServer.translate(item["title"]), _format(item["body"], item.get("args", [])))
			else:
				_android.cancel(_android_id(id))


static func title_of(message: Dictionary) -> String:
	return _format(message["title"], [])


static func body_of(message: Dictionary) -> String:
	return _format(message["body"], message.get("args", []))


static func _format(key: String, args: Array) -> String:
	var text := TranslationServer.translate(key)
	return text % args if not args.is_empty() else text


static func _android_id(id: String) -> int:
	return absi(hash(id)) % 2147483647
