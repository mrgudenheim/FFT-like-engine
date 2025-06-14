class_name UnitData
extends Node3D

# https://ffhacktics.com/wiki/Miscellaneous_Unit_Data
# https://ffhacktics.com/wiki/Battle_Stats

signal ability_assigned(id: int)
signal ability_completed()
signal primary_weapon_assigned(idx: int)
signal image_changed(new_image: ImageTexture)
signal knocked_out(unit: UnitData)
signal spritesheet_changed(new_spritesheet: ImageTexture)
signal reached_tile()
signal completed_move()
signal turn_ended()

var is_player_controlled: bool = false
var is_active: bool = false
var team: Team

@export var char_body: CharacterBody3D
@export var animation_manager: UnitAnimationManager
@export var popup_texts: PopupTextContainer
@export var debug_menu: UnitDebugMenu

@export var unit_nickname: String = "Unit Nickname"
@export var job_nickname: String = "Job Nickname"

var character_id: int = 0
var unit_index_formation: int = 0
var job_id: int = 0
var job_data: JobData
var sprite_palette_id: int = 0
var team_id: int = 0
var player_control: bool = true

var immortal: bool = false
var immune_knockback: bool = false
var game_over_trigger: bool = false
var type_id = 0 # male, female, monster
var death_counter: int = 3
var zodiac = "Ares"

var innate_ability_ids: PackedInt32Array = []
var skillsets: Array = [ScusData.SkillsetData]
var reaction_abilities: Array = []
var support_ability: Array = []
var movement_ability: Array = []

var primary_weapon: ItemData
var equipped: Array[ItemData] = []

var unit_exp: int = 0
var level: int = 0

var brave_base: int = 70
var brave_current: int = 70 # min 0, max 100
var faith_base: int = 70
var faith_current: int = 70 # min 0, max 100

var ct_current: int = 0
var ct_max: int = 100

var hp_base: int = 100
var hp_max: int = 100
var hp_current: int = 70
var mp_base: int = 100
var mp_max: int = 100
var mp_current: int = 70

var physical_attack_base: int = 5
var physical_attack_current: int = 5
var magical_attack_base: int = 5
var magical_attack_current: int = 5
var speed_base: int = 5
var speed_current: int = 5
var move_base: int = 5
var move_current: int = 5
var jump_base: int = 5
var jump_current: int = 3

var innate_statuses: Array[StatusEffect] = []
var immune_status_types: Array[StatusEffect] = []
var current_statuses: Array[StatusEffect] = [] # Status may have a corresponding CT countdown?

var learned_abilities: Array = []
var job_levels
var job_jp

var charging_abilities_ids: PackedInt32Array = []
var charging_abilities_remaining_ct: PackedInt32Array = [] # TODO this should be tracked per ability?
var sprite_id: int = 0
var sprite_file_idx = 0
var portrait_palette_id: int = 0
var unit_id: int = 0
var special_job_skillset_id: int = 0

@export var elemental_absorb: Array[Action.ElementTypes] = []
@export var elemental_cancel: Array[Action.ElementTypes] = []
@export var elemental_half: Array[Action.ElementTypes] = []
@export var elemental_weakness: Array[Action.ElementTypes] = []
@export var elemental_strengthen: Array[Action.ElementTypes] = []


var can_move: bool = true

#var map_position: Vector2i
var tile_position: TerrainTile
var map_paths: Dictionary[TerrainTile, TerrainTile]
var path_costs: Dictionary[TerrainTile, float]
@export var tile_highlights: Node3D
var facing: Facings = Facings.NORTH
var is_back_facing: bool = false
var facing_vector: Vector3 = Vector3.FORWARD:
	get:
		return FacingVectors[facing]

enum Facings {
	NORTH,
	EAST,
	SOUTH,
	WEST,
	}

const FacingVectors: Dictionary[Facings, Vector3] = {
	Facings.NORTH: Vector3.BACK,
	Facings.EAST: Vector3.RIGHT,
	Facings.SOUTH: Vector3.FORWARD,
	Facings.WEST: Vector3.LEFT,
	}

var is_in_air: bool = false
var is_traveling_path: bool = false

