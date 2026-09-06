# TASKS —— 阶段验收清单

> 每次改动代码/文档后更新本文件。范围纪律（R11）：**只做当前阶段条目，不超 Sprint 扩展。**

## 阶段总览

| 阶段 | 名称 | 状态 |
|---|---|---|
| Phase 0 | Repository Audit + Project Bootstrap | ✅ 完成 |
| Phase 1 | Vertical Slice Core Framework（Goal 1 完成） | ✅ Core Runtime 环 |
| Phase 2A | Core Contract Layer（GameState / DataRegistry / RuleValidator / InteractionResult） | ✅ 完成 |
| Phase 2B | Tavern Minimum Customer Loop（NPC 顾客环 / 座位 / 订单 / 最小交易） | ✅ 完成 |
| Phase 2C | Vertical Slice Stabilization（时间/日循环/经济/声望/存档/调试） | ✅ 完成 |

## Phase 0：Repository Audit + Project Bootstrap

- [x] 审计工作区、工具链（git / gh / Godot 4.7.2）与 GitHub 目标仓库
- [x] 建立 Godot 4.7 工程骨架（project.godot / icon.svg / main.tscn）
- [x] 建立目录结构占位（game/scripts 11 模块 + scenes + resources + tests）
- [x] 仓库规范化文件（.gitignore / .gitattributes / .editorconfig）
- [x] docs 基线：README / ARCHITECTURE / CODING_STANDARDS / TASKS
- [x] Godot headless 校验通过（--import 无错误）
- [x] git init（main）+ 首次 commit
- [x] 推送 GitHub（wangyuhao0831-max/-）并 API 验证

### Phase 0 验证协议记录

- Godot console 版本：`Godot_v4.7.2-stable_win64_console.exe`
- headless import 结果：无 error（记录于首次 commit 前）
- 目标远端：`https://github.com/wangyuhao0831-max/-`（public，main）

---

## Phase 1：Vertical Slice Core Framework

**当前里程碑：Goal 1（Core Runtime 灰盒环）✅ + Phase 2A（Core Contract Layer）✅ —— 见下。**
后续 Goal（NPC 运行态状态流 / 交付执行 / AI 层）未开始。

### Goal 1：Core Runtime（✅ 已完成 2026）

> 启动 → 出生 → WASD 移动 → 鼠标视角 → E 检测 Interactable → 拾取 Item → Inventory 更新
> 范围纪律：不做 AI Server、不做正式美术、仅 Godot Core Runtime + Primitive Mesh。

- [x] **Core**：`EventBus`（autoload 纯信号总线）、`GameManager`（autoload 启动编排）
- [x] **Player**：`PlayerController`（WASD 相对相机移动）、`CameraController`（鼠标视角/捕获/Esc 释放）
- [x] **Interaction**：`Interactable`（组件基类）、`InteractionManager`（相机射线检测+layer2 专用层）、`InteractionPrompt`（纯数据）、`ItemPickup`（世界拾取物）、`ItemDropper`（Q 键放下：库存→世界，贴面生成，可再拾回）
- [x] **Inventory**：`ItemDefinition`（Resource）、`ItemStack`、`Inventory`（Node 组件）+ `bottle_ale.tres` / `wooden_mug.tres`
- [x] **UI（调试）**：`DebugHUD`（CanvasLayer，仅订阅 EventBus，R8）+ `--smoke` headless 验收入口
- [x] **灰盒场景**：`game/scenes/dev/dev_playground.tscn`（地面/吧台/拾取物×5/出生点；Primitive Mesh）+ `dropped_pickup.tscn` 放下物模板（占位视觉）
- [x] InputMap 动作数据驱动（project.godot [input]：move_forward/back/left/right、interact、drop_item）
- [x] autoload 注册：`EventBus → GameManager`（顺序符合 ARCHITECTURE §5）

#### Goal 1 验证协议记录（Godot 4.7.2 console，全部通过）

1. `--headless --import`：无 parse error / script error
2. 主场景 headless 运行 240+ 帧：无运行时错误
3. `--headless -- --smoke` 自动化断言：场景加载 ✓ / 拾取 5 件（酒瓶×3+木杯×2）✓ / 按 ID 合并 2 堆叠 ✓ / EventBus.inventory_changed 广播 ✓ / **放下往返 ✓（Q：酒瓶 3→2→3，世界生成→拾回→无残留）** / 移动方向 ✓（W=-Z / S=+Z，exit 0）
4. **待手动验收**（headless 无法模拟真实输入）：WASD 手感 / 鼠标视角方向 / E 射线命中拾取 / Q 放下位置与再拾取 / DebugHUD 显示

