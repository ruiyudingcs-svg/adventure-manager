# 核心循环与规则 V0.1

## 1. 规则设计原则

### 1.1 结果必须可解释

随机数只决定不确定性，不能取代因果。每个结算修正必须产生 `ReasonEntry`。

### 1.2 状态变化比单次伤害重要

V0.1 不模拟逐次攻击。任务产生疲劳、伤病、士气、关系、阵营和世界状态变化。

### 1.3 意识形态通过具体对象与手段进入决策

不直接显示“你的意识形态坐标”。玩家通过成员认可度、提出方关系、合同条款和局势后果感知组织倾向。

### 1.4 短循环服务长循环

每周必须有明确可解决的小问题；连续选择同时改变 10 至 15 周的危机方向。

## 2. 周结算顺序

必须严格按以下顺序执行，避免隐藏依赖：

```text
1. week_started
2. pay_wages_and_maintenance
3. recover_fatigue_and_injuries
4. update_morale_and_relationship_decay
5. apply_situation_passive_progress
6. settle_problem_deadlines
7. resolve_old_contract_offer_lifecycle
8. evaluate_one_trigger_batch_and_problem_urgency
9. freeze_week_planning_snapshot
10. plan_one_mode_per_faction
11. materialize_contract_offers_or_action_commitments
12. generate_week_opening_messages
13. player_planning_phase
14. resolve_selected_contract_to_pending_effects
15. resolve_faction_actions_to_pending_effects
16. merge_effects_on_temporary_state
17. evaluate_one_trigger_batch_and_endings
18. validate_and_apply_week_end_effects_atomically
19. generate_result_messages_and_week_summary
20. increment_week
```

合同提案和常规阵营行动读取步骤9的同一快照。每个阵营没有 pending Offer 时只提出合同，已有 pending 时只选择不同 target lock 的直接行动。合同与行动效果都在玩家结束本周时提交，并于下一周规划界面体现。触发器在每个周边界只检查一批，不递归运行。完整规则见 `docs/14_week_flow_faction_commitments_and_messages.md`。

## 3. 成员模型

### 3.1 核心能力

每名成员拥有六项 0 至 100 能力：

- `frontline`：承压、保护、稳定正面
- `offense`：击破、压制、快速完成目标
- `scouting`：发现风险、路线与隐藏条件
- `support`：治疗、恢复、保护与后勤
- `arcana`：魔法、仪式、异常目标处理
- `discipline`：执行计划、降低失误和冲突

能力只表示任务贡献，不直接等于职业。

### 3.2 状态

- `fatigue`：0 至 100
- `morale`：0 至 100
- `injury_severity`：0 至 100
- `recovery_weeks_remaining`
- `growth_xp`

建议阈值：

- 疲劳 0–29：正常
- 30–59：轻度惩罚
- 60–79：明显惩罚
- 80–100：高伤病风险

### 3.3 性格标签

V0.1 每人 1 至 2 个：

- cautious
- ambitious
- compassionate
- ruthless
- loyal
- independent
- scholarly
- devout

标签通过规则修正特定情形，不创建通用复杂人格 AI。

### 3.4 价值观

每人维护五个 -5 至 +5 的维度：

- `protect_life`
- `respect_authority`
- `seek_knowledge`
- `pursue_profit`
- `taboo_tolerance`

合同维护同维度的 `intent_ideology_vector`，用于描述玩家在接受前已知的目标倾向。正值表示合同意图强化该价值，负值表示合同意图伤害或违背该价值。任务后的实际评价改用判定结果累计的 `ideology_impact`。

## 4. 合同认可度

成员对合同的认可度由三部分组成：

```text
attitude = ideology_fit + method_fit + personal_fit
```

### 4.1 价值匹配

```text
ideology_fit = sum(member_value[i] * contract_vector[i]) / 5
```

结果裁剪到 -40 至 +40。

### 4.2 手段匹配

合同有方法标签，例如：

- rescue
- coercion
- sacrifice
- necromancy
- research
- deception
- direct_assault

成员性格和禁忌对方法产生 -30 至 +20 修正。

### 4.3 个人匹配