var ability_id: int = 0
var ability_data: FftAbilityData

var active_action: ActionInstance
#@export var action_instance: ActionInstance
@export var move_action: Action
@export var attack_action: Action
@export var wait_action: Action
@export var actions: Array[Action] = []
var actions_data: Dictionary[Action, ActionInstance] = {}
@export var move_points_start: int = 1
@export var move_points_remaining: int = 1
@export var action_points_start: int = 1
@export var action_points_remaining: int = 1

var current_idle_animation_id: int = 6 # set based on status (critical, knocked out, etc.)
var current_animation_id_fwd: int = 6 # set based on current action
# constants?
var idle_walk_animation_id: int = 6
var walk_to_animation_id: int = 0x18
var evade_animation_id: int = 0x30
var taking_damage_animation_id: int = 0x32
var knocked_out_animation_id: int = 0x34
var heal_animation_id: int = 0x36
var mid_jump_animation: int = 0x3e

var submerged_depth: int = 0

func _ready() -> void:
	if not RomReader.is_ready:
		RomReader.rom_loaded.connect(initialize_unit)
	
	equipped.resize(5)
	equipped.fill(RomReader.items[0])
	add_to_group("Units")


func initialize_unit() -> void:
	debug_menu.populate_options()
	
	animation_manager.wep_spr = RomReader.sprs[RomReader.file_records["WEP.SPR"].type_index]
	animation_manager.wep_shp = RomReader.shps[RomReader.file_records["WEP1.SHP"].type_index]
	animation_manager.wep_seq = RomReader.seqs[RomReader.file_records["WEP1.SEQ"].type_index]
	
	animation_manager.eff_spr = RomReader.sprs[RomReader.file_records["EFF.SPR"].type_index]
	animation_manager.eff_shp = RomReader.shps[RomReader.file_records["EFF1.SHP"].type_index]
	animation_manager.eff_seq = RomReader.seqs[RomReader.file_records["EFF1.SEQ"].type_index]
	
	animation_manager.unit_sprites_manager.sprite_effect.texture = animation_manager.eff_spr.create_frame_grid_texture(0, 0, 0, 0, 0)
	
	animation_manager.item_spr = RomReader.sprs[RomReader.file_records["ITEM.BIN"].type_index]
	
	animation_manager.unit_sprites_manager.sprite_item.texture = ImageTexture.create_from_image(RomReader.sprs[RomReader.file_records["ITEM.BIN"].type_index].spritesheet)
	
	animation_manager.other_spr = RomReader.sprs[RomReader.file_records["OTHER.SPR"].type_index]
	animation_manager.other_shp = RomReader.shps[RomReader.file_records["OTHER.SHP"].type_index]
	
	# 1 cure
	# 0xc8 blood suck
	# 0x9b stasis sword
	set_ability(0x9b)
	set_primary_weapon(101) # 1 - dagger, 72 - mythril gun, 101 - mythril spear
	set_sprite_by_file_idx(98) # RAMUZA.SPR # TODO use sprite_id?
	#set_sprite_by_file_name("RAMUZA.SPR")
	
	update_unit_facing(FacingVectors[Facings.SOUTH])


func _physics_process(delta: float) -> void:
	# FFTae (and all non-battles) don't use physics, so this can be turned off
	if not is_instance_valid(BattleManager.main_camera):
		set_physics_process(false)
		return
	
	# Add the gravity.
	if not char_body.is_on_floor():
		char_body.velocity += char_body.get_gravity() * delta
	
	var velocity_horizontal = char_body.velocity
	velocity_horizontal.y = 0
	if velocity_horizontal.length_squared() > 0.01:
		update_unit_facing(velocity_horizontal.normalized())
	char_body.move_and_slide()


