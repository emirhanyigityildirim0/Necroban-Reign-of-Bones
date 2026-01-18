extends CharacterBody2D
# ==============================================================================
# PLAYER CONTROLLER SCRIPT
# ==============================================================================
# Description: Handles player movement, combat (combos & frame-perfect hits),
# health system, and UI interactions.
# ==============================================================================

# --- AYARLAR VE DEĞİŞKENLER ---

@export_category("Movement Settings")
@export var speed: float = 250.0
@export var jump_force: float = -450.0
@export var gravity: float = 980.0
@export var max_jumps: int = 2 

@export_category("Combat Settings")
@export var damage_heavy: int = 20 
@export var damage_light: int = 10 
@export var knockback_force: float = 1.5
@export var hitstop_duration: float = 0.1

# --- "FRAME PERFECT" SALDIRI VERİLERİ (YENİ) ---
# Hangi animasyonun kaçıncı karesinde (index) hasar vurulacak?
var attack_data = {
	"Attack1": 3, 
	"Attack2": 3,
	"Attack3": 4
}

@export_group("Dialogue Settings")
var diyalog_kutusu: CanvasLayer 
var diyalog_label: Label        

# --- SAHNE REFERANSLARI ---
var game_over_sahnesi = preload("res://Scenes/UI/DeathScreen.tscn")

# --- DURUM DEĞİŞKENLERİ ---
var jump_count: int = 0
var cutscene_active: bool = false
var su_an_konusuyor: bool = false
var can_hasar_alabilir: bool = true 
var is_attacking: bool = false
var is_dead: bool = false
var is_hurt: bool = false

# --- KOMBO SİSTEMİ ---
var combo_sayaci: int = 0
var combo_sifirlama_suresi: float = 0.8
var combo_zamanlayicisi: float = 0.0

# --- SES AYARLARI ---
var yurume_sesi_db: float = -15.0

# --- NODE REFERANSLARI ---
@onready var anim = $AnimatedSprite2D
@onready var pivot = $SaldiriPivotu 
@onready var saldiri_alani = $SaldiriPivotu/SaldiriAlani
@onready var saldiri_collision = $SaldiriPivotu/SaldiriAlani/CollisionShape2D

# Ses Node'ları
@onready var sfx_yurume = get_node_or_null("SfxYurume")
@onready var sfx_ziplama = get_node_or_null("SfxZiplama")
@onready var sfx_hasar = get_node_or_null("SfxHasar")
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")
@onready var sfx_flask = get_node_or_null("SfxFlask")
@onready var sfx_Death = get_node_or_null("SfxDeath")

# --- SİNYALLER ---
signal player_died

func _ready():
	add_to_group("oyuncu")
	
	# Zaman akışını normale döndür (Ölüm ekranından sonra restart atılırsa diye)
	Engine.time_scale = 1.0 
	
	if sfx_yurume: sfx_yurume.volume_db = yurume_sesi_db
	if saldiri_collision: saldiri_collision.disabled = true
	
	# UI Bağlantısı
	ui_baglantisini_kur()

func ui_baglantisini_kur():
	var bulunan_ui = get_tree().current_scene.find_child("DiyalogKatmani", true, false)
	if bulunan_ui:
		diyalog_kutusu = bulunan_ui
		var bulunan_label = diyalog_kutusu.find_child("Label", true, false)
		if bulunan_label:
			diyalog_label = bulunan_label
			# print(">> PLAYER: Connected to Dialogue System.") # Konsolu kirletmesin diye kapattım
	else:
		pass 

func _physics_process(delta):
	# 1. Yerçekimi her zaman uygulanmalı (Saldırırken havada asılı kalmamak için)
	apply_gravity(delta)

	# 2. Öncelikli Durumlar (Buradaysak aşağı inme)
	if cutscene_active:
		handle_cutscene_physics()
		return 

	if is_dead: return
	
	if is_hurt or is_attacking:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 2) # Hafif sürtünme ile dursun
		move_and_slide()
		return
	
	# 3. Kombo Zamanlayıcısı
	if combo_sayaci > 0:
		combo_zamanlayicisi -= delta
		if combo_zamanlayicisi <= 0:
			combo_sayaci = 0

	# 4. Normal Hareket
	handle_jump()
	handle_movement()
	
	move_and_slide()
	update_animations()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if not is_attacking: # Saldırı sırasında zıplama hakkını hemen sıfırlama (Havada kombo için)
			jump_count = 0 

func handle_cutscene_physics():
	velocity.x = 0 
	move_and_slide()
	if anim: anim.play("Idle")
	if sfx_yurume: sfx_yurume.stop()

func handle_jump():
	if Input.is_action_just_pressed("ui_accept"):
		if jump_count < max_jumps:
			velocity.y = jump_force
			jump_count += 1
			cal_ziplama_sesi()

func cal_ziplama_sesi():
	if sfx_ziplama:
		var random_pitch = randf_range(0.9, 1.1)
		if jump_count == 2:
			sfx_ziplama.pitch_scale = random_pitch + 0.2
		else:
			sfx_ziplama.pitch_scale = random_pitch
		sfx_ziplama.play()

func handle_movement():
	# Saldırı Girdisi
	if Input.is_action_just_pressed("saldiri"):
		# Sadece yerdeyken değil, havadayken de vurabilirsin (İstersen "and is_on_floor()" ekle)
		saldiri_baslat()
		return

	# Hareket Girdisi
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
		# Yön değiştirme
		if direction > 0:
			anim.flip_h = false
			pivot.scale.x = 1
		else:
			anim.flip_h = true
			pivot.scale.x = -1
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

