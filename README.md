# 冒险团管理游戏 V0.1

一款以合同、人员安排、准备、组织价值观和资源取舍为核心的奇幻冒险者公会管理游戏。

玩家不直接操作英雄战斗，而是通过选择合同、派遣四人小队、配置补给和决定行动倾向，间接塑造任务结果、阵营关系与长期世界局势。V0.1 的目标是验证这一管理循环是否成立，而不是制作完整战斗系统或大型世界模拟。

## 当前状态

- 产品、合同、阵营和“巨龙入侵”剧本的 V0.1 设计文档已经形成可实现闭环。
- Task 001 已完成：Godot 4.7 主场景、响应式 Dashboard 壳和无第三方依赖的 headless 测试器已经建立。
- Task 002 已完成：稳定 seed、值对象、只读成员快照和四人队能力聚合已经建立并通过 headless 测试。
- Gate A 已定案：协同、疲劳、伤势、窄随机和 score 舍入具有完整确定性规则。
- Gate B 已定案：任务前认可度、固定补给、疲劳、轻重伤概率与无循环结算顺序具有完整数值规则。
- Task 003 已完成：固定四阶段、MissionContext、独立 seed、评分与 failure cap 内核已经建立。
- Task 004 已完成：认可度、Approach、补给、条款、奖励、疲劳、伤病和三份完整 golden 已通过测试。
- Task 005 已完成：DataCatalog、authoring 编译边界与结构化 CatalogValidator 已建立。
- Task 006 已完成：首批 `.tres`、默认 manifest、八名成员和三份基准合同已发布。
- Task 007 已完成：CampaignState、StateOperation 与原子 CampaignTransaction 已建立。
- Task 008 已完成：纯领域 SituationResolver、问题生命周期、紧迫度、单批触发器和稳定结局选择已建立。
- Gate C 已定案：`.tres` 编译边界、Catalog 原子发布、StateOperation 事务和单批局势解析具有明确规则。
- Task 009 已完成：Offer 锁定快照、稳定 ID/seed、关系档、接受/拒绝命令和
  declined 归档已建立，并通过 Godot 4.7 headless 回归。
- Task 010 已完成：FactionAction Definition、两遍阵营规划、行动承诺、
  influence 预留和完整未处理 Offer 生命周期已建立。
- Task 011 已完成：历史参与投影、Gate D 周维护、Situation 分阶段解析、
  原子周开始/周末协调和 10 周 headless 循环已建立。
- Task 012 已完成：MessageRequest/MessageState、稳定消息投影、拒绝消息、
  周流程消息集成和显式 mark_read 事务已建立。
- Task 013 已完成：完整 12 合同、37 条条款、9 问题、14 阵营行动、4 结局与
  单一龙灾 Situation 已作为显式 `.tres` 发布。
- Gate D 已定案：维护不足、治疗费、疲劳/伤病恢复、近期计数和历史查询边界
  具有完整规则。
- Gate E 已定案：其余九份合同的完整 check、五档 outcome、条款和 final outcome
  数值已经固定。
- Gate F 已定案：唯一新战役 setup、精确开局值、64样本合同预测、会话阶段和
  Football Manager 风格应用外壳边界已经固定。
- Task 014 已完成：正式 CampaignSetup、确定性开局、GameSession、SceneRouter、
  FM 式应用壳、Dashboard 与 Roster 已接入。
- Task 015 已完成：临时 Planning Draft、64 样本稳定预测、不可逆派遣、
  Resolution Review 与连续周循环已接入。
- Task 016 实现与自动回归已完成：schema v1 JSON、canonical state、原子替换、
  `.bak` 恢复候选、planning-only 保存和继续/新游戏入口已接入；保存与继续加载
  以及修复后的第二周结算已通过手工确认。
- Task 017 实现与自动验证已完成：结局页、会话级六步引导、错误/空状态、
  十局只读平衡审计和 Windows Desktop preset 已接入；英雄选择卡显示六项能力；
  经人工批准的 check 等级调平已完成；完整 suite 为 233/0。
  当前开发机缺少 Godot 4.7 Windows export templates，导出启动与完整人工整局仍待验收。
- 当前已注册 `DataCatalog`、`GameSession`、`SceneRouter` 三个 Autoload；
  `SaveService` 是普通 `RefCounted`，没有新增 Autoload。

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

Task 005—016 已完成；Task 017 处于 Validation。当前完整 Godot 4.7 headless suite 为
233 passed、0 failed。自动收尾已完成；下一步是在安装 Godot 4.7 stable export
templates 后完成 Windows Debug/Release 启动、两周流程和三尺寸键盘/整局人工验收。
平衡调整、首周精确分布与剩余自动策略风险见
[`Task 017`](tasks/017_vertical_slice_hardening_balance_and_export.md)。

