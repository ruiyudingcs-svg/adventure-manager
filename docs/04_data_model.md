# 数据模型 V0.1

## 1. 约定

- 所有可引用对象使用稳定 `StringName id`。
- ID 使用小写 `snake_case`，发布后不随显示名称改变。
- 显示文本通过本地化 key 或单独字段保存。
- Definition 为静态数据；State 为运行时数据。
- 数值范围必须在 setter、验证器或加载阶段检查。

## 2. 静态定义

`.tres` authoring 层使用带 `@export` 字段的 `*DefinitionResource` 和一个显式
`ContentManifest`。CatalogValidator 校验并编译后，DataCatalog 只发布本章定义的
构造后只读运行时对象。两层之间不得共享可变集合；完整规则见
`docs/19_content_catalog_state_and_situation_rules.md`。

### 2.1 AdventurerDefinition

```text
id: StringName
display_name: String
class_id: StringName
portrait: Texture2D
base_capabilities: CapabilityBlock
traits: Array[StringName]
values: IdeologyVector
starting_relationships: Array[RelationshipDefinition]
wage: int
bio_key: StringName
```

#### 2.1.1 RelationshipDefinition

```text
target_id: StringName
base_value: int
```

关系是稀疏有向记录，`base_value` 合法范围为 -100 至 +100。同一 AdventurerDefinition 内 `target_id` 唯一；不要求反方向记录存在。

### 2.2 CapabilityBlock

```text
frontline: int      # 0..100
offense: int        # 0..100
scouting: int       # 0..100
support: int        # 0..100
arcana: int         # 0..100
discipline: int     # 0..100
```

### 2.3 IdeologyVector

```text
protect_life: int         # -5..5
respect_authority: int    # -5..5
seek_knowledge: int       # -5..5
pursue_profit: int        # -5..5
taboo_tolerance: int      # -5..5
```

### 2.4 TraitDefinition

```text
id: StringName
display_name_key: StringName
description_key: StringName
rule_tags: Array[StringName]
modifiers: Array[ConditionalModifier]
```

V0.1 的 ConditionalModifier 只支持少量白名单条件，不实现通用脚本表达式。
Gate B 的 trait 手段规则只允许 `docs/15_staged_contract_resolution_rules.md`
第 5.1 节列出的八种 trait 和 preferred/opposed tag 表；命中值固定为
`+3/-4`，不得由内容资源覆写，也不得把 trait ID 当作可执行规则。

#### 2.4.1 MethodTagDefinition

```text
id: StringName
ideology_vector: IdeologyVector
taboo_intensity: int       # 0..2
```

实际使用的 method tag 必须引用该定义。任务后同一 method tag 每份合同只累计一次 `ideology_vector`，不运行标签专用脚本。
`taboo_intensity` 只能使用 Gate B 固定表：necromancy、sacrifice 为 2；
coercion、corpse_handling、preservation、smuggling 为 1；其他已登记 tag 为 0。
Task 006 首批 19 个 method tag 的固定价值向量见
`docs/15_staged_contract_resolution_rules.md` 第 5.1 节；该向量和禁忌强度都是
静态内容，不由合同结果或角色 trait 覆写。

### 2.5 ContractDefinition

```text
id: StringName
title_key: StringName
description_key: StringName
sponsor_faction_id: StringName
related_problem_id: StringName
target_lock_key: StringName
target_problem_tags: Array[StringName]
agenda_tags: Array[StringName]
allow_agenda_origin: bool
starts_unlocked: bool
repeat_policy: StringName
min_reputation: int
prerequisite_contract_ids: Array[StringName]
exclusive_contract_ids: Array[StringName]
proposal_base_priority: int
urgency_weight: int
recent_repeat_cooldown: int
base_reward: int
base_fatigue: int
risk_level: int
offer_duration_weeks: int
intent_ideology_vector: IdeologyVector
expected_method_tags: Array[StringName]
stages: Array[ContractStageDefinition]
clause_ids: Array[StringName]
allowed_supply_tags: Array[StringName]
final_outcome_table: ContractOutcomeTable
availability_rules: Array[WorldRule]
instantiation_rules: Array[OfferInstantiationRule]
unhandled_policy: StringName
npc_completion_action_id: StringName
```

`related_problem_id` 是模板的主要问题锚点，可以为空。非空时必须与对应 `WorldProblemDefinition.contract_definition_ids` 双向一致。`allow_agenda_origin = true` 允许同一手工模板在没有 active 问题时作为阵营 Agenda 提案；此时运行时 Offer 的 `related_problem_id` 为空。

`repeat_policy` 白名单为 `repeatable`、`once_per_campaign`。Agenda 来源必须可重复且对提出方 `agenda_fit > 0`。`starts_unlocked` 为 false 时，合同必须存在于 `SituationState.unlocked_contract_ids` 才能提出。前置合同全部满足且任一互斥合同均未完成时才合格。

`offer_duration_weeks` 表示候选合同在没有关系加成时可供接受的回合数；V0.1 的合同接受后在当周完成，不表示任务执行时长。`target_lock_key` 表示合同的具体目标，同一问题的不同目标应使用不同 key。`urgency_weight` 为 0 至 40；Agenda 和 followup 来源的紧迫度贡献为 0。合同提案参与 FactionIntent 评分，但不读取玩家当前队伍、金币、成员伤病、补给或阵营关系。

`intent_ideology_vector` 和 `expected_method_tags` 用于玩家规划阶段的预期认可度。实际任务后的成员评价必须来自各判定真正产生的手段、价值影响和条款结果。

#### 2.5.1 ContractStageDefinition

```text
id: StringName
phase: StringName
check: ContractCheckDefinition
```

`phase` 白名单及顺序固定为：

- approach
- main_action
- special_objective
- extraction

每个 phase 在一份合同中必须恰好出现一次，并且恰好包含一个 check。

#### 2.5.2 ContractCheckDefinition

```text
id: StringName
check_type: StringName
capability_weights: CapabilityWeights
difficulty: int
result_weight: float
failure_result_cap: StringName
method_tags: Array[StringName]
context_modifiers: Array[MissionModifier]
approach_profile: StringName
outcome_table: CheckOutcomeTable
```

`check_type` 白名单：

- navigation
- reconnaissance
- confrontation
- protection
- rescue
- ritual
- salvage
- extraction

`approach_profile` 白名单为 `careful`、`forceful`、`neutral`。默认画像由 check_type 决定：navigation、reconnaissance、protection、rescue、ritual 和 extraction 为 careful，confrontation 为 forceful，salvage 为 neutral。模板可以改用另一画像，但不能配置自定义 Approach 数值表。