包括：

- 报酬吸引力
- 个人成长机会
- 与委托方关系
- 近期是否连续被冷落
- 伤病和风险承受意愿

V0.1 控制在 -20 至 +20。

### 4.4 认可度效果

| 认可度 | 状态 | 效果 |
|---|---|---|
| 40 以上 | Enthusiastic | 纪律或相关能力小幅加成 |
| 10 至 39 | Supportive | 无惩罚 |
| -9 至 9 | Neutral | 无惩罚 |
| -10 至 -39 | Reluctant | 纪律下降，任务后士气下降 |
| -40 以下 | Opposed | morale 不高于 20 时拒绝派遣；否则可强制派遣并承担士气后果 |

V0.1 不允许完全随机拒绝。拒绝必须由明确阈值和规则触发。

## 5. 小队协同

四人小队的 `cohesion_score`：

```text
cohesion_score = guild_base_cohesion
               + average_pair_relationship
               + discipline_support
               - active_conflicts
```

裁剪到 0 至 100。

关系只维护少量有意义的有向或无向记录，不生成全员完整社交图。V0.1 最多预制 8 至 12 条显著关系。

## 6. 合同阶段与能力判定

### 6.1 固定阶段槽

合同按以下固定顺序结算：

1. `approach`：接近与侦察
2. `main_action`：接敌或执行主要行动
3. `special_objective`：特殊目标处理
4. `extraction`：撤离与善后

每个阶段恰好包含一个结构化 `ContractCheckDefinition`。V0.1 不支持空阶段、同阶段多个 check、可选 check、跳过条件或阶段回跳，也不使用合同专用脚本。

### 6.2 判定类型

V0.1 判定类型白名单：

- `navigation`
- `reconnaissance`
- `confrontation`
- `protection`
- `rescue`
- `ritual`
- `salvage`
- `extraction`

判定类型用于语义、图标和验证，不内置固定公式。每个判定自行声明能力权重、难度、实际手段标签和五档结果，但不声明执行条件。

判定以能力需求权重表示：

```text
requirements:
  frontline: 0.20
  offense: 0.15
  scouting: 0.35
  support: 0.20
  arcana: 0.10
  discipline: 0.00
```

小队某项能力使用以下简化方式：

```text
team_capability = highest_member * 0.55
                + second_highest * 0.25
                + remaining_average * 0.20
```

这样专家重要，但不会让其他成员完全无意义。

每个判定分别计算能力匹配：

```text
capability_match = sum(team_capability[i] * requirement_weight[i])
```

同一支队伍可以在侦察判定中表现优秀，在仪式或撤离判定中表现不足。权重总和必须接近 1.0。

## 7. 成功与风险结算

### 7.1 任务内上下文

合同开始时创建独立的 `MissionContext`。V0.1 只允许以下任务内指标：

- `intel`
- `route_safety`
- `time_pressure`
- `alert_level`
- `enemy_pressure`
- `collateral_pressure`
- `team_strain`
- `extraction_pressure`
- `collected_resources`
- `protected_civilians`

判定可以读取已有指标作为修正，并把结果立即写回 `MissionContext`，供后续判定使用。任务内指标不直接等于 CampaignState 字段。

十个指标统一使用 0 至 10 的整数，默认值为 0，不允许负值。`intel`、`route_safety`、`collected_resources` 和 `protected_civilians` 越高越有利，其余压力指标越高越不利。一次 check 内同一 key 的全部 delta 先求和，再裁剪一次；check 完成后立即更新，后续 check 读取新值。Offer 初值增量同样先汇总，再应用到默认值并裁剪。规划和结算 UI 显示精确值及每次变化来源，不维护第二套等级区间。

### 7.2 单次判定评分

```text
check_score = capability_match
            + cohesion_modifier
            + preparation_modifier
            + approach_modifier
            + attitude_modifier
            + context_modifier
            - fatigue_penalty
            - injury_penalty
            - check_difficulty
            + seeded_variance
```

所有非零修正都必须产生 `ReasonEntry`。`context_modifier` 必须列出来自哪个先前判定和哪个任务内指标，不允许只记录一个无法解释的合计值。

