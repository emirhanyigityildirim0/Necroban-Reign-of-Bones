extends CharacterBody2D

# --- AYARLAR ---
@export var speed: float = 70.0
@export var chase_speed: float = 120.0
@export var gravity: float = 980.0
@export var max_health: int = 100
@export var kilic_hasari: int = 25
@export var büyü_bekleme_suresi: float = 4.0

@export var mezar_tasi_sahnesi: PackedScene 

# --- DURUMLAR (STATE MACHINE) ---
enum STATES { PATROL, CHASE, MELEE_ATTACK, RANGED_ATTACK, HURT, DEATH }
var current_state = STATES.PATROL
var current_health: int

# --- KONTROLLER ---
var direction = 1
var player = null
var buyu_sayaci: float = 0.0
var saldiriyor_mu: bool = false 

# --- REFERANSLAR ---
@onready var anim = $AnimatedSprite2D
@onready var pivot = $SaldiriPivotu
@onready var ucurum_sensoru = $SaldiriPivotu/UcurumSensoru
@onready var saldiri_sensoru = $SaldiriPivotu/SaldiriSensoru 
@onready var kilic_alani = $SaldiriPivotu/KilicAlani
@onready var detection_area = $SaldiriPivotu/DetectionArea
@onready var hitbox = $SaldiriPivotu/Hitbox

# --- SESLER ---
@onready var sfx_yurume = $SfxYurume
@onready var sfx_saldiri = $SfxSaldiri
@onready var sfx_hasar = $SfxHasar

func _ready():
	current_health = max_health
	kilic_alani.monitoring = false 
	buyu_sayaci = 2.0
	
	# Sinyalleri hazırla

	if not detection_area.body_entered.is_connected(_on_gorus_alani_girdi):
		detection_area.body_entered.connect(_on_gorus_alani_girdi)
	if not detection_area.body_exited.is_connected(_on_gorus_alani_cikti):
		detection_area.body_exited.connect(_on_gorus_alani_cikti)
	if not kilic_alani.body_entered.is_connected(_on_kilic_vurdu):
		kilic_alani.body_entered.connect(_on_kilic_vurdu)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if current_state != STATES.PATROL and current_state != STATES.CHASE:
			velocity.x = move_toward(velocity.x, 0, 20)

	if buyu_sayaci > 0:
		buyu_sayaci -= delta

	match current_state:
		STATES.PATROL:
			patrol_state(delta)
		STATES.CHASE:
			chase_state(delta)
		STATES.MELEE_ATTACK:
			pass 
		STATES.RANGED_ATTACK:
			pass 
			
	move_and_slide()

# ==============================================================================
# 🧠 DURUM FONKSİYONLARI
# ==============================================================================

func patrol_state(delta):
	velocity.x = speed * direction
	anim.play("Walk")
	yon_guncelle()
	
	if is_on_wall() or not ucurum_sensoru.is_colliding():
		direction *= -1
		yon_guncelle()
		ucurum_sensoru.force_raycast_update()
		
	# 🛠️ BUG ÇÖZÜMÜ 1: Eğer oyuncu zaten alanın içindeyse ve unutulduysa, radarda gör!
	var icerdekiler = detection_area.get_overlapping_bodies()
	for b in icerdekiler:
		if b.is_in_group("oyuncu"):
			player = b
			current_state = STATES.CHASE

func chase_state(delta):
	if player:
		if saldiri_sensoru.is_colliding():
			var collider = saldiri_sensoru.get_collider()
			if collider and collider.is_in_group("oyuncu"):
				yakin_saldiri_yap()
				return 
		
		if buyu_sayaci <= 0:
			uzak_saldiri_yap()
			return

		var player_yonu = sign(player.global_position.x - global_position.x)
		if player_yonu != 0:
			direction = player_yonu
			
		yon_guncelle()
		velocity.x = chase_speed * direction
		anim.play("Walk")

# ==============================================================================
# ⚔️ SALDIRI FONKSİYONLARI
# ==============================================================================

func yakin_saldiri_yap():
	if saldiriyor_mu: return
	saldiriyor_mu = true
	current_state = STATES.MELEE_ATTACK
	velocity.x = 0 
	
	anim.play("Attack")
	if sfx_saldiri: sfx_saldiri.play()
	
	await anim.animation_finished
	
	kilic_alani.monitoring = false 
	saldiriyor_mu = false
	if player:
		current_state = STATES.CHASE
	else:
		current_state = STATES.PATROL

func uzak_saldiri_yap():
	if saldiriyor_mu: return 
	saldiriyor_mu = true
	current_state = STATES.RANGED_ATTACK
	velocity.x = 0 
	
	anim.play("TombStoneAttack")
	
	await anim.animation_finished
	
	buyu_sayaci = büyü_bekleme_suresi
	saldiriyor_mu = false
	if player:
		current_state = STATES.CHASE
	else:
		current_state = STATES.PATROL

func mezari_cagir():
	if player and mezar_tasi_sahnesi:
		var yeni_tas = mezar_tasi_sahnesi.instantiate()
		yeni_tas.global_position = player.global_position 
		get_tree().current_scene.add_child(yeni_tas)

# ==============================================================================
# 🛠️ YARDIMCI FONKSİYONLAR
# ==============================================================================

func yon_guncelle():
	if direction != 0:
		anim.flip_h = (direction < 0)
		pivot.scale.x = abs(pivot.scale.x) * direction

func hasar_al(miktar):
	if current_state == STATES.DEATH: return
	
	current_health -= miktar
	current_state = STATES.HURT
	saldiriyor_mu = false
	kilic_alani.set_deferred("monitoring", false) 
	
	velocity.y = -150
	velocity.x = -direction * 50
	
	anim.play("Hurt")
	if sfx_hasar: sfx_hasar.play()
	
	await anim.animation_finished
	
	if current_health <= 0:
		olum()
	else:
		if player: current_state = STATES.CHASE
		else: current_state = STATES.PATROL

func olum():
	current_state = STATES.DEATH
	velocity.x = 0
	pivot.queue_free() 
	
	anim.play("Death")
	await anim.animation_finished
	await get_tree().create_timer(1.0).timeout
	queue_free()

# ==============================================================================
# 📡 SİNYALLER (BUG ÇÖZÜMLERİ BURADA)
# ==============================================================================

func _on_gorus_alani_girdi(body):
	if body.is_in_group("oyuncu"):
		player = body
		if current_state != STATES.HURT and current_state != STATES.DEATH:
			current_state = STATES.CHASE

func _on_gorus_alani_cikti(body):
	if body.is_in_group("oyuncu"):
		player = null
		# 🛠️ BUG ÇÖZÜMÜ 2: Sadece "Kovalıyorsan" Patrol'a dön. 
		if current_state == STATES.CHASE:
			current_state = STATES.PATROL

func _on_kilic_vurdu(body):
	if body.is_in_group("oyuncu") and body.has_method("hasar_al"):
		body.hasar_al(kilic_hasari)

func _on_animated_sprite_2d_frame_changed() -> void:
	if anim.animation == "Attack":
		if anim.frame == 6: 
			kilic_alani.monitoring = true
		elif anim.frame > 6:
			kilic_alani.monitoring = false
			
	elif anim.animation == "TombStoneAttack" or anim.animation == "ThombStone":
		if anim.frame == 8:
			mezari_cagir()
