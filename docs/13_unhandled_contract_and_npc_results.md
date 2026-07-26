# 未处理合同与 NPC 结果规范 V0.1

状态：Accepted（简化修订）  
日期：2026-07-24

## 1. 目的与边界

本文固定合同越过最后可接受周后的终止规则，对应 TODO 12 与 TODO 13。目标是让 `expired`、`npc_completed` 和 `escalated` 简单、确定、可解释，同时复用现有阵营行动与世界问题数据。

本文明确不处理或不引入：

- 未处理结果的条件数组、优先级竞争或随机抽取。
- NPC 英雄、NPC 队伍、四阶段判定、条款或伤病模拟。
- `npc_failed`、提出方撤回或第三方在 pending 期间提前完成合同。
- 在合同内复制阵营行动效果或世界问题恶化效果。
- 常规阵营行动承诺；其 target lock 排他与延迟结算由 `docs/14_week_flow_faction_commitments_and_messages.md` 处理。

## 2. 合同数据

每份 `ContractDefinition` 只增加两个未处理字段：

```text
unhandled_policy: StringName
npc_completion_action_id: StringName
```

策略白名单与固定分支：

| unhandled_policy | NPC 行动可执行 | NPC 行动不可执行 | 用途 |
|---|---|---|---|
| `expire` | `expired` | `expired` | 机会自然消失 |
| `npc_or_expire` | `npc_completed` | `expired` | 提出方可自行处理，否则放弃 |
| `npc_or_escalate` | `npc_completed` | `escalated` | 提出方可兜底，否则问题恶化 |
| `escalate` | `escalated` | `escalated` | 无人处理必然恶化 |

配置约束：

- `npc_or_expire`、`npc_or_escalate` 必须引用提出方 `weekly_action_ids` 中已有的 `FactionActionDefinition`。
- `expire`、`escalate` 的 `npc_completion_action_id` 必须为空。
- `npc_or_escalate`、`escalate` 的 ContractDefinition 必须有模板问题锚点。
- Followup 与 Agenda 来源 Offer 的运行时问题 ID 为空；NPC 路径仍可执行，但任何 `escalated` 后备结果都降为 `expired`。
- NPC 行动与合同必须使用相同 `target_lock_key`，表示提出方到期后改为自行完成同一个具体目标。

## 3. 触发条件与稳定顺序

生命周期服务只处理：

```text
offer.status == pending
and current_week > offer.expires_week
```

最后有效周仍可由玩家接受。服务不能读取界面显示的 `remaining_turns` 判断到期。

同周需要处理多份 Offer 时，按以下升序排序：

1. `expires_week`
2. `offered_week`
3. `instance_id`

每份 Offer 都读取前一份结果已经写入的临时工作状态。因此第一份 Offer 解决或恶化某个问题后，后续关联同一问题的 Offer 会看到问题不再 active，并自然过期。排序和判断都不使用随机种子。

## 4. 固定结算算法

对每份到期 Offer 依次执行：

1. 再次验证 Offer 仍为 pending 且已越过 `expires_week`。
2. 如果 Offer 有 `related_problem_id`，但问题状态不是 `active`，结果固定为 `expired`。
3. 读取 ContractDefinition 的 `unhandled_policy`。
4. 如果策略允许 NPC 完成，按第5节判断引用行动是否可执行；可执行则进入 `npc_completed`。
5. NPC 行动不可执行时，采用策略表中的固定后备结果。
6. 后备结果为 `escalated` 时，再验证关联问题仍为 active；否则降为 `expired`。
7. 生成 Offer 终止变更、历史、消息、原因和必要的世界效果计划。
8. 全部到期 Offer 都成功完成引用与边界验证后，一次性提交整批状态变化。

这里没有“比较哪个结果优先”，策略已经给出唯一分支。也没有“NPC 尝试失败”：条件不满足只表示 NPC 路径不可执行，然后进入合同预先声明的后备结果。

## 5. NPC 完成

NPC 完成只复用 `npc_completion_action_id` 指向的 `FactionActionDefinition`。行动可执行需要同时满足：

- 行动存在且属于提出方。
- 行动 `target_lock_key` 与 Offer 相同。
- 行动的全部 `conditions` 在当前临时工作状态成立。
- 提出方当前 `influence >= influence_cost`。
- 若 Offer 关联世界问题，该问题仍为 active。

Agenda 适配分数和问题难度不另行参与 NPC 成败。若某项世界限制确实必要，它必须已经写入该行动的结构化 `conditions`，不能由生命周期服务增加隐藏公式。

Offer 已经越过有效期，结算时先视为释放它自身派生的提出方承诺锁，再检查该行动；不能让刚到期 Offer 用自己的 target lock 阻止自己的 NPC 完成分支。其他仍为 pending 的同目标承诺锁依然有效。

可执行时：

1. Offer 进入 `npc_completed`。
2. 提出方扣除该行动的 `influence_cost`。
3. 应用行动已有的 `effects`。
4. 使用行动已有的 `event_key` 创建一个世界事件。
5. 写入合同历史、消息请求和完整原因记录；MessageState 由 `WeeklyMessageProjector` 创建。

NPC 完成不占用本周一次直接行动承诺容量；它是周开始时上一份合同承诺到期后的生命周期结算。它先于本周规划快照发生，可以影响随后生成的行动承诺和合同。它也不支付玩家报酬、不改变公会与阵营关系、不产生英雄疲劳或伤病，不读取合同 check、条款、MissionContext、队伍、补给或行动倾向。

