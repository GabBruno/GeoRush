extends CanvasLayer
class_name TelaVitoria

@onready var titulo: Label = $PanelContainer/VBoxContainer/Titulo
@onready var subtitulo: Label = $PanelContainer/VBoxContainer/Subtitulo
@onready var btn_infinito: Button = $PanelContainer/VBoxContainer/BotaoInfinito
@onready var btn_menu: Button = $PanelContainer/VBoxContainer/BotaoMenu
@onready var som_clique: AudioStreamPlayer = $SomClique

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	titulo.text = "PARABÉNS! MESTRE DA GEOMETRIA!"
	subtitulo.text = "Você dominou todos os setores do GeoRush!\nClientes atendidos: %d | Dinheiro: $%.2f" % [
		EconomyManager.clientes_totais_atendidos,
		EconomyManager.dinheiro
	]
	
	btn_infinito.pressed.connect(_on_continuar_infinito)
	btn_menu.pressed.connect(_on_menu_principal)

func _on_continuar_infinito() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
	EconomyManager.modo_infinito = true
	get_tree().paused = false
	queue_free()

func _on_menu_principal() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menu_principal.tscn")
