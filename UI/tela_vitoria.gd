extends CanvasLayer
class_name TelaVitoria

@onready var titulo: Label = $PanelContainer/VBoxContainer/Titulo
@onready var subtitulo: Label = $PanelContainer/VBoxContainer/Subtitulo
@onready var btn_infinito: Button = $PanelContainer/VBoxContainer/HBoxContainer/BotaoInfinito
@onready var btn_menu: Button = $PanelContainer/VBoxContainer/HBoxContainer/BotaoMenu
@onready var som_clique: AudioStreamPlayer = $SomClique
@onready var som_vitoria: AudioStreamPlayer = get_node_or_null("SomVitoria") as AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parar_musicas_fase()
	get_tree().paused = true

	if som_vitoria and not som_vitoria.playing:
		som_vitoria.play()

	titulo.text = "PARABÉNS! MESTRE DA GEOMETRIA!"
	subtitulo.text = "Você dominou todos os setores do GeoRush!\nClientes atendidos: %d | Dinheiro: $%.2f" % [
		EconomyManager.clientes_totais_atendidos,
		EconomyManager.dinheiro
	]

	btn_infinito.pressed.connect(_on_continuar_infinito)
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


func _tocar_musica_fundo() -> void:
	var nos: Array[Node] = get_tree().get_nodes_in_group("musica_fundo")
	if not nos.is_empty():
		get_tree().call_group("musica_fundo", "play")
		return

	var cena: Node = get_tree().current_scene
	if cena:
		var player: AudioStreamPlayer = cena.find_child("MusicaFundo", true, false) as AudioStreamPlayer
		if player:
			player.play()


func _on_continuar_infinito() -> void:
	btn_infinito.disabled = true
	btn_menu.disabled = true
	if som_vitoria and som_vitoria.playing:
		som_vitoria.stop()
	if som_clique:
		som_clique.play()
		await som_clique.finished
	EconomyManager.modo_infinito = true
	get_tree().paused = false
	_tocar_musica_fundo()
	queue_free()


func _on_menu_principal() -> void:
	btn_infinito.disabled = true
	btn_menu.disabled = true
	if som_vitoria and som_vitoria.playing:
		som_vitoria.stop()
	if som_clique:
		som_clique.play()
		await som_clique.finished
	EconomyManager.resetar_economia()
	CustomerManager.resetar_clientes()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menu_principal.tscn")
