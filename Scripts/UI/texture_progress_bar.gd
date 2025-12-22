extends TextureProgressBar 

func _ready():
	max_value = 100
	value = 100
	# Step ayarını kodla da zorlayalım, garanti olsun
	step = 0

func _process(delta):
	if Global:
		# Hedef canımız (Global'deki gerçek can)
		var hedef = float(Global.can)
		
		# --- SİHİRLİ SATIR (LERP) ---
		# Mevcut değeri hedefe doğru "yumuşat".
		# sondaki '5.0' hızıdır. Artırırsan hızlanır, azaltırsan ağır çekim olur.
		value = lerp(value, hedef, 6.0 * delta)
		
		# Görsel Renk Değişimi (Can azsa kızarır)
		if value < 30:
			tint_progress = Color(1, 0, 0) # Kırmızı
		else:
			tint_progress = Color(1, 1, 1) # Beyaz
