extends Control
@onready var skalm_intro: Control = $Skalm_Intro
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var video_stream_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

@warning_ignore("unused_parameter")
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("skip_intro"):
		queue_free()

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		queue_free()
	else:
		_play_team_logo()
		skalm_intro.visible = false

func _on_video_stream_player_finished() -> void:
	animation_player.play("output_intro")
	await animation_player.animation_finished 
	video_stream_player.visible = false
	_play_game_logo()

func _play_team_logo() -> void:
	animation_player.play("input_intro")
	video_stream_player.play()

func _play_game_logo() -> void:
	animation_player.play("input_intro")
	audio_stream_player_2d.play()
	skalm_intro.visible = true
	await audio_stream_player_2d.finished
	animation_player.play("output_intro")
	await animation_player.animation_finished 
	queue_free()