每个判定使用稳定派生种子：

```text
check_seed = hash(contract_seed, stage_id, check_id)
```

新增或删除其他判定不得改变已有稳定 ID 判定的随机结果。

### 7.3 随机范围

V0.1 使用窄随机：建议 `seeded_variance` 为 -10 至 +10。随机不能覆盖明显的准备差异。

### 7.4 判定结果等级

- 80 以上：Exceptional
- 60–79：Success
- 40–59：Partial
- 20–39：Failure
- 19 以下：Severe

每个判定为五档结果分别定义结果包，而不是使用统一伤害公式。

### 7.5 判定效果的应用顺序

每个判定结果可以产生：

1. `context_deltas`：立即修改本次任务上下文，影响后续判定。
2. `member_effects`：疲劳、伤病风险、士气等人员后果，先加入待应用列表。
3. `campaign_effects`：进度钟、世界问题和阵营相关效果，先加入待应用列表。
4. `ideology_impact`：实际行为产生的价值观影响。
5. `outcome_tags`：供条款、世界触发器和消息使用的语义标签。

只有 `context_deltas` 在阶段间立即生效。其他效果在整份合同成功完成结算后一次性应用，任何中途错误都不得部分修改 `CampaignState`。

例如：

```text
search_burned_town 成功
→ context: intel +2, time_pressure +1, enemy_pressure -1
→ pending campaign: settlement_destruction +1
→ outcome tag: civilians_located

后续 confrontation
→ intel 提供难度修正 -6
→ enemy_pressure 提供难度修正 -4

最终 extraction
→ time_pressure 提供难度修正 +5
```

### 7.6 成员态度在判定中的作用

规划阶段仍根据合同意图向量和预期手段计算成员认可度。实际判定再根据该判定的 `method_tags` 计算手段匹配。每名成员对当前判定提供以下可解释修正：

| 状态 | 判定修正 |
|---|---:|
| Enthusiastic | +2 |
| Supportive | 0 |
| Neutral | 0 |
| Reluctant | -3 |
| Opposed 且被强制派遣 | -6 |

`attitude_modifier` 为四名成员修正的平均值。合同完成后，成员根据实际累计的 `ideology_impact`、去重手段和条款结果更新士气；每个任务向量维度裁剪到 -10 至 +10，事后评价裁剪到 -40 至 +40。所有参与者评价整份任务，不按贡献阶段加权。评价 20 以上士气 +3，5 至 19 士气 +1，-4 至 4 不变，-19 至 -5 士气 -1，-20 以下士气 -3。

V0.1 不保存离队计数，也不永久移除成员。规划时预测态度为 Opposed 且 morale 不高于 20 的成员拒绝该派遣；其他 Opposed 成员仍可被强制派遣。意识形态不自动修改成员两两关系，也不替代能力判定。

### 7.7 合同最终等级

四个判定都声明大于 0 的 `result_weight`，权重总和必须接近 1.0。

判定等级转换为点数：

```text
Exceptional = 100
Success = 75
Partial = 50
Failure = 25
Severe = 0
```

```text
contract_score = sum(check_tier_points * result_weight)
```

四个 check 固定执行，不存在跳过或重新归一化。合同最终等级继续使用 80、60、40、20 阈值。关键判定可以声明 `failure_result_cap`；当该判定为 Failure 或 Severe 时，最终等级不得高于该上限。

### 7.8 条款、阵营和世界反馈

合同条款在四个判定完成后检查完整 `ResolutionTrace`，可以读取计划、实际手段、判定等级、结果标签、MissionContext 和重伤数量。条款不得读取待应用世界钟变化。

V0.1 条款类别固定为目标状态、执行手段、附带损失、隐蔽警戒、收集交付、时间效率和人员安全。重要程度只有 Mandatory 与 Bonus；所有条款公开并在任务后统一求值。

规划界面可以预览当前计划明显满足或违反的条款，但不会提前应用效果。多个封顶使用最严格等级；Bonus 不得产生失败惩罚或封顶。

