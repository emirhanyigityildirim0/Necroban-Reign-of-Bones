extends Node2D

# --- EDİTÖRDEN BAĞLANACAK DİYALOG AYARLARI ---
@export_group("Diyalog Bağlantıları")
@export var diyalog_kutusu: CanvasLayer # Sahneye eklediğin Diyalog UI'ı buraya sürükle
@export var diyalog_label: Label       # UI içindeki Label'ı buraya sürükle

@onready var ambiyans = get_node_or_null("Ambiyans")
@onready var ambiyans2 = get_node_or_null("Ambiyans2")
@onready var muzik = get_node_or_null("Muzik")

@export_group("Senaryo")
@export_multiline var giris_diyaloglari: Array[String] = [
	"Oyuncu: 'Öhhö... öhhö...'",
	"Oyuncu: 'Başım dönüyor...'",
	"Oyuncu: 'O ışık da neydi öyle?'",
	"Oyuncu: 'Mağaranın derinliklerinden soğuk bir rüzgar geliyor.'"
]
@onready var oyuncu = $Oyuncu # Oyuncunun yolu
@onready var hedef_nokta = $YeniBolgeBaslangic # Işınlanacağı Marker2D
@onready var siyah_perde = $GecisKatmani/ColorRect # Siyah ekran

var gecis_yapiliyor = false
func _ready():
	# 1. Önce senin yazdığın BEYAZ EKRAN GEÇİŞİ çalışsın
	beyaz_ekran_efekti_yap()
	if ambiyans and not ambiyans.playing:
		ambiyans.play()
		
	if ambiyans2 and not ambiyans2.playing:
		ambiyans2.play()
		
	# 2. Efekt bitene kadar bekle (Tween bitişini bekler)
	# Fonksiyonun içinde await kullandığımız için burası kodu duraklatmaz,
	# o yüzden aşağıda özel bir sinyal bekleyeceğiz.

func beyaz_ekran_efekti_yap():
	# --- SENİN YAZDIĞIN KOD (DOKUNMADIM) ---
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 128
	add_child(transition_layer)
	
	var beyaz_perde = ColorRect.new()
	beyaz_perde.color = Color.WHITE
	beyaz_perde.set_anchors_preset(Control.PRESET_FULL_RECT)
	beyaz_perde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(beyaz_perde)
	
	var tween = create_tween()
	# 2 saniyede yavaşça açılsın
	tween.tween_property(beyaz_perde, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT)
	tween.tween_callback(transition_layer.queue_free)
	
	print(">> Mağara Leveli Yüklendi. Fade-in başladı...")
	
	# --- EKLEME: PERDE AÇILINCA KONUŞMA BAŞLASIN ---
	# Tween bittiği an (finished sinyali), konuşma fonksiyonunu çağırıyoruz.
	tween.finished.connect(baslat_giris_konusmasi)

# --- KONUŞMA MANTIĞI ---
func baslat_giris_konusmasi():
	print(">> Fade-in bitti, konuşma başlıyor.")
	
	var oyuncu = get_tree().get_first_node_in_group("oyuncu")
	
	# --- OYUNCUYU KİLİTLE ---
	if oyuncu:
		oyuncu.set_physics_process(false) # Hareketi durdur
		if oyuncu.has_node("AnimatedSprite2D"):
			oyuncu.get_node("AnimatedSprite2D").play("Idle")
	
	# --- DİYALOG KUTUSUNU AÇ ---
	if diyalog_kutusu and diyalog_label:
		diyalog_kutusu.visible = true
		
		for cumle in giris_diyaloglari:
			# Yazıyı harf harf yaz
			await yazi_efekti(cumle)
			
			# Okuması için bekle (1.5 sn)
			await get_tree().create_timer(1.0).timeout
		
		# Her şey bitince kutuyu kapat
		diyalog_kutusu.visible = false
	else:
		print("!!! UYARI: Diyalog Kutusu veya Label Inspector'da atanmamış!")

	# --- OYUNCUYU SERBEST BIRAK ---
	if oyuncu:
		oyuncu.set_physics_process(true)
		print(">> Konuşma bitti, kontrol oyuncuda.")

