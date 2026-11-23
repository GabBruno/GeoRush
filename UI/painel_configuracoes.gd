extends Panel
class_name PainelConfiguracoes

@onready var label_musica: Label = $VBoxContainer/LabelMusica
@onready var slider_musica: HSlider = $VBoxContainer/SliderMusica
@onready var label_sfx: Label = $VBoxContainer/LabelSFX
@onready var slider_sfx: HSlider = $VBoxContainer/SliderSFX
@onready var som_teste: AudioStreamPlayer = $VBoxContainer/SomTeste

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_sincronizar_sliders()
	
	slider_musica.value_changed.connect(_on_musica_changed)
	slider_sfx.value_changed.connect(_on_sfx_changed)
	slider_sfx.drag_ended.connect(_on_sfx_drag_ended)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	# Sempre que o painel abrir, garante que os sliders reflitam o volume salvo
	if visible:
		_sincronizar_sliders()

func _sincronizar_sliders() -> void:
	slider_musica.set_value_no_signal(SettingsManager.volume_musica)
	slider_sfx.set_value_no_signal(SettingsManager.volume_sfx)
	_atualizar_textos()

func _on_musica_changed(valor: float) -> void:
	SettingsManager.volume_musica = valor
	SettingsManager.aplicar_volume("Musica", valor)
	SettingsManager.salvar_configuracoes()
	_atualizar_textos()

func _on_sfx_changed(valor: float) -> void:
	SettingsManager.volume_sfx = valor
	SettingsManager.aplicar_volume("SFX", valor)
	SettingsManager.salvar_configuracoes()
	_atualizar_textos()

func _on_sfx_drag_ended(_value_changed: bool) -> void:
	if som_teste:
		som_teste.play()

func _atualizar_textos() -> void:
	label_musica.text = "Música: %d%%" % int(round(SettingsManager.volume_musica * 100.0))
	label_sfx.text = "Efeitos: %d%%" % int(round(SettingsManager.volume_sfx * 100.0))
