extends TextureProgressBar

func _ready():
	# Encontra o player na cena pelo grupo "player"
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Conecta o sinal do player
		player.health_changed.connect(_on_player_health_changed)
		
		# Atualiza a vida inicial imediatamente
		update_bar(player.status['health'], 250)

# Função que recebe o sinal
func _on_player_health_changed(new_health, max_health_val):
	update_bar(new_health, max_health_val)

# Função auxiliar para atualizar os valores
func update_bar(current, maximum):
	# Como o script está na barra, usamos as variáveis direto (sem "health_bar.")
	max_value = maximum
	value = current