条款条件只支持 `all_conditions`。所有条款按 priority 和稳定 ID 各求值一次；同一行为可以影响多个条款并叠加效果。条款报酬百分比合计裁剪到 -100% 至 +100%。条款不直接修改成员士气、成员关系、消息、后续合同或世界钟；这些分别由任务后评价、结果投影和 outcome tag 触发规则处理。

条款不为英雄单独投骰。英雄通过相关 check 的能力贡献、实际手段、任务上下文和结果标签满足条款。全部条款进入任务前认可度，实际条款结果进入任务后成员评价。

实际 CheckOutcome 负责改变世界；条款只改变报酬、提出方关系、最终等级、价值影响和结果标签。完整白名单和报酬顺序见 `docs/08_contract_clause_spec.md`。

V0.1 只结算提出方关系：最终结果表的基础关系与条款关系求和后裁剪到 -20 至 +20。其他阵营不自动响应合同 outcome tags；更广泛的政治后果通过世界钟、问题、事件和后续合同体现。进度钟变化来自 CheckOutcome 和合同最终结果，每项变化必须有独立原因。

## 8. 行动倾向

每个 check 只声明 `careful`、`forceful` 或 `neutral` 画像。navigation、reconnaissance、protection、rescue、ritual 和 extraction 默认为 careful，confrontation 默认 forceful，salvage 默认 neutral；模板可以覆盖画像，但不能覆盖以下全局数值：

| 行动倾向 | careful check | forceful check | neutral check | 合同级效果 |
|---|---:|---:|---:|---|
| Cautious | +3 | -3 | 0 | time_pressure +1；疲劳 +1；严重伤病风险 -30% |
| Balanced | 0 | 0 | 0 | 无 |
| Aggressive | -3 | +5 | 0 | alert_level +1、team_strain +1、collateral_pressure +1；疲劳 +3；严重伤病风险 +30% |

合同级 MissionContextDelta 在任务开始时只应用一次，不随 check 重复。具体结果包仍可产生自己的上下文、疲劳和伤病效果。完整边界见 `docs/15_staged_contract_resolution_rules.md`。

Approach 疲劳加入每名参与成员。严重伤病风险在其他加减风险汇总后乘以 Cautious 0.70 或 Aggressive 1.30，再裁剪到 0% 至 100%；Balanced 乘数为 1.00。

## 9. 伤病与疲劳

### 9.1 疲劳增加

```text
fatigue_gain = contract_base_fatigue
             + approach_fatigue
             + failure_fatigue
             - supply_reduction
```

### 9.2 伤病检定

伤病风险来自：

- 合同风险
- 结果等级
- 当前疲劳
- 行动倾向
- 前卫或支援保护
- 补给

伤病结果只需要：无伤、轻伤、重伤。重伤必须产生明确原因。

## 10. 世界局势、问题与事件

### 10.1 结构

世界层使用：

- 世界局势阶段状态机
- 多条进度钟
- 当前世界问题
- 已发生的世界事件
- 阵营 Agenda
- 跨钟触发规则

概念边界：

- `Situation` 是持续整局的危机状态。
- `WorldProblem` 是当前尚待处理的具体压力或机会。
- `WorldEvent` 是已经发生的离散事实和效果记录。
- `FactionAction` 是 NPC 阵营对当前局势或问题采取的自主行动。
- `ContractOffer` 是阵营提供给玩家的限时行动方案，通常引用一个问题，但不是问题本身。

### 10.2 世界问题紧迫度

世界问题紧迫度回答“这个问题继续不处理时，对世界而言有多紧迫”。它不表示某个阵营有多想处理该问题；阵营偏好由 Agenda 匹配单独计算。

紧迫度为 0 至 100 的确定性派生值：

```text
urgency_score = base_urgency
              + clock_pressure
              + age_pressure
              + deadline_pressure
              + phase_pressure
```

最终裁剪到 0 至 100。每个非零组成项必须产生 `ReasonEntry`。

#### 基础紧迫度

`base_urgency` 表示问题刚出现时的基础严重程度，由问题定义提供。

#### 进度钟压力

每个问题使用结构化、互斥的 `ProblemUrgencyRule` 把进度钟区间映射为紧迫度修正。不同进度钟的危险方向可能不同，因此不使用通用的“钟越高越危险”公式。

