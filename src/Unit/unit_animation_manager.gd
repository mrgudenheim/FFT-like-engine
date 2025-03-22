class_name UnitAnimationManager
extends Node3D

signal animation_completed
signal animation_loop_completed
signal animation_frame_loaded
signal processing_opcode(index: int)

#@export var ui_manager: UiManager
@export var unit_data: UnitData
@export var unit_sprites_manager: UnitSpritesManager
var global_fft_animation: FftAnimation
var global_spr: Spr
var global_shp: Shp
var global_seq: Seq

var wep_spr: Spr
var wep_shp: Shp
var wep_seq: Seq

var eff_spr: Spr
var eff_shp: Shp
var eff_seq: Seq

var item_spr: Spr
var item_shp: Shp

var other_spr: Spr
var other_shp: Shp

@export var item_index: int = 0
@export var submerged_depth: int = 0
@export var is_right_facing: bool = false
#@export var is_playing_check: CheckBox
@export var is_back_facing: bool = false

@export_file("*.txt") var layer_priority_table_filepath: String
static var layer_priority_table: Array[PackedStringArray] = []
@export_file("*.txt") var item_list_filepath: String
static var item_list: Array[PackedStringArray] = []

@export var animation_is_playing: bool = true
@export var animation_speed: float = 59 # frames per sec
var opcode_frame_offset: int = 0
@export var weapon_sheathe_check1_delay: int = 0
@export var weapon_sheathe_check2_delay: int = 25
@export var wait_for_input_delay: int = 0


@export var weapon_shp_num: int = 1 # TODO fix for type2
var effect_type: int = 1

@export var global_animation_id: int = 0:
	get:
		return global_animation_id
	set(value):
		if (value != global_animation_id):
			global_animation_id = value
			#ui_manager.animation_name_options.select(value)
			_on_animation_changed()
			#if isReady:
				#if not global_fft_animation.sequence.seq_parts[0].isOpcode:
					#frame_id_spinbox.value = global_fft_animation.sequence.seq_parts[0].parameters[0]


@export var global_animation_ptr_id: int = 0:
	get:
		return global_animation_ptr_id
	set(value):
		if (value != global_animation_ptr_id):
			global_animation_ptr_id = value
			global_animation_id = global_seq.sequence_pointers[value]
			#ui_manager.animation_name_options.select(value)
			#_on_animation_changed()


func _ready() -> void:
	if layer_priority_table.size() == 0:
		layer_priority_table = load_csv(layer_priority_table_filepath)
	if item_list.size() == 0:
		item_list = load_csv(item_list_filepath)


func load_csv(filepath: String) -> Array[PackedStringArray]:
	var table: Array[PackedStringArray] = []
	var file := FileAccess.open(filepath, FileAccess.READ)
	var file_contents: String = file.get_as_text()
	var lines: PackedStringArray = file_contents.split("\r\n")
	if lines.size() == 1:
		lines = file_contents.split("\n")
	if lines.size() == 1:
		lines = file_contents.split("\r")
	#print(lines)

	for line_index in range(1,lines.size()): # skip first row of headers
		table.append(lines[line_index].split(","))

	return table


func start_animation(fft_animation: FftAnimation, draw_target: Sprite3D, is_playing: bool, isLooping: bool, force_loop: bool = false) -> void:
	if fft_animation.primary_anim != global_fft_animation:
		return
	
	var num_parts: int = fft_animation.sequence.seq_parts.size()
	
	var only_opcodes: bool = true
	for animation_part in fft_animation.sequence.seq_parts:
		if not animation_part.isOpcode:
			only_opcodes = false
			break
	
	#draw_target.visible = true
	#draw_target.modulate.a = 1
	
	# TODO this should play for actual game (ie. non-FFTae)
	# don't loop when no parts, only 1 part, or all parts are opcodes
	if num_parts == 0:
		#draw_target.visible = false
		draw_target.frame = (draw_target.hframes * draw_target.vframes) - 1
		await get_tree().create_timer(0.001).timeout # prevent infinite loop
		return
	elif fft_animation.is_primary_anim and only_opcodes: # TODO only_opcodes should play instead of showing a blank image, ie. if only a loop, but need to handle broken MON MFItem animation infinite loop
		# draw a blank image
		draw_target.frame = (draw_target.hframes * draw_target.vframes) - 1 # TODO fix this, set blank by setting visible = false?
		#draw_target.visible = false
		await get_tree().create_timer(0.001).timeout # prevent infinite loop from Wait opcodes looping only opcodes
		return
	elif (num_parts == 1 and not force_loop):
		process_seq_part(fft_animation, 0, draw_target)
		return
	
	if (is_playing):
		await play_animation(fft_animation, draw_target, isLooping)
	else:
		process_seq_part(fft_animation, 0, draw_target)


