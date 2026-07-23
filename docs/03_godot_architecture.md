# Godot 技术架构 V0.1

## 1. 技术目标

架构必须支持：

- 无界面运行完整周结算
- 可复现模拟
- 静态定义与运行时状态分离
- 界面替换不影响规则
- 小步交给 Codex 修改
- 未来加入自动战斗表现时保留结算接口

## 2. 技术栈

- Godot 4.7 stable
- GDScript，启用静态类型标注
- 桌面端优先
- `Control` 为主要 UI 节点
- 自定义 `Resource` 作为静态定义数据
- Git 版本控制
- V0.1 不使用第三方插件

选择 GDScript 的原因是迭代路径短、与 Godot API 贴合、无需额外构建链。若未来性能分析证明模拟层存在真实瓶颈，再通过 ADR 评估 C# 或 GDExtension；不得提前优化。

## 3. 目录结构

```text
res://
├── project.godot
├── AGENTS.md
├── docs/
│   ├── product/
│   ├── technical/
│   └── adr/
├── game/
│   ├── app/
│   │   ├── app_root.tscn
│   │   ├── app_root.gd
│   │   └── scene_router.gd
│   ├── core/
│   │   ├── ids/
│   │   ├── random/
│   │   ├── result/
│   │   └── time/
│   ├── domain/
│   │   ├── adventurers/
│   │   ├── contracts/
│   │   ├── factions/
│   │   ├── guild/
│   │   ├── simulation/
│   │   └── situations/
│   ├── data/
│   │   ├── definitions/
│   │   └── catalogs/
│   ├── features/
│   │   ├── dashboard/
│   │   ├── roster/
│   │   ├── contract_planning/
│   │   └── resolution/
│   ├── ui/
│   │   ├── components/
│   │   ├── theme/
│   │   └── icons/
│   └── persistence/
│       ├── save_service.gd
│       └── migrations/
├── tests/
│   ├── run_all.gd
│   ├── unit/
│   ├── integration/
│   └── fixtures/
└── assets/
    ├── fonts/
    ├── audio/
    └── temporary/
```

Godot 文件和文件夹使用 `snake_case`，节点名称使用 `PascalCase`。

## 4. 层级职责

### 4.1 Core

与游戏题材无关的基础设施：

- ID
- 随机数
- 通用结果类型
- 周数与时间
- 原因记录

Core 不得引用 Features 或具体 UI。

### 4.2 Domain

纯游戏规则：

- 成员状态
- 合同评估
- 小队能力
- 周结算
- 局势进度
- 世界问题与世界事件
- 阵营行动
- 合同提案与生命周期

Domain 不得访问场景树、按钮、标签或动画。

### 4.3 Data

静态内容定义：成员模板、合同、阵营、局势、世界问题、阵营行动和触发器。通过自定义 `Resource` 和 `.tres` 文件编辑。

### 4.4 Features

面向玩家的界面流程。每个功能目录同时包含场景、展示模型和界面脚本。

Feature 只能调用 Domain 的公开服务，不应复制规则公式。

### 4.5 Persistence

把运行时状态序列化为存档 DTO，并负责版本迁移。静态定义只保存 ID，不复制完整定义。

## 5. 静态定义与运行时状态

### 5.1 Definition

不可变的设计数据，例如：

- `AdventurerDefinition`
- `ContractDefinition`
- `FactionDefinition`
- `SituationDefinition`
- `WorldProblemDefinition`

由 `.tres` 文件保存。游戏运行时不得修改。

### 5.2 State

单局会改变的数据，例如：

- 当前疲劳
- 士气
- 伤病
- 金币
- 关系
- 已接受合同
- 待处理合同及其锁定报酬和过期周
- 本周已公开但尚未结算的阵营行动承诺及预留 influence
- 当前世界问题
- 已发生的世界事件
- 消息历史与已读状态
- 进度钟

