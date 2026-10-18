class_name StoreProduct
extends Resource
## One item of the shop. Prices come from the store provider (simulated now,
## Google Play Billing through the online service later); `price_hint` is only
## shown by the simulated store.

enum Kind { ENERGY, UNLIMITED_ENERGY, SPARKS, SEASON_PASS }

@export var id: StringName
@export var title_key := ""
@export var desc_key := ""
@export var kind: Kind = Kind.ENERGY
## Energy points, sparks, or minutes of unlimited energy.
@export var amount: int = 0
@export var price_hint := ""
## Highlighted in the shop.
@export var featured := false