`result_weight` 必须大于 0；四个 check 的权重合计接近 1.0，不存在跳过后的重新归一化。`failure_result_cap` 可以为空，或使用五个结果等级之一；只有该 check 得到 Failure 或 Severe 时才应用上限。

#### 2.5.3 MissionModifier

MissionModifier 条件白名单：

- context_gte
- context_lte
- previous_check_tier_gte
- previous_check_tier_lte
- outcome_tag_present
- supply_tag_present
- approach_is

MissionModifier 只改变当前 check 评分，不决定 check 是否执行。禁止使用表达式字符串或任意字段路径。

#### 2.5.4 CheckOutcomeTable

必须完整定义五个结果等级，每档关联一个 `CheckOutcomeDefinition`：

```text
context_deltas: Array[MissionContextDelta]
member_effects: Array[MemberEffect]
campaign_effects: Array[WorldEffect]
ideology_impact: IdeologyVector
outcome_tags: Array[StringName]
```

`context_deltas` 在任务内立即应用。`member_effects` 和 `campaign_effects` 只加入 `ContractResolution` 的待应用列表。

`ideology_impact` 只记录该结果档产生的实际后果；通用手段的价值含义由去重后的 MethodTagDefinition 提供，条款履约或违约由 ClauseResult 提供，三者不得重复描述同一来源。

MissionContextDelta 只能引用以下 key：

- intel
- route_safety
- time_pressure
- alert_level
- enemy_pressure
- collateral_pressure
- team_strain
- extraction_pressure
- collected_resources
- protected_civilians

#### 2.5.5 ContractClauseDefinition

```text
id: StringName
display_name_key: StringName
description_key: StringName
category: StringName
importance: StringName
all_conditions: Array[TraceCondition]
success_effects: Array[ContractEffect]
failure_effects: Array[ContractEffect]
breach_result_cap: StringName
success_ideology_impact: IdeologyVector
failure_ideology_impact: IdeologyVector
success_tags: Array[StringName]
failure_tags: Array[StringName]
priority: int
```

`category` 白名单：target_state、method、collateral、secrecy、delivery、efficiency、personnel_safety。  
`importance` 白名单：mandatory、bonus。  
所有条款在接受前公开，并在四个 check 完成后统一求值。

TraceCondition：

```text
type: StringName
source_id: StringName
key: StringName
int_value: int
tag_value: StringName
```

TraceCondition 白名单：

- selected_supply_tag_present
- selected_supply_tag_absent
- approach_is
- method_tag_used
- method_tag_not_used
- outcome_tag_present
- outcome_tag_absent
- check_tier_gte
- check_tier_lte
- context_gte
- context_lte
- member_heavy_injury_count_lte

ContractEffect 白名单：

- modify_reward_percent
- modify_sponsor_relation
- add_outcome_tag

V0.1 只支持 `all_conditions`。Bonus 条款不得配置失败效果或结果封顶。条款不直接修改世界钟、成员士气、成员关系、消息或后续合同。完整规则见 `docs/08_contract_clause_spec.md`。

#### 2.5.6 OfferInstantiationRule

```text
id: StringName
all_conditions: Array[OfferBindingCondition]
effects: Array[OfferInstantiationEffect]
reason_code: StringName
```

OfferBindingCondition 白名单：

- clock_gte
- clock_lte
- phase_is
- problem_urgency_gte
- problem_urgency_lte
- problem_age_gte
- problem_remaining_turns_lte
- problem_is_active
- world_event_occurred
- origin_type_is

OfferInstantiationEffect 白名单：

- add_check_difficulty
- add_initial_context

规则按稳定 ID 求值，全部匹配数值先求和后裁剪。单条 check 难度修正为 -10 至 +10，同一 check 汇总到 -20 至 +20；单条初始上下文修正为 -3 至 +3，同一 key 汇总到 -6 至 +6，再应用到默认值并裁剪到 0 至 10。完整规则见 `docs/12_contract_instantiation_and_commitment.md`。

### 2.6 ContractOutcomeTable

合同最终等级的结果表只处理整份合同的基础后果；判定特有后果放在 `CheckOutcomeTable`，避免重复：

```text
reward_multiplier
fatigue_multiplier
injury_risk_modifier
sponsor_relation_delta: int
campaign_effects
outcome_tags
```

成员士气由统一任务后评价产生；结果消息由 ContractResolution 投影；后续合同由 outcome tag 与 SituationRule 解锁。
V0.1 五档 `injury_risk_modifier` 固定为 Exceptional `-10`、Success `-5`、
Partial `0`、Failure `+10`、Severe `+20`，内容不得覆盖。

### 2.7 SupplyDefinition

```text
id: StringName
display_name_key: StringName
cost: int
tags: Array[StringName]
modifiers: Array[ConditionalModifier]
consumed_on_use: bool
```

V0.1 最多选择两个不同补给 ID。补给效果只允许以下固定规则：

- scouting：navigation check `+5`
- medical：rescue check `+5`、any injury `-5`、heavy injury `-2`
- protection：protection check `+5`、any injury `-3`、heavy injury `-4`
- arcane_binding：只触发合同 check 显式声明的 supply modifier
- rations：每名成员未乘结果倍率的疲劳 `-4`

首批补给的固定采购成本为：

| supply ID | tag | cost |
|---|---|---:|
| `supply_medical` | `medical` | 10 |
| `supply_scouting` | `scouting` | 8 |
| `supply_protection` | `protection` | 12 |
| `supply_arcane_binding` | `arcane_binding` | 20 |
| `supply_rations` | `rations` | 6 |

这些成本由后续 Offer/承诺事务锁定和扣除；Resolver 仍只读取补给效果，不直接扣款。

`ConditionalModifier` 只能结构化表达上述匹配条件和数值；不允许新增内容自定义的
全局伤病、疲劳或 check 公式。完整应用顺序见
`docs/15_staged_contract_resolution_rules.md` 第 5.2—5.5 节。

### 2.8 FactionDefinition

```text
id: StringName
display_name_key: StringName
description_key: StringName
agenda_weights: Array[FactionAgendaWeight]
preferred_ideology: IdeologyVector
weekly_action_ids: Array[StringName]
```

`weekly_action_ids` 是行动所有权的唯一来源。DataCatalog 按 ID 返回 detached
`FactionActionDefinition`；行动定义本身不重复保存 owner 字段。

#### 2.8.1 FactionAgendaWeight

```text
tag: StringName
weight: int        # -10..+10
```

候选意图的 `agenda_fit` 为所有匹配标签权重之和，并裁剪到 -30 至 +30。

