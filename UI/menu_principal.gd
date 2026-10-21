extends Control

# ==========================================
# --- REFERÊNCIAS DE NODES (UI E ÁUDIO) ---
# ==========================================
@onready var painel_controles: Panel = $PainelControles
@onready var som_clique: AudioStreamPlayer = $SomClique 


# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	# Inicializa o menu garantindo que o painel de controles esteja oculto para não sobrepor os botões
	painel_controles.visible = false


# ==========================================
# --- AÇÕES DOS BOTÕES (SINAIS DA UI) ---
# ==========================================

func _on_botao_jogar_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# ==========================================
	# --- RESET DE PROGRESSO (NOVA PARTIDA) ---
	# Garante que o jogador comece do zero limpando os AutoLoads de economia e controle de clientes
	# ==========================================
	EconomyManager.resetar_economia()
	CustomerManager.resetar_clientes()
	
	# Aguarda a finalização do áudio de clique antes de transitar para a cena do jogo (evita corte seco no som)
	await som_clique.finished
		
	get_tree().change_scene_to_file("res://Levels/game_level.tscn")


func _on_botao_controles_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# Inverte a visibilidade: se o painel estiver fechado, ele abre. Se já estiver aberto, ele fecha!
	painel_controles.visible = not painel_controles.visible


func _on_botao_voltar_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# Oculta o painel de controles, retornando à visualização principal do menu
	painel_controles.visible = false


func _on_botao_sair_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# Encerra a execução e fecha o jogo de forma segura
	get_tree().quit()