## 6. 问题恶化与自然过期

### 6.1 escalated

`escalated` 只复用关联 `WorldProblemDefinition.escalation_effects`：

1. 验证问题仍为 active。
2. 应用 `escalation_effects`。
3. 把 `WorldProblemState.status` 置为 `escalated`，记录关闭周与原因。
4. 记录 `escalation_effects` 中 `create_world_event` 已创建的恶化事件，不再额外创建第二份事件。
5. Offer 进入 `escalated`，写入历史、消息和原因。

如果问题已因自身 `response_deadline_week` 或其他规则恶化、解决或关闭，本次 Offer 只能进入 `expired`，不得再次应用恶化效果。

### 6.2 expired

`expired` 表示该委托机会结束，但本次到期本身不再改变世界。它：

- 释放提出方目标锁。
- 写入合同历史、消息请求和原因记录。
- 不扣 influence，不应用世界效果，不创建世界事件。

世界仍可通过问题自己的期限、被动变化和其他阵营行动继续推进；这些变化由各自系统负责，不伪装成合同过期效果。

## 7. 结果记录

| 终止状态 | ContractHistoryEntry | 玩家消息 | ReasonEntry | WorldEventState | 效果来源 |
|---|---:|---:|---:|---:|---|
| `expired` | 是 | 是 | 是 | 否 | 无即时效果 |
| `npc_completed` | 是 | 是 | 是 | 是 | `FactionActionDefinition` |
| `escalated` | 是 | 是 | 是 | 是 | `WorldProblemDefinition.escalation_effects` |

建议基础原因码：

- `offer_expired_by_policy`
- `offer_expired_problem_inactive`
- `npc_completion_action_executed`
- `npc_completion_action_missing_conditions`
- `npc_completion_insufficient_influence`
- `offer_escalated_by_policy`
- `offer_escalation_skipped_problem_inactive`

每个实际数值变化仍需要独立 `ReasonEntry`。玩家消息可以概括原因，但不能作为权威规则输入。

## 8. 原子应用与确定性

`ContractOfferService` 先在临时工作状态上生成一批待应用变化。任一 Offer 出现缺失引用、越界数值或非法状态转移时，整批拒绝提交并返回开发期错误；不能只应用前半批。

相同 CampaignState 和相同静态定义必须得到相同的：

- Offer 处理顺序。
- 终止状态。
- influence 与世界钟变化。
- 世界事件 ID 和顺序。
- 合同历史、消息和原因顺序。

未处理结算不读取或消耗随机数，因此 seed 不影响结果。

领域入口固定为：

```text
resolve_unhandled_offers(
    base_state,
    current_week,
    contract_definitions,
    faction_definitions,
    action_definitions,
    problem_definitions
) -> UnhandledLifecycleResult
```

Result 返回完整 operations、终止 Offer、历史、世界事件、原因、StateChange 和
成功后的 detached CampaignState。NPC 行动事件 ID 使用
`offer_instance_id + "_" + event_key`；问题恶化中的每个既有
`create_world_event` 也使用同一 Offer ID 作为来源前缀。任一引用或事务失败时，
Result 不返回部分 operations 或新状态。

## 9. 基准配置

三份完整基准合同都使用 `npc_or_escalate`：

| 合同 | npc_completion_action_id | NPC 成本与效果 |
|---|---|---|
| `contract_north_road_evacuation` | `action_free_alliance_evacuate_north_road` | influence -8；villagers_evacuated +10；settlement_destruction +8 |
| `contract_deploy_binding_towers` | `action_arcane_guild_deploy_binding_towers` | influence -10；capture_preparation +8；settlement_destruction +4 |
| `contract_recover_intact_corpses` | `action_necrotic_collective_recover_corpses` | influence -6；necrotic_corruption +12 |

三项行动的条件与事件键由对应 `FactionActionDefinition` 保存；关联问题的恶化分支由对应 `WorldProblemDefinition.escalation_effects` 保存。合同本身不重复这些 effects。

## 10. 验证与测试

CatalogValidator 必须检查：

- 策略属于四值白名单。
- NPC 策略的行动引用存在、属于提出方且 target lock 相同。
- 非 NPC 策略不携带行动引用。
- 恶化策略的模板存在问题锚点，followup 或 agenda 来源 Offer 运行时无问题锚点时不会应用恶化效果。
- 行动和世界问题效果中的所有目标与事件引用合法。

自动测试至少覆盖：

- 最后有效周仍 pending，下一周才进入未处理结算。
- 四种策略的所有可执行与不可执行分支。
- influence 恰好等于成本时 NPC 可完成，少 1 时走后备分支。
- NPC 完成不运行 ContractResolver，也不改变玩家报酬、关系、英雄状态或本周行动承诺容量。
- 已 resolved、escalated 或 closed 的问题使到期 Offer 自然过期。
- 同周两个 Offer 关联同一问题时只应用一次解决或恶化效果。
- 任一计划验证失败时 CampaignState 完全不变。
- 存档往返后得到相同终止状态、事件和原因顺序。

## 11. TODO 对应关系

- TODO 12：第2至4节、第6至8节。
- TODO 13：第5节、第9至10节。
