# 分阶段合同结算规则 V0.1

状态：Accepted（Gate A / Gate B 数值修订）
日期：2026-07-23

## 1. 简化边界

每份 V0.1 合同固定为四个阶段、每阶段恰好一个 check：

1. `approach`
2. `main_action`
3. `special_objective`
4. `extraction`

不支持空阶段、同阶段多个 check、可选 check、跳过条件、实例化开关或结果权重重新归一化。四个 check 的 `result_weight` 都必须大于 0，合计约等于 1.0。

## 2. MissionContext

十个字段全部为 0 至 10 的整数，默认值为 0：

| 字段 | 方向 |
|---|---|
| intel | 越高越有利 |
| route_safety | 越高越有利 |
| collected_resources | 越高越有利 |
| protected_civilians | 越高越有利 |
| time_pressure | 越高越不利 |
| alert_level | 越高越不利 |
| enemy_pressure | 越高越不利 |
| collateral_pressure | 越高越不利 |
| team_strain | 越高越不利 |
| extraction_pressure | 越高越不利 |

更新规则：

- 实例化初值 delta 先按 key 求和，再应用到默认值并裁剪。
- 单个 check 内同 key 的 delta 先求和，再裁剪一次。
- check 完成后立即更新，下一阶段读取新值。
- `outcome_tags` 和 `used_method_tags` 稳定去重。

UI 显示精确值和来源，不维护另一套模糊等级。

## 3. Approach

每个 check 声明一个 `approach_profile`：`careful`、`forceful` 或 `neutral`。

默认映射：

| check_type | profile |
|---|---|
| navigation | careful |
| reconnaissance | careful |
| confrontation | forceful |
| protection | careful |
| rescue | careful |
| ritual | careful |
| salvage | neutral |
| extraction | careful |

模板可以选择另一画像，但不能自定义数值表。

| Approach | careful | forceful | neutral | 合同级效果 |
|---|---:|---:|---:|---|
| cautious | +3 | -3 | 0 | time_pressure +1；每名成员疲劳 +1；重伤风险 ×0.70 |
| balanced | 0 | 0 | 0 | 无 |
| aggressive | -3 | +5 | 0 | alert_level +1、team_strain +1、collateral_pressure +1；每名成员疲劳 +3；重伤风险 ×1.30 |

合同级 MissionContextDelta 在任务开始时只应用一次。重伤乘数在其他风险加减汇总后应用，最终概率裁剪到 0% 至 100%。

## 4. Check 评分与结果

### 4.1 四人队协同

结算直接读取 Task 002 `AdventurerSnapshot.relationship_values` 中已经合并好的稀疏有向关系。每个显式关系值必须在 -100 至 +100；超出范围时结算验证失败，不在 Resolver 内静默裁剪。四名成员按稳定 ID 排序后形成六个无序成员对，每对关系按以下规则计算：

```text
双方都有显式记录：pair_relationship = (A_to_B + B_to_A) / 2
只有一方有显式记录：pair_relationship = 该方向数值
双方都没有显式记录：pair_relationship = 0
```

关系对允许保留 `.5` 精度。关系贡献、纪律支持、冲突和最终修正为：

```text
average_pair_relationship = round_away(
    average(six_pair_relationships) / 5
)

average_discipline = sum(four_member_discipline) / 4
discipline_support = round_away(
    (average_discipline - 50) / 10
)

active_conflict_count = count(
    pair where any explicit direction <= -50
)
active_conflicts = active_conflict_count * 5

cohesion_score = clamp(
    guild_base_cohesion
  + average_pair_relationship
  + discipline_support
  - active_conflicts,
    0,
    100
)

cohesion_modifier = clamp(
    round_away((cohesion_score - 50) / 5),
    -10,
    10
)
```

`guild_base_cohesion` 必须在 0 至 100。`average_pair_relationship` 范围为 -20 至 +20，`discipline_support` 范围为 -5 至 +5，`active_conflicts` 范围为 0 至 30。单向敌意仍会形成冲突，不会被另一方向的正关系平均消除。除快照关系外不维护第二套冲突 State。

### 4.2 疲劳与伤势惩罚

每名成员先独立转换，再将四人的惩罚相加。疲劳映射固定为：

| fatigue | 每名成员的 penalty |
|---:|---:|
| 0—29 | 0 |
| 30—59 | 1 |
| 60—79 | 3 |
| 80—100 | 5 |

