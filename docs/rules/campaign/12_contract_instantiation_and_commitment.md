# Offer 实例化、拒绝与提出方承诺 V0.1

状态：Accepted（简化修订）  
日期：2026-07-20

## 1. 目的与边界

Offer 实例化只负责把当前世界状态转成少量、可锁定的合同数值：

- check 难度修正。
- 初始 MissionContext。
- 玩家可理解的原因。

V0.1 不允许实例化改变阶段、check 数量、能力权重、结果权重、条款、结果表或世界效果；不允许启用或关闭可选 check，也不保存规则读取过的完整世界事实。

## 2. OfferInstantiationRule

```text
OfferInstantiationRule
- id: StringName
- all_conditions: Array[OfferBindingCondition]
- effects: Array[OfferInstantiationEffect]
- reason_code: StringName
```

规则只支持 `all_conditions`，按稳定 rule ID 求值，不使用 priority。所有匹配规则都生效；同一字段的数值效果先求和，再统一裁剪。

条件白名单：

- `clock_gte`
- `clock_lte`
- `phase_is`
- `problem_urgency_gte`
- `problem_urgency_lte`
- `problem_age_gte`
- `problem_remaining_turns_lte`
- `problem_is_active`
- `world_event_occurred`
- `origin_type_is`

条件不得读取队伍、成员、金币、补给、阵营关系、UI 或任意字段路径。Followup 与 Agenda 来源没有运行时关联问题，所有读取问题字段的条件为 false。

效果白名单：

- `add_check_difficulty`
- `add_initial_context`

边界：

- 单条 check 难度修正为 -10 至 +10，同一 check 汇总到 -20 至 +20。
- 单条初始上下文修正为 -3 至 +3，同一 key 的 delta 汇总到 -6 至 +6。
- 初始上下文以 0 为默认值，应用全部 delta 后裁剪到 0 至 10。
- 每个非零效果必须有 ReasonEntry；不再提供独立 `add_forecast_reason` 效果。

## 3. 最小锁定快照

```text
ContractInstantiationSnapshot
- evaluated_week: int
- check_difficulty_deltas: Array[CheckDifficultyBinding]
- initial_context: MissionContext
- reason_entries: Array[ReasonEntry]
```

快照只保存结算真正需要的最终 overlay 和原因，不保存：

- `source_rule_ids`
- `world_fact_snapshots`
- optional check availability
- forecast reason codes

Offer 历史已经保存来源、问题、周数和生成原因，足以解释为何出现。无需为了未来审计复制一份局势事实图。

相同模板和相同规划快照必须产生相同 `ContractInstantiationSnapshot` 及原因顺序。
Offer 还必须锁定 `sponsor_relation_snapshot` 精确值（-100 至 100）及关系档位
`standard`、`favorable` 或 `trusted`。前者供认可度预测和正式结算使用，后者
只解释期限与报酬修正；二者均不得在 Offer 创建后重读或重算。

## 4. Effective Contract 与预测

接受合同后使用：

```text
ContractDefinition
+ ContractInstantiationSnapshot
+ ContractPlanState
+ detached ContractClauseDefinition / MethodTagDefinition
→ effective contract
```

预测和正式结算必须构造同一 effective contract。预测只能显示：

- 主要能力优势和缺口。
- 当前态度风险。
- 初始 MissionContext。
- Approach 对四个 check 的固定修正。
- 条款预览。
- 结果等级区间，不显示精确随机结果。

预测不单独保存成功率、区间或修正。Offer 创建后的世界变化不改变锁定难度、上下文、报酬、期限或 seed。

## 5. 玩家拒绝

- 每周最多拒绝一份 `pending` Offer。
- 拒绝后状态变为 `declined`，当周合同栏保留 disabled 占位卡。
- 当周不补位；下一周开始的同一原子事务中归档 declined 记录，并由同一阵营重新提出。
- 拒绝不改变阵营关系、世界钟、问题或 influence。
- 相同合同定义、来源、问题和 target lock 组合在该阵营下一次选择时优先排除一次；没有其他合法候选时允许复用，避免产生空栏。
- 如果当前未确认计划引用该 Offer，拒绝命令同时清除该计划。

V0.1 没有接受后取消，也没有提出方主动撤回。

归档 declined Offer 时，`ContractOfferService` 把上述组合键作为仅供本次周开始规划使用的临时抑制项传给 `FactionTurnPlanner`；规划器先尝试其他合法候选，若没有则复用该组合并记录 `declined_offer_reused_no_alternative`。完成该阵营的一次选择后即消费抑制项。它不成为新的长期 CampaignState，也不会跨过下一次提案生成继续生效。

## 6. Pending 承诺

每个阵营最多一份 pending Offer。它直接表示该阵营正在等待玩家回应，不建立独立 ContractCommitmentState。

pending Offer：

- 占用提出方唯一合同栏。
- 锁定自己的 `target_lock_key`。
- 阻止所有阵营创建相同 target lock 的新 Offer 或直接行动。
- 不阻止提出方在随后一周对其他目标采取直接行动。

V0.1 不处理第三方在 pending 期间提前完成、取消或间接解决合同。Offer 只通过 accepted、declined 或周开始的过期生命周期离开 pending。

## 7. 状态流转

```text
pending → accepted → resolved
pending → declined
pending → expired
pending → npc_completed
pending → escalated
```

不存在 `cancelled`、`abandoned` 或 `npc_failed`。同一 Offer 只能进入一个终止状态。

## 8. ContractOfferService

一个 `ContractOfferService` 负责：

- 为阵营入选模板创建 Offer 和最小实例化快照。
- 计算关系修正后的锁定报酬与期限。
- 派生稳定 Offer ID 和合同结算 seed。
- 处理玩家拒绝和接受命令。
- 在周开始处理 declined 归档与 pending 到期。

预测是该服务的纯查询函数，不创建第二个顶层 Evaluator。未处理结果继续调用 `docs/rules/campaign/13_unhandled_contract_and_npc_results.md` 的固定策略，不在 Offer 服务中复制 NPC 行动或恶化公式。

## 9. 验证与测试

CatalogValidator 必须检查：

- 实例化规则只使用白名单条件和两种数值效果。
- 规则不引用队伍、成员、金币、补给或阵营关系。
- 每份合同恰好四个 check，不存在 optional toggle。
- 修正引用的 check 和 MissionContext key 有效。
- 快照不包含源规则、世界事实、预测或可选判定字段。
- 状态白名单不包含 cancelled。

自动测试至少覆盖：

- 多条难度和上下文修正先求和后裁剪。
- 相同输入产生相同快照、Offer ID、seed 和原因顺序。
- Offer 创建后的世界变化不改写快照。
- 每周最多拒绝一份，拒绝无世界和关系效果且当周不补位。
- 拒绝后的下一次生成有替代项时避开原组合，无替代项时复用且不留下空栏。
- pending Offer 锁定精确 target lock，但提出方下一周可以处理其他目标。
- 存档往返保留快照、状态、报酬、期限、seed 和原因。
