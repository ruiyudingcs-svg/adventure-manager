# 冒险团管理游戏 V0.1

一款以合同、人员安排、准备、组织价值观和资源取舍为核心的奇幻冒险者公会管理游戏。

玩家不直接操作英雄战斗，而是通过选择合同、派遣四人小队、配置补给和决定行动倾向，间接塑造任务结果、阵营关系与长期世界局势。V0.1 的目标是验证这一管理循环是否成立，而不是制作完整战斗系统或大型世界模拟。

## 当前状态

- 产品、合同、阵营和“巨龙入侵”剧本的 V0.1 设计文档已经形成可实现闭环。
- 根目录已有 Godot 4.7 生成的最小 `project.godot`、默认图标和本地导入缓存，但工程仍未完成 bootstrap。
- 当前没有主场景配置，也没有 `game/`、`tests/`、Autoload 或可运行游戏；现有 `project.godot` 只是空工程配置。
- 根目录已有 `.gitignore`、`.gitattributes` 和 `.editorconfig`，但当前文件夹尚未初始化为 Git 仓库。
- 下一项可执行开发任务是 `Task 001 — Project Bootstrap`。
- Task 001、002 已可执行。
- Task 003、004 的任务书已经完成，但开始前必须分别解决 Gate A、Gate B 中尚未定案的数值规则。

完整任务路线和阶段门见 [`tasks/000_v0.1_execution_map.md`](tasks/000_v0.1_execution_map.md)。

## 开始开发

每次交给 Codex 一个任务时，按以下顺序提供上下文：

```text
AGENTS.md
→ tasks/000_v0.1_execution_map.md
→ 当前 task 文件
→ task 的 Required reading
→ 现有代码与测试
```

现在应从 [`tasks/001_project_bootstrap.md`](tasks/001_project_bootstrap.md) 开始。已有最小 `project.godot` 不代表 Task 001 已完成；该任务仍需补齐主场景、Dashboard 壳、测试器和相应项目配置。不要让 Codex 一次连续执行整个里程碑；每个任务完成后先审查 diff 和测试结果，再进入下一项。

Task 001 完成后，完整测试命令为：

```bash
godot --headless --path . --script res://tests/run_all.gd
```
当前开发机已确认的 Godot 版本为 `4.7.stable.official.5b4e0cb0f`，安装目录为 `D:\software\Godot\Godot_v4.7-stable_win64`。Godot 未加入系统 `PATH` 时，应直接调用该目录中的 console 可执行文件。

在项目尚未 bootstrap、`tests/run_all.gd` 不存在或环境中没有 Godot 4.7 可执行文件时，不得声称该命令已经通过。

## 文档权威规则

README 只负责导航，不重复保存完整游戏规则。出现冲突时按以下原则处理：

1. `docs/01_v0.1_product_spec.md` 规定产品范围上限；实现便利不能扩大范围。
2. Accepted ADR 可以覆盖更早的技术指导，但不能绕过产品范围。当前已有 [`ADR-0001`](docs/adr/0001_initial_stack_and_scope.md) 固定初始技术栈与纵向切片范围。
3. 状态为 Accepted 的专项规格，在其负责领域内优先于更早、更宽泛的描述。
4. `docs/03_godot_architecture.md` 与 `docs/04_data_model.md` 分别约束技术职责和数据边界。
5. Task 文件负责限定本次实现范围、允许文件和验收测试，但不能自行创造产品规则。
6. Roadmap、内容计划、TODO 和手算示例用于规划或验证，除非明确标记为权威规格，否则不能覆盖 Accepted 规则。

根目录 [`AGENTS.md`](AGENTS.md) 是 Codex 的常驻仓库执行约束。若任务所需公式缺失，或两个 Accepted 文档仍然冲突，应停止实现并报告，不得用临时常数、零值 placeholder 或自行猜测补齐。

## 文档地图

### 核心产品与技术边界

