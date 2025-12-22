extends Node2D

# --- EDİTÖRDEN BAĞLANTILAR ---
# Eğer bu sahnede de genel bir UI kullanacaksan buraya bağlayabilirsin.
# Şimdilik Necro kendi UI'ını yönetiyor ama Level'in de haberi olsun.
@export var level_ui: CanvasLayer 

func _ready() -> void:
	# 1. ZAMANI DÜZELT (Çok Önemli)
	# Eğer önceki sahnede oyun yavaşladıysa (Slow Motion), burada normale dönsün.
	Engine.time_scale = 1.0
	
	print(">> Karanlık Alem (Ana Seviye) Yüklendi.")
	
	# 2. BEYAZ EKRAN GEÇİŞİNİ BAŞLAT
	beyaz_ekran_acilis_efekti()

# --- SİNEMATİK AÇILIŞ FONKSİYONU ---
func beyaz_ekran_acilis_efekti():
	# Geçici bir katman oluştur (En üstte dursun)
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 128 
	add_child(transition_layer)
	
	# Bembeyaz perdeyi oluştur
	var beyaz_perde = ColorRect.new()
	beyaz_perde.color = Color.WHITE
	beyaz_perde.set_anchors_preset(Control.PRESET_FULL_RECT) # Tüm ekranı kapla
	beyaz_perde.mouse_filter = Control.MOUSE_FILTER_IGNORE # Tıklamayı engelleme
	transition_layer.add_child(beyaz_perde)
	
	# --- TWEEN İLE YAVAŞÇA YOK ET ---
	var tween = create_tween()
	# Alpha değerini 1.0'dan (Opak) 0.0'a (Görünmez) çek
	# Süreyi 1.5 saniye yaptım, mağara kadar uzun sürmesin, oyuncu sıkılır.
	tween.tween_property(beyaz_perde, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_OUT)
	
	# İş bitince bu geçici katmanı RAM'den sil
	tween.tween_callback(transition_layer.queue_free)
	
	print(">> Sahne Fade-In efektiyle açılıyor...")

func _process(delta: float) -> void:
	pass
