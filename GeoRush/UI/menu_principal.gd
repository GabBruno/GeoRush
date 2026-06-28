extends Control

# --- Referências de Nodes ---
@onready var painel_controles: Panel = $PainelControles
@onready var som_clique: AudioStreamPlayer = $SomClique 

func _ready() -> void:
	# Inicializa o menu garantindo que o painel de controles esteja oculto
	painel_controles.visible = false

# ==========================================
# --- Ações dos Botões ---
# ==========================================

func _on_botao_jogar_pressed() -> void:
	if som_clique:
		som_clique.play()
		# Aguarda a finalização do áudio de clique antes de transitar para a cena do jogo
		await som_clique.finished
		
	get_tree().change_scene_to_file("res://Levels/game_level.tscn")

func _on_botao_controles_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# Sobrepõe o painel de instruções/controles na interface
	painel_controles.visible = true

func _on_botao_voltar_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# Oculta o painel de controles, retornando à visualização principal do menu
	painel_controles.visible = false

func _on_botao_sair_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# Encerra a execução e fecha o jogo
	get_tree().quit()