#### Goal 1 已记录的实现教训（供后续参考）

- Godot 4.7 禁止 class_name 与 autoload 单例同名 → autoload 脚本不写 class_name
- `get_node_or_null()` 参数为 NodePath：传字符串字面量可隐式转换，传 `&"..."`（StringName）报 Parse Error
- RefCounted 协程 await 挂起期间必须持有引用（否则静默中断）
- GDScript lambda 按值捕获局部变量 → 跨回调计数用成员变量
- **Godot 前向 = -Z**：前进输入(+y)必须映射 `-basis.z`；曾出现 W/S 反转 bug（手动验收发现）
- 输入模拟断言注意惯性：线性加速度下速度反转需时间，按键窗口须长于反转时间
- 手动验收有效：W/S 反转正是靠实机试玩发现，headless 输入模拟于修复后补为回归断言

---

## Phase 2A：Core Contract Layer（✅ 已完成 2026）

> 目标：为后续所有会"修改权威状态"的系统建立统一契约 —— 验证闸门 + 注册/查询 + 结果类型。
> 范围纪律：不实现 AI Server / LLM / NPC AI / 动态任务 / 复杂经济。

### 交付清单

- [x] **GameState**（autoload）：运行阶段（boot→playing）+ Inventory/actor 注册表（StringName 查询、退出树自动注销、反查）；职责单一，非 God Object
- [x] **DataRegistry**（autoload）：boot 扫描 `resources/items`（ItemDefinition）与 `resources/npcs`（NPCProfile）；强类型便捷接口 + 通用 register/get 接口；**recipe/quest 为预留类别**（走同一套 API，无需改本类）
- [x] **NPCProfile**（纯数据 Resource，npc 模块）+ `resources/npcs/npc_tommy.tres`（偏好/性格标签/初始关系）
- [x] **RuleValidator**（autoload）：统一行为验证入口 —— `validate_pickup` / `validate_deliver` / `validate_npc_request` / `validate_inventory_has` / `validate_inventory_can_receive` + `validate_action`（action+params 统一路由，R3 AI Intent 预留口）。**只裁决不代行**：通过后由 Godot 调用方执行变更
- [x] **InteractionResult**：success/code/message/actor_id/target_id/action/payload + 全局结果码常量；**跨系统禁止裸 bool 结果**
- [x] Phase 1 契约化改造：`Interactable.interact()` / `ItemPickup`（校验→add→广播）/ `ItemDropper.try_drop()` 全部返回 InteractionResult 并经 RuleValidator；`Inventory`/`PlayerController` 接入 GameState 注册注销；EventBus 新增 `interaction_result` 信号；DebugHUD 显示最近结果
- [x] autoload 注册顺序：`EventBus → GameState → DataRegistry → RuleValidator → GameManager`（符合 ARCHITECTURE §5）
- [x] 自动测试：`game/tests/phase2a_contract_smoke.gd`（`--smoke-contract`）

### Phase 2A 验证协议记录（Godot 4.7.2 console，全部通过）

1. `--headless --import`：无 parse error（曾抓出：嵌套 typed Dictionary 不支持 / Variant 推断警告按错误处理，均已修复）
2. 主场景 headless 运行 240+ 帧：无运行时错误（scene + Resource load：DataRegistry boot scan 扫描 items/npcs .tres 全部加载成功）
3. `-- --smoke`（Phase 1 回归）：拾取/放下往返/移动方向 全 PASS —— 无回归
4. `-- --smoke-contract`：**51 项断言全 PASS**（exit 0）—— GameState 注册/反查/注销生命周期、DataRegistry 扫描/预留类别、InteractionResult 结构、RuleValidator 4 规则正/负例 + 统一路由
5. **待手动验收**：HUD"最近结果"文案 / 在无库存时按 Q 无报错提示体验

### Phase 2A 已记录的实现教训

