# 编码规范（Coding Standards）

> Godot 4.7.x / GDScript 2.0。所有 `game/scripts/` 代码必须遵守；review 以本文为准。

## 1. 严格类型

- 每个变量/参数/返回值显式类型；禁止裸 `var x = ...`（推断例外：`const` 与局部立即初始化且类型不可省略时仍需标注）。
- 禁止把 `Variant` 当默认逃生口；确需异构容器时注释原因。
- 信号参数全部标注类型；类属性用 `@export`/类型声明。
- 函数返回 void 也要写 `-> void`。
- 允许 `@warning_ignore` 仅在附注释说明的场合；不允许 `@warning_ignore("untyped_declaration")` 无理由扩散。

## 2. 文件与模块

- **小文件小模块**：单文件目标 < 300 行；职责单一（Single Responsibility）。
- 一个类一个文件，`class_name` 与文件名语义一致（`npc_controller.gd` → `class_name NpcController`）。
- 禁止超大 Manager / God Object（R7）；Manager 只做编排。
- 模块目录见 ARCHITECTURE §6；依赖只许向下（R9）。

## 3. 命名

| 类别 | 规则 | 例 |
|---|---|---|
| 文件/目录 | `snake_case` | `npc_state_machine.gd` |
| class_name | PascalCase，**全局唯一**；同域类用域前缀消歧 | `PlayerController`、`NpcStateMachine`、`MockAIClient` |
| 变量/函数 | `snake_case` | `current_state` |
| 常量 | `UPPER_SNAKE` | `MAX_ITEM_STACK` |
| 枚举 | PascalCase 类型 + 大写成员 | `enum State { IDLE, SIT }` |
| ID | `StringName`（`&"..."`） | `&"item_mug_ale"` |

> `class_name` 前缀约定：Core=`Game*/EventBus/DataRegistry`、NPC 域=`Npc*`、AI 域=`AI*`、Inventory=`Item*/Inventory`、Interaction=`Interactable/Interaction*`。避免与 Godot 内置名冲突（如 `Time`、`Camera`）。

## 4. 数据与配置

- 配置优先 `Resource`（`.tres`），或注册表内集中 const；业务代码不散落魔法数字/字符串。
- 一切运行时键（物品、NPC、状态、事件名）用 `StringName`。
- 场景引用用 `@export` + 编辑器指派（UID 化）；代码内禁止拼接 `res://` 路径字符串。

## 5. 注释与文档

- 公开 API（class、method、signal）上方写 `##` 文档注释：职责、参数含义、前置条件。
- 架构级决策必须指向 `docs/ARCHITECTURE.md` 条款（如 `## 数据是建议，应用前需过 RuleValidator（R2/R3）`）。
- 逻辑复杂的函数写"为什么"，不写"是什么"的废话注释。

## 6. 日志策略

- Debug Build：保留有意义日志（状态切换、事件、校验拒绝原因）。
- Release：不打印无意义日志 —— 调试信息用 `print_debug()`（release 自动裁剪）；真正的错误用 `push_error()`/`push_warning()`。
- 禁止把 `print()` 留在热路径（每帧）。
- 后续统一收口到日志门面（Core 计划项），当前遵循上述 API 纪律即可。

## 7. UI 与核心分离（R8）

- UI 文件只存在于场景层；UI 内禁止业务判断逻辑（最多做显示格式转换）。
- 核心层引用 UI 类型 = 违规（review 打回）。

## 8. Mock 约定（R10）

- 外部依赖（AI、时间、存档、支付）必须提供：接口类 + `Mock*` 实现 + 注入点（构造/依赖注入，禁止 `if` 硬编码分支切换实现）。
- Mock 行为确定性：固定输入 → 固定输出（种子化），供自动化测试断言。
- Phase 1 AI 一律 `MockAIClient`；真客户端实现另建（接口不变即可热切换）。

## 9. 测试

- `game/tests/` 下 headless 脚本（`godot --headless -s` / 场景级冒烟测试）。
- 每阶段验收执行 TASKS 的验证协议（parser → resource → scene load → 核心流程），并把结果写回 `docs/TASKS.md`。

## 10. 提交流程

- commit 前：`git status` 确认无 `.godot/`、无临时文件；提交信息 `type: 简述`（type ∈ chore/feat/fix/docs/test/refactor）。
- 多人协作：单一权威分支（当前 main）；大改动先文档后实现。
