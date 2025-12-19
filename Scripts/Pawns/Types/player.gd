extends PawnMobile
signal health_changed(new_health, max_health)
# Attack system
var is_attacking: bool = false
@export var attack_cooldown: float = 0.35
var can_attack: bool = true

var status: Dictionary = {
	'health': 250,
	'stamina': 100,
	'vitality': 10,
	'breath': 10,
	'strength': 10,
	'agility': 10
}

const MOVEMENTS: Dictionary = {
	'ui_up': Vector2i.UP,
	'ui_left': Vector2i.LEFT,
	'ui_right': Vector2i.RIGHT,
	'ui_down': Vector2i.DOWN
}

var is_dead: bool = false

# Movement Related (+ animation)
var input_history: Array[String] = []
var cur_direction: Vector2i = Vector2i.DOWN
var is_sprinting: bool = false
var sprint_mult: float = 3.5
var base_speed: float = 1.5

# Roll System
var is_rolling: bool = false
var roll_distance: int = 3  # Quantas células o roll percorre
var roll_speed_mult: float = 5.0  # Multiplicador de velocidade do roll
var roll_cooldown: float = 0.5  # Tempo de cooldown entre rolls (em segundos)
var can_roll: bool = true
var roll_timer: Timer

# Knockback System
var is_knockbacking: bool = false
var knockback_distance: int = 2
var knockback_speed_mult: float = 7.5
var knockback_cooldown: float = 0.25
var can_kockback: bool = true
var knockback_timer: Timer

# Detecção de tap vs hold
var roll_button_press_time: float = 0.0
var roll_tap_threshold: float = 0.15  # Tempo máximo para considerar um "tap" (em segundos)



func _ready():
	base_speed = speed
	emit_signal("health_changed", status['health'], 250)
	# Configurar timer de cooldown do roll
	roll_timer = Timer.new()
	roll_timer.one_shot = true
	roll_timer.timeout.connect(_on_roll_cooldown_finished)
	add_child(roll_timer)
	
		# timer knockback
	knockback_timer = Timer.new()
	knockback_timer.one_shot = true
	knockback_timer.timeout.connect(_on_knockback_cooldown)
	add_child(knockback_timer)

func _on_knockback_cooldown():
	can_kockback = true


func _process(_delta):
	var mouse_pos = get_global_mouse_position()
	$SwordPivot.look_at(mouse_pos)
	
	if Input.is_action_just_pressed("ui_mb1"):
		try_attack()
	
	# Sistema de detecção tap vs hold para ui_roll
	if Input.is_action_just_pressed("ui_roll"):
		roll_button_press_time = 0.0
	
	if Input.is_action_pressed("ui_roll"):
		roll_button_press_time += _delta
	
	# Se soltar o botão rápido (tap), executa roll
	if Input.is_action_just_released("ui_roll"):
		if roll_button_press_time <= roll_tap_threshold and can_roll and not is_rolling and can_move():
			execute_roll()
			roll_button_press_time = 0.0
			return
		roll_button_press_time = 0.0
	
	# Sprint: apenas se estiver segurando por mais tempo que o threshold
	is_sprinting = Input.is_action_pressed("ui_roll") and roll_button_press_time > roll_tap_threshold
	
	# Não permite sprint durante o roll
	if is_rolling:
		is_sprinting = false
	
	speed = base_speed * (sprint_mult if is_sprinting else 1.0)
	
	input_priority()
	
	if can_move():
		if Input.is_action_just_pressed("ui_accept"): # To Request dialogue
			Grid.request_event(self, cur_direction, 0)
		
		var input_direction: Vector2i = set_direction()
		if input_direction:
			cur_direction = input_direction
			set_anim_direction(input_direction)
			
			# Checks if the next movement opportunity is possible, if it is move to target position
			var target_position: Vector2i = Grid.request_move(self, input_direction)
			if target_position:
				move_to(target_position)

func try_attack():
	if not can_attack or is_attacking or is_rolling or is_knockbacking:
		return

	is_attacking = true
	can_attack = false

	# ativa hitbox
	$SwordPivot/SwordArea.monitoring = true

	# animação de ataque simples (girando espada)
	var tween = create_tween()
	tween.tween_property($SwordPivot, "rotation_degrees", $SwordPivot.rotation_degrees + 120, 0.15)

	tween.finished.connect(_finish_attack)

func _finish_attack():
	$SwordPivot/SwordArea.monitoring = false
	is_attacking = false

	# cooldown do ataque
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func execute_roll():
	"""Executa o roll na direção atual do player"""
	is_rolling = true
	can_roll = false
	
	# Tenta mover múltiplas células na direção do roll
	var cells_moved: int = 0
	var last_valid_position: Vector2 = position
	
	# Tenta rolar pela distância especificada
	for i in range(1, roll_distance + 1):
		var target_position: Vector2 = Grid.request_move(self, cur_direction)
		
		if target_position:
			last_valid_position = target_position
			cells_moved += 1
		else:
			break  # Para se encontrar obstáculo
	
	# Executa o movimento do roll se conseguiu mover pelo menos 1 célula
	if cells_moved > 0:
		# Animação de roll (você pode personalizar)
		set_anim_direction(cur_direction)
		# Aqui você pode adicionar uma animação específica de roll
		# Ex: $AnimationPlayer.play("roll_" + get_direction_name())
		
		roll_to(last_valid_position)
	else:
		# Se não conseguiu rolar, cancela o roll
		finish_roll()