- **Godot 不支持嵌套 typed 集合**（`Dictionary[StringName, Dictionary[StringName, Resource]]` 报 Parse Error）→ 内层用普通 Dictionary + 强类型接口收口
- 部分 warning 在本工程按 error 处理（4.7 严格模式）：`var x := dict.get(...)` 推断 Variant 会直接编译失败 → 显式标注类型
- RuleValidator 校验顺序会影响可观测结果码（如 deliver 先查"交付者持有量"再查"接收者容量"）→ 测试需按真实分支构造场景（曾把 6337 件交付当成容量测试，实际命中持有量不足分支）
- autoload 脚本编译失败会级联报"Failed to compile depended scripts"到所有引用方 → 先修根因文件再复查

---

## Phase 2B：Tavern Minimum Customer Loop（✅ 已完成 2026）

> 目标（唯一）：NPC 进店 → 找座 → 坐下 → 下单 → 玩家交付 → 付款 → 饮用 → 离开 → 座位释放。
> 范围纪律：Mock 数据、无 AI（仅保留决策点接口位）、不实现最终美术/复杂 UI。
> 验收：**两个 NPC 依次复用同一座位，完成两轮完整订单流程**（自动测试 28 断言）。

### 交付清单

- [x] **NPC 运行时**：`NPCRuntimeState`（实例快照/关联；存档候选）、`NPCStateMachine`（enter_tavern→find_seat→walk_to_seat→sit→order→wait_drink→pay→drink→leave 合法迁移表）
- [x] **NPCController**（Game Brain）：状态驱动 + 走动/入座/下单/收款/饮用/离场；**AI 决策预留位** = `_pick_drink_item()` 等决策点（当前确定性 Godot 规则）
- [x] **Tavern**：`TavernSeat`（占用状态/入座点/组注册）、`SeatManager`（收集/空闲查询/释放）、`Order`（OPEN→FULFILLED→CLOSED）、`OrderManager`（下单：RuleValidator.npc_request 闸门 + 钱包门槛；交付/收款标记）、`CustomerSpawner`（档案队列轮转/门外出生/auto 循环）
- [x] **Economy 最小**：`Transaction`（事实记录 + 酒馆钱箱 id）+ GameState 金币台账（register/credit/debit/balance）；物品 `price`、NPC 档案 `wallet_coins/body_tint` 数据驱动
- [x] **交付链**：`NpcDelivery`（NPC 子组件，InteractionManager 组件解析约定扩展：命中物 → 子节点 "Interactable" → 祖先）+ NPCController.deliver_from（validate_deliver → 扣/收 → 订单 FULFILLED → InteractionResult 广播）
- [x] NPC actor/inventory 注册 GameState（npc_inv_<id>），离店注销（含钱包清理）
- [x] 事件：npc_state_changed / npc_left / order_created / order_fulfilled / order_closed / transaction_completed
- [x] 场景：DevPlayground 新增 TavernZone（吧台/双座/门/管理器/生成器，auto_spawn 演示）+ `npc_customer.tscn` 模板（灰盒胶囊 + 交付组件 + Inventory）

### Phase 2B 验证协议记录（Godot 4.7.2 console，全部通过）

1. `--headless --import`：无 parse error
2. 主场景 headless 240+ 帧：无运行时错误（含 NPC 模板/酒馆区加载）
3. `-- --smoke`（Phase 1 回归）：拾取/放下往返/移动方向 全 PASS
4. `-- --smoke-contract`（Phase 2A 回归）：51 断言 全 PASS
5. `-- --smoke-loop`（新增）：**28 断言全 PASS** —— tommy→grimble 两轮：进店/找座/占座/下单/交付（玩家 3→2→1 瓶）/付款 8+8=16/交易×2/饮用/离场/座位释放→复用/actor+库存注销/订单×2 关闭
6. **待手动验收**：F5 观察自动顾客流 + E 对准等待中的 NPC 交付（提示 "交付 空酒瓶"）

### Phase 2B 已记录的实现教训

- **状态轮询别用"仅 OPEN"查询**：交付后订单阶段变 FULFILLED，用 `get_open_order()` 轮询会永远卡在 wait_drink —— 必须按 order_id 查全阶段
- 座位分配顺序与直觉可能相反（场景节点名排序结果以运行日志为准）→ 验收断言用"同一座位引用相等"而非硬编码座位名
- 交付侧断言要先算清库存账（拾 3 交 1 剩 2），曾写错期望值导致误报失败
- 进程退出时 `_exit_tree` 防御性释放座位/注销会出现在日志尾部 —— 排查"卡死"时要区分运行期日志与退出期日志

---

## Phase 2C：Vertical Slice Stabilization（✅ 已完成 2026）

