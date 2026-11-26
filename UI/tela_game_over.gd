extends CanvasLayer
class_name TelaGameOver

@onready var titulo: Label = $PanelContainer/VBoxContainer/Titulo
@onready var subtitulo: Label = $PanelContainer/VBoxContainer/Subtitulo
@onready var btn_tentar: Button = $PanelContainer/VBoxContainer/HBoxContainer/BotaoTentarNovamente
@onready var btn_menu: Button = $PanelContainer/VBoxContainer/HBoxContainer/BotaoMenu
@onready var som_clique: AudioStreamPlayer = $SomClique
@onready var som_derrota: AudioStreamPlayer = get_node_or_null("SomDerrota") as AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parar_musicas_fase()
	get_tree().paused = true

	if som_derrota and not som_derrota.playing:
		som_derrota.play()

	titulo.text = "LOJA FECHADA!"
	subtitulo.text = "Sua reputação chegou a zero.\nDinheiro acumulado: $%.2f" % EconomyManager.dinheiro

	btn_tentar.pressed.connect(_on_tentar_novamente)
	btn_menu.pressed.connect(_on_menu_principal)


func _parar_musicas_fase() -> void:
	get_tree().call_group("musica_fase", "stop")
	get_tree().call_group("musica_fundo", "stop")
	get_tree().call_group("musica_boss", "stop")

	var cena: Node = get_tree().current_scene
	if cena:
		for nome in ["MusicaFundo", "MusicaBoss", "MusicaNormal"]:
			var player: AudioStreamPlayer = cena.find_child(nome, true, false) as AudioStreamPlayer
			if player and player.playing:
				player.stop()


func _on_tentar_novamente() -> void:
	btn_tentar.disabled = true
	btn_menu.disabled = true
	if som_derrota and som_derrota.playing:
		som_derrota.stop()
	if som_clique:
		som_clique.play()
		await som_clique.finished
	EconomyManager.resetar_economia()
	CustomerManager.resetar_clientes()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Levels/game_level.tscn")


func _on_menu_principal() -> void:
	btn_tentar.disabled = true
	btn_menu.disabled = true
	if som_derrota and som_derrota.playing:
		som_derrota.stop()
	if som_clique:
		som_clique.play()
		await som_clique.finished
	EconomyManager.resetar_economia()
	CustomerManager.resetar_clientes()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menu_principal.tscn")