```text
fatigue_penalty = sum(four_member_fatigue_penalties)
```

伤势使用连续五级转换，不依赖 Task 004 如何生成轻伤或重伤：

```text
member_injury_penalty = 0                         if injury_severity = 0
member_injury_penalty = ceil(injury_severity / 20) otherwise

injury_penalty = sum(four_member_injury_penalties)
```

等价整数实现为 `(injury_severity + 19) / 20`。单名成员的伤势惩罚为 0 至 5；全队疲劳和伤势惩罚各为 0 至 20。每名产生非零惩罚的成员各生成一条 ReasonEntry，并按稳定成员 ID 排序。

### 4.3 随机、精度与舍入

`round_away(x)` 表示四舍五入到最近整数，恰好位于 `.5` 时远离 0；Godot 实现统一使用 `roundi()`。除本节明确要求外不做中间取整。

每个 check 使用自己的派生 RNG，恰好调用一次：

```text
seeded_variance = rng.randi_range(-10, 10)
```

这是闭区间 -10 至 +10 上的离散均匀整数分布，21 个结果各为 `1/21`。不得改用浮点分布、额外抽取或共享 RNG。

评分先以 Godot 64 位 `float` 计算 `raw_score`：

```text
raw_score = capability_match
          + cohesion_modifier
          + preparation_modifier
          + approach_modifier
          + attitude_modifier
          + context_modifier
          - fatigue_penalty
          - injury_penalty
          - check_difficulty
          + seeded_variance

check_score = round_away(raw_score)
```

`check_score` 是不裁剪的整数，允许小于 0 或大于 100，结果等级只读取这个整数。每个非零修正产生 ReasonEntry；如果 `check_score != raw_score`，额外生成仅 debug 可见的 `score_rounding` ReasonEntry，amount 为 `check_score - raw_score`，使评分原因之和等于最终整数分数。原因按固定评分项顺序生成；成员惩罚和 context 来源在各自评分项内按稳定 ID 排序。

四个 check 各自使用稳定派生 seed：

```text
check_seed = hash(contract_seed, phase, check_id)
```

结果等级：

- 70 以上：Exceptional
- 50 至 69：Success
- 30 至 49：Partial
- 10 至 29：Failure
- 9 以下：Severe

Task 017 的 2026-07-25 实际战役与首周穷举审计表明，旧 `80/60/40/20`
check 边界与 V0.1 八名成员的真实能力分布不匹配：75 次玩家合同没有 Success，
而首周全部无补给合法方案都没有 Partial 或更好的预测下界。本次 Accepted
调平只将单次 check 边界整体下移 10 点；difficulty、成员能力、`-10..10`
随机、补给与条款均不改变。第 5 节的合同加权等级继续使用独立的
`80/60/40/20` 边界。

每个 check 仍定义五档结果包，因为阶段间 MissionContext、伤病和世界后果需要区别；V0.1 的结构简化来自固定四个 check，而不是合并结果语义。

## 5. 合同等级

```text
Exceptional = 100
Success = 75
Partial = 50
Failure = 25
Severe = 0

contract_score = sum(check_tier_points * result_weight)
```

四个权重固定合计约为 1.0，不做跳过后的重新归一化。check 的 Failure 或 Severe 可以应用自己的 `failure_result_cap`。

### 5.1 任务前认可度

认可度使用整数：

```text
attitude = ideology_fit + method_fit + personal_fit
```

所有公开条款都参与预期向量构造，但只有 `success_ideology_impact` 表达合同希望成员完成的公开方向；`failure_ideology_impact` 描述未来违约后果，不进入任务前预测。为避免合同意图和多个同方向条款重复计分，每个价值维度分别使用最强正、负信号：

```text
positive_signal[i] = max(
    0,
    contract_intent[i],
    every_clause_success_impact[i]
)

negative_signal[i] = min(
    0,
    contract_intent[i],
    every_clause_success_impact[i]
)

expected_vector[i] = clamp(
    positive_signal[i] + negative_signal[i],
    -10,
    10
)

ideology_fit = clamp(
    round_away(dot(member_values, expected_vector) / 5),
    -40,
    40
)
```

零向量条款仍经过稳定遍历和验证，但不凭空产生价值倾向。规划阶段的 method tag 集合为合同 `expected_method_tags` 加上所有公开条款 `method_tag_used` 条件引用的 tag，按首次出现顺序去重。check 阶段只使用该 check 实际 `method_tags` 重新计算 method fit。

