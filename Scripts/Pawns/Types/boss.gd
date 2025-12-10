extends Enemy
class_name Boss

@export var boss_scale := 2.0
@export var boss_damage := 35
@export var boss_knockback := 4
@export var boss_attack_distance := 48

func _ready():
	# aumenta tamanho gráfico
	scale = Vector2(boss_scale, boss_scale)

	# modifica stats herdados
	damage = boss_damage
	knockback_distance = boss_knockback
	attack_distance = boss_attack_distance
