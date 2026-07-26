# Task 010 — Faction Turn Planner and Action Commitments

状态：Completed（2026-07-24）
里程碑：Milestone 3（阵营规划）
依赖：Task 008、Task 009

## Goal

实现类型化 FactionActionDefinition、FactionTurnPlanner、行动承诺和完整未处理
Offer 生命周期。三个阵营读取同一规划快照，先补合同栏、后安排直接行动，并通过
精确 target lock、稳定排序和原子 influence 预留产生可存档的本周承诺。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md` 第 7.4—7.7 节
- `docs/02_core_loop_and_rules.md` 第 10.2—10.5、12 节
- `docs/03_godot_architecture.md` 第 5、7—8、12—13 节
- `docs/04_data_model.md` 第 2.8、2.10—2.12、3.8—3.9、4.3—4.4 节
- `docs/11_contract_proposal_generation.md`
- `docs/12_contract_instantiation_and_commitment.md`
- `docs/13_unhandled_contract_and_npc_results.md`
- `docs/14_week_flow_faction_commitments_and_messages.md` 第 1、3—5、10—11 节
- `docs/18_dragon_invasion_problem_and_action_catalog.md` 第 2、5—9 节
- Task 008—009 的实际 urgency、Offer、transaction 和 catalog API

## Allowed files

- `game/domain/factions/faction_action_definition.gd`
- `game/data/definitions/factions/faction_action_definition_resource.gd`
- `game/domain/factions/faction_definition.gd`
- `game/data/definitions/factions/faction_definition_resource.gd`
- `game/domain/factions/faction_action_commitment_state.gd`
- `game/domain/factions/faction_intent_candidate.gd`
- `game/domain/factions/faction_intent_plan.gd`
- `game/domain/simulation/faction_turn_planner.gd`
- Task 009 `contract_offer_service.gd`，仅完成行动相关生命周期
- `game/domain/campaign/campaign_state.gd`
- `game/domain/simulation/campaign_transaction.gd`
- `game/data/catalogs/content_manifest.gd`
- `game/data/catalogs/data_catalog.gd`
- `game/data/catalogs/catalog_validator.gd`
- Task 010 对应 tests/fixtures 和 `tests/run_all.gd`

正式十四项行动 `.tres` 属于 Task 013，本任务只使用测试 Resource/fixture。

## DataCatalog and Definition additions

### 1. FactionActionDefinition

字段严格使用 `docs/04` 第 2.11 节：

```text
id
agenda_tags
target_lock_key
base_intent_priority
urgency_weight
recent_repeat_cooldown
influence_cost
conditions
target_problem_tags
effects
event_key
```

FactionDefinition 继续保存稳定 `weekly_action_ids`，由 DataCatalog 按 ID 查询
detached ActionDefinition。所有权由该列表建立；CatalogValidator 要求每项行动
恰好被一个 faction 引用，不在 ActionDefinition 中保存第二份 owner 字段。

ContentManifest/DataCatalog 增加显式 action 集合、`get_faction_action(id)` 和稳定
`get_all_faction_actions()`。仍然先完整验证再原子发布。

分阶段兼容说明：Task 013 才发布正式十四项行动 `.tres`。因此默认 manifest 的
action 集合在 Task 010 完成时仍为空；一旦 manifest 声明任一 action，validator
立即启用 action owner、`weekly_action_ids` 和 NPC completion 引用的严格双向
校验。Task 013 不得再依赖空集合兼容路径。

### 2. FactionActionCommitmentState

严格使用 `docs/04` 第 3.9 节。必须深复制 reasons/world event IDs，并提供稳定
signature。CampaignState 增加：

```text
faction_action_commitments: Array[FactionActionCommitmentState]
```

只允许 `committed`、`resolved`。同一阵营同一 committed week 最多一项；只有
committed 项参与 target lock 和周末结算。

### 3. Intent result values

FactionIntentCandidate 和 FactionIntentPlan 使用 `docs/04` 第 4.3—4.4 节字段。
它们是纯派生值，不写入 CampaignState。所有不合格原因只保存在调试结果中；
最终入选项保留 player/debug reasons。

## Candidate derivation

### Contract proposals

- 只从当前 faction 的 ContractDefinition 产生。
- 来源顺序固定 `problem > followup > agenda`；同模板每周最多一个来源。
- problem 只来自 active WorldProblemDefinition 的显式合同白名单。
- followup 只来自 `SituationState.unlocked_contract_ids`。
- agenda 要求 `allow_agenda_origin`、repeatable 且 `agenda_fit > 0`。
- 资格顺序严格使用 `docs/11` 第 4 节。
- declined suppression 先尝试排除一次；若导致没有合法候选，复用并记录
  `declined_offer_reused_no_alternative`。

### Direct actions

- 只从 faction 的 `weekly_action_ids` 产生。
- 常规行动必须找到一个 active problem，其 tags 覆盖全部 target_problem_tags。
- conditions 在同一规划快照成立；influence 必须不少于 cost。
- 同一 ActionDefinition 对多个问题合格时，每个具体问题形成候选，稳定问题 ID
  参与最终排序。
- 行动 event 只来自 `event_key`；effects 不得含第二个 create_world_event。

### Shared priority

```text
total_priority =
    base_priority
  + round_away(problem_urgency * urgency_weight / 100.0)
  + clamp(sum(agenda tag weights), -30, 30)
  - repeat_penalty
