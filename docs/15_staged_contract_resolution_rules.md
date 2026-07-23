# 分阶段合同结算规则 V0.1

状态：Accepted（简化修订）  
日期：2026-07-20

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

每个非零修正产生 ReasonEntry。四个 check 各自使用稳定派生 seed：

```text
check_seed = hash(contract_seed, phase, check_id)
```

结果等级：

- 80 以上：Exceptional
- 60 至 79：Success
- 40 至 59：Partial
- 20 至 39：Failure
- 19 以下：Severe

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

随后统一求值公开条款，取最严格 mandatory cap，再读取最终 ContractOutcomeTable。完整条款规则见 `docs/08_contract_clause_spec.md`。

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
- 所有 method tag 有 MethodTagDefinition。
- ContractOutcomeTable 五档都有 sponsor relation delta。
- 不存在 FactionReactionRule 或 departure strikes。

确定性测试至少覆盖：

- 四个 check 固定顺序、稳定 seed 和阶段间 context 传递。
- 同一 check 多个 context delta 先合并后裁剪。
- Approach 合同级效果只应用一次。
- 四个权重直接计算最终分数，不执行重新归一化。
- 条款封顶、报酬、成员士气和提出方关系顺序稳定。
- Opposed 且低士气成员拒绝派遣，没有永久离队分支。
- 多来源数值先合并后裁剪，触发器每个边界只执行一批。
- 任一验证失败时正式状态、历史和消息完全不变。