运行时状态可以使用自定义 Resource 或 RefCounted 数据对象，但从定义构造时必须创建独立实例。不得修改共享定义 Resource。

## 6. Autoload 策略

V0.1 最多使用三个 Autoload：

### `GameSession`

持有当前 `CampaignState`，协调新游戏、读档、保存和周推进。它不包含具体公式。

### `DataCatalog`

只读加载静态定义，并通过稳定 ID 查询。

### `SceneRouter`

控制四个主要界面之间的切换。

禁止创建无边界的全局 `EventBus`。优先使用明确对象引用和局部 signals。只有跨越整个应用生命周期且没有自然所有者的事件，才考虑加入全局信号。

## 7. 主要服务

### `WeekFlowCoordinator`

协调周开始与周末两个原子事务，在临时状态上依次调用领域服务。数值效果先合并后裁剪，集合稳定去重，矛盾状态拒绝整批提交；触发器每个周边界只运行一批。Coordinator 不拥有工资、合同、阵营或世界公式。

### `ContractResolver`

按固定四阶段、每阶段一个 check 结算 effective contract，维护一次性 MissionContext，并生成完整 ContractResolution。条款求值、成员任务后评价和提出方关系作为内部纯计算组件实现，不建立独立顶层服务。

ContractResolver 不重新读取当前世界钟，不直接修改 CampaignState，也不运行其他阵营合同反应。它只返回人员、提出方与世界的待应用效果和原因。

### `WeeklyUpkeepResolver`

为周开场生成工资、维护、恢复、伤病倒计时、士气和关系自然衰减的待应用变化与原因。它不处理世界问题、合同或阵营意图。

### `SituationResolver`

处理被动推进、世界问题、世界事件、紧迫度、单批触发器和结局。紧迫度计算是内部纯函数，不建立独立顶层服务；它不得读取成员、金币或阵营关系。

### `FactionTurnPlanner`

读取同一周规划快照，为每个阵营锁定唯一模式：无 pending 时提出合同，有 pending 时选择直接行动。它先按稳定 faction ID 补齐空合同栏，再按稳定 faction ID 安排直接行动，使用 base、urgency、agenda 和 repeat 四项评分，并维护全局精确 target lock 排他。

Planner 直接创建行动承诺所需数据；不创建 ContractProposalCandidate，不运行全局三栏选择、NPC 冲突或随机决胜。

### `ContractOfferService`

负责 Offer 创建、最小实例化快照、关系报酬与期限锁定、玩家接受/拒绝、预测查询和周开始生命周期。它只允许实例化 check 难度与初始 MissionContext，不保存源规则或完整世界事实。

### `WeeklyMessageProjector`

把已经创建的 Offer、行动承诺、世界事件、合同历史和结构化结果转换为稳定 MessageState。它只支持 player/debug 原因，负责最多两条合同生成原因、排序和去重，不拥有世界规则或状态变化公式。

### `SaveService`

将 `CampaignState` 转为版本化 Dictionary/JSON，并恢复状态。

`SaveService` 属于持久化基础设施，不计入七个领域服务。前述七个领域服务应尽量为 `RefCounted`，无场景树依赖。条款、态度、紧迫度和提出方关系可以是服务内部的小型纯函数或私有 RefCounted helper，不作为额外顶层协调者。

## 8. 命令与结果模型

UI 不直接修改状态。玩家操作形成命令：

```text
PlanContractCommand
- contract_offer_id
- selected_member_ids
- selected_supply_ids
- approach

DeclineContractOfferCommand
- contract_offer_id
```

周开场与周末分别返回：

```text
WeekOpeningResult
- week_index
- state_changes[]
- reason_entries[]
- closed_contract_offers[]
- created_contract_offers[]
- created_action_commitments[]
- generated_messages[]

WeekResolution
- resolved_week
- next_week
- contract_result
- faction_action_results[]
- state_changes[]
- reason_entries[]
- generated_messages[]
- updated_problems[]
- triggered_events[]
```