### 2.9 SituationDefinition

```text
id: StringName
display_name_key: StringName
initial_phase: StringName
clock_definitions: Array[ClockDefinition]
phase_definitions: Array[SituationPhaseDefinition]
problem_definitions: Array[WorldProblemDefinition]
trigger_rules: Array[SituationTrigger]
passive_weekly_effects: Array[ClockDelta]
ending_definitions: Array[EndingDefinition]
```

#### 2.9.1 SituationPhaseDefinition

```text
id: StringName
display_name_key: StringName
description_key: StringName
sort_order: int
is_terminal: bool
```

阶段定义只保存身份与展示信息。进入条件统一由 `SituationTrigger` 的 `change_phase` 效果表达，合同与行动再通过 `phase_is` 条件引用阶段 ID。V0.1 每个局势只能有一个 `is_terminal = true` 的阶段；选择结局后必须进入该阶段。

#### 2.9.2 EndingDefinition

```text
id: StringName
display_name_key: StringName
description_key: StringName
priority: int
all_conditions: Array[WorldCondition]
any_conditions: Array[WorldCondition]
```

结局在周边界的效果与问题转移完成后统一求值。`all_conditions` 必须全部成立；`any_conditions` 为空时不追加限制，否则至少一项成立。同时合格时按 `priority` 降序、再按稳定 ID 升序选择一个，只允许写入一个 `ending_id`，随后进入唯一 terminal 阶段。

`SituationTrigger.set_ending` 不立即覆盖状态，只把引用的 EndingDefinition 加入同一批结局候选，仍使用上述稳定选择规则。V0.1“北境村庄巨龙灾变”直接使用 EndingDefinition 条件，不通过可执行字符串或 UI 公式判断结局。

### 2.10 WorldProblemDefinition

```text
id: StringName
title_key: StringName
description_key: StringName
problem_tags: Array[StringName]
base_urgency: int
age_urgency_per_week: int
age_urgency_cap: int
response_window_weeks: int
urgency_rules: Array[ProblemUrgencyRule]
activation_rules: Array[WorldRule]
resolution_rules: Array[WorldRule]
related_clock_ids: Array[StringName]
contract_definition_ids: Array[StringName]
escalation_effects: Array[WorldEffect]
```

世界问题是持续状态，不是一次性事件。合同和阵营行动通过稳定 ID 引用它。`response_window_weeks` 为 -1 表示没有硬期限，否则必须至少为 1。`escalation_effects` 必须包含一个 `create_world_event` 效果，使问题恶化无论由自身期限还是合同未处理分支触发，都复用同一事件与世界后果。

`activation_rules` 中任一规则成立即可把从未打开的 `inactive` 问题激活；`resolution_rules` 中任一规则成立即可解决 active 问题。问题一旦进入 `resolved`、`escalated` 或 `closed` 不得重新激活。合同和行动通过钟与事件间接满足 resolution rule，不直接争写问题终态。

#### 2.10.1 ProblemUrgencyRule

```text
id: StringName
all_conditions: Array[WorldCondition]
urgency_delta: int
reason_code: StringName
visibility: StringName
priority: int
```

V0.1 的紧迫度规则条件只允许：

- clock_gte
- clock_lte
- phase_is

同一问题针对同一进度钟配置的数值区间必须互斥。所有匹配规则按 `priority`、再按稳定 ID 排序后应用，以保证原因顺序稳定。年龄和期限压力使用统一公式，不通过自定义规则重复实现。
`visibility` 只允许 `player` 或 `debug`。

### 2.11 FactionActionDefinition

```text
id: StringName
agenda_tags: Array[StringName]
target_lock_key: StringName
base_intent_priority: int
urgency_weight: int
recent_repeat_cooldown: int
influence_cost: int
conditions: Array[WorldCondition]
target_problem_tags: Array[StringName]
effects: Array[WorldEffect]
event_key: StringName
```

阵营只从条件成立的行动中按 base priority、紧迫度、Agenda 和重复惩罚排序。`target_lock_key` 与所有 pending Offer、新 Offer 和本周行动全局互斥；`urgency_weight` 为 0 至 40。influence 低于成本时不合格；同分按稳定 Definition ID。入选行动预留 influence，效果延迟到周末应用，不存在竞争或退款分支。`event_key` 必须非空，行动事件只由该字段创建；`effects` 不得再包含 `create_world_event`，避免重复事件。

常规直接行动必须从 active 问题中选择一个 `problem_tags` 覆盖全部 `target_problem_tags` 的目标。作为未处理合同的 `npc_completion_action_id` 复用时，行动读取 Offer 与自身结构化条件，不要求另行生成常规行动候选。

### 2.12 未处理合同字段

`unhandled_policy` 白名单：

- `expire`
- `npc_or_expire`
- `npc_or_escalate`
- `escalate`

`npc_or_expire` 与 `npc_or_escalate` 必须配置 `npc_completion_action_id`，并引用提出方 `weekly_action_ids` 中已有的 `FactionActionDefinition`。其他两种策略必须留空该字段。NPC 完成复用该行动的 `conditions`、`influence_cost`、`effects` 和 `event_key`，不在 ContractDefinition 中复制效果。

使用 `npc_or_escalate` 或 `escalate` 的 ContractDefinition 必须存在非空模板问题锚点。若同一模板以 followup 或 agenda 来源生成 Offer，运行时 `related_problem_id` 为空；NPC 路径仍可执行，但任何 `escalated` 后备结果降为 `expired`。未处理结算不配置条件数组、优先级、Agenda 权重或随机分支。`npc_completed` 只在合同越过有效期后的未处理结算中产生。V0.1 不允许提出方撤回，也不在 pending 期间由第三方行动提前产生终止状态。

### 2.13 ClockDefinition

```text
id: StringName
display_name_key: StringName
min_value: int = 0
max_value: int = 100
initial_value: int
visibility: StringName
```

### 2.14 SituationTrigger

不要使用可执行字符串。使用结构化条件：

```text
id: StringName
all_conditions: Array[WorldCondition]
any_conditions: Array[WorldCondition]
effects: Array[WorldEffect]
once: bool
priority: int
```

V0.1 条件类型白名单：

- clock_gte
- clock_lte
- phase_is
- week_gte
- contract_completed
- problem_is_active
- problem_is_resolved
- world_event_occurred
- world_event_not_occurred

效果类型白名单：

- change_phase
- modify_clock
- unlock_contract
- add_message
- set_ending
- create_problem
- resolve_problem
- create_world_event

#### 2.14.1 WorldRule