func roll_to(target: Vector2):
	"""Move o player para a posição alvo com velocidade de roll"""
	is_moving = true
	
	var roll_duration: float = (walk_anim_length / base_speed) / roll_speed_mult
	
	move_tween = create_tween()
	move_tween.tween_property(self, "position", target, roll_duration)
	move_tween.finished.connect(_on_roll_finished)

func _on_roll_finished():
	"""Callback quando o roll termina"""
	move_tween.kill()
	finish_roll()

func finish_roll():
	"""Finaliza o estado de roll"""
	is_rolling = false
	is_moving = false
	
	# Inicia cooldown do roll
	roll_timer.start(roll_cooldown)
	
	# Verifica eventos na posição final
	Grid.request_event(self, Vector2i.ZERO, 2)

func _on_roll_cooldown_finished():
	"""Callback quando o cooldown do roll termina"""
	can_roll = true

func can_move() -> bool:
	"""Verifica se o player pode se mover (não está em roll)"""
	return not is_moving and not is_talking and not is_rolling

func input_priority():
	# Input priority system, prioritize the latest inputs
	for direction in MOVEMENTS.keys():
		if Input.is_action_just_released(direction):
			var index: int = input_history.find(direction)
			if index != -1:
				input_history.remove_at(index)
		
		if Input.is_action_just_pressed(direction):
			input_history.append(direction)

func set_direction() -> Vector2i:
	var direction := Vector2i.ZERO
	
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1

	return Vector2i(round(direction.x), round(direction.y))



func _move_tween_done():
	move_tween.kill()
	switch_walk = !switch_walk
	Grid.request_event(self, Vector2i.ZERO, 2) # Check if there's an event
	is_moving = false

func set_talking(talk_state: bool):
	is_talking = !talk_state
	if is_talking: 
		input_history.clear()
		# Cancela roll se começar a falar
		if is_rolling:
			is_rolling = false

# Função auxiliar para debug/animações
func get_direction_name() -> String:
	match cur_direction:
		Vector2i.UP: return "up"
		Vector2i.DOWN: return "down"
		Vector2i.LEFT: return "left"
		Vector2i.RIGHT: return "right"
		_: return "down"

func receive_damage(amount: int, attacker: Node2D):
	if attacker == null:
		return
	var new_health := calc_damage(amount)
	# Garante que a vida não fique negativa
	if new_health < 0:
		new_health = 0 
	print(new_health)
	status["health"] = new_health
	# >>> LINHA NOVA: Avisa o HUD que a vida mudou <<<
	# Você pode querer definir uma variável 'max_health' no dicionário status também
	# Por enquanto, estou usando 250 fixo ou você pode calcular
	var max_health = 250 # Ou status['max_health'] se você adicionar lá
	emit_signal("health_changed", new_health, max_health)
	if new_health > 0:
		apply_knockback(attacker)
	else:
		get_tree().change_scene_to_file("res://game_over.tscn")
		#die()

func die():
	print("Player morreu!")
	# Desabilita movimento
	#is_talking = true
	#is_rolling = false
	#is_moving = false
	#is_dead = true
	# Aqui você pode chamar animação, respawn, tela game over, etc.


func calc_damage(damage) -> int:
	var current_life = status.get('health')
	var current_vitality = status.get('vitality')
	var new_health = current_life + current_vitality - damage
	return new_health

func apply_knockback(attacker: Node2D):
	if not can_kockback or is_knockbacking or is_rolling:
		return

	# calcula direção cardinal do impacto
	var diff := global_position - attacker.global_position
	var dir := Vector2i.ZERO

	if diff == Vector2.ZERO:
		dir = -cur_direction
	else:
		if abs(diff.x) > abs(diff.y):
			dir = Vector2i(sign(diff.x), 0)
		else:
			dir = Vector2i(0, sign(diff.y))

	# distância depende do atacante (Enemy ou Boss)
	var force := knockback_distance
	if "knockback_distance" in attacker:
		force = attacker.knockback_distance

	is_knockbacking = true
	can_kockback = false

	var last_valid := position
	for i in range(force):
		var next = Grid.request_move(self, dir)
		if next:
			last_valid = next
		else:
			break

	_knockback_to(last_valid)


func _knockback_to(target: Vector2):
	is_moving = true

	var duration = (walk_anim_length / base_speed) / knockback_speed_mult

	move_tween = create_tween()
	move_tween.tween_property(self, "position", target, duration)
	move_tween.finished.connect(_on_knockback_done)

func _on_knockback_done():
	move_tween.kill()
	_finish_knockback()

func _finish_knockback():
	is_knockbacking = false
	is_moving = false

	knockback_timer.start(knockback_cooldown)

	Grid.request_event(self, Vector2i.ZERO, 2)

func deal_damage(target: Node2D, amount: int):
	if target == null:
		return

	if target.has_method("receive_damage"):
		target.receive_damage(amount, self)

func _on_area_2d_area_entered(area: Area2D):
	var attacker := area.get_parent()
	if not attacker:
		return

	if area.is_in_group("hitbox"):
		receive_damage(50, attacker)
		return

	if area.is_in_group("hitbox_boss"):
		receive_damage(75, attacker)
		return


func _on_sword_area_area_entered(area):
	print("acertou:", area.name)
	var enemy = area.get_parent()
	if enemy.is_in_group("enemy"):
		deal_damage(enemy, 25)
	elif enemy.is_in_group("boss"):
		deal_damage(enemy, 40)
		
