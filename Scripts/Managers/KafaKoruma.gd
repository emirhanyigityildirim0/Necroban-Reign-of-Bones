extends Area2D


func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("oyuncu"):
		print("🦶 Oyuncu kafaya bastı, fırlatılıyor!")
		
		
		if "velocity" in body:
			var itme_yonu = 1
			# Area2D'nin (yani düşmanın) solunda mı sağında mı?
			if body.global_position.x < global_position.x:
				itme_yonu = -1

			body.velocity = Vector2(itme_yonu * 400, -250)
			
