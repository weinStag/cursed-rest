extends PawnMobile
class_name Enemy

signal trigger_dialogue

@export var move_pattern: Array[Vector2i]
@export var dialogue_keys: Array[String]

# Stats base
@export var damage := 10
@export var knockback_distance := 2
@export var attack_distance := 24
@export var attack_cooldown := 1.2

var can_attack := true
var player: Node2D = null

var move_step := 0
@onready var move_max := move_pattern.size()
@onready var dialogue := GbmUtils.get_dialogue(dialogue_keys)


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


func attack() -> void:
	if not can_attack:
		return

	can_attack = false
	is_stopped = true

	if player.has_method("receive_damage"):
		player.receive_damage(damage, self)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	is_stopped = false


func get_direction_to_player() -> Vector2i:
	var diff := player.global_position - global_position
	if abs(diff.x) > abs(diff.y):
		return Vector2i(sign(diff.x), 0)
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


func _on_visao_area_entered(area):
	var p = area.get_parent()
	if p.is_in_group("player"):
		player = p


func _on_visao_area_exited(area):
	var p = area.get_parent()
	if p.is_in_group("player"):
		player = null
