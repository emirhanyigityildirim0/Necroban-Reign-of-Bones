extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var label = $Label
@onready var button = $Button

func _ready():
	# Oyun yavaşlasa bile bu kod çalışsın
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Başlangıçta görünmez
	if color_rect: color_rect.modulate.a = 0
	if label: label.modulate.a = 0
	if button: button.modulate.a = 0
	
	# --- ANİMASYON ---
	var tween = get_tree().create_tween()
	
	# !!! MATEMATİKSEL HİLE !!!
	# Oyun şu an 10 kat yavaş (Time Scale 0.1).
	
	# O yüzden "0.15" yazıyoruz ki gerçekte 1.5 saniye sürsün.
	var sure = 0.1
	
	if color_rect: tween.tween_property(color_rect, "modulate:a", 1.0, sure)
	if label: tween.parallel().tween_property(label, "modulate:a", 1.0, sure)
	if button: tween.parallel().tween_property(button, "modulate:a", 1.0, sure)

func _on_button_pressed():
	# --- EN ÖNEMLİ KISIM ---
	# Zamanı normale döndür (Yoksa yeni oyun yavaş başlar!)
	Engine.time_scale = 1.0 
	# -----------------------

	# Canı fulle
	if Global: Global.can = 100
	
	# Sahneyi yenile
	get_tree().reload_current_scene()
	
	# Ekranı sil
	queue_free()
