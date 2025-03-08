class_name VisualEffectData

# https://ffhacktics.com/wiki/Effect_Files
# https://ffhacktics.com/wiki/Effect_Data
var is_initialized: bool = false
var file_name: String = "effect file name"
var vfx_id: int = 0
var ability_names: String = ""

var header_start: int = 0
var section_offsets: PackedInt32Array = []

var frame_sets: Array[VfxFrameSet] = []

class VfxFrameSet:
	var frame_set: Array[VfxFrame] = []

class VfxFrame:
	var top_left_uv: Vector2i = Vector2i.ZERO
	var width: int = 0
	var height: int = 0
	var quad: Rect2i = Rect2i()


var spritesheet: Image
var image_color_depth: int = 0 # 8bpp or 4bpp
var image_height: int = 0 # pixels
var image_width = image_color_depth * 16 # unless full 256 x 256

# SINGLE - camera will point at the targeted location
# SEQUENTIAL - camera will move between each each target
# MULTI - camera will point at a single location, but make sure all targets are in view
enum camera_focus {SINGLE, SEQUENTIAL, MULTI} 

var sound_effects
var partical_effects


enum VfxSections {
	FRAMES = 0,
	ANIMATION = 1,
	VFX_SCRIPT = 2,
	EMITTER_MOTION_CONTROL = 3,
	TIMER_DATA_CAMERA_HEADER = 6,
	TIMER_DATA_CAMERA = 7,
	SOUND_EFFECTS = 8,
	PALETTE_IMAGE = 9,
	}


func _init(new_file_name: String = "") -> void:
	file_name = new_file_name
	vfx_id = new_file_name.trim_suffix(".BIN").trim_prefix("E").to_int()


func init_from_file() -> void:
	var vfx_bytes: PackedByteArray = RomReader.get_file_data(file_name)
	
	#### header data
	header_start = RomReader.battle_bin_data.ability_vfx_header_offsets[vfx_id]
	var section_offsets_bytes: PackedByteArray = vfx_bytes.slice(header_start, header_start + 40)
	var entry_size = 4
	var num_entries = 10
	var data_bytes: PackedByteArray = vfx_bytes.slice(header_start, header_start + (entry_size * num_entries))
	section_offsets.resize(num_entries)
	for id: int in num_entries:
		section_offsets[id] = data_bytes.decode_u32(id * entry_size) + header_start
	
	#### frame data (and image color depth)
	var section_num = VfxSections.FRAMES
	var section_start: int = header_start + section_offsets[section_num]
	data_bytes = vfx_bytes.slice(section_start, header_start + section_offsets[section_num + 1])
	
	var frame_sets_data_start: int = data_bytes.decode_u16(6)
	var num_frame_sets: int = (frame_sets_data_start - 6) / 2
	frame_sets.resize(num_frame_sets)
	var frame_set_offsets: PackedInt32Array = []
	for id: int in num_frame_sets:
		frame_set_offsets[id] = data_bytes.decode_u16(6 + (2 * id)) + 4
	
	# image color depth from first frame in first frame_set
	if data_bytes.decode_u8(frame_set_offsets[0] + 1) & 0x80 == 0:
		image_color_depth = 4
	else:
		image_color_depth = 8
	
	# frame sets
	for frame_set_id: int in num_frame_sets:
		var frame_set: VfxFrameSet = VfxFrameSet.new()
		
		var next_section_start: int = data_bytes.size()
		if frame_set_id < num_frame_sets - 1:
			next_section_start = frame_set_offsets[frame_set_id + 1]
		
		var frame_set_bytes: PackedByteArray = data_bytes.slice(frame_set_offsets[frame_set_id] + 4, next_section_start)
		var frame_data_length: int = 0x18
		var num_frames: int = (frame_set_bytes.size() - 4) / frame_data_length
		frame_set.frame_set.resize(num_frames)
		for frame_id: int in num_frames:
			var frame_bytes: PackedByteArray = frame_set_bytes.slice(4 + (frame_id * frame_data_length))
			var new_frame: VfxFrame = VfxFrame.new()
			var top_left_u: int = frame_bytes.decode_u8(4)
			var top_left_v: int = frame_bytes.decode_u8(5)
			new_frame.top_left_uv = Vector2i(top_left_u, top_left_v)
			new_frame.width = frame_bytes.decode_s8(6)
			new_frame.height = frame_bytes.decode_s8(7)
			var top_left_x: int = frame_bytes.decode_s16(8)
			var top_left_y: int = frame_bytes.decode_s16(0xa)
			var bottom_right_x: int = frame_bytes.decode_s16(0x14)
			var bottom_right_y: int = frame_bytes.decode_s16(0x16)
			new_frame.quad.position = Vector2i(top_left_x, top_left_y)
			new_frame.quad.end = Vector2i(bottom_right_x, bottom_right_y)
			
			frame_set.frame_set[frame_id] = new_frame
		
		frame_sets[frame_set_id] = frame_set
	
	#### image and palette data
	
	
	is_initialized = true