> 目标：把 Tavern Minimum Loop 变成可连续试玩 5–10 分钟的最小游戏循环。
> 范围纪律：不进入 AI Server / LLM / NPC Memory / 动态任务 / 复杂经营。

### 交付清单

- [x] **GameClock**（time/game_clock.gd，autoload）：暂停/恢复（SceneTree.paused）、时间倍率（Engine.time_scale 0.1–10）、营业日秒数累计、Debug 快进
- [x] **DayManager**（tavern/day_manager.gd，autoload）：`StartDay → OpenTavern → Service → CloseTavern → DaySummary → NextDay` 全生命周期（时间窗口数据驱动、可调时长）
- [x] **营业闸门**：`can_spawn_customer()` —— 仅 Service 且未到"关门前停止接待"窗口允许生成；顾客全部离场且无进行中订单 → 自动结算
- [x] **Minimal Economy**：ItemDefinition `cost`（酒瓶 3 / 木杯 2）与 `price`；日级 revenue（实收）/ cost（售出成本记账口径）/ profit；金币=钱箱台账
- [x] **Reputation**：0–100 起步 50；成功订单 +2 / 失败订单 −3（EventBus.reputation_changed）
- [x] **订单失败路径**：Order `expires_at`（GameClock 口径 TTL 40s）→ 超时 mark_failed → 顾客离开（状态机补 wait_drink→leave）→ 失败计数/声望扣减
- [x] **DaySummary**：Day/Customers/Completed/Failed/Revenue/Cost/Profit/ReputationChange/Gold 快照对象 + EventBus.day_summary_ready
- [x] **Minimal Save**（save/save_manager.gd，autoload，user:// JSON）：game_version/current_day/gold/reputation/inventory/unlocks；日结算自动存档（save_requested），`--autoload-save` 启动载入
- [x] **Debug Panel**（ui/debug_panel.gd）：开始营业/生成顾客/添加物品/添加金币/时间快进/提前关门/重置今天/暂停/倍率 + HUD 营业与 NPC/座位/订单状态视图

### Phase 2C 验证协议记录（Godot 4.7.2 console，全部通过）

1. `--headless --import`：无 parse error
2. 主场景 headless 240+ 帧：无运行时错误
3. `-- --smoke` / `--smoke-contract` / `--smoke-loop`：Phase 1 / 2A / 2B 全 PASS —— **无回归**
4. `-- --smoke-days`（新增）：**37 断言全 PASS** —— 连续两个完整营业日：Day1 开张→顾客×2→交付→打烊→结算（顾客2/完成2/失败0/收入16/成本6/利润10/声望+4/金币16）→ 自动存档（current_day=1/gold/rep/版本/inventory/unlocks）→ 次日；Day2 故意不交付 → 订单超时失败 → 声望 −3 → 结算存档（day=2）→ Day3 开始
5. **待手动验收**：F5 完整游玩（默认节奏 1x：约 5+7 秒后开张，营业 90 秒，接客间隔 5 秒；可用调试面板/倍率加速）

### Phase 2C 已记录的实现教训

