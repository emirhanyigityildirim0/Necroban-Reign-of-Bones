extends CharacterBody2D

# --- SENARYO ---
@export_group("Senaryo")
@export_multiline var diyaloglar: Array[String] = [
	"Necromancer: ...",
	"Necromancer: hmm...",
	"Necromancer: Sanırım Sunağıma yaklaşmışsın!",
	"Necromancer: hm... ",
	"Necromancer: Olmaması gerekirdi",
	"Necromancer: Kıta'nın fethi yakın...",
	"Necromancer: Seni geldiğin yerden beterine göndericem",
	"Necromancer: ..."
]

# --- BAĞLANTILAR ---
@export var aura_alani: Area2D
@export var aura_camera: Camera2D 

@onready var boss_muzigi = $BossMuzigi 
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")

# --- GÖRSEL EFEKT REFERANSLARI ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var staff_position = $StaffPosition
@onready var spell_light = $StaffPosition/SpellLight
@onready var charge_particles = $StaffPosition/ChargeParticles

# --- DEĞİŞKENLER ---
var player = null
var konusma_basladi = false
var time_passed = 0.0 
var is_attacking = false 

func _ready():
	if animated_sprite: animated_sprite.play("Idle")
	
	# --- DÜZELTME BURADA ---
	# Eskiden direkt spell_light.energy = 0 diyorduk, patlıyordu.
	# Artık kontrol ediyoruz: "Eğer bu gerçekten bir ışıksa enerjisini kıs"
	if spell_light and "energy" in spell_light: 
		spell_light.energy = 0
	elif spell_light and "emitting" in spell_light:
		spell_light.emitting = false # Eğer particlesa kapatsın

	if charge_particles: charge_particles.emitting = false
	
	if aura_alani:
		if aura_alani.body_entered.is_connected(_on_aura_entered):
			aura_alani.body_entered.disconnect(_on_aura_entered)
		aura_alani.body_entered.connect(_on_aura_entered)

func _physics_process(delta):
	# Crash Önleyici
	if not is_instance_valid(animated_sprite) or not is_instance_valid(staff_position): return

	# Hover (Süzülme) Efekti
	time_passed += delta
	position.y += sin(time_passed * 2.5) * 0.3 
	
	if not player: player = get_tree().get_first_node_in_group("oyuncu")
	
	# Yüzünü dönme mantığı (Saldırmıyorsa döner)
	if player and not is_attacking:
		if player.global_position.x > global_position.x:
			animated_sprite.flip_h = false 
			staff_position.position.x = abs(staff_position.position.x)
		else:
			animated_sprite.flip_h = true 
			staff_position.position.x = -abs(staff_position.position.x)

# --- AURA TETİĞİ ---
func _on_aura_entered(body):
	if body.is_in_group("oyuncu"):
		player = body 
		baslat_konusma()

# --- KONUŞMA BAŞLATMA ---
func baslat_konusma():
	if konusma_basladi: return
	konusma_basladi = true
	
	# 1. OYUNCUYU DONDUR
	if player and player.has_method("hareket_kilit"):
		player.hareket_kilit(true) 
	
	# Kamerayı Boss'a al
	if aura_camera:
		aura_camera.enabled = true
		aura_camera.make_current()
	
	if boss_muzigi: boss_muzigi.play()
	
	# Global diyaloğu oynat
	await Diyalog.senaryo_oynat(diyaloglar)
	
	# Konuşma bitince ışınlanma senaryosu başlar
	bitir_ve_isinla()

# --- IŞINLANMA SENARYOSU ---
func bitir_ve_isinla():
	# 1. Saldırı Animasyonunu Yap
	cast_attack_1()
	
	# 2. Müziği Kıs
	if boss_muzigi:
		var music_tween = create_tween()
		music_tween.tween_property(boss_muzigi, "volume_db", -80.0, 1.0)
	
	# Animasyonun biraz oynaması için bekle
	await get_tree().create_timer(0.6).timeout
	
	# 3. Kamera Sarsıntısı
	if aura_camera:
		var shake_tween = create_tween()
		var shake_power = 8.0 
		for i in range(12):
			var random_offset = Vector2(randf_range(-shake_power, shake_power), randf_range(-shake_power, shake_power))
			shake_tween.tween_property(aura_camera, "offset", random_offset, 0.04)
		shake_tween.tween_property(aura_camera, "offset", Vector2.ZERO, 0.05)
	
	# 4. Beyaz Ekran Efekti
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 100 
	add_child(transition_layer) 
	
	var flash_rect = ColorRect.new()
	flash_rect.color = Color.WHITE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT) 
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(flash_rect)
	
	# Önce görünmez yap, sonra parlat
	flash_rect.modulate.a = 0.0
	var flash_tween = create_tween()
	flash_tween.tween_property(flash_rect, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	
	# Beyaz ekran tam olunca ışınla
	await flash_tween.finished
	
	# 5. Sahne Değiştir (Işınlanma)
	var sonraki_level = "res://Scenes/Levels/Cavelevel.tscn"
	
	if ResourceLoader.exists(sonraki_level):
		get_tree().change_scene_to_file(sonraki_level)
	else:
		print("!!! HATA: ", sonraki_level, " bulunamadı! İsmi kontrol et.")

# --- SALDIRI ANİMASYONU ---
func cast_attack_1():
	is_attacking = true
	if animated_sprite: animated_sprite.play("Attack1") 
	if sfx_saldiri: sfx_saldiri.play()
	if charge_particles: charge_particles.emitting = true

func _on_animated_sprite_2d_animation_finished():
	if konusma_basladi: return 
	
	if animated_sprite.animation == "Attack1":
		is_attacking = false
		animated_sprite.play("Idle")
		if charge_particles: charge_particles.emitting = false
