extends CharacterBody2D

# --- FSM TANIMI VE DURUM GEÇİŞLERİ ---
enum STATE {IDLE, PATROL, CHASE, ATTACK, HURT, DEAD}
var current_state = STATE.PATROL
var donme_sogumasi = false
var donme_kilidi = false
var memory_timer = 0.0 
const HAFIZA_SURESI = 2.0

# --- EXPORT DEĞİŞKENLERİ ---
@export var patrol_speed = 60.0
@export var chase_speed = 100.0
@export var gravity = 980.0

# --- CAN VE HASAR AYARLARI ---
var can = 30
var is_dead = false
var has_target = false

# --- SALDIRI AYARLARI ---
const SALDIRI_COOLDOWN_SURESI = 1.0
var attack_timer = 0.0
var is_attacking = false
# GÜNCELLEME: Menzili 100 yaptık. Artık uzaktan da olsa vuracak!
const SALDIRI_MENZILI = 100.0 

# --- GÖRSEL VE YÖN AYARLARI ---
var direction = 1 

# --- DÜĞÜM REFERANSLARI (@onready) ---
@onready var anim = $AnimatedSprite2D
@onready var ucurum_sensoru = $SaldiriPivotu/UcurumSensoru
@onready var kilic_alani = $SaldiriPivotu/KilicAlani
@onready var vision_area = $SaldiriPivotu/VisionArea
@onready var saldiri_sensoru = $SaldiriPivotu/SaldiriSensoru 

# Sesler
@onready var sfx_yurume = get_node_or_null("SfxYurume")
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")
@onready var sfx_hasar = get_node_or_null("SfxHasar")

func _ready():
	add_to_group("dusman")
	
	if kilic_alani.has_node("CollisionShape2D"):
		kilic_alani.get_node("CollisionShape2D").disabled = true
	
	# Sinyalleri kod ile bağla
	if vision_area:
		if not vision_area.body_entered.is_connected(_on_vision_area_body_entered):
			vision_area.body_entered.connect(_on_vision_area_body_entered)
		if not vision_area.body_exited.is_connected(_on_vision_area_body_exited):
			vision_area.body_exited.connect(_on_vision_area_body_exited)
			
	if not anim.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		anim.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

func _physics_process(_delta):
	if not is_on_floor():
		velocity.y += gravity * _delta

	# Ölü kontrolü
	if current_state == STATE.DEAD or is_dead:
		velocity.x = move_toward(velocity.x, 0, 200 * _delta)
		move_and_slide()
		return 

	if attack_timer > 0:
		attack_timer -= _delta
	
	set_direction_visuals()

	match current_state:
		STATE.IDLE: idle_state(_delta)
		STATE.PATROL: patrol_state(_delta)
		STATE.CHASE: chase_state(_delta)
		STATE.ATTACK: attack_state(_delta)
		STATE.HURT: hurt_state(_delta)
	
	move_and_slide()

# --- DURUM GEÇİŞİ ---
func transition_to_state(new_state):
	if current_state == STATE.DEAD: return
	if current_state == new_state: return
	
	match current_state:
		STATE.ATTACK:
			is_attacking = false
			if kilic_alani.has_node("CollisionShape2D"):
				kilic_alani.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	current_state = new_state
	
	match new_state:
		STATE.IDLE:
			velocity.x = 0
			anim.play("Idle")
		STATE.PATROL:
			anim.play("Walk")
		STATE.CHASE:
			anim.play("Walk")
		STATE.HURT:
			anim.play("Hurt")
			velocity.x = 0 
		STATE.ATTACK:
			is_attacking = true
			velocity.x = 0
			saldiri_baslat_temiz()
		STATE.DEAD:
			velocity.x = 0
			olu_ver()

# --- STATE FONKSİYONLARI ---
func idle_state(_delta):
	velocity.x = 0
	if has_target: transition_to_state(STATE.CHASE)

func patrol_state(_delta):
	if not donme_kilidi:
		if is_on_wall() or not ucurum_sensoru.is_colliding():
			direction *= -1
			donme_kilidi = true
			await get_tree().create_timer(1.0).timeout
			donme_kilidi = false

	velocity.x = direction * patrol_speed
	anim.play("Walk")
	if sfx_yurume and not sfx_yurume.playing: sfx_yurume.play()
	if has_target: transition_to_state(STATE.CHASE)

