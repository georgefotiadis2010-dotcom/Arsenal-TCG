class_name CharacterCard
extends Resource

enum Affinity {
	MELEE = 0,
	RANGED = 1,
	MAGIC = 2
}

@export var card_name: String = ""
@export var texture: Texture2D
@export var max_hp: int = 100
@export var power: int = 20
@export var affinity: Affinity = Affinity.MELEE


func get_affinity_label() -> String:
	match affinity:
		Affinity.MELEE:
			return "MELEE"
		Affinity.RANGED:
			return "RANGED"
		Affinity.MAGIC:
			return "MAGIC"
	return "UNKNOWN"
