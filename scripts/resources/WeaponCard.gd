class_name WeaponCard
extends Resource

enum WeaponClass {
	MELEE = 0,
	RANGED = 1,
	MAGIC = 2
}

@export var card_name: String = ""
@export var texture: Texture2D
@export var damage: int = 25
@export var weapon_class: WeaponClass = WeaponClass.MELEE


func get_class_label() -> String:
	match weapon_class:
		WeaponClass.MELEE:
			return "MELEE"
		WeaponClass.RANGED:
			return "RANGED"
		WeaponClass.MAGIC:
			return "MAGIC"
	return "UNKNOWN"
