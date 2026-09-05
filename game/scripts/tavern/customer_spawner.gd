class_name CustomerSpawner
extends Node
## Tavern：顾客生成器（场景节点）。
## 从 DataRegistry 取 NPCProfile（profile_ids 队列轮转），实例化 npc_customer.tscn，
## 在门外出生 → NPC 自行走完顾客流程 → npc_left 后释放引用。
## auto_spawn = true 时循环接待（演示/手动验收）；测试可置 false 并手动 spawn_customer()。
## 启动时 ensure 酒馆钱箱钱包（Transaction.TAVERN_TILL_ID）。

const NPC_STAND_Y := 0.75
## 门外出生偏移（门朝向酒馆内部为 +Z 时，-Z 为门外；与 NPCController.EXIT_OFFSET 一致）。
const SPAWN_OUTSET := 1.2

@export var npc_scene: PackedScene = preload("res://game/scenes/dev/npc_customer.tscn")
## 顾客档案队列（DataRegistry 已注册的 NPCProfile id）。
@export var profile_ids: Array[StringName] = [&"npc_tommy", &"npc_grimble"]
@export var auto_spawn: bool = true
@export var respawn_delay: float = 5.0
@export var door_path: NodePath = ^"../Door"

var _door: Node3D = null
var _active_npc: NPCController = null
var _queue_index := 0
var _auto_timer := 0.0


func _ready() -> void:
	_door = get_node_or_null(door_path) as Node3D
	if _door == null:
		push_warning("CustomerSpawner: 未找到门（%s）" % door_path)
	GameState.ensure_wallet(Transaction.TAVERN_TILL_ID)
	EventBus.npc_left.connect(_on_npc_left)
	_auto_timer = respawn_delay


func _process(delta: float) -> void:
	if not auto_spawn:
		return
	if _active_npc != null:
		return
	if not DayManager.can_spawn_customer():
		return
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		_auto_timer = respawn_delay
		spawn_customer()


## 生成下一位顾客（profile_ids 队列轮转）；失败返回 null。
## 营业闸门：仅 DayManager.can_spawn_customer()（Service 且未到关门前窗口）允许。
## 测试可直接调用：同批 NPC 依队列顺序为 tommy → grimble → tommy → …
func spawn_customer() -> NPCController:
	if not DayManager.can_spawn_customer():
		print_debug("[CustomerSpawner] 拒绝生成：未营业或临近关门（phase=%s）" % DayManager.phase)
		return null
	if _active_npc != null and is_instance_valid(_active_npc):
		push_warning("CustomerSpawner: 已有顾客在场（%s），拒绝生成" % _active_npc.get_npc_id())
		return null
	if profile_ids.is_empty():
		push_warning("CustomerSpawner: profile_ids 为空")
		return null
	var profile_id := profile_ids[_queue_index % profile_ids.size()]
	_queue_index += 1
	var profile := DataRegistry.get_npc_profile(profile_id)
	if profile == null:
		push_error("CustomerSpawner: 档案未注册 %s" % profile_id)
		return null
	if GameState.has_actor(profile_id):
		push_warning("CustomerSpawner: %s 已在场（重复实例）" % profile_id)
		return null
	var npc := npc_scene.instantiate() as NPCController
	if npc == null:
		push_error("CustomerSpawner: npc_scene 根节点不是 NPCController")
		return null
	var zone := get_parent() as Node3D
	if zone == null:
		push_error("CustomerSpawner: 父节点非 Node3D，无法安放 NPC")
		npc.free()
		return null
	var spawn_position := _spawn_position()
	npc.setup(profile, spawn_position)
	zone.add_child(npc)
	npc.global_position = spawn_position
	_active_npc = npc
	EventBus.npc_entered.emit(profile_id)
	print_debug("[CustomerSpawner] 生成 %s @ %s" % [profile_id, spawn_position])
	return npc


func get_active_npc() -> NPCController:
	if _active_npc != null and not is_instance_valid(_active_npc):
		_active_npc = null
	return _active_npc


func _spawn_position() -> Vector3:
	if _door != null:
		var p := _door.global_position
		return Vector3(p.x, NPC_STAND_Y, p.z - SPAWN_OUTSET)
	return Vector3(0.0, NPC_STAND_Y, 0.0)


func _on_npc_left(_npc_id: StringName) -> void:
	_active_npc = null