# --- YAZI EFEKTİ (HELPER) ---
# --- YAZI EFEKTİ (GÜNCELLENDİ: ARTIK RENKLİ) ---
func yazi_efekti(metin):
	if diyalog_label:
		# 1. ADIM: Kimin konuştuğunu bul ve rengi ayarla
		var parcalar = metin.split(":", true, 1) # Metni ":" işaretinden ikiye böl
		
		# Varsayılan renk BEYAZ olsun (Her cümlede sıfırlansın diye)
		diyalog_label.modulate = Color(1, 1, 1) 

		if parcalar.size() > 1:
			var isim = parcalar[0].strip_edges() # İsim kısmını al (boşlukları temizle)
			
			# İSME GÖRE RENK SEÇİMİ
			match isim:
				"Oyuncu":
					diyalog_label.modulate = Color(0.2, 0.8, 1.0) # Mavi
				"Necromancer":
					diyalog_label.modulate = Color(0.9, 0.1, 0.1) # Kırmızı
				"Köylü":
					diyalog_label.modulate = Color(1, 1, 0.6)     # Sarı
				_:
					diyalog_label.modulate = Color(1, 1, 1)       # Bilinmeyen biri (Beyaz)
		
		# 2. ADIM: Yazıyı Ekrana Bas (Daktilo Efekti)
		diyalog_label.text = metin
		diyalog_label.visible_characters = 0
		
		for i in range(metin.length()):
			diyalog_label.visible_characters = i + 1
			await get_tree().create_timer(0.04).timeout


func _on_level_cıkıs_tetigi_body_entered(body: Node2D) -> void:
	print(">>> BİRİ Tetiğe Girdi! Giren kişi: ", body.name)
	
	if body.name == "Oyuncu" or body.is_in_group("oyuncu"):
		print(">>> Giren kişi OYUNCU! Geçiş başlatılıyor...")
		if not gecis_yapiliyor:
			sinematik_gecis_yap()
		else:
			print(">>> Zaten geçiş yapılıyor, tekrar başlatmadım.")
	else:
		print(">>> Giren kişi oyuncu DEĞİL. Bu yüzden çalışmadı.")
func sinematik_gecis_yap():
	print("Bölüm bitti! Yeni bölgeye geçiliyor...")
	gecis_yapiliyor = true
	
	# 1. Oyuncuyu dondur (Opsiyonel ama tavsiye edilir)
	# oyuncu.set_physics_process(false) 
	# VEYA oyuncu.cutscene_active = true (senin kodundaki gibi)
	if oyuncu.get("cutscene_active") != null:
		oyuncu.cutscene_active = true
	
	# --- TWEEN İLE KARARMA EFEKTİ ---
	var tween = create_tween()
	# Siyah perdeyi 1 saniyede görünür yap (Alpha 0 -> 1)
	tween.tween_property(siyah_perde, "modulate:a", 1.0, 1.0)
	# Tween bitene kadar bekle
	await tween.finished
	
	# --- IŞINLANMA ANI (Kimse görmüyor) ---
	# Oyuncuyu hedef Marker2D'nin pozisyonuna taşı
	oyuncu.global_position = hedef_nokta.global_position
	
	# (Kamera oyuncuya bağlıysa otomatik gelecektir)
	# Kısa bir bekleme (yükleme hissi için)
	await get_tree().create_timer(0.5).timeout
	
	# --- AYDINLANMA EFEKTİ ---
	var tween_out = create_tween()
	# Siyah perdeyi 1 saniyede tekrar görünmez yap (Alpha 1 -> 0)
	tween_out.tween_property(siyah_perde, "modulate:a", 0.0, 1.0)
	await tween_out.finished
	
	# 2. Oyuncuyu serbest bırak
	# oyuncu.set_physics_process(true)
	if oyuncu.get("cutscene_active") != null:
		oyuncu.cutscene_active = false
		
	gecis_yapiliyor = false
	print("Yeni bölgeye varıldı!")
