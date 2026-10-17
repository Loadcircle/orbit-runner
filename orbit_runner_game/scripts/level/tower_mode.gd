class_name TowerMode
extends Node
## Wind Tower: an endless climb of generated floors whose difficulty rises
## floor by floor, with a checkpoint every 10 floors. New floors are built a
## few at a time ahead of the player; the run ends when the player leaves.

## Floors kept generated ahead of the player.
const FLOORS_AHEAD := 5

var level: Level
var generator: LevelGenerator
var floor_reached := 0
var _checkpoint_piece := 0


static func create(spec: LevelSpec) -> Level:
	var generator := LevelGenerator.new()
	var level := generator.begin_tower(spec, FLOORS_AHEAD + 3)
	var mode := TowerMode.new()
	mode.name = "TowerMode"
	mode.generator = generator
	level.add_child(mode)
	return level


func _ready() -> void:
	level = get_parent() as Level
	level.tower = self


func _physics_process(_delta: float) -> void:
	if level.player == null or level.finished:
		return
	var route: Array = level.get_meta("route", [])
	if level.player.is_on_floor() and not level.player.is_dead:
		var piece := level.route_index()
		if piece >= 0 and piece < route.size():
			for i in range(piece, -1, -1):
				if route[i].has("floor"):
					floor_reached = maxi(floor_reached, int(route[i]["floor"]))
					break
	# One floor per tick at most, so building never causes a long frame.
	if generator.floor_number < floor_reached + FLOORS_AHEAD:
		generator.extend_tower(1)
		level.refresh_route()
		_update_kill_height()


func on_checkpoint() -> void:
	_checkpoint_piece = maxi(level.route_index(), 0)
	_update_kill_height()


## Falling far below the current section respawns quickly, wherever the climb is.
func _update_kill_height() -> void:
	var route: Array = level.get_meta("route", [])
	var lowest := INF
	for i in range(_checkpoint_piece, route.size()):
		lowest = minf(lowest, (route[i]["pos"] as Vector3).y)
	if lowest != INF:
		level.kill_height = lowest - 9.0
