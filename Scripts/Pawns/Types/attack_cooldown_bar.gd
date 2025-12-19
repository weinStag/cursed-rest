extends ProgressBar

var player: Node2D

func _ready():
	# Configura a barra
	max_value = 100
	value = 100
	show_percentage = false
	
	# Estilo visual simplificado
	modulate = Color(1, 1, 1, 0.7)
	
	# Posição abaixo do player
	position = Vector2(-12, 14)
	size = Vector2(24, 4)
	
	# Pega referência ao player
	player = get_parent()

func _process(_delta):
	if not player:
		return
	
	# Atualiza a barra baseado no cooldown do ataque
	if player.attack_cooldown_timer <= 0:
		value = 100
		modulate = Color(0.3, 1, 0.3, 0.7)  # Verde quando pronto
	else:
		# Calcula o progresso do cooldown (0 a 100)
		var progress = (player.attack_cooldown - player.attack_cooldown_timer) / player.attack_cooldown
		value = progress * 100
		modulate = Color(1, 0.6, 0, 0.7)  # Laranja quando em cooldown