#### 持续时间压力

```text
age_weeks = current_week - opened_week

age_pressure = min(
    age_weeks * age_urgency_per_week,
    age_urgency_cap
)
```

不随时间恶化的问题可将 `age_urgency_per_week` 设为 0。

#### 响应期限压力

问题激活时锁定：

```text
response_deadline_week = opened_week + response_window_weeks - 1
remaining_turns = response_deadline_week - current_week + 1
```

`response_window_weeks = -1` 表示没有硬期限。存在期限时使用统一修正：

| 剩余回合 | 修正 |
|---|---:|
| 3 回合以上 | +0 |
| 2 回合 | +10 |
| 1 回合 | +25 |

当 `current_week > response_deadline_week` 时，不再继续增加紧迫度，而是执行问题定义的恶化、关闭或阶段变化规则。

#### 局势阶段压力

`ProblemUrgencyRule` 可以根据当前 Situation phase 提供修正。阶段修正应避免和进度钟规则重复表达同一危险。

#### 紧迫度等级

| 分数 | ID | 玩家显示 |
|---|---|---|
| 0–19 | low | 暂时稳定 |
| 20–39 | guarded | 值得关注 |
| 40–59 | high | 紧迫 |
| 60–79 | severe | 严重 |
| 80–100 | critical | 临界 |

玩家界面显示等级、响应倒计时和最重要的两个可见原因，不显示精确 AI 权重。完整分数与原因用于测试、调试和遥测。

紧迫度可以用于：

- 阵营意图优先级
- 合同提案优先级
- Dashboard 警报

紧迫度不得直接修改合同难度、报酬、成员能力、阵营关系、进度钟或问题状态。这些变化必须由各自的显式规则产生。

紧迫度由无状态纯函数按需计算：在世界被动变化和问题状态更新后供阵营行动使用；阵营行动、旧合同处理或触发器改变世界后再次计算，供合同提案和 Dashboard 使用。紧迫度本身不作为权威 State 存档。

### 10.3 阵营意图

`FactionIntent` 表示某个阵营本周希望针对一个世界问题或 Agenda 目标采取什么行动，以及形成该选择的原因。V0.1 不实现通用规划 AI；所有候选来自结构化的阵营行动定义、合同定义、活跃世界问题和阵营 Agenda。

意图执行方式只有：

- `direct_action`：阵营直接改变世界状态。
- `contract_proposal`：阵营向玩家提出合同，本身不立即改变世界状态。

每个候选必须声明 `target_lock_key`。目标锁表示具体目标而不是整个问题，例如 `east_road.evacuate_civilians` 和 `east_road.scout_route` 可以属于同一世界问题但互不冲突。

#### 候选来源

直接行动候选来自条件成立的 `FactionActionDefinition`。合同提案来源固定为：

- `problem`：响应 active 世界问题。
- `followup`：由合同结果或局势规则解锁。
- `agenda`：阵营使用可重复的手工模板推进自身进度钟和 Agenda。

问题来源只从 `WorldProblemDefinition.contract_definition_ids` 显式白名单枚举，不按标签自动拼装合同。合同的 `related_problem_id` 必须与问题双向一致；`problem_tags` 与 `target_problem_tags` 只用于内容验证和原因解释。

`allow_agenda_origin = true` 的模板可以在没有 active 锚点问题时作为 Agenda 来源。它仍使用原有阶段、判定、条款与世界效果，不是无后果的填充任务。同一模板的来源优先级固定为 `problem > followup > agenda`，每周只产生一个来源候选。

候选不得根据玩家队伍能力、金币或成员伤病生成。阵营关系在 V0.1 也不参与意图评分。

#### 合同提案资格

合同提案按固定顺序检查战役结局、引用、局势阶段、问题状态、解锁、前置、互斥、最低声望、重复策略、pending 合同、目标锁、Agenda 匹配和最终正优先级。每个失败项都生成结构化排除原因。