每个 trait 对每个唯一 method tag 独立贡献；preferred 为 +3，opposed 为 -4，未列出为 0：

| trait | preferred method tags | opposed method tags |
|---|---|---|
| cautious | scouting, reconnaissance, stealth, protection, nonlethal, extraction | confrontation, direct_assault, coercion, sacrifice |
| ambitious | confrontation, direct_assault, capture, research, ritual | — |
| compassionate | rescue, protection, evacuation, medical, nonlethal | coercion, sacrifice, necromancy, corpse_handling |
| ruthless | confrontation, direct_assault, coercion, sacrifice, necromancy, smuggling | rescue, nonlethal |
| loyal | protection, rescue, evacuation | deception, smuggling |
| independent | scouting, stealth, deception, smuggling, salvage | coercion |
| scholarly | research, ritual, binding, preservation, capture | direct_assault, sacrifice |
| devout | rescue, protection, ritual, nonlethal | necromancy, corpse_handling, sacrifice, deception |

禁忌贡献由 MethodTagDefinition 的固定 `taboo_intensity` 计算：

| taboo_intensity | method tags |
|---:|---|
| 2 | necromancy, sacrifice |
| 1 | coercion, corpse_handling, preservation, smuggling |
| 0 | 其他 tag |

Task 006 首批 method tag 的 `ideology_vector` 固定如下。向量顺序为
`L/A/K/P/T`；未列出的维度为 0。该向量只在任务后按实际使用过的唯一 tag
累计，不替代 CheckOutcome 或条款自身的价值影响。

| method tag | L/A/K/P/T | taboo intensity |
|---|---|---:|
| rescue | +1/0/0/0/0 | 0 |
| protection | +1/+1/0/0/0 | 0 |
| evacuation | +1/0/0/0/0 | 0 |
| scouting | 0/0/+1/0/0 | 0 |
| nonlethal | +1/0/0/0/0 | 0 |
| medical | +1/0/+1/0/0 | 0 |
| research | 0/0/+1/0/0 | 0 |
| ritual | 0/0/+1/0/+1 | 0 |
| capture | +1/0/+1/0/0 | 0 |
| reconnaissance | 0/0/+1/0/0 | 0 |
| confrontation | 0/0/0/0/0 | 0 |
| binding | +1/0/+1/0/0 | 0 |
| stealth | 0/0/0/0/0 | 0 |
| extraction | 0/0/0/0/0 | 0 |
| necromancy | -2/0/+1/+1/+2 | 2 |
| corpse_handling | -1/0/0/+1/+1 | 1 |
| preservation | -1/0/+1/+1/+1 | 1 |
| smuggling | 0/-1/0/+1/+1 | 1 |
| deception | 0/-1/0/0/0 | 0 |

这张表只发布三份基准合同实际引用的首批 19 个 tag。`sacrifice`、`coercion`
等已在全局规则中保留含义但尚未进入 Task 006 manifest，后续发布时必须先补齐
其固定价值向量。

```text
taboo_modifier_for_tag =
    member.taboo_tolerance * method_tag.taboo_intensity

method_fit = clamp(
    sum(trait method modifiers)
  + sum(taboo modifiers for unique method tags),
    -30,
    20
)
```

未知 method tag、未知 trait 或缺少 MethodTagDefinition 均为内容验证错误，不按 0 静默处理。

`personal_fit` 固定为以下六项之和，最后裁剪到 -20 至 +20：

```text
personal_fit = clamp(
    reward_fit
  + growth_fit
  + sponsor_fit
  + neglect_fit
  + risk_fit
  + injury_fit,
    -20,
    20
)
```

报酬按锁定报酬的四人均分与成员周工资之比计算；成员工资必须大于 0：

| `(offered_reward / 4.0) / member_wage` | reward_fit |
|---:|---:|
| < 1.0 | -3 |
| 1.0—1.99 | 0 |
| 2.0—2.99 | +2 |
| >= 3.0 | +4 |

成长机会从锁定后的四个有效 check 难度最高值派生：

| 最高 difficulty | growth_fit |
|---:|---:|
| <= 24 | 0 |
| 25—29 | +1 |
| 30—34 | +2 |
| >= 35 | +3 |

提出方关系读取结算请求中锁定的关系快照：

