extends CharacterBody2D

# --- AYARLAR ---
@export var max_health = 400
@export var speed = 160 
@export var attack_range = 55
@export var damage = 25

# --- REFERANSLAR ---
@onready var anim = $AnimatedSprite2D
@onready var player = null 

# --- DURUM MAKİNESİ ---
enum State { IDLE, CHASE, ATTACK, DEATH }
var current_state = State.IDLE
var current_health = 0
var is_attacking = false 
var has_dealt_damage = false 

func _ready():
	current_health = max_health
	add_to_group("dusman")
	
	# Oyuncuyu bul
	var players = get_tree().get_nodes_in_group("oyuncu")
	if players.size() > 0:
		player = players[0]
		
	# Animasyon bitişini dinle
	anim.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	# Öldüyse veya saldırıyorsa hareket etme
	if current_state == State.DEATH or is_attacking:
		return 

	match current_state:
		State.IDLE:
			anim.play("Idle")
			velocity = Vector2.ZERO
			if player: change_state(State.CHASE)
			
		State.CHASE:
			if player:
				var mesafe = global_position.distance_to(player.global_position)
				
		
				if player.global_position.x < global_position.x:
					anim.flip_h = true  # Sola bak
			
				else:
					anim.flip_h = false # Sağa bak

				if mesafe <= attack_range:
					change_state(State.ATTACK)
				else:
					anim.play("Run")
					velocity = position.direction_to(player.global_position) * speed
	
	move_and_slide()


func _process(delta):

	if current_state == State.ATTACK and not has_dealt_damage:

		if anim.frame == 9: 
			if player and global_position.distance_to(player.global_position) <= attack_range + 10:
				if player.has_method("hasar_al"):
					player.hasar_al(damage)
					has_dealt_damage = true 

func change_state(new_state):
	current_state = new_state
	
	if new_state == State.ATTACK:
		is_attacking = true
		has_dealt_damage = false 
		anim.play("Attack")
		
	elif new_state == State.DEATH:
		velocity = Vector2.ZERO
		anim.play("Death") 
		
		$CollisionShape2D.set_deferred("disabled", true)

func _on_animation_finished():
	if current_state == State.ATTACK:
		is_attacking = false
		change_state(State.CHASE) # Saldırı bitti, kovalamaya dön
		
	elif current_state == State.DEATH:
		queue_free() # Animasyon bitti, boss silinsin

func hasar_al(miktar):
	if current_state == State.DEATH: return
	
	current_health -= miktar
	
	# Can 0 olunca öl
	if current_health <= 0:
		change_state(State.DEATH)

	