| 文档 | 职责 | 何时阅读 |
|---|---|---|
| [`docs/01_v0.1_product_spec.md`](docs/01_v0.1_product_spec.md) | V0.1 产品目标、范围、体验与验收标准 | 所有范围判断 |
| [`docs/02_core_loop_and_rules.md`](docs/02_core_loop_and_rules.md) | 核心周循环、英雄、合同结算、阵营与世界局势总规则 | 实现任何领域规则前 |
| [`docs/03_godot_architecture.md`](docs/03_godot_architecture.md) | Godot 目录、分层、服务职责、随机数、测试与存档边界 | 新增模块或公共 API 前 |
| [`docs/04_data_model.md`](docs/04_data_model.md) | Definition、State、结果对象、字段和验证规则 | 新增或修改数据类型前 |

### 路线、协作和设计跟踪

| 文档 | 职责 | 状态说明 |
|---|---|---|
| [`docs/05_vertical_slice_roadmap.md`](docs/05_vertical_slice_roadmap.md) | V0.1 里程碑和退出条件 | 路线参考；具体执行以 `tasks/000` 为入口 |
| [`docs/06_codex_workflow.md`](docs/06_codex_workflow.md) | Codex 任务拆分、验证和报告方式 | 工作流指导 |
| [`docs/07_contract_generation_and_integration_todos.md`](docs/07_contract_generation_and_integration_todos.md) | 合同生成与系统联动的设计决策记录和待办 | **Draft/跟踪文档，不是独立权威规格** |

### 玩家合同结算

| 文档 | 职责 | 权威范围 |
|---|---|---|
| [`docs/08_contract_clause_spec.md`](docs/08_contract_clause_spec.md) | 七类合同条款、条件/效果白名单和求值顺序 | 条款系统 |
| [`docs/10_baseline_contracts.md`](docs/10_baseline_contracts.md) | 三份完整基准合同和手算结果 | 实现与平衡基准；golden 差异必须人工审查 |
| [`docs/15_staged_contract_resolution_rules.md`](docs/15_staged_contract_resolution_rules.md) | 固定四阶段、MissionContext、Approach、等级、成员评价和原子提交边界 | 分阶段合同结算 |

### 合同内容与生命周期

| 文档 | 职责 | 权威范围 |
|---|---|---|
| [`docs/09_contract_template_catalog.md`](docs/09_contract_template_catalog.md) | 12 份手工合同的身份、目标、阶段骨架和系统覆盖 | V0.1 合同内容目录 |
| [`docs/11_contract_proposal_generation.md`](docs/11_contract_proposal_generation.md) | 合同来源、资格、优先级、每阵营一栏与 fallback | 合同提案 |
| [`docs/12_contract_instantiation_and_commitment.md`](docs/12_contract_instantiation_and_commitment.md) | Offer 数值实例化、拒绝、关系加成和提出方承诺 | Offer 创建与锁定 |
| [`docs/13_unhandled_contract_and_npc_results.md`](docs/13_unhandled_contract_and_npc_results.md) | 过期、NPC 完成、问题恶化与稳定结算顺序 | 未处理合同 |
| [`docs/14_week_flow_faction_commitments_and_messages.md`](docs/14_week_flow_faction_commitments_and_messages.md) | 周流程、阵营单一模式、行动延迟、目标锁与消息 | 周流程和阵营承诺 |

### 巨龙入侵剧本

| 文档 | 职责 | 权威范围 |
|---|---|---|
| [`docs/16_dragon_invasion_scenario_content_plan.md`](docs/16_dragon_invasion_scenario_content_plan.md) | 剧本内容定案过程、覆盖目标和完成记录 | 内容计划与审计入口 |
| [`docs/17_dragon_invasion_scenario_spec.md`](docs/17_dragon_invasion_scenario_spec.md) | 局势阶段、四个结局、三个阵营目标和五条进度钟 | 剧本结构的单一权威来源 |
| [`docs/18_dragon_invasion_problem_and_action_catalog.md`](docs/18_dragon_invasion_problem_and_action_catalog.md) | 九个世界问题、阵营行动表、合同覆盖和结局路径 | 问题与行动内容的单一权威来源 |

## 开发任务

