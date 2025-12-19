extends CanvasLayer

@onready var health_bar: TextureProgressBar = $TextureProgressBar
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var soul_label: Label = $SoulCounter
@onready var heal_label: Label = $HealCounter

func _ready():
	# Encontra o player na cena pelo grupo "player"
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Conecta todos os sinais do player
		player.health_changed.connect(_on_player_health_changed)
		player.stamina_changed.connect(_on_player_stamina_changed)
		player.souls_changed.connect(_on_player_souls_changed)
		player.heal_changed.connect(_on_player_heal_changed)
		
		# Atualiza valores iniciais
		_on_player_health_changed(player.status['health'], player.MAX_HEALTH)
		_on_player_stamina_changed(player.status['stamina'], player.MAX_STAMINA)
		_on_player_souls_changed(player.souls)
		_on_player_heal_changed(player.heal_uses_remaining, player.max_heal_uses)

func _on_player_health_changed(new_health, max_health):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = new_health

func _on_player_stamina_changed(new_stamina, max_stamina):
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = new_stamina

func _on_player_souls_changed(new_souls):
	if soul_label:
		soul_label.text = "Souls: " + str(new_souls)

func _on_player_heal_changed(heal_remaining, max_heals):
	if heal_label:
		heal_label.text = "Heals (F): " + str(heal_remaining) + "/" + str(max_heals)