func _process(_delta: float) -> void:
	if not RomReader.is_ready:
		return
	
	if char_body.velocity.y != 0 and is_in_air == false:
		is_in_air = true
		
		#var mid_jump_animation: int = 62 # front facing mid jump animation
		#if animation_manager.is_back_facing:
			#mid_jump_animation += 1
		current_animation_id_fwd = mid_jump_animation
		#debug_menu.anim_id_spin.value = mid_jump_animation
	elif char_body.velocity.y == 0 and is_in_air == true:
		is_in_air = false
		
		#var idle_animation: int = 6 # front facing idle walk animation
		#if animation_manager.is_back_facing:
			#idle_animation += 1
		current_animation_id_fwd = current_idle_animation_id
		#debug_menu.anim_id_spin.value = idle_animation
	
	set_base_animation_ptr_id(current_animation_id_fwd)


func start_turn(battle_manager: BattleManager) -> void:
	# TODO focus camera on unit
	
	# set CT
	ct_current = max(0, ct_current - 100)
	
	update_actions(battle_manager)


func update_actions(battle_manager: BattleManager) -> void:
	# get possible actions
	for action_instance: ActionInstance in actions_data.values():
		action_instance.clear()
	
	actions.clear()
	actions_data.clear()
	actions.append(move_action)
	actions.append(attack_action)
	actions.append(wait_action)
	for skillset: ScusData.SkillsetData in skillsets:
		for ability_id: int in skillset.action_ability_ids:
			if ability_id != 0:
				var new_action: Action = RomReader.abilities[ability_id].ability_action
				actions.append(new_action)
	# TODO append all other potential actions, from jobs, wait, equipment, etc.
	
	# remove any existing buttons
	for child in battle_manager.action_button_list.get_children():
		child.queue_free()
	
	# show list UI for selecting an action TODO should action list be toggle/button group?
	for action: Action in actions:
		var new_action_instance: ActionInstance = ActionInstance.new(action, self, battle_manager)
		actions_data[action] = new_action_instance
		var new_action_button: ActionButton = ActionButton.new(new_action_instance)
		
		battle_manager.action_button_list.add_child(new_action_button)
		
		# disable buttons for actions that are not usable - TODO provide hints why action is not usable - not enough mp, already moved, etc.
		if not new_action_instance.is_usable():
			new_action_button.disabled = true
		
		new_action_instance.action_completed.connect(update_actions)
	
	# select first usable action by default (usually Move)
	active_action = null
	for action_instance: ActionInstance in actions_data.values():
		if action_instance.is_usable() and action_instance.action != wait_action:
			active_action = action_instance
			active_action.update_potential_targets()
			active_action.start_targeting()
			break
	
	# end turn when no actions left
	if active_action == null:
		end_turn()


func end_turn():
	#if UnitControllerRT.unit != self: # prevent accidentally ending a different units turn TODO what if the next turn is also this unit?
		#return
	
	if active_action != null:
		active_action.clear()
		active_action.stop_targeting()
	
	# set some stats for next turn - move_points_remaining, action_points_remaining, etc.
	move_points_remaining = move_points_start
	action_points_remaining = action_points_start
	
	if UnitControllerRT.unit == self: # prevent accidentally ending a different units turn TODO what if the next turn is also this unit?
		turn_ended.emit()


func use_attack() -> void:
	can_move = false
	push_warning("using attack: " + primary_weapon.name)
	#push_warning("Animations: " + str(PackedInt32Array([ability_data.animation_start_id, ability_data.animation_charging_id, ability_data.animation_executing_id])))
	#if ability_data.animation_start_id != 0:
		#debug_menu.anim_id_spin.value = ability_data.animation_start_id + int(is_back_facing)
		#await animation_manager.animation_completed
	#
	#if ability_data.animation_charging_id != 0:
		#debug_menu.anim_id_spin.value = ability_data.animation_charging_id + int(is_back_facing)
		#await get_tree().create_timer(0.1 + (ability_data.ticks_charge_time * 0.1)).timeout
	
		#animation_executing_id = 0x3e * 2 # TODO look up based on equiped weapon and target relative height
		#animation_manager.unit_debug_menu.anim_id_spin.value = 0x3e * 2 # TODO look up based on equiped weapon and target relative height
	
	# execute atttack
	#debug_menu.anim_id_spin.value = (RomReader.battle_bin_data.weapon_animation_ids[primary_weapon.item_type].y * 2) + int(is_back_facing) # TODO lookup based on target relative height
	current_animation_id_fwd = (RomReader.battle_bin_data.weapon_animation_ids[primary_weapon.item_type].y * 2) # TODO lookup based on target relative height
	set_base_animation_ptr_id(current_animation_id_fwd)
	
	# TODO implement proper timeout for abilities that execute using an infinite loop animation
	# this implementation can overwrite can_move when in the middle of another ability
	get_tree().create_timer(2).timeout.connect(func() -> void: can_move = true) 
	
	await animation_manager.animation_completed

	#ability_completed.emit()
	animation_manager.reset_sprites()
	#debug_menu.anim_id_spin.value = current_idle_animation_id  + int(is_back_facing)
	current_animation_id_fwd = current_idle_animation_id
	set_base_animation_ptr_id(current_animation_id_fwd)
	can_move = true


