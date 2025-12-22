extends CanvasLayer # Veya Control, hangisine script bağladıysan

# Düğümleri Koda Bağlama (onready)
@onready var health_bar = $TextureProgressBar
@onready var flask_count_label = $HBoxContainer/Label
# Not: İksir ikonu (TextureRect) değişmeyeceği için onu bağlamamıza gerek yok.

# Bu fonksiyon, oyuncu can aldığında veya iksir kullandığında çağrılacak!
func update_hud():
	
	# Global script'in var olduğundan emin ol
	if not is_instance_valid(Global):
		print("HATA: Global script yüklenemedi!")
		return
	
	# 1. Can Barını Güncelle
	health_bar.max_value = Global.max_can
	health_bar.value = Global.can
	
	# 2. İksir Sayacını Güncelle
	flask_count_label.text = "x" + str(Global.current_flasks)

# Sahne yüklendiğinde HUD'ı ilk değerlerle doldur
func _ready():
	update_hud()
