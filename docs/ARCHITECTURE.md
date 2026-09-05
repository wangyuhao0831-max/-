# 架构文档（Architecture）

> 基线版本：Phase 0（2026 项目启动）。Phase 1 实现时必须逐条遵守；修订需在 TASKS 记录。

## 1. 设计目标与范围

构建**稳定、模块化、可多人协作、可长期扩展**的 Vertical Slice Core Framework，而非完整游戏。范围以 `docs/TASKS.md` 的阶段清单为准，**不得超范围实现**。

## 2. 铁律（不可协商约束）

| # | 铁律 | 落地方式 |
|---|---|---|
| R1 | Godot 是游戏世界唯一权威 | 世界状态只由 Godot 内代码变更；外部（AI）只能提建议 |
| R2 | AI 不直接修改游戏状态 | AI 产出 `dialogue/emotion/intent/relationship_delta` 建议数据 |
| R3 | AI Intent 必须过 Rule Validator | 所有 `AIIntent` 应用前走 `RuleValidator.validate()`（Godot 侧规则权威） |
| R4 | NPC 双层架构 | `NPCController`（Game Brain：状态机/规则）持有 `AIBrain`（建议来源），两者通过事件/接口交换，不耦合具体 AI 实现 |
| R5 | 数据驱动 | 配置一律 `Resource`（.tres / 代码内 const 注册），ID 一律 `StringName` |
| R6 | 跨系统解耦 | 只经 Signal / EventBus；禁止跨模块直接调用 Manager 方法（Core 内部除外） |
| R7 | 无 God Object | 任何单例职责单一；禁止出现"万能 Manager" |
| R8 | 核心逻辑不依赖 UI | UI 只订阅 EventBus/信号并显示；`InteractionPrompt` 等是**纯数据**，非 Control |
| R9 | 禁止循环依赖 | 依赖只允许指向"更底层"模块（见 §4）；违规代码不通过 review |
| R10 | 外部系统必须可 Mock | AI/时间/存档/经济等边界提供接口 + Mock 实现，接口与实现分离 |

## 3. AI 边界（本轮最关键的架构决定）

```
                    ┌───────────────────────────────┐
   建议(advisory)   │          GODOT (权威)          │
  ───────────────▶  │  NPCController(Game Brain)    │
  dialogue/emotion  │   → StateMachine 驱动行为      │
  intent            │   → RuleValidator 校验 Intent  │
  relationship_delta│   → 校验通过才写入 GameState    │
                    │   → EventBus 广播世界变化        │
                    └───────────────────────────────┘
   AI Brain 通过 AIClient 接口（HttpAIClient / MockAIClient）
   在 Phase 1 一律使用 MockAIClient —— AI Server 缺席不阻塞开发。
```

- `AIClient` 是接口层（Godot 内以 `class_name AIClient` 基类 + 子类实现，或鸭子类型约定），返回 `AIResponse`（内含结构化建议字段）。
- Rule Validator 校验规则由数据/资源配置，可随版本扩展。

## 4. 分层与依赖方向（防循环依赖）

```
Presentation (UI)          ── 只订阅，不反向调用 ──┐
        ▲                                          │
Domain   Player / Interaction / Inventory / NPC /  │
         Tavern / Economy / Quest / Time           │
        ▲（单向向下依赖）                            │
AI layer ai/（建议生产者，不依赖 Domain 实现细节）    │
        ▲（单向向下依赖）                            │
Core     EventBus / GameState / DataRegistry /     │
         GameManager（仅编排与启动）                 │
```

规则：
- 依赖只能指向下方；Core 不依赖 Domain，Domain 不依赖 UI。
- 跨层通信 = EventBus 信号（R6）；需要"询问"时用接口/查询对象而非直接拿别的模块内部对象。
- `GameManager` 仅做启动编排与生命周期管理，业务逻辑下沉到各模块。

## 5. EventBus 约定

- `game/scripts/core/event_bus.gd`：全局单例（autoload），只持有 Signal，不做业务。
- 信号命名：`snake_case`，语义 = 过去时事件，例：`inventory_changed(inventory)`、`interaction_result(result)`、`npc_state_changed(npc_id, old, new)`、`order_fulfilled(order_id)`。
- 参数用轻量数据（ID + 值对象），**禁止**传大对象图或 UI 节点。
- autoload 注册顺序（已落实）：`EventBus → GameState → DataRegistry → RuleValidator → GameManager`（先总线、再状态注册表、再数据注册表、再验证闸门、最后启动编排；避免启动竞态）。
- 输入动作：一律定义于 `project.godot` 的 `[input]`（InputMap，数据驱动），代码只引用动作名（`&"interact"` 等），禁止硬编码键位判断。

