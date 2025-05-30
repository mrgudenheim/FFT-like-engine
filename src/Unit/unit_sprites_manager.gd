class_name UnitSpritesManager
extends Node3D

const LAYERING_OFFSET: float = 0.001

@export var sprite_primary: Sprite3D
@export var sprite_weapon: Sprite3D
@export var sprite_effect: Sprite3D
@export var sprite_text: Sprite3D

@export var sprite_item: Sprite3D
var item_initial_pos: Vector3 = Vector3(0, -0.714, 0)
@export var sprite_background: Sprite3D



func reset_sprites() -> void:
	# reset position
	self.position = Vector3.ZERO
	sprite_item.position = item_initial_pos
	sprite_item.rotation = Vector3.ZERO
	sprite_item.frame = 32
	
	# reset layer priority
	sprite_primary.position.z = -2 * LAYERING_OFFSET
	sprite_weapon.position.z = -3 * LAYERING_OFFSET
	sprite_weapon.frame = (sprite_weapon.hframes * sprite_weapon.vframes) - 1 # TODO fix setting blank, set visible = false?
	#sprite_weapon.visible = false
	sprite_effect.position.z = -1 * LAYERING_OFFSET
	sprite_effect.frame = (sprite_effect.hframes * sprite_effect.vframes) - 1 # TODO fix setting blank, set visible = false?
	#sprite_effect.visible = false
	sprite_text.position.z = 0 * LAYERING_OFFSET
	
	sprite_primary.rotation_degrees.z = 0
	sprite_weapon.rotation_degrees.z = 0
	sprite_effect.rotation_degrees.z = 0
	sprite_text.rotation_degrees.z = 0
	
	# reset flip_h
	sprite_primary.flip_h = false
	sprite_weapon.flip_h = false
	sprite_effect.flip_h = false
	sprite_text.flip_h = false
	
	# reset flip_v
	sprite_primary.flip_v = false
	sprite_weapon.flip_v = false
	sprite_effect.flip_v = false
	sprite_text.flip_v = false


func flip_h() -> void:
	sprite_primary.flip_h = not sprite_primary.flip_h
	sprite_weapon.flip_h = not sprite_weapon.flip_h
	sprite_effect.flip_h = not sprite_effect.flip_h
	sprite_item.flip_h = not sprite_item.flip_h
