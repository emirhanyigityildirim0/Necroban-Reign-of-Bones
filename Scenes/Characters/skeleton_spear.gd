extends CharacterBody2D

# --- DURUM MAKİNESİ ---
enum State { IDLE, PATROL, CHASE, ATTACK, BLOCK, DEATH, HURT }
var current_state = State.PATROL 

# --- AYARLAR ---
@export var speed = 90.0
@export var patrol_speed = 50.0
@export var gravity = 980.0
@export var max_health = 150 
@export var attack_cooldown = 1.2
@export var block_chance = 40 
@export var heavy_attack_chance = 40 
@export var damage_light = 15
@export var damage_heavy = 40

# --- UYARI VE SERSEMLEME SÜRELERİ (GÜNCELLENDİ) ---
@export var heavy_attack_windup = 0.8 
@export var hurt_duration = 0.25 # Sersemleme süresi kısaldı (Eskisi 0.4'tü)

# --- KNOCKBACK AYARLARI (GÜNCELLENDİ) ---
@export var knockback_force_x = 100 # Geri tepme azaldı (Eskisi 200'dü)
@export var knockback_force_y = -100 

# --- ANIMASYON KARELERİ ---
var attack_frames = { "Attack1": 2, "Attack2": 5 }

# --- BAĞLANTILAR ---
@onready var anim = $AnimatedSprite2D
@onready var pivot = $SaldiriPivotu
@onready var spear_area = $SaldiriPivotu/SpearArea
@onready var spear_collision = $SaldiriPivotu/SpearArea/CollisionShape2D
@onready var vision_area = $SaldiriPivotu/VisionArea
@onready var saldiri_sensoru = $SaldiriPivotu/SaldiriSensoru
@onready var ucurum_sensoru = $SaldiriPivotu/UcurumSensoru
@onready var kivilcim = get_node_or_null("SaldiriPivotu/Kivilcim") 

# Sesler
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")
@onready var sfx_hasar = get_node_or_null("SfxHasar")
@onready var sfx_blok = get_node_or_null("SfxBlok")
@onready var sfx_yurume = get_node_or_null("SfxYurume")

var current_health = 0
var player = null
var can_attack = true
var facing_right = true

func _ready():
	current_health = max_health
	add_to_group("dusman")
	spear_collision.disabled = true
	change_state(State.PATROL)
	
	if not spear_area.body_entered.is_connected(_on_spear_hit): spear_area.body_entered.connect(_on_spear_hit)
	if not vision_area.body_entered.is_connected(_on_vision_entered): vision_area.body_entered.connect(_on_vision_entered)
	if not vision_area.body_exited.is_connected(_on_vision_exited): vision_area.body_exited.connect(_on_vision_exited)
	if not anim.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished): anim.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	if not anim.frame_changed.is_connected(_on_animated_sprite_2d_frame_changed): anim.frame_changed.connect(_on_animated_sprite_2d_frame_changed)

func _physics_process(delta):
	if current_state != State.DEATH and not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.IDLE:
			velocity.x = 0
			anim.play("Idle")
			if sfx_yurume: sfx_yurume.stop()
			if player: change_state(State.CHASE)
		State.PATROL:
			velocity.x = (1 if facing_right else -1) * patrol_speed
			anim.play("Walk")
			handle_walk_sound()
			if not ucurum_sensoru.is_colliding() or is_on_wall(): yon_degistir(!facing_right)
			if player: change_state(State.CHASE)
		State.CHASE:
			if player:
				var direction = player.global_position.x - global_position.x
				yon_degistir(direction > 0)
				if saldiri_sensoru.is_colliding():
					var collider = saldiri_sensoru.get_collider()
					if collider and collider.is_in_group("oyuncu"):
						if can_attack: change_state(State.ATTACK)
						else: velocity.x = 0; anim.play("Idle")
					else: velocity.x = sign(direction) * speed; anim.play("Walk"); handle_walk_sound()
				else: velocity.x = sign(direction) * speed; anim.play("Walk"); handle_walk_sound()
			else: change_state(State.PATROL)
		State.ATTACK: velocity.x = 0
		State.BLOCK: velocity.x = 0
		State.HURT: velocity.x = move_toward(velocity.x, 0, speed * delta)
		State.DEATH: velocity.x = 0
	move_and_slide()