`problem` 来源要求问题 active 且显式匹配；`agenda` 来源要求 `agenda_fit > 0`、`repeat_policy = repeatable`。非初始开放合同必须存在于 `SituationState.unlocked_contract_ids`。资格规则不得读取队伍、成员伤病、金币、补给或阵营关系。

每个阵营至少配置一份从正常阶段可达、可重复且目标锁独立的 Agenda 模板。具体模板可以因阶段、问题或目标失效而不合格，但阵营仍必须能产生其他合法提案。

#### 意图优先级

```text
total_priority = base_priority
               + urgency_contribution
               + agenda_fit
               - repeat_penalty
```

V0.1 固定范围：

| 组成项 | 范围 |
|---|---:|
| base_priority | 0..20 |
| urgency_contribution | 0..40 |
| agenda_fit | -30..+30 |
| repeat_penalty | 0..20 |

只有 `total_priority > 0` 的候选可以入选。

```text
urgency_contribution = round(
    problem_urgency * urgency_weight / 100
)
```

`urgency_weight` 为 0 至 40。Agenda 匹配为候选所有 `agenda_tags` 在阵营 `agenda_weights` 中的权重之和，并裁剪到 -30 至 +30。

无关联问题的 Agenda 与 followup 来源 `urgency_contribution = 0`。需要优先展示的 followup 直接在手工定义中使用更高 base priority。

重复惩罚只影响排序，不禁止可重复合同：

```text
remaining_cooldown = max(
    0,
    recent_repeat_cooldown - (current_week - last_offered_week)
)

repeat_penalty = 0                               if recent_repeat_cooldown = 0
repeat_penalty = round(
    20 * remaining_cooldown / recent_repeat_cooldown
)                                                otherwise
```

所有非零评分项和排除条件都必须生成原因记录。排序依次使用总优先级、静态优先级和 Definition ID；规划选择不使用随机决胜。

#### 阵营每周容量

每个阵营每周只进入一种模式：

- 没有 pending Offer：选择并提出一份合同，不创建直接行动。
- 已有 pending Offer：保留合同，并可以选择一项不同 target lock 的直接行动。

合同提案不消耗 influence；行动承诺创建时预留并扣除 `influence_cost`。每个阵营最多一份 pending Offer，三个阵营各自维护一个合同栏。

#### 协调顺序

所有阵营读取同一规划快照，模式以规划开始时是否已有 pending 确定。规划器先按稳定 faction ID 为所有空栏选择合同，再按稳定 faction ID 为已有 pending 的阵营选择直接行动。pending Offer、新 Offer 和行动承诺共享一个精确 target lock 集合；目标已占用时，当前阵营尝试下一合法候选，没有候选则等待。合同优先的一次两遍规划保证直接行动不会阻止正常三栏生成。

正式进入 pending 的合同形成不可撤回的提出方承诺。提出方可以在下一周处理其他目标，但不能创建相同 target lock 的行动或 Offer。

直接行动入选后创建 `FactionActionCommitmentState`，只锁定定义、目标、预留 influence 和原因。行动在玩家结束本周时应用预制效果；不存在谈判、抢先、冲突、胜者、退款或 NPC 战斗。V0.1 不定义 objective group、stance 或静态 NPC 阵营关系。

需要补栏的阵营各自选择自己的最高分合同，不创建 `ContractProposalCandidate`，不运行全局多样性、紧迫问题入口或 Agenda 补位。完整规则见 `docs/11_contract_proposal_generation.md` 与 `docs/14_week_flow_faction_commitments_and_messages.md`。

### 10.4 每周推进

进度来源：

- 被动环境变化
- NPC 阵营行动
- 玩家合同结果
- 未处理问题的恶化事件
- 阈值触发效果

世界问题在被创建后持续存在，直到被合同、阵营行动、触发规则或局势阶段变化解决或关闭。世界事件只记录一次发生，不承担持续状态。

本周合同与常规阵营行动在进入下一周的边界一起产生世界效果。它们从同一规划快照独立求值，再合并为待应用变化；不得通过先应用一方来改写另一方的成功率或资格。

### 10.5 消息与生成原因可见性

