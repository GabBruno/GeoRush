extends Control

# ==========================================
# --- REFERÊNCIAS DE NODES (UI E ÁUDIO) ---
# ==========================================
@onready var painel_controles: Panel = $PainelControles
@onready var painel_configuracoes: Control = $PainelConfiguracoes
@onready var som_clique: AudioStreamPlayer = $SomClique


# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	# Garante que ambos os painéis laterais comecem fechados
	painel_controles.visible = false
	painel_configuracoes.visible = false


# ==========================================
# --- CONTROLE DE ABAS LATERAIS ---
# Fecha qualquer painel aberto antes de abrir o painel escolhido
# ==========================================
func _alternar_painel(painel_alvo: Control) -> void:
	var vai_abrir := not painel_alvo.visible
	painel_controles.visible = false
	painel_configuracoes.visible = false
	painel_alvo.visible = vai_abrir


# ==========================================
# --- AÇÕES DOS BOTÕES (SINAIS DA UI) ---
# ==========================================
func _on_botao_jogar_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	EconomyManager.resetar_economia()
	CustomerManager.resetar_clientes()
	
	await som_clique.finished
	get_tree().change_scene_to_file("res://Levels/game_level.tscn")


func _on_botao_controles_pressed() -> void:
	if som_clique:
		som_clique.play()
	_alternar_painel(painel_controles)


func _on_botao_configuracoes_pressed() -> void:
	if som_clique:
		som_clique.play()
	_alternar_painel(painel_configuracoes)


func _on_botao_voltar_pressed() -> void:
	if som_clique:
		som_clique.play()
	painel_controles.visible = false
	painel_configuracoes.visible = false


func _on_botao_sair_pressed() -> void:
	if som_clique:
		som_clique.play()
	get_tree().quit()
