extends CanvasLayer
class_name TelaGameOver

@onready var titulo: Label = $PanelContainer/VBoxContainer/Titulo
@onready var subtitulo: Label = $PanelContainer/VBoxContainer/Subtitulo
@onready var btn_tentar: Button = $PanelContainer/VBoxContainer/HBoxContainer/BotaoTentarNovamente
@onready var btn_menu: Button = $PanelContainer/VBoxContainer/HBoxContainer/BotaoMenu
@onready var som_clique: AudioStreamPlayer = $SomClique

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	titulo.text = "LOJA FECHADA!"
	subtitulo.text = "Sua reputação chegou a zero.\nDinheiro acumulado: $%.2f" % EconomyManager.dinheiro
	
	btn_tentar.pressed.connect(_on_tentar_novamente)
	btn_menu.pressed.connect(_on_menu_principal)

func _on_tentar_novamente() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
	EconomyManager.resetar_economia()
	CustomerManager.resetar_clientes()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Levels/game_level.tscn")

func _on_menu_principal() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menu_principal.tscn")
