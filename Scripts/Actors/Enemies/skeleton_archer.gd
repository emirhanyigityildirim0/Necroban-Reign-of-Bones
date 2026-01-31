extends CharacterBody2D

# --- DURUM MAKİNESİ (FSM) ---
enum STATE {IDLE, PATROL, CHASE, ATTACK, FLEE, HURT, DEAD}
var current_state = STATE.PATROL

# --- DIŞARIDAN AYARLANABİLİR AYARLAR ---
@export_category("Movement Settings")
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 90.0
@export var flee_speed: float = 140.0 
@export var gravity: float = 980.0

@export_category("Combat Settings")
@export var max_health: int = 40
@export var attack_range: float = 300.0 # Ok atma menzili
@export var flee_range: float = 120.0   # Kaçmaya başlama sınırı
@export var panic_range: float = 60.0   # Kaçmayı bırakıp kılıç çekme sınırı
@export var attack_cooldown: float = 2.0 

# Ok sahnesinin dosya yolu (Sahnende bu dosyanın olduğundan emin ol)
var arrow_scene = preload("res://Scenes/Objects/EnemyArrow.tscn") 
var melee_anims = ["Attack1", "Attack2", "Attack3"]

# --- DEĞİŞKENLER ---
var current_health: int
var is_dead: bool = false
var has_target: bool = false
var is_attacking: bool = false
var direction: int = 1 
var attack_timer: float = 0.0

# --- NODE REFERANSLARI ---
@onready var anim = $AnimatedSprite2D
@onready var pivot = $SaldiriPivotu
@onready var ucurum_sensoru = $SaldiriPivotu/UcurumSensoru
@onready var vision_area = $SaldiriPivotu/VisionArea
@onready var kilic_collider = $SaldiriPivotu/KilicAlani/CollisionShape2D 
@onready var kilic_alani = $SaldiriPivotu/KilicAlani
@onready var namlu_ucu = $SaldiriPivotu/NamluUcu 

# Ses Referansları
@onready var sfx_yurume = get_node_or_null("SfxYurume")
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri") 
@onready var sfx_saldiri2 = get_node_or_null("SfxSaldiri2")
@onready var sfx_hasar = get_node_or_null("SfxHasar")

func _ready():
	add_to_group("dusman")
	current_health = max_health
	if kilic_collider: kilic_collider.disabled = true
	
	# Sinyalleri kodla bağlayarak kopuklukları engelliyoruz
	if vision_area:
		vision_area.body_entered.connect(_on_vision_body_entered)
		vision_area.body_exited.connect(_on_vision_body_exited)
	
	anim.animation_finished.connect(_on_anim_finished)

func _physics_process(delta):
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, 200 * delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta
		
		# Saldırı anında beyni dondur (Hareketi engeller)
	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return 
	if attack_timer > 0:
		attack_timer -= delta

	# Yön belirleme (Kaçarken de oyuncuya bakar)
	if current_state != STATE.PATROL:
		face_player()
	else:
		update_direction_visuals()

	# Durumları çalıştır
	match current_state:
		STATE.IDLE: idle_state()
		STATE.PATROL: patrol_state()
		STATE.CHASE: chase_state(delta)
		STATE.FLEE: flee_state(delta)
		STATE.ATTACK: attack_state()
		STATE.HURT: hurt_state(delta)
	
	move_and_slide()

# --- DURUM FONKSİYONLARI ---

func idle_state():
	velocity.x = 0
	if has_target: decide_combat_state()

func patrol_state():
	if is_on_wall() or not ucurum_sensoru.is_colliding():
		direction *= -1
		
	velocity.x = direction * patrol_speed
	anim.play("Walk")
	if has_target: decide_combat_state()

func chase_state(_delta):
	var player = get_player()
	if not player: 
		transition_to_state(STATE.PATROL)
		return
		
	var distance = global_position.distance_to(player.global_position)
	
	if distance < panic_range:
		transition_to_state(STATE.ATTACK)
	elif distance <= flee_range:
		transition_to_state(STATE.FLEE)
	elif distance <= attack_range:
		transition_to_state(STATE.ATTACK)
	else:
		var dir_to_player = sign(player.global_position.x - global_position.x)
		velocity.x = dir_to_player * chase_speed
		anim.play("Walk")

