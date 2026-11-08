extends Node
## Boot splash: installs the global theme and hands over to the main menu.


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0b1220"))
	get_tree().root.theme = UIKit.theme()
	await get_tree().process_frame
	await get_tree().process_frame
	SceneManager.change_scene("res://scenes/MainMenu.tscn", 0.2)