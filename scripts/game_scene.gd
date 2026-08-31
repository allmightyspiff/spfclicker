extends Node2D

@onready var player_name_label: Label = %PlayerNameLabel
@onready var score_label: Label = %ScoreLabel
@onready var cps_label: Label = %CpsLabel
@onready var save_button: Button = %SaveButton
@onready var menu_button: Button = %MenuButton
@onready var red_button: Button = %RedButton
@onready var fx_container: Control = %FXContainer
@onready var bong_player: AudioStreamPlayer = %BongPlayer

# Clickers UI
@onready var clickers_button: Button = %ClickersButton
@onready var clickers_panel: PanelContainer = %ClickersPanel
@onready var clickers_close_button: Button = %ClickersCloseButton
@onready var passive_rate_label: Label = %PassiveRateLabel

# Auto Clicker (1 CPS)
@onready var auto_clicker_owned_label: Label = %AutoClickerOwnedLabel
@onready var auto_clicker_buy_button: Button = %AutoClickerBuyButton

# Double Clicker (2 CPS)
@onready var double_clicker_owned_label: Label = %DoubleClickerOwnedLabel
@onready var double_clicker_buy_button: Button = %DoubleClickerBuyButton

var _button_tween: Tween

func _ready() -> void:
	# Hide clickers panel by default
	clickers_panel.visible = false
	
	# Initialize UI from GameManager
	_update_player_name(GameManager.player_name)
	_update_score(GameManager.score)
	_update_clickers_ui()
	
	# Connect signals
	GameManager.score_changed.connect(_update_score)
	GameManager.player_name_changed.connect(_update_player_name)
	GameManager.clickers_changed.connect(_update_clickers_ui)
	
	red_button.pressed.connect(_on_red_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	clickers_button.pressed.connect(_on_clickers_button_pressed)
	clickers_close_button.pressed.connect(_on_clickers_close_pressed)
	auto_clicker_buy_button.pressed.connect(_on_auto_clicker_buy_pressed)
	double_clicker_buy_button.pressed.connect(_on_double_clicker_buy_pressed)

func _update_player_name(new_name: String) -> void:
	player_name_label.text = "Player: %s" % new_name

func _update_score(new_score: int) -> void:
	score_label.text = "Clicks: %s" % _format_number(new_score)
	_update_buy_buttons_affordability()

func _update_clickers_ui() -> void:
	var total_cps = GameManager.get_total_cps()
	passive_rate_label.text = "Passive Income: %d clicks / sec" % total_cps
	
	if total_cps > 0:
		cps_label.text = "(+%d/s)" % total_cps
		cps_label.visible = true
	else:
		cps_label.visible = false
		
	auto_clicker_owned_label.text = "Owned: %d" % GameManager.auto_clickers
	double_clicker_owned_label.text = "Owned: %d" % GameManager.double_clickers
	
	_update_buy_buttons_affordability()

func _update_buy_buttons_affordability() -> void:
	var auto_cost = GameManager.get_auto_clicker_cost()
	auto_clicker_buy_button.text = "Buy (%s)" % _format_number(auto_cost)
	auto_clicker_buy_button.disabled = not GameManager.can_afford_auto_clicker()
	
	var double_cost = GameManager.get_double_clicker_cost()
	double_clicker_buy_button.text = "Buy (%s)" % _format_number(double_cost)
	double_clicker_buy_button.disabled = not GameManager.can_afford_double_clicker()

func _on_red_button_pressed() -> void:
	GameManager.add_click()
	_play_bong_sound()
	_animate_button_press()
	_spawn_floating_text()

func _play_bong_sound() -> void:
	if bong_player:
		bong_player.pitch_scale = randf_range(0.96, 1.04)
		bong_player.play()

func _animate_button_press() -> void:
	if _button_tween and _button_tween.is_valid():
		_button_tween.kill()
	
	# Center pivot for scale animation
	red_button.pivot_offset = red_button.size / 2.0
	red_button.scale = Vector2(0.9, 0.9)
	
	_button_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(red_button, "scale", Vector2(1.0, 1.0), 0.2)

func _spawn_floating_text() -> void:
	var label = Label.new()
	label.text = "+1"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	
	var mouse_pos = fx_container.get_local_mouse_position()
	var random_offset = Vector2(randf_range(-25, 25), randf_range(-10, 10))
	label.position = mouse_pos + random_offset - Vector2(15, 20)
	
	fx_container.add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func _on_save_button_pressed() -> void:
	if GameManager.save_game():
		_spawn_save_notification()

func _spawn_save_notification() -> void:
	var label = Label.new()
	label.text = "💾 Game Saved!"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.65, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.08, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	
	var save_pos = save_button.global_position
	label.position = save_pos + Vector2(-20, 42)
	
	fx_container.add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 25.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func _on_clickers_button_pressed() -> void:
	clickers_panel.visible = true
	_update_clickers_ui()

func _on_clickers_close_pressed() -> void:
	clickers_panel.visible = false

func _on_auto_clicker_buy_pressed() -> void:
	if GameManager.buy_auto_clicker():
		_update_clickers_ui()

func _on_double_clicker_buy_pressed() -> void:
	if GameManager.buy_double_clicker():
		_update_clickers_ui()

func _on_menu_button_pressed() -> void:
	GameManager.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _format_number(n: int) -> String:
	var s = str(n)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			res = "," + res
		res = s[i] + res
		count += 1
	return res
