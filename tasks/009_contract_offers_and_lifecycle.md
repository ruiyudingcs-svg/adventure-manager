# Task 009 — Contract Offers, Instantiation, and Player Commands

状态：Completed（2026-07-24）
里程碑：Milestone 3（合同生命周期）
依赖：Task 005—008、Gate C

## Goal

在现有 DataCatalog、CampaignState、CampaignTransaction 和 SituationResolver API
之上实现类型化 Offer 状态、最小实例化快照、关系档锁定、玩家接受/拒绝命令和
EffectiveContract 投影。Task 009 只处理不依赖阵营行动定义的生命周期部分；
NPC 完成、到期后备分支和跨阵营目标锁协调在 Task 010 与行动定义一起完成。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md` 第 4、7.4—7.7 节
- `docs/02_core_loop_and_rules.md` 第 10.3、12 节
- `docs/03_godot_architecture.md` 第 5、7—8、12—13 节
- `docs/04_data_model.md` 第 2.5、3.1、3.8、3.10—3.11、4.1—4.4 节
- `docs/11_contract_proposal_generation.md`
- `docs/12_contract_instantiation_and_commitment.md`
- `docs/13_unhandled_contract_and_npc_results.md` 第 2—4、6—8 节
- `docs/19_content_catalog_state_and_situation_rules.md` 第 2、5—7 节
- Task 005—008 的实际 Catalog、StateOperation、CampaignTransaction、
  ProblemUrgencyResult 和 WorldConditionEvaluator API

## Existing API anchors

实现必须复用而不是复制：

- `DataCatalog.get_contract()`、`get_contract_clause()` 和稳定排序的 `get_all_*()`。
- `CampaignState.duplicate_state()` 与 `CampaignState.validate()`。
- `CampaignTransaction.apply(base_state, operations)`。
- `SituationState`、`WorldProblemState`、`WorldEventState` 和
  `ProblemUrgencyResult` 的深副本值。
- `StableSeed.derive()`；不得使用全局随机数或新增第二套 hash。
- Task 004 的 `EffectiveContract`、`ContractPlan` 和 `ContractPlanValidator`。

Task 009 可以扩展 CampaignState 和 CampaignTransaction 的显式字段白名单，但
不得增加 Gate C 之外的新 operation 类型，也不得使用反射属性路径。

## Allowed files

- `game/domain/contracts/contract_offer_state.gd`
- `game/domain/contracts/contract_instantiation_snapshot.gd`
- `game/domain/contracts/check_difficulty_binding.gd`
- `game/domain/contracts/contract_plan_state.gd`
- `game/domain/contracts/effective_contract.gd`
- `game/domain/campaign/campaign_state.gd`
- `game/domain/campaign/contract_history_entry.gd`
- `game/domain/simulation/contract_offer_service.gd`
- `game/domain/simulation/campaign_transaction.gd`
- `game/data/catalogs/catalog_validator.gd`
- `game/core/result/state_operation.gd`
- 为上述类型所需的最小 command/result 值对象
- Task 009 对应的 `tests/unit/**`、`tests/integration/**`、`tests/fixtures/**`
- `tests/run_all.gd`

不得新增阵营行动 Definition、FactionTurnPlanner、WeekFlowCoordinator、
WeeklyMessageProjector、GameSession、UI 或存档序列化。

## Required state and value types

### 1. CampaignState additions

增加并深复制、验证：

```text
pending_contracts: Array[ContractOfferState]
active_plan: ContractPlanState
declined_offer_week: int
```

- `active_plan` 可以为空；非空时必须引用一份 `accepted` Offer。
- `declined_offer_week` 初始为 `-1`，只能为 `-1` 或不大于当前 week。
- 每个阵营最多一份 pending Offer。
- pending/accepted Offer 的 instance ID 和精确 target lock 均不得重复。
- terminal Offer 不长期保留在 `pending_contracts`；declined 只保留到下次周开始
  归档步骤。

CampaignTransaction 继续只使用现有五种 operation。对记录集合：

- `append_record` 按 record instance ID 插入并检测同 ID 不同内容冲突。
- `remove_unique` 使用稳定 record ID 删除对应 Offer。
- Offer 内部状态字段使用显式 `target_kind = contract_offer` 和字段白名单。
- `active_plan` 的安装/清除必须在 CampaignTransaction 中使用显式的单例记录
  dispatch，并测试空值、重复同值和冲突；不得新增通用 `set_record`。

### 2. ContractOfferState

字段严格使用 `docs/04` 第 3.8 节。必须提供：

- 状态常量和合法转移验证。
- `duplicate_state()` 与稳定 `content_signature()`。
- `remaining_turns(current_week)` 纯派生查询。
- 对嵌套 snapshot 和 reasons 的深复制。
- `sponsor_relation_snapshot` 在创建时锁定 -100 至 100 精确值；关系档 ID 固定
  为 `standard`、`favorable`、`trusted`。

合法状态仅为：

```text
pending, accepted, resolved, declined, expired, npc_completed, escalated
```

本任务只实际产生 `pending`、`accepted` 和 `declined`；Task 010 完成到期分支，
Task 011 完成 accepted → resolved 的周末协调。

### 3. ContractInstantiationSnapshot

严格保存：

```text
evaluated_week
check_difficulty_deltas: Array[CheckDifficultyBinding]
initial_context: MissionContext
reason_entries: Array[ReasonEntry]
```

不保存规则 ID、世界事实、预测结果、optional check 或 Definition 引用。
CheckDifficultyBinding 按 check ID 升序，reason code 稳定去重。

### 4. Commands

```text
PlanContractCommand
- contract_offer_id
- selected_member_ids
- selected_supply_ids
- approach

DeclineContractOfferCommand
- contract_offer_id
```

命令和值对象不持有 Node、Resource 或 CampaignState 引用。

## ContractOfferService

公开 API 至少覆盖：

```text
create_offer(request) -> OfferServiceResult
accept_offer(base_state, command, detached_definitions) -> OfferServiceResult
decline_offer(base_state, command) -> OfferServiceResult
archive_declined(base_state, current_week) -> OfferServiceResult
build_effective_contract(offer, definition, clauses, method_tags) -> EffectiveContract
```

Result 至少包含 operations、created/updated Offer、plan、reason entries 和 issues；
只有调用方通过 CampaignTransaction 成功后才替换状态。

### 1. Offer creation

输入是 Task 010 将来选中的单一合同意图，不在本任务内重新排序阵营候选。
使用文档固定公式锁定：

- offered/expires week
- offered reward
- relation tier
- problem urgency at offer
- target lock、origin 和 related problem
- instantiation snapshot
- resolution seed
- generation reasons

关系档：

| relation | duration bonus | reward multiplier |
|---|---:|---:|
| `< 25` | 0 | 1.00 |
| `25..59` | 1 | 1.10 |
| `>= 60` | 2 | 1.20 |

报酬只舍入一次。Offer instance ID 必须由命名空间和文档列出的六个片段稳定派生，
输出合法 lower snake_case；若发生 ID 碰撞必须报错，不得覆盖。resolution seed
固定使用：

```text
StableSeed.derive(campaign_seed, [offer_instance_id, "contract_resolution"])
```

ID 命名空间固定为 `contract_offer`，编码固定为
`contract_offer_%08x % StableSeed.derive(0, [namespace] + six_fragments)`；空问题
ID 保持为空片段参与长度编码。报酬使用 `roundi()`（即 `round_away`）且只舍入
一次。

### 2. Instantiation

- rule 按稳定 rule ID 升序求值，所有匹配规则生效。
- 条件只读周、phase、clock、问题派生值、事件和 origin。
- Followup/Agenda 没有关联问题，所有问题字段条件为 false。
- 单条 difficulty 为 `-10..10`，同 check 合并后裁剪 `-20..20`。
- 单条 context delta 为 `-3..3`，同 key 合并后裁剪 `-6..6`，再应用到
  MissionContext 的 `0..10`。
- 每个非零最终 overlay 保存完整原因；交换 manifest/rule 输入顺序不得改变结果。

### 3. Accept and decline

接受：

- 只允许当前周仍有效的 pending Offer。
- 计划必须是四个不同成员、最多两个不同补给和合法 approach。
- 成员可用性、Opposed/morale 和金币补给预检复用调用方提供的 detached
  AdventurerDefinition、SupplyDefinition 和既有 Validator；领域服务不得依赖
  DataCatalog Node 或 Autoload。
- 同一事务把 Offer 置为 accepted 并安装 active_plan。
- 不立即运行 ContractResolver、扣补给、发报酬或改变世界。

拒绝：

- 只允许 pending Offer，且 `declined_offer_week != current_week`。
- 同一事务置为 declined、清除引用它的 active_plan、记录拒绝历史并锁定本周额度。
- 不改变 relation、influence、世界钟、问题或事件；当周不补位。
- 下一周归档 declined 占位时不重复写历史，并返回一次性 suppression key：
  definition + origin + problem + target lock。

## Catalog validation additions

- Offer instantiation condition/effect 白名单和引用完整。
- 规则不能读取成员、金币、补给或阵营关系。
- check/context 目标、单条值和汇总边界合法。
- Offer 状态白名单不含 cancelled、abandoned 或 npc_failed。
- ContractDefinition 的期限、报酬、来源、重复策略和 target lock 合法。

完整 fallback、行动引用和 NPC completion 验证属于 Task 010。

## Focused tests

至少覆盖：

1. 三个关系档的边界 24/25/59/60、期限和报酬舍入。
2. 相同输入重复 100 次得到相同 Offer ID、seed、snapshot 和原因顺序。
3. 多条 difficulty/context 先合并后裁剪，规则输入顺序不影响结果。
4. Offer 创建后的世界、问题和关系变化不改写任何锁定字段。
5. snapshot 与 Definition、Resource、MissionContext 不共享可变数据。
6. 合法计划进入 accepted；无效人数、重复 ID、禁用成员、Opposed/morale、
   非法补给和金币不足均原子失败。
7. 每周只拒绝一次；拒绝不产生世界/关系/influence 效果且当周不补位。
8. declined 归档只写一份历史并产生恰好一次 suppression key。
9. pending/accepted target lock 与 instance ID 重复时完整状态验证失败。
10. EffectiveContract 使用锁定 reward、seed overlay 和 clause Definition，
    不重新读取当前世界。
11. 失败事务保持 CampaignState、Offer、Definition 和命令输入不变。

## Out of scope

- 阵营候选评分和两遍规划
- FactionActionDefinition、行动承诺和 influence 预留
- NPC completion 与完整过期分支
- 周开始/周末协调与正式状态替换
- MessageState、UI 和存档 JSON

## Acceptance tests

先运行 Task 009 focused/integration tests，再运行完整 suite：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

## Completion checklist

- [x] Offer、snapshot、plan 和 command 全部类型化且深复制。
- [x] 关系档、ID、seed、期限和报酬只在创建时锁定一次。
- [x] 接受/拒绝只返回事务意图，不直接修改输入状态。
- [x] 未增加 Gate C operation 类型或任意属性反射。
- [x] 未提前实现阵营规划、消息、UI 或存档。
- [x] focused/full suite 实际运行。

## Expected report

- 新增状态和值对象
- ContractOfferService 公开 API 与锁定字段
- CampaignTransaction 白名单扩展
- 接受/拒绝原子性与输入不变性
- focused/full 测试命令、退出码和结果
- 明确交给 Task 010 的 NPC 生命周期接口
