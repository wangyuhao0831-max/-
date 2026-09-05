class_name DaySummary
extends RefCounted
## Tavern：单日结算数据（纯数据快照；由 DayManager 在进入 DaySummary 阶段生成，
## 经 EventBus.day_summary_ready 广播，HUD 显示 / 存档引用）。

var day: int = 0
var customers: int = 0
var completed_orders: int = 0
var failed_orders: int = 0
## 当日营业收入（订单实收金币合计）。
var revenue: int = 0
## 当日售出物品成本合计（def.cost × 数量；记账口径，暂不从金币中扣除）。
var cost: int = 0
var profit: int = 0
## 当日声望变化（成功 +REP_SUCCESS / 失败 +REP_FAIL）。
var reputation_change: int = 0
## 结算时钱箱金币。
var gold: int = 0


func to_text() -> String:
	return "Day %d | 顾客 %d | 完成 %d | 失败 %d | 收入 %d | 成本 %d | 利润 %d | 声望 %+d | 金币 %d" % [
		day, customers, completed_orders, failed_orders, revenue, cost, profit,
		reputation_change, gold,
	]