| sponsor relation | sponsor_fit |
|---:|---:|
| -100—-50 | -4 |
| -49—-10 | -2 |
| -9—24 | 0 |
| 25—59 | +2 |
| 60—100 | +4 |

近期冷落：

| recent_neglect_count | neglect_fit |
|---:|---:|
| 0 | 0 |
| 1 | +1 |
| 2 | +3 |
| >= 3 | +5 |

`risk_level` 必须为 1 至 5。基础风险认可为 `-(risk_level - 1)`；当 risk level 至少为 3 时，cautious 额外 -2，ambitious 或 ruthless 额外 +2，trait 风险修正合计裁剪到 -2 至 +2。伤势认可为：

| injury_severity | injury_fit |
|---:|---:|
| 0 | 0 |
| 1—20 | -1 |
| 21—40 | -2 |
| 41—60 | -4 |
| 61—79 | -6 |
| 80—100 | 禁止派遣 |

`is_available == false` 同样禁止派遣。规划 attitude 为 Opposed 且 morale 不高于 20 时拒绝派遣；其他 Opposed 成员可以强制派遣并记录原因。

每个 check 对每名成员重算：

```text
check_attitude =
    locked_ideology_fit
  + method_fit(actual_check_method_tags)
  + locked_personal_fit
```

Enthusiastic 为 +2，Supportive/Neutral 为 0，Reluctant 为 -3，Opposed 为 -6。四人修正直接除以 4.0，不舍入，保留 `.25` 精度进入 raw check score。任务途中不再触发拒绝派遣。

### 5.2 补给固定效果

V0.1 最多选择两个不同 supply ID。补给只使用结构化 tag 和白名单 ConditionalModifier：

| supply tag | 固定效果 |
|---|---|
| scouting | navigation check +5 |
| medical | rescue check +5；any injury risk -5；heavy injury risk -2 |
| protection | protection check +5；any injury risk -3；heavy injury risk -4 |
| arcane_binding | 只应用合同 check 已声明的 supply tag modifier |
| rations | 每名成员未乘倍率 fatigue -4 |

同一补给的多个不同效果可以同时成立；每个效果保留独立 ReasonEntry。Resolver
返回待消费 supply ID；Task 007 按 Gate C 补充锁定总成本。Resolver 不扣金币，
V0.1 不保存补给库存。

### 5.3 疲劳结算

```text
unscaled_fatigue = max(
    0,
    contract_base_fatigue
  + approach_fatigue
  + sum(applicable CheckOutcome fatigue effects)
  - supply_reduction
)

fatigue_gain = round_away(
    unscaled_fatigue
    * final ContractOutcome.fatigue_multiplier
)

applied_fatigue_delta = min(
    fatigue_gain,
    100 - current_fatigue
)
```

Approach fatigue 为 cautious +1、balanced 0、aggressive +3；rations 对每名成员 `supply_reduction = 4`。全合同最终 tier 确定后才读取 fatigue multiplier，只在乘法完成后舍入一次。本次新增疲劳不参与本次伤病概率，伤病只读取任务开始时快照疲劳。

### 5.4 伤病概率与结果

ContractOutcomeTable 五档的 `injury_risk_modifier` 在所有 V0.1 合同中固定为：

| operational tier | modifier |
|---|---:|
| Exceptional | -10 |
| Success | -5 |
| Partial | 0 |
| Failure | +10 |
| Severe | +20 |

当前疲劳风险：

| current fatigue | risk |
|---:|---:|
| 0—29 | 0 |
| 30—59 | +3 |
| 60—79 | +7 |
| 80—100 | +12 |

队伍保护分别读取四人最高 frontline 和最高 support；同一成员可以同时提供两项。每项按下表转换后相加，因此最多降低 6：

| capability | reduction |
|---:|---:|
| 0—39 | 0 |
| 40—59 | 1 |
| 60—79 | 2 |
| 80—100 | 3 |

CheckOutcome `injury_risk` 的 target ID 为空时作用于四人，指定成员时只作用于该成员。每名成员独立计算：

```text
common_risk =
    risk_level * 5
  + sum(applicable check injury risk)
  + operational_tier injury_risk_modifier
  + current_fatigue_risk
  - team_frontline_support_reduction

any_injury_chance = clamp(
    common_risk + supply_any_injury_modifiers,
    0,
    100
)

heavy_base = clamp(
    round_away(common_risk * 0.40)
    + supply_heavy_injury_modifiers,
    0,
    100
)

heavy_injury_chance = min(
    any_injury_chance,
    clamp(
        round_away(heavy_base * approach_heavy_multiplier),
        0,
        100
    )
)

light_injury_chance =
    any_injury_chance - heavy_injury_chance
```

