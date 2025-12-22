extends CharacterBody2D

# --- SETTINGS AND VARIABLES ---

@export_category("Movement Settings")
@export var speed: float = 250.0
@export var jump_force: float = -450.0
@export var gravity: float = 980.0
@export var max_jumps: int = 2 # 2 = Double Jump

@export_category("Combat Settings")
@export var damage_heavy: int = 20 # First hit damage
@export var damage_light: int = 10 # Combo hit damage
@export var knockback_force: float = 1.5
@export var hitstop_duration: float = 0.1

@export_group("Dialogue Settings")
var diyalog_kutusu: CanvasLayer 
var diyalog_label: Label        

# --- SCENE REFERENCES (Preload) ---
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

# --- NODE REFERENCES (@onready) ---
@onready var anim = $AnimatedSprite2D
@onready var pivot = $SaldiriPivotu 
@onready var saldiri_alani = $SaldiriPivotu/SaldiriAlani
@onready var saldiri_collision = $SaldiriPivotu/SaldiriAlani/CollisionShape2D

# Audio Nodes (Using get_node_or_null to prevent crashes if nodes are missing)
@onready var sfx_yurume = get_node_or_null("SfxYurume")
@onready var sfx_ziplama = get_node_or_null("SfxZiplama")
@onready var sfx_hasar = get_node_or_null("SfxHasar")
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")
@onready var sfx_flask = get_node_or_null("SfxFlask")
@onready var sfx_Death = get_node_or_null("SfxDeath")

# --- SIGNALS ---
signal player_died

func _ready():
	add_to_group("oyuncu") # "oyuncu" group
	
	# Initial setup
	if sfx_yurume: sfx_yurume.volume_db = yurume_sesi_db
	if saldiri_collision: saldiri_collision.disabled = true
	
	# Connect to UI
	ui_baglantisini_kur()

func ui_baglantisini_kur():
	var bulunan_ui = get_tree().current_scene.find_child("DiyalogKatmani", true, false)
	if bulunan_ui:
		diyalog_kutusu = bulunan_ui
		var bulunan_label = diyalog_kutusu.find_child("Label", true, false)
		if bulunan_label:
			diyalog_label = bulunan_label
			print(">> PLAYER: Connected to Dialogue System.")
		else:
			push_warning("DialogueLayer found but it has no 'Label' child!")
	else:
		# Not a critical error, maybe the scene has no dialogue.
		pass 

func _physics_process(delta):
	# State Checks (Priority Order)
	if cutscene_active:
		handle_cutscene(delta)
		return 

	if is_dead: return
	
	if is_hurt:
		apply_gravity(delta)
		move_and_slide()
		return

	if is_attacking:
		velocity.x = 0 # Prevent sliding while attacking
		apply_gravity(delta) # Continue falling if attacking in air
		move_and_slide()
		return
	
	# Combo Timer Logic
	if combo_sayaci > 0:
		combo_zamanlayicisi -= delta
		if combo_zamanlayicisi <= 0:
			combo_sayaci = 0

	# --- MOVEMENT LOGIC ---
	apply_gravity(delta)
	handle_jump()
	handle_movement()
	
	move_and_slide()
	update_animations()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jump_count = 0 # Reset jumps when on floor

func handle_cutscene(delta):
	velocity.x = 0 
	if not is_on_floor():
		velocity.y += gravity * delta
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
		# --- MENTOR TOUCH: Organic Audio ---
		# Generate a random pitch between 0.9 and 1.1 to avoid robotic repetition
		var random_pitch = randf_range(0.9, 1.1)
		if jump_count == 2:
			# Higher pitch for the double jump
			sfx_ziplama.pitch_scale = random_pitch + 0.2
		else:
			sfx_ziplama.pitch_scale = random_pitch
		sfx_ziplama.play()

func handle_movement():
	# Attack Input
	if Input.is_action_just_pressed("saldiri") and is_on_floor():
		saldiri_yap()
		return

	# Movement Input
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

func _unhandled_input(event):
	if event.is_action_pressed("use_flask"): 
		use_flask()

