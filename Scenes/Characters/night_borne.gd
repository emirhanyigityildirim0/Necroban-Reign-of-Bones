extends CharacterBody2D

# --- AYARLAR ---
@export var max_health = 150
@export var speed = 160
@export var damage = 25
@export var gravity = 980

# --- REFERANSLAR ---
@onready var anim = $AnimatedSprite2D

# PIVOT VE SENSÖRLER
@onready var saldiri_pivotu = $SaldiriPivotu
@onready var saldiri_sensoru = $SaldiriPivotu/SaldiriSensoru 
@onready var saldiri_alani = $SaldiriPivotu/Saldiri_Alani   
@onready var ucurum_sensoru = $SaldiriPivotu/UcurumSensoru
@onready var kafa_kaydirak = $KafaKaydirak 

# SES EFEKTLERİ
@onready var sfx_saldiri = $SfxSaldiri
@onready var sfx_hasar = $SfxHasar
@onready var sfx_yurume = $SfxYurume
@onready var sfx_olum = $SfxDeath 

@onready var player = null

# --- DURUM MAKİNESİ ---
enum State { IDLE, CHASE, ATTACK, HURT, DEATH }
var current_state = State.IDLE
var current_health = 0
var is_attacking = false
var has_dealt_damage = false 

# Ses Kilitleri
var saldiri_sesi_calindi = false 
var olum_sesi_calindi = false

func _ready():
	current_health = max_health
	add_to_group("dusman")
	
	var players = get_tree().get_nodes_in_group("oyuncu")
	if players.size() > 0:
		player = players[0]
	
	anim.animation_finished.connect(_on_animation_finished)
	
	# Kafa Kaydırak Bağlantısı
	if kafa_kaydirak:
		if not kafa_kaydirak.body_entered.is_connected(_on_kafa_kaydirak_body_entered):
			kafa_kaydirak.body_entered.connect(_on_kafa_kaydirak_body_entered)

func _physics_process(delta):
	
	if current_state == State.DEATH:
		velocity = Vector2.ZERO 
		return 

	# Yerçekimi
	if not is_on_floor():
		velocity.y += gravity * delta


	if is_attacking or current_state == State.HURT:
		velocity.x = move_toward(velocity.x, 0, speed) 
		move_and_slide()
		return

	match current_state:
		State.IDLE:
			anim.play("Idle")
			velocity.x = 0
			sfx_yurume.stop()
			if player: change_state(State.CHASE)

		State.CHASE:
			if player:
				# GLITCH ÖNLEYİCİ
				var fark_x = player.global_position.x - global_position.x
				
				if abs(fark_x) > 10:
					yonu_ayarla(fark_x)

				if saldiri_sensoru.is_colliding():
					var carpan = saldiri_sensoru.get_collider()
					if carpan.is_in_group("oyuncu"):
						change_state(State.ATTACK)
						velocity.x = 0 
						sfx_yurume.stop()
				

				else:
					if not ucurum_sensoru.is_colliding() and is_on_floor():
						velocity.x = 0
						anim.play("Idle")
						sfx_yurume.stop()
					else:
						anim.play("Run")
						velocity.x = sign(fark_x) * speed
						if not sfx_yurume.playing:
							sfx_yurume.play()

	move_and_slide()


func _on_kafa_kaydirak_body_entered(body):
	if body.is_in_group("oyuncu"):

		change_state(State.ATTACK)
		

		if "velocity" in body:
			var itme_yonu = 1
			if body.global_position.x < global_position.x:
				itme_yonu = -1
			

			body.velocity = Vector2(itme_yonu * 100, -150)
			


# --- YÖN AYARLAMA ---
func yonu_ayarla(dir_x):
	if dir_x < 0: # Sola bak
		anim.flip_h = true
		saldiri_pivotu.scale.x = -1 
	else: # Sağa bak
		anim.flip_h = false
		saldiri_pivotu.scale.x = 1

# --- SALDIRI KUTUSU (AREA2D) İLE HASAR ---
func _process(delta):
	
	if current_state == State.ATTACK:
		
		# 1. SES (Frame 8)
		if anim.frame == 8 and not saldiri_sesi_calindi:
			if sfx_saldiri: sfx_saldiri.play()
			saldiri_sesi_calindi = true 
			
		# 2. HASAR VE KNOCKBACK (Frame 9-10)
		if not has_dealt_damage and (anim.frame >= 9 and anim.frame <= 10):
			
			# --- BURASI DEĞİŞTİ: RAYCAST YERİNE AREA2D KULLANIYORUZ ---
			# Saldiri_Alani (Kutu) içindeki herkesi bul
			var vurulanlar = saldiri_alani.get_overlapping_bodies()
			
			for hedef in vurulanlar:
				# Sadece oyuncuya vur
				if hedef.is_in_group("oyuncu") and hedef.has_method("hasar_al"):
					if hedef.get("can_hasar_alabilir") == false:
						continue
					print("⚔️ Boss Kutuyla (Area2D) Vurdu!")
					hedef.hasar_al(damage)
					has_dealt_damage = true # Tek vuruş kilidi
					
					# Knockback (Boss nereye bakıyorsa o tarafa uçsun)
					if "velocity" in hedef:
						var vurus_yonu = -1 if anim.flip_h else 1
						hedef.velocity = Vector2(vurus_yonu * 450, -250)
					
					# Bir kişiye vurunca döngüden çıkabiliriz (veya çoklu vuruş için kalabilir)
					# break 

	# --- ÖLÜM AYARLARI ---
	elif current_state == State.DEATH:
		if anim.animation == "Death":
			
			if anim.frame == 12 and not olum_sesi_calindi:
				if sfx_olum: sfx_olum.play()
				olum_sesi_calindi = true
			
			if anim.frame == anim.sprite_frames.get_frame_count("Death") - 1:
				queue_free()

func change_state(new_state):
	if current_state == State.CHASE and new_state != State.CHASE:
		sfx_yurume.stop()

	current_state = new_state
	
	if new_state == State.ATTACK:
		is_attacking = true
		has_dealt_damage = false
		saldiri_sesi_calindi = false
		anim.play("Attack")
		
	elif new_state == State.DEATH:
		velocity = Vector2.ZERO 
		olum_sesi_calindi = false 
		
		await get_tree().create_timer(0.3).timeout
		anim.play("Hurt")
		await get_tree().create_timer(0.3).timeout
		
		anim.play("Death")
		$CollisionShape2D.set_deferred("disabled", true)
		
	elif new_state == State.HURT:
		is_attacking = false 
		velocity.x = 0
		anim.play("Hurt")
		if sfx_hasar: sfx_hasar.play()

func _on_animation_finished():
	if current_state == State.ATTACK:
		is_attacking = false
		change_state(State.CHASE)
		
	elif current_state == State.DEATH and anim.animation == "Death":
		queue_free()
	
	elif current_state == State.HURT:
		change_state(State.CHASE)

# --- HASAR ALMA ---
func hasar_al(miktar):
	if current_state == State.DEATH: return
	if sfx_hasar: sfx_hasar.play()
	current_health -= miktar
	print("🩸 Boss Canı: ", current_health)
	
	if current_health <= 0:
		change_state(State.DEATH)
		return


	if current_state == State.ATTACK:
	
		anim.modulate = Color(0.814, 0.505, 1.0, 1.0)
		await get_tree().create_timer(0.15).timeout
		anim.modulate = Color(0.482, 0.001, 0.67, 1.0)
		await get_tree().create_timer(0.15).timeout
		anim.modulate = Color(1, 1, 1)
		return 

	if current_state == State.HURT:
		return 
	
	change_state(State.HURT)
