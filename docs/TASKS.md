# TASKS —— 阶段验收清单

> 每次改动代码/文档后更新本文件。范围纪律（R11）：**只做当前阶段条目，不超 Sprint 扩展。**

## 阶段总览

| 阶段 | 名称 | 状态 |
|---|---|---|
| Phase 0 | Repository Audit + Project Bootstrap | ✅ 完成 |
| Phase 1 | Vertical Slice Core Framework（Core/Player/Interaction/Inventory/AI/NPC） | ⬜ 未开始 |

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

## Phase 1：Vertical Slice Core Framework（规划 —— 未开始）

**范围**：以下模块 + NPC 完整状态流，配合灰盒酒馆场景（可复用桌面素材）。验收 = 用户侧一条完整流程：

> 玩家进灰盒酒馆 → 移动/观察 → 交互拾取酒瓶 → Inventory 更新 → NPC 进入酒馆 → 找座 → 坐下 → 生成订单 → 玩家交付指定物品 → NPC 消费完成 → 离开。

### Core（game/scripts/core）

- [ ] `GameManager`（启动编排 + 生命周期，非 God Object）
- [ ] `EventBus`（autoload，纯信号总线）
- [ ] `GameState`（世界状态唯一权威容器）
- [ ] `DataRegistry`（数据驱动注册表：物品/NPC 定义等）
- [ ] `RuleValidator`（AI Intent 校验闸门 —— R3 前置依赖）

### Player（game/scripts/player）

- [ ] `PlayerController`（3D 移动）
- [ ] `CameraController`（观察/第三人称跟随）

### Interaction（game/scripts/interaction）

- [ ] `Interactable`（可交互组件基类）
- [ ] `InteractionManager`（检测 + 广播 prompt）
- [ ] `InteractionPrompt`（**纯数据**，禁 UI 依赖）
- [ ] `InteractionResult`（交互结果数据）

### Inventory（game/scripts/inventory）

- [ ] `ItemDefinition`（Resource）
- [ ] `ItemStack`
- [ ] `Inventory`（含事件广播，供 NPC 交付/消费复用）

### AI（game/scripts/ai）

- [ ] `AIClient` 接口（对话/建议语义契约）
- [ ] `AIRequest` / `AIResponse`（结构化建议：dialogue/emotion/intent/relationship_delta）
- [ ] `AIIntent`（建议意图数据，必须经 RuleValidator）
- [ ] `MockAIClient`（确定性 mock；AI Server 缺席不阻塞）

### NPC（game/scripts/npc）

- [ ] `NPCProfile`（Resource 数据）
- [ ] `NPCRuntimeState`（运行态，可序列化候选）
- [ ] `NPCController`（Game Brain：驱动状态机 + 校验应用 AI 建议）
- [ ] `NPCStateMachine` + 状态：`Idle → EnterTavern → FindSeat → WalkToSeat → Sit → Order → WaitDrink → Drink → Talk → Pay → Leave`

### Tavern / Economy（最小子集，仅支撑 NPC 验收流）

- [ ] 座位表/入口（FindSeat 数据源）—— 只做验收所需最小实现
- [ ] 价格与支付结算最小接口（Pay 用）—— 只做验收所需最小实现

### Phase 1 收尾

- [ ] 灰盒场景串通（占位模型 + 灰盒材质）
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
