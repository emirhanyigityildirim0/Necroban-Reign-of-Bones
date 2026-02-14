extends CharacterBody2D

# ==============================================================================
# PLAYER CONTROLLER SCRIPT (FULL VERSION - WITH FALL ANIMATION)
# ==============================================================================

# --- CONFIGURATION & EXPORTS ---
var respawn_position = Vector2.ZERO
@export_category("Movement Settings")
@export var speed: float = 300.0
@export var jump_force: float = -450.0
@export var gravity: float = 980.0
@export var max_jumps: int = 2 
@export var roll_speed: float = 500.0 
var is_rolling: bool = false 

@export_category("Combat Settings")
@export var knockback_force: float = 1.5
@export var hitstop_duration: float = 0.1
var state_lock_timer: float = 0.0

# 2'li Saldırı için Frame verileri
var attack_data = {
	"Attack1": 1, 
	"Attack2": 2, 
}

@export_group("Dialogue Settings")
var diyalog_kutusu: CanvasLayer 
var diyalog_label: Label        

# --- SCENE RESOURCES ---
var game_over_sahnesi = preload("res://Scenes/UI/DeathScreen.tscn")

# --- STATE VARIABLES ---
var jump_count: int = 0
var cutscene_active: bool = false
var su_an_konusuyor: bool = false
var can_hasar_alabilir: bool = true 
var is_attacking: bool = false
var is_dead: bool = false
var is_hurt: bool = false

# --- COMBO SYSTEM ---
var combo_sayaci: int = 0
var combo_sifirlama_suresi: float = 0.8
var combo_zamanlayicisi: float = 0.0

# --- AUDIO SETTINGS ---
var yurume_sesi_db: float = -15.0

# --- NODE REFERENCES ---
@onready var anim = $AnimatedSprite2D
@onready var pivot = $SaldiriPivotu 
@onready var saldiri_alani = $SaldiriPivotu/SaldiriAlani
@onready var saldiri_collision = $SaldiriPivotu/SaldiriAlani/CollisionShape2D

# Audio Nodes
@onready var sfx_yurume = get_node_or_null("SfxYurume")
@onready var sfx_ziplama = get_node_or_null("SfxZiplama")
@onready var sfx_hasar = get_node_or_null("SfxHasar")
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")
@onready var sfx_flask = get_node_or_null("SfxFlask")
@onready var sfx_Death = get_node_or_null("SfxDeath")

signal player_died

# ==============================================================================
# MAIN LOOPS
# ==============================================================================

func _ready():
	add_to_group("oyuncu")
	Engine.time_scale = 1.0 
	
	if sfx_yurume: sfx_yurume.volume_db = yurume_sesi_db
	if saldiri_collision: saldiri_collision.disabled = true

	cutscene_active = false
	ui_baglantisini_kur()
	
	if GameManager.last_checkpoint_pos != null:
		global_position = GameManager.last_checkpoint_pos
	else:
		GameManager.last_checkpoint_pos = global_position
		
	Global.can = Global.max_can

func ui_baglantisini_kur():
	var bulunan_ui = get_tree().current_scene.find_child("DiyalogKatmani", true, false)
	if bulunan_ui:
		diyalog_kutusu = bulunan_ui
		var bulunan_label = diyalog_kutusu.find_child("Label", true, false)
		if bulunan_label:
			diyalog_label = bulunan_label

func _physics_process(delta):
	
	apply_gravity(delta)
	
	if is_dead: return
	
	if is_attacking or is_rolling or is_hurt:
		state_lock_timer += delta
		# Eğer 1.2 saniyeden uzun sürdüyse (Animasyonlar bu kadar sürmez)
		if state_lock_timer > 1.2:
			print("⚠️ DİKKAT: Karakter kilitlendi! Zorla düzeltiliyor...")
			force_reset_states()
		else:
			state_lock_timer = 0.0 # Her şey normalse süreyi sıfırla
	# -----------------------
	
	if cutscene_active:
		handle_cutscene_physics()
		return 
	
	if is_rolling:
		move_and_slide()
		return 
	
	if is_hurt or is_attacking:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 2)
		move_and_slide()
		return
	
	if combo_sayaci > 0:
		combo_zamanlayicisi -= delta
		if combo_zamanlayicisi <= 0:
			combo_sayaci = 0 

	handle_jump()
	handle_movement()
	
	move_and_slide()
	update_animations()

func _unhandled_input(event):
	if event.is_action_pressed("use_flask"): 
		use_flask()

# ==============================================================================
# MOVEMENT LOGIC
# ==============================================================================

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if not is_attacking and not is_rolling: 
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
			if sfx_ziplama: sfx_ziplama.play()

func handle_movement():
	if Input.is_action_just_pressed("saldiri"):
		saldiri_baslat()
		return
		
	if Input.is_action_just_pressed("roll") and is_on_floor() and not is_rolling:
		roll_baslat()
		return
		
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
		if direction > 0:
			anim.flip_h = false
			pivot.scale.x = 1
		else:
			anim.flip_h = true
			pivot.scale.x = -1
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

