extends Node

# --- Recursos do Jogador ---
var dinheiro: float = 0.0
var reputacao: int = 0

# --- Sistema de Expansão ---
var nivel_expansao: int = 0
var expansoes_maximas: int = 2 
var clientes_atendidos: int = 0
var meta_expansao: int = 5 

func adicionar_recompensa(valor: float, rep: int) -> void:
	"""
	Adiciona dinheiro e reputação ao saldo atual e 
	contabiliza o atendimento para o progresso da expansão.
	"""
	dinheiro += valor
	reputacao += rep
	clientes_atendidos += 1

func aplicar_punicao(perda_dinheiro: float, perda_rep: int) -> void:
	"""
	Subtrai dinheiro e reputação como penalidade por erros ou atrasos.
	Possui uma trava de segurança para impedir que os saldos fiquem negativos.
	"""
	dinheiro -= perda_dinheiro
	reputacao -= perda_rep
	
	# Trava de segurança (Floor)
	if dinheiro < 0: 
		dinheiro = 0.0
		
	if reputacao < 0: 
		reputacao = 0
