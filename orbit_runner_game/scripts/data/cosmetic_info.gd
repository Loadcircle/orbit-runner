class_name CosmeticInfo
extends Resource
## A reward that changes the protagonist or the yo-yo colours.

enum Kind { OUTFIT, YOYO }
enum Unlock { DEFAULT, SPARKS, GEMS, GOLD_MEDALS, ACHIEVEMENT, MASTERY }

@export var id: StringName
@export var kind: Kind = Kind.OUTFIT
@export var title_key: String
@export var unlock: Unlock = Unlock.DEFAULT
## Sparks price, gem count, gold medal count or world index (MASTERY), depending on `unlock`.
@export var cost: int = 0
## Achievement id when unlock == ACHIEVEMENT.
@export var achievement_id: StringName
## Material name (from the GLB) -> colour. Outfits use M_Jacket, M_Accent,
## M_Pants, M_Hair, M_Teal; yo-yos use M_Yoyo, M_YoyoAccent, M_DiscCyan.
@export var colors: Dictionary = {}
## Trail colour used by the yo-yo and dash effects.
@export var trail_color: Color = Color(0.13, 0.83, 0.93)
