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

var is_player_controlled: bool = false

@export var char_body: CharacterBody3D
@export var animation_manager: UnitAnimationManager
@export var debug_menu: UnitDebugMenu

@export var unit_nickname: String = "Unit Nickname"
@export var job_nickname: String = "Job Nickname"

var character_id: int = 0
var unit_index_formation: int = 0
var job_id: int = 0
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
var skillsets: Array = []
var reaction_abilities: Array = []
var support_ability: Array = []
var movement_ability: Array = []

var primary_weapon: ItemData
var equipment: PackedInt32Array = []

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

var physical_power_base: int = 5
var physical_power_current: int = 5
var magical_power_base: int = 5
var magical_power_current: int = 5
var speed_base: int = 5
var speed_current: int = 5
var move_base: int = 5
var move_current: int = 5
var jump_base: int = 5
var jump_current: int = 5

var innate_statuses: Array = []
var immune_status_types: Array = []
var current_statuses: Array = [] # Status may have a corresponding CT countdown?

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

var can_move: bool = true

var map_position: Vector2i
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
	Facings.NORTH: Vector3.FORWARD,
	Facings.EAST: Vector3.RIGHT,
	Facings.SOUTH: Vector3.BACK,
	Facings.WEST: Vector3.LEFT,
	}

var is_in_air: bool = false

var ability_id: int = 0
var ability_data: AbilityData

var idle_animation_id: int = 6
var idle_walk_animation_id: int = 6
var taking_damage_animation_id: int = 0x32
var knocked_out_animation_id: int = 0x34
var submerged_depth: int = 0

func _ready() -> void:
	if not RomReader.is_ready:
		RomReader.rom_loaded.connect(initialize_unit)
	
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
	set_primary_weapon(1)
	set_sprite(98) # RAMUZA.SPR
	#set_sprite_file("RAMUZA.SPR")
	
	update_unit_facing(FacingVectors[Facings.SOUTH])


func _physics_process(delta: float) -> void:	
	# FFTae (and all non-battles) don't use physics, so this can be turned off
	if not is_instance_valid(MapViewer.main_camera):
		set_physics_process(false)
		return
	
	# Add the gravity.
	if not char_body.is_on_floor():
		char_body.velocity += char_body.get_gravity() * delta
	
	if not is_player_controlled:
		char_body.move_and_slide()


func _process(_delta: float) -> void:
	if not RomReader.is_ready:
		return
	
	if char_body.velocity.y != 0 and is_in_air == false:
		is_in_air = true
		
		var mid_jump_animation: int = 62 # front facing mid jump animation
		if animation_manager.is_back_facing:
			mid_jump_animation += 1
		debug_menu.anim_id_spin.value = mid_jump_animation
	elif char_body.velocity.y == 0 and is_in_air == true:
		is_in_air = false
		
		var idle_animation: int = 6 # front facing idle walk animation
		if animation_manager.is_back_facing:
			idle_animation += 1
		debug_menu.anim_id_spin.value = idle_animation


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
	debug_menu.anim_id_spin.value = (RomReader.battle_bin_data.weapon_animation_ids[primary_weapon.item_type].y * 2) + int(is_back_facing) # TODO lookup based on target relative height
	
	# TODO implement proper timeout for abilities that execute using an infinite loop animation
	# this implementation can overwrite can_move when in the middle of another ability
	get_tree().create_timer(2).timeout.connect(func() -> void: can_move = true) 
		
	await animation_manager.animation_completed

	#ability_completed.emit()
	animation_manager.reset_sprites()
	debug_menu.anim_id_spin.value = idle_animation_id  + int(is_back_facing)
	can_move = true


func use_ability(pos: Vector3) -> void:
	can_move = false
	push_warning("using: " + ability_data.name)
	#push_warning("Animations: " + str(PackedInt32Array([ability_data.animation_start_id, ability_data.animation_charging_id, ability_data.animation_executing_id])))
	if ability_data.animation_start_id != 0:
		debug_menu.anim_id_spin.value = ability_data.animation_start_id + int(is_back_facing)
		await animation_manager.animation_completed
	
	if ability_data.animation_charging_id != 0:
		debug_menu.anim_id_spin.value = ability_data.animation_charging_id + int(is_back_facing)
		await get_tree().create_timer(0.1 + (ability_data.ticks_charge_time * 0.1)).timeout
	
	#if ability_data.animation_executing_id != 0:
	if ability_data.animation_executing_id == 0:
		#animation_executing_id = 0x3e * 2 # TODO look up based on equiped weapon and target relative height
		#animation_manager.unit_debug_menu.anim_id_spin.value = 0x3e * 2 # TODO look up based on equiped weapon and target relative height
		debug_menu.anim_id_spin.value = (RomReader.battle_bin_data.weapon_animation_ids[primary_weapon.item_type].y * 2) + int(is_back_facing) # TODO lookup based on target relative height
	else:
		var ability_animation_executing_id = ability_data.animation_executing_id
		if ["RUKA.SEQ", "ARUTE.SEQ", "KANZEN.SEQ"].has(RomReader.sprs[sprite_file_idx].seq_name):
			ability_animation_executing_id = 0x2c * 2 # https://ffhacktics.com/wiki/Set_attack_animation_flags_and_facing_3
		debug_menu.anim_id_spin.value = ability_animation_executing_id + int(is_back_facing)
		
	var new_vfx_location: Node3D = Node3D.new()
	new_vfx_location.position = pos
	new_vfx_location.position.y += 3.2 # TODO set position dependent on ability vfx data
	new_vfx_location.name = "VfxLocation"
	get_parent().add_child(new_vfx_location)
	ability_data.display_vfx(new_vfx_location)
	
	# TODO implement proper timeout for abilities that execute using an infinite loop animation
	# this implementation can overwrite can_move when in the middle of another ability
	get_tree().create_timer(2).timeout.connect(func() -> void: can_move = true) 
		
	await animation_manager.animation_completed

	ability_completed.emit()
	animation_manager.reset_sprites()
	debug_menu.anim_id_spin.value = idle_animation_id  + int(is_back_facing)
	can_move = true