当前完整测试命令为：

```bash
godot --headless --path . --script res://tests/run_all.gd
```
当前开发机已确认的 Godot 版本为 `4.7.stable.official.5b4e0cb0f`，安装目录为 `D:\software\Godot\Godot_v4.7-stable_win64`。Godot 未加入系统 `PATH` 时，应直接调用该目录中的 console 可执行文件。

在 `tests/run_all.gd` 不存在、测试未实际运行或环境中没有 Godot 4.7 可执行文件时，不得声称该命令已经通过。

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
| [`docs/19_content_catalog_state_and_situation_rules.md`](docs/19_content_catalog_state_and_situation_rules.md) | `.tres` 编译、Catalog、状态事务、补给消费和 SituationResolver 边界 | Task 005—008 / Gate C |
| [`docs/20_weekly_upkeep_and_history_rules.md`](docs/20_weekly_upkeep_and_history_rules.md) | 工资、治疗、恢复、近期计数和只读历史查询边界 | Task 011 / Gate D |
| [`docs/21_remaining_contract_numerical_rules.md`](docs/21_remaining_contract_numerical_rules.md) | 其余九份合同的完整数值定义 | Task 013 / Gate E |
| [`docs/22_campaign_bootstrap_forecast_and_ui_shell.md`](docs/22_campaign_bootstrap_forecast_and_ui_shell.md) | 新战役 setup、合同预测、会话阶段和三层 UI 外壳 | Task 014—017 / Gate F |

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
| [`tasks/000_v0.1_execution_map.md`](tasks/000_v0.1_execution_map.md) | 路线已定义 | 完整关键路径、分批细化节点和 Gate A—F |
| [`tasks/001_project_bootstrap.md`](tasks/001_project_bootstrap.md) | Completed | Godot 工程、Dashboard 壳和 headless 测试器 |
| [`tasks/002_deterministic_simulation.md`](tasks/002_deterministic_simulation.md) | Completed | 确定性 seed、值对象、英雄快照和四人队能力聚合 |
| [`tasks/003_staged_contract_resolver.md`](tasks/003_staged_contract_resolver.md) | Completed | 固定四阶段 ContractResolver 内核 |
| [`tasks/004_complete_contract_resolution.md`](tasks/004_complete_contract_resolution.md) | Completed | 计划、认可度、Approach、补给、条款、报酬、疲劳与伤病 |
| [`tasks/005_data_catalog_and_validation.md`](tasks/005_data_catalog_and_validation.md) | Completed | DataCatalog、authoring 编译边界与 CatalogValidator |
| [`tasks/006_baseline_content_resources.md`](tasks/006_baseline_content_resources.md) | Completed | 首批 `.tres`、默认 manifest 与三份基准合同 |
| [`tasks/007_campaign_state_transactions.md`](tasks/007_campaign_state_transactions.md) | Completed | CampaignState、StateOperation 与原子事务 |
| [`tasks/008_situation_resolver.md`](tasks/008_situation_resolver.md) | Completed | 世界钟、问题、紧迫度、单批触发器与结局 |
| [`tasks/009_contract_offers_and_lifecycle.md`](tasks/009_contract_offers_and_lifecycle.md) | Completed | Offer 状态、实例化、关系锁定、接受与拒绝 |
| [`tasks/010_faction_turn_planner.md`](tasks/010_faction_turn_planner.md) | Completed | 行动 Definition、两遍阵营规划、承诺与到期生命周期 |
| [`tasks/011_week_flow_and_upkeep.md`](tasks/011_week_flow_and_upkeep.md) | Completed | 每周维护、历史参与快照、Situation 分阶段组合与原子周流程 |
| [`tasks/012_weekly_message_projector.md`](tasks/012_weekly_message_projector.md) | Completed | 稳定、去重且只投影已提交事实的周消息 |
| [`tasks/013_complete_dragon_invasion_content.md`](tasks/013_complete_dragon_invasion_content.md) | Completed | 完整 12 合同、9 问题、14 行动和 4 结局内容 |
| [`tasks/014_game_session_dashboard_and_roster.md`](tasks/014_game_session_dashboard_and_roster.md) | Completed | GameSession、新战役、FM式应用壳、Dashboard 与 Roster |
| [`tasks/015_contract_planning_and_resolution_ui.md`](tasks/015_contract_planning_and_resolution_ui.md) | Completed | 合同规划、稳定预测、周末结算与结果页 |
| [`tasks/016_save_service_and_round_trip.md`](tasks/016_save_service_and_round_trip.md) | Completed | JSON SaveService、原子写入、保存/继续和第二周结算复验 |
| [`tasks/017_vertical_slice_hardening_balance_and_export.md`](tasks/017_vertical_slice_hardening_balance_and_export.md) | Validation | 自动验证 233/0；首周合同已调平，人工整局与 Windows 模板待验收 |

