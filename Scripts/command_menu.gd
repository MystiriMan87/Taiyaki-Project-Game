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
var allies: Array = []
var target_pool: Array = []

const SKILL_COLUMNS := 2
var skill_grid: GridContainer

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

func open(a: Battler, living_enemies: Array, living_allies: Array = []) -> void:
	_clear_skill_buttons()
	_clear_cursor()
	targeting = false
	in_skills = false
	pending_action = null
	actor = a
	targets = living_enemies
	allies = living_allies
	targeting = false
	pending_action = null
	mp_label.text = "%s  Lv %d   MP %d/%d" % [a.stats.display_name, Game.get_level(a.stats), a.mp, a.stats.max_mp]
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
	_clear_skill_buttons()
	in_skills = true
	$AttackButton.hide()
	skills_button.hide()
	$DefendButton.hide()
	
	skill_grid = GridContainer.new()
	skill_grid.columns = SKILL_COLUMNS
	skill_grid.add_theme_constant_override("h_separation", 8)
	skill_grid.add_theme_constant_override("v_separation", 6)
	skill_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(skill_grid)
	
	var first_enabled: Button = null
	for action in actor.stats.actions:
		if action == null:
			continue
		var b := Button.new()
		b.text = "%s (%d MP)" % [action.display_name, action.mp_cost]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = actor.mp < action.mp_cost
		b.pressed.connect(_on_skill_picked.bind(action))
		skill_grid.add_child(b)
		if first_enabled == null and not b.disabled:
			first_enabled = b
			
	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_show_main)
	skill_grid.add_child(back)
	
	(first_enabled if first_enabled else back).grab_focus()

func _on_skill_picked(action: BattleAction) -> void:
	if action not in actor.stats.actions:
		return
	pending_action = action
	match action.target_type:
		BattleAction.TargetType.ALL_ENEMIES:
			_finish(["skill", action, targets])
		BattleAction.TargetType.ALL_ALLIES:
			_finish(["skill", action, allies])
		BattleAction.TargetType.ONE_ALLY:
			_begin_targeting(allies)
		_:
			_begin_targeting(targets)

func _on_attack() -> void:
	pending_action = null
	_begin_targeting(targets)

func _clear_skill_buttons() -> void:
	if skill_grid:
		remove_child(skill_grid)
		skill_grid.queue_free()
		skill_grid = null
	skill_buttons.clear()

# --- Targeting ----------------------------------------------------------

func _begin_targeting(pool: Array) -> void:
	if pool.is_empty():
		return
	target_pool = pool
	await get_tree().process_frame
	targeting = true
	target_index = 0
	hide()
	_update_cursor()

func _unhandled_input(event: InputEvent) -> void:
	if targeting:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			target_index = wrapi(target_index - 1, 0, target_pool.size())
			_update_cursor()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			target_index = wrapi(target_index + 1, 0, target_pool.size())
			_update_cursor()
		elif event.is_action_pressed("ui_accept"):
			var target = target_pool[target_index]
			_clear_cursor()
			targeting = false
			if pending_action:
				_finish(["skill", pending_action, [target]])
			else:
				_finish(["attack", target])
		elif event.is_action_pressed("ui_cancel"):
			_clear_cursor()
			targeting = false
			var was_skill := pending_action != null
			pending_action = null
			show()
			if was_skill and skill_grid != null:
				_focus_grid()
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
	target_pool[target_index].add_child(cursor)
	cursor.position = Vector2(-12, -90)

func _clear_cursor() -> void:
	if cursor.get_parent():
		cursor.get_parent().remove_child(cursor)

func _finish(result: Array) -> void:
	hide()
	_clear_skill_buttons()
	_clear_cursor()
	in_skills = false
	targeting = false
	chosen.emit(result)
	
func _focus_grid() -> void:
	if skill_grid == null:
		return
	for b in skill_grid.get_children():
		if b is Button and not b.disabled:
			b.grab_focus()
			return
