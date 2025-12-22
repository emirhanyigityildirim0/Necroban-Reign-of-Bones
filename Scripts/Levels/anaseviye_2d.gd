extends Node2D

# Sahnedeki ses düğümlerini tanıyalım
# (Eğer düğüm yoksa hata vermesin diye get_node_or_null kullanıyoruz)
@onready var Bossmuzik = get_node_or_null("BossMuzik")
@onready var ambiyans = get_node_or_null("Ambiyans")
@onready var muzik = get_node_or_null("Muzik")

func _ready():
	
		
	# Ambiyans varsa ve çalmıyorsa başlat
	if ambiyans and not ambiyans.playing:
		ambiyans.play()

# İleride oyuncu ölünce bu fonksiyonu çağırıp her şeyi susturabilirsin
func sesleri_kes():
	if muzik: muzik.stop()
	if ambiyans: ambiyans.stop()

# İleride "Boss" gelince müziği değiştirmek istersen bu lazım olur
func muzik_degistir(BossMuzik):
	if muzik:
		muzik.stop()
		muzik.stream = BossMuzik
		muzik.play()
