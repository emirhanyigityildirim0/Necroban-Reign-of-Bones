extends Area2D

# Inspector'dan gidilecek yeri seç
@export var hedef_marker: Node2D 

@onready var oyuncu = get_tree().get_first_node_in_group("oyuncu")
# Sahnede "GecisPerdesi" grubundaki siyah kutuyu otomatik bulur
@onready var siyah_perde = get_tree().get_first_node_in_group("GecisPerdesi")

var gecis_yapiliyor = false

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if hedef_marker == null:
		print("HATA: Hedef nokta seçilmemiş!")
		return

	if body.is_in_group("oyuncu") and not gecis_yapiliyor:
		sinematik_gecis_yap()

func sinematik_gecis_yap():
	print("Sinematik geçiş başladı...")
	gecis_yapiliyor = true
	
	# Oyuncuyu dondur
	if oyuncu.get("cutscene_active") != null:
		oyuncu.cutscene_active = true
	
	# --- KARARMA EFEKTİ (FADE IN) ---
	if siyah_perde:
		var tween = create_tween()
		# 0.5 saniyede Alpha değerini 1 (Simsiyah) yap
		tween.tween_property(siyah_perde, "modulate:a", 1.0, 0.5)
		await tween.finished
	else:
		# Perde yoksa hata vermesin, azıcık beklesin
		print("UYARI: Siyah Perde bulunamadı! 'GecisPerdesi' grubunu kontrol et.")
		await get_tree().create_timer(0.2).timeout
	
	# --- IŞINLANMA ---
	oyuncu.global_position = hedef_marker.global_position
	
	# --- AYDINLANMA EFEKTİ (FADE OUT) ---
	if siyah_perde:
		# Işınlandıktan sonra kapkaranlık ekranda yarım saniye bekle (Yükleme hissi)
		await get_tree().create_timer(1).timeout
		
		var tween_out = create_tween()
		# 0.5 saniyede Alpha değerini 0 (Şeffaf) yap
		tween_out.tween_property(siyah_perde, "modulate:a", 0.0, 0.5)
		await tween_out.finished
	
	# Oyuncuyu serbest bırak
	if oyuncu.get("cutscene_active") != null:
		oyuncu.cutscene_active = false
		
	gecis_yapiliyor = false
