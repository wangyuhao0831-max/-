# TASKS —— 阶段验收清单

> 每次改动代码/文档后更新本文件。范围纪律（R11）：**只做当前阶段条目，不超 Sprint 扩展。**

## 阶段总览

| 阶段 | 名称 | 状态 |
|---|---|---|
| Phase 0 | Repository Audit + Project Bootstrap | ✅ 完成 |
| Phase 1 | Vertical Slice Core Framework（Goal 1 完成，NPC 流未开始） | 🔄 进行中 |
| Phase 2A | Core Contract Layer（GameState / DataRegistry / RuleValidator / InteractionResult） | ✅ 完成 |

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

- [x] `NPCProfile`（纯数据 Resource，Phase 2A 交付 + 示例 .tres）
- [ ] `NPCRuntimeState`（运行态，可序列化候选）
- [ ] `NPCController`（Game Brain：驱动状态机 + 校验应用 AI 建议）
- [ ] `NPCStateMachine` + 状态：`Idle → EnterTavern → FindSeat → WalkToSeat → Sit → Order → WaitDrink → Drink → Talk → Pay → Leave`

### Tavern / Economy（最小子集，仅支撑 NPC 验收流）

- [ ] 座位表/入口（FindSeat 数据源）—— 只做验收所需最小实现
- [ ] 价格与支付结算最小接口（Pay 用）—— 只做验收所需最小实现

### Phase 1 收尾

- [x] Goal 1 灰盒场景串通（DevPlayground：Primitive Mesh + 灰盒材质）✅
- [ ] NPC 全流程灰盒串通（后续 Goal）
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
