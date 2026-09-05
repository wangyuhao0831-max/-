extends Node
## Core：统一游戏行为验证入口（autoload）。
## 铁律 R3：AI/NPC/玩家交互欲修改权威游戏状态，必须先通过本类的验证规则；
## 验证通过后由调用方（Godot 侧）执行实际变更 —— Validator 只裁决、不代行。
## 所有规则返回 InteractionResult（禁止裸 bool 跨系统）。
## 规则签名约定（InteractionResult 字段语义）：
##   pickup/交付/drop → actor_id=执行者, target_id=物品 id（drop 同）；
##   npc_request_item → actor_id 为空, target_id=NPC id；
##   inventory 查询    → actor_id=inventory_id, target_id=item_id。
## 注：无 class_name —— 以 autoload 名 RuleValidator 作为全局访问符号。

## 校验通过：允许拾取（含 payload: inventory_id/amount）。
func validate_pickup(actor_id: StringName, item_id: StringName, amount: int) -> InteractionResult:
	const action := &"pickup_item"
	if amount <= 0:
		return _fail(action, actor_id, item_id, InteractionResult.CODE_INVALID_AMOUNT,
				"数量必须大于 0（got %d）" % amount)
	if not DataRegistry.has_item(item_id):
		return _fail(action, actor_id, item_id, InteractionResult.CODE_ITEM_UNKNOWN,
				"未知物品：%s" % item_id)
	if not GameState.has_actor(actor_id):
		return _fail(action, actor_id, item_id, InteractionResult.CODE_ACTOR_UNKNOWN,
				"未知交互者：%s" % actor_id)
	var inventory := GameState.get_inventory_for_actor(actor_id)
	if inventory == null:
		return _fail(action, actor_id, item_id, InteractionResult.CODE_INVENTORY_UNKNOWN,
				"交互者无可用库存（actor=%s）" % actor_id)
	var definition: ItemDefinition = DataRegistry.get_item(item_id)
	if not inventory.can_receive(definition, amount):
		var space := inventory.max_addable(definition)
		return _fail(action, actor_id, item_id, InteractionResult.CODE_INVENTORY_FULL,
				"背包空间不足（还差 %d 件）" % maxi(amount - space, 0),
				{"need": amount, "space": space})
	return _ok(action, actor_id, item_id,
			"允许拾取 %s x%d" % [item_id, amount],
			{"inventory_id": inventory.inventory_id, "amount": amount})


## 校验通过：actor 交付 amount 件 item 给 target（双方库存须可用且容量足够）。
func validate_deliver(actor_id: StringName, target_id: StringName, item_id: StringName, amount: int) -> InteractionResult:
	const action := &"deliver_item"
	if amount <= 0:
		return _fail(action, actor_id, target_id, InteractionResult.CODE_INVALID_AMOUNT,
				"数量必须大于 0（got %d）" % amount)
	if not DataRegistry.has_item(item_id):
		return _fail(action, actor_id, target_id, InteractionResult.CODE_ITEM_UNKNOWN,
				"未知物品：%s" % item_id)
	if not GameState.has_actor(actor_id):
		return _fail(action, actor_id, target_id, InteractionResult.CODE_ACTOR_UNKNOWN,
				"未知交付者：%s" % actor_id)
	if not GameState.has_actor(target_id):
		return _fail(action, actor_id, target_id, InteractionResult.CODE_TARGET_UNKNOWN,
				"未知接收者：%s" % target_id)
	var giver_inventory := GameState.get_inventory_for_actor(actor_id)
	if giver_inventory == null:
		return _fail(action, actor_id, target_id, InteractionResult.CODE_INVENTORY_UNKNOWN,
				"交付者无可用库存（actor=%s）" % actor_id)
	var have := giver_inventory.get_count(item_id)
	if have < amount:
		return _fail(action, actor_id, target_id, InteractionResult.CODE_INSUFFICIENT_ITEM,
				"交付者库存不足（have=%d, need=%d）" % [have, amount],
				{"have": have, "need": amount})
	var receiver_inventory := GameState.get_inventory_for_actor(target_id)
	if receiver_inventory == null:
		return _fail(action, actor_id, target_id, InteractionResult.CODE_INVENTORY_UNKNOWN,
				"接收者无可用库存（target=%s）" % target_id)
	var definition: ItemDefinition = DataRegistry.get_item(item_id)
	if not receiver_inventory.can_receive(definition, amount):
		var space := receiver_inventory.max_addable(definition)
		return _fail(action, actor_id, target_id, InteractionResult.CODE_INVENTORY_FULL,
				"接收者空间不足（还差 %d 件）" % maxi(amount - space, 0),
				{"need": amount, "space": space})
	return _ok(action, actor_id, target_id,
			"允许交付 %s x%d：%s -> %s" % [item_id, amount, actor_id, target_id],
			{"from_inventory": giver_inventory.inventory_id,
				"to_inventory": receiver_inventory.inventory_id, "amount": amount})