## 5b. Core Contract Layer（Phase 2A）约定

- **GameState**：运行阶段（boot→playing）+ Inventory/actor 注册表（StringName 键）。只做注册/查询，不承载玩法决策（反 God Object）。
- **DataRegistry**：Resource 按 `category + StringName id` 注册/查询；启动扫描 `resources/items`、`resources/npcs`；recipe/quest 为预留类别（通用 API 直接可用）。
- **RuleValidator**：**唯一**行为验证入口（R3）。AI/NPC/玩家一切修改权威状态的交互必须先过对应规则；只裁决、不代行（变更仍由 Godot 调用方执行）。规则用 InteractionResult 返回，禁止裸 bool。
- **InteractionResult**：success/code/message/actor_id/target_id/action/payload；结果码常量集中在本类（CODE_*）。语义约定：pickup/deliver/drop → actor_id=执行者、target_id=物品 id（deliver 的接收者在 params/target 角色位）；npc_request_item → target_id=NPC id；inventory 查询 → actor_id=inventory_id。
- **actor 注册**：角色节点（Player/NPC）_ready 以 actor_id 向 GameState 注册并关联其 Inventory（组件自身也注册），退出树自动注销 —— 跨系统按 ID 查询，禁止节点爬取。
- 类型化引用例外（明确许可）：Core 单例（EventBus/GameState/DataRegistry/RuleValidator）可引用领域 class_name 类型做信号/API 签名 —— 仅全局符号引用，非文件级 import，不构成循环依赖。

## 6. 模块职责表

| 目录 | 职责 | Phase 1 交付 |
|---|---|---|
| `scripts/core` | EventBus / GameState / DataRegistry / GameManager / RuleValidator | ✅（Phase 2A 全部交付） |
| `scripts/player` | 玩家控制与相机（灰盒验证用） | ✅ |
| `scripts/interaction` | 可交互物抽象、检测、Prompt/Result 契约 | ✅（含 ItemDropper、NpcDelivery 交付组件） |
| `scripts/inventory` | 物品定义、栈、库存容器（玩家+NPC 消费侧） | ✅ |
| `scripts/ui` | 调试 UI：DebugHUD + DebugPanel（只订阅 EventBus / 按钮驱动，R8） | ✅ |
| `scripts/npc` | Profile/RuntimeState/Controller/StateMachine | ✅（Phase 2B 顾客环；AI 决策点预留） |
| `scripts/tavern` | 座位/订单/顾客生成/DayManager/DaySummary（2B 顾客环 + 2C 营业日/结算） | ✅（2B/2C 最小交付） |
| `scripts/economy` | Transaction 最小交易记录 | ✅（Phase 2B 最小交付） |
| `scripts/ai` | AIClient 接口与数据模型 + MockAIClient | 未开始（AI Server 缺席不阻塞） |
| `scripts/time` | GameClock：时间倍率/暂停/营业日秒（autoload） | ✅（Phase 2C） |
| `scripts/quest` | 任务（当前 Sprint 无交付） | 占位 |
| `scripts/save` | SaveManager：最小 JSON 存档 I/O（autoload） | ✅（Phase 2C） |

> 注：tavern/economy 在 Phase 2B 只交付顾客环所需**最小接口**（座位/订单/单笔交易），禁止提前扩展成完整经济系统（R11）。

## 7. 潜在架构风险登记（多人协作注意）

1. `class_name` 全局命名空间冲突 → 见 CODING_STANDARDS §命名；autoload 脚本禁止再写同名 class_name（Godot 4.7 报 hides an autoload）。
2. GameState 演进为"万能状态桶"的风险 → 只允许注册表 + 阶段字段，新状态先论证归属。
3. 真 AI 客户端接入时行为漂移 → Mock 必须实现与接口同语义的确定性行为，接口契约写入 AIRequest/AIResponse 文档注释。
4. 3D 灰盒场景资源路径硬编码 → 场景通过 `@export` 注入，代码零硬路径（资源 UID 化）。
5. RuleValidator 规则膨胀 → 规则按 action 收敛；跨域前置校验顺序固定并写入注释（顺序影响结果码可观测性）。
