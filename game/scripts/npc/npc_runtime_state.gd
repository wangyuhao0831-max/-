class_name NPCRuntimeState
extends RefCounted
## NPC：运行时状态（Phase 2B）。
## 与静态档案（NPCProfile）分离：本对象 = 本次进店实例的快照/状态引用。
## 权威数值（钱包/库存/座位归属）存于 GameState / 组件，本类只做实例级关联，
## 为后续序列化/存档与 AI 建议落点预留（AI 不参与决策，仅预留接口位）。

## NPC actor id（== profile.npc_id，实例唯一约定）。
var npc_id: StringName = &""
## 静态档案引用。
var profile: NPCProfile = null
## 本次进店的出生/离店坐标（世界坐标）。
var spawn_position: Vector3 = Vector3.ZERO
## 当前座位引用（入座后持有，离店释放）。
var seat: TavernSeat = null
## 当前订单 id（下单后持有；&"" = 无）。
var order_id: StringName = &""
## 入店时刻（Time.get_ticks_msec()）。
var entered_at_msec := 0


## 摘要（调试）。
func to_text() -> String:
	return "npc=%s order=%s seat=%s" % [
		npc_id, order_id, seat.name if seat != null else "-"
	]
