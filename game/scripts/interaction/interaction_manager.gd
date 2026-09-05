class_name InteractionManager
extends Node3D
## Interaction：交互检测管理器。
## 每个物理帧从相机向正前方发射短射线（专用 layer），命中 Interactable 时：
##  1. 目标变化时广播 InteractionPrompt（EventBus，UI 零耦合）；
##  2. 玩家按下交互动作（默认 E）时调用 Interactable.interact(actor)。
## 命中目标 = Interactable 组件直接挂在碰撞体节点上（组件约定，见 Interactable 文档）。

## 交互专用碰撞层（DevPlayground 中物品置于该层，避免被地面等阻挡）。
const INTERACTION_MASK := 2

@export_group("Dependencies")
## 交互发起者（默认：父节点，即玩家根节点）。
@export var actor_path: NodePath = ^".."
## 视线来源相机（相对本节点的路径）。
@export var camera_path: NodePath = ^"../CameraRig/Camera3D"

@export_group("Config")
@export var max_range: float = 2.8
## 交互输入动作（InputMap 中定义）。
@export var interact_action: StringName = &"interact"

var _actor: Node3D = null
var _camera: Camera3D = null
var _current: Interactable = null


func _ready() -> void:
	_actor = get_node_or_null(actor_path) as Node3D
	_camera = get_node_or_null(camera_path) as Camera3D
	if _actor == null:
		push_warning("InteractionManager: 未找到 actor（%s）" % actor_path)
	if _camera == null:
		push_warning("InteractionManager: 未找到相机（%s）" % camera_path)


func _physics_process(_delta: float) -> void:
	if _camera == null:
		return
	var target := _raycast_target()
	if target != _current:
		_current = target
		if is_instance_valid(_current) and _current.can_interact(_actor):
			EventBus.interaction_prompt_changed.emit(_current.make_prompt())
		else:
			_current = null
			EventBus.interaction_prompt_changed.emit(null)
	if _current != null and Input.is_action_just_pressed(interact_action):
		if is_instance_valid(_current) and _current.can_interact(_actor):
			_current.interact(_actor)
		else:
			_current = null
			EventBus.interaction_prompt_changed.emit(null)


## 从相机正前方向 max_range 距离发射交互射线；命中 Interactable 返回之，否则 null。
func _raycast_target() -> Interactable:
	var space := get_world_3d().direct_space_state
	var origin := _camera.global_position
	var end := origin - _camera.global_transform.basis.z * max_range
	var query := PhysicsRayQueryParameters3D.create(origin, end, INTERACTION_MASK)
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	var collider := result.get(&"collider") as Node3D
	return _resolve_interactable(collider)


## 组件解析约定（Phase 2B）：命中物自身 → 命中物固定子节点 "Interactable"
## → 向上最多 3 层祖先中的 Interactable。
func _resolve_interactable(collider: Node3D) -> Interactable:
	if collider == null:
		return null
	if collider is Interactable:
		return collider as Interactable
	var component := collider.get_node_or_null("Interactable")
	if component is Interactable:
		return component as Interactable
	var node := collider.get_parent() as Node3D
	for _depth in 3:
		if node == null:
			break
		if node is Interactable:
			return node as Interactable
		node = node.get_parent() as Node3D
	return null