func change_state(new_state):

	anim.speed_scale = 1
	
	if current_state == State.ATTACK and new_state != State.ATTACK:
		spear_collision.set_deferred("disabled", true)
	
	current_state = new_state
	
	if new_state == State.ATTACK:
		saldiri_baslat()
	elif new_state == State.BLOCK:
		blok_baslat()
	elif new_state == State.HURT:
		anim.play("Idle")
	
		await get_tree().create_timer(hurt_duration).timeout
		

		if current_state == State.HURT:

			can_attack = true 
			change_state(State.CHASE)
			
	elif new_state == State.DEATH:
		anim.play("Death")
		$CollisionShape2D.set_deferred("disabled", true)
		spear_collision.set_deferred("disabled", true)
		set_physics_process(false)
		await get_tree().create_timer(1.5).timeout
		queue_free()
func saldiri_baslat():
	can_attack = false
	var zar = randi() % 100
	if zar < heavy_attack_chance:
		anim.play("Attack2"); anim.speed_scale = 0; anim.modulate = Color(0.6, 0, 0)
		await get_tree().create_timer(heavy_attack_windup).timeout
		if current_state == State.ATTACK:
			anim.speed_scale = 1; anim.modulate = Color(1, 1, 1); anim.play("Attack2")
			if sfx_saldiri: sfx_saldiri.pitch_scale = 0.8; sfx_saldiri.play()
	else:
		anim.speed_scale = 1; anim.play("Attack1")
		if sfx_saldiri: sfx_saldiri.pitch_scale = 1.2; sfx_saldiri.play()

func blok_baslat():
	if anim.sprite_frames.has_animation("Block"): anim.play("Block")
	else: anim.play("Idle"); anim.modulate = Color(0.38, 0.3, 1.0)
	if sfx_blok: sfx_blok.pitch_scale = 1.0; sfx_blok.play()

func hasar_al(miktar):
	if current_state == State.DEATH: return
	
	if current_state == State.BLOCK:
		if kivilcim:
			var patlama_yonu = -1 if facing_right else 1
			kivilcim.direction = Vector2(patlama_yonu, 0)
			kivilcim.restart(); kivilcim.emitting = true 
		if sfx_blok: sfx_blok.pitch_scale = randf_range(0.9, 1.1); sfx_blok.play()
		return

	if current_state in [State.IDLE, State.CHASE, State.PATROL]:
		var zar = randi() % 100
		if zar < block_chance: change_state(State.BLOCK); hasar_al(0); return

	# --- HASAR ---
	current_health -= miktar
	
	# BEYAZ FLAŞ (Artık çalışacak!)
	anim.modulate = Color(10, 10, 10) 
	
	if sfx_hasar: sfx_hasar.play()
	
	# KNOCKBACK (Gücü azaltıldı)
	velocity.y = knockback_force_y
	var knock_dir = 0
	if player: knock_dir = sign(global_position.x - player.global_position.x)
	else: knock_dir = -1 if facing_right else 1
	if knock_dir == 0: knock_dir = 1
	velocity.x = knock_dir * knockback_force_x
	
	change_state(State.HURT)
	
	# Rengi 0.1 sn sonra düzelt
	await get_tree().create_timer(0.1).timeout
	
	if current_state != State.DEATH and current_state != State.BLOCK:
		# Eğer Ağır Saldırı Donması devam ediyorsa Kırmızıya dön, yoksa Normale
		if current_state == State.ATTACK and anim.animation == "Attack2" and anim.speed_scale == 0:
			anim.modulate = Color(0.6, 0, 0)
		else:
			anim.modulate = Color(1, 1, 1)

	if current_health <= 0: change_state(State.DEATH)

# --- SİNYALLER ---
func _on_animated_sprite_2d_animation_finished():
	if current_state == State.ATTACK:
		spear_collision.set_deferred("disabled", true)
		change_state(State.CHASE)
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
	elif current_state == State.BLOCK:
		anim.modulate = Color(1, 1, 1)
		change_state(State.CHASE)

func _on_animated_sprite_2d_frame_changed():
	if current_state == State.ATTACK:
		var current_anim = anim.animation
		if attack_frames.has(current_anim):
			if anim.frame == attack_frames[current_anim]: spear_collision.disabled = false
			else: spear_collision.disabled = true

func _on_spear_hit(body):
	if body.is_in_group("oyuncu") and body.has_method("hasar_al"):
		var dmg = damage_heavy if anim.animation == "Attack2" else damage_light
		body.hasar_al(dmg)
		spear_collision.set_deferred("disabled", true)

func yon_degistir(saga_baksin: bool):
	if current_state in [State.ATTACK, State.BLOCK, State.DEATH, State.HURT]: return
	facing_right = saga_baksin
	if facing_right: pivot.scale.x = 1; anim.flip_h = false
	else: pivot.scale.x = -1; anim.flip_h = true

func handle_walk_sound(): if sfx_yurume and not sfx_yurume.playing: sfx_yurume.play()
func _on_vision_entered(body): if body.is_in_group("oyuncu"): player = body
func _on_vision_exited(body): if body == player: player = null