func flee_state(_delta):
	var player = get_player()
	if not player: return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Sıkışma veya çok yaklaşma kontrolü
	if distance < panic_range or is_on_wall() or not ucurum_sensoru.is_colliding():
		transition_to_state(STATE.ATTACK)
		return

	if distance > flee_range * 1.5: 
		decide_combat_state() 
		return

	var dir_away = sign(global_position.x - player.global_position.x)
	velocity.x = dir_away * flee_speed
	anim.play("Evasion") 

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
	
	var player = get_player()
	var mesafemiz = 999.0
	if player: mesafemiz = global_position.distance_to(player.global_position)
	
	face_player()
	
	if mesafemiz <= flee_range: 
		# MELEE
		anim.play(melee_anims.pick_random()) 
		if sfx_saldiri2:sfx_saldiri2.pitch_scale = randf_range(0.8, 1.2); sfx_saldiri2.play()
		await get_tree().create_timer(0.4).timeout 
		if is_attacking and not is_dead: 
			melee_hit_check()
	else:
		# SHOT
		anim.play("Shot") 
	
	# Rastgele cooldown
	attack_timer = randf_range(1.5, 3.0)

func shoot_arrow():
	if not arrow_scene: return
	if sfx_saldiri:sfx_saldiri.pitch_scale = randf_range(0.8, 1.2); sfx_saldiri.play()
	
	var arrow = arrow_scene.instantiate()
	arrow.global_position = namlu_ucu.global_position if namlu_ucu else global_position
	arrow.direction = direction 
	get_tree().root.add_child(arrow)

func melee_hit_check():
	if not kilic_alani: return
	kilic_collider.disabled = false
	await get_tree().create_timer(0.1).timeout 
	var bodies = kilic_alani.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("oyuncu") and body.has_method("hasar_al"):
			body.hasar_al(10) 
	kilic_collider.disabled = true

# --- YARDIMCI FONKSİYONLAR ---

func get_player():
	return get_tree().get_first_node_in_group("oyuncu")

func face_player():
	var player = get_player()
	if player:
		var dir = sign(player.global_position.x - global_position.x)
		if dir != 0:
			direction = dir
			update_direction_visuals()

func update_direction_visuals():
	if direction > 0:
		anim.flip_h = false
		pivot.scale.x = 1
	else:
		anim.flip_h = true
		pivot.scale.x = -1

func transition_to_state(new_state):
	if current_state == STATE.DEAD: return
	current_state = new_state
	match new_state:
		STATE.IDLE: anim.play("Idle")
		STATE.HURT: 
			anim.play("Hurt")
			is_attacking = false # Saldırı kesilir
			if kilic_collider: kilic_collider.set_deferred("disabled", true)
		STATE.DEAD: die()

func hasar_al(amount):
	print("💀 İSKELET: Auuv! Hasar fonksiyonu tetiklendi!")
	
	if is_dead:
		print("💀 İSKELET: Zaten ölüyüm, hasar işlemi iptal.")
		return
		
	current_health -= amount
	print("🩸 Kalan Can: ", current_health, " / ", max_health)
	
	if sfx_hasar: sfx_hasar.play()
	
	# Saldırıyı kes
	is_attacking = false 
	
	# Beyaz Parlama
	var tween = create_tween()
	anim.modulate = Color(10, 10, 10, 1) 
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)

	if current_health <= 0: 
		print("💀 İSKELET: Ölüyorum...")
		transition_to_state(STATE.DEAD)
	else:
		print("🤕 İSKELET: Acıdı! Hurt moduna geçiliyor.")
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
		if current_state in [STATE.PATROL, STATE.IDLE]:
			decide_combat_state()

func _on_vision_body_exited(body):
	if body.is_in_group("oyuncu"):
		has_target = false

func _on_anim_finished():
	if is_dead: return
	if anim.animation == "Shot" or anim.animation in melee_anims:
		is_attacking = false 
		decide_combat_state()
	elif anim.animation == "Hurt":
		decide_combat_state()
	elif anim.animation == "Evasion":
		if current_state == STATE.FLEE:
			anim.play("Evasion")
		else:
			decide_combat_state()

func decide_combat_state():
	var player = get_player()
	if not player: 
		transition_to_state(STATE.PATROL)
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance < panic_range:
		transition_to_state(STATE.ATTACK)
	elif distance <= flee_range:
		transition_to_state(STATE.FLEE) 
	elif distance <= attack_range:
		transition_to_state(STATE.ATTACK)
	else:
		transition_to_state(STATE.CHASE)


func _on_animated_sprite_2d_frame_changed() -> void:

	if is_dead or not is_attacking: return

	if anim.animation == "Shot":
	
		if anim.frame == 11: 
			shoot_arrow()