func use_ability(pos: Vector3) -> void:
	can_move = false
	push_warning("using: " + ability_data.name)
	#push_warning("Animations: " + str(PackedInt32Array([ability_data.animation_start_id, ability_data.animation_charging_id, ability_data.animation_executing_id])))
	if ability_data.animation_start_id != 0:
		#debug_menu.anim_id_spin.value = ability_data.animation_start_id + int(is_back_facing)
		current_animation_id_fwd = ability_data.animation_start_id
		set_base_animation_ptr_id(current_animation_id_fwd)
		await animation_manager.animation_completed
	
	if ability_data.animation_charging_id != 0:
		#debug_menu.anim_id_spin.value = ability_data.animation_charging_id + int(is_back_facing)
		current_animation_id_fwd = ability_data.animation_charging_id
		set_base_animation_ptr_id(current_animation_id_fwd)
		await get_tree().create_timer(0.1 + (ability_data.ticks_charge_time * 0.1)).timeout
	
	#if ability_data.animation_executing_id != 0:
	if ability_data.animation_executing_id == 0:
		#animation_executing_id = 0x3e * 2 # TODO look up based on equiped weapon and target relative height
		#animation_manager.unit_debug_menu.anim_id_spin.value = 0x3e * 2 # TODO look up based on equiped weapon and target relative height
		#debug_menu.anim_id_spin.value = (RomReader.battle_bin_data.weapon_animation_ids[primary_weapon.item_type].y * 2) + int(is_back_facing) # TODO lookup based on target relative height
		current_animation_id_fwd = (RomReader.battle_bin_data.weapon_animation_ids[primary_weapon.item_type].y * 2) # TODO lookup based on target relative height
		set_base_animation_ptr_id(current_animation_id_fwd)
	else:
		var ability_animation_executing_id = ability_data.animation_executing_id
		if ["RUKA.SEQ", "ARUTE.SEQ", "KANZEN.SEQ"].has(RomReader.sprs[sprite_file_idx].seq_name):
			ability_animation_executing_id = 0x2c * 2 # https://ffhacktics.com/wiki/Set_attack_animation_flags_and_facing_3
		#debug_menu.anim_id_spin.value = ability_animation_executing_id + int(is_back_facing)
		current_animation_id_fwd = ability_animation_executing_id
		set_base_animation_ptr_id(current_animation_id_fwd)
		
	#var new_vfx_location: Node3D = Node3D.new()
	#new_vfx_location.position = pos
	##new_vfx_location.position.y += 2 # TODO set position dependent on ability vfx data
	#new_vfx_location.name = "VfxLocation"
	#get_parent().add_child(new_vfx_location)
	active_action.action.show_vfx(active_action, pos)
	
	# TODO implement proper timeout for abilities that execute using an infinite loop animation
	# this implementation can overwrite can_move when in the middle of another ability
	get_tree().create_timer(2).timeout.connect(func() -> void: can_move = true) 
		
	await animation_manager.animation_completed

	ability_completed.emit()
	animation_manager.reset_sprites()
	#debug_menu.anim_id_spin.value = current_idle_animation_id  + int(is_back_facing)
	current_animation_id_fwd = current_idle_animation_id
	set_base_animation_ptr_id(current_animation_id_fwd)
	can_move = true


