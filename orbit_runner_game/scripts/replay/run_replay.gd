class_name RunReplay
extends RefCounted
## One recorded run: the gameplay input of every physics tick (to replay or
## verify the run) and the protagonist's position every 0.1 s (to draw a
## ghost cheaply). Stored compressed in user://replays/.

const FORMAT := 1
## Bytes per tick: raw move x, raw move y (int16), buttons (u8), camera yaw (float).
const TICK_BYTES := 9
## Animations a ghost can show, indexed by the recorded state byte.
const ANIMATIONS := ["Idle", "Run", "Jump", "Fall", "Bounce", "Slide", "Dash", "Hurt", "Throw", "Victory"]
const SAMPLE_INTERVAL := 0.1
const BUTTONS := [&"jump", &"yoyo", &"action"]

## Level the run belongs to (campaign id, "daily_2026-10-18", ...).
var key := ""
var time := 0.0
var respawns := 0
var ticks := PackedByteArray()
## x, y, z, facing yaw per sample, from the moment the timer starts.
var samples := PackedFloat32Array()
## Animation per sample (index in ANIMATIONS).
var states := PackedByteArray()
var route_hash := ""


func tick_count() -> int:
	return ticks.size() / TICK_BYTES


func sample_count() -> int:
	return states.size()


## Ghost position and yaw at `elapsed` seconds of level time.
func pose_at(elapsed: float) -> Dictionary:
	var count := sample_count()
	if count == 0:
		return {}
	var f := clampf(elapsed / SAMPLE_INTERVAL, 0.0, count - 1.0)
	var i := int(f)
	var j := mini(i + 1, count - 1)
	var t := f - i
	var a := Vector3(samples[i * 4], samples[i * 4 + 1], samples[i * 4 + 2])
	var b := Vector3(samples[j * 4], samples[j * 4 + 1], samples[j * 4 + 2])
	# Respawns teleport: do not slide the ghost across the level.
	var pos := a if a.distance_to(b) > 4.0 else a.lerp(b, t)
	return {"position": pos, "yaw": lerp_angle(samples[i * 4 + 3], samples[j * 4 + 3], t), "state": states[i],
			"finished": elapsed >= count * SAMPLE_INTERVAL}


func to_bytes() -> PackedByteArray:
	var data := {"format": FORMAT, "key": key, "time": time, "respawns": respawns, "ticks": ticks,
			"samples": samples, "states": states, "route_hash": route_hash}
	var raw := var_to_bytes(data)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var header := PackedByteArray()
	header.resize(4)
	header.encode_u32(0, raw.size())
	return header + packed


static func from_bytes(bytes: PackedByteArray) -> RunReplay:
	if bytes.size() < 5:
		return null
	var raw := bytes.slice(4).decompress(bytes.decode_u32(0), FileAccess.COMPRESSION_ZSTD)
	var data: Variant = bytes_to_var(raw)
	if typeof(data) != TYPE_DICTIONARY or int(data.get("format", 0)) != FORMAT:
		return null
	var replay := RunReplay.new()
	replay.key = data["key"]
	replay.time = data["time"]
	replay.respawns = data["respawns"]
	replay.ticks = data["ticks"]
	replay.samples = data["samples"]
	replay.states = data["states"]
	replay.route_hash = data.get("route_hash", "")
	return replay