消息只投影已经创建的 Offer、行动承诺、事件、历史或已提交结果。结构化结果可以产生 `MessageRequest`，由 `WeeklyMessageProjector` 统一创建稳定、可去重的 `MessageState`。

`ReasonEntry.visibility` 只允许 `player` 和 `debug`。合同固定显示一条来源说明和最多两条 player 原因；可以显示紧迫度等级、响应倒计时、阶段、事件、Agenda 与后续机会，不显示精确 AI 权重、被排除候选或内部 ID 排序。

### 10.6 巨龙入侵阶段与结局触发

“北境村庄巨龙灾变”的精确阶段、结局和进度钟规格以 `docs/17_dragon_invasion_scenario_spec.md` 为唯一来源。阶段按周数转移，钟阈值负责问题、机会和结局，不再用毁坏阈值创建额外阶段：

```text
IF phase = phase_early_crisis
AND week >= 5
THEN phase = phase_open_conflict

IF phase = phase_open_conflict
AND week >= 9
THEN phase = phase_final_window

IF week >= 10
AND capture_preparation >= 80
AND dragon_exhaustion >= 60
AND necrotic_corruption <= 59
THEN ending candidate = ending_arcane_capture

IF week >= 10
AND necrotic_corruption >= 100
THEN ending candidate = ending_necrotic_catastrophe
```

结局在同一周边界统一求值，同时合格时按 EndingDefinition priority 降序、稳定 ID 升序选择一个。跨钟规则必须数据化，不写死在 UI。第 15 周的保底杀龙条件和四个结局的完整优先级见剧本规格。

## 11. 合同对局势的影响

每个结果等级定义一组时钟增量。例如“护送北境村民撤离”：

| 结果 | 撤离 | 毁坏 | 巨龙疲劳 | 捕获准备 | 死灵污染 |
|---|---:|---:|---:|---:|---:|
| Exceptional | +24 | +2 | +4 | 0 | -3 |
| Success | +18 | +5 | +2 | 0 | 0 |
| Partial | +10 | +10 | 0 | 0 | +2 |
| Failure | +3 | +16 | 0 | 0 | +5 |
| Severe | 0 | +24 | -2 | 0 | +10 |

玩家在准备阶段只能看到预测区间，而不是精确表格。

## 12. 候选合同生命周期

### 12.1 生成与保留

每周处理完世界问题和旧合同后，三个阵营分别维护自己的合同栏。旧 pending Offer 继续保留；没有 pending 的阵营从自己的合法 problem、followup 或 Agenda 模板中提出一份最高分合同。

每个非结局阶段必须为每个阵营配置至少一个可达 fallback Agenda 模板。某阵营无法恢复自己的合同栏时返回 `faction_offer_missing` 内容错误，不运行全局补位或生成无效合同。玩家在规划阶段拒绝一份合同后，当周不补位。

合同生成时锁定：

- `offered_week`
- `expires_week`
- `offered_reward`
- `locked_seed`
- 提出方、来源类型和关联世界问题
- `ContractInstantiationSnapshot`

实例化规则只允许修改 check 难度和初始 MissionContext。快照只保存最终 overlay 与原因；预测从静态模板、锁定快照和当前计划派生，不单独保存预测值、源规则或世界事实。

Offer 生成后的世界变化不重算实例快照。`related_problem_id` 在实例化后是来源记录，不作为实时取消条件。完整规则见 `docs/12_contract_instantiation_and_commitment.md`。

过期周按以下公式锁定：

```text
expires_week = offered_week
             + offer_duration_weeks
             + relation_duration_bonus
             - 1
```

当前周可接受的剩余回合：

```text
remaining_turns = expires_week - week_index + 1
```

关系修正在生成时应用，档位不叠加：

```text
relation < 25:  duration +0, reward x1.00
relation 25..59: duration +1, reward x1.10
relation >= 60: duration +2, reward x1.20
```

报酬取整规则为四舍五入到整数金币。已生成合同不会因关系变化重新计算。V0.1 的阵营关系不参与阵营行动选择；提出方不存在撤回判断。

### 12.2 玩家拒绝

玩家每周最多拒绝一份尚未接受的 pending 合同：