func process_targeted() -> void:
	if UnitControllerRT.unit == self:
		return
	
	# set being targeted frame
	var targeted_frame_index: int = RomReader.battle_bin_data.targeted_front_frame_id[animation_manager.global_spr.seq_id]
	if is_back_facing:
		targeted_frame_index = RomReader.battle_bin_data.targeted_back_frame_id[animation_manager.global_spr.seq_id]
	
	#animation_manager.global_animation_ptr_id = 0
	#debug_menu.anim_id_spin.value = 0
	#var assembled_image: Image = animation_manager.global_shp.get_assembled_frame(targeted_frame_index, animation_manager.global_spr.spritesheet, 0, 
		#0, 0, 0)
	#animation_manager.unit_sprites_manager.sprite_primary.texture = ImageTexture.create_from_image(assembled_image)
	
	await get_tree().create_timer(0.2).timeout
	
	# take damage animation
	#animation_manager.global_animation_ptr_id = taking_damage_animation_id
	#debug_menu.anim_id_spin.value = taking_damage_animation_id
	current_animation_id_fwd = taking_damage_animation_id
	set_base_animation_ptr_id(current_animation_id_fwd)
	
	# show result / damage numbers
	
	# TODO await ability.vfx_completed? Or does ability_completed just need to wait to post numbers? aka WaitWeaponSheathe1/2 opcode?
	await UnitControllerRT.unit.ability_completed
	# show death animation
	#animation_manager.global_animation_ptr_id = knocked_out_animation_id
	#debug_menu.anim_id_spin.value = knocked_out_animation_id
	current_idle_animation_id = knocked_out_animation_id
	current_animation_id_fwd = current_idle_animation_id
	set_base_animation_ptr_id(current_animation_id_fwd)
	
	knocked_out.emit(self)


func animate_start_action(animation_start_id: int, animation_charging_id: int) -> void:
	if animation_start_id != 0:
		set_base_animation_ptr_id(animation_start_id)
		await animation_manager.animation_completed
	
	if animation_charging_id != 0:
		set_base_animation_ptr_id(animation_charging_id)
		await get_tree().create_timer(0.1 + (ability_data.ticks_charge_time * 0.1)).timeout # TODO allow looping until changed, ie. charging a spell


func animate_execute_action(animation_executing_id: int, vfx: VisualEffectData = null) -> void:
	if animation_executing_id < 0: # no animatione
		return
	
	var ability_animation_executing_id = animation_executing_id
	if ["RUKA.SEQ", "ARUTE.SEQ", "KANZEN.SEQ"].has(RomReader.sprs[sprite_file_idx].seq_name):
		ability_animation_executing_id = 0x2c * 2 # https://ffhacktics.com/wiki/Set_attack_animation_flags_and_facing_3
	#debug_menu.anim_id_spin.value = ability_animation_executing_id + int(is_back_facing)
	set_base_animation_ptr_id(ability_animation_executing_id)
	
	await animation_manager.animation_completed # TODO change based on vfx timing data?
	
	if current_animation_id_fwd == animation_executing_id:
		animate_return_to_idle()


func animate_take_hit(vfx: VisualEffectData = null) -> void:
	set_base_animation_ptr_id(taking_damage_animation_id)
	
	if vfx != null:
		await vfx.vfx_completed
	else:
		await get_tree().create_timer(1).timeout # TODO show based on vfx timing data?
	
	if current_animation_id_fwd == taking_damage_animation_id:
		animate_return_to_idle()


func animate_recieve_heal(vfx: VisualEffectData = null) -> void:
	set_base_animation_ptr_id(heal_animation_id)
	
	if vfx != null:
		await vfx.vfx_completed
	else:
		await get_tree().create_timer(1).timeout # TODO show based on vfx timing data?
	
	if current_animation_id_fwd == heal_animation_id:
		animate_return_to_idle()


func animate_evade() -> void:
	set_base_animation_ptr_id(evade_animation_id)
	
	await animation_manager.animation_completed
	
	if current_animation_id_fwd == evade_animation_id:
		animate_return_to_idle()


func animate_knock_out() -> void:
	current_idle_animation_id = knocked_out_animation_id
	set_base_animation_ptr_id(knocked_out_animation_id)
	
	knocked_out.emit(self)


