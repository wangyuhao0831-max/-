extends Node
## Core：全局事件总线（架构规则 R6）。
## 只声明信号、不做任何业务逻辑；所有跨系统事件经由此总线广播。
## 依赖方向：EventBus 不依赖业务实现，仅引用领域数据类型（class_name 全局符号）。
## 注：无 class_name —— 以 autoload 名 EventBus 作为全局访问符号
## （Godot 4.7 禁止全局类名与 autoload 同名）。

## 游戏启动引导完成（由 GameManager 发出；参数为启动时刻毫秒）。
signal game_booted(boot_time_msec: int)

## 当前可交互目标发生变化。prompt 为 null 表示没有可交互目标（UI 应清空提示）。
signal interaction_prompt_changed(prompt: InteractionPrompt)

## 某个 Inventory 的内容发生变化（携带引用，供 HUD/后续系统刷新显示）。
signal inventory_changed(inventory: Inventory)

## 一次交互结束（成功或失败皆广播；由执行方发出，UI/日志订阅做反馈）。
signal interaction_result(result: InteractionResult)

# --- Phase 2B：NPC / 订单 / 交易 ---

## NPC 状态切换（previous/current 为 NPCStateMachine 状态 StringName）。
signal npc_state_changed(npc_id: StringName, previous_state: StringName, current_state: StringName)

## NPC 完成消费离开酒馆（随后节点被释放）。
signal npc_left(npc_id: StringName)

## 新订单创建（NPC 落座后请求）。
signal order_created(order: Order)

## 订单交付完成（等待付款/饮用）。
signal order_fulfilled(order: Order)

## 订单收款并关闭。
signal order_closed(order: Order)

## 一笔最小交易完成（NPC 付款入账酒馆）。
signal transaction_completed(transaction: Transaction)