`GameSession` 分别原子应用周开场事务和玩家结束本周事务，允许在规划阶段保存 Offer 与行动承诺，但不允许半结算的周末结果。

合同内部的数据流：

```text
ContractDefinition + locked ContractInstantiationSnapshot
+ ContractPlan + selected member snapshots + contract seed
→ planning attitude snapshot
→ four PhaseResult / CheckResult pairs
→ MissionContext changes
→ preliminary weighted tier and check failure caps
→ internal clause evaluation and breach caps
→ final outcome table and reward
→ internal member evaluation + sponsor relation
→ immutable ContractResolution
```

周末提交的数据流：

```text
ContractResolution + faction action results
→ merge numeric deltas and stable sets
→ apply base effects to temporary CampaignState
→ one situation trigger batch and endings
→ final validation
→ atomic CampaignState replacement
→ project result messages
```

## 9. Signals 使用原则

Signals 用于通知，不用于隐藏控制流。

允许：

- `campaign_loaded`
- `campaign_changed`
- `screen_requested`
- `resolution_ready`

禁止：

- 通过多层 signal 链执行核心周结算
- 由 UI signal 直接修改多个领域对象
- 使用字符串事件名模拟通用总线

## 10. 场景结构

### `app_root.tscn`

```text
AppRoot (Control)
├── Background
├── TopBar
├── Navigation
├── ScreenContainer
└── ModalLayer
```

ScreenContainer 每次只挂载一个主要 Feature 场景。

### Feature 场景

每个功能遵循：

```text
FeatureScreen (Control)
├── Header
├── Content
└── Actions
```

复杂可复用卡片放在 `ui/components`，不要复制场景树。

## 11. UI 展示模型

UI 不应直接读取深层 Domain 对象。每个界面通过 Presenter 或 ViewModel 生成适合显示的数据：

```text
ContractCardViewData
- title
- sponsor_name
- reward_text
- risk_text
- remaining_turns
- expiry_text
- status
- can_decline
- is_declined_placeholder
- predicted_outcomes[]
- member_warnings[]
```

`remaining_turns` 由 Domain 使用 `expires_week - week_index + 1` 计算，UI 只负责显示。这样可以在不改规则的情况下调整信息层级，也避免界面产生倒计时偏差。

Dashboard 的世界问题 ViewData 由 Presenter 读取 `ProblemUrgencyResult`，显示紧迫度等级、问题剩余响应回合和最多两个玩家可见主要原因。精确分数只进入调试与遥测展示。

## 12. 随机数

所有模拟入口都必须接收 `RandomNumberGenerator` 或明确 seed。

禁止：

- 在领域服务内部调用全局随机函数
- 用当前时间作为不可追踪种子
- 在 UI 刷新时重新投掷结果

推荐：

```text
campaign_seed
week_seed = hash(campaign_seed, week_index)
offer_seed = hash(week_seed, offer_instance_id, "contract_resolution")
contract_seed = contract_offer.locked_seed
check_seed = hash(contract_seed, stage_id, check_id)
```

存档必须保存 campaign seed、当前周和任何已锁定的合同 seed。合同与行动提案完全同分时按稳定 Definition ID，不使用选择随机源。未处理合同按固定策略和稳定 Offer 顺序结算，也不使用随机源。

## 13. 原因记录与状态变更

规则服务不直接打印最终解释文本。它返回结构化记录：

```text
ReasonEntry
- code
- source_id
- target_id
- category
- amount
- localization_key
- parameters
- phase
- visibility
```

`visibility` 只允许 player 和 debug；玩家原因按产生顺序与稳定 reason code 排序。

```text
StateChange
- target_id
- field_path
- old_value
- new_value
- reason_codes
```

玩家日志、调试日志和测试断言使用同一来源。

## 14. 存档

