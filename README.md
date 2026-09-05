# Project Arcane Tavern

3D AI 魔法酒馆经营 / 社交模拟游戏 —— Vertical Slice 基础架构（Godot 4.7.x / GDScript 严格类型）。

> **当前阶段：Phase 0 完成（Repository Bootstrap）。** 本仓库承载工程骨架、目录约定、docs 基线与验收清单；游戏代码（Phase 1 Core Framework）尚未开始。
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
│  │  ├─ core/          # GameManager / EventBus / GameState / DataRegistry
│  │  ├─ player/        # PlayerController / CameraController
│  │  ├─ interaction/   # Interactable / InteractionManager / Prompt / Result
│  │  ├─ inventory/     # ItemDefinition / ItemStack / Inventory
│  │  ├─ npc/           # NPCProfile / NPCRuntimeState / NPCController / NPCStateMachine
│  │  ├─ tavern/        # 酒馆空间与座位等（Phase 1 范围外模块，占位）
│  │  ├─ economy/       # 经济（占位）
│  │  ├─ time/          # 时间（占位）
│  │  ├─ quest/         # 任务（占位）
│  │  ├─ save/          # 存档（占位）
│  │  └─ ai/            # AIClient 接口 / AIRequest / AIResponse / AIIntent / MockAIClient
│  ├─ scenes/           # 场景（main 等）
│  ├─ resources/        # 数据驱动配置（.tres 等）
│  └─ tests/            # headless 自动化测试脚本（Phase 1 起）
├─ docs/                # 工程文档（架构 / 编码规范 / TASKS 验收）
├─ icon.svg
└─ project.godot        # Godot 4.7（config_version=5）
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
