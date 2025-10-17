extends PawnMobile

const MOVEMENTS: Dictionary = {
	'ui_up': Vector2i.UP,
	'ui_left': Vector2i.LEFT,
	'ui_right': Vector2i.RIGHT,
	'ui_down': Vector2i.DOWN
	}

# Movement Related
var input_history: Array[String] = []
var cur_direction: Vector2i = Vector2i.DOWN
var base_speed: float = 1.5

# Sprint Related
var is_sprinting: bool = false
var sprint_mult: float = 2.0 # Ajustei para um valor mais comum de corrida

# Roll Related
var is_rolling: bool = false
var can_roll: bool = true
var roll_speed_mult: float = 3.5 # Quão mais rápido o roll é em relação à caminhada
var roll_distance: int = 2 # Quantos "tiles" o player vai rolar
var roll_cooldown_time: float = 0.8 # Tempo de espera em segundos para poder rolar de novo

# Timers para diferenciar Toque de Segurar
var roll_press_timer: Timer
var roll_cooldown_timer: Timer
const HOLD_TO_SPRINT_TIME: float = 0.2 # Tempo em segundos para considerar "segurar"

func _ready():
	base_speed = speed

	# --- Criação dos Timers por código ---
	# Timer para verificar se o botão está sendo segurado
	roll_press_timer = Timer.new()
	roll_press_timer.wait_time = HOLD_TO_SPRINT_TIME
	roll_press_timer.one_shot = true
	roll_press_timer.timeout.connect(_on_roll_press_timer_timeout)
	add_child(roll_press_timer)

	# Timer para o cooldown do roll
	roll_cooldown_timer = Timer.new()
	roll_cooldown_timer.wait_time = roll_cooldown_time
	roll_cooldown_timer.one_shot = true
	roll_cooldown_timer.timeout.connect(_on_roll_cooldown_timer_timeout)
	add_child(roll_cooldown_timer)

func _process(_delta):
	# A lógica de input e movimento só roda se o player não estiver ocupado
	if is_moving or is_rolling:
		return

	# Lida com todos os inputs (movimento, roll, sprint)
	_handle_input()
	
	if can_move():
		if Input.is_action_just_pressed("ui_accept"): # Para solicitar diálogo
			Grid.request_event(self, cur_direction, 0)
			return # Retorna para não processar movimento no mesmo frame

		var input_direction: Vector2i = set_direction()
		
		# Se houver input de direção, move o personagem
		if input_direction:
			cur_direction = input_direction
			set_anim_direction(input_direction)
			
			# Define a velocidade baseada em estar correndo ou não
			speed = base_speed * (sprint_mult if is_sprinting else 1.0)
			
			var target_position: Vector2i = Grid.request_move(self, input_direction)
			if target_position:
				move_to(target_position)

func _handle_input():
	# Input para Roll/Sprint
	if Input.is_action_just_pressed("ui_roll"):
		roll_press_timer.start()

	if Input.is_action_just_released("ui_roll"):
		is_sprinting = false # Para de correr assim que solta
		# Se soltou ANTES do timer de "segurar" terminar, é um toque (roll)
		if not roll_press_timer.is_stopped():
			roll_press_timer.stop()
			_perform_roll()

	# Input para movimento (seu sistema de prioridade)
	input_priority()

func _perform_roll():
	if not can_roll:
		return

	# Pega a direção atual do input ou a última direção que o player estava virado
	var roll_direction: Vector2i = set_direction()
	if roll_direction == Vector2i.ZERO:
		roll_direction = cur_direction

	# Se não há direção nenhuma, não faz o roll
	if roll_direction == Vector2i.ZERO:
		return

	# Verifica se a posição final do roll é válida
	var target_position: Vector2i = Grid.request_move(self, roll_direction * roll_distance)
	if target_position:
		is_rolling = true
		can_roll = false
		roll_cooldown_timer.start() # Inicia o cooldown
		
		set_anim_direction(roll_direction) # Atualiza a animação para a direção do roll
		
		# O roll é mais rápido que a caminhada
		speed = base_speed * roll_speed_mult
		move_to(target_position)

func input_priority():
	# Input prioritie system, prioritize the latest inputs
	for direction in MOVEMENTS.keys():
		if Input.is_action_just_released(direction):
			var index: int = input_history.find(direction)
			if index != -1:
				input_history.remove_at(index)
		
		if Input.is_action_just_pressed(direction):
			input_history.append(direction)

func set_direction() -> Vector2i:
	# Handles the movement direction depending on the inputs
	var direction: Vector2i = Vector2i()
	
	if input_history.size():
		for i in input_history:
			direction += MOVEMENTS[i]
		
		match(input_history.back()):
			'ui_right', 'ui_left': if direction.x != 0: direction.y = 0
			'ui_up', 'ui_down': if direction.y != 0: direction.x = 0
	
	return direction

func _move_tween_done():
	move_tween.kill()
	
	# Se estava rolando, reseta o estado de "rolling"
	if is_rolling:
		is_rolling = false

	switch_walk = !switch_walk
	Grid.request_event(self, Vector2i.ZERO, 2) # Check if there's an event
	is_moving = false

# --- Funções de Timeout dos Timers ---
func _on_roll_press_timer_timeout():
	# Se o timer terminou, significa que o player está segurando o botão.
	is_sprinting = true

func _on_roll_cooldown_timer_timeout():
	# O cooldown acabou, o player pode rolar de novo.
	can_roll = true

func set_talking(talk_state: bool):
	is_talking = !talk_state
	if is_talking: input_history.clear()
