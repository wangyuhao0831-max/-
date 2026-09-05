# Project Arcane Tavern

3D AI 魔法酒馆经营 / 社交模拟游戏 —— Vertical Slice 基础架构（Godot 4.7.x / GDScript 严格类型）。

> **当前阶段：Phase 0–2B 完成。** Phase 1 灰盒可玩环 + Phase 2A Core Contract Layer + Phase 2B 顾客最小循环（NPC 进店→找座→下单→玩家交付→付款→饮用→离场→座位释放，两 NPC 复用同一座位自动验证）已就绪。
> 详细进度见 [`docs/TASKS.md`](docs/TASKS.md)。

## 铁律（摘要，完整约束见 docs/ARCHITECTURE.md）

1. **Godot 是游戏世界唯一权威** —— AI 不得直接修改游戏状态。
2. AI 只能产生 `dialogue / emotion / intent / relationship_delta` 等**建议**；一切 AI Intent 必须经 Godot 侧 **Rule Validator** 校验后才可进入世界。
3. NPC 采用 **Game Brain（规则权威）+ AI Brain（行为建议）** 双层架构。
4. 游戏逻辑**数据驱动**（Resource 优先）；跨系统事件一律走 **Signal / EventBus**。
5. 禁止 God Object、禁止核心逻辑依赖 UI、禁止循环依赖；所有外部系统（AI Server、时间、存档…）**必须可 Mock**。
6. AI Server 缺失不得阻塞开发 —— 当前一律使用 `MockAIClient`。

## 目录结构

```
project root  = res:// 根（Godot 工程根）
├─ game/
│  ├─ scripts/          # 全部游戏代码（GDScript，模块化小文件）
│  │  ├─ core/          # EventBus / GameState / DataRegistry / RuleValidator / GameManager（autoload×5）✅
│  │  ├─ player/        # PlayerController / CameraController ✅
│  │  ├─ interaction/   # Interactable / InteractionManager / Prompt / Result / ItemPickup / ItemDropper / NpcDelivery ✅
│  │  ├─ inventory/     # ItemDefinition / ItemStack / Inventory ✅
│  │  ├─ npc/           # NPCProfile / NPCRuntimeState / NPCController / NPCStateMachine ✅（2B 顾客环）
│  │  ├─ tavern/        # TavernSeat / SeatManager / Order / OrderManager / CustomerSpawner ✅（2B）
│  │  ├─ economy/       # Transaction（最小交易）✅（2B）
│  │  ├─ time/          # 时间（占位）
│  │  ├─ quest/         # 任务（占位）
│  │  ├─ save/          # 存档（占位）
│  │  ├─ ai/            # AIClient 接口 / MockAIClient（后续 Goal；NPC 决策点已预留）
│  │  └─ ui/            # DebugHUD（调试 UI，仅订阅 EventBus，R8）
│  ├─ scenes/           # 场景（dev/：dev_playground 主场景 + npc_customer 模板 + dropped_pickup）
│  ├─ resources/        # 数据驱动配置：items/*.tres、npcs/*.tres（DataRegistry 启动扫描）
│  └─ tests/            # headless 自动化测试（--smoke / --smoke-contract / --smoke-loop）
├─ docs/                # 工程文档（架构 / 编码规范 / TASKS 验收）
├─ icon.svg
└─ project.godot        # Godot 4.7（config_version=5；autoload×5 + InputMap）
```

## 文档索引

| 文档 | 内容 |
|---|---|
| `docs/ARCHITECTURE.md` | 架构铁律、分层与依赖方向、EventBus 约定、AI 边界、模块职责 |
| `docs/CODING_STANDARDS.md` | 编码规范：严格类型、命名、注释、日志策略、Mock 约定 |
| `docs/TASKS.md` | 阶段验收清单与进度（持续更新） |

## 开发环境

- Godot **4.7.2 stable**（Windows：`D:\Godot\Godot_v4.7.2-stable_win64_console.exe` 可用于 headless 校验）
- git + GitHub CLI（推送至 `wangyuhao0831-max/-`）

## 本地验证命令（每次改代码后执行）

```powershell
$gd = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
# 1) 全量解析/导入检查（parser + broken resource）
& $gd --headless --import --path .
# 2) 主场景运行冒烟（DevPlayground）
& $gd --headless --path . --quit-after 240
# 3) Phase 1 回归：拾取/放下/移动链路断言
& $gd --headless --path . --quit-after 2500 -- --smoke
# 4) Phase 2A 契约测试：GameState/DataRegistry/RuleValidator/InteractionResult
& $gd --headless --path . --quit-after 1500 -- --smoke-contract
# 5) Phase 2B 顾客环测试：两 NPC 复用同一座位、两轮订单流程
& $gd --headless --path . --quit-after 12000 -- --smoke-loop
```

运行方式：Godot 4.7.2 打开 `project.godot` → F5。操作：WASD 移动、鼠标视角（左键捕获 / Esc 释放）、对准物品按 **E** 拾取、按 **Q** 丢下；顾客 NPC 会自行进店找座下单，对准等待中的 NPC 按 **E** 交付酒水（DebugHUD 左下角显示状态与最近结果）。
