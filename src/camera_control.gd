extends Node3D

@export var sprite: Sprite3D
@export var camera: Camera3D

signal zoom_changed
signal offset_changed

const PAN_SPEED: float = 0.1

var zoom: float = 15:
	get:
		return zoom
	set(value):
		zoom = value
		zoom_changed.emit()
@export var zoom_in_max: float = 500
@export var zoom_out_max: float = 0.01
var mouse_pos := Vector2.ZERO
var drag := false
var should_tween := true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"zoom_in", false, true):  # Wheel Up Event
		zoom_camera(1)
	elif event.is_action_pressed(&"zoom_out", false, true):  # Wheel Down Event
		zoom_camera(-1)
	elif event is InputEventMagnifyGesture:  # Zoom gesture on touchscreens
		if event.factor >= 1:  # Zoom in
			zoom_camera(1)
		else:  # Zoom out
			zoom_camera(-1)
	else:
		var dir := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
		if dir != Vector2.ZERO:
			push_warning(dir)
			pan_camera(dir)


func zoom_camera(dir: int) -> void:
	var zoom_margin := zoom * (-dir) / 5
	var new_zoom := zoom + zoom_margin
	if new_zoom < zoom_in_max and new_zoom > zoom_out_max:
		var tween := create_tween().set_parallel()
		tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		tween.tween_property(camera, "size", new_zoom, 0.05)
	zoom = new_zoom


func pan_camera(dir: Vector2) -> void:
	var new_position: Vector3 = Vector3.ZERO
	var offset: Vector2 = dir * zoom * PAN_SPEED
	
	var new_x = self.position.x + offset.x
	var new_y = self.position.y - offset.y
	var new_z = self.position.z
	new_position = Vector3(new_x, new_y, new_z)
	
	var tween := create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", new_position, 0.05)
