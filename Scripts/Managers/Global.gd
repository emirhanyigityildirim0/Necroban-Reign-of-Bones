extends Node

# Tüm oyun boyunca skor burada tutulacak
var skor = 0
var can = 100
var max_can = 100
# --- İKSİR SİSTEMİ (YENİ) ---
var flask_heal_amount: int = 40   # Bir iksirin iyileştirme miktarı
var max_flasks: int = 3           # Taşınabilecek maksimum iksir sayısı (Bu upgrade ile artacak)
var current_flasks: int = 3       # Şu anki iksir sayısı
