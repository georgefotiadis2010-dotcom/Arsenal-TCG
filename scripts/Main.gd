extends Control

enum TurnPhase {
	PLAYER_DRAW,
	PLAYER_ACTION,
	AI_TURN,
	GAME_OVER
}

enum AIState {
	IDLE,
	DRAW_AND_REFRESH,
	EVALUATE_COMBOS,
	EXECUTE_SUMMON,
	EXECUTE_EQUIP,
	EXECUTE_ATTACK,
	FINISH_TURN
}

const COST_SUMMON: int = 2
const COST_EQUIP: int = 1
const COST_ATTACK: int = 1
const MAX_HAND_SIZE: int = 5
const START_ENERGY: int = 3
const MAX_ENERGY_CAP: int = 5
const TARGET_KOS: int = 3

const CARD_PATHS: Array[String] = [
	"res://data/cyber_knight.tres",
	"res://data/shadow_ranger.tres",
	"res://data/arcane_mage.tres",
	"res://data/plasma_blade.tres",
	"res://data/laser_rifle.tres",
	"res://data/void_staff.tres"
]

var card_library: Array[Resource] = []

# Match & Turn State
var current_turn: int = 1
var current_phase: TurnPhase = TurnPhase.PLAYER_DRAW
var ai_state: AIState = AIState.IDLE

# Energy State
var player_max_energy: int = START_ENERGY
var player_energy: int = START_ENERGY
var ai_max_energy: int = START_ENERGY
var ai_energy: int = START_ENERGY

# Attack limit per turn (max 1 attack per turn)
var player_attacks_left: int = 1
var ai_attacks_left: int = 1

# Knockout counters
var player_kos_scored: int = 0
var ai_kos_scored: int = 0

# Decks & Hands
var player_deck: Array[Resource] = []
var player_hand: Array[Resource] = []
var ai_deck: Array[Resource] = []
var ai_hand: Array[Resource] = []

# Active Battlefield Slots
var player_active_char: CharacterCard = null
var player_char_hp: int = 0
var player_active_weapon: WeaponCard = null

var ai_active_char: CharacterCard = null
var ai_char_hp: int = 0
var ai_active_weapon: WeaponCard = null

# AI Planned Combo for State Machine
var ai_planned_char: CharacterCard = null
var ai_planned_weapon: WeaponCard = null

# UI Node References (bound from Main.tscn)
@onready var turn_banner_label: Label = %TurnBannerLabel
@onready var phase_banner_label: Label = %PhaseBannerLabel
@onready var score_label: Label = %ScoreLabel
@onready var combat_log_label: Label = %CombatLogLabel
@onready var affinity_banner: PanelContainer = %AffinityBanner
@onready var affinity_banner_label: Label = %AffinityBannerLabel

# AI Slot UI References
@onready var ai_char_panel: PanelContainer = %AICharPanel
@onready var ai_char_name_label: Label = %AICharNameLabel
@onready var ai_char_affinity_label: Label = %AICharAffinityLabel
@onready var ai_char_texture: TextureRect = %AICharTexture
@onready var ai_hp_bar: ProgressBar = %AIHPBar
@onready var ai_hp_label: Label = %AIHPLabel
@onready var ai_power_label: Label = %AIPowerLabel

@onready var ai_weapon_panel: PanelContainer = %AIWeaponPanel
@onready var ai_weapon_name_label: Label = %AIWeaponNameLabel
@onready var ai_weapon_class_label: Label = %AIWeaponClassLabel
@onready var ai_weapon_texture: TextureRect = %AIWeaponTexture
@onready var ai_weapon_dmg_label: Label = %AIWeaponDmgLabel
@onready var ai_total_atk_label: Label = %AITotalAtkLabel
@onready var ai_affinity_badge: Label = %AIAffinityBadge
@onready var ai_status_info_label: Label = %AIStatusInfoLabel

# Player Slot UI References
@onready var player_char_panel: PanelContainer = %PlayerCharPanel
@onready var player_char_name_label: Label = %PlayerCharNameLabel
@onready var player_char_affinity_label: Label = %PlayerCharAffinityLabel
@onready var player_char_texture: TextureRect = %PlayerCharTexture
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var player_power_label: Label = %PlayerPowerLabel

@onready var player_weapon_panel: PanelContainer = %PlayerWeaponPanel
@onready var player_weapon_name_label: Label = %PlayerWeaponNameLabel
@onready var player_weapon_class_label: Label = %PlayerWeaponClassLabel
@onready var player_weapon_texture: TextureRect = %PlayerWeaponTexture
@onready var player_weapon_dmg_label: Label = %PlayerWeaponDmgLabel
@onready var player_total_atk_label: Label = %PlayerTotalAtkLabel
@onready var player_affinity_badge: Label = %PlayerAffinityBadge

# Controls & Hand UI References
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var energy_pips_box: HBoxContainer = %EnergyPipsBox
@onready var deck_info_label: Label = %DeckInfoLabel
@onready var attack_button: Button = %AttackButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var hand_container: HBoxContainer = %HandContainer