- 状态机迁移表必须覆盖异常路径：新增 wait_drink→leave（超时放弃）时若漏加，NPC 会每帧尝试非法迁移并永久卡死（实测抓到）
- 测试中的"到达状态" ≠ "流程完成"：LEAVE 状态在开始走出时即置位，必须再等节点真正离场（spawner 活跃引用清空）后再进行下一轮
- 营业时间窗口与测试节奏强耦合：自动计时下第二轮生成可能恰好撞上关门线 → 测试显式放宽窗口/手动快进跨线
- Engine.time_scale 是全游戏节拍唯一开关（Physics/Process delta 自动折算），计时系统不要另搞一套
- PowerShell 批量改文件时 `` `n `` 会写成字面量（非换行）→ 后续用 edit 工具逐处处理

---

## 场景搭建：Arcane Tavern 真实酒馆（Phase 2C+ Art Integration —— 首批落地）

> 依据场景设计图（《魔法酒馆·场景设计图》：入口/吧台+储物/就餐区/壁炉/楼梯+阁楼/二层扩展）
> 用本地资产包搭建首个可加载的真实酒馆场景。

### 资产管线（已验证全链路可用）

| 资产 | 格式 | Godot 导入结果 |
|---|---|---|
| wooden+furniture | OBJ+MTL+JPG | ✅ Mesh + 贴图（`game/art/tavern/...`） |
| wooden+barrels | OBJ+MTL+JPG | ✅ Mesh + 贴图 |
| medieval+banners | OBJ+MTL+JPG | ✅ Mesh + 贴图 |
| wooden+stairs | OBJ+MTL+JPG | ✅ Mesh + 贴图 |
| medieval+wall+panels | FBX+JPEG | ✅ **Scene**（本版本可导入 FBX）+ 9 张贴图 |

- 注：无 Blender；本机 Godot 4.7 可直接导入 OBJ 与 FBX（无转换阻塞）。
- 模型为 Tripo 归一化源（约 0.2–1.0 单位、底部贴 y=0）→ 场景内已按比例放大摆放，细节待编辑器微调。

### 交付

- [x] `game/scenes/tavern/tavern.tscn`：真实酒馆（14×10m）——地面/四面墙（墙板贴图）/天花板/入口缺口/吧台+储物架（北墙）/壁炉+火点光源（东墙）/楼梯（东北）+阁楼占位/"二楼后续扩展"/就餐区家具×4/木桶×6/挂旗×2/吊灯×2 + 方向光 + 环境
- [x] 各模型挂材质贴图（StandardMaterial3D albedo_texture）
- [x] 探针验证：`--check-tavern`（加载+实例化，26 Mesh / 4 Light，无空网格）
- [x] **真实酒馆已升为主场景**（run/main_scene = tavern.tscn）：含碰撞（墙/地面/吧台/壁炉）、玩家全套（移动/相机/交互/物品/丢弃）、NPC 区（座位×3/门/生成器/订单/管理器）、吧台酒瓶（可拾取→交付）、补道具（吊灯/植物/地毯）；DebugHUD + DebugPanel 同挂
- [x] 自动测试与主场景解耦：GameManager 检测 --smoke*/--smoke-contract/--smoke-loop/--smoke-days 时自动切回 dev_playground（其节点布局为回归基准）；--check-tavern / --smoke-tavern 在真实酒馆主场景运行
- [x] 真实酒馆闭环烟测 `--smoke-tavern`：**9 断言 PASS**（开张→生成顾客→寻路→坐下→下单→吧台拾瓶→交付→付款/饮用→离场→座位释放，验证新碰撞布局下 NPC 路径可走）
- [x] **墙面/地面/吧台贴图修复（CC0 平铺）**：原墙板 JPG 是"图集(atlas)"，整图贴盒面会乱拼 —— 已改自取 ambientCG CC0 可平铺贴图（砖墙 wall_bricks / 木地板 floor_wood / 木梁 wood_beams），墙面/吊顶/吧台用 `uv1_scale` 平铺（`game/art/tavern/textures/`）
- [x] **家具拆分**：把合并的 furniture OBJ（16 对象）按对象拆成独立 Mesh（`furniture_split/part_00..15.obj`，保留 UV）—— 实测该资产为**微缩/娃娃屋比例**（最大 0.31m），作主体家具观感差
- [x] **改用真实尺寸图元家具**（依据可视截图）：弃用微缩件作主体，改 Godot 图元按真实比例重建 —— 圆桌(桌面+独腿)+吧凳×6、U 型卡座×2（北墙椅背+坐垫+桌板）、大酒桶×4（桶身+箍环）、吧台台面、长凳；视觉件（不加碰撞）保留已通过的 NPC 走线

### 验证记录

- 资产解压入 `res://game/art/tavern/**`；`--import` 无错误
- `-- --check-tavern`：**PASS**（加载/实例化/网格/灯光就位）
- Phase 1/2A/2B/2C 全量回归：**零失败**（主场景未改，预览为独立场景）

### 后续（待办，未开始）

**已完成（更新后）**：真实酒馆为主场景 + 碰撞/玩家/NPC 座位/交付/吧台拾取 + 补道具（吊灯/植物/地毯）+ 闭环验证
- [ ] 编辑器内微调模型缩放/朝向/位置（首次摆放为近似值；请截图回传以便修正）
- [ ] 家具 mesh 内含多件，如需单件摆放需拆分
- [ ] 墙板贴图平铺 UV 校正
- [ ] 可继续用 CC0 素材补齐：更精细吊灯、酒架陈列、酒杯、编织地毯

---

### Phase 1 后续（未开始，规划清单）

**范围**：以下模块 + NPC 完整状态流，配合灰盒酒馆场景（可复用桌面素材）。验收 = 用户侧一条完整流程：

