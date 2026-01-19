extends CanvasLayer

@onready var label = $Label
@onready var arka_plan = $ColorRect
@onready var ses_oynatici = $SesEfekti # Yeni eklediğimiz ses çalar

# --- RENK VE SES AYARLARI ---

var karakter_verileri = {
	
	"Necromancer": {"renk": Color("ff3333"), "pitch": 0.9}, 
	

	"Oyuncu":      {"renk": Color("33ccff"), "pitch": 1.6}, # Daha ince/normal tonda
	
	# Köylü daha da tiz olsun
	"Köylü":       {"renk": Color("ffff99"), "pitch": 2.0}, # Çok ince
	
	"Sistem":      {"renk": Color("ffffff"), "pitch": 1.5}
}

var su_an_yaziliyor = false
var hizli_gec_basildi = false

func _ready():
	visible = false
	if arka_plan: arka_plan.color = Color(0, 0, 0, 0.7)
	if label: label.modulate = Color(1, 1, 1)

# --- TUŞA BASINCA HIZLANDIRMA ---
func _input(event):
	if not visible: return # Kutu kapalıysa tuşları dinleme
	
	# "ui_accept" genelde SPACE veya ENTER tuşudur.
	# İstersen "etkilesim" veya "saldiri" tuşunu da ekleyebilirsin.
	if event.is_action_pressed("ui_accept"):
		hizli_gec_basildi = true

# --- SENARYO OYNATICI ---
func senaryo_oynat(cumleler_listesi: Array[String]):
	visible = true 
	
	for cumle in cumleler_listesi:
		hizli_gec_basildi = false # Her yeni cümlede sıfırla
		await _yazi_yazdir(cumle)
		
		# Cümle bitti, okuması için bekleme süresi
		# Eğer oyuncu tuşa basarsa bu süreyi de atlarız
		var bekleme_suresi = 2.0
		while bekleme_suresi > 0:
			if hizli_gec_basildi:
				hizli_gec_basildi = false
				break # Beklemeyi iptal et, sonraki cümleye geç
			
			await get_tree().create_timer(0.1).timeout
			bekleme_suresi -= 0.1
	
	visible = false 

# --- YAZDIRMA VE SES MOTORU ---
func _yazi_yazdir(cumle: String):
	su_an_yaziliyor = true
	
	# 1. Kim Konuşuyor?
	var parcalar = cumle.split(":", true, 1)
	var konusan = "Sistem"
	if parcalar.size() > 1:
		konusan = parcalar[0].strip_edges()
	
	# 2. Ayarları Uygula (Renk ve Pitch)
	var pitch_degeri = 1.0
	
	if label:
		if konusan in karakter_verileri:
			label.modulate = karakter_verileri[konusan]["renk"]
			pitch_degeri = karakter_verileri[konusan]["pitch"]
		else:
			label.modulate = Color(1, 1, 1)
		
		label.text = cumle
		label.visible_characters = 0
		
		# 3. Harf Harf Yazdırma Döngüsü
		for i in range(cumle.length()):
			# Eğer tuşa basıldıysa döngüyü kır ve hepsini göster
			if hizli_gec_basildi:
				label.visible_characters = -1 # Hepsini aç
				hizli_gec_basildi = false     # Tuşu tükettik
				break
			
			label.visible_characters = i + 1
			
			# --- SES ÇALMA KISMI ---
			# Her 2 harfte bir ses çalsın (Çok kafa ütülemesin diye)
			if ses_oynatici and i % 2 == 0:
				ses_oynatici.pitch_scale = pitch_degeri + randf_range(-0.1, 0.1) # Hafif rastgelelik
				ses_oynatici.play()
			
			await get_tree().create_timer(0.04).timeout
	
	su_an_yaziliyor = false
