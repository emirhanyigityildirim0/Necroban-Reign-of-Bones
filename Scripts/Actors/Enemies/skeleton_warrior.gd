extends CharacterBody2D

# --- FSM DEFINITIONS ---
enum STATE {IDLE, PATROL, CHASE, ATTACK, HURT, DEAD}
var current_state = STATE.PATROL

# --- EXPORT SETTINGS ---
@export_category("Movement Settings")
@export var patrol_speed: float = 60.0
@export var chase_speed: float = 100.0
@export var gravity: float = 980.0

@export_category("Combat Settings")
@export var max_health: int = 40
@export var attack_range: float = 100.0
@export var attack_cooldown: float = 1.0
@export var damage_amount: int = 20
@export var memory_duration: float = 2.0 # How long AI remembers player after losing sight

# --- STATE VARIABLES ---
var current_health: int
var is_dead: bool = false
var has_target: bool = false
var is_attacking: bool = false
var direction: int = 1 

# --- TIMERS & COOLDOWNS ---
var attack_timer: float = 0.0
var memory_timer: float = 0.0
var turn_cooldown: bool = false

# --- NODE REFERENCES ---
@onready var anim = $AnimatedSprite2D
@onready var pivot = $SaldiriPivotu
@onready var ucurum_sensoru = $SaldiriPivotu/UcurumSensoru
@onready var kilic_alani = $SaldiriPivotu/KilicAlani
# Optimization: Cache the collision shape to avoid repeated get_node calls
@onready var kilic_collider = $SaldiriPivotu/KilicAlani/CollisionShape2D 
@onready var vision_area = $SaldiriPivotu/VisionArea

# Audio Nodes
@onready var sfx_yurume = get_node_or_null("SfxYurume")
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")
@onready var sfx_hasar = get_node_or_null("SfxHasar")

func _ready():
	add_to_group("dusman")
	current_health = max_health
	
	# Ensure hitbox is disabled on start
	if kilic_collider:
		kilic_collider.disabled = true
	
	# Connect Signals programmatically
	if vision_area:
		if not vision_area.body_entered.is_connected(_on_vision_area_body_entered):
			vision_area.body_entered.connect(_on_vision_area_body_entered)
		if not vision_area.body_exited.is_connected(_on_vision_area_body_exited):
			vision_area.body_exited.connect(_on_vision_area_body_exited)
			
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

func _physics_process(delta):
	# Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Dead State Logic (Drift check)
	if current_state == STATE.DEAD or is_dead:
		velocity.x = move_toward(velocity.x, 0, 200 * delta)
		move_and_slide()
		return 

	# Update Cooldowns
	if attack_timer > 0:
		attack_timer -= delta
	
	update_direction_visuals()

	# State Machine Logic
	match current_state:
		STATE.IDLE: idle_state()
		STATE.PATROL: patrol_state()
		STATE.CHASE: chase_state(delta)
		STATE.ATTACK: attack_state()
		STATE.HURT: hurt_state(delta)
	
	move_and_slide()

# --- STATE TRANSITIONS ---
func transition_to_state(new_state):
	if current_state == STATE.DEAD: return
	if current_state == new_state: return
	
	# Exit current state logic
	match current_state:
		STATE.ATTACK:
			is_attacking = false
			if kilic_collider: kilic_collider.set_deferred("disabled", true)
	
	current_state = new_state
	
	# Enter new state logic
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
			start_attack_sequence()
		STATE.DEAD:
			velocity.x = 0
			die()

# --- STATE LOGIC ---
func idle_state():
	velocity.x = 0
	if has_target: transition_to_state(STATE.CHASE)

func patrol_state():
	if not turn_cooldown:
		if is_on_wall() or not ucurum_sensoru.is_colliding():
			direction *= -1
			turn_cooldown = true
			await get_tree().create_timer(1.0).timeout
			turn_cooldown = false

	velocity.x = direction * patrol_speed
	anim.play("Walk")
	
	if sfx_yurume and not sfx_yurume.playing: 
		sfx_yurume.play()
		
	if has_target: transition_to_state(STATE.CHASE)

