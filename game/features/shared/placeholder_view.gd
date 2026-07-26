extends Control

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel

var _title: String = ""
var _body: String = ""


func _ready() -> void:
	_render()


func configure(title: String, body: String) -> void:
	_title = title
	_body = body
	if is_node_ready():
		_render()


func _render() -> void:
	title_label.text = _title
	body_label.text = _body
