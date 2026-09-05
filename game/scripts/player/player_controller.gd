class_name PlayerController
extends CharacterBody3D
## Player：玩家角色控制（WASD 相对相机移动；相机视角由 CameraController 负责）。
## 交互输入（E）与目标检测由 InteractionManager 负责，本类不持有交互逻辑。
## 事件：Inventory 变化时转发到 EventBus.inventory_changed（R6）。

@export_group("Movement")
@export var move_speed: float = 5.0
@export var acceleration: float = 12.0

@export_group("Dependencies")
## 决定移动方向基准的相机节点（相对本节点的路径）。
@export var aim_rig_path: NodePath = ^"CameraRig"

var _rig: Node3D = null
var _inventory: Inventory = null
var _gravity: float = 0.0


func _ready() -> void:
	_rig = get_node_or_null(aim_rig_path) as Node3D
	_inventory = get_node_or_null("Inventory") as Inventory
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	if _inventory != null:
		_inventory.changed.connect(_on_inventory_changed)
	else:
		push_warning("PlayerController: 未找到 Inventory 子节点，库存事件不会广播")


## 返回本玩家持有的库存（供后续交付流程使用）；可能为 null。
func get_inventory() -> Inventory:
	return _inventory


func _physics_process(delta: float) -> void:
	var input_vec := Input.get_vector(
		&"move_left", &"move_right", &"move_back", &"move_forward"
	)
	# input_vec.y 为正 = 向前；基于相机（含偏航/俯仰）的世界朝向。
	var basis: Basis = global_transform.basis
	if _rig != null:
		basis = _rig.global_transform.basis
	var wish_dir := basis * Vector3(input_vec.x, 0.0, input_vec.y)
	wish_dir.y = 0.0

	var target_h := Vector3.ZERO
	if wish_dir.length_squared() > 0.0001:
		target_h = wish_dir.normalized() * move_speed

	velocity.x = move_toward(velocity.x, target_h.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_h.z, acceleration * delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()


func _on_inventory_changed() -> void:
	if _inventory != null:
		EventBus.inventory_changed.emit(_inventory)