## 校验通过：NPC 可以请求该物品（档案存在 + 物品存在 + 符合偏好）。
## 注：NPC 运行态/酒馆库存层面的规则在 NPC 运行态接入（Phase 2B）后扩展。
func validate_npc_request(npc_id: StringName, item_id: StringName, amount: int) -> InteractionResult:
	const action := &"npc_request_item"
	if amount <= 0:
		return _fail(action, &"", npc_id, InteractionResult.CODE_INVALID_AMOUNT,
				"数量必须大于 0（got %d）" % amount)
	if not DataRegistry.has_item(item_id):
		return _fail(action, &"", npc_id, InteractionResult.CODE_ITEM_UNKNOWN,
				"未知物品：%s" % item_id)
	var profile: NPCProfile = DataRegistry.get_npc_profile(npc_id)
	if profile == null:
		return _fail(action, &"", npc_id, InteractionResult.CODE_NPC_UNKNOWN,
				"未知 NPC 档案：%s" % npc_id)
	if not profile.prefers(item_id):
		return _fail(action, &"", npc_id, InteractionResult.CODE_ITEM_NOT_PREFERRED,
				"%s 不偏好 %s" % [profile.display_name, item_id],
				{"preferred": profile.preferred_item_ids.duplicate()})
	return _ok(action, &"", npc_id,
			"允许 %s 请求 %s x%d" % [npc_id, item_id, amount],
			{"npc_id": npc_id, "item_id": item_id, "amount": amount})


## 校验通过：库存持有量足够（可用作 NPC 请求/交付等前置抽取检查）。
func validate_inventory_has(inventory_id: StringName, item_id: StringName, amount: int) -> InteractionResult:
	const action := &"inventory_has"
	if amount <= 0:
		return _fail(action, inventory_id, item_id, InteractionResult.CODE_INVALID_AMOUNT,
				"数量必须大于 0（got %d）" % amount)
	if not DataRegistry.has_item(item_id):
		return _fail(action, inventory_id, item_id, InteractionResult.CODE_ITEM_UNKNOWN,
				"未知物品：%s" % item_id)
	var inventory := GameState.get_inventory(inventory_id)
	if inventory == null:
		return _fail(action, inventory_id, item_id, InteractionResult.CODE_INVENTORY_UNKNOWN,
				"未知库存：%s" % inventory_id)
	var have := inventory.get_count(item_id)
	if have < amount:
		return _fail(action, inventory_id, item_id, InteractionResult.CODE_INSUFFICIENT_ITEM,
				"库存不足（have=%d, need=%d）" % [have, amount],
				{"have": have, "need": amount})
	return _ok(action, inventory_id, item_id,
			"库存充足（%s x%d/%d）" % [item_id, have, amount],
			{"have": have, "need": amount})


## 校验通过：库存可接收 amount 件（拾取/交付/入库的容量侧检查）。
func validate_inventory_can_receive(inventory_id: StringName, item_id: StringName, amount: int) -> InteractionResult:
	const action := &"inventory_capacity"
	if amount <= 0:
		return _fail(action, inventory_id, item_id, InteractionResult.CODE_INVALID_AMOUNT,
				"数量必须大于 0（got %d）" % amount)
	if not DataRegistry.has_item(item_id):
		return _fail(action, inventory_id, item_id, InteractionResult.CODE_ITEM_UNKNOWN,
				"未知物品：%s" % item_id)
	var inventory := GameState.get_inventory(inventory_id)
	if inventory == null:
		return _fail(action, inventory_id, item_id, InteractionResult.CODE_INVENTORY_UNKNOWN,
				"未知库存：%s" % inventory_id)
	var definition: ItemDefinition = DataRegistry.get_item(item_id)
	var space := inventory.max_addable(definition)
	if space < amount:
		return _fail(action, inventory_id, item_id, InteractionResult.CODE_INVENTORY_FULL,
				"空间不足（need=%d, space=%d）" % [amount, space],
				{"need": amount, "space": space})
	return _ok(action, inventory_id, item_id,
			"空间充足（need=%d, space=%d）" % [amount, space],
			{"need": amount, "space": space})


## 统一行为路由（R3 预留口）：按 action 分发到上面的强类型规则。
## 未来 AI Intent 将以此 action + params 形态进入本入口。
## 参数键：actor_id / target_id / item_id / inventory_id / amount（StringName/数值）。
func validate_action(action: StringName, params: Dictionary) -> InteractionResult:
	var actor_id := _param_string_name(params, &"actor_id")
	var target_id := _param_string_name(params, &"target_id")
	var item_id := _param_string_name(params, &"item_id")
	var inventory_id := _param_string_name(params, &"inventory_id")
	var amount := int(params.get(&"amount", 0))
	match action:
		&"pickup_item":
			return validate_pickup(actor_id, item_id, amount)
		&"deliver_item":
			return validate_deliver(actor_id, target_id, item_id, amount)
		&"npc_request_item":
			# 约定：NPC 以 target_id 传入（见类注释）。
			return validate_npc_request(target_id, item_id, amount)
		&"inventory_has":
			return validate_inventory_has(inventory_id, item_id, amount)
		&"inventory_capacity":
			return validate_inventory_can_receive(inventory_id, item_id, amount)
		_:
			return _fail(action, actor_id, target_id, InteractionResult.CODE_ACTION_UNKNOWN,
					"未知行为：%s" % action)


func _ok(action: StringName, actor_id: StringName, target_id: StringName, message: String, payload: Dictionary) -> InteractionResult:
	return InteractionResult.ok(action, actor_id, target_id, message, payload)


func _fail(action: StringName, actor_id: StringName, target_id: StringName, code: StringName, message: String, payload: Dictionary = {}) -> InteractionResult:
	return InteractionResult.failed(code, action, actor_id, target_id, message, payload)


## 从参数字典取 StringName（容忍 String/StringName/null）。
func _param_string_name(params: Dictionary, key: StringName) -> StringName:
	var value: Variant = params.get(key, null)
	if value is StringName:
		return value as StringName
	if value is String:
		return StringName(value as String)
	return &""
