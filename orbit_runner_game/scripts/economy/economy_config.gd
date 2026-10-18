class_name EconomyConfig
extends Resource
## Freemium values: energy, rewarded ads and the shop catalogue. Starting
## hypotheses to tune with players; remote configuration will override them.

@export_group("Energy")
@export var energy_max: int = 10
## Seconds to recover one energy point while below the maximum.
@export var energy_recharge_seconds: int = 1200
## Energy spent when a level attempt starts (death and respawn are free).
@export var energy_per_attempt: int = 1
## The tutorial never costs energy, so a new player can always start.
@export var free_tutorial := true

@export_group("Rewarded ads")
@export var ad_energy: int = 2
@export var ads_per_day: int = 5
## Length of the simulated ad.
@export var simulated_ad_seconds: float = 5.0

@export_group("Seasons")
## Sparks for the final position: top 1, top 3, top 10, top 50 %, everyone else who played.
@export var season_rewards := PackedInt32Array([1500, 1000, 600, 300, 100])

@export_group("Shop")
@export var products: Array[StoreProduct] = []


func product(id: StringName) -> StoreProduct:
	for p in products:
		if p.id == id:
			return p
	return null
