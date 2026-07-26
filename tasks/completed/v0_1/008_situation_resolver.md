# Task 008 — SituationResolver

状态：Completed
里程碑：Milestone 2（局势规则）
依赖：Task 005、Task 007、Gate C

## Goal

实现不依赖场景树和随机数的 SituationResolver：世界钟、被动推进、问题期限、
问题激活/解决、紧迫度、单批触发器、稳定结局选择。所有变化返回
StateOperation，并由 Task 007 原子事务提交。

## Required reading

- 根目录 `AGENTS.md`
- `docs/product/01_v0.1_product_spec.md` 第 6—7、9、15 节
- `docs/rules/02_core_loop_and_rules.md` 第 2、10—12 节
- `docs/architecture/03_godot_architecture.md` 第 7—8、13、15—16 节
- `docs/architecture/04_data_model.md` 第 2.9—2.14、3.5—3.7、4.5 节
- `docs/rules/campaign/14_week_flow_faction_commitments_and_messages.md` 第 2、6 节
- `docs/content/dragon_invasion/17_dragon_invasion_scenario_spec.md`
- `docs/content/dragon_invasion/18_dragon_invasion_problem_and_action_catalog.md`
- `docs/rules/campaign/19_content_catalog_state_and_situation_rules.md` 第 6—8 节
- Task 005 CatalogValidator 和 Task 007 CampaignTransaction API

## Allowed files

- `game/domain/situations/**`
- `game/domain/simulation/situation_resolver.gd`
- `game/domain/simulation/problem_urgency_calculator.gd`
- Task 005 的 situation authoring Resource 与 CatalogValidator，仅用于补齐本任务
  明确要求的语义验证
- `tests/unit/test_problem_urgency.gd`
- `tests/unit/test_situation_resolver.gd`
- `tests/integration/test_situation_transaction.gd`
- `tests/fixtures/situation_fixtures.gd`
- `tests/run_all.gd`

不得修改正式巨龙内容数值；不得创建 WeekFlowCoordinator、Offer、阵营规划、消息、
UI 或存档。

## Resolver inputs

SituationResolver 只读取：

- current week
- SituationDefinition
- SituationState
- WorldProblemState
- WorldEventState
- contract history 的稳定完成事实
- 本边界已合并的基础世界 StateOperation

不得读取成员、队伍、金币、补给、成员关系或阵营关系。不得使用随机数。

## Problem urgency

严格实现：

```text
urgency =
    base_urgency
  + clock_pressure
  + min(age_weeks * age_per_week, age_cap)
  + deadline_pressure
  + phase_pressure
```

- deadline：3 回合以上 0、2 回合 +10、1 回合 +25。
- 最后裁剪 0—100。
- band：low 0—19、guarded 20—39、high 40—59、severe 60—79、
  critical 80—100。
- 紧迫度是派生结果，不写入 CampaignState。
- 每个非零来源生成 ReasonEntry。

## Problem lifecycle

- activation rules 中任一成立时，inactive 问题可以激活一次。
- 激活时锁定 opened week 和 response deadline。
- resolution rules 中任一成立时，active 问题 resolved。
- 越过期限的 active 问题应用 escalation effects 并进入 escalated。
- resolved、escalated、closed 不得重新激活。
- escalation effects 必须创建一个稳定 world event。
- 合同/行动不直接争写互斥问题终态；Resolver 读取合并后状态统一决定。

## Trigger batch

```text
eligible = evaluate all triggers against one snapshot
sort by priority descending, stable ID ascending
apply eligible once
```

- `once` 且 ID 已在 triggered_rule_ids 中时不合格。
- 批次锁定后不追加新合格触发器。
- triggered ID 只作为同一原子事务的操作返回。
- 同批冲突由 CampaignTransaction 拒绝，不用 priority 覆盖。

## Ending selection

- 在触发器和问题转移后统一求值。
- all conditions 全部满足。
- any conditions 为空或至少一项满足。
- priority 降序、稳定 ending ID 升序。
- 最多选择一个 ending。
- 写入 ending ID 并进入唯一 terminal phase。
- `set_ending` 只增加候选，不直接覆盖稳定选择。

## Boundary order

严格使用 `docs/19` 第 7 节。新游戏第 1 周不运行 passive；进入第 2 周及以后
每个周开始边界恰好一次。周末边界不重复应用 passive。

## Catalog validation additions

- clock/phase/problem/trigger/ending ID 与引用存在。
- clock min/max/initial 合法。
- ProblemUrgencyRule 条件只允许 clock_gte、clock_lte、phase_is。
- 同问题同 clock 数值区间互斥。
- 世界条件不包含 `faction_relation_gte`。
- 世界效果不包含 `modify_faction_relation`。
- 恰好一个 terminal phase。
- trigger 与 ending priority 可稳定排序。
- problem escalation 至少一个 create_world_event。
- 结局条件引用合法且同分可由 ID 决胜。

## Focused tests

至少覆盖：

1. 钟多来源先合并后裁剪。
2. 第 1 周不应用 passive，第 2 周只应用一次。
3. urgency 年龄上限、期限 3/2/1/越期、区间和 0/100 边界。
4. urgency 原因与 band 顺序稳定且不写入 State。
5. 问题激活锁定 deadline，resolve/escalate 互斥且不重开。
6. escalation 只发生一次并创建事件。
7. 触发器同一快照锁批，不递归。
8. once trigger 只在成功提交后记录。
9. 同批冲突使 Task 007 事务完整回滚。
10. 多个 ending 同时成立时 priority/ID 稳定选一个。
11. 选结局后进入唯一 terminal phase。
12. 第 15 周保底杀龙条件的 accepted fixture 路径。
13. 相同输入重复 100 次结果和原因完全相同。
14. Resolver 不读取成员、金币、补给或阵营关系。

## Out of scope

- 完整九问题/十二合同内容
- Offer 生命周期和阵营行动执行
- 周开始/周末顶层协调
- MessageState 创建
- GameSession、UI 和存档
- 递归触发器或规则表达式语言

## Acceptance tests

先运行 focused/integration tests，再运行完整 suite。

## Completion checklist

- [x] 紧迫度为纯派生结果。
- [x] 问题终态不重开。
- [x] 触发器每个边界只运行一批。
- [x] 结局稳定且唯一。
- [x] 所有效果通过 StateOperation 和 CampaignTransaction。
- [x] 无随机、scene tree 或阵营关系依赖。
- [x] focused/full suite 实际运行。

## Expected report

- SituationResolver 公开 API 与边界顺序
- urgency、problem、trigger 和 ending 行为
- 新增 CatalogValidator 规则
- Task 007 原子事务集成结果
- focused/full 测试结果
- Task 009—013 需要使用的稳定 API
