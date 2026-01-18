extends Node

# UI Referansları
var diyalog_kutusu: CanvasLayer = null
var diyalog_label: Label = null
var is_dialogue_active = false

# --- KARAKTER RENK AYARLARI ---
# Anahtar kelimeler (İsimler) ile renkleri eşleştiriyoruz
var karakter_renkleri = {
	"Necromancer": Color(0.8, 0, 0),    # Koyu Kırmızı
	"Oyuncu": Color(0.4, 0.8, 1.0),     # Açık Mavi (Cyan)
	"Köylü": Color(1, 1, 0.6),          # Soluk Sarı
	"Bilinmeyen": Color(1, 1, 1)        # Beyaz (Varsayılan)
}

func register_ui(kutu, label):
	diyalog_kutusu = kutu
	diyalog_label = label
	diyalog_kutusu.visible = false

func konus_bakalim(cumleler: Array[String]):
	if is_dialogue_active: return
	is_dialogue_active = true
	diyalog_kutusu.visible = true
	
	for cumle in cumleler:
		# --- RENK AYARLAMA KISMI (YENİ) ---
		# Cümleyi analiz et: Kim konuşuyor?
		var konusan_kim = "Bilinmeyen" # Varsayılan
		
		# Cümleyi ":" işaretinden ikiye bölüyoruz. 
		# Örnek: "Necromancer: Merhaba" -> ["Necromancer", " Merhaba"]
		var parcalar = cumle.split(":", true, 1)
		
		if parcalar.size() > 1:
			# Eğer ":" varsa, ilk parça isimidir.
			var isim = parcalar[0].strip_edges() # Boşlukları temizle
			
			# İsim listemizde var mı diye bakıyoruz
			if isim in karakter_renkleri:
				konusan_kim = isim
		
		# Rengi uygula
		if diyalog_label:
			diyalog_label.modulate = karakter_renkleri.get(konusan_kim, Color(1,1,1))
		
		# --- YAZDIRMA KISMI ---
		diyalog_label.text = cumle
		diyalog_label.visible_characters = 0
		
		# Daktilo Efekti
		var harf_sayisi = cumle.length()
		for i in range(harf_sayisi):
			diyalog_label.visible_characters = i + 1
			await get_tree().create_timer(0.04).timeout
		
		# Okuması için bekle
		await get_tree().create_timer(2.0).timeout
		
	# Konuşma bitince kapat ve rengi beyaza döndür
	if diyalog_label: diyalog_label.modulate = Color(1, 1, 1)
	diyalog_kutusu.visible = false
	is_dialogue_active = false
