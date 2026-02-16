extends Control

# --- AYARLAR ---
@export var scroll_speed: float = 60.0  # Kayma hızı
@export var title_screen_scene = "res://Scenes/UI/main_menu.tscn" # Ana menü dosya yolun

@onready var kayan_yazi = $KayanYazi
@onready var yazi_label = $KayanYazi/Yazi
@onready var geri_butonu = $GeriButonu
@onready var creidtsfx = get_node_or_null("CreditsSFX")
var text_bitti_mi: bool = false

func _ready():
	if creidtsfx and not creidtsfx.playing: creidtsfx.play()
	
	

	var ekran_boyutu = get_viewport_rect().size.y
	kayan_yazi.position.y = ekran_boyutu + 50

func _process(delta):
	if text_bitti_mi: return
	

	var current_speed = scroll_speed
	if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		current_speed *= 4.0 # 4 kat hızlandır
	
	# Yukarı doğru kaydır
	kayan_yazi.position.y -= current_speed * delta
	

	if kayan_yazi.position.y < -yazi_label.size.y - 100:
		text_bitti_mi = true
		_credits_bitti()

func _credits_bitti():
	print("Credits bitti, ana menüye dönülüyor...")
	# Otomatik menüye dönsün istersen:
	get_tree().change_scene_to_file(title_screen_scene)

func _on_geri_butonu_pressed():
	
	get_tree().change_scene_to_file(title_screen_scene)