func chase_state(_delta):
	var player = get_tree().get_first_node_in_group("oyuncu")
	if not player:
		transition_to_state(STATE.PATROL)
		return

	if has_target:
		memory_timer = HAFIZA_SURESI
	else:
		memory_timer -= _delta
		if memory_timer <= 0:
			transition_to_state(STATE.PATROL)
			return

	direction = sign(player.global_position.x - global_position.x)
	if direction == 0: direction = 1
	
	var mesafe = abs(player.global_position.x - global_position.x)
	
	# Saldırı Menzili Kontrolü (100.0 yaptık, artık rahat vurmalı)
	if mesafe < SALDIRI_MENZILI:
		if attack_timer <= 0:
			transition_to_state(STATE.ATTACK)
		else:
			velocity.x = 0
			anim.play("Idle")
		return 

	velocity.x = direction * chase_speed
	anim.play("Walk")

func attack_state(_delta):
	velocity.x = 0 

func hurt_state(_delta):
	velocity.x = move_toward(velocity.x, 0, 400 * _delta)

func set_direction_visuals():
	if direction > 0:
		anim.flip_h = false
		$SaldiriPivotu.scale.x = 1
	else:
		anim.flip_h = true
		$SaldiriPivotu.scale.x = -1

# --- HASAR / ÖLÜM ---
func hasar_al(miktar):
	if current_state == STATE.DEAD or is_dead: return
	
	can -= miktar
	if sfx_hasar: sfx_hasar.play()
	
	var sprite = $AnimatedSprite2D 
	sprite.modulate = Color(10, 10, 10, 1)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	
	if can <= 0:
		transition_to_state(STATE.DEAD)
	else:
		transition_to_state(STATE.HURT)

func olu_ver():
	if is_dead: return
	is_dead = true
	if sfx_yurume: sfx_yurume.stop()
	anim.play("Death")
	
	# CESET FUTBOLU ÇÖZÜMÜ:
	collision_layer = 0 # Kimseye çarpmasın
	collision_mask = 1  # Sadece yere bassın
	
	if kilic_alani.has_node("CollisionShape2D"):
		kilic_alani.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	await get_tree().create_timer(5.0).timeout
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()

func saldiri_baslat_temiz():
	anim.play("Idle")
	anim.modulate = Color(0.8, 0.5, 0.5) 
	await get_tree().create_timer(0.2).timeout
	
	if current_state != STATE.ATTACK: 
		anim.modulate = Color(1, 1, 1)
		return
		
	anim.modulate = Color(1, 1, 1)
	anim.play("Attack") # Senin resimdeki isimle aynı (Attack)
	if sfx_saldiri: sfx_saldiri.play()
	
	await get_tree().create_timer(0.2).timeout
	if current_state != STATE.ATTACK: return
	vurus_baslat()

func vurus_baslat():
	if current_state != STATE.ATTACK: return
	var shape = kilic_alani.get_node("CollisionShape2D")
	shape.disabled = false
	await get_tree().create_timer(0.05).timeout
	
	var icerdekiler = kilic_alani.get_overlapping_bodies()
	print("Kılıç vurdukları: ", icerdekiler)
	
	for kisi in icerdekiler:
		if kisi == self: continue
		if kisi.is_in_group("oyuncu"):
			if kisi.has_method("hasar_al"):
				kisi.hasar_al(20)
	
	await get_tree().create_timer(0.1).timeout
	if shape: shape.disabled = true

# --- EKSİK FONKSİYONLAR EKLENDİ (HATAYI ÇÖZEN KISIM) ---

func _on_vision_area_body_entered(body):
	if body.is_in_group("oyuncu"):
		has_target = true
		if current_state == STATE.PATROL or current_state == STATE.IDLE:
			transition_to_state(STATE.CHASE)

func _on_vision_area_body_exited(body):
	if body.is_in_group("oyuncu"):
		has_target = false

func _on_animated_sprite_2d_animation_finished():
	if anim.animation == "Hurt" and current_state == STATE.HURT:
		if can > 0:
			if has_target: transition_to_state(STATE.CHASE)
			else: transition_to_state(STATE.PATROL)
	elif anim.animation == "Attack" and current_state == STATE.ATTACK:
		attack_timer = SALDIRI_COOLDOWN_SURESI
		if has_target: transition_to_state(STATE.CHASE)
		else: transition_to_state(STATE.PATROL)