Approach heavy multiplier 为 cautious 0.70、balanced 1.00、aggressive 1.30。每名成员恰好使用一次独立投掷：

```text
injury_seed = stable_hash(contract_seed, "injury", member_id)
roll = rng.randi_range(1, 100)

roll <= heavy_injury_chance       → heavy
roll <= any_injury_chance         → light
otherwise                         → none
```

结果：

```text
none:
    状态不变

light:
    injury_severity =
        min(79, max(30, current_injury + 20))
    recovery_weeks_remaining =
        max(current_recovery, 1)
    保持 available

heavy:
    injury_severity =
        min(100, max(80, current_injury + 40))
    recovery_weeks_remaining =
        max(current_recovery, 3)
    is_available = false
```

`member_heavy_injury_count_lte` 只读取本次投掷得到的 heavy 数量，不读取概率，也不把 light 计为 heavy。每名成员的风险组成、概率、seed、roll 和结果都生成稳定排序的 ReasonEntry。

### 5.5 无循环结算顺序

```text
1. 验证并锁定 ContractPlan、预期认可度和输入快照
2. 应用一次合同级 Approach context
3. 依次完成四个 check
4. 计算 initial tier
5. 应用 check failure caps，得到 operational tier
6. 只读取 operational ContractOutcome.injury_risk_modifier
7. 为四名成员生成伤病结果
8. 按 priority、稳定 clause ID 求值全部条款一次
9. 汇总 mandatory caps，与 operational tier 取最严格者
10. 得到 final tier
11. 读取 final ContractOutcome 的 reward/fatigue/relation/campaign/tags
12. 计算报酬、疲劳、事后评价和全部待应用结果
```

伤病不读取 clause cap 后的 final tier；人员安全条款可以读取第 7 步已经生成的 heavy 数量；条款改变 final tier 后不得回头重投伤病。`injury_risk_modifier` 只在第 6 步使用一次，fatigue multiplier 只读取第 10 步 final tier。完整条款顺序见 `docs/08_contract_clause_spec.md`。

## 6. 成员任务后评价

任务前认可度读取公开合同意图、公开条款、预期手段和个人状态。任务后只读取实际结果：

```text
actual_ideology_vector =
    sum(CheckOutcome.ideology_impact)
  + sum(ClauseResult.ideology_impact)

actual_method_vector =
    sum(unique used MethodTagDefinition.ideology_vector)

post_mission_evaluation = clamp(
    dot(member_values, actual_ideology_vector) / 5
  + dot(member_values, actual_method_vector) / 5,
    -40,
    40
)
```

两个任务向量各维度先裁剪到 -10 至 +10。同一 method tag 每份合同只计算一次。CheckOutcome ideology impact 只描述实际后果；通用手段含义只放在 MethodTagDefinition，避免重复。

| 评价 | 士气变化 |
|---|---:|
| 20 至 40 | +3 |
| 5 至 19 | +1 |
| -4 至 4 | 0 |
| -19 至 -5 | -1 |
| -40 至 -20 | -3 |

士气裁剪到 0 至 100。V0.1 不保存 departure strikes，也不让成员永久离队：

- 规划时成员预测态度为 Opposed 且当前 morale 不高于 20，则拒绝该派遣，玩家必须换人。
- 其他 Opposed 成员仍可被强制派遣，并承担正常任务后士气变化。
- 价值观不自动修改成员两两关系。

这样保留价值观对派遣的硬约束，不引入补员、永久离队或名单枯竭系统。

## 7. 提出方关系

V0.1 只结算合同提出方：

```text
sponsor_relation_delta = clamp(
    ContractOutcomeTable.sponsor_relation_delta
    + sum(clause sponsor relation effects),
    -20,
    20
)
```

不运行 FactionReactionRule，不让其他阵营自动响应合同 outcome tags。世界政治后果继续通过世界钟、问题、事件和后续合同体现。

## 8. 待应用效果与原子提交

稳定来源顺序：

