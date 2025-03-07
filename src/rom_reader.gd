#class_name RomReader
extends Node

signal rom_loaded

var is_ready: bool = false

var rom: PackedByteArray = []
var file_records: Dictionary[String, FileRecord] = {} # {String, FileRecord}
var lba_to_file_name: Dictionary[int, String] = {} # {int, String}

const DIRECTORY_DATA_SECTORS_ROOT: PackedInt32Array = [22]
const OFFSET_RECORD_DATA_START: int = 0x60

# https://en.wikipedia.org/wiki/CD-ROM#CD-ROM_XA_extension
const BYTES_PER_SECTOR: int = 2352
const BYTES_PER_SECTOR_HEADER: int = 24
const BYTES_PER_SECTOR_FOOTER: int = 280
const DATA_BYTES_PER_SECTOR: int = 2048

var sprs: Array[Spr] = []
var spr_file_name_to_id: Dictionary[String, int] = {}

var shps: Array[Shp] = []
var seqs: Array[Seq] = []
var maps: Array[MapData] = []
var effects: Array[VisualEffectData] = []
var abilities: Array[AbilityData] = []

@export_file("*.txt") var item_frames_csv_filepath: String = "res://src/fftae/frame_data_item.txt"

# BATTLE.BIN tables
# https://ffhacktics.com/wiki/BATTLE.BIN_Data_Tables#Animation_.26_Display_Related_Data
var sounds_attacks # BATTLE.BIN offset="2cd40" - table of sounds for miss, hit, and deflected, by weapong type
var ability_animations # BATTLE.BIN offset="2ce10" - sets of 3 bytes total for 1) charging, 2) executing, and 3) text
var wep_animation_offsets # BATTLE.BIN offset="2d364" - Weapon Change of Animation (multiplied by 2 (+1 if camera is behind the unit) to get true animation - applied to unit when attacking
var item_graphics # BATTLE.BIN offset="2d3e4" - Item Graphic Data (0x7f total?), palettes (wep1 or wep2), and graphic id (multiple of 2)
var unit_frame_sizes # BATTLE.BIN offset="2d53c" - Unit raw size measurements? all words. contains many possible raw size combinations (for the record, these are all *8 to get the true graphic size.)
var wep_eff_frame_sizes # BATTLE.BIN offset="2d6c8" - weapon/effect raw size measurements? all words, with only a byte of data each. this is just inefficient.
var spritesheet_data # BATTLE.BIN offset="2d748" - Spritesheet Data (4 bytes each, 0x9f total), SHP, SEQ, Flying, Graphic Height
var frame_targeted # BATTLE.BIN offset="2d9c4" - called if target hasn't replaced target animation (e.g. shield)


# Images
# https://github.com/Glain/FFTPatcher/blob/master/ShishiSpriteEditor/PSXImages.xml#L148


# Text
var fft_text: FftText = FftText.new()
# https://github.com/Glain/FFTPatcher/blob/master/FFTacText/notes.txt
# https://ffhacktics.com/wiki/Load_FFTText
# https://github.com/Glain/FFTPatcher/blob/master/FFTacText/PSXText.xml
var world_lzw_offsets: PackedInt32Array = []
enum WORLD_LZW_SECTIONS {
	JOB_NAMES = 6,
	ITEM_NAMES = 7,
	ROSTER_UNIT_NAMES = 8,
	UNIT_NAMES2 = 9,
	BATTLE_MENUS = 10,
	HELP_TEXT = 11,
	PROPOSITION_OUTCOMES = 12,
	ABILITY_NAMES = 14,
	PROPOSITION_REWARDS = 15,
	TIPS_NAMES = 16,
	LOCATION_NAMES = 18,
	WORLD_MAP_MENU = 20,
	MAP_NAMES = 21,
	SKILLSET_NAMES = 22,
	BAR_TEXT = 23,
	TUTORIAL_NAMES = 24,
	RUMORS_NAMES = 25,
	PROPOSITION_NAMES = 26,
	UNEXPLORED_LANDS = 27,
	TREASURE = 28,
	RECORD = 29,
	PERSON = 30,
	PROPOSITION_OBJECTIVES = 31,
	}

var battle_bin_text_offsets: PackedInt32Array = []
var battle_bin_text_end: int = 0xfee64
enum BATTLE_BIN_TEXT_SECTIONS {
	EVENT_TEXT = 0,
	BATTLE_ACTION_DENIED = 2,
	BATTLE_ACTION_EFFECT = 3,
	JOB_NAMES = 6,
	ITEM_NAMES = 7,
	UNIT_NAMES = 8,
	MISC_MENU = 10,
	ROSTER_UNIT_NICKNAMES = 11,
	ABILITY_NAMES = 14,
	BATTLE_NAVIGATION_MESSAGES = 16,
	STATUSES_NAMES = 17,
	FORMATION_TEXT = 18,
	SKILLSET_NAMES = 22,
	SUMMON_DRAW_OUT_NAMES = 23,
	}


