# 周流程、阵营行动承诺与消息规范 V0.1

状态：Accepted（简化修订）  
日期：2026-07-24

## 1. 核心决定

合同和常规阵营行动读取同一周规划快照，均在玩家结束本周时产生效果。每个阵营每周只进入一种模式：

- 没有 pending Offer：提出一份合同，不创建直接行动。
- 已有 pending Offer：保留合同，并可以承诺一项不同 target lock 的直接行动。

V0.1 不模拟 NPC 行动之间的谈判、抢先或战斗。所有 Offer 与行动只使用精确 `target_lock_key` 排他。规划器先补齐空合同栏，再安排直接行动；每一遍都按稳定阵营 ID 顺序选择，遇到已经占用的 target lock 就尝试下一合法候选，没有合法候选则等待。

## 2. 周开始与规划快照

新战役直接初始化为第 1 周规划快照，使用局势定义的初值，不额外执行一次周开始被动变化。以下完整周开始流程从第 1 周结束、进入第 2 周时开始执行；之后每个周边界恰好执行一次。

进入第 N 周规划前：

```text
1. week_started(N)
2. pay_wages_and_maintenance
3. recover_fatigue_and_injuries
4. update_morale_and_relationship_decay
5. apply_situation_passive_progress
6. settle_problem_deadlines
7. resolve_old_contract_offer_lifecycle
8. evaluate_one_trigger_batch
9. evaluate_problem_urgency
10. freeze_week_planning_snapshot
```

步骤 2 前，`WeekFlowCoordinator` 通过只读 `CampaignHistoryQuery` 从已提交历史
生成第 `N - 1` 周的 `WeeklyParticipationSnapshot`，并显式传给
`WeeklyUpkeepResolver`。Upkeep 不读取 `ContractHistoryEntry`；合同历史保持参与
记录的唯一权威来源。工资、治疗、恢复和资金不足的数值见
`docs/20_weekly_upkeep_and_history_rules.md`。

问题期限先于旧 Offer 到期。问题已关闭时，关联 Offer 只自然过期，不重复应用问题后果。任一步进入结局后停止创建新 Offer 与行动承诺。

步骤 8 只检查一次当前合格触发器集合；本批触发器产生的新条件留到下一周或周末边界，不递归运行到稳定。

## 3. FactionTurnPlanner

所有阵营读取同一个只读快照。先根据快照中的 pending 状态锁定各自模式，再执行两遍选择：

```text
for faction without pending Offer in stable_faction_id_order:
    choose highest-priority legal contract
    create Offer and reserve its target lock

for faction with pending Offer in stable_faction_id_order:
    choose highest-priority legal direct action
    reserve its target lock and influence
```

合同与行动优先级都使用：

```text
intent_priority = base_priority
                + urgency_contribution
                + agenda_fit
                - repeat_penalty
```

完全同分按 Definition ID 升序。合同提案遍次先于直接行动遍次，因此行动不能占掉本周应生成的合同目标。规划阶段不使用随机数，不修改世界状态。

## 4. 阵营行动承诺

```text
FactionActionCommitmentState
- instance_id: StringName
- faction_id: StringName
- action_definition_id: StringName
- target_problem_id: StringName
- target_lock_key: StringName
- committed_week: int
- resolves_at_week: int
- reserved_influence: int
- commitment_reason_entries: Array[ReasonEntry]
- status: StringName
- resolved_week: int
- world_event_ids: Array[StringName]
```

`resolves_at_week = committed_week + 1`，表示结束 committed week 时应用。状态只有 `committed` 和 `resolved`。

创建承诺时立即从 FactionState 预留并扣除 influence。承诺没有竞争、退出或退款分支；只要周末事务验证成功，行动就应用预制世界效果和事件，并进入 resolved，先前预留的 influence 不重复扣除。

行动创建后不重新检查 Agenda 或优先级。它和玩家合同视为同期发生，均不能读取对方尚未提交的结果重新计算成功率或资格。

承诺与事件身份固定为：

```text
commitment_instance_id = "faction_action_" + lower_hex8(
    StableSeed.derive(
        0,
        ["faction_action_commitment", committed_week, faction_id,
         action_definition_id, target_problem_id, target_lock_key]
    )
)

action_event_instance_id = commitment_instance_id + "_" + event_key
```

`FactionTurnPlanner.resolve_commitments(base_state, current_week,
action_definitions)` 只投影
`status == committed && resolves_at_week == current_week + 1` 的条目，返回供
Task011 与玩家合同效果合并的 operations。调用方先把周索引推进到
`resolves_at_week`，再原子应用整批；结算不再次扣除或退还 influence。

## 5. Target lock

以下对象共享同一个精确 target lock 集合：

- 所有 pending Offer。
- 本周新 Offer。
- 本周直接行动承诺。

规则：