```text
id: StringName
all_conditions: Array[WorldCondition]
any_conditions: Array[WorldCondition]
effects: Array[WorldEffect]
once: bool
priority: int
```

`all_conditions` 全部成立且 `any_conditions` 为空或至少一项成立时规则匹配。数组中多条 WorldRule 由拥有该数组的字段决定是“任一规则成立”还是作为候选批处理；规则始终按 priority、再按稳定 ID 求值，不执行表达式字符串。

#### 2.14.2 WorldCondition

```text
type: StringName
target_id: StringName
int_value: int
```

`target_id` 根据 type 引用钟、阶段、周、合同、问题或世界事件；不需要阈值的条件忽略 `int_value`。type 必须来自本节既有条件白名单。

#### 2.14.3 WorldEffect

```text
type: StringName
target_id: StringName
amount: int
reason_code: StringName
```

`target_id` 根据 type 引用钟、阶段、结局、合同、问题、事件或消息 key；非数值效果忽略 `amount`。所有效果必须携带稳定 reason code，并来自本节既有效果白名单。

#### 2.14.4 ClockDelta

```text
clock_id: StringName
amount: int
reason_code: StringName
```

ClockDelta 是 `modify_clock` 的静态简写，用于 SituationDefinition 的每周被动变化；提交时转换成普通 WorldEffect 并参与同一批合并与裁剪。

### 2.15 CampaignSetupDefinition

```text
id: StringName
situation_definition_id: StringName
adventurer_ids: Array[StringName]
faction_setups: Array[FactionSetupDefinition]
initial_active_problem_ids: Array[StringName]
initial_gold: int
initial_reputation: int
initial_base_cohesion: int
weekly_maintenance: int
```

```text
FactionSetupDefinition
- faction_id: StringName
- initial_relation: int
- initial_influence: int
```

正式 manifest 恰好发布一个 `campaign_setup_dragon_invasion_v0_1`。它显式引用八名
成员、三个阵营、唯一 Situation 和三个开局 active 问题；初值固定为 Gold 250、
Reputation 20、base Cohesion 50、weekly maintenance 25，阵营 relation 0 与
influence 60。完整构造规则见
`docs/22_campaign_bootstrap_forecast_and_ui_shell.md`。

Setup 是静态只读 Definition，不进入 CampaignState，也不允许包含 Node、Callable、
可执行字符串或运行时 State。DataCatalog 返回 detached runtime Definition。

## 3. 运行时状态

### 3.1 CampaignState

```text
save_version: int
campaign_seed: int
week_index: int
guild: GuildState
adventurers: Dictionary[StringName, AdventurerState]
factions: Dictionary[StringName, FactionState]
situation: SituationState
pending_contracts: Array[ContractOfferState]
faction_action_commitments: Array[FactionActionCommitmentState]
active_plan: ContractPlanState
contract_history: Array[ContractHistoryEntry]
world_events: Array[WorldEventState]
message_history: Array[MessageState]
declined_offer_week: int
ending_id: StringName
```

V0.1 正式存档 schema 使用 `save_version = 1`；`week_index` 从 0 开始且不得为负。
任何后续 schema 升级必须显式迁移，而不是静默接受未知版本。

### 3.2 GuildState

```text
gold: int
reputation: int
base_cohesion: int
weekly_maintenance: int
```

`gold` 与 `weekly_maintenance` 不得为负；`reputation` 与
`base_cohesion` 的合法范围均为 0 至 100。事务中的多个增减先求和，再在最终
字段上裁剪一次。

V0.1 不保存补给库存。计划选择的补给按 Definition cost 在周末原子事务中购买并
消费；失败不扣金币。ContractResolution 锁定总成本和消费 ID。

### 3.3 AdventurerState

```text
definition_id: StringName
fatigue: int
morale: int
injury_severity: int
recovery_weeks_remaining: int
growth_xp: int
is_available: bool
relationship_deltas: Dictionary[StringName, int]
recent_assignment_count: int
recent_neglect_count: int
```

基础能力和价值观从 Definition 读取。V0.1 不保存离队计数或永久移除成员；预测态度为 Opposed 且 morale 不高于 20 时，派遣命令验证失败。

Gate D 规定 `recent_assignment_count` 与 `recent_neglect_count` 表示连续周数并封顶
3。计数根据上一周冻结参与快照更新，不是独立历史来源。Morale 和
`relationship_deltas` 在 V0.1 没有自然漂移。伤病恢复期间 severity 保持不变；
`recovery_weeks_remaining` 归零的周开场清除伤势并恢复 available。完整规则见
`docs/20_weekly_upkeep_and_history_rules.md`。

#### 3.3.1 AdventurerSnapshot

Task 002 的只读结算快照至少投影稳定成员 ID、能力、价值观、疲劳、士气、伤势、可用性、恢复周数、近期冷落次数、trait IDs 和：

```text
wage: int
relationship_values: Dictionary[StringName, int]
```

`wage` 必须大于 0，供锁定报酬四人均分后的 `reward_fit` 使用。
`relationship_values` 是 `starting_relationships + relationship_deltas` 的独立稀疏有向副本，key 为目标成员 ID。进入合同结算的有效值必须在 -100 至 +100；缺少 key 表示没有显式记录，而不是显式的 0。Resolver 按 `docs/15_staged_contract_resolution_rules.md` 第 4.1 节从四人快照派生六个成员对，不读取 Definition、State 或完整 CampaignState。

### 3.4 FactionState

```text
definition_id: StringName
relation: int       # -100..100
influence: int      # 0..100
```

`relation` 表示该阵营与玩家公会的关系。V0.1 不保存或模拟 NPC 阵营之间的外交关系。

### 3.5 SituationState

```text
definition_id: StringName
phase_id: StringName
clock_values: Dictionary[StringName, int]
triggered_rule_ids: Array[StringName]
unlocked_contract_ids: Array[StringName]
problems: Dictionary[StringName, WorldProblemState]
ending_id: StringName
```

`clock_values` 的每个运行时值均裁剪到 0 至 100；字典 key、阶段、触发器、
解锁合同、问题和结局只保存稳定 ID。

### 3.6 WorldProblemState

```text
definition_id: StringName
status: StringName
opened_week: int
response_deadline_week: int
closed_week: int
source_event_id: StringName
resolution_reason_code: StringName
```

`status` 白名单为 `inactive`、`active`、`resolved`、`escalated`、`closed`。

问题激活时，如果 `response_window_weeks >= 1`，锁定 `response_deadline_week = opened_week + response_window_weeks - 1`；没有期限时保存 -1。`age_weeks`、`remaining_turns` 和当前紧迫度均为派生值，不写入 WorldProblemState。

