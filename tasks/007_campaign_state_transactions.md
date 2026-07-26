# Task 007 — CampaignState and Atomic Transactions

状态：Completed
里程碑：Milestone 2（状态提交）
依赖：Task 004、Task 005、Task 006、Gate C

## Goal

实现最小 CampaignState、StateOperation 合并、StateChange 审计和
CampaignTransaction，使合同的金币、成员、提出方与世界效果在深副本上全部
成功或全部失败。

## Required reading

- 根目录 `AGENTS.md`
- `docs/02_core_loop_and_rules.md` 第 2、7、9—14 节
- `docs/03_godot_architecture.md` 第 5、7—8、13、16 节
- `docs/04_data_model.md` 第 3、4.1—4.2、4.10 节
- `docs/15_staged_contract_resolution_rules.md` 第 8 节
- `docs/19_content_catalog_state_and_situation_rules.md` 第 4—5、8 节
- Task 004 ContractResolution 和 Task 005 DataCatalog API

## Allowed files

- `game/domain/campaign/**`
- `game/domain/guild/**`
- `game/domain/factions/**` 中运行时 State
- `game/domain/situations/**` 中运行时 State
- `game/core/result/state_operation.gd`
- `game/core/result/state_change.gd`
- `game/domain/simulation/campaign_transaction.gd`
- `game/domain/simulation/contract_resolution_projector.gd`
- 为锁定补给总成本所需的：
  - `game/domain/contracts/contract_resolution.gd`
  - `game/domain/simulation/contract_resolver.gd`
- `tests/unit/test_state_operation_merge.gd`
- `tests/unit/test_campaign_transaction.gd`
- `tests/integration/test_contract_resolution_commit.gd`
- `tests/fixtures/campaign_state_fixtures.gd`
- `tests/run_all.gd`

不得创建 GameSession、WeekFlowCoordinator、SaveService 或 UI。

## Required state

本任务至少实现：

- CampaignState：save version 占位常量、campaign seed、week index、GuildState、
  adventurers、factions、SituationState、contract history、world events。
- GuildState：gold、reputation、base cohesion、weekly maintenance。
- FactionState：definition ID、relation、influence。
- SituationState：definition ID、phase ID、clock values、triggered IDs、
  unlocked contract IDs、problem states、ending ID。
- WorldProblemState 和 WorldEventState。

Offer、行动承诺、消息和存档字段由其拥有任务后续扩展，不创建无类型占位数组。

所有 State 必须支持深复制和完整验证；不得引用或修改静态 Definition。

## StateOperation

严格实现 Gate C 白名单：

- add_int
- set_id
- add_unique
- remove_unique
- append_record

目标和字段使用显式常量与 `match` dispatch。不得调用任意 `set(field_path)`。

## Merge rules

- 数值按 target kind、ID、field 求和后裁剪一次。
- 相同集合请求稳定去重。
- 同值 set 合并，不同终值失败。
- 同一值同时 add/remove 失败。
- 同稳定 ID、不同 record 内容失败。
- 原因按 source order、再按 reason code。
- 合并不依赖输入数组顺序决定最终状态。

## Contract projection

ContractResolutionProjector 把以下内容转换为 StateOperation：

- reward 增加 guild gold。
- `supply_cost_total` 减少 guild gold。
- 每个 MemberOutcome 的 fatigue、injury、recovery、availability、morale。
- sponsor relation delta。
- situation WorldEffect。
- outcome tags 和合同历史请求。

提交前检查 gold 足够支付锁定补给总成本。金币不足或任一 target 缺失时整批失败。

ContractResolver 在不读取 CampaignState 的前提下，把所选补给 cost 求和写入
`supply_cost_total`，并保留 `consumed_supply_ids`。Resolver 不扣金币。

## CampaignTransaction

```text
apply(base_state, operations) -> CampaignTransactionResult
```

流程：

1. 深复制 base state。
2. 验证并合并全部操作。
3. 在临时状态应用。
4. 生成 StateChange old/new。
5. 验证完整临时状态和引用。
6. 成功返回新状态；失败返回问题且 new state 为空。

不得修改 `base_state`、operations、ContractResolution 或 DataCatalog。

## Comments

对一次裁剪、冲突规则、深副本事务和白名单 dispatch 添加“为什么”的注释；
公共事务 API 使用 `##`。

## Focused tests

至少覆盖：

1. 多个数字 delta 合并后只裁剪一次。
2. 交换 operation 输入顺序，最终 StateChange 和状态一致。
3. add/remove 冲突、不同 set、重复 record 冲突。
4. 未知 target kind、target ID、field 和 operation。
5. 任一失败时原 CampaignState 字节级/字段级不变。
6. Definition、ContractResolution 和 StateOperation 输入不变。
7. reward 与 supply cost 各应用一次；余额不足整批失败。
8. 四名 MemberOutcome 与提出方关系同事务提交。
9. 世界钟效果与成员效果中任一非法时全部回滚。
10. Reason code 和 StateChange 顺序稳定。
11. 三份基准 ContractResolution 均可提交到 fixture CampaignState。
12. 重复提交同一事务不会被测试误当成合法幂等操作。

## Out of scope

- 原子替换 GameSession 正式状态
- 工资、恢复和周推进
- 触发器、问题和结局求值
- Offer、阵营行动、消息和存档
- 补给库存、堆叠或市场

## Acceptance tests

先运行 focused/integration tests，再运行完整 suite。

## Completion checklist

- [x] StateOperation 与 StateChange 职责分离。
- [x] 没有任意字段反射或 executable string。
- [x] 所有事务在深副本上执行。
- [x] 补给只扣金币一次，不存在库存。
- [x] 任一失败无部分提交。
- [x] focused/full suite 实际运行。

## Expected report

- State 类型与公开事务 API
- operation 白名单、合并和裁剪规则
- ContractResolution 投影清单
- 原子性和输入不变性证据
- focused/full 测试结果
- 后续 CampaignState 字段扩展点
