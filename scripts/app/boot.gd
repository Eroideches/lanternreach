extends Control
## Prima scena del gioco: schermo nero con la scritta bianca "EroideGames" centrata.
## Durata TOTALE 2 s, dissolvenze incluse: 0,4 s in entrata + 1,2 s fissa + 0,4 s in uscita.
## Poi lo splash di Lanternreach (scenes/main.tscn), che carica il salvataggio e apre villaggio o tutorial.
## Lo splash del motore e' nero e senza immagine (project.godot: boot_splash/show_image=false), quindi la
## sequenza all'avvio e': nero -> "EroideGames" (2 s) -> splash Lanternreach -> gioco.

const TOTAL := 2.0
const FADE := 0.4
const STUDIO := "EroideGames"
const NEXT_SCENE := "res://scenes/main.tscn"

var label: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	label = Label.new()
	label.text = STUDIO
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UIK.body_font())
	label.add_theme_font_size_override("font_size", 120)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate.a = 0.0
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, FADE)
	tw.tween_interval(TOTAL - 2.0 * FADE)
	tw.tween_property(label, "modulate:a", 0.0, FADE)
	tw.tween_callback(_next)


func _next() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
