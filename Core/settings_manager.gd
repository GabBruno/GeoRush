extends Node

const CONFIG_PATH := "user://settings.cfg"

var volume_musica: float = 0.8
var volume_sfx: float = 0.8

func _ready() -> void:
	carregar_configuracoes()

func aplicar_volume(nome_bus: String, valor_linear: float) -> void:
	var bus_idx := AudioServer.get_bus_index(nome_bus)
	if bus_idx == -1:
		return
	var clamped := clampf(valor_linear, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_idx, clamped <= 0.001)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(clamped, 0.001)))

func salvar_configuracoes() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "musica", volume_musica)
	cfg.set_value("audio", "sfx", volume_sfx)
	cfg.save(CONFIG_PATH)

func carregar_configuracoes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		volume_musica = cfg.get_value("audio", "musica", 0.8)
		volume_sfx = cfg.get_value("audio", "sfx", 0.8)
	aplicar_volume("Musica", volume_musica)
	aplicar_volume("SFX", volume_sfx)