#func _init() -> void:
	#pass


func on_load_rom_dialog_file_selected(path: String) -> void:
	var start_time: int = Time.get_ticks_msec()
	rom = FileAccess.get_file_as_bytes(path)
	push_warning("Time to load file (ms): " + str(Time.get_ticks_msec() - start_time))
	
	process_rom()


func clear_data() -> void:
	file_records.clear()
	lba_to_file_name.clear()
	sprs.clear()
	spr_file_name_to_id.clear()
	shps.clear()
	seqs.clear()
	maps.clear()
	effects.clear()
	abilities.clear()


func process_rom() -> void:
	clear_data()
	
	var start_time: int = Time.get_ticks_msec()
	
	# http://wiki.osdev.org/ISO_9660#Directories
	process_file_records(DIRECTORY_DATA_SECTORS_ROOT)
	
	push_warning("Time to process ROM (ms): " + str(Time.get_ticks_msec() - start_time))
	
	_load_battle_bin_sprite_data()
	cache_associated_files()
	fft_text.init_text()
	
	is_ready = true
	rom_loaded.emit()


func process_file_records(sectors: PackedInt32Array) -> void:
	for sector: int in sectors:
		var offset_start: int = 0
		if sector == sectors[0]:
			offset_start = OFFSET_RECORD_DATA_START
		var directory_start: int = sector * BYTES_PER_SECTOR
		var directory_data: PackedByteArray = rom.slice(directory_start + BYTES_PER_SECTOR_HEADER, directory_start + DATA_BYTES_PER_SECTOR + BYTES_PER_SECTOR_HEADER)
		
		var byte_index: int = offset_start
		while byte_index < DATA_BYTES_PER_SECTOR:
			var record_length: int = directory_data.decode_u8(byte_index)
			var record_data: PackedByteArray = directory_data.slice(byte_index, byte_index + record_length)
			var record: FileRecord = FileRecord.new(record_data)
			record.record_location_sector = sector
			record.record_location_offset = byte_index
			file_records[record.name] = record
			lba_to_file_name[record.sector_location] = record.name
			
			var file_extension: String = record.name.get_extension()
			if file_extension == "": # folder
				#push_warning("Getting files from folder: " + record.name)
				var data_length_sectors: int = ceil(float(record.size) / DATA_BYTES_PER_SECTOR)
				var directory_sectors: PackedInt32Array = range(record.sector_location, record.sector_location + data_length_sectors)
				process_file_records(directory_sectors)
			elif file_extension == "SPR":
				record.type_index = sprs.size()
				sprs.append(Spr.new(record.name))
			elif file_extension == "SHP":
				record.type_index = shps.size()
				shps.append(Shp.new(record.name))
			elif file_extension == "SEQ":
				record.type_index = seqs.size()
				seqs.append(Seq.new(record.name))
			elif file_extension == "GNS":
				record.type_index = maps.size()
				maps.append(MapData.new(record.name))
			
			byte_index += record_length
			if directory_data.decode_u8(byte_index) == 0: # end of data, rest of sector will be padded with zeros
				break