func play_animation(fft_animation: FftAnimation, draw_target: Sprite3D, isLooping: bool) -> void:
	var animation_part_id: int = 0
	while animation_part_id < fft_animation.sequence.seq_parts.size():
		if fft_animation.primary_anim != global_fft_animation:
			return
		
		var seq_part: SeqPart = fft_animation.sequence.seq_parts[animation_part_id]
		if fft_animation.is_primary_anim:
			processing_opcode.emit(animation_part_id)
		
		# break loop animation when stopped or on selected animation changed to prevent 2 loops playing at once
		if ((isLooping or fft_animation.is_primary_anim) 
			and (!animation_is_playing or fft_animation != global_fft_animation)):
			return
		
		animation_part_id = await process_seq_part(fft_animation, animation_part_id, draw_target)
		
		if not seq_part.isOpcode:
			var delay_frames: int = seq_part.parameters[1]  # param 1 is delay
			if delay_frames == 0 and fft_animation.is_primary_anim:
				animation_completed.emit()
				return
			
			var delay_sec: float = delay_frames / animation_speed
			await get_tree().create_timer(delay_sec).timeout


func process_seq_part(fft_animation: FftAnimation, seq_part_id: int, draw_target: Sprite3D) -> int:
	# print_debug(str(animation) + " " + str(animation_part_id + 3))
	var next_seq_part_id: int = seq_part_id + 1
	var seq_part:SeqPart = fft_animation.sequence.seq_parts[seq_part_id]
	
	var frame_id_label: String = ""
	if seq_part.isOpcode:
		frame_id_label = seq_part.to_string()
	else:
		frame_id_label = str(seq_part.parameters[0])
	
	if fft_animation.primary_anim_opcode_part_id == 0:
		fft_animation.primary_anim_opcode_part_id = fft_animation.sequence.seq_parts.size()
	
	# handle LoadFrameWait
	if not seq_part.isOpcode:
		var new_frame_id: int = seq_part.parameters[0]
		var frame_id_offset: int = get_animation_frame_offset(unit_data.primary_weapon.item_type, fft_animation.shp, fft_animation.back_face_offset)
		new_frame_id = new_frame_id + frame_id_offset + opcode_frame_offset
		frame_id_label = str(new_frame_id)
		
		# clear the frame to prevent weird and inconsistent ghosting issues
		draw_target.frame = (draw_target.hframes * draw_target.vframes) - 1 # TODO fix this so a 255th frame can actually be made/set - set draw_target.visible = false?
		if new_frame_id < fft_animation.shp.frames.size(): # high frame offsets (such as shuriken) can only be used with certain animations
			#draw_target.visible = true
			var y_rotation: float = fft_animation.shp.get_frame(new_frame_id, fft_animation.submerged_depth).y_rotation
			if fft_animation.flipped_h != fft_animation.flipped_v:
				y_rotation = -y_rotation
			draw_target.rotation_degrees = Vector3(0, 0, -y_rotation)
			
			draw_target.frame = new_frame_id
			
			if fft_animation.is_primary_anim:
				animation_frame_loaded.emit()
	# Handle opcodes
	elif seq_part.isOpcode:
		#push_warning(anim_part_start)
		if seq_part.opcode_name == "QueueSpriteAnim":
			#push_warning("Performing " + anim_part_start) 
			if seq_part.parameters[0] == 1: # play weapon animation
				weapon_shp_num = 2 if global_shp.file_name.to_upper().contains("TYPE2") else 1
				var new_animation := FftAnimation.new()
				var wep_file_name: String = "WEP" + str(weapon_shp_num)
				new_animation.seq = wep_seq
				new_animation.shp = wep_shp
				new_animation.sequence = new_animation.seq.sequences[new_animation.seq.sequence_pointers[seq_part.parameters[1]]]
				new_animation.is_primary_anim = false
				new_animation.primary_anim = fft_animation.primary_anim
				new_animation.flipped_h = fft_animation.flipped_h
				
				start_animation(new_animation, unit_sprites_manager.sprite_weapon, true, false, false)
			elif seq_part.parameters[0] == 2: # play effect animation
				var new_animation := FftAnimation.new()
				var eff_file_name: String = "EFF" + str(effect_type)
				new_animation.seq = eff_seq
				new_animation.shp = eff_shp
				new_animation.sequence = new_animation.seq.sequences[new_animation.seq.sequence_pointers[seq_part.parameters[1]]]
				new_animation.is_primary_anim = false
				new_animation.primary_anim = fft_animation.primary_anim
				new_animation.flipped_h = fft_animation.flipped_h
				
				start_animation(new_animation, unit_sprites_manager.sprite_effect, true, false, false)
			else:
				push_warning("Error: QueueSpriteAnim: " + seq_part.to_string() + "\n" + fft_animation.sequence.to_string())
		elif seq_part.opcode_name.begins_with("Move"):
			var position_offset: Vector3 = Vector3.ZERO
			if seq_part.opcode_name == "MoveUnitFB":
				position_offset = unit_data.facing_vector * seq_part.parameters[0]
			elif seq_part.opcode_name == "MoveUnitDU":
				position_offset = Vector3(0, -seq_part.parameters[0], 0)
			elif seq_part.opcode_name == "MoveUnitRL":
				position_offset = unit_data.facing_vector.rotated(Vector3.UP, deg_to_rad(-90)) * seq_part.parameters[0]
			elif seq_part.opcode_name == "MoveUnitRLDUFB":
				var position_offset_fb: Vector3 = unit_data.facing_vector * seq_part.parameters[2]
				var position_offset_rl: Vector3 = unit_data.facing_vector.rotated(Vector3.UP, deg_to_rad(-90)) * seq_part.parameters[0]
				var position_offset_du: Vector3 = Vector3(0, -seq_part.parameters[1], 0)
				position_offset = position_offset_fb + position_offset_rl + position_offset_du
			elif seq_part.opcode_name == "MoveUp1":
				position_offset = Vector3(0, 1, 0)
			elif seq_part.opcode_name == "MoveUp2":
				position_offset = Vector3(0, 2, 0)
			elif seq_part.opcode_name == "MoveDown1":
				position_offset = Vector3(0, -1, 0)
			elif seq_part.opcode_name == "MoveDown2":
				position_offset = Vector3(0, -2, 0)
			elif seq_part.opcode_name == "MoveBackward1":
				position_offset = unit_data.facing_vector * -1
			elif seq_part.opcode_name == "MoveBackward2":
				position_offset = unit_data.facing_vector * -2
			elif seq_part.opcode_name == "MoveForward1":
				position_offset = unit_data.facing_vector * 1
			elif seq_part.opcode_name == "MoveForward2":
				position_offset = unit_data.facing_vector * 2
			else:
				push_warning("can't interpret " + seq_part.opcode_name)
				
			unit_sprites_manager.global_position += position_offset * MapViewer.SCALE
		elif seq_part.opcode_name == "SetLayerPriority": # TODO fix for sprite3Ds, use sorting_offset property?
			# push_warning(layer_priority_table)
			var layer_priority: Array = layer_priority_table[seq_part.parameters[0]]
			for i in range(0, layer_priority.size() - 1):
				var layer_name: String = layer_priority[i + 1] # skip set_id
				if layer_name == "unit":
					unit_sprites_manager.sprite_primary.position.z = -i * UnitSpritesManager.LAYERING_OFFSET
				elif layer_name == "weapon":
					unit_sprites_manager.sprite_weapon.position.z = -i * UnitSpritesManager.LAYERING_OFFSET
				elif layer_name == "effect":
					unit_sprites_manager.sprite_effect.position.z = -i * UnitSpritesManager.LAYERING_OFFSET
				elif layer_name == "text":
					unit_sprites_manager.sprite_text.position.z = -i * UnitSpritesManager.LAYERING_OFFSET
		elif seq_part.opcode_name == "SetFrameOffset":
			opcode_frame_offset = seq_part.parameters[0] # use global var since SetFrameOffset is only used in animations that do not call other animations
		elif seq_part.opcode_name == "FlipHorizontal": # does not do anything for wep or eff animations through QueueSpriteAnim
			if draw_target == unit_sprites_manager.sprite_primary:
				draw_target.flip_h = !draw_target.flip_h
				fft_animation.flipped_h = not fft_animation.flipped_h
		elif seq_part.opcode_name == "FlipVertical": # does not do anything for wep or eff animations through QueueSpriteAnim
			if draw_target == unit_sprites_manager.sprite_primary:
				draw_target.flip_v = !draw_target.flip_v
				fft_animation.flipped_v = not fft_animation.flipped_v
		elif seq_part.opcode_name == "UnloadMFItem":
			var target_sprite: Sprite3D = unit_sprites_manager.sprite_item
			target_sprite.texture = ImageTexture.create_from_image(fft_animation.shp.create_blank_frame())
			# reset any rotation or movement
			target_sprite.rotation_degrees = Vector3.ZERO
			target_sprite.position = Vector3.ZERO
		elif seq_part.opcode_name == "MFItemPosFBDU":
			var target_sprite_pivot := unit_sprites_manager.sprite_item
			target_sprite_pivot.position = Vector3(-seq_part.parameters[0], -seq_part.parameters[1], 0.01) * MapViewer.SCALE # assume facing left, add 20 because it is y position from bottom of unit
		elif seq_part.opcode_name == "LoadMFItem":
			var item_frame_id: int = item_index # assumes loading item
			var item_sheet_type:Shp = item_shp
			var item_image: Image = item_spr.spritesheet
			
			if item_index >= 180:
				item_sheet_type = other_shp
				item_image = other_spr.spritesheet
				
				if item_index <= 187: # load crystal
					item_frame_id = item_index - 179
					unit_data.debug_menu.other_type_options.select(2) # to update ui
					#other_type_index = 2 # to set v_offset is correct
				elif item_index == 188: # load chest 1
					item_frame_id = 15
					unit_data.debug_menu.other_type_options.select(0)
					#other_type_index = 0
				elif item_index == 189: # load chest 2
					item_frame_id = 16
					unit_data.debug_menu.other_type_options.select(0)
					#other_type_index = 0
			
			frame_id_label = str(item_index)
			
			var assembled_image: Image = item_sheet_type.get_assembled_frame(
					item_frame_id, item_image, global_animation_ptr_id, unit_data.debug_menu.other_type_options.selected, unit_data.primary_weapon.wep_frame_v_offset, submerged_depth)
			var target_sprite: Sprite3D = unit_sprites_manager.sprite_item
			target_sprite.texture = ImageTexture.create_from_image(assembled_image)
			var y_rotation: float = item_sheet_type.get_frame(item_frame_id, submerged_depth).y_rotation
			target_sprite.rotation_degrees = Vector3(0, 0, y_rotation)
		elif seq_part.opcode_name == "Wait":
			var loop_length: int = seq_part.parameters[0]
			if loop_length > 0:
				var jump_length: int = 1
				var jump_seq_part_id: int = seq_part_id + 1
				while jump_seq_part_id < fft_animation.sequence.seq_parts.size():
					if jump_length >= loop_length:
						break
					jump_length += fft_animation.sequence.seq_parts[jump_seq_part_id].length
					jump_seq_part_id += 1
				
				next_seq_part_id = jump_seq_part_id
			else:
				var num_loops: int = seq_part.parameters[1]
				
				var primary_animation_part_id: int = seq_part_id + fft_animation.primary_anim_opcode_part_id - fft_animation.sequence.seq_parts.size()
				# push_warning(str(primary_animation_part_id) + "\t" + str(animation_part_id) + "\t" + str(primary_anim_opcode_part_id) + "\t" + str(animation.size() - 3))
				
				var temp_seq: Sequence = get_sub_animation(loop_length, primary_animation_part_id, fft_animation.parent_anim.sequence)
				var temp_fft_animation: FftAnimation = fft_animation.get_duplicate()
				temp_fft_animation.sequence = temp_seq
				temp_fft_animation.parent_anim = fft_animation
				temp_fft_animation.is_primary_anim = false
				temp_fft_animation.primary_anim = fft_animation.primary_anim
				temp_fft_animation.primary_anim_opcode_part_id = primary_animation_part_id
				
				for iteration in num_loops:
					if temp_fft_animation.primary_anim != global_fft_animation:
						break
					await start_animation(temp_fft_animation, draw_target, true, false, true)
		
		elif seq_part.opcode_name == "WaitForInput":
			var delay_frames: int = wait_for_input_delay
			var loop_length: int = seq_part.parameters[0]
			var primary_animation_part_id: int = seq_part_id + fft_animation.primary_anim_opcode_part_id - fft_animation.sequence.seq_parts.size()
			var temp_seq: Sequence = get_sub_animation(loop_length, primary_animation_part_id, fft_animation.parent_anim.sequence)
			var temp_fft_animation: FftAnimation = fft_animation.get_duplicate()
			temp_fft_animation.sequence = temp_seq
			temp_fft_animation.parent_anim = fft_animation
			temp_fft_animation.is_primary_anim = false
			temp_fft_animation.primary_anim = fft_animation.primary_anim
			temp_fft_animation.primary_anim_opcode_part_id = primary_animation_part_id
			
			# push_warning(str(temp_anim))
			# TODO wait for input signal
			var timer: SceneTreeTimer = get_tree().create_timer(delay_frames / animation_speed)
			while timer.time_left > 0:
				if temp_fft_animation.primary_anim != global_fft_animation:
					break
				# push_warning(str(timer.time_left) + " " + str(temp_anim))
				await start_animation(temp_fft_animation, draw_target, true, false, true)
		elif seq_part.opcode_name.begins_with("WeaponSheatheCheck"):
			var delay_frames: int = weapon_sheathe_check1_delay
			if seq_part.opcode_name == "WeaponSheatheCheck2":
				delay_frames = weapon_sheathe_check2_delay
			
			var loop_length: int = seq_part.parameters[0]
			var primary_animation_part_id: int = seq_part_id + fft_animation.primary_anim_opcode_part_id - fft_animation.sequence.seq_parts.size()
			# push_warning(str(primary_animation_part_id) + "\t" + str(animation_part_id) + "\t" + str(primary_anim_opcode_part_id) + "\t" + str(animation.size() - 3))
			
			var temp_seq: Sequence = get_sub_animation(loop_length, primary_animation_part_id, fft_animation.parent_anim.sequence)
			var temp_fft_animation: FftAnimation = fft_animation.get_duplicate()
			temp_fft_animation.sequence = temp_seq
			temp_fft_animation.parent_anim = fft_animation
			temp_fft_animation.is_primary_anim = false
			temp_fft_animation.primary_anim = fft_animation.primary_anim
			temp_fft_animation.primary_anim_opcode_part_id = primary_animation_part_id
			
			# print_debug(str(temp_anim))
			# TODO wait for weapon sheathe check signal
			var timer: SceneTreeTimer = get_tree().create_timer(delay_frames / animation_speed)
			while timer.time_left > 0:
				if temp_fft_animation.primary_anim != global_fft_animation:
					break
				await start_animation(temp_fft_animation, draw_target, true, false, true)
		elif seq_part.opcode_name == "WaitForDistort":
			pass
		elif seq_part.opcode_name == "QueueDistortAnim":
			# https://ffhacktics.com/wiki/Animate_Unit_Distorts
			pass
		elif seq_part.opcode_name == "IncrementLoop":
			animation_loop_completed.emit()
			if fft_animation.is_primary_anim:
				reset_sprites()
			start_animation(fft_animation, draw_target, animation_is_playing, false)
		elif seq_part.opcode_name == "EndAnimation":
			#reset_sprites() # TODO reset position and rotation of draw_target (and pivot)
			draw_target.frame = (draw_target.hframes * draw_target.vframes) - 1 # TODO fix this so a 255th frame can actually be made
			#draw_target.visible = false
			if fft_animation.is_primary_anim:
				reset_sprites()
				animation_completed.emit()
		elif seq_part.opcode_name == "PauseAnimation":
			if fft_animation.is_primary_anim:
				animation_completed.emit()
		# Opcodes from animation rewraite ASM by Talcall
		elif seq_part.opcode_name == "SetBackFacedOffset":
			fft_animation.back_face_offset = seq_part.parameters[0]
			pass
	
	return next_seq_part_id