| Task | 状态 | 目标 |
|---|---|---|
| [`tasks/000_v0.1_execution_map.md`](tasks/000_v0.1_execution_map.md) | 路线已定义 | 完整关键路径、分批细化节点和 Gate A/B |
| [`tasks/001_project_bootstrap.md`](tasks/001_project_bootstrap.md) | Ready | Godot 工程、Dashboard 壳和 headless 测试器 |
| [`tasks/002_deterministic_simulation.md`](tasks/002_deterministic_simulation.md) | Ready after Task 001 | 确定性 seed、值对象、英雄快照和四人队能力聚合 |
| [`tasks/003_staged_contract_resolver.md`](tasks/003_staged_contract_resolver.md) | Blocked until Task 002 and Gate A | 固定四阶段 ContractResolver 内核 |
| [`tasks/004_complete_contract_resolution.md`](tasks/004_complete_contract_resolution.md) | Blocked until Task 003 and Gate B | 计划、认可度、Approach、补给、条款、报酬、疲劳与伤病 |

### Gate A：评分内核缺失规则

Task 003 前必须先定案：

- 四人队协同输入和 `cohesion_modifier`。
- `fatigue_penalty` 与 `injury_penalty`。
- `seeded_variance` 的精确分布、区间和 score 舍入规则。

### Gate B：完整合同政策缺失规则

Task 004 前必须先定案：

- `method_fit`、`personal_fit` 和公开条款进入任务前认可度的算法。
- 轻伤/重伤风险汇总、投掷、阈值和恢复结果。
- `fatigue_multiplier` 的应用与舍入顺序。
- 人员安全条款、伤病人数、条款封顶、最终 tier 和 `injury_risk_modifier` 之间的无循环结算顺序。

Gate 的完整验收项以 [`tasks/000_v0.1_execution_map.md`](tasks/000_v0.1_execution_map.md) 为准。

## 固定技术决策

- Godot 4.7 stable。
- GDScript，公共 API 使用静态类型。
- 桌面端优先，管理界面使用 `Control`。
- 无第三方 addon。
- 静态 `*Definition` Resource 在运行时只读；单局变化放入 `*State`。
- 领域模拟不依赖 scene tree 或 UI。
- UI 不保存游戏公式，也不直接修改多个领域对象。
- 所有模拟随机数使用显式 seed 或注入的 `RandomNumberGenerator`。
- 每项有意义的状态变化都有结构化 `ReasonEntry`。
- V0.1 最多三个 Autoload：`GameSession`、`DataCatalog`、`SceneRouter`；只在出现真实职责时创建。
- 不创建全局事件总线，不使用 executable string 表达世界规则。

## 统一术语

设计文档保留中文，代码标识统一使用英文。不要维护中英文两套完整规格。

| 中文概念 | 代码术语 |
|---|---|
| 世界局势 | `Situation` |
| 世界问题 | `WorldProblem` |
| 世界事件 | `WorldEvent` |
| 阵营行动 | `FactionAction` |
| 合同模板 | `ContractDefinition` |
| 合同提案/实例 | `ContractOfferState` |
| 合同计划 | `ContractPlanState` |
| 目标锁 | `target_lock_key` |
| 任务内上下文 | `MissionContext` |
| 判定 | `ContractCheckDefinition` / `CheckResult` |
| 原因记录 | `ReasonEntry` |
| 状态变化 | `StateChange` |
| 待应用效果 | pending effects |
| 行动倾向 | `Approach` |
| 提出方 | sponsor faction |

## 文档与代码维护规则

- 产品范围变化先更新 `docs/01_v0.1_product_spec.md`。
- 领域规则变化同时更新 `docs/02_core_loop_and_rules.md` 和对应专项规格。
- 公共数据字段变化先更新 `docs/04_data_model.md`。
- 跨模块架构变化应新增 Accepted ADR，并同步 `docs/03_godot_architecture.md`。
- 实现顺序或任务依赖变化更新 `tasks/000_v0.1_execution_map.md`。
- 代码行为改变时，同一提交更新相关文档和测试。
- 新规则必须有 focused test；确定性变更必须重复相同输入和 seed。
- 不自动更新 golden 期望；先报告差异并由人工审查。
- 不把“未来可能做”实现成 V0.1 框架。
