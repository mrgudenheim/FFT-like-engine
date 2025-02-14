extends Node3D

var rom_reader: RomReader = RomReader.new()
@export var load_rom: LoadRomButton
@export var texture_viewer: Sprite3D
@export var camera_controller: CameraController
@export var background_gradient: TextureRect
@export var map_dropdown: OptionButton
@export var menu_reminder: Label
@export var map_size_label: Label

@export var maps: Node3D
@export var map_tscn: PackedScene

@export var unit: CharacterBody3D

@export var mirror: bool = true

const SCALE: float = 1.0 / MapData.TILE_SIDE_LENGTH
const SCALED_UNITS_PER_HEIGHT: float = SCALE * MapData.UNITS_PER_HEIGHT


func _ready() -> void:
	load_rom.file_selected.connect(rom_reader.on_load_rom_dialog_file_selected)
	rom_reader.rom_loaded.connect(on_rom_loaded)
	map_dropdown.item_selected.connect(on_map_selected)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		map_dropdown.visible = not map_dropdown.visible
		load_rom.visible = not load_rom.visible
		menu_reminder.visible = not menu_reminder.visible


func on_rom_loaded() -> void:
	push_warning("on rom loaded")
	
	for file_name in RomReader.file_records.keys():
		if file_name.contains(".GNS"):
			map_dropdown.add_item(file_name)
	
	var default_map_index: int = 56 # Orbonne
	default_map_index = 22 # Gariland
	map_dropdown.select(default_map_index)
	map_dropdown.item_selected.emit(default_map_index)


func on_map_selected(index: int) -> void:
	var map_file_name: String = map_dropdown.get_item_text(index)
	
	var start_time: int = Time.get_ticks_msec()
	var map_gns_data: PackedByteArray = RomReader.get_file_data(map_file_name)
	
	push_warning("Time to get file data (ms): " + str(Time.get_ticks_msec() - start_time))
	
	var map_data: MapData = MapData.new()
	map_data.file_name = map_file_name
	map_data.init_map(map_gns_data)
	map_size_label.text = "Map Size: " + str(map_data.map_width) + " x " + str(map_data.map_length) + " (" + str(map_data.map_width * map_data.map_length) + ")"
	
	background_gradient.texture.gradient.colors[0] = map_data.background_gradient_bottom
	background_gradient.texture.gradient.colors[1] = map_data.background_gradient_top
	
	texture_viewer.texture = map_data.albedo_texture
	#map_mesh.mesh = map_data.mesh
	
	for child: Node in maps.get_children():
		child.queue_free()
	
	instantiate_map(map_data, Vector3.ZERO, Vector3.ONE)
	
	#var shape_mesh: ConcavePolygonShape3D = map_mesh.mesh.create_trimesh_shape()
	#map_collision_shape.shape = shape_mesh
	
	if mirror:
		instantiate_map(map_data, Vector3.ZERO, Vector3(1, 1, -1))
		instantiate_map(map_data, Vector3.FORWARD * map_data.map_length * 2, Vector3(1, 1, -1))
		instantiate_map(map_data, Vector3.ZERO, Vector3(-1, 1, 1))
		instantiate_map(map_data, Vector3.RIGHT * map_data.map_width * 2, Vector3(-1, 1, 1))
		instantiate_map(map_data, Vector3.ZERO, Vector3(-1, 1, -1))
		instantiate_map(map_data, Vector3.FORWARD * map_data.map_length * 2, Vector3(-1, 1, -1))
		instantiate_map(map_data, Vector3.RIGHT * map_data.map_width * 2, Vector3(-1, 1, -1))
		instantiate_map(map_data, (Vector3.RIGHT * map_data.map_width * 2) + (Vector3.FORWARD * map_data.map_length * 2), Vector3(-1, 1, -1))
	
	
	var middle_height: float = (map_data.terrain_tiles[map_data.terrain_tiles.size() / 2].height * SCALED_UNITS_PER_HEIGHT) + 2
	var middle_position: Vector3 = Vector3(map_data.map_width / 2.0, middle_height, -map_data.map_length / 2.0)
	camera_controller.position = middle_position
	camera_controller.camera_pivot.rotation_degrees = Vector3(-CameraController.LOW_ANGLE, 45, 0)
	
	push_warning("Time to create map (ms): " + str(Time.get_ticks_msec() - start_time))
	push_warning("Map_created")
	
	push_warning(middle_position)
	unit.global_position = middle_position + Vector3(-0.5, 0, 0)
	unit.global_position = Vector3(5.5, 15, -5.5)
	
	map_dropdown.visible = false
	load_rom.visible = false
	menu_reminder.visible = true


func instantiate_map(new_map_data: MapData, position: Vector3, scale: Vector3) -> void:
	var new_map_instance: Map = map_tscn.instantiate()
	maps.add_child(new_map_instance)
	new_map_instance.mesh.mesh = new_map_data.mesh
	new_map_instance.mesh.scale = scale
	new_map_instance.position = position
	new_map_instance.rotation_degrees = Vector3(0, 180, 180)
	
	var shape_mesh: ConcavePolygonShape3D = new_map_data.mesh.create_trimesh_shape()
	if scale == Vector3.ONE:
		new_map_instance.collision_shape.shape = new_map_data.mesh.create_trimesh_shape()
	else:
		new_map_instance.collision_shape.shape = get_scaled_collision_shape(new_map_data.mesh, scale)


func get_scaled_collision_shape(mesh: Mesh, scale: Vector3) -> ConcavePolygonShape3D:
	var new_collision_shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	var faces: PackedVector3Array = new_collision_shape.get_faces()
	for i: int in faces.size():
		faces[i] = faces[i] * scale
	
	#push_warning(faces)
	new_collision_shape.set_faces(faces)
	new_collision_shape.backface_collision = true
	return new_collision_shape
