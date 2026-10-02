extends Node
## Strumento di cattura schermate del gioco REALE (non dei mockup): avviare con un display (anche virtuale, Xvfb)
##   godot --rendering-driver opengl3 res://tools/capture.tscn
## Salva i PNG in docs/screens/. Non modifica il salvataggio del giocatore (SaveManager disattivato).

const OUT := "res://docs/screens/"
var driver: Node


func _ready() -> void:
	SaveManager.enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	driver = Node.new()
	driver.set_script(load("res://tools/capture_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
