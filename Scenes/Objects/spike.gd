extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("oyuncu"):
		print("💀 Diken battı!")
		
		# Oyuncunun kendi ölüm fonksiyonunu çalıştır
		if body.has_method("olum_gerceklesti"):
			body.olum_gerceklesti()