func animate_return_to_idle() -> void:
	# add random delay to prevent unit animations from syncing
	# Talcall: if changing animation to one of the walking animations (anything less than 0xC) it checks the unit ID && 0x3 against the event timer. if they are equal, start animating the unit. else... don't animate the unit.
	var desync_delay: float = randf_range(0.0, 0.25)
	await  get_tree().create_timer(desync_delay).timeout 
	
	set_base_animation_ptr_id(current_idle_animation_id)


func set_base_animation_ptr_id(ptr_id: int) -> void:
	current_animation_id_fwd = ptr_id
	var new_ptr: int = ptr_id
	if is_back_facing:
		new_ptr = ptr_id + 1
	
	#if is_back_facing:
		#debug_menu.anim_id_spin.value = ptr_id + 1
		##animation_manager.global_animation_ptr_id = ptr_id + 1
	#else:
		#debug_menu.anim_id_spin.value = ptr_id
		##animation_manager.global_animation_ptr_id = ptr_id
	
	if animation_manager.global_animation_ptr_id != new_ptr:
		debug_menu.anim_id_spin.value = new_ptr # TODO the debug ui should not be the primary path to changing he animation
		#animation_manager.global_animation_ptr_id = new_ptr


func update_unit_facing(dir: Vector3) -> void:
	var angle_deg: float = rad_to_deg(atan2(dir.z, dir.x))
	angle_deg = fposmod(angle_deg, 359.99) + 45 # add 45 so EAST is just < 90 instead of < 45 and > 315
	angle_deg = fposmod(angle_deg, 359.99) # correction for values over 360 due to adding 45
	var new_facing: Facings = facing
	if angle_deg < 90:
		new_facing = Facings.EAST
	elif angle_deg < 180:
		new_facing = Facings.NORTH
	elif angle_deg < 270:
		new_facing = Facings.WEST
	elif angle_deg < 360:
		new_facing = Facings.SOUTH
	
	if new_facing != facing:
		var temp_facing = facing
		facing = new_facing
		update_animation_facing(UnitControllerRT.CameraFacingVectors[UnitControllerRT.camera_facing])


func update_animation_facing(camera_facing_vector: Vector3) -> void:
	var unit_facing_vector: Vector3 = FacingVectors[facing]
	#var camera_facing_vector: Vector3 = UnitControllerRT.CameraFacingVectors[controller.camera_facing]
	#var facing_difference: Vector3 = camera_facing_vector - unt_facing_vectorwad
	
	var unit_facing_angle = fposmod(rad_to_deg(atan2(unit_facing_vector.z, unit_facing_vector.x)), 359.99)
	var camera_facing_angle = fposmod(rad_to_deg(atan2(-camera_facing_vector.z, -camera_facing_vector.x)), 359.99)
	var facing_difference_angle = fposmod(camera_facing_angle - unit_facing_angle, 359.99)
		
	#push_warning("Difference: " + str(facing_difference) + ", UnitFacing: " + str(unit_facing_vector) + ", CameraFacing: " + str(camera_facing_vector))
	#push_warning("Difference: " + str(facing_difference_angle) + ", UnitFacing: " + str(unit_facing_angle) + ", CameraFacing: " + str(camera_facing_angle))
	#push_warning(rad_to_deg(atan2(facing_difference.z, facing_difference.x)))
	
	var new_is_right_facing: bool = false
	#is_back_facing: bool = false
	if facing_difference_angle < 90:
		new_is_right_facing = true
		is_back_facing = false
	elif facing_difference_angle < 180:
		new_is_right_facing = true
		is_back_facing = true
	elif facing_difference_angle < 270:
		new_is_right_facing = false
		is_back_facing = true
	elif facing_difference_angle < 360:
		new_is_right_facing = false
		is_back_facing = false
	
	if (animation_manager.is_right_facing != new_is_right_facing
			or animation_manager.is_back_facing != is_back_facing):
		animation_manager.set_face_right(new_is_right_facing)
		
		# TODO when changing fwd/back animations, retain the current step of the animation
		# Talcall: the direction the unit is facing gets updated on every parse of the routine, but unless the animation is changing, the instruction pointer byte doesn't get refreshed every vanilla animation is coded such that this swapping between front and back works flawlessly.
		if animation_manager.is_back_facing != is_back_facing:
			animation_manager.is_back_facing = is_back_facing
			if is_back_facing == true:
				debug_menu.anim_id_spin.value += 1
			else:
				debug_menu.anim_id_spin.value -= 1