```text
1. 四个 CheckOutcome
2. 所有 ClauseResult
3. ContractOutcomeTable
4. 成员事后评价
5. 提出方关系
6. 同周阵营直接行动
7. 一批世界触发器与结局
```

Task 007 的 `source_order` 使用百位分段，段内按既有稳定顺序递增：

```text
100..199  ContractResolution 中锁定的世界效果
200..299  ClauseResult
300..399  ContractOutcomeTable、报酬与补给购买
400..499  成员事后结果（成员稳定 ID 顺序）
500..599  提出方关系
600..649  同周阵营直接行动
650..674  周开始被动世界推进
675..699  问题期限与恶化效果
700..749  本边界锁定的一批世界触发器
750..774  问题激活、解决与关闭
775..799  结局选择与 terminal phase
800..899  合同历史追加请求
```

reason code 先按 `source_order`、再按稳定 code 排序；这些数字只编码审计顺序，
不表示优先级，也不得用于覆盖冲突终值。

合并规则：

- 数值按 `target_id + field` 求和后只裁剪一次。
- 标签、解锁 ID、事件和消息请求稳定去重。
- 相同状态终值合并。
- 矛盾状态终值使整个事务失败，不使用 priority 覆盖。
- 每个最终 StateChange 保存全部来源 reason codes。

周末事务：

```text
1. 创建临时 CampaignState
2. 生成合同和阵营行动基础效果
3. 合并、验证并应用到临时状态
4. 从该状态确定一批当前合格触发器
5. 按 priority、稳定 trigger ID 应用这一批一次
6. 结算问题关闭、阶段变化和结局
7. 验证最终临时状态
8. 原子替换正式 CampaignState
9. 生成消息
```

触发器不递归。本批触发器新满足的另一规则留到下一周开始或下一次周末边界。任一失败都不得修改正式状态、历史或消息。

## 9. 验证与测试

CatalogValidator 必须检查：

- 每份合同恰好四个顺序正确的阶段，每阶段恰好一个 check。
- 四个 result weight 均大于 0 且合计约为 1.0。
- 不存在 optional、skip、toggle 或 check condition 字段。
- MissionContext、Approach、结果表和条款边界合法。
- 所有 trait 都在八项白名单中；所有预期、条款引用和实际 method tag 都有 MethodTagDefinition。
- MethodTagDefinition 的 `taboo_intensity` 与固定 0/1/2 表一致。
- 成员工资大于 0；合同 risk level 为 1 至 5，锁定提出方关系为 -100 至 +100。
- 补给 ID 不重复，tag、匹配条件和数值只使用第 5.2 节固定白名单。
- ContractOutcomeTable 五档都有 sponsor relation delta，且 injury risk modifier 固定为 -10/-5/0/+10/+20。
- 不存在 FactionReactionRule 或 departure strikes。

确定性测试至少覆盖：

- 四个 check 固定顺序、稳定 seed 和阶段间 context 传递。
- 六个成员对在无记录、单向记录、双向记录和单向活跃冲突下的协同手算。
- 疲劳 29/30、59/60、79/80 与伤势 0/1、20/21、100 的惩罚边界。
- 离散 variance、raw score 单次舍入、`.5` 远离 0 和不裁剪整数 score。
- 同一 check 多个 context delta 先合并后裁剪。
- Approach 合同级效果只应用一次。
- 四个权重直接计算最终分数，不执行重新归一化。
- 公开条款 success impact 的逐维正负覆盖、method 条件并入预期 tag，以及同方向不重复计分。
- 八种 trait、三档 taboo intensity、personal fit 六项边界和最终裁剪。
- 四人 check attitude 平均值不舍入，保留 `.25` 精度。
- 补给 check、疲劳和伤病效果只在匹配条件成立时应用。
- 疲劳只在 final tier 确定后乘倍率并舍入一次，且不参与本次伤病。
- 疲劳风险档、frontline/support 保护档、any/heavy 概率裁剪和 Approach heavy 乘数边界。
- 每名成员独立 injury seed 恰好抽取一次，heavy/any 阈值与轻重伤终值正确。
- operational tier 先生成伤病，人员安全条款后读取 heavy 数量，final cap 不重投伤病。
- 条款封顶、报酬、成员士气和提出方关系顺序稳定。
- Opposed 且低士气成员拒绝派遣，没有永久离队分支。
- 多来源数值先合并后裁剪，触发器每个边界只执行一批。
- 任一验证失败时正式状态、历史和消息完全不变。