func roll_baslat():
	if is_rolling: return
	
	is_rolling = true
	can_hasar_alabilir = false # 🛡️ Hasar ve knockback almanı engeller
	set_collision_mask_value(1, false)
	set_collision_layer_value(2, false)
	$CollisionShape2D.scale.y = 0.5 
	$CollisionShape2D.position.y = 5
	
	# Bakılan yöne doğru hız ver
	var roll_dir = -1 if anim.flip_h else 1
	velocity.x = roll_dir * roll_speed
	velocity.y = 0 
	
	if anim.sprite_frames.has_animation("Roll"):
		anim.play("Roll")
	else:
		print("❌ HATA: 'Roll' animasyonu bulunamadı!")

# --- BURASI GÜNCELLENDİ (JUMP & FALL KONTROLÜ) ---
func update_animations():
	if is_dead or is_hurt or is_attacking or is_rolling or cutscene_active:
		if sfx_yurume: sfx_yurume.stop()
		return
			
	if not is_on_floor():
		# Eğer dikey hız sıfırdan küçükse yukarı çıkıyordur (Jump)
		if velocity.y < 0:
			anim.play("Jump")
		# Eğer dikey hız sıfırdan büyükse aşağı düşüyordur (Fall)
		else:
			anim.play("Fall")
			
		if sfx_yurume: sfx_yurume.stop()
	elif velocity.x != 0:
		anim.play("Run")
		if sfx_yurume and not sfx_yurume.playing:
			sfx_yurume.play()
	else:
		anim.play("Idle")
		if sfx_yurume: sfx_yurume.stop()

# ==============================================================================
# COMBAT SYSTEM
# ==============================================================================

func saldiri_baslat():
	if is_attacking or is_rolling: return
	
	is_attacking = true
	combo_sayaci += 1
	combo_zamanlayicisi = combo_sifirlama_suresi
	
	if combo_sayaci == 1: 
		anim.play("Attack1")
	else:
		anim.play("Attack2")
		combo_sayaci = 0 

	if sfx_saldiri: 
		sfx_saldiri.play()

func _on_animated_sprite_2d_frame_changed():
	if not is_attacking: return
	var current_anim = anim.animation
	if current_anim in attack_data:
		if anim.frame == attack_data[current_anim]:
			hasar_vur()

func hasar_vur():
	saldiri_alani.monitoring = true
	saldiri_collision.disabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	var dusmanlar = saldiri_alani.get_overlapping_bodies()
	for dusman in dusmanlar:
		if dusman == self: continue
		if dusman.has_method("hasar_al"):
			var hasar = Global.damage_heavy if combo_sayaci == 0 else Global.damage_light
			dusman.hasar_al(hasar)
	await get_tree().create_timer(0.1).timeout
	saldiri_collision.disabled = true

func _on_animated_sprite_2d_animation_finished():
	var finished_anim = anim.animation
	if finished_anim in attack_data:
		is_attacking = false
		saldiri_collision.set_deferred("disabled", true)
		
	if finished_anim == "Roll":
		is_rolling = false
		can_hasar_alabilir = true # Dokunulmazlık bitti
		set_collision_mask_value(1, true)
		set_collision_layer_value(2, true)
		# --- HITBOX'I ESKİ HALİNE GETİR ---
		$CollisionShape2D.scale.y = 1.0
		$CollisionShape2D.position.y = 0 # Pozisyonu sıfırla
		
		velocity.x = 0
		print("✅ Takla ve dokunulmazlık bitti, hitbox düzeldi.")

# ==============================================================================
# HEALTH & UTILS
# ==============================================================================

func hasar_al(miktar):
	if is_dead or not can_hasar_alabilir: return
	
	is_attacking = false
	is_rolling = false
	combo_sayaci = 0
	saldiri_collision.set_deferred("disabled", true) # Kılıcı kapat
	
	if Global: Global.can -= miktar
	if sfx_hasar: sfx_hasar.play()
	is_hurt = true 
	anim.play("Hurt")
	can_hasar_alabilir = false
	anim.modulate = Color(1, 0, 0) 
	velocity.x = -pivot.scale.x * 100 
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

func use_flask():
	if is_dead or is_attacking: return
	if Global.current_flasks > 0 and Global.can < Global.max_can:
		Global.current_flasks -= 1
		Global.can = min(Global.can + Global.flask_heal_amount, Global.max_can)
		if sfx_flask: sfx_flask.play()
		get_tree().call_group("hud_group", "update_hud")

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

func checkpoint_kaydet(yeni_pozisyon):
	respawn_position = yeni_pozisyon

func respawn_ol():
	velocity = Vector2.ZERO
	global_position = respawn_position
	Global.can = Global.max_can
func force_reset_states():
	is_attacking = false
	is_rolling = false
	is_hurt = false
	can_hasar_alabilir = true
	saldiri_collision.set_deferred("disabled", true)

	# Fiziksel takılmaları çöz
	$CollisionShape2D.scale.y = 1.0 
	$CollisionShape2D.position.y = 0
	set_collision_mask_value(1, true) 
	anim.play("Idle")
	state_lock_timer = 0.0