- 同一个 key 只能被一个对象占用。
- 同一 WorldProblemState 的不同 target lock 可以同时处理。
- 不同 target lock 的内容效果必须可以合并，不得直接写入互斥的问题终态；问题最终转移由合并后的 `SituationResolver` 统一决定。
- 不定义 objective group、objective stance、NPC 阵营关系或冲突模式。
- 没有合法非冲突目标时，阵营等待并记录原因。

这意味着 V0.1 不表现“两个阵营争夺同一个精确目标”。如果后续版本需要谈判、抢先或冲突，应作为独立扩展，不隐藏在合同生命周期中。

## 6. 玩家结束本周

玩家确认合同计划或选择不接合同时，执行不可中断的周末事务：

```text
1. 结算玩家合同，生成待应用效果
2. 结算全部 committed 阵营行动，生成待应用效果
3. 合并数值效果、集合请求和状态转移
4. 把基础效果应用到临时 CampaignState
5. 从该临时状态确定一批合格世界触发器并应用一次
6. 结算问题关闭、局势阶段和结局
7. 验证完整临时状态
8. 原子替换正式 CampaignState
9. 投影合同、阵营行动和周总结消息
10. 进入下一周
```

世界触发器不递归。由本批触发器新产生的另一触发条件留到下一次周边界。任一非法引用、矛盾状态写入或无效转移都使整批失败；正式状态、历史和消息保持不变。

## 7. 消息所有权

`WeeklyMessageProjector` 是 `MessageState` 的唯一创建者。其他规则只返回结构化结果或 `MessageRequest`，不得直接修改 `message_history`。

消息时机：

### 周开始

- 工资、恢复和成员警告。
- 被动世界变化、问题期限和旧 Offer 结果。
- 新 Offer 到达。
- 已有 pending 阵营的直接行动预告。

### 玩家命令

- Offer 被拒绝。
- 计划确认失败原因。

### 周末

- 合同结果。
- 阵营行动完成。
- 世界钟、问题、阶段和结局变化。
- 周总结。

相同来源、相同周和相同类别只创建一条稳定消息，存档加载或事务重试不得重复追加。

## 8. ReasonEntry 可见性

V0.1 只保留：

- `player`：可以展示给玩家。
- `debug`：仅用于测试和开发审计。

不使用 `player_if_discovered`、`display_priority` 或 `required_information_id`。玩家原因按规则产生顺序和稳定 reason code 排序；Offer 固定显示一条来源说明和最多两条 player 原因。

玩家可以看到紧迫度等级、响应倒计时、阶段、已发生事件、公开 Agenda 和后续机会。精确 AI 权重、被排除候选和内部 ID 排序只进入 debug。

## 9. MessageState

```text
MessageState
- instance_id: StringName
- week_index: int
- category: StringName
- source_type: StringName
- source_id: StringName
- title_key: StringName
- body_key: StringName
- parameters: Dictionary
- importance: StringName
- sort_order: int
- is_read: bool
```

```text
message_instance_id = stable_id(
    week_index,
    source_type,
    source_id,
    category
)
```

category 白名单：`upkeep`、`world_event`、`contract_offer`、`contract_lifecycle`、`faction_action`、`contract_result`、`week_summary`。importance 白名单：`low`、`normal`、`high`、`critical`。

## 10. 服务职责

| 变化 | 负责人 |
|---|---|
| 周流程与事务边界 | `WeekFlowCoordinator` |
| 已提交合同历史到上一周参与快照 | `CampaignHistoryQuery` |
| 工资、治疗、恢复和近期计数 | `WeeklyUpkeepResolver` |
| 问题、世界钟、触发器和结局 | `SituationResolver` |
| 阵营本周模式、合同和直接行动选择 | `FactionTurnPlanner` |
| Offer 创建、命令、预测与生命周期 | `ContractOfferService` |
| 合同阶段、条款、成员和提出方结算 | `ContractResolver` |
| 结果到 MessageState | `WeeklyMessageProjector` |

## 11. 验证与测试

CatalogValidator 必须检查：

- 每个阵营同周只进入一种模式。
- 合同提案遍次先于直接行动遍次。
- 所有 pending Offer、新 Offer 和行动承诺 target lock 唯一。
- 同一问题不同 target lock 的可并发内容不会直接写入互斥终态。
- 行动 influence cost 非负且引用有效世界效果。
- 不存在 objective group、stance、NPC relation 或 conflict mode 字段。
- ReasonEntry 可见性只使用 player 或 debug。

自动测试至少覆盖：

- 没有 pending 的阵营只提出合同，不创建行动。
- 有 pending 的阵营只保留合同并选择不同 target lock 的行动。
- 稳定阵营顺序使 target lock 选择可复现。
- 直接行动不能阻止空合同栏在同周补齐。
- 行动创建时扣除 influence，周末成功后完成且不退款。
- 合同和行动读取同一快照并在一个事务中全部提交或全部拒绝。
- 触发器每个周边界只检查一批，不递归触发。
- 消息只在状态提交后创建且稳定去重。
