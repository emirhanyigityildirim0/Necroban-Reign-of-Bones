extends PointLight2D

var hedef_enerji = 1.0

func _process(delta):
	# Işığın gücünü rastgele değiştir (Titreme efekti)
	if randf() < 0.1: # Her karede %10 şansla yeni bir güç belirle
		hedef_enerji = randf_range(0.8, 2) # 0.8 ile 1.2 arasında gidip gelsin
	
	# Yumuşak geçiş yap (Küt diye değişmesin)
	energy = move_toward(energy, hedef_enerji,1* delta)
