extends CanvasLayer
class_name MenuPausa

# ==========================================
# --- REFERÊNCIAS DE NODES (UI E ÁUDIO) ---
# ==========================================
@export_category("Referências de Nodes")
@onready var painel_pausa: Control = $PainelPausa
@onready var som_clique: AudioStreamPlayer = $PainelPausa/SomClique
@onready var painel_controles: Panel = $PainelPausa/PainelControles
@onready var painel_configuracoes: Control = $PainelPausa/PainelConfiguracoes


# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	painel_pausa.visible = false
	painel_controles.visible = false
	painel_configuracoes.visible = false
	self.process_mode = Node.PROCESS_MODE_ALWAYS


# ==========================================
# --- CONTROLE DE INPUT ---
# ==========================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		# Se a loja de upgrades estiver aberta, o Esc fecha apenas a loja e não pausa o jogo
		var loja = get_tree().get_first_node_in_group("loja_upgrades")
		if loja and loja._loja_aberta:
			loja.fechar_loja()
			get_viewport().set_input_as_handled()
			return
			
		alternar_pausa()

# ==========================================
# --- LÓGICA PRINCIPAL DE PAUSA ---
# ==========================================
func alternar_pausa() -> void:
	var novo_estado_pausa = not get_tree().paused
	
	get_tree().paused = novo_estado_pausa
	painel_pausa.visible = novo_estado_pausa
	
	# Ao sair da pausa, fecha os painéis laterais para o menu abrir limpo na próxima vez
	if not novo_estado_pausa:
		painel_controles.visible = false
		painel_configuracoes.visible = false


# ==========================================
# --- CONTROLE DE ABAS LATERAIS ---
# ==========================================
func _alternar_painel(painel_alvo: Control) -> void:
	var vai_abrir := not painel_alvo.visible
	painel_controles.visible = false
	painel_configuracoes.visible = false
	painel_alvo.visible = vai_abrir


# ==========================================
# --- AÇÕES DOS BOTÕES (SINAIS DA UI) ---
# ==========================================
func _on_botao_continuar_pressed() -> void:
	if som_clique:
		som_clique.play()
	alternar_pausa()


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


func _on_botao_menu_principal_pressed() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
		
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menu_principal.tscn")


func _on_botao_sair_pressed() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
		
	get_tree().quit()
