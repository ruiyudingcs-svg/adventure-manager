# 合同条款规范 V0.1

状态：Accepted（简化修订）  
日期：2026-07-20

## 1. 目的

条款描述委托方对目标、手段和附带结果的要求。合同主要目标仍由四个阶段 check、结果权重和失败封顶决定；条款不获得专用投骰，也不执行合同专用脚本。

V0.1 所有条款在接受前公开，并在四个 check 全部完成后统一求值。规划界面可以根据当前计划预览明显满足或违反的条款，但不提前应用效果。

## 2. 条款类别

七类 category 仅用于内容组织、图标和文本：

| category | 含义 |
|---|---|
| target_state | 最终目标状态 |
| method | 要求或禁止手段 |
| collateral | 附带损失限制 |
| secrecy | 警戒与暴露限制 |
| delivery | 收集与交付 |
| efficiency | 时间与效率 |
| personnel_safety | 人员安全 |

条款要求结果或手段，不要求固定职业。职业和能力只通过相关 check 影响任务。

## 3. 重要程度

### mandatory

满足或违反都可以产生报酬、提出方关系、价值观和结果标签；违反时可以通过 `breach_result_cap` 限制最终合同等级。

### bonus

满足时产生奖励；不满足没有失败效果。Bonus 不得配置结果封顶。

## 4. 数据结构

```text
ContractClauseDefinition
- id: StringName
- display_name_key: StringName
- description_key: StringName
- category: StringName
- importance: StringName
- all_conditions: Array[TraceCondition]
- success_effects: Array[ContractEffect]
- failure_effects: Array[ContractEffect]
- breach_result_cap: StringName
- success_ideology_impact: IdeologyVector
- failure_ideology_impact: IdeologyVector
- success_tags: Array[StringName]
- failure_tags: Array[StringName]
- priority: int
```

V0.1 不包含 `evaluation_phase`、`visibility` 或 `required_information_id`。所有条款均公开，priority 只用于稳定求值和原因顺序。

## 5. 条件白名单

| condition type | 读取来源 |
|---|---|
| selected_supply_tag_present / absent | ContractPlanState |
| approach_is | ContractPlanState |
| method_tag_used / not_used | ResolutionTrace |
| outcome_tag_present / absent | ResolutionTrace |
| check_tier_gte / lte | CheckResult |
| context_gte / lte | final MissionContext |
| member_heavy_injury_count_lte | 待应用成员结果 |

只支持 `all_conditions`。OR 语义通过 check 产生统一 outcome tag，或拆为多个独立条款。

`protected_civilians` 和 `collected_resources` 直接使用 `context_gte/lte`，不定义别名条件。条款不得读取待应用世界钟 delta；需要评价附带损失时，使用 `collateral_pressure` 或 CheckOutcome 产生的明确标签。

## 6. 效果白名单

| effect type | 说明 |
|---|---|
| modify_reward_percent | 修改锁定报酬百分比 |
| modify_sponsor_relation | 修改提出方关系 |
| add_outcome_tag | 添加语义结果标签 |

结果封顶使用独立 `breach_result_cap` 字段；价值反馈使用 success/failure ideology impact 字段。

V0.1 不提供：

- flat reward：内容统一使用百分比。
- 直接成员士气或成员关系效果：统一由任务后价值观评价产生。
- add_message：消息从 ClauseResult 自动投影。
- unlock_followup_contract：由 outcome tag 与 SituationRule 解锁。
- 世界钟效果：由 CheckOutcome 或 ContractOutcomeTable 负责。

## 7. 英雄对接

```text
公开合同目标和条款
→ 任务前 Attitude 预览
→ 玩家选择四名英雄、补给和 Approach
→ 四个阶段 check 生成实际手段、上下文和结果标签
→ ContractResolver 内部条款求值读取完整 ResolutionTrace
→ 产生报酬、提出方关系、封顶、价值影响和结果标签
→ 统一任务后成员评价
```

英雄不为条款单独投骰。保护目标、控制附带损失、使用规定手段和携带补给都必须通过已有 check、MissionContext 或标签体现。

## 8. 求值顺序

```text
1. 锁定 ContractPlan，并生成条款预览
2. 依序完成四个阶段 check
3. 计算未封顶 contract_score、初始 result_tier 和 check failure caps
4. 按 priority、稳定 clause ID 求值所有条款一次
5. 汇总 mandatory breach caps，使用最严格等级
6. 读取最终 ContractOutcomeTable
7. 计算报酬并汇总 outcome tags 与 ideology impacts
8. 运行成员事后评价和提出方关系结算
9. 将待应用效果交给周末原子事务
```

同一行为可以影响多个条款，效果全部叠加，每个来源保留独立 ReasonEntry。同一条款实例不得重复求值。

## 9. 数值边界

```text
clause_reward_percent_delta = clamp(
    sum(clause reward percent effects),
    -100,
    100
)

reward_percent = max(0, 100 + clause_reward_percent_delta)

final_reward = round(
    offered_reward
    * final_tier_reward_multiplier
    * reward_percent / 100
)

final_reward = max(0, final_reward)
```

提出方关系：

```text
sponsor_relation_delta = clamp(
    ContractOutcomeTable.sponsor_relation_delta
    + sum(clause sponsor relation effects),
    -20,
    20
)
```

V0.1 不计算其他阵营对合同的关系反应。

## 10. 价值观

- 所有公开条款进入任务前预期认可度。
- 满足时累计 success ideology impact；违反时累计 failure ideology impact。
- 实际 method tags 独立参与任务后评价，同一 tag 每份合同只计算一次。
- CheckOutcome 与条款 ideology impact 按维度累加后裁剪到 -10 至 +10。
- 条款不得通过直接士气效果重复计算价值反馈。

## 11. UI

规划界面按 Mandatory、Bonus 分组显示：

- 条款文本和类别。
- 当前计划可判断的满足、违反或未知状态。
- 相关 check 和主要能力。
- 可预见的报酬、关系和结果封顶。
- 最多两个成员价值观警告。

结算界面显示证据、满足与否、数值效果和原因。

## 12. 验证与测试

- category、importance、condition 和 effect 都在白名单。
- 所有条款公开，不存在 visibility、情报或隐藏条款字段。
- Bonus 没有 failure effects 或 breach cap。
- planning 预览只读取 ContractPlan；正式求值只读取锁定计划和 ResolutionTrace。
- 条款不引用职业 ID、世界钟 delta 或 UI。
- 多个封顶取最严格等级。
- 同一 Trace 产生相同 ClauseResult、报酬、提出方关系和原因顺序。
- 条款消息由结果投影，后续合同由标签与局势规则解锁。
