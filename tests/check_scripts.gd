extends Node


func _ready() -> void:
	var falhou: bool = false
	var arquivos: Array[String] = []
	_coletar_scripts("res://", arquivos)

	for caminho in arquivos:
		var recurso: Resource = load(caminho)
		if recurso == null:
			printerr("SCRIPT ERROR: Falha ao carregar ", caminho)
			falhou = true

	get_tree().quit(1 if falhou else 0)


func _coletar_scripts(pasta: String, lista: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(pasta)
	if dir == null:
		return

	dir.list_dir_begin()
	var nome: String = dir.get_next()
	while nome != "":
		if not nome.begins_with(".") and nome != "addons":
			var caminho: String = pasta.path_join(nome)
			if dir.current_is_dir():
				_coletar_scripts(caminho, lista)
			elif nome.ends_with(".gd"):
				lista.append(caminho)
		nome = dir.get_next()
	dir.list_dir_end()