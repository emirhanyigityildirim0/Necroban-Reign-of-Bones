extends Node

# --- OYUNCU İSTATİSTİKLERİ (PLAYER STATS) ---
var skor = 0
var can = 100
var max_can = 100

# --- SAVAŞ GÜCÜ (Burası Yeni) ---
# İleride "Kılıç +1" alınca burayı artıracağız
var damage_heavy: int = 20  # Ağır saldırı hasarı
var damage_light: int = 10  # Hızlı saldırı hasarı

# --- İKSİR SİSTEMİ ---
var flask_heal_amount: int = 40   
var max_flasks: int = 3           
var current_flasks: int = 3
