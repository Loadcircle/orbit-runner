class_name SeasonScoring
extends RefCounted
## Points of a season level run. The leaderboard adds the best points of each
## level and breaks ties with the total of the best times (lower is better).

const MEDAL_POINTS := [0, 400, 700, 1000]
const GEM_POINTS := 100
const SPARK_POINTS := 200
const FLAWLESS_POINTS := 150


## `spark_ratio`: sparks collected / sparks in the level (0..1).
static func points(medal: int, gems: int, spark_ratio: float, flawless: bool) -> int:
	return MEDAL_POINTS[clampi(medal, 0, 3)] + gems * GEM_POINTS + roundi(clampf(spark_ratio, 0.0, 1.0) * SPARK_POINTS) \
		+ (FLAWLESS_POINTS if flawless else 0)


static func max_points() -> int:
	return points(3, 3, 1.0, true)