```

无关联问题时 urgency 为 0。repeat penalty 使用 `docs/02` 第 10.3 节固定公式；
历史来源包括 Offer 和 ContractHistoryEntry，不能只读取成功合同。

排序：

1. total priority 降序
2. base priority 降序
3. source Definition ID 升序
4. target problem ID 升序

规划不读取 relation、成员、金币或补给，不使用随机数。

## Two-pass planning

公开入口：

```text
plan_week(request) -> FactionPlanningResult
```

Result 至少包含 plans、new offers、new commitments、operations、reasons 和 issues。

固定过程：

1. 从输入快照收集所有 pending/accepted Offer 和 committed action 的 target lock。
2. 按稳定 faction ID 锁定模式。
3. 第一遍为无 pending 的 faction 选择合同，并调用 Task 009
   `ContractOfferService.create_offer()`。
4. 第二遍为规划开始时已有 pending 的 faction 选择不同 lock 的直接行动。
5. 没有行动候选时返回等待 plan/reason，不制造占位承诺。
6. 新 Offer、行动承诺和 influence 扣除作为同一 CampaignTransaction 批次提交。

Task 009 的 declined 占位不算 pending；accepted Offer 表示玩家已经选定本周合同，
不在新的周开始规划快照中出现。

## Action commitment resolution

```text
resolve_commitments(base_state, current_week, action_definitions)
    -> FactionActionResolutionResult
```

- 只处理 `status == committed && resolves_at_week == current_week + 1` 的承诺。
- 行动创建后不重查 conditions、agenda、priority 或 influence。
- effects 投影为 StateOperation，并以 action event_key 创建恰好一个 WorldEventState。
- 不再次扣 influence，不退款。
- 承诺置为 resolved，保存 resolved week 和 event ID。
- 所有 committed 行动按 committed week、faction ID、instance ID 升序。
- 返回基础世界 operations，交给 Task 011 与玩家合同效果合并后只提交一次。

## Complete unhandled Offer lifecycle

在 Task 009 服务中完成 `docs/13` 全部分支：

- 周开始仅处理 `pending && current_week > expires_week`。
- 顺序为 expires week、offered week、instance ID 升序。
- 每份读取前一份结果后的临时工作状态。
- NPC completion 复用提出方行动 Definition、conditions、cost、effects 和 event_key。
- 到期 Offer 自身先释放 target lock；其他占用仍有效。
- 无关联问题的 escalate 后备降为 expired。
- 同一问题已非 active 时固定 expired。
- 不运行 ContractResolver、不读取英雄/补给/玩家金币、不使用随机数。
- 三种终止结果都写 ContractHistoryEntry；world event 只由 npc_completed/escalated
  的既有定义产生。

## Catalog validation additions

- Action ID/owner/weekly_action_ids 双向一致且全局唯一。
- priority、urgency weight、cooldown、cost 和 agenda weight 范围合法。
- conditions/effects/target problem tags 引用合法。
- event_key 非空，effects 不含 create_world_event。
- NPC completion action 属于 sponsor 且与合同 target lock 完全一致。
- NPC/非 NPC unhandled policy 的 action 引用规则。
- 同一问题不同 lock 的并发内容不直接写互斥问题终态。
- 每个非结局阶段每个 faction 至少有可达 fallback Agenda 合同。
- 三个 fallback target lock 互不相同。
- 不存在 objective group、stance、NPC relation、contest 或 refund 字段。

## Focused tests

至少覆盖：

1. 无 pending 只生成一个 Offer，不创建行动。
2. 有 pending 只保留 Offer，并选择不同 lock 的行动。
3. 三阵营两遍规划证明行动不能抢占本周应生成的合同 lock。
4. 稳定 faction/definition/problem 排序与 100 次重复一致。
5. priority 四项公式、边界、round-away 和 repeat cooldown。
6. problem/followup/agenda 来源去重与固定优先级。
7. declined suppression 有替代时避开、无替代时复用。
8. 行动创建与 influence 预留同事务；少 1 influence 时不合格。
9. committed 行动周末应用一次、创建一个事件、不重复扣费且不退款。
10. 四种 unhandled policy 的全部 NPC 可执行/不可执行分支。
11. 同周两个到期 Offer 关联同一问题时只应用一次解决或恶化。
12. 任一缺失引用、target lock 冲突或事务失败使整个 planning/lifecycle 批次回滚。
13. Definition、CampaignState、urgency 输入和 candidate 输出互不别名。

## Out of scope

- 正式十四项行动内容
- 工资、恢复、week index 推进和顶层周流程
- 消息投影、GameSession、UI 和存档 JSON
- NPC 队伍、外交、谈判、冲突、退款或随机行动

## Acceptance tests

先运行 Task 010 focused/integration tests，再运行完整 suite。

## Completion checklist

- [x] 行动 Definition 经 manifest 验证和深编译。
- [x] 两遍规划、单一模式和 target lock 排他原样实现。
- [x] influence 只在承诺创建时扣一次。
- [x] Task 009 未处理生命周期的所有分支已闭合。
- [x] 无 relation/队伍/金币参与规划，无随机决胜。
- [x] focused/full suite 实际运行。

## Expected report

- 新增 Definition/State/Candidate/Plan API
- DataCatalog 和 CampaignTransaction 扩展
- 两遍规划与稳定排序证据
- action/Offer 生命周期原子性
- focused/full 测试结果
- Task 011 可直接调用的 planning、lifecycle 和 commitment result