- 状态变为 `declined` 并立即释放提出方目标锁。
- 不修改关系、世界钟、世界问题或 influence。
- 当周不补位；界面保留 declined 占位卡，下一周由同一阵营重新提出。
- 同一合同定义、来源、问题和目标锁组合在下一次生成时优先排除一次；若排除后没有合法候选，则允许该组合重复并记录原因。
- 拒绝额度以 `declined_offer_week` 保存，支持规划阶段中途存档。

拒绝不会处理关联问题或触发合同到期后果。问题继续正常推进。已接受合同在当周结束、进入下一周的边界结算，不允许接受后放弃，也不会跨过下一次玩家规划阶段。

### 12.3 提出方承诺

每份 pending Offer 从自身字段派生提出方承诺锁，不保存第二套 State。锁阻止所有阵营创建相同 target lock 的行动承诺或新合同，但不阻止提出方下一周处理其他目标。

V0.1 不允许提出方主动撤回，不使用 `cancellation_rules` 或 `cancelled`。第三方行动不会在 pending 期间直接完成、取消或间接关闭 Offer。Offer 只会因玩家接受、玩家拒绝或越过有效期离开 pending。

### 12.4 未处理合同结果

只处理同时满足 `status == pending` 与 `current_week > expires_week` 的 Offer。每份合同模板用 `unhandled_policy` 固定选择路径：

| `unhandled_policy` | NPC 行动可执行 | NPC 行动不可执行 |
|---|---|---|
| `expire` | `expired` | `expired` |
| `npc_or_expire` | `npc_completed` | `expired` |
| `npc_or_escalate` | `npc_completed` | `escalated` |
| `escalate` | `escalated` | `escalated` |

如果 Offer 关联的问题已经不是 `active`，无论策略为何都只进入 `expired`，避免重复解决或重复恶化。Followup 和 Agenda 来源 Offer 的运行时问题 ID 为空；它们仍可执行策略中的 NPC 路径，但任何 `escalated` 后备结果都降为 `expired`，绝不凭空恶化一个世界问题。

NPC 行动可执行的条件固定为：`npc_completion_action_id` 引用提出方已有的 `FactionActionDefinition`；行动的 `conditions` 在当前工作状态中全部成立；提出方 influence 不低于 `influence_cost`。Offer 已到期，因此它自身的承诺锁不再阻止这次生命周期行动。满足时扣除 influence、应用该行动的 `effects` 并创建其 `event_key` 对应事件。该过程不运行四阶段合同模拟，不创建英雄队伍，不读取条款、难度、成员、补给或玩家资源，也不产生随机 NPC 成败。

`escalated` 只在关联问题仍为 `active` 时应用 `WorldProblemDefinition.escalation_effects`，并把问题置为 `escalated`。如果问题已经按自身响应期限恶化，Offer 只自然过期，不重复应用效果。`expired` 不产生即时世界效果。

同周到期 Offer 按 `expires_week`、`offered_week`、`instance_id` 升序，在一份临时工作状态上依次求值。前一个结果改变问题后，后一个 Offer 必须读取新状态；全部计划验证通过后再原子提交。整个流程不使用随机数。三种结果都生成合同历史、玩家消息和原因记录；只有 `npc_completed` 与 `escalated` 创建世界事件。终止结果应用后，Offer 不再参与后续判断。完整规范见 `docs/13_unhandled_contract_and_npc_results.md`。

## 13. 经济

### 13.1 收入

- 合同基础报酬
- 条款奖金
- 阵营支持

### 13.2 支出

- 周工资
- 基础维护
- 补给购买
- 治疗费用

V0.1 不模拟税务、物价和库存市场。阵营关系对报酬的修正只使用第 12 节的固定档位，不进行合同谈判。

## 14. 因果日志

每条日志至少包含：

```text
source_id
category
label
value_delta
affected_entity_id
visibility
```

示例：

```text
source_id: member_elin_scouting
category: capability
label: "艾琳的侦察发现了安全路线"
value_delta: +11
affected_entity_id: contract_north_road_evacuation
visibility: player
```

日志既用于玩家解释，也用于测试和后续平衡分析。
