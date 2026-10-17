class_name CosmeticCatalog
extends Resource

@export var items: Array[CosmeticInfo] = []


func get_item(id: StringName) -> CosmeticInfo:
	for item in items:
		if item.id == id:
			return item
	return null


func of_kind(kind: CosmeticInfo.Kind) -> Array[CosmeticInfo]:
	var result: Array[CosmeticInfo] = []
	for item in items:
		if item.kind == kind:
			result.append(item)
	return result
