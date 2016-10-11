# ==== Pepper & Carrot Game ====
#
# Purpose: Manages game state and configuration files, and loading of stuff
#
# ==============================

extends Node

var current_scene = null

const INPUT_ACTIONS = ["ui_accept", "jump", "up", "down", "left", "right"]

var player = null

# Display
var width = 1280 # Display width
var height = 720 # Display height
var fullscreen = false # Whether we run in fullscreen or not


# Audio
var music = true # Should the music play
var music_volume = 1 # Volume of the music, between 0 and 1
var sfx = true # Should sound effects play
var sfx_volume = 1 # Volume of sound effects, between 0 and 1


var character_info = load("res://Scripts/character_info.gd")
var battle_set = load("res://Scripts/Battle/battle_set.gd")
const settings_filename = "user://config.cfg"

var PLAYER_SCENE = preload("res://Scenes/Player/player.tscn")
var DEBUG = null

var game_states = preload("res://Scripts/game_states.gd")
var state_machine
var player_data
var ui_layer

# Class of a character saved to file
class CharacterSave:
	var level
	var internal_name
	var stats
	func _init(character):
    	self.level = character.level
    	self.internal_name = character.internal_name
	func to_dict():
		var save_dict ={
			level = self.level,
			internal_name = self.internal_name
		}
		return save_dict
	static func get_full_character_from_dict(dict):
		var character_info = load("res://Scripts/character_info.gd")
		var charinfo = character_info.CharacterInfo.new()
		charinfo.load_from_file(dict["internal_name"])
		charinfo.level_up(dict["level"]-1)
		return charinfo

# Contains run-time information about the player
class PlayerData:
	var characters = {}
	var selected_characters = {"first": null, "second": null}
	func load_defaults():
		# Loads the defaults for the player data, gathered at the start of savefile creation.
		var character_info = load("res://Scripts/character_info.gd")
		characters["pepper"] = character_info.CharacterInfo.new()
		characters["pepper"].load_from_file("pepper")
		selected_characters["first"] = "pepper"
	func to_dict():
		var characters_dict = {}
		for character_name in characters:
			characters_dict[character_name] = CharacterSave.new(characters[character_name]).to_dict()
		var save_dict = {
			characters = characters_dict,
			selected_characters = selected_characters
		}
		return save_dict
	static func get_full_player_data_from_dict(dict):
		# Grabs a CharacterSave based dictionary and returns a full character.
		var playerinfo  = new()
		var characters = dict["characters"]
		for key in characters:
			var character = characters[key]
			characters[key] = CharacterSave.get_full_character_from_dict(character)
		playerinfo.characters = characters
		playerinfo.selected_characters = dict["selected_characters"]
		return playerinfo
		
func _process(delta):
	if(DEBUG):
		OS.set_window_title("PCGTRPG DEBUG " + str(OS.get_frames_per_second()))
func _ready():
	set_pause_mode(PAUSE_MODE_PROCESS)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	# Load default player data in startup
	player_data = PlayerData.new()
	player_data.load_defaults()

	DEBUG = OS.is_debug_build()

	current_scene = get_tree().get_current_scene()
	

	# This avoids the singleton from loading the menu scene on load when loading in debug mode, but it allows
	# loading the menu scene if the scene currently being loaded is the base scene (which should be the default)
	if DEBUG and get_tree().get_current_scene().get_filename() == "res://Scenes/base_scene.xscn":
		change_scene("res://Scenes/main_menu.xscn")
	elif DEBUG:
		change_scene(get_tree().get_current_scene().get_filename())
	# Load parameters from the config file, overriding the default ones
	load_config()
	
	# Handle display
	OS.set_window_size(Vector2(width, height))
	OS.set_window_fullscreen(fullscreen)
	
	# Save window size if changed by the user
	get_tree().connect("screen_resized", self, "save_screen_size")
	"""var save_manager = get_node("/root/save_manager")
	var battle_manager = get_node("/root/battle_manager")
	var BattleSet = load("res://Scripts/Battle/battle_set.gd")
	var battle_set = BattleSet.from_file("res://Stats/BattleSets/demo/demo_battleset.json")
	
	print("battle_set")
	battle_manager.start_battle(battle_set)"""
	
	# Load player state

	set_process(true)
	var machine = load("res://Scripts/state_machine.gd")
	state_machine = machine.new()
	add_child(state_machine)
	state_machine.add_state(game_states.InGameState)
	state_machine.change_state("ingame")
	

	#save_manager.save_game("test")
	#save_manager.load_game("test")
	randomize()
func change_scene_door(path, door_number):
	change_scene(path, false)
	spawn_player(door_number)

