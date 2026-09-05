class_name ItemDropper
extends Node3D
## Interaction：把库存物品"放下"回世界（Q 键输入 / try_drop() 直接调用）。
## Phase 2A 契约：先经 RuleValidator.validate_inventory_has()（抽取侧检查），
## 通过后执行 Inventory.remove_item() 并广播 InteractionResult；
## 不再返回裸 bool（见 InteractionResult 铁律）。
## 规则：每次丢弃"最早加入的堆叠"的第 1 件；放置于角色前方 drop_distance 处，
## 并向下射线探测承载面（地板/桌面/箱顶），物品底部贴面。
## 产出为统一占位模板 dropped_pickup.tscn（占位视觉=琥珀瓶；正式视觉后续数据驱动接入）。

const ACTION := &"drop_item"
const DROPPED_PICKUP_SCENE := preload("res://game/scenes/dev/dropped_pickup.tscn")
## 与 dropped_pickup.tscn 中 CylinderMesh height=0.5 匹配（半高用于贴面）。
const ITEM_HALF_HEIGHT := 0.25
## 承载面探测层（静态物层，同玩家移动碰撞层）。
const FLOOR_MASK := 1

@export_group("Dependencies")
## 拥有库存的角色（默认：父节点 = 玩家根节点）。
@export var actor_path: NodePath = ^".."

@export_group("Config")
## 放下物与角色的水平距离。
@export var drop_distance: float = 1.2
## 放下输入动作（InputMap 中定义，默认 Q）。
@export var drop_action: StringName = &"drop_item"

var _actor: Node3D = null


func _ready() -> void:
	_actor = get_node_or_null(actor_path) as Node3D
	if _actor == null:
		push_warning("ItemDropper: 未找到 actor（%s）" % actor_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.is_action_pressed(drop_action):
			try_drop()


## 丢下"最早加入堆叠"的第 1 件；返回 InteractionResult（禁止裸 bool）。
func try_drop() -> InteractionResult:
	var inventory := _resolve_inventory()
	if inventory == null:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_INVENTORY_UNKNOWN, ACTION, &"", &"",
			"actor 子树中未找到 Inventory"
		))
	var actor_id := GameState.get_actor_id_for_inventory(inventory.inventory_id)
	if inventory.stack_count() <= 0:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_INVENTORY_EMPTY, ACTION, actor_id, &"",
			"库存为空，无可丢下物品"
		))
	var stack := inventory.list_stacks()[0]
	var definition := stack.definition
	if definition == null:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_STATE_MISMATCH, ACTION, actor_id, &"",
			"堆叠缺少 definition"
		))
	# 统一闸门：抽取侧校验（库存是否有 1 件）。
	var verdict := RuleValidator.validate_inventory_has(inventory.inventory_id, definition.item_id, 1)
	if not verdict.success:
		return _finish(verdict)
	if inventory.remove_item(definition.item_id, 1) != 1:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_STATE_MISMATCH, ACTION, actor_id, definition.item_id,
			"校验通过但移除失败（状态不一致）"
		))
	_spawn_pickup(definition, _drop_position())
	print_debug("[ItemDropper] 放下 %s x1 @ %s" % [definition.item_id, _drop_position()])
	return _finish(InteractionResult.ok(
		ACTION, actor_id, definition.item_id,
		"丢下 %s x1" % definition.display_name,
		{"inventory_id": inventory.inventory_id, "amount": 1}
	))


func _resolve_inventory() -> Inventory:
	if _actor == null:
		return null
	var node := _actor.find_child("Inventory", true, false)
	return node as Inventory


## 计算放下坐标：actor 前方水平 drop_distance，垂直向下射线求承载面。
func _drop_position() -> Vector3:
	if _actor == null:
		return Vector3.ZERO
	var fwd := -_actor.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var target := _actor.global_position + fwd * drop_distance
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		target + Vector3.UP * 3.0, target + Vector3.DOWN * 6.0, FLOOR_MASK
	)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector3(target.x, ITEM_HALF_HEIGHT, target.z)
	var hit_pos := hit.get(&"position") as Vector3
	return Vector3(target.x, hit_pos.y + ITEM_HALF_HEIGHT, target.z)


## 实例化占位拾取物模板并放入世界（actor 的父节点 = 场景空间根）。
func _spawn_pickup(definition: ItemDefinition, pos: Vector3) -> void:
	if _actor == null:
		return
	var world: Node3D = _actor.get_parent() as Node3D
	if world == null:
		world = _actor.get_tree().current_scene as Node3D
	if world == null:
		push_error("ItemDropper: 无可放置节点的世界")
		return
	var pickup := DROPPED_PICKUP_SCENE.instantiate() as ItemPickup
	if pickup == null:
		push_error("ItemDropper: dropped_pickup.tscn 根节点不是 ItemPickup")
		return
	pickup.item_definition = definition
	pickup.amount = 1
	world.add_child(pickup)
	pickup.global_position = pos


## 统一出口：广播结果后返回。
func _finish(result: InteractionResult) -> InteractionResult:
	EventBus.interaction_result.emit(result)
	return result
