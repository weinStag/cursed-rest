extends PawnMobile
class_name Enemy

@warning_ignore("unused_signal")
signal trigger_dialogue

signal died(enemy)

@export var move_pattern: Array[Vector2i]
@export var dialogue_keys: Array[String]

#vida
@export var max_health := 100
var health := 100

# Stats base
@export var damage := 7.5
@export var knockback_distance := 2
@export var attack_distance := 24
@export var attack_cooldown := 3

var can_attack := true
var player: Node2D = null

var move_step := 0
@onready var move_max := move_pattern.size()
@onready var dialogue := GbmUtils.get_dialogue(dialogue_keys)

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var attack_sprite: Sprite2D = $AttackHitbox/AttackSprite

func _ready():
	attack_hitbox.monitoring = false
	attack_hitbox.set_collision_layer_value(3, true) # layer inimigo
	attack_hitbox.set_collision_mask_value(1, true)  # player
	health = max_health

func _process(_delta):
	if player:
		if is_in_attack_range() and not player.is_dead:
			attack()
		else:
			move_towards_player()
	else:
		process_default_movement()


func is_in_attack_range() -> bool:
	return player and global_position.distance_to(player.global_position) <= attack_distance


func attack():
	if not can_attack:
		return
	can_attack = false

	is_stopped = true

	var dir := get_direction_to_player()
	if dir == Vector2i.ZERO:
		dir = Vector2i.DOWN

	# posiciona a hitbox na direção certa
	position_attack_hitbox(dir)

	# ativa hitbox e visual
	attack_hitbox.monitoring = true
	attack_sprite.visible = true

	# tempo em que o ataque fica ativo (hitbox + sprite)
	await get_tree().create_timer(0.15).timeout

	# desativa hitbox e sprite
	attack_hitbox.monitoring = false
	attack_sprite.visible = false

	# cooldown do ataque
	await get_tree().create_timer(attack_cooldown).timeout

	is_stopped = false
	can_attack = true


func position_attack_hitbox(dir: Vector2i):
	var cell_size := 16 # ou o tamanho da SUA tile
	var offset := Vector2(dir.x * cell_size, dir.y * cell_size)
	attack_hitbox.position = offset

	# opcional: rotacionar sprite pela direção
	attack_sprite.rotation = atan2(dir.y, dir.x)


func get_direction_to_player() -> Vector2i:
	var diff := player.global_position - global_position

	if abs(diff.x) > abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	else:
		return Vector2i(0, sign(diff.y))


func move_towards_player():
	if not can_move(): return

	var d := get_direction_to_player()
	if d == Vector2i.ZERO:
		return

	set_anim_direction(d)
	var target = Grid.request_move(self, d)
	if target:
		move_to(target)


func process_default_movement():
	if not can_move(): return
	var step := move_pattern[move_step]

	if step != Vector2i.ZERO:
		set_anim_direction(step)
		var target = Grid.request_move(self, step)
		if target:
			move_to(target)

	move_step = (move_step + 1) % move_max

func receive_damage(amount: int, attacker: Node2D):
	if amount <= 0:
		return

	health -= amount

	print("[Enemy] sofreu", amount, "de dano. HP:", health)

	# Opcional: piscada de hit
	if has_node("Sprite2D"):
		var spr = $Sprite2D
		spr.modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		spr.modulate = Color(1, 1, 1)

	if health <= 0:
		die(attacker)


func die(_attacker: Node2D):
	print("[Enemy] morreu:", self)
	emit_signal("died", self)

	# Se quiser animação de morte:
	# if $AnimationPlayer:
	#     $AnimationPlayer.play("die")
	#     await $AnimationPlayer.animation_finished

	queue_free()

func _on_visao_area_entered(area):
	var p = area.get_parent()
	if p.is_in_group("player"):
		player = p


func _on_visao_area_exited(area):
	var p = area.get_parent()
	if p.is_in_group("player"):
		player = null


func _on_AttackHitbox_area_entered(area: Area2D):
	var target := area.get_parent()
	if target.is_in_group("ataque"):
		if target.has_method("receive_damage"):
			target.receive_damage(damage, self)