func get_animation_frame_offset(local_frame_offset_index: int, shp: Shp, back_faced_offset: int) -> int:
	if ((shp.file_name.contains("WEP") or shp.file_name.contains("EFF"))
			and shp.zero_frames.size() > 0):
		return shp.zero_frames[local_frame_offset_index]
	else:
		if is_back_facing: # TODO how to handle combination of weapon and back facing?
			return back_faced_offset
		else:
			return 0


func get_sub_animation(length: int, sub_animation_end_part_id: int, parent_animation: Sequence) -> Sequence:
	var sub_anim_length: int = 0
	var sub_anim: Sequence = Sequence.new()
	var previous_anim_part_id: int = sub_animation_end_part_id - 1
	
	# push_warning(str(animation) + "\n" + str(previous_anim_part_id))
	while sub_anim_length < abs(length):
		# push_warning(str(previous_anim_part_id) + "\t" + str(sub_anim_length) + "\t" + str(parent_animation[previous_anim_part_id + 3]) + "\t" + str(parent_animation[sub_animation_end_part_id + 3][0]))
		var previous_anim_part: SeqPart = parent_animation.seq_parts[previous_anim_part_id]
		sub_anim.seq_parts.insert(0, previous_anim_part)
		sub_anim_length += previous_anim_part.length
	
		previous_anim_part_id -= 1
	
	# add label, id, and num_parts
	sub_anim.seq_name = parent_animation.seq_name + ":" + str(sub_animation_end_part_id - length) + "-" + str(sub_animation_end_part_id)
	
	return sub_anim


