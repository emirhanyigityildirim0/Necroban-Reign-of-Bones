extends CharacterBody2D

var cutscene_active = false

@export var speed = 250.0
@export var jump_force = -450.0
@export var gravity = 980.0
# --- YENİ EKLENTİ: Çift Zıplama Ayarları ---
@export var max_jumps = 2 # Kaç kere zıplayabilir? (2 = Çift Zıplama)
var jump_count = 0        # Şu an kaçıncı zıplamada?

var game_over_sahnesi = preload("res://Scenes/UI/DeathScreen.tscn")

@export_group("Diyalog Ayarları")
var diyalog_kutusu: CanvasLayer 
var diyalog_label: Label        
var su_an_konusuyor = false

var can_hasar_alabilir = true 
signal player_died

# --- PIVOT REFERANSI ---
@onready var pivot = $SaldiriPivotu 

# --- KOMBO AYARLARI ---
var combo_sayaci = 0
var combo_sifirlama_suresi = 0.8
var combo_zamanlayicisi = 0.0

# --- DURUM DEĞİŞKENLERİ ---
var is_attacking = false
var is_dead = false
var is_hurt = false
var yurume_sesi_db = -15.0

@onready var anim = $AnimatedSprite2D

# --- DÜĞÜMLER ---
@onready var sfx_yurume = get_node_or_null("SfxYurume")
@onready var sfx_ziplama = get_node_or_null("SfxZiplama")
@onready var sfx_hasar = get_node_or_null("SfxHasar")
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")
@onready var sfx_flask = get_node_or_null("SfxFlask")
@onready var sfx_Death = get_node_or_null("SfxDeath")
@onready var saldiri_alani = $SaldiriPivotu/SaldiriAlani
@onready var saldiri_collision = $SaldiriPivotu/SaldiriAlani/CollisionShape2D

func _ready():
	if sfx_yurume:
		sfx_yurume.volume_db = yurume_sesi_db
	if saldiri_collision:
		saldiri_collision.disabled = true
	add_to_group("oyuncu")
	var bulunan_ui = get_tree().current_scene.find_child("DiyalogKatmani", true, false)
	
	if bulunan_ui:
		diyalog_kutusu = bulunan_ui
		var bulunan_label = diyalog_kutusu.find_child("Label", true, false)
		if bulunan_label:
			diyalog_label = bulunan_label
			print(">> OYUNCU: Diyalog sistemine başarıyla bağlandı! Hazırım komutanım.")
		else:
			print("!!! HATA: DiyalogKatmani bulundu ama içinde 'Label' yok!")
	else:
		print("!!! HATA: Sahnede 'DiyalogKatmani' isimli düğüm bulunamadı!")

func _physics_process(delta):
	# Cutscene Kontrolü
	if cutscene_active:
		velocity.x = 0 
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		if has_node("AnimatedSprite2D"): $AnimatedSprite2D.play("Idle")
		if sfx_yurume: sfx_yurume.stop()
		return 

	if is_dead: return
	
	if is_hurt:
		velocity.y += gravity * delta
		move_and_slide()
		return

	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return
	
	# Kombo Zamanlayıcısı
	if combo_sayaci > 0 and not is_attacking:
		combo_zamanlayicisi -= delta
		if combo_zamanlayicisi <= 0:
			combo_sayaci = 0

	# --- YERÇEKİMİ VE ZIPLAMA SIFIRLAMA ---
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Yere değdiğimiz an zıplama sayacını sıfırla
		jump_count = 0

	# --- GÜNCELLENMİŞ ZIPLAMA MANTIĞI (DOUBLE JUMP) ---
	if Input.is_action_just_pressed("ui_accept"):
		# Sadece yerde olması gerekmiyor, hakkı varsa zıplayabilir
		if jump_count < max_jumps:
			velocity.y = jump_force
			jump_count += 1
			if sfx_ziplama: 
				sfx_ziplama.play()
				# Eğer ikinci zıplamaysa sesin tonunu biraz değiştirebiliriz (Pitch)
				if jump_count == 2:
					sfx_ziplama.pitch_scale = 1.2
				else:
					sfx_ziplama.pitch_scale = 1.0

	# Saldırı Tuşu
	if Input.is_action_just_pressed("saldiri") and is_on_floor():
		saldiri_yap()

	# --- YÜRÜME VE YÖN ---
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

	move_and_slide()
	update_animations()