生命周期字段必须保持一致：`inactive` 的三个周数字均为 -1；非 inactive 状态必须
具有非负 `opened_week`；deadline 若存在则不得早于 opened week；只有 terminal
状态可以具有非负 `closed_week`，而 `resolved`、`escalated`、`closed` 必须具有
closed week。非空的 `source_event_id` 和 `resolution_reason_code` 必须是稳定 ID。

### 3.7 WorldEventState

```text
instance_id: StringName
event_key: StringName
week_index: int
source_id: StringName
related_problem_id: StringName
effect_reason_codes: Array[StringName]
visibility: StringName
```

世界事件是追加式历史记录。持续效果必须写入 `SituationState` 或其他 State，不能依赖反复执行历史事件。

### 3.8 ContractOfferState

```text
instance_id: StringName
definition_id: StringName
sponsor_faction_id: StringName
origin_type: StringName
related_problem_id: StringName
target_lock_key: StringName
offered_week: int
expires_week: int
offered_reward: int
applied_relation_tier: StringName
sponsor_relation_snapshot: int
problem_urgency_at_offer: int
generation_reason_entries: Array[ReasonEntry]
locked_seed: int
instantiation_snapshot: ContractInstantiationSnapshot
status: StringName
resolved_week: int
terminal_reason_code: StringName
```

`status` 白名单为 `pending`、`accepted`、`resolved`、`declined`、`expired`、`npc_completed`、`escalated`。`accepted` 只用于本周结算事务中的过渡状态；结算成功后必须进入 `resolved`。

玩家拒绝后，Offer 以 declined 占位卡保留到当前规划阶段结束，但不再计入 pending 数量，也不能被接受。拒绝命令同时写入历史；下一周归档占位卡时不得重复写入历史。

pending 状态的 `target_lock_key` 进入全局排他集合，阻止任何阵营生成同目标合同或行动。V0.1 不允许提出方撤回，也不让第三方行动直接改变 pending Offer 状态。

`origin_type` 白名单为 `problem`、`followup`、`agenda`。Followup 与 Agenda Offer 的 `related_problem_id` 为空且 `problem_urgency_at_offer = 0`。

`expires_week`、`offered_reward`、`problem_urgency_at_offer` 和完整 `generation_reason_entries` 在生成时锁定。未处理策略来自只读 ContractDefinition，不复制到 Offer；存档加载必须使用相同内容版本。问题当前紧迫度随后可以变化，但不得改写合同生成时的历史解释或可见层级。剩余回合不存档，按以下公式派生：

```text
expires_week = offered_week
             + offer_duration_weeks
             + relation_duration_bonus
             - 1

remaining_turns = expires_week - week_index + 1
```

关系档位：

```text
relation < 25:     standard,  duration_bonus = 0, reward_multiplier = 1.00
relation 25..59:  favorable, duration_bonus = 1, reward_multiplier = 1.10
relation >= 60:   trusted,   duration_bonus = 2, reward_multiplier = 1.20
```

档位不叠加，报酬使用 `round_away` 四舍五入为整数金币且只舍入一次。
`sponsor_relation_snapshot` 在创建时锁定精确的 -100 至 100 关系值；三档字段
只解释期限和报酬，不能替代精确值参与成员认可度。V0.1 的关系档位不参与阵营
行动选择；提出方不存在撤回判断。

#### 3.8.1 ContractInstantiationSnapshot

```text
evaluated_week: int
check_difficulty_deltas: Array[CheckDifficultyBinding]
initial_context: MissionContext
reason_entries: Array[ReasonEntry]
```

```text
CheckDifficultyBinding
- check_id: StringName
- difficulty_delta: int
- reason_codes: Array[StringName]
```

快照在 Offer 生成时锁定并随存档保存，只包含最终难度 overlay、最终初始 MissionContext 和原因。`CheckDifficultyBinding` 只保存 check ID、汇总 delta 与 reason codes；不复制世界事实或规则图。

`declined_offer_week` 初始为 -1；等于当前 week_index 时表示本周拒绝额度已经使用。

### 3.9 FactionActionCommitmentState

```text
instance_id: StringName
faction_id: StringName
action_definition_id: StringName
target_problem_id: StringName
target_lock_key: StringName
committed_week: int
resolves_at_week: int
reserved_influence: int
commitment_reason_entries: Array[ReasonEntry]
status: StringName
resolved_week: int
world_event_ids: Array[StringName]
```

`resolves_at_week = committed_week + 1`。`status` 只允许 `committed`、`resolved`。创建承诺时从 FactionState 扣除 `reserved_influence`，没有退款分支。承诺在规划阶段随存档保存，周末不重新检查行动条件、Agenda 或优先级。

resolved 承诺可以在 10 至 15 周战役内保留在该数组中作为行动历史；只有 `status == committed` 的条目参与周末结算和目标锁判断。

承诺 ID 固定为：

```text
digest = StableSeed.derive(
    0,
    ["faction_action_commitment", committed_week, faction_id,
     action_definition_id, target_problem_id, target_lock_key]
)
instance_id = "faction_action_" + lower_hex8(digest)
```

行动结算事件 ID 为 `instance_id + "_" + event_key`。同一输入必须得到相同
承诺、事件和 reason 顺序；任何 ID 碰撞都拒绝整批事务。

### 3.10 ContractPlanState

```text
contract_instance_id: StringName
selected_member_ids: Array[StringName]
selected_supply_ids: Array[StringName]
approach: StringName
```

Task 004 的纯逻辑输入将保存为只读运行时投影，不修改存档 schema：

```text
EffectiveContract
- instance_id: StringName
- definition_id: StringName
- offered_reward: int
- base_fatigue: int
- risk_level: int
- sponsor_relation_snapshot: int
- intent_ideology_vector: IdeologyVector
- expected_method_tags: Array[StringName]
- allowed_supply_tags: Array[StringName]
- stages: Array[ContractStageDefinition]
- clauses: Array[ContractClauseDefinition]
- initial_context_deltas: Array[MissionContextDelta]
- final_outcome_table: ContractOutcomeTable

ContractPlan
- members: Array[AdventurerSnapshot]
- selected_supplies: Array[SupplyDefinition]
- approach: StringName
```

`EffectiveContract` 是 Offer 与静态定义在结算边界上的完整锁定输入；
`ContractPlan` 使用类型化 SupplyDefinition，不以裸 tag 或 Dictionary 代替。
这些对象均不得持有或修改 CampaignState。

构造 EffectiveContract 时必须显式传入 detached clause 与 MethodTagDefinition
集合；Offer 服务不得从 DataCatalog Autoload 隐式读取它们。

