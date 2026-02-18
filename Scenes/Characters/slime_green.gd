extends CharacterBody2D

# --- AYARLAR ---
@export var speed: float = 100.0       # Zıplama ileri hızı
@export var jump_force: float = -350.0 # Zıplama gücü (Biraz daha artırdım, daha tok zıplasın)
@export var gravity: float = 980.0
@export var max_health: int = 35
@export var damage: int = 15

# --- DURUMLAR (STATE MACHINE) ---
enum STATES { PATROL, CHASE, HURT }
var current_state = STATES.PATROL
var current_health: int

# --- ZAMANLAYICILAR VE KONTROLLER ---
var jump_timer: float = 0.0
var was_on_floor: bool = true # Yere inişi anlamak için hafıza değişkeni

# --- NODE REFERANSLARI ---
@onready var anim = $AnimatedSprite2D
@onready var ucurum_sensoru = $UcurumSensoru  # RayCast2D
@onready var detection_area = $DetectionArea  # Bizi gören alan
@onready var hitbox = $Hitbox                 # Bize vuran alan
@onready var kan_efekti = $KanEfekti
# --- DEĞİŞKENLER ---
var direction = 1 # 1: Sağ, -1: Sol
var player = null

func _ready():
	current_health = max_health
	# Sensor başlangıçta mutlak pozitif (sağ) konumda başlasın
	ucurum_sensoru.position.x = abs(ucurum_sensoru.position.x)
	
	if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
		detection_area.body_entered.connect(_on_detection_area_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta):
	# 1. YERÇEKİMİ
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Yerdeysek sürtünme uygula
		velocity.x = move_toward(velocity.x, 0, 20)
	
	# 🌟 CİLA: Yere İniş Efekti (Landing Squash)
	# Eğer şu an yerdeysek AMA geçen karede havadaysak -> Yere yeni inmişizdir!
	if is_on_floor() and not was_on_floor:
		ezil_buzul_efekti(0.18, 0.10)
	
	was_on_floor = is_on_floor() # Durumu kaydet
	
	# 2. STATE MACHINE
	match current_state:
		STATES.PATROL:
			patrol_state(delta)
		STATES.CHASE:
			chase_state(delta)
		STATES.HURT:
			hurt_state(delta)
	
	move_and_slide()

# ==============================================================================
# 🧠 MANUEL DURUM FONKSİYONLARI
# ==============================================================================

func patrol_state(delta):
	anim.play("Idle")
	
	if is_on_floor():
		jump_timer -= delta
		
		# Duvar veya Uçurum Kontrolü
		if is_on_wall() or not ucurum_sensoru.is_colliding():
			direction *= -1
			yon_gorselini_cevir()
		
		# Süre dolduysa ZIPLA!
		if jump_timer <= 0:
			velocity.y = jump_force           # Yukarı fırlat
			velocity.x = speed * direction    # İleri fırla
			
			# CİLA: Zıplarken incel ve uza
			ezil_buzul_efekti(0.10, 0.18)  
			
			jump_timer = 2.0 + randf_range(-0.5, 0.5) # Rastgelelik ekledim, robot gibi olmasın

func chase_state(delta):
	anim.play("Idle")
	
	if is_on_floor():
		jump_timer -= delta
		
		# Oyuncuya dön
		if player:
			var direction_check = sign(player.global_position.x - global_position.x)
			if direction_check != 0:
				direction = direction_check
			yon_gorselini_cevir()
		
		# Süre dolduysa SALDIRGAN ZIPLA!
		if jump_timer <= 0:
			velocity.y = jump_force           # Yukarı fırlat
			velocity.x = speed * 1.5 * direction # Daha hızlı atıl
			
			# CİLA: Kovalarken de efekt çalışsın (Unutulmuştu)
			ezil_buzul_efekti(0.10, 0.18)
			
			jump_timer = 0.8 # Çok daha seri zıplasın (Agresif mod)

func hurt_state(delta):
	# Hasar alınca savrulma hareketi
	velocity.x = move_toward(velocity.x, 0, 10)
	anim.play("Idle") 

# ==============================================================================
# 🛠️ YARDIMCI FONKSİYONLAR
# ==============================================================================

func yon_gorselini_cevir():
	# 1. Yön Tayini
	var bakilan_yon = 1 
	if direction < 0: bakilan_yon = -1
	
	# 2. Sprite Çevir
	anim.flip_h = (bakilan_yon == -1)

	# 3. Sensor Çevir (Mutlak değer alıp yönle çarpıyoruz, en garantisi)
	var mesafe = abs(ucurum_sensoru.position.x)
	ucurum_sensoru.position.x = mesafe * bakilan_yon

func ezil_buzul_efekti(x_hedef, y_hedef):
	var tween = create_tween()
	
	# 1. Hedeflenen ezilme boyutuna git
	tween.tween_property(anim, "scale", Vector2(x_hedef, y_hedef), 0.1).set_trans(Tween.TRANS_SINE)
	
	# 2. SENİN ORİJİNAL BOYUTUNA (0.14) GERİ DÖN
	tween.tween_property(anim, "scale", Vector2(0.14, 0.14), 0.1).set_trans(Tween.TRANS_SINE)

func hasar_al(miktar):
	current_health -= miktar
	kan_efekti.restart() 
	kan_efekti.emitting = true
	current_state = STATES.HURT
	
	# Geri tepme (Knockback)
	velocity.y = -200
	velocity.x = -direction * 100
	
	# CİLA: Hasar rengi
	anim.modulate = Color(10, 10, 10, 1) # BEYAZ PARLAMA (Flash efekti daha çok belli olur)
	ezil_buzul_efekti(0.16, 0.12)
	
	await get_tree().create_timer(0.1).timeout
	anim.modulate = Color(0.16, 0.427, 0.106, 1.0) # Yeşilimsi tona dön
	
	await get_tree().create_timer(0.3).timeout
	anim.modulate = Color(1, 1, 1) # Normale dön
	
	if current_health <= 0:
		queue_free() # Ölüm efekti eklenebilir
	else:
		current_state = STATES.CHASE # Tekrar saldır

# ==============================================================================
# 📡 SİNYALLER
# ==============================================================================

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("oyuncu"):
		player = body
		current_state = STATES.CHASE
		jump_timer = 0.1 # Görür görmez hemen zıplasın

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("oyuncu"):
		player = null
		current_state = STATES.PATROL
		jump_timer = 1.0 # Sakinleşsin

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("oyuncu") and body.has_method("hasar_al"):
		body.hasar_al(damage)