func chase_state(delta):
	var player = get_tree().get_first_node_in_group("oyuncu")
	if not player:
		transition_to_state(STATE.PATROL)
		return

	# Memory Logic
	if has_target:
		memory_timer = memory_duration
	else:
		memory_timer -= delta
		if memory_timer <= 0:
			transition_to_state(STATE.PATROL)
			return

	# Face Player
	direction = sign(player.global_position.x - global_position.x)
	if direction == 0: direction = 1
	
	var distance = abs(player.global_position.x - global_position.x)
	
	# Attack Range Check
	if distance < attack_range:
		if attack_timer <= 0:
			transition_to_state(STATE.ATTACK)
		else:
			velocity.x = 0
			anim.play("Idle")
		return 

	velocity.x = direction * chase_speed
	anim.play("Walk")

func attack_state():
	velocity.x = 0 

func hurt_state(delta):
	velocity.x = move_toward(velocity.x, 0, 400 * delta)

func update_direction_visuals():
	if direction > 0:
		anim.flip_h = false
		pivot.scale.x = 1
	else:
		anim.flip_h = true
		pivot.scale.x = -1

# --- COMBAT & HEALTH ---
func hasar_al(amount):
	if current_state == STATE.DEAD or is_dead: return
	
	current_health -= amount
	if sfx_hasar: sfx_hasar.play()
	
	# Visual Feedback (Flash White)
	var sprite = $AnimatedSprite2D 
	sprite.modulate = Color(10, 10, 10, 1)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	
	if current_health <= 0:
		transition_to_state(STATE.DEAD)
	else:
		transition_to_state(STATE.HURT)

func die():
	if is_dead: return
	is_dead = true
	
	if sfx_yurume: sfx_yurume.stop()
	anim.play("Death")
	
	# Anti-Corpse Soccer: Disable collisions with player/enemies, keep floor
	set_deferred("collision_layer", 0) 
	set_deferred("collision_mask", 1)  
	
	if kilic_collider:
		kilic_collider.set_deferred("disabled", true)
	
	# Fade out and free
	await get_tree().create_timer(5.0).timeout
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()

func start_attack_sequence():
	# Telegraphing (Warning color)
	anim.play("Idle")
	anim.modulate = Color(0.8, 0.5, 0.5) 
	await get_tree().create_timer(0.2).timeout
	
	if current_state != STATE.ATTACK: 
		anim.modulate = Color(1, 1, 1)
		return
		
	anim.modulate = Color(1, 1, 1)
	anim.play("Attack") 
	if sfx_saldiri: sfx_saldiri.play()
	
	# Wait for impact frame (approximate)
	await get_tree().create_timer(0.2).timeout
	if current_state != STATE.ATTACK: return
	perform_hit_check()

func perform_hit_check():
	if current_state != STATE.ATTACK: return
	
	kilic_collider.disabled = false
	await get_tree().create_timer(0.05).timeout
	
	var bodies = kilic_alani.get_overlapping_bodies()
	
	for body in bodies:
		if body == self: continue
		if body.is_in_group("oyuncu"):
			if body.has_method("hasar_al"):
				body.hasar_al(damage_amount)
	
	await get_tree().create_timer(0.1).timeout
	if kilic_collider: kilic_collider.disabled = true

# --- SIGNAL CALLBACKS ---

func _on_vision_area_body_entered(body):
	if body.is_in_group("oyuncu"):
		has_target = true
		if current_state == STATE.PATROL or current_state == STATE.IDLE:
			transition_to_state(STATE.CHASE)

func _on_vision_area_body_exited(body):
	if body.is_in_group("oyuncu"):
		has_target = false

func _on_anim_finished():
	if anim.animation == "Hurt" and current_state == STATE.HURT:
		if current_health > 0:
			if has_target: transition_to_state(STATE.CHASE)
			else: transition_to_state(STATE.PATROL)
	elif anim.animation == "Attack" and current_state == STATE.ATTACK:
		attack_timer = attack_cooldown
		if has_target: transition_to_state(STATE.CHASE)
		else: transition_to_state(STATE.PATROL)
