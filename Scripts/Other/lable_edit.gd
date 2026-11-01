@tool
extends HBoxContainer
class_name LableEdit

signal value_changed(new_value: Variant)

@export var label: Label
@export var line_edit: LineEdit
@export var check_box: CheckBox

## Title ввода
@export var text: String = 'Text':
	set(new_value):
		text = new_value
		label.text = new_value+':'
## Тип ввода
@export_enum('text', 'int', 'float', 'bool') var input_type: String = 'text':
	set(new_value):
		input_type = new_value
		line_edit.placeholder_text = input_type
## Вводимое значение
signal change_value(value: String)
@export var value: String = 'test':
	set(new_value):
		value = new_value
		line_edit.text = new_value
		change_value.emit(value)

## Позиция курсора
var caret_column: int = 0

func _ready() -> void:
	# Если тип ввода bool, то мы используем check_box
	if input_type == 'bool':
		var lower: String = value.to_lower()
		if lower == "true" or lower == "1":
			check_box.button_pressed = true
		elif lower == "false" or lower == "0":
			check_box.button_pressed = false
		check_box.show()
		line_edit.hide()
		check_box.pressed.connect(_on_check_box_pressed)
	# Если тип ввода не bool, то мы используем line_edit
	else:
		check_box.hide()
		line_edit.show()
		line_edit.text_changed.connect(_on_line_edit_text_changed)

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		line_edit.release_focus()
		check_box.release_focus()

## Обрабатываем изменение check_box
func _on_check_box_pressed() -> void:
	value_changed.emit(bool(check_box.button_pressed))

## Обрабатываем изменение line_edit
func _on_line_edit_text_changed(new_text: String) -> void:
	caret_column = line_edit.caret_column
	match input_type:
		'text':
			value = new_text
			value_changed.emit(new_text)
		'int':
			if new_text.is_valid_int():
				value = str(int(new_text))
				value_changed.emit(int(new_text))
			else:
				if new_text == '':
					value_changed.emit(int(0))
				else:
					line_edit.text = value
		'float':
			if new_text.is_valid_float():
				value = str(float(new_text))
				value_changed.emit(float(new_text))
			else:
				if new_text == '':
					value_changed.emit(float(0))
				else:
					line_edit.text = value
	line_edit.caret_column = caret_column