### 3.11 ContractHistoryEntry

```text
week_index
offered_week
contract_instance_id
contract_definition_id
sponsor_faction_id
origin_type
related_problem_id
target_lock_key
terminal_status
terminal_reason_code
member_ids
supply_ids
approach
result_tier
reward_received
trace_summary
state_changes
world_event_ids
generation_reason_entries
```

未被玩家接受的合同也写入历史；其 `member_ids`、`supply_ids`、`approach` 和 `result_tier` 为空。

`ContractHistoryEntry` 是玩家合同及成员参与历史的唯一权威记录。V0.1 不另存成员
出勤表、累计次数或最近周数组。`CampaignHistoryQuery` 只能读取已提交记录，并将
指定周的玩家 resolved `member_ids` 投影为：

```text
WeeklyParticipationSnapshot
- week_index: int
- assigned_member_ids: Array[StringName]
```

成员 ID 稳定排序、去重。declined、expired、npc_completed、escalated 和阵营行动
不进入参与快照；没有玩家合同的周返回空数组。同一周存在多份玩家 resolved 合同
属于历史不一致。快照是临时只读值，不写入 CampaignState 或存档。

### 3.12 MessageState

```text
instance_id: StringName
week_index: int
category: StringName
source_type: StringName
source_id: StringName
title_key: StringName
body_key: StringName
parameters: Dictionary
importance: StringName
sort_order: int
is_read: bool
```

消息 ID 由周、来源类型、来源 ID 和类别稳定生成。同一组合只能写入一次，结算重试和存档加载不得重复追加。

```text
MessageRequest
- category: StringName
- source_type: StringName
- source_id: StringName
- title_key: StringName
- body_key: StringName
- parameters: Dictionary
- importance: StringName
- trace_order: int
```

规则中的 `add_message` 只产生 MessageRequest；只有 `WeeklyMessageProjector` 可以将其转换为 MessageState 并写入历史。

`MessageState.importance` 白名单为 `low`、`normal`、`high`、`critical`。`MessageState.category` 白名单为 `upkeep`、`world_event`、`contract_offer`、`contract_lifecycle`、`faction_action`、`contract_result`、`week_summary`。

### 3.13 SaveEnvelope 与 CampaignState DTO（schema v1）

正式存档根对象固定为：

```text
format: "adventure_manager_campaign"
save_version: 1
campaign_setup_id: String
saved_at_unix_seconds: int
campaign_state: CampaignStateDTO
```

`CampaignStateDTO` 完整保存第 3.1 节字段，其中 `adventurers`、`factions`、
`SituationState.clock_values`、`SituationState.problems` 和
`AdventurerState.relationship_deltas` 使用稳定 ID 作为 JSON object key。其余
Offer、承诺、历史、事件、消息、ReasonEntry、StateChange、实例化快照与
MissionContext 按各自权威数组顺序保存。`active_plan` 没有时为 JSON `null`。

以下数据明确不进入 DTO：

- `ProblemUrgencyResult`、问题年龄和 remaining turns
- `ForecastViewData` 与 Presenter cache
- `WeekOpeningResult`
- `WeekResolution` 和 Resolution review snapshot
- 静态 Definition 数值图

JSON object key 使用稳定排序写出；数组不因序列化重新排序。除
`saved_at_unix_seconds` 外，同一 CampaignState 的 canonical state JSON 必须完全
一致。JSON 本身无法区分整数与浮点、`String` 与 `StringName`，因此只在
Reason/Message parameters、history trace 和 StateChange old/new 这类任意 Variant
位置使用显式标签：

```json
{"__type": "integer", "value": 7}
{"__type": "string_name", "value": "problem_dragon_location_unknown"}
```

已知 schema 字段仍使用普通 JSON number/string，并由 codec 按字段类型恢复。
加载必须构造全新的嵌套 State，运行 `CampaignState.validate()`，再验证所有 Definition
ID 属于 `campaign_setup_id` 的内容闭包；不得把 DTO Dictionary 直接作为权威状态。

## 4. 结果与日志

### 4.1 ReasonEntry

```text
code: StringName
category: StringName
source_id: StringName
target_id: StringName
amount: float
localization_key: StringName
parameters: Dictionary
phase: StringName
visibility: StringName
```

`visibility` 白名单为 `player`、`debug`。玩家展示按产生顺序、再按 reason code 稳定排序。

### 4.2 StateChange

```text
target_id: StringName
field_path: String
old_value: Variant
new_value: Variant
reason_codes: Array[StringName]
```

同一最终字段变化保存所有非零来源的 reason code，顺序由统一结算源顺序确定。对应的完整 `ReasonEntry` 仍保存在 ResolutionTrace 或周结算结果中。

#### 4.2.1 StateOperation

```text
target_kind: StringName
target_id: StringName
field_id: StringName
operation: StringName
value: Variant
reason_code: StringName
source_order: int
```

`operation` 白名单为 `add_int`、`set_id`、`add_unique`、`remove_unique`、
`append_record`。StateOperation 是合并前的待应用意图，StateChange 是成功应用后
的审计结果。字段必须由 `target_kind + field_id` 白名单 dispatch，不把
`field_path` 当作可执行属性路径。合并、冲突和原子规则见
`docs/19_content_catalog_state_and_situation_rules.md` 第 5 节。

### 4.3 FactionIntentCandidate

```text
id: StringName
faction_id: StringName
week_index: int
execution_mode: StringName
source_definition_id: StringName
origin_type: StringName
target_problem_id: StringName
target_lock_key: StringName
agenda_tags: Array[StringName]
base_priority: int
urgency_contribution: int
agenda_fit: int
repeat_penalty: int
total_priority: int
influence_cost: int
eligible: bool
rejection_reason_codes: Array[StringName]
reason_entries: Array[ReasonEntry]
```

`execution_mode` 白名单为 `direct_action`、`contract_proposal`。`origin_type` 仅在合同提案中使用，白名单为 `problem`、`followup`、`agenda`；直接行动为空。候选是纯派生结果，不写入 CampaignState。同分按 source Definition ID，不保存 tie seed。

### 4.4 FactionIntentPlan

```text
faction_id: StringName
week_index: int
mode: StringName
selected_intent_id: StringName
reserved_target_lock_key: StringName
reason_entries: Array[ReasonEntry]
```

`mode` 为 `direct_action` 或 `contract_proposal`。计划最多选择一个意图；模式按规划快照中的 pending 状态锁定，有 pending 时只能 direct action，没有 pending 时只能 contract proposal。所有 contract proposal 计划先于 direct action 计划选择。计划本身不写入 CampaignState。

