extends Area2D

@export var aninda_oldur: bool = true
@export var hasar_miktari: int = 999 

func _ready():
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Eğer giren şey "oyuncu" grubundaysa
	if body.is_in_group("oyuncu"):
		print("💀 Oyuncu zehirli sise düştü!")
		
		if body.has_method("hasar_al"):
			if aninda_oldur:
				body.hasar_al(hasar_miktari) 
			else:
				body.hasar_al(10) 