### Gate A：评分内核规则（已解决）

Accepted 数值规则位于 [`docs/15_staged_contract_resolution_rules.md`](docs/15_staged_contract_resolution_rules.md) 第 4.1—4.3 节：

- 四人队关系、纪律和活跃冲突确定性汇总为 `cohesion_modifier`。
- 疲劳与伤势逐成员转换后汇总为队伍惩罚。
- 每个 check 使用独立的 -10 至 +10 离散均匀整数随机。
- raw score 只在 tier 判断前舍入一次，最终 score 为不裁剪整数。

### Gate B：完整合同政策规则（已解决）

Accepted 数值规则位于 [`docs/15_staged_contract_resolution_rules.md`](docs/15_staged_contract_resolution_rules.md) 第 5.1—5.5 节：

- 公开条款 success 影响、trait/method、禁忌和六项 personal fit 共同构成任务前认可度。
- 五类补给具有固定 check、疲劳和伤病修正。
- 每名成员使用独立 seed 和一次投掷确定无伤、轻伤或重伤。
- 伤病读取 operational tier 并先于条款；条款 cap 得到 final tier 后不重投伤病。
- 疲劳只读取 final tier 的 multiplier，并在乘法后舍入一次。

Task 017 人工批准调平后，三份基准 golden 已重新手算并审查；当前结果见
[`docs/10_baseline_contracts.md`](docs/10_baseline_contracts.md)。Gate 的完整验收项以
[`tasks/000_v0.1_execution_map.md`](tasks/000_v0.1_execution_map.md) 为准。

### Gate C：内容目录、状态事务与局势规则（已解决）

Accepted 规则位于 [`docs/19_content_catalog_state_and_situation_rules.md`](docs/19_content_catalog_state_and_situation_rules.md)：

- `.tres` authoring graph 经过显式 manifest、校验和编译后才发布为只读 Definition。
- DataCatalog 加载失败不发布部分目录。
- 补给不保存库存，在成功事务中按锁定成本购买并消费一次。
- StateOperation 负责待应用合并，StateChange 只负责 old/new 审计。
- CampaignTransaction 使用深副本、白名单和冲突回滚。
- SituationResolver 不读取成员、金币、补给或阵营关系，每个边界只执行一批触发器。

### Gate D：每周维护、恢复与历史查询（已解决）

Accepted 规则位于
[`docs/20_weekly_upkeep_and_history_rules.md`](docs/20_weekly_upkeep_and_history_rules.md)：

- 无伤员时八人工资与基础维护合计 123；轻伤/重伤每周治疗费为 10/20。
- 强制维护不足不阻塞周流程：Gold 归零、全员 morale -5、reputation -5，不负债。
- 未出勤成员恢复 20 fatigue；伤势倒计时归零时清零并恢复 available。
- 连续派遣/冷落计数封顶 3，morale 与成员关系没有自然漂移。
- 合同历史是参与记录的唯一权威来源；只读历史查询生成上一周参与快照，Upkeep
  不解析合同记录。

### Gate E：其余九份合同完整数值图（已解决）

Accepted 规则位于
[`docs/21_remaining_contract_numerical_rules.md`](docs/21_remaining_contract_numerical_rules.md)：

- 文档 09 继续负责十二份合同的身份、战略方向和 Success/Failure 净变化锚点。
- 文档 10 继续只负责三份基准合同及其人工 golden。
- Gate E 固定其余九份合同的头部、36 个 check、五档 outcome、27 份条款、
  方法/补给和三类 final outcome profile。
- 共享表只在 authoring 阶段展开；运行时不插值、不增加合同 ID 分支。
- 三份既有 golden 不因 Gate E 自动变化。

### Gate F：新战役、预测与应用外壳（已解决）

Accepted 规则位于
[`docs/22_campaign_bootstrap_forecast_and_ui_shell.md`](docs/22_campaign_bootstrap_forecast_and_ui_shell.md)：

- 唯一 CampaignSetupDefinition 固定 Gold 250、Reputation 20、Cohesion 50、
  维护 25、八名成员与三个阵营的开局状态。
- 新战役从内部 week 0 经真实 WeekFlow 原子进入第 1 周，不重复维护或被动变化。
- 合同预测复用正式 Resolver 的64个稳定样本，排除 locked seed，只显示第10—90
  百分位近似 tier 区间。
- GameSession 使用 planning、resolution_review 等明确阶段，UI 刷新不得重新结算。
- 左侧全局导航、单行上下文 tabs 和顶部状态/主动作工具栏职责固定。

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