func _unhandled_input(event):
	if event.is_action_pressed("use_flask"): 
		use_flask()

func use_flask():
	if is_dead or is_attacking: return
	
	if Global.current_flasks > 0 and Global.can < Global.max_can:
		Global.current_flasks -= 1
		Global.can += Global.flask_heal_amount
		if Global.can > Global.max_can:
			Global.can = Global.max_can
		if sfx_flask:
			sfx_flask.stop()
			sfx_flask.play()
	
		print("İksir kullanıldı. Can: ", Global.can, " Kalan İksir: ", Global.current_flasks)
		get_tree().call_group("hud_group", "update_hud")
		
	elif Global.current_flasks == 0:
		print("İksir bitti!")

func update_animations():
	if is_dead or is_hurt or is_attacking:
		if sfx_yurume: sfx_yurume.stop()
		return
	if cutscene_active:
		anim.play("Idle")     
		if sfx_yurume: 
			sfx_yurume.stop() 
			return             
			
	if not is_on_floor():
		# Havada İkinci Zıplama Animasyonu (Opsiyonel)
		# Eğer elinde "DoubleJump" animasyonu varsa buraya: if jump_count == 2: anim.play("DoubleJump") ekleyebilirsin.
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
	print("!!! KILIÇ SALLANDI !!!")
	is_attacking = true
	combo_sayaci += 1
	combo_zamanlayicisi = combo_sifirlama_suresi
	
	if sfx_saldiri: sfx_saldiri.play()
	GameFeel.vur(1.5, 0.1)
	
	if combo_sayaci == 1: anim.play("Attack1")
	elif combo_sayaci == 2: anim.play("Attack2")
	elif combo_sayaci >= 3:
		anim.play("Attack3")
		combo_sayaci = 0

	await get_tree().create_timer(0.2).timeout
	saldiri_collision.disabled = false
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var dusmanlar = saldiri_alani.get_overlapping_bodies()
	print("Kılıç alanındaki nesne sayısı: ", dusmanlar.size())
	
	for dusman in dusmanlar:
		if dusman != self and dusman.has_method("hasar_al"):
			print("Düşman Bulundu: ", dusman.name)
			if combo_sayaci == 0:
				dusman.hasar_al(20)
			else:
				dusman.hasar_al(10)

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
	
	can_hasar_alabilir = false
	anim.modulate = Color(1, 0, 0)
	
	await get_tree().create_timer(0.5).timeout
	
	anim.modulate = Color(1, 1, 1)
	can_hasar_alabilir = true
	
	if Global and Global.can <= 0:
		olum_gerceklesti()

func olum_gerceklesti():
	is_dead = true
	velocity = Vector2.ZERO
	anim.play("Death")
	$CollisionShape2D.set_deferred("disabled", true)
	if sfx_yurume: sfx_yurume.stop()
	if sfx_Death:sfx_Death.play()
	emit_signal("player_died") 
	
	await get_tree().create_timer(1.0).timeout
	
	Engine.time_scale = 0.3
	var ekran = game_over_sahnesi.instantiate()
	get_tree().root.add_child(ekran)

func cutscene_moduna_gec():
	cutscene_active = true 
	velocity = Vector2.ZERO 
	
func konus(cumle: String):
	if not diyalog_kutusu or not diyalog_label:
		print("!!! HATA: Bağlantı kopuk, konuşamıyorum!")
		return
	
	su_an_konusuyor = true
	diyalog_kutusu.visible = true
	diyalog_label.text = cumle
	diyalog_label.visible_characters = 0
	diyalog_label.modulate = Color(0.4, 0.8, 1.0) 
	
	for i in range(cumle.length()):
		diyalog_label.visible_characters = i + 1
		await get_tree().create_timer(0.04).timeout
	
	await get_tree().create_timer(2.0).timeout
	diyalog_kutusu.visible = false
	su_an_konusuyor = false
