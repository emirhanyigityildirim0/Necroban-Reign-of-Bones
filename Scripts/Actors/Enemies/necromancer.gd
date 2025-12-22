extends CharacterBody2D

# --- EDİTÖRDEN AYARLANACAKLAR (UI) ---
@export_group("UI Bağlantıları")
@export var diyalog_kutusu: CanvasLayer
@export var diyalog_text: Label
@export var aura_alani: Area2D
@export var aura_camera: Camera2D 

@export_group("Diyalog Ayarları")

   # Yazıyı buraya bağlayacağız
var su_an_konusuyor = false

# --- YENİ SİSTEM: EDİTÖRDEN DÜZENLENEBİLİR SENARYO ---
@export_group("Senaryo")
# Burası artık Inspector panelinden değiştirilebilir!
@export_multiline var diyaloglar: Array[String] = [
	"Necromancer: '...'",
	"Necromancer: 'hmm...'",
	"Necromancer: 'Sanırım Sunağıma yaklaşmışsın!'",
	"Necromancer: 'hm... '",
	"Necromancer: 'Olmaması gerekirdi'",
	"Necromancer: '...'",	
	"Necromancer: 'Sana Dokunamam'",
	"Necromancer: '...'",
	"Necromancer: 'Burası Ruhsal bir alem...'",
	"Necromancer:'Sadece benim izin verdiğim ölülerin girebileceği bir alem!!'",
	"Necromancer: 'Olman gereken yer burası değil ölümlü!...'",
	"Necromancer: 'Karanlığın kalbinde sizin türünüze yer yok.'",
	"Necromancer: 'Atalarınız ders Çıkarmadı...",
	"Necromancer: '...Ve sizlerde.'",
	"Necromancer: '...'",
	"Necromancer: 'Kıta'nın.'fethi yakın...",
	"Necromancer: 'Seni geldiğin yerden beterine göndericem'",
	"Necromancer: '...'"
]

# --- DİĞER BAĞLANTILAR (DOKUNULMADI) ---
@onready var boss_muzigi = $BossMuzigi 
@onready var blip_player = $BlipSesi 
@onready var sfx_saldiri = get_node_or_null("SfxSaldiri")

# --- GÖRSEL EFEKT REFERANSLARI ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var staff_position = $StaffPosition
@onready var spell_light = $StaffPosition/SpellLight
@onready var charge_particles = $StaffPosition/ChargeParticles

# --- AYARLAR ---
var yazi_hizi = 0.04 
var ses_sikligi = 3 

# --- DEĞİŞKENLER ---
var player = null
var konusma_basladi = false
var konusma_sirasi = 0
var su_an_yaziliyor = false 
var time_passed = 0.0 
var is_attacking = false 

func _ready():
	if animated_sprite: animated_sprite.play("Idle")
	if spell_light: spell_light.energy = 0
	if charge_particles: charge_particles.emitting = false
	if diyalog_kutusu: diyalog_kutusu.visible = false
	
	if aura_alani:
		# Sinyali temizleyip bağlıyoruz
		if aura_alani.body_entered.is_connected(_on_aura_entered):
			aura_alani.body_entered.disconnect(_on_aura_entered)
		aura_alani.body_entered.connect(_on_aura_entered)

func _process(delta):
	# Crash Önleyici
	if not is_instance_valid(animated_sprite) or not is_instance_valid(staff_position): return

	# Hover (Süzülme) Efekti
	time_passed += delta
	position.y += sin(time_passed * 2.5) * 0.3 
	
	if not player: player = get_tree().get_first_node_in_group("oyuncu")
	
	# Yüzünü dönme mantığı
	if player and not is_attacking:
		if player.global_position.x > global_position.x:
			animated_sprite.flip_h = false 
			staff_position.position.x = abs(staff_position.position.x)
		else:
			animated_sprite.flip_h = true 
			staff_position.position.x = -abs(staff_position.position.x)