func _on_animation_changed() -> void:
	reset_sprites()
	var new_fft_animation: FftAnimation = get_animation_from_globals()
	var num_parts: int = new_fft_animation.sequence.seq_parts.size()
	start_animation(new_fft_animation, unit_sprites_manager.sprite_primary, animation_is_playing, false)


func reset_sprites() -> void:
	# reset frame offset
	opcode_frame_offset = 0
	unit_sprites_manager.reset_sprites(is_right_facing)


func get_animation_from_globals() -> FftAnimation:
	var fft_animation: FftAnimation = FftAnimation.new()
	fft_animation.seq = global_seq
	fft_animation.shp = global_shp
	fft_animation.sequence = global_seq.sequences[global_animation_id]
	fft_animation.flipped_h = is_right_facing
	fft_animation.flipped_v = false
	fft_animation.submerged_depth = submerged_depth
	fft_animation.back_face_offset = 0
	
	global_fft_animation = fft_animation
	return fft_animation


func _on_is_playing_check_box_toggled(toggled_on: bool) -> void:
	animation_is_playing = toggled_on
	
	if toggled_on and not animation_completed.is_connected(_on_animation_changed):
		animation_completed.connect(_on_animation_changed)
	elif !toggled_on and animation_completed.is_connected(_on_animation_changed):
		animation_completed.disconnect(_on_animation_changed)
	
	if global_seq.sequences.size() == 0:
		return
	_on_animation_changed()


func _on_animation_id_spin_box_value_changed(value: int) -> void:
	global_animation_id = value


func _on_animation_h_slider_value_changed(value: int) -> void:
	if(animation_is_playing):
		return
	
	process_seq_part(global_fft_animation, value, unit_sprites_manager.sprite_primary)


func _on_palette_spin_box_value_changed(value: float) -> void:
	global_spr.set_pixel_colors(value)
	global_spr.spritesheet = global_spr.get_rgba8_image()
	
	_on_animation_changed()


func _on_submerged_options_item_selected(index: int) -> void:
	submerged_depth = index
	_on_animation_changed()


func _on_face_right_check_toggled(toggled_on: bool) -> void:
	#unit_sprites_manager.flip_h()
	is_right_facing = toggled_on
	
	#unit_sprites_manager.scale.x = unit_sprites_manager.scale.x * -1
	_on_animation_changed()


func set_animation_fps(value: float) -> void:
	animation_speed = value