func spawn_player(door_number=-1):
	var doors = get_tree().get_nodes_in_group("doors")
	if door_number != -1:
		for door in doors:
			if door.door_number == door_number:
				var player_instance = PLAYER_SCENE.instance()
				get_tree().get_current_scene().add_child(player_instance)
				player_instance.set_global_pos(door.get_global_pos())
				print("Player spawned on door: " + str(door_number))
				return
	var player_spawn = get_tree().get_nodes_in_group("player_start")
	if player_spawn.size() > 0:
		var player_instance = PLAYER_SCENE.instance()
		player_instance.set_pos(player_spawn[0].get_pos())
		game_manager.current_scene.add_child(player_instance)
		print("Player spawned")
	else:
		print("found no spawn")

func change_scene(path, callback_object=null ,callback = null, no_free = false):
	# Make sure there's no scene code running to avoid crashes
	call_deferred("change_scene_impl", path, callback_object, callback, no_free)
	
func change_to_packed_scene_impl(packed_scene):
	# Make sure there's no scene code running to avoid crashes
	call_deferred("change_to_packed_scene_impl", packed_scene)

func set_player(new_player):
	player=new_player

func get_player():
	return player

# Actual implementation of change_scene
func change_scene_impl(path, callback_object=null, callback = null, no_free = false):
	var tree_root = get_tree().get_root()
		
	if current_scene:
		if not no_free:
			current_scene.free()
	var scene = ResourceLoader.load(path)
	current_scene = scene.instance()
	tree_root.add_child(current_scene)
	
	print("Loaded scene: ", path)
	
	if callback:
		callback_object.call(callback, current_scene)
	
	spawn_player(-1)


func change_to_packed_scene(packed_scene):
	var tree_root = get_tree().get_root()
	if current_scene and packed_scene:
		current_scene.free()
		#Create an instance from the packed scene
		current_scene = packed_scene.instance()
		
		tree_root.add_child(current_scene)
		

func load_config():
	"""Load the user-defined settings from the default settings file. Create this file
	if it is missing and populate it with default values as defined in this class.
	"""
	var config = ConfigFile.new()
	var err = config.load(settings_filename)
	if err:
		# Config file does not exist, dump default settings in it
		
		# Are any other forms of error handling needed here? if the
		# config file is invalid it just gets overriden with default
		# values
		
		# Display
		config.set_value("display", "width", width)
		config.set_value("display", "height", height)
		config.set_value("display", "fullscreen", fullscreen)
		
		# Audio
		config.set_value("audio", "music", music)
		config.set_value("audio", "music_volume", music_volume)
		config.set_value("audio", "sfx", sfx)
		config.set_value("audio", "sfx_volume", sfx_volume)
		
		# Default inputs
		var action_name
		for i in range(1, 5):
			for action_name in INPUT_ACTIONS:
				config.set_value("input", action_name, OS.get_scancode_string(InputMap.get_action_list(action_name)[0].scancode))
		
		config.save(settings_filename)
	else:
		# Display
		set_from_cfg(config, "display", "width")
		set_from_cfg(config, "display", "height")
		set_from_cfg(config, "display", "fullscreen")
		
		# Audio
		set_from_cfg(config, "audio", "music")
		set_from_cfg(config, "audio", "music_volume")
		set_from_cfg(config, "audio", "sfx")
		set_from_cfg(config, "audio", "sfx_volume")
		
		# Input overrides
		var scancode
		var event
		for action in config.get_section_keys("input"):
			# Get the key scancode corresponding to the saved human-readable string
			scancode = OS.find_scancode_from_string(config.get_value("input", action))
			# Create a new event object based on the saved scancode
			event = InputEvent()
			event.type = InputEvent.KEY
			event.scancode = scancode
			# Replace old actions by the new one - apparently erasing the old action
			# works better to get the control buttons properly initialised in the UI
			# TODO: Handle multiple events per action in a better way
			for old_event in InputMap.get_action_list(action):
				if old_event.type != InputEvent.JOYSTICK_BUTTON:
					InputMap.action_erase_event(action, old_event)
			InputMap.action_add_event(action, event)
			
func set_from_cfg(config, section, key):
	"""Retrieve the parameter from the config file, or restore it
	if it is missing from the config file.
	"""
	if config.has_section_key(section, key):
		set(key, config.get_value(section, key))
	else:
		print("Warning: '" + key + "' missing from '" + section + "' section in the config file, default value has been added.")
		save_to_config(section, key, get(key))

func save_to_config(section, key, value):
	var config = ConfigFile.new()
	var error = config.load(settings_filename)
	if error:
		# TODO: Better error handling
		print("Error loading config: ", error)
	else:
		config.set_value(section, key, value)
		config.save(settings_filename)

func save_screen_size():
	"""
	var screen_size = OS.get_window_size()
	width = int(screen_size.x)
	height = int(screen_size.y)
	save_to_config("display", "width", width)
	save_to_config("display", "height", height)
	"""
	# TODO: FIX THIS
	pass
	