func toggle_debug_menu() -> void:
	debug_menu.visible = not debug_menu.visible


func hide_debug_menu() -> void:
	debug_menu.visible = false


func set_job_id(job_id: int) -> void:
	job_id = job_id
	job_data = RomReader.scus_data.jobs_data[job_id]
	set_sprite_by_id(job_data.sprite_id)
	if job_id >= 0x5e: # monster
		set_sprite_palette(job_data.monster_palette_id)
	
	skillsets.clear()
	skillsets.append(RomReader.scus_data.skillsets_data[job_data.skillset_id])
	
	job_nickname = job_data.job_name
	
	if animation_manager.global_spr.flying_flag:
		idle_walk_animation_id = 0x0c
		current_idle_animation_id = idle_walk_animation_id
		set_base_animation_ptr_id(current_idle_animation_id)

func set_ability(new_ability_id: int) -> void:
	ability_id = new_ability_id
	ability_data = RomReader.abilities[new_ability_id]
	
	if not ability_data.vfx_data.is_initialized:
		ability_data.vfx_data.init_from_file()
	
	image_changed.emit(ImageTexture.create_from_image(ability_data.vfx_data.vfx_spr.spritesheet))
	#debug_menu.sprite_viewer.texture = ImageTexture.create_from_image(ability_data.vfx_data.vfx_spr.spritesheet)
	ability_assigned.emit(new_ability_id)


func set_primary_weapon(new_weapon_id: int) -> void:
	primary_weapon = RomReader.items[new_weapon_id]
	equipped[0] = primary_weapon
	#animation_manager.weapon_id = new_weapon_id
	#var weapon_palette_id = RomReader.battle_bin_data.weapon_graphic_palettes_1[primary_weapon.id]
	animation_manager.unit_sprites_manager.sprite_weapon.texture = animation_manager.wep_spr.create_frame_grid_texture(
		primary_weapon.wep_frame_palette, 0, 0, primary_weapon.wep_frame_v_offset, 0, animation_manager.wep_shp.file_name)
	
	attack_action = primary_weapon.weapon_attack_action
	primary_weapon_assigned.emit(new_weapon_id)


func change_equipment(slot_id: int, new_equipment: ItemData) -> void:
	if new_equipment == null: # used by RemoveEquipment action effect?
		equipped[slot_id] = RomReader.items[0] 
	else:
		equipped[slot_id] = new_equipment
	
	# TODO update stats and/or weapon


func get_evade(evade_source: EvadeData.EvadeSource, evade_type: EvadeData.EvadeType, evade_direction: EvadeData.Directions) -> int:
	var evade: int = 0
	
	for evade_data: EvadeData in job_data.evade_datas:
		if (evade_data.source == evade_source 
				and evade_data.type == evade_type
				and evade_data.directions.has(evade_direction)):
			evade += evade_data.value
	
	for equipment: ItemData in equipped:
		for evade_data: EvadeData in equipment.evade_datas:
			if (evade_data.source == evade_source 
					and evade_data.type == evade_type
					and evade_data.directions.has(evade_direction)):
				evade += evade_data.value
	
	return evade


func show_popup_text(text: String) -> void:
	popup_texts.show_popup_text(text)


func set_sprite_by_file_idx(new_sprite_file_idx: int) -> void:
	sprite_file_idx = new_sprite_file_idx
	var spr: Spr = RomReader.sprs[new_sprite_file_idx]	
	if RomReader.spr_file_name_to_id.has(spr.file_name):
		sprite_id = RomReader.spr_file_name_to_id[spr.file_name]
	debug_menu.sprite_options.select(new_sprite_file_idx)
	on_sprite_idx_selected(new_sprite_file_idx)
	if spr.file_name == "WEP.SPR":
		animation_manager.unit_sprites_manager.sprite_primary.vframes = 32
	else:
		animation_manager.unit_sprites_manager.sprite_primary.vframes = 16 + (16 * spr.sp2s.size())
	update_spritesheet_grid_texture()
	
	debug_menu.anim_id_spin.value = current_idle_animation_id


