extends Control

@onready var play_btn: Button = $Buttons/PlayButton
@onready var friends_btn: Button = $Buttons/FriendsButton
@onready var training_btn: Button = $Buttons/TrainingButton
@onready var shop_btn: Button = $Buttons/ShopButton
@onready var settings_btn: Button = $Buttons/SettingsButton
@onready var leaderboard_btn: Button = $Buttons/LeaderboardButton

func _ready() -> void:
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://game.tscn"))
	training_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://game.tscn"))
	friends_btn.pressed.connect(func(): print("Friends"))
	shop_btn.pressed.connect(func(): print("Shop"))
	settings_btn.pressed.connect(func(): print("Settings"))
	leaderboard_btn.pressed.connect(func(): print("Leaderboard"))
