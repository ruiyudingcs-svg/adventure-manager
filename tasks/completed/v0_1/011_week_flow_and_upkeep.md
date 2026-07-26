# Task 011 — Weekly Upkeep and Week Flow Coordination

状态：Completed（2026-07-24）
里程碑：Milestone 3（完整 headless 周循环）
依赖：Task 007—010、Gate D

## Goal

实现 WeeklyUpkeepResolver 和 WeekFlowCoordinator，把周开始、玩家合同、阵营行动、
旧 Offer 生命周期和 SituationResolver 组合为两个可重试的原子事务。Coordinator
只协调既有服务，不复制合同、阵营、世界或维护公式。

## Gate D — Accepted upkeep policy

Gate D 已于 2026-07-24 Accepted，权威规则见
`docs/rules/campaign/20_weekly_upkeep_and_history_rules.md`。实现必须使用其中固定的：

- 全员工资 + 25 基础维护 + 轻伤 10/重伤 20 的自动治疗费；
- 强制维护不足时 Gold 归零、全员 morale -5、reputation -5，且不创建负债；
- 未出勤成员 fatigue -20；
- 伤势在恢复倒计时归零前保持不变，归零当周清零并恢复 available；
- 连续派遣/冷落计数封顶 3；
- morale 与成员关系没有自然漂移。

不得使用临时常数、零值 placeholder 或自行增加按缺口比例变化的规则。

## Required reading

- 根目录 `AGENTS.md`
- `docs/product/01_v0.1_product_spec.md` 第 4、6 节
- `docs/rules/02_core_loop_and_rules.md` 第 2、9、10.4、12—14 节
- `docs/architecture/03_godot_architecture.md` 第 5、7—8、12—16 节
- `docs/architecture/04_data_model.md` 第 3、4.1—4.5、4.10 节
- `docs/rules/campaign/13_unhandled_contract_and_npc_results.md`
- `docs/rules/campaign/14_week_flow_faction_commitments_and_messages.md`
- `docs/rules/contracts/15_staged_contract_resolution_rules.md` 第 8 节
- `docs/rules/campaign/19_content_catalog_state_and_situation_rules.md` 第 5—7 节
- `docs/rules/campaign/20_weekly_upkeep_and_history_rules.md`
- Task 007—010 的实际 projector/result API

## Existing API contradiction to resolve

当前 `SituationResolver.resolve()` 在一个调用内依次执行 passive、问题期限、触发器、
问题转移和结局；Accepted 周开始顺序要求在“问题期限”之后、“触发器”之前处理
旧 Offer 生命周期。Task 011 必须在不改变单批触发器语义的前提下把 Resolver
拆成可组合阶段：

```text
resolve_week_start_prelude(...)
→ passive + problem deadline operations

resolve_after_base_operations(...)
→ one trigger batch + problem transitions + ending + urgency
```

兼容入口 `resolve()` 应继续支持 Task 008 的完整单次边界用法，并由上述阶段组合，
现有 Task 008 测试不得删除或放宽。

Coordinator 在临时深副本上：

1. 预览 upkeep 与 week-start prelude。
2. 让 Offer lifecycle 读取期限结算后的临时状态。
3. 把 lifecycle world effects 交给 post-base resolver。
4. 最终把全部 operations 对原始状态只运行一次 CampaignTransaction。

预览结果不得成为正式提交，也不得产生消息或修改输入。

## Allowed files

- `game/domain/simulation/weekly_upkeep_resolver.gd`
- `game/domain/simulation/week_flow_coordinator.gd`
- `game/domain/simulation/situation_resolver.gd`
- `game/domain/campaign/campaign_state.gd`
- `game/domain/campaign/campaign_history_query.gd`
- `game/domain/campaign/weekly_participation_snapshot.gd`
- `game/domain/simulation/campaign_transaction.gd`
- 周开场/周末 request/result 值对象
- Task 011 对应 tests/fixtures 和 `tests/run_all.gd`

只允许为组合真实 API 对 Task 007—010 service/result 做窄幅修复。不得创建
GameSession、MessageState、UI 或存档序列化。

## WeeklyUpkeepResolver

公开入口：

```text
resolve(
    current_week,
    campaign_state,
    adventurer_definitions,
    previous_week_participation
)
    -> WeeklyUpkeepResult
```

Result 只包含 StateOperation、ReasonEntry 和 issues。必须：

- 工资读取所有八名当前成员 Definition.wage，稳定 member ID 顺序。
- 基础维护读取 GuildState.weekly_maintenance。
- 疲劳、伤势、恢复、availability、morale、关系和近期计数严格使用 Gate D。
- 每个非零变化有独立 reason；同字段多来源交给 CampaignTransaction 合并。
- 不读取合同历史、Offer、合同 Definition、问题、阵营 agenda 或 UI。
- 只使用 Coordinator 传入的 `WeeklyParticipationSnapshot` 判断上一周出勤。
- 不原地修改 State/Definition。

## Campaign history query

`CampaignState.contract_history` 与 `ContractHistoryEntry` 保持合同和成员参与历史的唯一
权威来源。新增的 `CampaignHistoryQuery` 只读查询上一周已提交的玩家 resolved
记录，并返回稳定排序、去重的 `WeeklyParticipationSnapshot`。它不是新的状态所有者
或第八个领域服务，不保存出勤缓存。

不得创建第二份成员出勤历史。declined、expired、npc_completed、escalated 和阵营
行动不算成员出勤；同一周存在多份玩家 resolved 合同必须返回 issue。

## WeekFlowCoordinator public API

```text
open_week(request) -> WeekOpeningResult
resolve_week(request) -> WeekResolution
```

