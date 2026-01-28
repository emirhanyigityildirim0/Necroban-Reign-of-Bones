extends RigidBody2D

@export var damage = 30

func _ready():
	# Başlangıçta havada asılı kal
	freeze = true 

# Dedektör oyuncuyu görünce çalışır


# Kaya bir şeye (oyuncuya veya yere) çarpınca çalışır
func _on_body_entered(body):
	
	if body.is_in_group("oyuncu") and body.has_method("hasar_al"):
		body.hasar_al(damage)
		
	# Yere veya oyuncuya çarpınca yok olsun (Efekt ekleyebilirsin)
	queue_free()

func _on_detektor_body_entered(body: Node2D) -> void:
	if body.is_in_group("oyuncu"):
		print("⚠️ TUZAK TETİKLENDİ!")
		set_deferred("freeze", false)
		set_deferred("sleeping", false)
		apply_central_impulse(Vector2(0, 10))
		
		# Dedektörü kapat ki düşerken kendi kendine çarpmasın
		$Dedektor/CollisionShape2D.set_deferred("disabled", true)
