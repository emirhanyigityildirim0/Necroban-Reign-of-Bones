extends Area2D

# Label'ı buluyoruz (Sunağın içindeki)
@onready var label = $Label 

# SARSINTI AYARI: Ne kadar şiddetli sallansın? (Piksel cinsinden)
var shake_intensity = 8.0 

func _ready():
	if label:
		label.visible = false

func _on_body_entered(body):
	if body.is_in_group("oyuncu"):
		if label: label.visible = true

func _on_body_exited(body):
	if body.is_in_group("oyuncu"):
		if label: label.visible = false

func _unhandled_input(event):
	# Sadece yazı görünüyorsa ve tuşa basıldıysa
	if label and label.visible and event.is_action_pressed("interact"):
		# Tekrar basılmasını engellemek için yazıyı hemen gizle
		label.visible = false
		transition_to_necromancer_realm()

# --- SİNEMATİK GEÇİŞ KISMI ---
func transition_to_necromancer_realm():
	print(">>> GEÇİŞ EFEKTİ BAŞLIYOR (Zaman + Flash + Sarsıntı)...")
	
	# 1. GİRİŞİ KİLİTLE
	var player = get_tree().get_first_node_in_group("oyuncu")
	if player:
		player.set_physics_process(false)
	
	# 2. BEYAZ PERDE OLUŞTUR
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var flash_ekrani = ColorRect.new()
	flash_ekrani.color = Color.MEDIUM_PURPLE
	flash_ekrani.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_ekrani.modulate.a = 0.0
	canvas.add_child(flash_ekrani)
	
	# 3. TWEEN İLE EFEKTLERİ OYNAT
	var duration = 1.5 # Geçiş süresi (Beyaz ekranın süresi)
	var tween = get_tree().create_tween()
	tween.set_parallel(true) 
	
	# Efekt A: Zamanı yavaşlat
	tween.tween_property(Engine, "time_scale", 0.05, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Efekt B: Ekranı beyaza boya
	tween.tween_property(flash_ekrani, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# --- DÜZELTME BURADA ---
	# Sarsıntıya 'duration + 2.0' dedik. Yani normalden uzun sürecek.
	# Sahne değişince sarsıntı mecburen kesileceği için "erken bitme" sorunu çözülür.
	start_camera_shake(duration + 4.5, shake_intensity)
	# -----------------------
	
	# 4. BİTİŞİ BEKLE (Beyaz ekranın bitmesini bekle)
	await tween.finished
	
	# 5. GEÇİŞ YAP
	print(">>> SAHNE YÜKLENİYOR...")
	Engine.time_scale = 1.0 
	get_tree().change_scene_to_file("res://Scenes/Levels/NecromancerRealm.tscn")

# --- KAMERA SARSINTI FONKSİYONU ---
func start_camera_shake(shake_duration: float, intensity: float):
	var camera = get_viewport().get_camera_2d()
	if not camera: return

	var elapsed_time = 0.0
	
	# Döngü verilen süre boyunca çalışır
	while elapsed_time < shake_duration:
		# Eğer sahne değiştiyse veya kamera yok olduysa döngüyü kır (Hata vermesin)
		if not is_instance_valid(camera):
			break
			
		var random_x = randf_range(-intensity, intensity)
		var random_y = randf_range(-intensity, intensity)
		camera.offset = Vector2(random_x, random_y)
		
		# Zaman yavaşladığı için 'ignore_time_scale=true' olmalı
		await get_tree().create_timer(0.05, false, false, true).timeout
		elapsed_time += 0.05
		
	# Güvenlik önlemi: Eğer kamera hala oradaysa sıfırla
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