存档格式使用带版本号的 JSON 或 Godot Variant 序列化结果。V0.1 推荐 JSON，便于调试和 Codex 检查。

```text
save_version
campaign_seed
week_index
guild_state
adventurer_states
faction_states
situation_state
world_problem_states
world_event_history
contract_history
pending_offers
faction_action_commitments
message_history
locked_resolution_seed
declined_offer_week
```

静态定义只保存 ID。加载时必须验证 ID 是否存在，并对缺失数据给出可理解错误。当前问题紧迫度、年龄和剩余响应回合不存档，加载后从状态重新派生；合同中的 `problem_urgency_at_offer`、生成原因和 `ContractInstantiationSnapshot`，以及行动承诺中的预留 influence 必须保存。

## 15. 测试

V0.1 不引入测试插件。创建可通过命令行运行的最小测试器：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

测试分为：

### Unit

- 认可度公式
- 能力聚合
- 疲劳惩罚
- 时钟裁剪
- 触发器判断
- 世界问题紧迫度的年龄上限、期限边界、区间规则和 0 至 100 裁剪
- 阵营四项意图评分、单一模式和精确目标锁排除
- 每阵营合同来源、资格、重复惩罚和稳定 ID 排序
- 四阶段各一个 check、固定权重和 MissionContext 传递
- 条款条件白名单、Mandatory/Bonus、结果封顶和报酬应用顺序

### Integration

- 同一种子同一结果
- 完整一周结算
- 合同最后有效周仍可接受，下一周正确过期
- 存档加载前后重新派生的问题紧迫度与原因顺序一致
- 阵营关系在合同生成时正确锁定期限与报酬
- declined、过期、NPC 完成和恶化互斥且都有原因记录
- 同周多个到期 Offer 按稳定顺序读取临时工作状态，不会重复解决或重复恶化同一问题
- NPC 完成只复用阵营行动成本、条件和效果；不可执行时按策略后备，不存在 npc_failed
- pending、新 Offer 和行动承诺的 target lock 全局唯一
- 合同提案遍次先于直接行动遍次，行动不会阻止正常三栏恢复
- 同一问题不同 target lock 的并发效果可合并，不产生互斥问题终态
- 行动承诺与 Offer 从同一规划快照生成，承诺 effects 不改变同周合同和预测
- 规划阶段存档往返保留承诺和预留 influence
- 没有 pending 的阵营只提案，有 pending 的阵营只直接行动
- 玩家合同与行动承诺在同一周末事务中全部提交或全部拒绝
- 新 Offer 与承诺创建后才生成开场消息，拒绝消息不会在归档时重复
- 玩家合同来源最多显示两条 player 原因，不暴露精确 AI 权重
- Offer 实例化只修改难度和初始 MissionContext，快照不保存世界事实或可选 check
- 预测与结算使用同一 effective contract，Offer 后续世界变化不改写快照
- 每周最多拒绝一份、当周不补位、下一次生成优先避开相同实例组合且无替代时确定性复用
- 状态和服务中不存在提出方撤回或 cancelled 分支
- 相同状态生成相同阵营意图排序、合同栏和行动计划
- 三个阵营各自最多一份 pending，正常周由 fallback 恢复三栏
- 每个周边界只执行一批触发器，不递归触发
- Opposed 且低士气成员拒绝派遣，不存在永久离队
- 10 周模拟无崩溃
- 保存后加载结果一致
- 合同后果正确写入局势钟

### Golden Trace

为关键合同保存预期原因记录摘要。规则变化时必须人工确认是否更新基准。

## 16. 错误处理

- 对玩家输入使用验证结果，不使用 assert 崩溃。
- 对开发期不变量使用 `assert`。
- 数据加载错误必须包含资源路径和字段名。
- 任何结算失败不得部分修改 CampaignState。

## 17. 性能原则

V0.1 的数据量很小，不做对象池、线程化、ECS 或复杂缓存。优先保证确定性、可读性和测试覆盖。
