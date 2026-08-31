extends Control

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton

# Settings Modal Nodes
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var username_line_edit: LineEdit = %UsernameLineEdit
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value_label: Label = %VolumeValueLabel
@onready var settings_close_button: Button = %SettingsCloseButton

func _ready() -> void:
	# Hide settings dialog by default
	settings_panel.visible = false
	
	# Update continue button availability based on save file
	_update_continue_button()
	
	# Connect main menu buttons
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect settings controls
	username_line_edit.text_changed.connect(_on_username_changed)
	username_line_edit.text_submitted.connect(_on_username_submitted)
	volume_slider.value_changed.connect(_on_volume_changed)
	settings_close_button.pressed.connect(_on_settings_close_pressed)

func _update_continue_button() -> void:
	continue_button.disabled = not GameManager.has_save_file()

func _on_continue_pressed() -> void:
	if GameManager.load_game():
		get_tree().change_scene_to_file("res://scenes/game_scene.tscn")

func _on_new_game_pressed() -> void:
	GameManager.reset_score()
	get_tree().change_scene_to_file("res://scenes/game_scene.tscn")

func _on_settings_pressed() -> void:
	# Populate current values from GameManager
	username_line_edit.text = GameManager.player_name
	volume_slider.value = GameManager.volume * 100.0
	_update_volume_label(volume_slider.value)
	
	settings_panel.visible = true
	username_line_edit.grab_focus()

func _on_exit_pressed() -> void:
	if GameManager.score > 0 or GameManager.auto_clickers > 0 or GameManager.double_clickers > 0:
		GameManager.save_game()
	get_tree().quit()

func _on_username_changed(new_text: String) -> void:
	GameManager.player_name = new_text

func _on_username_submitted(new_text: String) -> void:
	GameManager.player_name = new_text
	username_line_edit.release_focus()

func _on_volume_changed(value: float) -> void:
	GameManager.volume = value / 100.0
	_update_volume_label(value)

func _update_volume_label(value: float) -> void:
	volume_value_label.text = "%d%%" % int(round(value))

func _on_settings_close_pressed() -> void:
	# Commit final username
	if not username_line_edit.text.strip_edges().is_empty():
		GameManager.player_name = username_line_edit.text
	GameManager.save_game()
	settings_panel.visible = false
