extends Node2D

# --- ARTIK UI SÜRÜKLEMENE GEREK YOK! ---
# Global sistem (Autoload) otomatik halledecek.

@onready var ambiyans = get_node_or_null("Ambiyans")
@onready var ambiyans2 = get_node_or_null("Ambiyans2")
@onready var muzik = get_node_or_null("Muzik")

@export_group("Senaryo")
@export_multiline var giris_diyaloglari: Array[String] = [
	"Oyuncu: Öhhö... öhhö...",
	"Oyuncu: Başım dönüyor...",
	"Oyuncu: O ışık da neydi öyle?",
	"Oyuncu: Mağaranın derinliklerinden soğuk bir rüzgar geliyor."
]

@onready var oyuncu = $Oyuncu # Oyuncunun yolu
@onready var hedef_nokta = $YeniBolgeBaslangic # Işınlanacağı Marker2D
@onready var siyah_perde = $GecisKatmani/ColorRect # Siyah ekran

var gecis_yapiliyor = false

func _ready():
	# 1. Beyaz ekran efektiyle başla
	beyaz_ekran_efekti_yap()
	
	if ambiyans and not ambiyans.playing: ambiyans.play()
	if ambiyans2 and not ambiyans2.playing: ambiyans2.play()

func beyaz_ekran_efekti_yap():
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 128
	add_child(transition_layer)
	
	var beyaz_perde = ColorRect.new()
	beyaz_perde.color = Color.WHITE
	beyaz_perde.set_anchors_preset(Control.PRESET_FULL_RECT)
	beyaz_perde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(beyaz_perde)
	
	var tween = create_tween()
	tween.tween_property(beyaz_perde, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT)
	tween.tween_callback(transition_layer.queue_free)
	
	# Tween bittiği an konuşmayı başlat
	tween.finished.connect(baslat_giris_konusmasi)

# --- İŞTE BURASI DEĞİŞTİ (ÇOK BASİTLEŞTİ) ---
func baslat_giris_konusmasi():
	print(">> Konuşma başlıyor (Senaryo Modu).")
	
	var player = get_tree().get_first_node_in_group("oyuncu")

	await Diyalog.senaryo_oynat(giris_diyaloglari)
	
	if player: 
		player.set_physics_process(true)
		print(">> Konuşma bitti.")

func _on_level_cıkıs_tetigi_body_entered(body: Node2D) -> void:
	if body.is_in_group("oyuncu") and not gecis_yapiliyor:
		sinematik_gecis_yap()

func sinematik_gecis_yap():
	print("Bölüm bitti! Yeni bölgeye geçiliyor...")
	gecis_yapiliyor = true
	
	if oyuncu.get("cutscene_active") != null:
		oyuncu.cutscene_active = true
	
	# Kararma Efekti
	var tween = create_tween()
	tween.tween_property(siyah_perde, "modulate:a", 1.0, 1.0)
	await tween.finished
	
	# Işınlanma
	oyuncu.global_position = hedef_nokta.global_position
	await get_tree().create_timer(0.5).timeout
	
	# Aydınlanma Efekti
	var tween_out = create_tween()
	tween_out.tween_property(siyah_perde, "modulate:a", 0.0, 1.0)
	await tween_out.finished
	
	if oyuncu.get("cutscene_active") != null:
		oyuncu.cutscene_active = false
		
	gecis_yapiliyor = false
