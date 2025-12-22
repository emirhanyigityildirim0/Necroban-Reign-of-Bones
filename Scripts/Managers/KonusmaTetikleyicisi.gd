extends Area2D

# Sağdaki panelden (Inspector) her kutu için farklı yazı yazabilmeni sağlar
@export_multiline var soylenecek_soz: String = "Ananı sikeyim"

func _ready():
	# Sinyali kodla bağlayalım, uğraşma
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# İçeri giren şey Oyuncu mu?
	if body.is_in_group("oyuncu"):
		# Oyuncunun içinde 'konus' fonksiyonu var mı? (Önceki adımda eklemiştik)
		if body.has_method("konus"):
			body.konus(soylenecek_soz)
			
			# Bir kere söyledikten sonra bu kutuyu yok et (Tekrarlamasın)
			queue_free()
