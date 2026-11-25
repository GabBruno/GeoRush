extends Node

var _passaram: int = 0
var _falharam: int = 0


func _ready() -> void:
	print("=== Iniciando testes automatizados do GeoRush ===")
	_testar_reputacao_e_ritmo()
	_testar_avaliacao_carrinho()
	_testar_limite_visual_gondola()

	print("=== Resultado: %d passaram | %d falharam ===" % [_passaram, _falharam])
	get_tree().quit.call_deferred(1 if _falharam > 0 else 0)


func _assert_igual(atual: Variant, esperado: Variant, descricao: String) -> void:
	if atual == esperado:
		_passaram += 1
		print("[OK] ", descricao)
	else:
		_falharam += 1
		printerr("[FALHA] %s | esperado: %s | obtido: %s" % [descricao, str(esperado), str(atual)])


func _assert_aprox(atual: float, esperado: float, descricao: String) -> void:
	if is_equal_approx(atual, esperado):
		_passaram += 1
		print("[OK] ", descricao)
	else:
		_falharam += 1
		printerr("[FALHA] %s | esperado: %.2f | obtido: %.2f" % [descricao, esperado, atual])


func _testar_reputacao_e_ritmo() -> void:
	var eco: Node = get_tree().root.get_node_or_null("EconomyManager")
	if eco == null:
		_falharam += 1
		printerr("[FALHA] Autoload EconomyManager nao encontrado")
		return

	eco.reputacao = 50
	_assert_aprox(eco.obter_multiplicador_reputacao(), 1.25, "5 estrelas aplica multiplicador 1.25x")
	_assert_aprox(eco.obter_intervalo_spawn_clientes(), 4.2, "5 estrelas define spawn em 4.2s")

	eco.reputacao = 20
	_assert_aprox(eco.obter_multiplicador_reputacao(), 1.0, "3 estrelas aplica multiplicador 1.0x")
	_assert_aprox(eco.obter_multiplicador_paciencia(), 0.85, "3 estrelas aplica paciencia 0.85x")

	eco.reputacao = 10
	_assert_aprox(eco.obter_multiplicador_reputacao(), 0.75, "1-2 estrelas aplica multiplicador 0.75x")
	_assert_aprox(eco.obter_intervalo_spawn_clientes(), 10.0, "1-2 estrelas reduz spawn para 10.0s")


func _testar_avaliacao_carrinho() -> void:
	var cm: Node = get_tree().root.get_node_or_null("CustomerManager")
	if cm == null:
		_falharam += 1
		printerr("[FALHA] Autoload CustomerManager nao encontrado")
		return

	var maca := ProductData.new()
	maca.product_name = "Maçã"
	maca.shape = ProductData.ShapeType.ESFERA

	var leite := ProductData.new()
	leite.product_name = "Caixa de Leite"
	leite.shape = ProductData.ShapeType.PARALELEPIPEDO

	cm.pedido_atual = {maca: 2}
	cm.pedido_por_forma = {}

	var res_perfeito: Dictionary = cm.avaliar_carrinho([maca, maca])
	_assert_igual(res_perfeito["perfeito"], true, "Carrinho exato e aprovado como perfeito")
	_assert_igual(res_perfeito["erros"], 0, "Carrinho exato tem 0 erros")
	_assert_igual(res_perfeito["faltantes"], 0, "Carrinho exato tem 0 faltantes")

	var res_faltando: Dictionary = cm.avaliar_carrinho([maca])
	_assert_igual(res_faltando["perfeito"], false, "Carrinho incompleto e reprovado")
	_assert_igual(res_faltando["faltantes"], 1, "Carrinho incompleto registra 1 item faltante")

	var res_errado: Dictionary = cm.avaliar_carrinho([maca, maca, leite])
	_assert_igual(res_errado["perfeito"], false, "Carrinho com item extra/errado e reprovado")
	_assert_igual(res_errado["erros"], 1, "Carrinho com item extra registra 1 erro")

	cm.pedido_atual = {}
	cm.pedido_por_forma = {ProductData.ShapeType.ESFERA: 2}
	var res_forma: Dictionary = cm.avaliar_carrinho([maca, maca])
	_assert_igual(res_forma["perfeito"], true, "Pedido por forma aceita produtos da mesma geometria")


func _testar_limite_visual_gondola() -> void:
	var prateleira := BaseProducts.new()
	prateleira._max_visual_icons = 5
	prateleira.max_stock = 10

	prateleira._current_stock = 10
	_assert_igual(prateleira._calcular_icones_visiveis(), 5, "Estoque 10/10 limita visual a 5 icones")

	prateleira._current_stock = 1
	_assert_igual(prateleira._calcular_icones_visiveis(), 1, "Estoque 1/10 ainda exibe 1 icone")

	prateleira._current_stock = 0
	_assert_igual(prateleira._calcular_icones_visiveis(), 0, "Estoque 0/10 exibe 0 icones")

	# Regra de negocio: recusar incremento negativo ou zero no estoque maximo
	prateleira.max_stock = 5
	_assert_igual(prateleira.aumentar_estoque_maximo(-3), false, "Recusa incremento negativo no estoque maximo")
	_assert_igual(prateleira.max_stock, 5, "Estoque maximo permanece 5 apos incremento negativo")
	_assert_igual(prateleira.aumentar_estoque_maximo(0), false, "Recusa incremento zero no estoque maximo")
	_assert_igual(prateleira.aumentar_estoque_maximo(3), true, "Aceita incremento positivo no estoque maximo")
	_assert_igual(prateleira.max_stock, 8, "Estoque maximo aumenta para 8 com incremento positivo")

	prateleira.free()