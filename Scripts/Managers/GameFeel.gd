extends Node

# --- EKRAN SARSINTI AYARLARI ---
var shake_strength = 0.0
var shake_decay = 5.0 # Sarsıntının ne kadar hızlı biteceği
var rng = RandomNumberGenerator.new()

# --- KAMERA REFERANSI ---
var camera = null

func _ready():
	rng.randomize()

func _process(delta):
	# Sarsıntı gücünü zamanla azalt (Sıfıra doğru)
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		
		# Kamerayı bul (Her seferinde aramamak için check ediyoruz)
		if not is_instance_valid(camera):
			camera = get_viewport().get_camera_2d()
		
		if is_instance_valid(camera):
			# Kamerayı rastgele salla
			var offset = Vector2(rng.randf_range(-shake_strength, shake_strength), rng.randf_range(-shake_strength, shake_strength))
			camera.offset = offset
	
	elif is_instance_valid(camera) and camera.offset != Vector2.ZERO:
		# Sarsıntı bittiyse kamerayı merkeze oturt
		camera.offset = Vector2.ZERO

# --- DIŞARIDAN ÇAĞRILACAK FONKSİYONLAR ---

# 1. EKRANI SALLA
func sarsinti(guc: float):
	shake_strength = guc

# 2. ZAMANI DURDUR (HIT STOP)
func donma(sure: float, zaman_yavasligi: float = 0.05):
	# Oyunu yavaşlat (Neredeyse durdur)
	Engine.time_scale = zaman_yavasligi
	
	# Gerçek dünya zamanıyla bekle (Oyun zamanı durduğu için normal timer çalışmaz)
	# create_timer'ın son parametresi (true) time_scale'i yok saymasını sağlar.
	await get_tree().create_timer(sure * zaman_yavasligi, true, false, true).timeout
	
	# Zamanı normale döndür
	Engine.time_scale = 1.0

# 3. KOMBO PAKET (Hem salla hem dondur)
func vur(sarsinti_gucu: float, donma_suresi: float):
	sarsinti(sarsinti_gucu)
	donma(donma_suresi)