### 4.5 ProblemUrgencyResult

```text
problem_id: StringName
evaluated_week: int
score: int
band: StringName
remaining_turns: int
reason_entries: Array[ReasonEntry]
```

`ProblemUrgencyResult` 是纯派生结果，不写入 CampaignState。`band` 白名单：

- low
- guarded
- high
- severe
- critical

完整原因用于测试、调试和遥测；Presenter 只选择最多两个 `visibility = player` 的主要原因展示。

### 4.6 MissionContext

```text
intel: int
route_safety: int
time_pressure: int
alert_level: int
enemy_pressure: int
collateral_pressure: int
team_strain: int
extraction_pressure: int
collected_resources: int
protected_civilians: int
outcome_tags: Array[StringName]
used_method_tags: Array[StringName]
```

MissionContext 只存在于一次合同结算中，不写回 CampaignState。需要长期保留的结果必须转换为 `StateChange`、`WorldEventState` 或合同历史。

十个整数指标默认都为 0，合法范围都为 0 至 10。一次 check 内同一 key 的全部 delta 先求和，再裁剪一次；不同 check 按阶段与稳定 check ID 顺序更新。`outcome_tags` 和 `used_method_tags` 稳定去重。完整方向、UI 与更新规则见 `docs/15_staged_contract_resolution_rules.md`。

### 4.7 CheckResult

```text
check_id: StringName
phase: StringName
check_type: StringName
score: int
result_tier: StringName
result_weight: float
seed: int
used_method_tags: Array[StringName]
context_before: MissionContext
context_deltas: Array[MissionContextDelta]
reason_entries: Array[ReasonEntry]
pending_member_effects: Array[MemberEffect]
pending_campaign_effects: Array[WorldEffect]
ideology_impact: IdeologyVector
outcome_tags: Array[StringName]
```

`context_before` 必须是解析该判定前的不可变值快照，不能引用随后继续修改的 MissionContext 实例。四个 check 固定执行，不存在 skipped 状态。

`score` 是 64 位浮点 raw score 按 `round_away` 舍入后得到的不裁剪整数。发生舍入时，`reason_entries` 包含仅 debug 可见的 `score_rounding`，使全部评分原因 amount 之和等于最终 score。完整精度、随机和惩罚规则见 `docs/15_staged_contract_resolution_rules.md` 第 4 节。

### 4.8 PhaseResult

```text
phase: StringName
check_result: CheckResult
reason_entries: Array[ReasonEntry]
```

每个 PhaseResult 恰好引用一个 CheckResult。

### 4.9 ClauseResult

```text
clause_id: StringName
category: StringName
importance: StringName
satisfied: bool
evidence: Array[StringName]
reason_entries: Array[ReasonEntry]
effects: Array[ContractEffect]
ideology_impact: IdeologyVector
outcome_tags: Array[StringName]
```

### 4.9.1 MemberOutcome

```text
member_id: StringName
fatigue_delta: int
injury_result: StringName       # none / light / heavy
injury_seed: int
injury_roll: int
any_injury_chance: int
heavy_injury_chance: int
injury_severity_after: int
recovery_weeks_after: int
is_available_after: bool
morale_delta: int
reason_entries: Array[ReasonEntry]
```

伤病概率读取任务开始时快照疲劳，并使用 operational tier；
疲劳倍率和任务后结果读取 final tier。MemberOutcome 只描述待应用终值，
不得直接修改 AdventurerState。

### 4.10 ContractResolution

```text
contract_instance_id
initial_result_tier
operational_result_tier
result_tier
contract_score
phase_results: Array[PhaseResult]
clause_results: Array[ClauseResult]
final_context: MissionContext
reward
supply_cost_total: int
consumed_supply_ids: Array[StringName]
member_outcomes: Array[MemberOutcome]
sponsor_relation_delta: int
situation_outcomes
outcome_tags
reason_entries
state_changes
```

`member_outcomes`、提出方关系、`situation_outcomes` 和 `state_changes` 都是待应用结果。V0.1 不包含其他阵营反应结果。Resolver 返回完整且验证通过的 ContractResolution 后，GameSession 才能一次性修改 CampaignState。

周末提交时，数值变化按 `target_id + field_path` 求和后只裁剪一次；相同集合项去重，相同状态终值合并，矛盾终值使整个事务失败。世界触发器读取基础效果合并后的临时状态，每个周边界只执行一批，不递归。任一验证失败时，正式 CampaignState、历史与消息都保持不变。

## 5. 数据验证

启动新游戏前运行 CatalogValidator：