func process_targeted() -> void:
	if UnitControllerRT.unit == self:
		return
	
	# set being targeted frame
	var targeted_frame_index: int = RomReader.battle_bin_data.targeted_front_frame_id[animation_manager.global_spr.seq_id]
	if is_back_facing:
		targeted_frame_index = RomReader.battle_bin_data.targeted_back_frame_id[animation_manager.global_spr.seq_id]
	
	#animation_manager.global_animation_ptr_id = 0
	debug_menu.anim_id_spin.value = 0
	var assembled_image: Image = animation_manager.global_shp.get_assembled_frame(targeted_frame_index, animation_manager.global_spr.spritesheet, 0, 
		0, 0, 0)
	animation_manager.unit_sprites_manager.sprite_primary.texture = ImageTexture.create_from_image(assembled_image)
	
	await get_tree().create_timer(0.2).timeout
	
	# take damage animation
	#animation_manager.global_animation_ptr_id = taking_damage_animation_id
	debug_menu.anim_id_spin.value = taking_damage_animation_id
	
	# show result / damage numbers
	
	# TODO await ability.vfx_completed? Or does ability_completed just need to wait to post numbers? aka WaitWeaponSheathe1/2 opcode?
	await UnitControllerRT.unit.ability_completed
	# show death animation
	#animation_manager.global_animation_ptr_id = knocked_out_animation_id
	debug_menu.anim_id_spin.value = knocked_out_animation_id
	idle_animation_id = knocked_out_animation_id
	
	knocked_out.emit(self)


func update_unit_facing(dir: Vector3) -> void:
	var angle_deg: float = rad_to_deg(atan2(dir.z, dir.x)) + 45 + 90
	var new_facing: Facings = Facings.NORTH
	if angle_deg < 90:
		new_facing = Facings.NORTH
	elif angle_deg < 180:
		new_facing = Facings.EAST
	elif angle_deg < 270:
		new_facing = Facings.SOUTH
	elif angle_deg < 360:
		new_facing = Facings.WEST
	
	if new_facing != facing:
		facing = new_facing
		update_animation_facing(UnitControllerRT.CameraFacingVectors[UnitControllerRT.camera_facing])


func update_animation_facing(camera_facing_vector: Vector3) -> void:
	var unit_facing_vector: Vector3 = FacingVectors[facing]
	#var camera_facing_vector: Vector3 = UnitControllerRT.CameraFacingVectors[controller.camera_facing]
	#var facing_difference: Vector3 = camera_facing_vector - unt_facing_vectorwad
	
	var unit_facing_angle = fposmod(rad_to_deg(atan2(unit_facing_vector.z, unit_facing_vector.x)), 360)
	var camera_facing_angle = fposmod(rad_to_deg(atan2(-camera_facing_vector.z, -camera_facing_vector.x)), 360)
	var facing_difference_angle = fposmod(camera_facing_angle - unit_facing_angle, 360)
		
	#push_warning("Difference: " + str(facing_difference) + ", UnitFacing: " + str(unit_facing_vector) + ", CameraFacing: " + str(camera_facing_vector))
	push_warning("Difference: " + str(facing_difference_angle) + ", UnitFacing: " + str(unit_facing_angle) + ", CameraFacing: " + str(camera_facing_angle))
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
	#animation_manager.weapon_id = new_weapon_id
	#var weapon_palette_id = RomReader.battle_bin_data.weapon_graphic_palettes_1[primary_weapon.id]
	animation_manager.unit_sprites_manager.sprite_weapon.texture = animation_manager.wep_spr.create_frame_grid_texture(
		primary_weapon.wep_frame_palette, 0, 0, primary_weapon.wep_frame_v_offset, 0, animation_manager.wep_shp.file_name)
	primary_weapon_assigned.emit(new_weapon_id)


func set_sprite(new_sprite_file_idx: int) -> void:
	sprite_file_idx = new_sprite_file_idx
	var spr: Spr = RomReader.sprs[new_sprite_file_idx]
	if spr.file_name == "WEP.SPR":
		animation_manager.unit_sprites_manager.sprite_primary.vframes = 32
	else:
		animation_manager.unit_sprites_manager.sprite_primary.vframes = 16 + (16 * spr.sp2s.size())
	
	if RomReader.spr_file_name_to_id.has(spr.file_name):
		sprite_id = RomReader.spr_file_name_to_id[spr.file_name]
	debug_menu.sprite_options.select(new_sprite_file_idx)
	on_sprite_idx_selected(new_sprite_file_idx)
	update_spritesheet_grid_texture()
	
	debug_menu.anim_id_spin.value = idle_animation_id


func set_sprite_file(sprite_file_name: String) -> void:
	var new_sprite_file_idx: int = RomReader.file_records[sprite_file_name].type_index
	set_sprite(new_sprite_file_idx)


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


func _on_character_body_3d_input_event(_camera: Node, _event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if Input.is_action_just_pressed("secondary_action") and UnitControllerRT.unit.char_body.is_on_floor():
		UnitControllerRT.unit.use_ability(char_body.position)
		process_targeted()
