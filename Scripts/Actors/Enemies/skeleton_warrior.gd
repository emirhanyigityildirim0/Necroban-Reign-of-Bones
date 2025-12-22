extends CharacterBody2D

# --- FSM (DURUM MAKİNESİ) ---
enum STATE {IDLE, PATROL, CHASE, ATTACK, HURT, DEAD}
var current_state = STATE.PATROL

# --- AYARLAR ---
@export_category("Movement Settings")
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 100.0
@export var gravity: float = 980.0

@export_category("Combat Settings")
@export var max_health: int = 40
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.2
var melee_anims = ["Attack"] # Savaşçının tek saldırı animasyonu varsa burası böyle kalır

# --- DEĞİŞKENLER ---
var current_health: int
var is_dead: bool = false
var has_target: bool = false
var is_attacking: bool = false
var direction: int = 1 
var attack_timer: float = 0.0

# --- NODE REFERANSLARI ---
@onready var anim = $AnimatedSprite2D
@onready var pivot = $SaldiriPivotu # KilicAlani bunun içinde olmalı!
@onready var ucurum_sensoru = $SaldiriPivotu/UcurumSensoru
@onready var vision_area = $SaldiriPivotu/VisionArea
@onready var kilic_collider = $SaldiriPivotu/KilicAlani/CollisionShape2D 
@onready var kilic_alani = $SaldiriPivotu/KilicAlani

# Sesler
@onready var sfx_yurume = get_node_or_null("SfxYurume")
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri") 
@onready var sfx_hasar = get_node_or_null("SfxHasar")

func _ready():
	add_to_group("dusman")
	current_health = max_health
	if kilic_collider: kilic_collider.disabled = true
	
	# Sinyalleri bağla
	if vision_area:
		if not vision_area.body_entered.is_connected(_on_vision_body_entered):
			vision_area.body_entered.connect(_on_vision_body_entered)
		if not vision_area.body_exited.is_connected(_on_vision_body_exited):
			vision_area.body_exited.connect(_on_vision_body_exited)
	
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

func _physics_process(delta):
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, 200 * delta)
		move_and_slide()
		return

	# Saldırı anında kilitlen
	if is_attacking:
		velocity.x = 0
		return 

	if not is_on_floor():
		velocity.y += gravity * delta
	
	if attack_timer > 0:
		attack_timer -= delta

	# Yön güncelleme mantığı
	if current_state != STATE.PATROL:
		face_player()
	else:
		update_direction_visuals()

	match current_state:
		STATE.IDLE: idle_state()
		STATE.PATROL: patrol_state()
		STATE.CHASE: chase_state(delta)
		STATE.ATTACK: attack_state()
		STATE.HURT: hurt_state(delta)
	
	move_and_slide()

# --- STATE MANTIĞI ---

func idle_state():
	velocity.x = 0
	if has_target: transition_to_state(STATE.CHASE)

func patrol_state():
	if is_on_wall() or not ucurum_sensoru.is_colliding():
		direction *= -1
		
	velocity.x = direction * patrol_speed
	anim.play("Walk")
	if has_target: transition_to_state(STATE.CHASE)

func chase_state(_delta):
	var player = get_player()
	if not player: 
		transition_to_state(STATE.PATROL)
		return
		
	var distance = global_position.distance_to(player.global_position)
	
	if distance <= attack_range:
		transition_to_state(STATE.ATTACK)
	else:
		var dir_to_player = sign(player.global_position.x - global_position.x)
		velocity.x = dir_to_player * chase_speed
		anim.play("Walk")

func attack_state():
	velocity.x = 0
	if attack_timer <= 0 and not is_attacking:
		start_attack_sequence()
	else:
		anim.play("Idle")

func hurt_state(delta):
	velocity.x = move_toward(velocity.x, 0, 300 * delta)

# --- SALDIRI SİSTEMİ ---

func start_attack_sequence():
	is_attacking = true
	velocity.x = 0
	
	# Saldırı başlamadan HEMEN ÖNCE yönü kesinleştir
	face_player() 
	
	var secilen_saldiri = melee_anims.pick_random()
	anim.play(secilen_saldiri) 
	
	# Vuruş anını bekle (0.4 saniye)
	await get_tree().create_timer(0.4).timeout 
	
	# Hasar yiyip iptal olmadıysa ve ölmediyse vur
	if is_attacking and not is_dead: 
		melee_hit_check()
	
	attack_timer = attack_cooldown

func melee_hit_check():
	if not kilic_alani: return
	if sfx_saldiri: sfx_saldiri.play()

	kilic_collider.disabled = false
	await get_tree().create_timer(0.1).timeout 
	
	var bodies = kilic_alani.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("oyuncu") and body.has_method("hasar_al"):
			body.hasar_al(15) 
			print("Vurdum!") # Konsoldan vuruşu takip et
			
	if kilic_collider: kilic_collider.disabled = true

# --- YARDIMCI FONKSİYONLAR ---

func get_player():
	return get_tree().get_first_node_in_group("oyuncu")

func face_player():
	var player = get_player()
	if player:
		var dir = sign(player.global_position.x - global_position.x)
		# Sadece yön değiştiyse işlem yap (Performans ve titreme önler)
		if dir != 0 and dir != direction:
			direction = dir
			update_direction_visuals()

func update_direction_visuals():
	if direction > 0:
		anim.flip_h = false
		pivot.scale.x = 1 # Sağa bakıyorsa normal
	else:
		anim.flip_h = true
		pivot.scale.x = -1 # Sola bakıyorsa HİTBOX'I TERS ÇEVİR

func transition_to_state(new_state):
	if current_state == STATE.DEAD: return
	current_state = new_state
	
	match new_state:
		STATE.IDLE: anim.play("Idle")
		STATE.HURT: 
			anim.play("Hurt")
			is_attacking = false # Hasar alınca saldırıyı iptal et
			if kilic_collider: kilic_collider.set_deferred("disabled", true)
		STATE.DEAD: die()

func hasar_al(amount):
	if is_dead: return
	current_health -= amount
	if sfx_hasar: sfx_hasar.play()
	
	is_attacking = false # Saldırıyı boz
	
	# Beyaz Parlama
	var tween = create_tween()
	anim.modulate = Color(10, 10, 10, 1) 
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)

	if current_health <= 0: 
		transition_to_state(STATE.DEAD)
	else:
		transition_to_state(STATE.HURT)

func die():
	is_dead = true
	anim.play("Death")
	is_attacking = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 1)
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _on_vision_body_entered(body):
	if body.is_in_group("oyuncu"):
		has_target = true

func _on_vision_body_exited(body):
	if body.is_in_group("oyuncu"):
		has_target = false

func _on_anim_finished():
	if is_dead: return
	
	if anim.animation in melee_anims:
		is_attacking = false
		decide_combat_state()
	elif anim.animation == "Hurt":
		decide_combat_state()

func decide_combat_state():
	var player = get_player()
	if not player: 
		transition_to_state(STATE.PATROL)
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance <= attack_range:
		transition_to_state(STATE.ATTACK)
	else:
		transition_to_state(STATE.CHASE)
