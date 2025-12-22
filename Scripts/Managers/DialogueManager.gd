# DialogueManager.gd (Global Autoload)
extends Node

# UI Referanslarını oyunu açınca bağlayacağız
var diyalog_kutusu: CanvasLayer = null
var diyalog_label: Label = null
var is_dialogue_active = false
# --- KARAKTER RENK AYARLARI ---
# İsimleri buraya, cümlelerin başındakiyle BİREBİR aynı yazmalısın.
var karakter_renkleri = {
	"Necromancer": Color(0.8, 0, 0),   # Koyu Kırmızı
	"Oyuncu": Color(0.4, 0.8, 1.0),    # Açık Mavi (Cyan)
	"Köylü": Color(1, 1, 0.6),         # Soluk Sarı
	"Bilinmeyen": Color(0.7, 0.7, 0.7) # Gri
}

func register_ui(kutu, label):
	# Her bölüm açıldığında UI buraya kendini kaydettirecek
	diyalog_kutusu = kutu
	diyalog_label = label
	diyalog_kutusu.visible = false

func konus_bakalim(cumleler: Array[String]):
	if is_dialogue_active: return
	is_dialogue_active = true
	diyalog_kutusu.visible = true
	
	for cumle in cumleler:
		diyalog_label.text = cumle
		diyalog_label.visible_characters = 0
		
		# Daktilo Efekti
		var harf_sayisi = cumle.length()
		for i in range(harf_sayisi):
			diyalog_label.visible_characters = i + 1
			await get_tree().create_timer(0.04).timeout
		
		# Okuması için bekle (veya tuşa basmayı bekle)
		await get_tree().create_timer(1.5).timeout
		
	# Konuşma bitince
	diyalog_kutusu.visible = false
	is_dialogue_active = false
