extends Node

# ==========================================
# --- RECURSOS DO JOGADOR ---
# Variáveis que representam o saldo atual do jogador durante a partida.
# ==========================================
var dinheiro: float = 0.0
var reputacao: int = 0

# ==========================================
# --- SISTEMA DE EXPANSÃO ---
# Variáveis responsáveis por controlar o progresso e o crescimento do mercado.
# ==========================================
var nivel_expansao: int = 0
var expansoes_maximas: int = 2 
var clientes_atendidos: int = 0
var meta_expansao: int = 5 

# ==========================================
# --- FUNÇÕES DE RECOMPENSA E PUNIÇÃO ---
# ==========================================

func adicionar_recompensa(valor: float, rep: int) -> void:
	"""
	Adiciona dinheiro e reputação ao saldo atual e 
	contabiliza o atendimento com sucesso para o progresso da expansão do mercado.
	"""
	dinheiro += valor
	reputacao += rep
	clientes_atendidos += 1

func aplicar_punicao(perda_dinheiro: float, perda_rep: int) -> void:
	"""
	Subtrai dinheiro e reputação como penalidade por erros na entrega ou atrasos.
	Possui uma trava de segurança estrutural para impedir que os saldos fiquem negativos.
	"""
	dinheiro -= perda_dinheiro
	reputacao -= perda_rep
	
	# Trava de segurança para garantir que a economia não quebre (fique abaixo de zero)
	if dinheiro < 0: 
		dinheiro = 0.0
		
	if reputacao < 0: 
		reputacao = 0

# ==========================================
# --- CONTROLE DE FLUXO DO JOGO ---
# ==========================================

func resetar_economia() -> void:
	""" 
	Reinicia todos os valores da economia e expansão para o estado inicial de um novo jogo. 
	Chamado sempre que o jogador clicar em "Jogar" no Menu Principal.
	"""
	dinheiro = 0.0
	reputacao = 0
	nivel_expansao = 0
	clientes_atendidos = 0
	meta_expansao = 5
