class_name CameraController
extends Node3D
## Player：第三人称/第一人称观察相机控制器（灰盒版）。
## 偏航角写入 body_path 指定的父级节点（角色身体），俯仰角写入自身 rotation.x。
## 交互：左键点击捕获鼠标，Esc 释放（ui_cancel 内建动作）。

@export_group("Look")
@export var sensitivity: float = 0.0022
## 俯仰角限制（弧度，上下各约 ±83°）。
@export var pitch_limit: float = 1.45

@export_group("Dependencies")
## 被旋转偏航的目标节点（通常为父级 CharacterBody3D）。
@export var body_path: NodePath = ^".."

var _body: Node3D = null
var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	_body = get_node_or_null(body_path) as Node3D
	if _body == null:
		push_warning("CameraController: 未找到偏航目标节点（body_path=%s）" % body_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
				and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * sensitivity
		_pitch = clampf(_pitch - mm.relative.y * sensitivity, -pitch_limit, pitch_limit)
		_apply_orientation()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()


## 直接设置观察朝向（供自动化测试/传送后校正）。
func set_orientation(p_yaw: float, p_pitch: float) -> void:
	_yaw = p_yaw
	_pitch = clampf(p_pitch, -pitch_limit, pitch_limit)
	_apply_orientation()


func _apply_orientation() -> void:
	if _body != null:
		_body.rotation.y = _yaw
	rotation.x = _pitch
