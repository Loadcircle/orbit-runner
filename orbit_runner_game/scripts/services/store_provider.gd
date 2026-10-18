class_name StoreProvider
extends RefCounted
## In-app purchases. The real provider (Google Play Billing, receipts checked
## by the online service) replaces the simulated one. Granting the item is the
## caller's job once `purchase` returns true.


func is_available() -> bool:
	return false


## Localised price of a product, as the store reports it.
func price(_product: StoreProduct) -> String:
	return ""


func purchase(_product: StoreProduct) -> bool:
	return false