Result 在 Task 012 前保存 typed source results、operations、state_changes、reasons、
new_state 和 issues；`generated_messages` 由 Task 012 后续补入。

### 1. New campaign

第 1 周直接使用 Definition 初值和初始化 State，不运行 upkeep、passive 或旧
Offer 生命周期。初始三栏由 Task 010 对第 1 周规划快照运行一次产生。

### 2. Open week N, N >= 2

固定顺序：

```text
1. week_started(N)
2. CampaignHistoryQuery projects participation for N - 1
3. WeeklyUpkeepResolver consumes the participation snapshot
4. SituationResolver week-start prelude
5. ContractOfferService lifecycle
6. SituationResolver post-base one trigger batch / transitions / ending
7. CampaignTransaction.apply once on the internal working copy
8. if not ended: FactionTurnPlanner.plan_week and apply its operations to that copy
9. return frozen planning snapshot and typed results
```

Coordinator 可以使用两个 CampaignTransaction 结果作为内部预览：第一批确定
本周世界快照，第二批只创建 Offer/行动承诺并预留 influence。但两批共同构成一个
周开始命令；第二批失败时不得向调用方暴露第一批 new_state。GameSession 尚未
实现，因此 Coordinator 只在全部成功后返回最终新状态和合并审计。

若第 5 步选出结局，不运行第 7 步。

### 3. Resolve current week

输入要么包含一份 accepted Offer + active plan，要么明确选择不接合同。固定顺序：

```text
1. validate and resolve player contract, producing ContractResolution
2. project ContractResolution to base StateOperation
3. resolve all committed faction actions from the same planning snapshot
4. combine contract/action base operations
5. SituationResolver post-base one trigger batch / transitions / ending
6. CampaignTransaction.apply once to the pre-week-end CampaignState
7. mark accepted Offer resolved and active plan cleared in the same batch
8. only after success return WeekResolution
```

- 合同和行动都不能读取对方尚未提交的结果重新计算。
- ContractResolver 只运行一次；重试复用同一 locked seed 和 inputs。
- 补给成本、报酬、成员、提出方、世界效果、行动事件、Offer/history 状态必须
  全部提交或全部失败。
- 周末不应用 passive，不增加 week_index；进入下一周由下一次 `open_week(N+1)`
  完成。

## Validation and atomicity

- CampaignState 增加 `week_index` operation dispatch；只允许 Coordinator 推进。
- `open_week(N)` 必须满足 `N == state.week_index + 1`。
- `resolve_week` 必须匹配当前 week，且不能重复结算已 resolved Offer/commitment。
- 事务成功前不创建 MessageState。
- 任一 Definition 缺失、非法状态转移、冲突 set、历史/伤病状态不一致或 Resolver
  issue 均清空 new_state/state_changes。
- 强制周维护余额不足使用 Gate D 紧缩分支并正常提交；只有周末可选补给余额不足
  才使周末事务失败。
- 输入状态、Definition、Offer snapshot、plan 和 ContractResolution 均不变。

## Focused tests

至少覆盖：

1. 第 1 周不运行 upkeep/passive；进入第 2 周恰好一次。
2. 工资、维护和所有 Gate D 边界值与 reason。
3. 强制维护余额不足提交紧缩后果，周末补给余额不足仍完整回滚。
4. 问题期限先于 Offer 生命周期；Offer 生命周期效果先于触发器。
5. lifecycle 新满足的 trigger 进入本边界唯一批次；trigger 产生的新 trigger 不递归。
6. 结局产生后不创建新 Offer 或行动。
7. 三个空栏恢复与已有 pending 阵营行动预告来自同一冻结快照。
8. 玩家合同与全部 committed 行动同批提交或同批回滚。
9. reward/supply/member/relation/world/action event 各应用一次。
10. 不接合同时 committed 行动和世界仍正常推进。
11. 重试同一 week-end request 得到相同 ContractResolution、状态和原因。
12. `resolve()` 兼容入口继续通过 Task 008 全部测试。
13. 10 周纯 headless fixture 无场景树运行且每周边界顺序可审计。

## Out of scope

- Gate D 数值的自行修改
- MessageState 创建
- GameSession 正式状态持有和 signals
- UI、SaveService、自动治疗市场或负债框架

## Acceptance tests

先运行 upkeep/history-query/week-flow focused tests、Task 008 回归测试和周循环
integration tests，再运行完整 suite。

## Completion checklist

- [x] Gate D 已 Accepted；实现不得使用 placeholder 数值。
- [x] 历史查询生成冻结参与快照，Upkeep 不解析 ContractHistoryEntry。
- [x] SituationResolver 拆分保留单批、非递归和兼容入口。
- [x] 周开始与周末顺序和两个事务边界准确。
- [x] 合同/行动读取同一规划快照。
- [x] 任一失败没有部分状态、历史或消息。
- [x] 10 周 headless fixture 与 full suite 实际运行。

完成证据：

- `test_weekly_upkeep.gd` 覆盖工资 98、维护 25、治疗 10/20、固定紧缩、
  出勤/休息、伤病恢复、近期计数、非法伤病和确定性。
- `test_week_flow_coordinator.gd` 覆盖首周、期限先于生命周期、冻结规划快照、
  合同与行动同批提交、补给不足回滚、重试和 10 周纯 headless 循环。
- Task 008 `resolve()` 兼容回归继续通过；focused 为 25 passed / 0 failed，
  full suite 为 153 passed / 0 failed。

## Expected report

- Gate D 引用和实际数值行为
- SituationResolver API 重构及 Task 008 回归证据
- 周开始/周末调用顺序和事务边界
- 10 周 headless trace 摘要
- focused/full 测试结果
- Task 012 可投影的 typed source result 清单