func _input(event):
	# Sadece konuşma başladıysa ve ilerletmek istiyorsak çalışır
	if konusma_basladi and (event.is_action_pressed("ui_accept") or event.is_action_pressed("etkilesim")):
		if su_an_yaziliyor:
			if diyalog_text: diyalog_text.visible_characters = -1 
			su_an_yaziliyor = false 
		else:
			siradaki_cumle()

# --- OTOMATİK BAŞLATMA ---
func _on_aura_entered(body):
	if body.is_in_group("oyuncu"):
		player = body 
		# İçeri girer girmez konuşmayı tetikliyoruz
		baslat_konusma()

# --- DİYALOG MOTORU ---

func baslat_konusma():
	if konusma_basladi: return
	konusma_basladi = true
	
	if aura_camera:
		aura_camera.enabled = true
		aura_camera.make_current()
	
	if boss_muzigi: boss_muzigi.play()
	if player and player.has_method("cutscene_moduna_gec"):
		player.cutscene_moduna_gec()

	if diyalog_kutusu:
		diyalog_kutusu.visible = true
		siradaki_cumle()

func siradaki_cumle():
	# Dizi boyutu kontrolü (Artık editörden gelen listeye bakıyor)
	if konusma_sirasi < diyaloglar.size():
		yaziyi_daktilo_efektiyle_yaz(diyaloglar[konusma_sirasi])
		konusma_sirasi += 1
	else:
		bitir_ve_isinla()

func yaziyi_daktilo_efektiyle_yaz(cumle: String):
	if not diyalog_text: return
	su_an_yaziliyor = true 
	diyalog_text.text = cumle
	diyalog_text.visible_characters = 0 
	
	var toplam_harf = cumle.length()
	for i in range(toplam_harf):
		if not su_an_yaziliyor: break 
		diyalog_text.visible_characters = i + 1 
		if blip_player and i % ses_sikligi == 0:
			blip_player.pitch_scale = randf_range(0.95, 1.05)
			blip_player.play()
		await get_tree().create_timer(yazi_hizi).timeout
	
	diyalog_text.visible_characters = -1 
	su_an_yaziliyor = false 

# --- OPTİMİZE EDİLMİŞ SALDIRI ---
func cast_attack_1():
	is_attacking = true
	if animated_sprite: animated_sprite.play("Attack1") 
	if sfx_saldiri: sfx_saldiri.play()
	if charge_particles: charge_particles.emitting = true

# --- FİNAL SENARYOSU ---
func bitir_ve_isinla():
	if diyalog_kutusu: diyalog_kutusu.visible = false
	
	cast_attack_1()
	
	if boss_muzigi:
		var music_tween = create_tween()
		music_tween.tween_property(boss_muzigi, "volume_db", -80.0, 1.0)
	
	await get_tree().create_timer(0.6).timeout
	
	# Sarsıntı
	if aura_camera:
		var shake_tween = create_tween()
		var shake_power = 8.0 
		for i in range(12):
			var random_offset = Vector2(randf_range(-shake_power, shake_power), randf_range(-shake_power, shake_power))
			shake_tween.tween_property(aura_camera, "offset", random_offset, 0.04)
		shake_tween.tween_property(aura_camera, "offset", Vector2.ZERO, 0.05)
	
	# Beyaz Ekran
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 100 
	add_child(transition_layer) 
	
	var flash_rect = ColorRect.new()
	flash_rect.color = Color.WHITE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT) 
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(flash_rect)
	
	flash_rect.modulate.a = 0.0
	var flash_tween = create_tween()
	flash_tween.tween_property(flash_rect, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	
	await flash_tween.finished
	
	if ResourceLoader.exists("res://Scenes/Levels/CaveLevel.tscn"):
		get_tree().change_scene_to_file("res://Scenes/Levels/Cavelevel.tscn")
	else:
		print("!!! HATA: MagaraLeveli.tscn bulunamadı!")

func _on_animated_sprite_2d_animation_finished():
	if konusma_basladi: return
	if animated_sprite.animation == "Attack1":
		is_attacking = false
		animated_sprite.play("Idle")
		if charge_particles: charge_particles.emitting = false
