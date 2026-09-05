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
- 信号命名：`snake_case`，语义 = 过去时事件，例：`inventory_changed(inventory)`、`npc_state_changed(npc_id, old, new)`、`order_fulfilled(order_id)`。
- 参数用轻量数据（ID + 值对象），**禁止**传大对象图或 UI 节点。
- 计划 autoload 注册顺序（Phase 1 落实）：`EventBus → GameState → DataRegistry → GameManager`（先总线后数据，注册顺序写入 TASKS 记录，避免启动竞态）。当前已注册：`EventBus → GameManager`。
- 输入动作：一律定义于 `project.godot` 的 `[input]`（InputMap，数据驱动），代码只引用动作名（`&"interact"` 等），禁止硬编码键位判断。

## 6. 模块职责表

| 目录 | 职责 | Phase 1 交付 |
|---|---|---|
| `scripts/core` | EventBus / GameState / DataRegistry / GameManager / RuleValidator | ✅ EventBus/GameManager（其余后续 Goal） |
| `scripts/player` | 玩家控制与相机（灰盒验证用） | ✅ |
| `scripts/interaction` | 可交互物抽象、检测、Prompt 数据 | ✅（InteractionResult 未交付） |
| `scripts/inventory` | 物品定义、栈、库存容器（玩家+NPC 消费侧） | ✅ |
| `scripts/ui` | 调试 UI：DebugHUD（只订阅 EventBus 并格式化显示，R8） | ✅ |
| `scripts/npc` | Profile / RuntimeState / Controller / StateMachine + 状态 | 未开始 |
| `scripts/ai` | AIClient 接口与数据模型 + MockAIClient | 未开始（AI Server 缺席不阻塞） |
| `scripts/tavern` | 酒馆布局、座位表、门/入口（Phase 1 提供 NPC 流程所需最小子集：座位查找） | Phase 1 最小子集 |
| `scripts/economy` | 定价/支付结算（NPC Pay 流程所需最小接口） | Phase 1 最小子集 |
| `scripts/time` | 游戏时钟（NPC 节奏可 Mock） | 占位（Phase 1 不强制） |
| `scripts/quest` | 任务（当前 Sprint 无交付） | 占位 |
| `scripts/save` | 存档（当前 Sprint 无交付） | 占位 |

> 注：tavern/economy 只实现 NPC 状态机验收所需的**最小接口**，禁止提前扩展成完整系统（R11 不做超出 Sprint 的工作）。

## 7. 潜在架构风险登记（多人协作注意）

1. `class_name` 全局命名空间冲突 → 见 CODING_STANDARDS §命名。
2. `GameState ↔ DataRegistry` 与 `PlayerController ↔ InteractionManager` 的循环依赖倾向 → 依赖方向规则 + code review 把关。
3. 真 AI 客户端接入时行为漂移 → Mock 必须实现与接口同语义的确定性行为，接口契约写入 AIRequest/AIResponse 文档注释。
4. 3D 灰盒场景资源路径硬编码 → 场景通过 `@export` 注入，代码零硬路径（资源 UID 化）。
