extends Area2D

@export var hasar: int = 20
@export var hasar_karesi: int = 10 
@onready var anim = $ThombStoneAttack

func _ready():

	monitoring = false 

	anim.play("TombStone")


# Alan açıkken biri değerse
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("oyuncu") and body.has_method("hasar_al"):
		body.hasar_al(hasar)




func _on_thomb_stone_attack_frame_changed() -> void:
	if anim.frame == hasar_karesi:
		# Tam taşın çıktığı kareye geldik, alanı AÇ!
		monitoring = true
		
	elif anim.frame > hasar_karesi:
		# Vuruş karesi geçti, alanı KAPAT!
		monitoring = false


func _on_thomb_stone_attack_animation_finished() -> void:
	queue_free()