func use_flask():
	if is_dead or is_attacking: return
	
	# Check for Global singleton
	if not Global: return

	if Global.current_flasks > 0 and Global.can < Global.max_can:
		Global.current_flasks -= 1
		Global.can += Global.flask_heal_amount
		if Global.can > Global.max_can:
			Global.can = Global.max_can
		
		if sfx_flask:
			sfx_flask.stop()
			sfx_flask.play()
	
		print("Flask used. Remaining: ", Global.current_flasks)
		get_tree().call_group("hud_group", "update_hud")
	elif Global.current_flasks == 0:
		print("No flasks left!")

func update_animations():
	# Animation Priority Check
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

func saldiri_yap():
	if is_attacking: return
	
	is_attacking = true
	combo_sayaci += 1
	combo_zamanlayicisi = combo_sifirlama_suresi
	
	if sfx_saldiri: sfx_saldiri.play()
	
	# Trigger GameFeel (Screen shake/Hitstop)
	if GameFeel:
		GameFeel.vur(knockback_force, hitstop_duration)
	
	# Animation Selection based on combo count
	if combo_sayaci == 1: anim.play("Attack1")
	elif combo_sayaci == 2: anim.play("Attack2")
	elif combo_sayaci >= 3:
		anim.play("Attack3")
		combo_sayaci = 0 # Reset combo

	# Damage Logic (Using timers to sync with animation frames)
	await get_tree().create_timer(0.2).timeout
	saldiri_collision.disabled = false
	
	# Wait for physics frame to ensure collision detection
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var dusmanlar = saldiri_alani.get_overlapping_bodies()
	
	for dusman in dusmanlar:
		if dusman != self and dusman.has_method("hasar_al"):
			# Apply damage based on export variables
			if combo_sayaci <= 1: # First hit or reset
				dusman.hasar_al(damage_heavy)
			else:
				dusman.hasar_al(damage_light)

	await get_tree().create_timer(0.1).timeout
	saldiri_collision.disabled = true
	
	await anim.animation_finished
	is_attacking = false

func hasar_al(miktar):
	if is_dead: return
	if not can_hasar_alabilir: return
	
	if Global:
		Global.can -= miktar
	
	if sfx_hasar: sfx_hasar.play()
	
	is_hurt = true # Lock movement
	can_hasar_alabilir = false
	anim.modulate = Color(1, 0, 0)
	
	# Optional: Add knockback logic here
	
	await get_tree().create_timer(0.5).timeout
	
	anim.modulate = Color(1, 1, 1)
	can_hasar_alabilir = true
	is_hurt = false
	
	if Global and Global.can <= 0:
		olum_gerceklesti()

func olum_gerceklesti():
	if is_dead: return # Prevent double trigger
	is_dead = true
	velocity = Vector2.ZERO
	anim.play("Death")
	$CollisionShape2D.set_deferred("disabled", true)
	
	if sfx_yurume: sfx_yurume.stop()
	if sfx_Death: sfx_Death.play()
	
	emit_signal("player_died") 
	
	await get_tree().create_timer(1.0).timeout
	
	Engine.time_scale = 0.3 # Slow motion effect on death
	var ekran = game_over_sahnesi.instantiate()
	get_tree().root.add_child(ekran)

func cutscene_moduna_gec():
	cutscene_active = true 
	velocity = Vector2.ZERO 
	
func konus(cumle: String):
	if not diyalog_kutusu or not diyalog_label:
		push_error("Dialogue System is NOT connected!")
		return
	
	su_an_konusuyor = true
	diyalog_kutusu.visible = true
	diyalog_label.text = cumle
	diyalog_label.visible_characters = 0
	diyalog_label.modulate = Color(0.4, 0.8, 1.0) 
	
	# Typewriter effect
	for i in range(cumle.length()):
		diyalog_label.visible_characters = i + 1
		await get_tree().create_timer(0.04).timeout
	
	await get_tree().create_timer(2.0).timeout
	diyalog_kutusu.visible = false
	su_an_konusuyor = false