func set_sprite_by_file_name(sprite_file_name: String) -> void:
	var new_sprite_file_idx: int = RomReader.file_records[sprite_file_name].type_index
	set_sprite_by_file_idx(new_sprite_file_idx)


func set_sprite_by_id(new_sprite_id: int) -> void:
	var new_sprite_file_idx = RomReader.spr_id_file_idxs[new_sprite_id]
	set_sprite_by_file_idx(new_sprite_file_idx)


func set_sprite_palette(new_palette_id: int) -> void:
	if new_palette_id == sprite_palette_id:
		return
	
	sprite_palette_id = new_palette_id
	update_spritesheet_grid_texture()


func set_submerged_depth(new_depth: int) -> void:
	if new_depth == submerged_depth:
		return
	
	submerged_depth = new_depth
	update_spritesheet_grid_texture()


func update_spritesheet_grid_texture() -> void:
	var new_spr: Spr = RomReader.sprs[sprite_file_idx]
	animation_manager.unit_sprites_manager.sprite_primary.texture = new_spr.create_frame_grid_texture(sprite_palette_id, 0, 0, 0, submerged_depth)


func on_sprite_idx_selected(index: int) -> void:
	var spr: Spr = RomReader.sprs[index]
	if not spr.is_initialized:
		spr.set_data()
		spr.set_spritesheet_data(RomReader.spr_file_name_to_id[spr.file_name])
	
	animation_manager.global_spr = spr
	
	var shp: Shp = RomReader.shps[RomReader.file_records[spr.shp_name].type_index]
	if not shp.is_initialized:
		shp.set_data_from_shp_bytes(RomReader.get_file_data(shp.file_name))
	
	var seq: Seq = RomReader.seqs[RomReader.file_records[spr.seq_name].type_index]
	if not seq.is_initialized:
		seq.set_data_from_seq_bytes(RomReader.get_file_data(seq.file_name))
	
	var animation_changed: bool = false
	if shp.file_name == "TYPE2.SHP":
		if animation_manager.wep_shp.file_name != "WEP2.SHP":
			animation_manager.wep_shp = RomReader.shps[RomReader.file_records["WEP2.SHP"].type_index]
			set_primary_weapon(primary_weapon.id) # get new texture based on wep2.shp
			animation_changed = true
		animation_manager.wep_seq = RomReader.seqs[RomReader.file_records["WEP2.SEQ"].type_index]
	
	if shp != animation_manager.global_shp or seq != animation_manager.global_seq:
		animation_changed = true
	
	animation_manager.global_spr = spr
	animation_manager.global_shp = shp
	animation_manager.global_seq = seq
	
	
	#spritesheet_changed.emit(animation_manager.unit_sprites_manager.sprite_item.texture) # TODO hook up to sprite for debug purposes
	#spritesheet_changed.emit(ImageTexture.create_from_image(spr.spritesheet)) # TODO hook up to sprite for debug purposes
	#spritesheet_changed.emit(animation_manager.unit_sprites_manager.sprite_weapon.texture) # TODO hook up to sprite for debug purposes
	if animation_changed:
		animation_manager._on_animation_changed()


func update_map_paths(map_tiles: Dictionary[Vector2i, Array], units: Array[UnitData], max_cost: int = 9999) -> void:
	if move_action.targeting_strategy.has_method("get_map_paths"):
		map_paths = await move_action.targeting_strategy.get_map_paths(self, map_tiles, units)


func _on_character_body_3d_input_event(_camera: Node, _event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if Input.is_action_just_pressed("secondary_action") and UnitControllerRT.unit.char_body.is_on_floor():
		UnitControllerRT.unit.use_ability(char_body.position)
		process_targeted()


# TODO Unit preview ui - hp, mp, evade, hand equipment, statuses, status immunities, elemental scalaing, etc. portrait/mini sprite?