> 玩家进灰盒酒馆 → 移动/观察 → 交互拾取酒瓶 → Inventory 更新 → NPC 进入酒馆 → 找座 → 坐下 → 生成订单 → 玩家交付指定物品 → NPC 消费完成 → 离开。

### Core（game/scripts/core）✅ Phase 2A 交付

- [x] `GameState`（注册表 + 运行阶段，Phase 2A 交付）
- [x] `DataRegistry`（物品/NPC 档案注册查询，recipe/quest 预留，Phase 2A 交付）
- [x] `RuleValidator`（统一验证闸门 + validate_action 路由，R3 前置依赖就绪，Phase 2A 交付）

### Player（game/scripts/player）✅ Goal 1 已完成

- [x] `PlayerController`（3D 移动）
- [x] `CameraController`（观察/第三人称跟随 → 当前为鼠标视角灰盒版）

### Interaction（game/scripts/interaction）Goal 1 已完成

- [x] `Interactable`（可交互组件基类）
- [x] `InteractionManager`（检测 + 广播 prompt）
- [x] `InteractionPrompt`（**纯数据**，禁 UI 依赖）
- [x] `ItemPickup`（世界拾取物，Goal 1 新增；Phase 2A 起经 RuleValidator）
- [x] `ItemDropper`（Q 放下，Goal 1；Phase 2A 起经 RuleValidator 返回 InteractionResult）
- [x] `InteractionResult`（统一交互结果 + 结果码，Phase 2A 交付）

### Inventory（game/scripts/inventory）✅ Goal 1 已完成

- [x] `ItemDefinition`（Resource）
- [x] `ItemStack`
- [x] `Inventory`（含事件广播，供 NPC 交付/消费复用）

### AI（game/scripts/ai）

- [ ] `AIClient` 接口（对话/建议语义契约）
- [ ] `AIRequest` / `AIResponse`（结构化建议：dialogue/emotion/intent/relationship_delta）
- [ ] `AIIntent`（建议意图数据，必须经 RuleValidator）
- [ ] `MockAIClient`（确定性 mock；AI Server 缺席不阻塞）

### NPC（game/scripts/npc）

- [x] `NPCProfile`（纯数据 Resource，Phase 2A 交付 + 钱包/体型扩展 2B）
- [x] `NPCRuntimeState`（运行态快照/关联，Phase 2B 交付）
- [x] `NPCController`（Game Brain：状态机驱动 + RuleValidator 闸门，Phase 2B 交付）
- [x] `NPCStateMachine` + 状态：`EnterTavern → FindSeat → WalkToSeat → Sit → Order → WaitDrink → Drink → Pay → Leave`（Phase 2B 交付；实现顺序 Drink/Pay 按交付后付款语义：WaitDrink→Pay→Drink→Leave）
- [ ] NPC AI Brain 建议注入（决策点已预留：_pick_drink_item 等；后续 Goal）

### Tavern / Economy（Phase 2B 最小交付 ✅）

- [x] 座位表/入口（TavernSeat/SeatManager/门）—— 验收所需最小实现
- [x] Order/OrderManager/CustomerSpawner + 最小 Transaction + GameState 金币台账 —— 验收所需最小实现

### Phase 1 收尾

- [x] Goal 1 灰盒场景串通（DevPlayground：Primitive Mesh + 灰盒材质）✅
- [x] NPC 全流程灰盒串通（Phase 2B：两 NPC 两轮顾客环自动验证）✅
- [ ] 玩家→NPC 交付的手动 UI 手感验收（自动测试覆盖逻辑链；E 对准 NPC 提示/交付需 F5 确认）
- [ ] 验证协议全项通过（parser / broken resource / scene load / 核心流程冒烟）
- [ ] 本文件更新为 Phase 1 ✅

## 验证协议（每个阶段必做）

1. Godot console headless：`--headless --import` 无 parser error
2. 打开工程无 broken resource（.tscn/.tres 可加载）
3. 场景加载冒烟（main 场景可运行）
4. 核心流程自动化冒烟（game/tests）
5. `docs/TASKS.md` 更新并 commit

## 已知事项 / 技术债

- 桌面素材目录（tavern 3D 模型等）尚未决定纳入方式；灰盒阶段不依赖外部素材。
- 真 AI Server 客户端、存档、任务系统在后续 Sprint（接口预留，不提前实现）。