func cache_associated_files() -> void:
	var associated_file_names: PackedStringArray = [
		"WEP1.SEQ",
		"WEP2.SEQ",
		"EFF1.SEQ",
		"WEP1.SHP",
		"WEP2.SHP",
		"EFF1.SHP",
		"WEP.SPR",
		]
	
	for file_name: String in associated_file_names:
		var type_index: int = file_records[file_name].type_index
		match file_name.get_extension():
			"SPR":
				var spr: Spr = sprs[type_index]
				spr.set_data(get_file_data(file_name))
				if file_name != "WEP.SPR":
					spr.set_spritesheet_data(spr_file_name_to_id[file_name])
			"SHP":
				var shp: Shp = shps[type_index]
				shp.set_data_from_shp_bytes(get_file_data(file_name))
			"SEQ":
				var seq: Seq = seqs[type_index]
				seq.set_data_from_seq_bytes(get_file_data(file_name))
	
	# getting effect / weapon trail / glint
	var eff_spr_name: String = "EFF.SPR"
	var eff_spr: Spr = Spr.new(eff_spr_name)
	eff_spr.height = 144
	var eff_spr_record: FileRecord = FileRecord.new()
	eff_spr_record.name = eff_spr_name
	eff_spr_record.type_index = sprs.size()
	file_records[eff_spr_name] = eff_spr_record
	eff_spr.set_data(get_file_data("WEP.SPR").slice(0x8200, 0x10400))
	eff_spr.shp_name = "EFF1.SHP"
	eff_spr.seq_name = "EFF1.SEQ"
	sprs.append(eff_spr)
	
	# TODO get trap effects - not useful for this tool at this time
	
	# crop wep spr
	var wep_spr_start: int = 0
	var wep_spr_end: int = 256 * 256 # wep is 256 pixels tall
	var wep_spr_index: int = file_records["WEP.SPR"].type_index
	var wep_spr: Spr = sprs[wep_spr_index].get_sub_spr("WEP.SPR", wep_spr_start, wep_spr_end)
	wep_spr.shp_name = "WEP1.SHP"
	wep_spr.seq_name = "WEP1.SEQ"
	sprs[wep_spr_index] = wep_spr
	
	# get shp for item graphics
	var item_shp_name: String = "ITEM.SHP"
	var item_shp_record: FileRecord = FileRecord.new()
	item_shp_record.name = item_shp_name
	item_shp_record.type_index = shps.size()
	file_records[item_shp_name] = item_shp_record
	var item_shp: Shp = Shp.new(item_shp_name)
	item_shp.set_frames_from_csv(item_frames_csv_filepath)
	shps.append(item_shp)
	
	# get item graphics
	# TODO set type_index
	var item_record: FileRecord = FileRecord.new()
	item_record.sector_location = 6297 # ITEM.BIN is in EVENT not BATTLE, so needs a new record created
	item_record.size = 33280
	item_record.name = "ITEM.BIN"
	item_record.type_index = sprs.size()
	file_records[item_record.name] = item_record
	
	var item_spr_data: PackedByteArray = RomReader.get_file_data(item_record.name)
	var item_spr: Spr = Spr.new(item_record.name)
	item_spr.height = 256
	item_spr.set_palette_data(item_spr_data.slice(0x8000, 0x8200))
	item_spr.color_indices = item_spr.set_color_indices(item_spr_data.slice(0, 0x8000))
	item_spr.set_pixel_colors()
	item_spr.spritesheet = item_spr.get_rgba8_image()
	sprs.append(item_spr)


# https://ffhacktics.com/wiki/BATTLE.BIN_Data_Tables#Animation_.26_Display_Related_Data
func _load_battle_bin_sprite_data() -> void:
	# get BATTLE.BIN file data
	# get item graphics
	var battle_bin_record: FileRecord = FileRecord.new()
	battle_bin_record.sector_location = 1000 # ITEM.BIN is in EVENT not BATTLE, so needs a new record created
	battle_bin_record.size = 1397096
	battle_bin_record.name = "BATTLE.BIN"
	file_records[battle_bin_record.name] = battle_bin_record
	
	# look up spr file_name based on LBA
	var spritesheet_file_data_length: int = 8
	var battle_bin_bytes: PackedByteArray = file_records["BATTLE.BIN"].get_file_data(rom)
	for sprite_id: int in range(0, 0x9f):
		var spritesheet_file_data_start: int = 0x2dcd4 + (sprite_id * spritesheet_file_data_length)
		var spritesheet_file_data_bytes: PackedByteArray = battle_bin_bytes.slice(spritesheet_file_data_start, spritesheet_file_data_start + spritesheet_file_data_length)
		var spritesheet_lba: int = spritesheet_file_data_bytes.decode_u32(0)
		var spritesheet_file_name: String = ""
		if spritesheet_lba != 0:
			spritesheet_file_name = lba_to_file_name[spritesheet_lba]
		spr_file_name_to_id[spritesheet_file_name] = sprite_id


func get_file_data(file_name: String) -> PackedByteArray:
	var file_data: PackedByteArray = []
	var sector_location: int = file_records[file_name].sector_location
	var file_size: int = file_records[file_name].size
	var file_data_start: int = (sector_location * BYTES_PER_SECTOR) + BYTES_PER_SECTOR_HEADER
	var num_sectors_full: int = floor(file_size / float(DATA_BYTES_PER_SECTOR))
	
	for sector_index: int in num_sectors_full:
		var sector_data_start: int = file_data_start + (sector_index * BYTES_PER_SECTOR)
		var sector_data_end: int = sector_data_start + DATA_BYTES_PER_SECTOR
		var sector_data: PackedByteArray = rom.slice(sector_data_start, sector_data_end)
		file_data.append_array(sector_data)
	
	# add data from last sector
	var last_sector_data_start: int = file_data_start + (num_sectors_full * BYTES_PER_SECTOR)
	var last_sector_data_end: int = last_sector_data_start + (file_size % DATA_BYTES_PER_SECTOR)
	var last_sector_data: PackedByteArray = rom.slice(last_sector_data_start, last_sector_data_end)
	file_data.append_array(last_sector_data)
	
	return file_data
