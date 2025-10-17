extends PawnMobile

const MOVEMENTS: Dictionary = {
    'ui_up': Vector2i.UP,
    'ui_left': Vector2i.LEFT,
    'ui_right': Vector2i.RIGHT,
    'ui_down': Vector2i.DOWN
}

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

func _ready():
    base_speed = speed
    
    # Configurar timer de cooldown do roll
    roll_timer = Timer.new()
    roll_timer.one_shot = true
    roll_timer.timeout.connect(_on_roll_cooldown_finished)
    add_child(roll_timer)
    
func _process(_delta):
    # Verifica se está segurando o botão de roll para sprint
    is_sprinting = Input.is_action_pressed("ui_roll")
    
    # Não permite sprint durante o roll
    if is_rolling:
        is_sprinting = false
    
    speed = base_speed * (sprint_mult if is_sprinting else 1.0)
    
    input_priority()
    
    if can_move():
        # Detecta tap único no botão de roll para executar o roll
        if Input.is_action_just_pressed("ui_roll") and can_roll and not is_rolling:
            execute_roll()
            return
        
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
