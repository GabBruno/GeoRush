extends CanvasLayer
class_name MenuPausa

# ==========================================
# --- REFERÊNCIAS DE NODES (UI E ÁUDIO) ---
# ==========================================
@export_category("Referências de Nodes")
@onready var painel_pausa: Control = $PainelPausa
@onready var som_clique: AudioStreamPlayer = $PainelPausa/SomClique
@onready var painel_controles: Panel = $PainelPausa/PainelControles


# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	# Garante que o menu de pausa comece sempre oculto ao carregar a fase
	painel_pausa.visible = false
	
	# Define o modo de processamento para 'Always' (Sempre), garantindo que
	# este menu e o áudio continuem rodando mesmo quando a SceneTree for pausada.
	self.process_mode = Node.PROCESS_MODE_ALWAYS


# ==========================================
# --- CONTROLE DE INPUT ---
# ==========================================
func _input(event: InputEvent) -> void:
	# Escuta a ação configurada (ex: Tecla 'Esc') para abrir e fechar o menu
	if event.is_action_pressed("menu"):
		alternar_pausa()


# ==========================================
# --- LÓGICA PRINCIPAL DE PAUSA ---
# ==========================================
func alternar_pausa() -> void:
	"""
	Alterna o estado de execução da árvore principal (SceneTree)
	e exibe ou oculta a interface do menu de pausa.
	"""
	# Inverte o estado atual (se estiver pausado, despausa; se não, pausa)
	var novo_estado_pausa = not get_tree().paused
	
	get_tree().paused = novo_estado_pausa
	painel_pausa.visible = novo_estado_pausa


# ==========================================
# --- AÇÕES DOS BOTÕES (SINAIS DA UI) ---
# ==========================================

func _on_botao_continuar_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# Reutiliza a função principal para remover a pausa e esconder a tela
	alternar_pausa()
	

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


func _on_botao_menu_principal_pressed() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
		
	# Remove a pausa antes de trocar de cena para evitar travamentos no novo menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menu_principal.tscn")


func _on_botao_sair_pressed() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
		
	# Encerra o jogo
	get_tree().quit()