func _unhandled_input(event):
	if event.is_action_pressed("use_flask"): 
		use_flask()

func use_flask():
	if is_dead or is_attacking: return
	if not Global: return # Global script yüklü değilse hata vermesin

	if Global.current_flasks > 0 and Global.can < Global.max_can:
		Global.current_flasks -= 1
		Global.can += Global.flask_heal_amount
		if Global.can > Global.max_can:
			Global.can = Global.max_can
		
		if sfx_flask:
			sfx_flask.stop()
			sfx_flask.play()
	
		get_tree().call_group("hud_group", "update_hud")
	elif Global.current_flasks == 0:
		pass # Flask yok sesi eklenebilir

func update_animations():
	if is_dead or is_hurt or is_attacking or cutscene_active:
		if sfx_yurume: sfx_yurume.stop()
		return
			
	if not is_on_floor():
		anim.play("Jump")
		if sfx_yurume: sfx_yurume.stop()
	elif velocity.x != 0:
		anim.play("Run")
		if sfx_yurume and not sfx_yurume.playing:
			sfx_yurume.play()
	else:
		anim.play("Idle")
		if sfx_yurume: sfx_yurume.stop()

# --- SİNYAL İLE ÇALIŞAN SALDIRI SİSTEMİ (YENİLENMİŞ) ---

func saldiri_baslat():
	if is_attacking: return
	
	is_attacking = true
	combo_sayaci += 1
	combo_zamanlayicisi = combo_sifirlama_suresi
	
	# Kombo seçimi
	if combo_sayaci == 1: anim.play("Attack1")
	elif combo_sayaci == 2: anim.play("Attack2")
	elif combo_sayaci >= 3:
		anim.play("Attack3")
		combo_sayaci = 0 

	# Ses
	if sfx_saldiri: 
		sfx_saldiri.pitch_scale = randf_range(0.9, 1.1) # Saldırı sesine de varyasyon ekledik
		sfx_saldiri.play()
	
	# Timer YOK! Sadece bekliyoruz, Sinyal (_on_animated_sprite_2d_frame_changed) işi yapacak.

# BU FONKSİYONU SİNYALE BAĞLA: AnimatedSprite2D -> frame_changed
func _on_animated_sprite_2d_frame_changed():
	if not is_attacking: return
	
	var current_anim = anim.animation
	
	# Çalan animasyon bizim listemizde var mı?
	if current_anim in attack_data:
		# Doğru kareye (Impact Frame) geldik mi?
		if anim.frame == attack_data[current_anim]:
			hasar_vur()

func hasar_vur():
	print("⚔️ Kılıç sallandı! Çarpışma alanı açılıyor...")
	
	saldiri_collision.disabled = false
	
	# Fizik motorunun uyanması için 2 kare bekleyelim (Bazen 1 yetmez)
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Kılıç alanının içindeki HERKESİ listele
	var dusmanlar = saldiri_alani.get_overlapping_bodies()
	
	
	
	for dusman in dusmanlar:
		
		
		# Kendimizi vurmayalım
		if dusman != self:
			if dusman.has_method("hasar_al"):
				print("💀 Enemy detected /hitting Damage... ", dusman.name)
				# Hasar hesaplama
				var hasar = damage_heavy if combo_sayaci <= 1 else damage_light
				dusman.hasar_al(hasar)
	

	# Hitbox'ı kapat
	await get_tree().create_timer(0.1).timeout
	saldiri_collision.disabled = true

func _on_animated_sprite_2d_animation_finished():
	if anim.animation in attack_data:
		is_attacking = false
		saldiri_collision.set_deferred("disabled", true) 

# --- HASAR ALMA VE ÖLÜM ---

func hasar_al(miktar):
	if is_dead or not can_hasar_alabilir: return
	
	if Global: Global.can -= miktar
	
	if sfx_hasar: sfx_hasar.play()
	
	is_hurt = true 
	can_hasar_alabilir = false
	anim.modulate = Color(1, 0, 0)
	
	
	velocity.x = -pivot.scale.x * 200 
	velocity.y = -150 
	
	await get_tree().create_timer(0.4).timeout
	
	anim.modulate = Color(1, 1, 1)
	can_hasar_alabilir = true
	is_hurt = false
	
	if Global and Global.can <= 0:
		olum_gerceklesti()

func olum_gerceklesti():
	if is_dead: return 
	is_dead = true
	velocity = Vector2.ZERO
	anim.play("Death")
	$CollisionShape2D.set_deferred("disabled", true)
	
	if sfx_yurume: sfx_yurume.stop()
	if sfx_Death: sfx_Death.play()
	
	emit_signal("player_died") 
	
	await get_tree().create_timer(1.0).timeout
	
	Engine.time_scale = 0.3 
	var ekran = game_over_sahnesi.instantiate()
	get_tree().root.add_child(ekran)


func konus(cumle: String):
	if not diyalog_kutusu or not diyalog_label: return
	
	su_an_konusuyor = true
	diyalog_kutusu.visible = true
	diyalog_label.text = cumle
	diyalog_label.visible_characters = 0
	
	for i in range(cumle.length()):
		diyalog_label.visible_characters = i + 1
		await get_tree().create_timer(0.04).timeout
	
	await get_tree().create_timer(2.0).timeout
	diyalog_kutusu.visible = false
	su_an_konusuyor = false