# Game Over Overlay References
@onready var game_over_overlay: ColorRect = %GameOverOverlay
@onready var game_over_title: Label = %GameOverTitle
@onready var game_over_subtitle: Label = %GameOverSubtitle
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	randomize()
	_load_card_library()
	_apply_theme_styles()
	attack_button.pressed.connect(_on_attack_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	restart_button.pressed.connect(_start_new_match)
	_start_new_match()


func _load_card_library() -> void:
	card_library.clear()
	for path in CARD_PATHS:
		var res: Resource = load(path)
		if res != null:
			card_library.append(res)


func _build_deck() -> Array[Resource]:
	# Build a 12-card deck (2 copies of each of the 6 .tres cards)
	var deck: Array[Resource] = []
	for copy_idx in range(2):
		for card in card_library:
			deck.append(card.duplicate())
	deck.shuffle()
	return deck


func _draw_specific_type(deck: Array[Resource], want_character: bool) -> Resource:
	for i in range(deck.size()):
		var is_char: bool = deck[i] is CharacterCard
		if is_char == want_character:
			var card: Resource = deck[i]
			deck.remove_at(i)
			return card
	if not deck.is_empty():
		return deck.pop_back()
	return null


func _start_new_match() -> void:
	game_over_overlay.visible = false
	affinity_banner.visible = false

	current_turn = 1
	player_kos_scored = 0
	ai_kos_scored = 0

	player_active_char = null
	player_char_hp = 0
	player_active_weapon = null

	ai_active_char = null
	ai_char_hp = 0
	ai_active_weapon = null

	player_deck = _build_deck()
	ai_deck = _build_deck()
	player_hand.clear()
	ai_hand.clear()

	# Deploy AI's opening vanguard character so the arena has an active opponent on Turn 1
	var ai_starter: CharacterCard = _draw_specific_type(ai_deck, true) as CharacterCard
	if ai_starter != null:
		ai_active_char = ai_starter
		ai_char_hp = ai_starter.max_hp

	# Deal AI initial hand (3 cards: 1 character, 2 weapons/random)
	var ai_c1: Resource = _draw_specific_type(ai_deck, true)
	if ai_c1 != null:
		ai_hand.append(ai_c1)
	while ai_hand.size() < 3 and not ai_deck.is_empty():
		ai_hand.append(ai_deck.pop_back())

	# Deal Player initial hand (4 cards before Turn 1 draw -> becomes 5 cards on Turn 1 draw)
	# Guarantee 2 Characters and 2 Weapons so Player can immediately summon + equip on Turn 1
	for i in range(2):
		var pc: Resource = _draw_specific_type(player_deck, true)
		if pc != null:
			player_hand.append(pc)
		var pw: Resource = _draw_specific_type(player_deck, false)
		if pw != null:
			player_hand.append(pw)

	_log_combat("Match started! Summon a Character from your hand (2 Energy) and equip a matching Weapon (1 Energy).")
	_begin_player_turn()


func _begin_player_turn() -> void:
	if current_phase == TurnPhase.GAME_OVER:
		return

	current_phase = TurnPhase.PLAYER_DRAW
	# Energy starts at 3 on Turn 1 and increases by +1 per turn up to 5 max
	player_max_energy = mini(START_ENERGY + (current_turn - 1), MAX_ENERGY_CAP)
	player_energy = player_max_energy
	player_attacks_left = 1

	# Step 1: Draw 1 card (max hand size 5)
	_draw_card_for_player(true)

	# Step 2 & 3: Refresh Energy & enter Player Action Phase
	current_phase = TurnPhase.PLAYER_ACTION
	_update_all_ui()


func _draw_card_for_player(is_player: bool) -> void:
	var deck: Array[Resource] = player_deck if is_player else ai_deck
	var hand: Array[Resource] = player_hand if is_player else ai_hand
	var active_char: CharacterCard = player_active_char if is_player else ai_active_char

	if hand.size() >= MAX_HAND_SIZE or deck.is_empty():
		return

	# If player has no active character and no character in hand, prioritize drawing a character if one remains in deck
	var has_char_in_hand: bool = false
	for c in hand:
		if c is CharacterCard:
			has_char_in_hand = true
			break

	var drawn: Resource = null
	if active_char == null and not has_char_in_hand and _count_chars_in_array(deck) > 0:
		drawn = _draw_specific_type(deck, true)
	else:
		drawn = deck.pop_back()

	if drawn != null:
		hand.append(drawn)


func _count_chars_in_array(arr: Array[Resource]) -> int:
	var count: int = 0
	for item in arr:
		if item is CharacterCard:
			count += 1
	return count


func calculate_combat_damage(character: CharacterCard, weapon: WeaponCard) -> Dictionary:
	if character == null:
		return {"base": 0, "total": 0, "affinity_match": false}
	var base_attack: int = character.power
	var is_match: bool = false
	if weapon != null:
		base_attack += weapon.damage
		is_match = int(character.affinity) == int(weapon.weapon_class)
	var final_damage: int = base_attack
	if is_match:
		final_damage = int(round(float(base_attack) * 1.5))
	return {
		"base": base_attack,
		"total": final_damage,
		"affinity_match": is_match
	}


func _on_hand_card_clicked(hand_index: int) -> void:
	if current_phase != TurnPhase.PLAYER_ACTION:
		return
	if hand_index < 0 or hand_index >= player_hand.size():
		return

	var card: Resource = player_hand[hand_index]
	if card is CharacterCard:
		var char_card: CharacterCard = card as CharacterCard
		if player_energy < COST_SUMMON:
			_log_combat("Not enough Energy to Summon/Swap %s! Need %d Energy." % [char_card.card_name, COST_SUMMON])
			return
		player_energy -= COST_SUMMON
		player_hand.remove_at(hand_index)
		var action_verb: String = "Summoned" if player_active_char == null else "Swapped to"
		player_active_char = char_card
		player_char_hp = char_card.max_hp
		_animate_panel_pulse(player_char_panel)

		var combat_info: Dictionary = calculate_combat_damage(player_active_char, player_active_weapon)
		if combat_info["affinity_match"]:
			_show_affinity_match_indicator("AFFINITY MATCH! %s + %s (1.5x DMG = %d)" % [
				player_active_char.card_name,
				player_active_weapon.card_name,
				combat_info["total"]
			])
			_log_combat("%s %s (%d HP, %s) — AFFINITY MATCH with %s!" % [
				action_verb,
				char_card.card_name,
				char_card.max_hp,
				char_card.get_affinity_label(),
				player_active_weapon.card_name
			])
		else:
			_log_combat("%s %s (%d HP, %d PWR, %s Affinity)." % [
				action_verb,
				char_card.card_name,
				char_card.max_hp,
				char_card.power,
				char_card.get_affinity_label()
			])
		_update_all_ui()

	elif card is WeaponCard:
		var weapon_card: WeaponCard = card as WeaponCard
		if player_active_char == null:
			_log_combat("Summon an Active Character first before equipping %s!" % weapon_card.card_name)
			return
		if player_energy < COST_EQUIP:
			_log_combat("Not enough Energy to Equip %s! Need %d Energy." % [weapon_card.card_name, COST_EQUIP])
			return
		player_energy -= COST_EQUIP
		player_hand.remove_at(hand_index)
		player_active_weapon = weapon_card
		_animate_panel_pulse(player_weapon_panel)

		var combat_info: Dictionary = calculate_combat_damage(player_active_char, player_active_weapon)
		if combat_info["affinity_match"]:
			_show_affinity_match_indicator("AFFINITY MATCH! %s + %s -> %d DMG (1.5x!)" % [
				player_active_char.card_name,
				weapon_card.card_name,
				combat_info["total"]
			])
			_log_combat("Equipped %s on %s — AFFINITY MATCH! Total Attack multiplied by 1.5x to %d!" % [
				weapon_card.card_name,
				player_active_char.card_name,
				combat_info["total"]
			])
		else:
			_log_combat("Equipped %s (+%d DMG, %s) on %s. Total Attack: %d." % [
				weapon_card.card_name,
				weapon_card.damage,
				weapon_card.get_class_label(),
				player_active_char.card_name,
				combat_info["total"]
			])
		_update_all_ui()


func _on_attack_pressed() -> void:
	if current_phase != TurnPhase.PLAYER_ACTION:
		return
	if player_active_char == null:
		_log_combat("You must Summon a Character before attacking!")
		return
	if player_attacks_left <= 0:
		_log_combat("Max 1 attack per turn already used!")
		return
	if player_energy < COST_ATTACK:
		_log_combat("Not enough Energy to Attack! Need %d Energy." % COST_ATTACK)
		return
	if ai_active_char == null:
		_log_combat("AI has no active character on the field to attack!")
		return

	player_energy -= COST_ATTACK
	player_attacks_left -= 1

	var combat_info: Dictionary = calculate_combat_damage(player_active_char, player_active_weapon)
	var dmg: int = combat_info["total"]
	var is_match: bool = combat_info["affinity_match"]

	if is_match:
		_show_affinity_match_indicator("AFFINITY MATCH STRIKE! %d DAMAGE (1.5x)" % dmg)

	ai_char_hp = maxi(0, ai_char_hp - dmg)
	_animate_panel_pulse(player_char_panel)
	_animate_damage_flash(ai_char_panel)

	var match_tag: String = " [AFFINITY MATCH! 1.5x]" if is_match else ""
	_log_combat("%s attacks %s for %d DMG%s!" % [
		player_active_char.card_name,
		ai_active_char.card_name,
		dmg,
		match_tag
	])

	if ai_char_hp <= 0:
		var defeated_name: String = ai_active_char.card_name
		ai_active_char = null
		ai_active_weapon = null
		player_kos_scored += 1
		_log_combat("KNOCKOUT! AI's %s was defeated! (Player KOs: %d/%d)" % [
			defeated_name,
			player_kos_scored,
			TARGET_KOS
		])
		if _check_win_loss_condition():
			_update_all_ui()
			return

	_update_all_ui()


func _on_end_turn_pressed() -> void:
	if current_phase != TurnPhase.PLAYER_ACTION:
		return
	current_phase = TurnPhase.AI_TURN
	ai_state = AIState.DRAW_AND_REFRESH
	_update_all_ui()
	_advance_ai_state_machine()


func _advance_ai_state_machine() -> void:
	if current_phase != TurnPhase.AI_TURN:
		return

	match ai_state:
		AIState.DRAW_AND_REFRESH:
			ai_max_energy = mini(START_ENERGY + (current_turn - 1), MAX_ENERGY_CAP)
			ai_energy = ai_max_energy
			ai_attacks_left = 1
			_draw_card_for_player(false)
			_log_combat("AI Turn %d: AI draws a card and refreshes to %d Energy." % [current_turn, ai_energy])
			_update_all_ui()
			ai_state = AIState.EVALUATE_COMBOS
			get_tree().create_timer(0.55).timeout.connect(_advance_ai_state_machine)

		AIState.EVALUATE_COMBOS:
			_evaluate_ai_best_combo()
			ai_state = AIState.EXECUTE_SUMMON
			get_tree().create_timer(0.45).timeout.connect(_advance_ai_state_machine)

		AIState.EXECUTE_SUMMON:
			if ai_planned_char != null and ai_energy >= COST_SUMMON:
				var idx: int = ai_hand.find(ai_planned_char)
				if idx != -1:
					ai_hand.remove_at(idx)
				ai_energy -= COST_SUMMON
				var verb: String = "summons" if ai_active_char == null else "swaps to"
				ai_active_char = ai_planned_char
				ai_char_hp = ai_planned_char.max_hp
				_animate_panel_pulse(ai_char_panel)
				_log_combat("AI %s %s (%d HP, %s Affinity)!" % [
					verb,
					ai_active_char.card_name,
					ai_active_char.max_hp,
					ai_active_char.get_affinity_label()
				])
				_update_all_ui()
			ai_state = AIState.EXECUTE_EQUIP
			get_tree().create_timer(0.50).timeout.connect(_advance_ai_state_machine)

		AIState.EXECUTE_EQUIP:
			if ai_planned_weapon != null and ai_active_char != null and ai_energy >= COST_EQUIP:
				var idx: int = ai_hand.find(ai_planned_weapon)
				if idx != -1:
					ai_hand.remove_at(idx)
				ai_energy -= COST_EQUIP
				ai_active_weapon = ai_planned_weapon
				_animate_panel_pulse(ai_weapon_panel)
				var info: Dictionary = calculate_combat_damage(ai_active_char, ai_active_weapon)
				if info["affinity_match"]:
					_show_affinity_match_indicator("AI AFFINITY MATCH! %s + %s (1.5x DMG)" % [
						ai_active_char.card_name,
						ai_active_weapon.card_name
					])
					_log_combat("AI equips %s on %s — AFFINITY MATCH! Attack boosted to %d!" % [
						ai_active_weapon.card_name,
						ai_active_char.card_name,
						info["total"]
					])
				else:
					_log_combat("AI equips %s (+%d DMG) on %s." % [
						ai_active_weapon.card_name,
						ai_active_weapon.damage,
						ai_active_char.card_name
					])
				_update_all_ui()
			ai_state = AIState.EXECUTE_ATTACK
			get_tree().create_timer(0.55).timeout.connect(_advance_ai_state_machine)

		AIState.EXECUTE_ATTACK:
			_execute_ai_attack()
			if current_phase == TurnPhase.GAME_OVER:
				return
			ai_state = AIState.FINISH_TURN
			get_tree().create_timer(0.55).timeout.connect(_advance_ai_state_machine)

		AIState.FINISH_TURN:
			ai_state = AIState.IDLE
			current_turn += 1
			_begin_player_turn()


func _evaluate_ai_best_combo() -> void:
	"""
	AI State Machine Evaluator:
	1. Evaluates hand for Affinity matches first.
	2. Selects highest-value playable Character + Weapon combo within Energy budget.
	"""
	ai_planned_char = null
	ai_planned_weapon = null

	var hand_chars: Array[CharacterCard] = []
	var hand_weapons: Array[WeaponCard] = []
	for card in ai_hand:
		if card is CharacterCard:
			hand_chars.append(card as CharacterCard)
		elif card is WeaponCard:
			hand_weapons.append(card as WeaponCard)

	# Build candidate character choices: [CharacterCard, summon_cost, is_new_summon]
	var char_candidates: Array[Dictionary] = []
	if ai_active_char != null:
		char_candidates.append({"char": ai_active_char, "cost": 0, "summon": null})
	for hc in hand_chars:
		if ai_energy >= COST_SUMMON:
			# Consider summoning if slot is empty, or if swapping yields a new affinity match
			if ai_active_char == null or hc.affinity != ai_active_char.affinity:
				char_candidates.append({"char": hc, "cost": COST_SUMMON, "summon": hc})

	# Build candidate weapon choices: [WeaponCard, equip_cost, is_new_equip]
	var weapon_candidates: Array[Dictionary] = []
	weapon_candidates.append({"weapon": ai_active_weapon, "cost": 0, "equip": null})
	for hw in hand_weapons:
		weapon_candidates.append({"weapon": hw, "cost": COST_EQUIP, "equip": hw})

	var best_score: float = -99999.0

	for c_opt in char_candidates:
		var candidate_char: CharacterCard = c_opt["char"]
		var c_cost: int = c_opt["cost"]
		if candidate_char == null:
			continue

		for w_opt in weapon_candidates:
			var candidate_weapon: WeaponCard = w_opt["weapon"]
			var w_cost: int = w_opt["cost"]
			var total_cost: int = c_cost + w_cost
			if total_cost > ai_energy:
				continue

			# Avoid paying energy to equip a weapon identical to already equipped weapon
			if w_opt["equip"] != null and ai_active_weapon != null:
				if candidate_weapon.card_name == ai_active_weapon.card_name and candidate_weapon.weapon_class == ai_active_weapon.weapon_class:
					continue

			var combat_info: Dictionary = calculate_combat_damage(candidate_char, candidate_weapon)
			var dmg: int = combat_info["total"]
			var is_match: bool = combat_info["affinity_match"]
			var can_attack_after: bool = (ai_energy - total_cost) >= COST_ATTACK and player_active_char != null

			var score: float = 0.0
			# 1. Prioritize Affinity Match combos first
			if is_match:
				score += 500.0
			# 2. Value expected attack damage and ability to execute an attack this turn
			score += float(dmg) * 4.0
			if can_attack_after:
				score += float(dmg) * 3.0 + 120.0
			# 3. Slight preference for keeping healthy active character unless swapping achieves Affinity Match
			if c_opt["summon"] == null:
				score += 35.0
			else:
				score += float(candidate_char.max_hp) * 0.25

			if score > best_score:
				best_score = score
				ai_planned_char = c_opt["summon"]
				ai_planned_weapon = w_opt["equip"]


func _execute_ai_attack() -> void:
	if ai_active_char == null or ai_energy < COST_ATTACK or ai_attacks_left <= 0:
		return

	# If Player failed to summon an active character when they had one in hand, auto-deploy one so combat resolves
	if player_active_char == null:
		for i in range(player_hand.size()):
			if player_hand[i] is CharacterCard:
				player_active_char = player_hand[i] as CharacterCard
				player_char_hp = player_active_char.max_hp
				player_hand.remove_at(i)
				_log_combat("%s was forced onto the field to defend!" % player_active_char.card_name)
				break

	if player_active_char == null:
		_check_win_loss_condition()
		return

	ai_energy -= COST_ATTACK
	ai_attacks_left -= 1

	var combat_info: Dictionary = calculate_combat_damage(ai_active_char, ai_active_weapon)
	var dmg: int = combat_info["total"]
	var is_match: bool = combat_info["affinity_match"]

	if is_match:
		_show_affinity_match_indicator("AI AFFINITY MATCH STRIKE! %d DAMAGE (1.5x)" % dmg)

	player_char_hp = maxi(0, player_char_hp - dmg)
	_animate_panel_pulse(ai_char_panel)
	_animate_damage_flash(player_char_panel)

	var match_tag: String = " [AFFINITY MATCH! 1.5x]" if is_match else ""
	_log_combat("AI's %s attacks your %s for %d DMG%s!" % [
		ai_active_char.card_name,
		player_active_char.card_name,
		dmg,
		match_tag
	])

	if player_char_hp <= 0:
		var lost_name: String = player_active_char.card_name
		player_active_char = null
		player_active_weapon = null
		ai_kos_scored += 1
		_log_combat("KNOCKOUT! Your %s was knocked out! (AI KOs: %d/%d)" % [
			lost_name,
			ai_kos_scored,
			TARGET_KOS
		])
		if _check_win_loss_condition():
			_update_all_ui()
			return

	_update_all_ui()


func _check_win_loss_condition() -> bool:
	"""
	Win/Loss condition when a player's active character is knocked out and they have
	no remaining character cards in hand/deck (or 3 knockouts total).
	"""
	var ai_remaining_chars: int = _count_chars_in_array(ai_hand) + _count_chars_in_array(ai_deck)
	var player_remaining_chars: int = _count_chars_in_array(player_hand) + _count_chars_in_array(player_deck)

	if player_kos_scored >= TARGET_KOS or (ai_active_char == null and ai_remaining_chars == 0):
		_trigger_game_over(true, "You knocked out the AI Vanguard! (KOs: %d | AI Remaining Characters: %d)" % [
			player_kos_scored,
			ai_remaining_chars
		])
		return true

	if ai_kos_scored >= TARGET_KOS or (player_active_char == null and player_remaining_chars == 0):
		_trigger_game_over(false, "Your Vanguard fell! (AI KOs: %d | Your Remaining Characters: %d)" % [
			ai_kos_scored,
			player_remaining_chars
		])
		return true

	return false


func _trigger_game_over(player_won: bool, reason: String) -> void:
	current_phase = TurnPhase.GAME_OVER
	game_over_overlay.visible = true
	if player_won:
		game_over_title.text = "VICTORY — ARSENAL MASTER!"
		game_over_title.modulate = Color(0.3, 1.0, 0.65)
	else:
		game_over_title.text = "DEFEAT — VANGUARD OVERRUN"
		game_over_title.modulate = Color(1.0, 0.38, 0.42)
	game_over_subtitle.text = reason


func _show_affinity_match_indicator(message: String) -> void:
	affinity_banner_label.text = "★ " + message + " ★"
	affinity_banner.visible = true
	affinity_banner.modulate = Color(1, 1, 1, 1)
	affinity_banner.scale = Vector2(0.92, 0.92)
	var tween: Tween = create_tween()
	tween.tween_property(affinity_banner, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_panel_pulse(panel: Control) -> void:
	panel.scale = Vector2(1.04, 1.04)
	var tween: Tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.18)


func _animate_damage_flash(panel: Control) -> void:
	panel.modulate = Color(1.6, 0.45, 0.45, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.28)


func _log_combat(msg: String) -> void:
	combat_log_label.text = msg


func _get_affinity_color(affinity_val: int) -> Color:
	match affinity_val:
		0: # MELEE
			return Color(0.22, 0.78, 1.0)
		1: # RANGED
			return Color(0.25, 0.94, 0.54)
		2: # MAGIC
			return Color(0.85, 0.42, 1.0)
	return Color(0.8, 0.8, 0.8)


func _update_all_ui() -> void:
	# Header Banners
	turn_banner_label.text = "ARSENAL TCG  •  TURN %d" % current_turn
	match current_phase:
		TurnPhase.PLAYER_DRAW:
			phase_banner_label.text = "PHASE: DRAW & REFRESH"
			phase_banner_label.modulate = Color(0.6, 0.85, 1.0)
		TurnPhase.PLAYER_ACTION:
			phase_banner_label.text = "PHASE: PLAYER ACTION"
			phase_banner_label.modulate = Color(0.35, 1.0, 0.68)
		TurnPhase.AI_TURN:
			phase_banner_label.text = "PHASE: AI OPPONENT TURN"
			phase_banner_label.modulate = Color(1.0, 0.72, 0.30)
		TurnPhase.GAME_OVER:
			phase_banner_label.text = "PHASE: MATCH COMPLETE"
			phase_banner_label.modulate = Color(1.0, 0.45, 0.55)

	score_label.text = "PLAYER KOs: %d / %d   |   AI KOs: %d / %d" % [
		player_kos_scored,
		TARGET_KOS,
		ai_kos_scored,
		TARGET_KOS
	]

	# AI Status & Active Slots
	ai_status_info_label.text = "AI Hand: %d/%d  |  AI Deck: %d  |  AI Energy: %d/%d" % [
		ai_hand.size(),
		MAX_HAND_SIZE,
		ai_deck.size(),
		ai_energy,
		ai_max_energy
	]

	if ai_active_char != null:
		ai_char_name_label.text = ai_active_char.card_name
		ai_char_affinity_label.text = ai_active_char.get_affinity_label()
		ai_char_affinity_label.modulate = _get_affinity_color(int(ai_active_char.affinity))
		ai_char_texture.texture = ai_active_char.texture
		ai_hp_bar.max_value = ai_active_char.max_hp
		ai_hp_bar.value = ai_char_hp
		ai_hp_label.text = "HP: %d / %d" % [ai_char_hp, ai_active_char.max_hp]
		ai_power_label.text = "Base Power: %d" % ai_active_char.power
	else:
		ai_char_name_label.text = "[ NO ACTIVE CHARACTER ]"
		ai_char_affinity_label.text = "KO'd"
		ai_char_affinity_label.modulate = Color(0.6, 0.6, 0.6)
		ai_char_texture.texture = null
		ai_hp_bar.max_value = 100
		ai_hp_bar.value = 0
		ai_hp_label.text = "HP: 0 / 0"
		ai_power_label.text = "Base Power: --"

	if ai_active_weapon != null:
		ai_weapon_name_label.text = ai_active_weapon.card_name
		ai_weapon_class_label.text = ai_active_weapon.get_class_label()
		ai_weapon_class_label.modulate = _get_affinity_color(int(ai_active_weapon.weapon_class))
		ai_weapon_texture.texture = ai_active_weapon.texture
		ai_weapon_dmg_label.text = "+%d Weapon DMG" % ai_active_weapon.damage
	else:
		ai_weapon_name_label.text = "[ UNARMED ]"
		ai_weapon_class_label.text = "NO WEAPON"
		ai_weapon_class_label.modulate = Color(0.55, 0.58, 0.65)
		ai_weapon_texture.texture = null
		ai_weapon_dmg_label.text = "+0 Weapon DMG"

	var ai_combat: Dictionary = calculate_combat_damage(ai_active_char, ai_active_weapon)
	ai_total_atk_label.text = "TOTAL ATK: %d" % ai_combat["total"]
	ai_affinity_badge.visible = ai_combat["affinity_match"]

	# Player Active Slots
	if player_active_char != null:
		player_char_name_label.text = player_active_char.card_name
		player_char_affinity_label.text = player_active_char.get_affinity_label()
		player_char_affinity_label.modulate = _get_affinity_color(int(player_active_char.affinity))
		player_char_texture.texture = player_active_char.texture
		player_hp_bar.max_value = player_active_char.max_hp
		player_hp_bar.value = player_char_hp
		player_hp_label.text = "HP: %d / %d" % [player_char_hp, player_active_char.max_hp]
		player_power_label.text = "Base Power: %d" % player_active_char.power
	else:
		player_char_name_label.text = "[ EMPTY — SUMMON FROM HAND ]"
		player_char_affinity_label.text = "COST: 2⚡"
		player_char_affinity_label.modulate = Color(1.0, 0.85, 0.35)
		player_char_texture.texture = null
		player_hp_bar.max_value = 100
		player_hp_bar.value = 0
		player_hp_label.text = "HP: -- / --"
		player_power_label.text = "Click a Character card below"

	if player_active_weapon != null:
		player_weapon_name_label.text = player_active_weapon.card_name
		player_weapon_class_label.text = player_active_weapon.get_class_label()
		player_weapon_class_label.modulate = _get_affinity_color(int(player_active_weapon.weapon_class))
		player_weapon_texture.texture = player_active_weapon.texture
		player_weapon_dmg_label.text = "+%d Weapon DMG" % player_active_weapon.damage
	else:
		player_weapon_name_label.text = "[ UNARMED — EQUIP WEAPON ]"
		player_weapon_class_label.text = "COST: 1⚡"
		player_weapon_class_label.modulate = Color(0.65, 0.75, 0.85)
		player_weapon_texture.texture = null
		player_weapon_dmg_label.text = "+0 Weapon DMG"

	var player_combat: Dictionary = calculate_combat_damage(player_active_char, player_active_weapon)
	player_total_atk_label.text = "TOTAL ATK: %d" % player_combat["total"]
	player_affinity_badge.visible = player_combat["affinity_match"]

	# Energy Counter & Pips
	energy_value_label.text = "ENERGY: %d / %d" % [player_energy, player_max_energy]
	_rebuild_energy_pips()

	deck_info_label.text = "Hand: %d / %d   |   Deck: %d cards" % [
		player_hand.size(),
		MAX_HAND_SIZE,
		player_deck.size()
	]

	# Action Buttons state
	var is_player_turn: bool = current_phase == TurnPhase.PLAYER_ACTION
	var can_attack: bool = (
		is_player_turn
		and player_active_char != null
		and ai_active_char != null
		and player_energy >= COST_ATTACK
		and player_attacks_left > 0
	)
	attack_button.disabled = not can_attack
	if player_active_char != null:
		attack_button.text = "ATTACK (%d DMG • 1 EN)" % player_combat["total"]
	else:
		attack_button.text = "ATTACK (1 EN)"

	end_turn_button.disabled = not is_player_turn

	# Rebuild Player Hand cards
	_rebuild_hand_ui()


func _rebuild_energy_pips() -> void:
	for child in energy_pips_box.get_children():
		child.queue_free()

	for i in range(MAX_ENERGY_CAP):
		var pip: Panel = Panel.new()
		pip.custom_minimum_size = Vector2(26, 16)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		if i < player_energy:
			style.bg_color = Color(0.18, 0.88, 1.0)
			style.border_color = Color(0.75, 0.98, 1.0)
			style.set_border_width_all(1)
		elif i < player_max_energy:
			style.bg_color = Color(0.14, 0.22, 0.32)
			style.border_color = Color(0.32, 0.45, 0.62)
			style.set_border_width_all(1)
		else:
			style.bg_color = Color(0.08, 0.10, 0.14, 0.5)
		pip.add_theme_stylebox_override("panel", style)
		energy_pips_box.add_child(pip)


func _rebuild_hand_ui() -> void:
	for child in hand_container.get_children():
		child.queue_free()

	var is_player_turn: bool = current_phase == TurnPhase.PLAYER_ACTION

	for idx in range(player_hand.size()):
		var card: Resource = player_hand[idx]
		var is_char: bool = card is CharacterCard
		var cost: int = COST_SUMMON if is_char else COST_EQUIP
		var aff_val: int = int((card as CharacterCard).affinity) if is_char else int((card as WeaponCard).weapon_class)
		var aff_label: String = (card as CharacterCard).get_affinity_label() if is_char else (card as WeaponCard).get_class_label()
		var aff_color: Color = _get_affinity_color(aff_val)

		var can_play: bool = is_player_turn and player_energy >= cost and (is_char or player_active_char != null)
		var would_match_affinity: bool = false
		if not is_char and player_active_char != null:
			would_match_affinity = int(player_active_char.affinity) == aff_val
		elif is_char and player_active_weapon != null:
			would_match_affinity = aff_val == int(player_active_weapon.weapon_class)

		var card_btn: Button = Button.new()
		card_btn.custom_minimum_size = Vector2(174, 212)
		card_btn.disabled = not can_play
		card_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_play else Control.CURSOR_ARROW

		var normal_style: StyleBoxFlat = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.10, 0.14, 0.22, 0.96)
		normal_style.set_corner_radius_all(10)
		normal_style.set_border_width_all(2)
		if would_match_affinity and can_play:
			normal_style.border_color = Color(1.0, 0.84, 0.25)
		else:
			normal_style.border_color = aff_color if can_play else Color(0.24, 0.28, 0.36)

		var hover_style: StyleBoxFlat = normal_style.duplicate()
		hover_style.bg_color = Color(0.15, 0.21, 0.32, 1.0)
		hover_style.border_color = Color(1.0, 0.92, 0.45) if would_match_affinity else aff_color.lightened(0.25)

		var disabled_style: StyleBoxFlat = normal_style.duplicate()
		disabled_style.bg_color = Color(0.07, 0.09, 0.13, 0.72)
		disabled_style.border_color = Color(0.20, 0.22, 0.28, 0.6)

		card_btn.add_theme_stylebox_override("normal", normal_style)
		card_btn.add_theme_stylebox_override("hover", hover_style)
		card_btn.add_theme_stylebox_override("pressed", hover_style)
		card_btn.add_theme_stylebox_override("disabled", disabled_style)

		var margin: MarginContainer = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		card_btn.add_child(margin)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)

		# Top row: Type + Energy Cost
		var top_row: HBoxContainer = HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(top_row)

		var type_lbl: Label = Label.new()
		type_lbl.text = "CHARACTER" if is_char else "WEAPON"
		type_lbl.add_theme_font_size_override("font_size", 11)
		type_lbl.modulate = Color(0.72, 0.80, 0.92)
		type_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(type_lbl)

		var cost_lbl: Label = Label.new()
		cost_lbl.text = "%d⚡" % cost
		cost_lbl.add_theme_font_size_override("font_size", 13)
		cost_lbl.modulate = Color(0.25, 0.92, 1.0) if player_energy >= cost else Color(1.0, 0.42, 0.42)
		top_row.add_child(cost_lbl)

		# Sprite Thumbnail
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.custom_minimum_size = Vector2(96, 86)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = (card as CharacterCard).texture if is_char else (card as WeaponCard).texture
		vbox.add_child(tex_rect)

		# Card Name
		var name_lbl: Label = Label.new()
		name_lbl.text = (card as CharacterCard).card_name if is_char else (card as WeaponCard).card_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_lbl)

		# Affinity / WeaponClass Tag
		var aff_tag: Label = Label.new()
		if would_match_affinity:
			aff_tag.text = "★ %s (1.5x MATCH)" % aff_label
			aff_tag.modulate = Color(1.0, 0.86, 0.28)
		else:
			aff_tag.text = aff_label
			aff_tag.modulate = aff_color
		aff_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aff_tag.add_theme_font_size_override("font_size", 11)
		vbox.add_child(aff_tag)

		# Stats Row
		var stats_lbl: Label = Label.new()
		if is_char:
			var cc: CharacterCard = card as CharacterCard
			stats_lbl.text = "HP %d  •  PWR %d" % [cc.max_hp, cc.power]
		else:
			var wc: WeaponCard = card as WeaponCard
			stats_lbl.text = "DMG +%d" % wc.damage
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_lbl.add_theme_font_size_override("font_size", 12)
		stats_lbl.modulate = Color(0.88, 0.94, 1.0)
		vbox.add_child(stats_lbl)

		var captured_idx: int = idx
		card_btn.pressed.connect(func() -> void: _on_hand_card_clicked(captured_idx))
		hand_container.add_child(card_btn)