- ContentManifest 显式列出全部资源，不通过目录扫描发现内容
- 正式 manifest 恰好包含一个 CampaignSetupDefinition，且 setup ID 唯一
- setup 恰好引用八名不重复成员、三个不重复阵营、一个 Situation 和三个开局问题
- setup 的成员、阵营、Situation、问题引用均存在并属于同一 V0.1 内容闭包
- setup 的 Gold、Reputation、Cohesion、维护、阵营 relation/influence 符合 Gate F
- ID 在整个 manifest 内全局唯一
- 引用 ID 存在
- authoring Resource 编译结果与源资源不共享可变数组、Dictionary 或子资源
- `base_urgency` 在 0 至 100
- `age_urgency_per_week` 和 `age_urgency_cap` 非负
- `response_window_weeks` 为 -1 或至少为 1
- 紧迫度规则只引用存在的进度钟和阶段
- 同一问题的进度钟紧迫度区间不重叠
- 每条非零紧迫度规则都有 reason_code
- 紧迫度规则不引用队伍、金币、成员、阵营关系或合同结果
- FactionAgendaWeight 在 -10 至 +10，且同一阵营 tag 唯一
- 合同和阵营行动的 `target_lock_key` 非空
- 问题 `problem_tags` 与合同 `target_problem_tags` 只使用已登记语义标签
- 问题合同显式列表与合同 `related_problem_id` 双向一致
- 合同 `target_problem_tags` 是对应问题 `problem_tags` 的子集
- 合同与阵营行动的 `urgency_weight` 在 0 至 40
- 意图优先级组成字段在规则规定范围内
- 直接行动的 `influence_cost` 非负
- 阵营行动 `event_key` 非空，且 `effects` 不含第二个 `create_world_event`
- 合同提案规则不引用队伍能力、金币、成员伤病或阵营关系
- 合同 `repeat_policy`、最低声望、前置与互斥引用合法，前置关系无循环
- 每个阵营至少有一份从正常阶段可达、可重复且正 Agenda 匹配的 Agenda 模板
- 三个阵营的 fallback Agenda 合同使用互不相同的 target lock
- Agenda 模板至少推进一项提出方关心的进度钟，并保留正常合同后果
- FactionIntentPlan 的 mode 与规划开始时的 pending Offer 状态一致，并且最多选择一个意图；合同提案遍次先于直接行动遍次
- pending Offer、新 Offer 和行动承诺的精确 target lock 全局唯一
- 阵营行动不包含 objective group、stance、contest 或退款字段
- 能力与价值观范围合法
- 成员工资大于 0；成员快照包含 Gate B 所需的工资、trait、冷落、伤势、恢复和可用性字段
- trait 只使用 Gate B 八项白名单；MethodTagDefinition ID 唯一，所有预期、条款引用和实际 method tag 都有定义
- MethodTagDefinition 的 `taboo_intensity` 与固定 0/1/2 表一致
- 每个 CheckOutcomeTable 和 ContractOutcomeTable 的五个结果等级齐全
- ContractOutcomeTable 五档的 `sponsor_relation_delta` 在 -20 至 +20
- 所有 V0.1 ContractOutcomeTable 五档 `injury_risk_modifier` 固定为 -10/-5/0/+10/+20
- 每份合同恰好包含四个顺序正确且 ID 唯一的阶段
- 每阶段恰好一个 check，四个 check ID 唯一且类型在白名单中
- 每个 check 的 `approach_profile` 在白名单内，不存在合同自定义 Approach 数值表
- 每个判定的能力权重总和接近 1.0
- 四个 `result_weight` 都大于 0 且合计接近 1.0
- check 不包含 required、conditions、optional、toggle 或 skipped 字段
- `expected_method_tags` 覆盖所有玩家在规划阶段应知的必然手段
- `risk_level` 为 1 至 5，锁定提出方关系为 -100 至 +100，锁定报酬和基础疲劳非负
- allowed supply tags、SupplyDefinition tag 和补给 ConditionalModifier 只使用 Gate B 固定白名单与数值
- MissionModifier、TraceCondition、上下文 key 和效果类型在白名单中
- Bonus 条款没有 failure penalty 或 breach_result_cap
- 所有条款公开且不包含 evaluation phase、visibility 或情报字段
- 条款不引用职业 ID、世界钟 delta、成员关系、消息或后续合同直接效果
- clock delta 只引用已定义进度钟
- 合同关联的问题 ID 存在或为空
- `offer_duration_weeks` 至少为 1
- `unhandled_policy` 在白名单内；NPC 策略引用提出方已有的合法行动，非 NPC 策略不携带行动 ID
- 实例化难度、上下文修正和汇总值在规定范围内
- MissionContext 初值和每次 check 更新均按 key 合并后裁剪到 0 至 10
- 实例化规则只修改难度与初始 MissionContext，不保存源规则或世界事实
- 恶化策略的模板必须有问题锚点；followup 或 agenda 来源 Offer 运行时无问题锚点，不得应用恶化效果
- 触发规则效果类型在白名单中
- 世界条件不包含 `faction_relation_gte`，世界效果不包含 `modify_faction_relation`
- 合同至少有一种可达的 availability rule 状态
- 每个非结局阶段、每个阵营至少有一份可达 fallback Agenda 合同
- SituationPhaseDefinition ID 唯一、排序稳定，且恰好一个阶段标记为 terminal
- EndingDefinition 的条件类型合法、priority 可稳定排序，且引用的事件、钟和阶段存在
- 同一输入下同时满足多个结局时只选择 priority 最高的一项
- ContractOfferState 的实例化快照、完整生成原因、declined 状态和每周拒绝额度可完整存档
- FactionActionCommitmentState 的预留 influence、target lock 和状态可完整存档
- ReasonEntry 可见层级只使用 player 或 debug
- MessageState 类别与重要度合法，稳定 ID 不重复
- 数据中不存在 FactionReactionRule、departure strikes 或永久离队分支
- 同一问题不同 target lock 的合同与行动效果可交换合并，不直接写入互斥的问题终态；长期结果优先通过 clock delta、事件和单次 SituationResolver 转移表达
- 状态白名单不包含 cancelled，Definition 不包含 cancellation rule

验证失败时禁止开始游戏，并输出资源路径、字段和错误。

## 6. 首批八名成员基线

Task 006 将下表锁定为 V0.1 首批 `AdventurerDefinition`。能力顺序为
`F/O/Sc/Su/Ar/D`（frontline、offense、scouting、support、arcana、
discipline）；价值顺序为 `L/A/K/P/T`（protect_life、respect_authority、
seek_knowledge、pursue_profit、taboo_tolerance）。

| ID | class | F/O/Sc/Su/Ar/D | L/A/K/P/T | traits | wage |
|---|---|---|---|---|---:|
| `mara_shield` | `vanguard` | 78/42/35/52/18/82 | +2/+4/-1/-1/-3 | loyal | 12 |
| `toren_hammer` | `vanguard` | 72/82/28/32/12/55 | -1/0/-2/+4/+3 | ruthless | 13 |
| `elin_pathfinder` | `ranger` | 38/45/84/40/20/76 | +4/-2/+1/0/-2 | independent | 11 |
| `veska_hunter` | `ranger` | 45/78/72/30/18/48 | -1/-1/0/+2/+1 | ambitious | 12 |
| `sister_ana` | `adept` | 30/22/35/88/52/72 | +5/+2/+1/-2/-5 | compassionate, devout | 12 |
| `orrin_arcanist` | `adept` | 25/35/42/55/86/65 | 0/+1/+5/0/+2 | scholarly | 14 |
| `pell_quartermaster` | `adept` | 42/30/38/80/25/78 | 0/+3/0/+5/0 | cautious | 11 |
| `nera_hedgewitch` | `adept` | 28/38/68/48/82/42 | 0/-4/+2/+1/+5 | independent | 13 |

这些数值是静态角色模板，不是黄金合同测试队伍。每名成员都保留至少一项明显弱项；
疲劳、士气、伤势、成长和当前关系仍只存在于 `AdventurerState`。

## 7. 初始合同类别

12 份合同固定分为：

- 4 份撤离与保护
- 3 份侦察与路线
- 3 份捕获、研究或仪式准备
- 2 份高收益但有伦理代价的合同

完整 ID、提出方、问题锚点、阶段骨架、条款和世界方向见
`docs/09_contract_template_catalog.md`。三份数值化基准合同见
`docs/10_baseline_contracts.md`，其余九份完整数值见
`docs/21_remaining_contract_numerical_rules.md`。每类至少有一份会改变后续合同池。
