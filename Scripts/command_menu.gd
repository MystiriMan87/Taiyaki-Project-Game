extends VBoxContainer

signal chosen(result: Array)

var actor: Battler
var targets: Array = []
var target_index := 0
var targeting := false
var in_skills := false
var pending_action: BattleAction = null
var cursor: Label
var mp_label: Label
var skills_button: Button
var skill_buttons: Array[Button] = []

func _ready() -> void:
	hide()
	mp_label = Label.new()
	add_child(mp_label)
	move_child(mp_label, 0)
	skills_button = Button.new()
	skills_button.text = "Skills"
	add_child(skills_button)
	move_child(skills_button, $AttackButton.get_index() + 1)

	$AttackButton.pressed.connect(_on_attack)
	skills_button.pressed.connect(_on_skills)
	$DefendButton.pressed.connect(func(): _finish(["defend", null]))

	cursor = Label.new()
	cursor.text = "▼"
	cursor.add_theme_font_size_override("font_size", 32)

func open(a: Battler, living_enemies: Array) -> void:
	actor = a
	targets = living_enemies
	targeting = false
	pending_action = null
	mp_label.text = "%s   MP %d/%d" % [a.stats.display_name, a.mp, a.stats.max_mp]
	skills_button.disabled = a.stats.actions.is_empty()
	_show_main()
	show()
	$AttackButton.grab_focus()

# --- Menus --------------------------------------------------------------

func _show_main() -> void:
	in_skills = false
	_clear_skill_buttons()
	$AttackButton.show()
	skills_button.show()
	$DefendButton.show()
	$AttackButton.grab_focus()

func _on_skills() -> void:
	in_skills = true
	$AttackButton.hide()
	skills_button.hide()
	$DefendButton.hide()
	var first_enabled: Button = null
	for action in actor.stats.actions:
		var b := Button.new()
		b.text = "%s  (%d MP)" % [action.display_name, action.mp_cost]
		b.disabled = actor.mp < action.mp_cost
		b.pressed.connect(_on_skill_picked.bind(action))
		add_child(b)
		skill_buttons.append(b)
		if first_enabled == null and not b.disabled:
			first_enabled = b
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_show_main)
	add_child(back)
	skill_buttons.append(back)
	(first_enabled if first_enabled else back).grab_focus()

func _on_skill_picked(action: BattleAction) -> void:
	pending_action = action
	if action.target_type == BattleAction.TargetType.ALL_ENEMIES:
		_finish(["skill", action, targets])
	else:
		_begin_targeting()

func _on_attack() -> void:
	pending_action = null
	_begin_targeting()

func _clear_skill_buttons() -> void:
	for b in skill_buttons:
		b.queue_free()
	skill_buttons.clear()

# --- Targeting ----------------------------------------------------------

func _begin_targeting() -> void:
	if targets.is_empty():
		return
	await get_tree().process_frame   # don't let the same key press confirm the target
	targeting = true
	target_index = 0
	hide()
	_update_cursor()

func _unhandled_input(event: InputEvent) -> void:
	if targeting:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			target_index = wrapi(target_index - 1, 0, targets.size())
			_update_cursor()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			target_index = wrapi(target_index + 1, 0, targets.size())
			_update_cursor()
		elif event.is_action_pressed("ui_accept"):
			var target = targets[target_index]
			_clear_cursor()
			targeting = false
			if pending_action:
				_finish(["skill", pending_action, [target]])
			else:
				_finish(["attack", target])
		elif event.is_action_pressed("ui_cancel"):
			_clear_cursor()
			targeting = false
			show()
			if pending_action:
				_on_skills()
			else:
				_show_main()
		else:
			return
		get_viewport().set_input_as_handled()
	elif visible and in_skills and event.is_action_pressed("ui_cancel"):
		_show_main()
		get_viewport().set_input_as_handled()

func _update_cursor() -> void:
	_clear_cursor()
	targets[target_index].add_child(cursor)
	cursor.position = Vector2(-12, -90)

func _clear_cursor() -> void:
	if cursor.get_parent():
		cursor.get_parent().remove_child(cursor)

func _finish(result: Array) -> void:
	hide()
	_clear_skill_buttons()
	in_skills = false
	chosen.emit(result)