func _apply_theme_styles() -> void:
	var slot_panels: Array[PanelContainer] = [
		ai_char_panel,
		ai_weapon_panel,
		player_char_panel,
		player_weapon_panel
	]
	for panel in slot_panels:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.09, 0.12, 0.19, 0.95)
		style.border_color = Color(0.24, 0.36, 0.54)
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		panel.add_theme_stylebox_override("panel", style)

	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = Color(0.22, 0.16, 0.04, 0.96)
	banner_style.border_color = Color(1.0, 0.82, 0.24)
	banner_style.set_border_width_all(2)
	banner_style.set_corner_radius_all(8)
	affinity_banner.add_theme_stylebox_override("panel", banner_style)

	# Style Health Bars
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.06, 0.08, 0.12)
	hp_bg.border_color = Color(0.20, 0.28, 0.40)
	hp_bg.set_border_width_all(1)
	hp_bg.set_corner_radius_all(5)

	var player_hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	player_hp_fill.bg_color = Color(0.18, 0.86, 0.52)
	player_hp_fill.set_corner_radius_all(5)

	var ai_hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	ai_hp_fill.bg_color = Color(0.92, 0.28, 0.36)
	ai_hp_fill.set_corner_radius_all(5)

	player_hp_bar.add_theme_stylebox_override("background", hp_bg)
	player_hp_bar.add_theme_stylebox_override("fill", player_hp_fill)
	ai_hp_bar.add_theme_stylebox_override("background", hp_bg)
	ai_hp_bar.add_theme_stylebox_override("fill", ai_hp_fill)

