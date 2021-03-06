# ==== Pepper & Carrot Game ====
#
# Purpose: Triggers dialogues in the world said by the player
#
# ==============================
extends Node2D

var _scene_manager

# Should be a bunch of dialogues put together hierarchically
export(NodePath) var first_dialogue
export(String, "close_up", "floating") var dialogue_type = "floating"

var dialogue

func _ready():
	_scene_manager = get_node("/root/scene_manager")
	dialogue = get_node(first_dialogue)


func _on_Area2D_body_enter( body ):
	game_manager = get_node("/root/game_manager")
	if _scene_manager.get_player() == body:
		if dialogue_type == "floating":
			dialogue.get_parent().remove_child(dialogue)
			body.add_child(dialogue)
			dialogue.set_pos(Vector2(0,0))
			dialogue.set_pos(body.get_node("DialoguePosition").get_pos())
			dialogue.start()
		else:
			dialogue.start_dialog()