extends VBoxContainer

## Кнопка для открытия окна
@export var switch_button: Button
## Видимость кнопок
@export var window_visible: bool = false:
	set(new_value):
		window_visible = new_value
		_init_visible_window()

func _ready() -> void:
	switch_button.button_pressed = window_visible
	_init_visible_window()
	switch_button.toggled.connect(_togle_visible_window)

## Меняет параметр видимости окна при изменении кнопки
func _togle_visible_window(toggle_on: bool) -> void:
	window_visible = toggle_on
	switch_button.button_pressed = toggle_on

## Меняет видимость кнопок
func _init_visible_window() -> void:
	var childs: Array = get_children()
	if get_child_count() > 1:
		for i: int in range(get_child_count()-1):
			childs[i+1].visible = window_visible
