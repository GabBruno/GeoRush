extends CanvasLayer
class_name TutorialOverlay

# ==========================================
# --- ESTADOS DO TUTORIAL ---
# ==========================================
enum Passo {
	BOAS_VINDAS,
	IR_AO_CAIXA,
	COLETAR_PRODUTOS,
	ENTREGAR_NO_CAIXA,
	CONCLUIDO
}

var passo_atual: Passo = Passo.BOAS_VINDAS

# ==========================================
# --- REFERÊNCIAS DE NODES ---
# Certifique-se de que os nomes batem com a sua árvore de nós
# ==========================================
@onready var painel_dialogo: PanelContainer = $PainelDialogo
@onready var titulo_label: Label = $PainelDialogo/MarginContainer/VBoxContainer/TituloKratos
@onready var texto_fala: Label = $PainelDialogo/MarginContainer/VBoxContainer/TextoFala
@onready var botao_entendi: Button = $PainelDialogo/MarginContainer/VBoxContainer/BotaoEntendi

# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	# Se o jogador já concluiu o tutorial nesta sessão, remove a tela imediatamente
	if CustomerManager.tutorial_concluido:
		queue_free()
		return

	# Registra este nó no grupo "tutorial" automaticamente via código
	add_to_group("tutorial")

	# Conecta o clique do botão automaticamente via código
	botao_entendi.pressed.connect(_on_botao_entendi_pressed)

	_atualizar_interface()

# ==========================================
# --- CONTROLE DOS PASSOS ---
# ==========================================
func _atualizar_interface() -> void:
	match passo_atual:
		Passo.BOAS_VINDAS:
			titulo_label.text = "PRIMEIRO DIA DO KRATOS"
			texto_fala.text = "Bem-vindo ao GeoRush! Eu sou o Kratos e hoje é meu primeiro turno no mercado. Vamos atender o primeiro cliente juntos!"
			botao_entendi.text = "Vamos lá!"
			botao_entendi.visible = true

		Passo.IR_AO_CAIXA:
			titulo_label.text = "PASSO 1/3 — ATENDA NO CAIXA"
			texto_fala.text = "Aproxime-se do balcão do caixa (onde o cliente está esperando) e aperte [E] para receber o pedido."
			botao_entendi.visible = false
			botao_entendi.release_focus()

		Passo.COLETAR_PRODUTOS:
			titulo_label.text = "PASSO 2/3 — COLETE AS ESFERAS"
			texto_fala.text = "O pedido abriu na prancheta ([Tab] abre/fecha). Vá até a gôndola de Maçãs (Esferas) e aperte [E] duas vezes para pegar 2 Maçãs."
			botao_entendi.visible = false

		Passo.ENTREGAR_NO_CAIXA:
			titulo_label.text = "PASSO 3/3 — ENTREGUE O PEDIDO"
			texto_fala.text = "Perfeito! Você coletou as 2 Maçãs. Agora volte ao balcão do caixa e aperte [E] para finalizar a entrega."
			botao_entendi.visible = false

		Passo.CONCLUIDO:
			CustomerManager.tutorial_concluido = true
			titulo_label.text = "TURNO LIBERADO!"
			texto_fala.text = "Mandou bem! A partir de agora os pedidos têm tempo contado. Lembre-se: [R] devolve itens, [F] repõe estoque e fique de olho na sua reputação!"
			botao_entendi.text = "Começar!"
			botao_entendi.visible = true

# ==========================================
# --- SINAIS E EVENTOS EXTERNOS ---
# Chamados pelo CaixaCheckout e BaseCharacter via call_group("tutorial", ...)
# ==========================================
func _on_botao_entendi_pressed() -> void:
	if passo_atual == Passo.BOAS_VINDAS:
		passo_atual = Passo.IR_AO_CAIXA
		_atualizar_interface()
	elif passo_atual == Passo.CONCLUIDO:
		queue_free()

func avancar_passo(evento: String) -> void:
	match evento:
		"pegou_pedido":
			# Avança mesmo que o jogador tenha ido direto ao caixa antes de clicar "Vamos lá!"
			if passo_atual == Passo.BOAS_VINDAS or passo_atual == Passo.IR_AO_CAIXA:
				passo_atual = Passo.COLETAR_PRODUTOS
				_atualizar_interface()

		"entregou_pedido":
			if passo_atual == Passo.COLETAR_PRODUTOS or passo_atual == Passo.ENTREGAR_NO_CAIXA:
				passo_atual = Passo.CONCLUIDO
				_atualizar_interface()

func verificar_coleta(carrinho: Array[ProductData]) -> void:
	if passo_atual != Passo.COLETAR_PRODUTOS:
		return

	var qtd_corretos := 0
	var tem_item_errado := false

	for item in carrinho:
		if item.product_name.to_lower().strip_edges() == "maçã":
			qtd_corretos += 1
		else:
			tem_item_errado = true

	if tem_item_errado or qtd_corretos > 2:
		texto_fala.text = "Ops! Você pegou um item errado ou a mais. Encoste na prateleira dele e aperte [R] para devolver!"
	elif qtd_corretos == 2:
		passo_atual = Passo.ENTREGAR_NO_CAIXA
		_atualizar_interface()
	else:
		texto_fala.text = "Ótimo! Falta pegar mais " + str(2 - qtd_corretos) + " Maçã(s) na gôndola apertando [E]."
