extends Node

signal reputacao_alterada(nova_reputacao: int, delta: int)
signal game_over_acionado

# --- RECURSOS DO JOGADOR ---
var dinheiro: float = 0.0
var reputacao: int = 20 # Começa com 3 estrelas para poder ganhar ou perder

# --- SISTEMA DE EXPANSÃO E VITÓRIA ---
var nivel_expansao: int = 0
var expansoes_maximas: int = 2
var clientes_atendidos: int = 0
var clientes_totais_atendidos: int = 0
var meta_expansao: int = 5
var meta_vitoria: int = 10
var modo_infinito: bool = false

func adicionar_recompensa(valor: float, rep: int) -> void:
	dinheiro += valor
	reputacao += rep
	clientes_atendidos += 1
	clientes_totais_atendidos += 1
	reputacao_alterada.emit(reputacao, rep)

func aplicar_punicao(perda_dinheiro: float, perda_rep: int) -> void:
	dinheiro = maxf(0.0, dinheiro - perda_dinheiro)
	reputacao = maxi(0, reputacao - perda_rep)
	reputacao_alterada.emit(reputacao, -perda_rep)
	
	if reputacao <= 0:
		game_over_acionado.emit()

func obter_multiplicador_reputacao() -> float:
	if reputacao >= 50: return 1.5   # 5 estrelas (+50%)
	if reputacao >= 30: return 1.25  # 4 estrelas (+25%)
	if reputacao >= 15: return 1.0   # 3 estrelas (padrão)
	return 0.85                      # 1-2 estrelas (-15%)

func resetar_economia() -> void:
	dinheiro = 0.0
	reputacao = 20
	nivel_expansao = 0
	clientes_atendidos = 0
	clientes_totais_atendidos = 0
	meta_expansao = 5
	meta_vitoria = 10
	modo_infinito = false
