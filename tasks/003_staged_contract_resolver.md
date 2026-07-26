# Task 003 — Deterministic Staged ContractResolver Kernel

状态：Completed
里程碑：Milestone 1（阶段结算内核）  
依赖：Task 002、`tasks/000_v0.1_execution_map.md` Gate A

## Goal

实现 UI 无关的固定四阶段合同结算内核：每阶段一个 check、稳定派生 seed、阶段间 MissionContext、五档结果、固定权重总评和延迟效果。条款、完整认可度、Approach 非平衡效果及最终报酬留给 Task 004。

## Gate A rule basis

Gate A 已由 `docs/15_staged_contract_resolution_rules.md` 第 4.1—4.3 节定案：

- `relationship_values` 按六个无序成员对汇总，纪律使用四人平均，单向或双向低关系派生活跃冲突。
- `cohesion_modifier` 范围 -10 至 +10。
- 疲劳逐成员使用 0/1/3/5 档，伤势逐成员使用 `ceil(injury_severity / 20)`，再分别相加。
- `seeded_variance` 为闭区间 -10 至 +10 的离散均匀整数，每个 check 恰好抽取一次。
- raw score 使用 64 位浮点，只在 tier 判断前以 `.5` 远离 0 的方式舍入一次，最终 score 为不裁剪整数。

实现必须直接使用上述 Accepted 规则。若 Task 002 实际 API 与这些输入约束存在不兼容，只允许做任务书所述的最小兼容调整并报告，不得更改数值规则。

## Required reading

- 根目录 `AGENTS.md`
- `docs/02_core_loop_and_rules.md` 第 5—7 节
- `docs/03_godot_architecture.md` 第 4、5、7、8、12、13、15 节
- `docs/04_data_model.md` 第 2.1.1、2.5、2.6、3.3.1、3.10、4.6—4.10 节
- `docs/10_baseline_contracts.md` 的北境道路手算样例
- `docs/15_staged_contract_resolution_rules.md` 第 1—5、8、9 节
- Task 002 的实际公开 API 和测试

## Allowed files

- `game/domain/contracts/contract_stage_definition.gd`
- `game/domain/contracts/contract_check_definition.gd`
- `game/domain/contracts/check_outcome_definition.gd`
- `game/domain/contracts/check_outcome_table.gd`
- `game/domain/contracts/contract_outcome_definition.gd`
- `game/domain/contracts/contract_outcome_table.gd`
- `game/domain/contracts/mission_modifier.gd`
- `game/domain/contracts/effective_contract.gd`
- `game/domain/contracts/contract_plan.gd`
- `game/domain/contracts/mission_context.gd`
- `game/domain/contracts/check_result.gd`
- `game/domain/contracts/phase_result.gd`
- `game/domain/contracts/resolution_trace.gd`
- `game/domain/contracts/member_effect.gd`
- `game/domain/contracts/world_effect.gd`
- `game/domain/simulation/contract_resolver.gd`
- `game/domain/simulation/check_score_calculator.gd`
- `game/domain/simulation/mission_context_reducer.gd`
- `tests/unit/test_mission_context.gd`
- `tests/unit/test_contract_resolver.gd`
- `tests/fixtures/contract_resolver_fixtures.gd`
- `tests/run_all.gd`

若实际 Task 002 API 需要调整，只允许做保持语义的最小兼容修改，并在报告中逐项列出。不得新增 `.tres`、CampaignState、Autoload 或 UI。

## Stable public boundary

Resolver 接受一个显式请求对象或等价参数组：

- `EffectiveContract`：锁定后的结算投影，不回读当前世界状态。
- `ContractPlan`：四名英雄快照、已选补给快照和 Approach。
- 明确 `contract_seed`。
- 必要的协同/准备输入必须是文档定义的领域数据，不允许 UI 预先计算最终修正值。

Resolver 返回阶段结算草案（可命名为 `ResolutionTrace` 或等价的强类型中间结果），包含四个 PhaseResult、最终 MissionContext、未封顶等级、check caps 和待应用的 check 效果。Task 004 再把它组装为完整 `ContractResolution`。Task 004 只能补齐政策，不应推翻阶段、check、context、seed 或 trace API；不得用含“未结算 reward”的半成品冒充可提交 Resolution。

## Required behavior

### Structure validation

1. 阶段固定为 `approach`、`main_action`、`special_objective`、`extraction`，顺序不可变。
2. 每阶段恰好一个 check；不支持空阶段、optional、skip、toggle、回跳或动态插入。
3. 阶段 ID 和 check ID 在合同内唯一。
4. 四个 `result_weight` 均大于 0，合计在统一 epsilon 内接近 1.0；不自动归一化。
5. check type、Approach profile、MissionContext key 和 MissionModifier condition 使用文档白名单。
6. 本任务 fixture 只允许 `balanced`、空补给和空条款；遇到其他值返回明确“Task 004 policy not implemented”验证错误，而不是静默忽略。

### Check score

按 Accepted 文档实现完整数值项：

```text
raw_score = capability_match
          + cohesion_modifier
          + preparation_modifier
          + context_modifier
          - fatigue_penalty
          - injury_penalty
          - check_difficulty
          + seeded_variance

check_score = round_away(raw_score)
```

本任务的 `balanced` 不产生 `approach_modifier`；完整 `attitude_modifier` 在 Task 004 加入。不得创建永久返回零的公开 attitude API。

- `seeded_variance` 使用 `randi_range(-10, 10)`，闭区间内 21 个整数等概率，每个 check 只抽取一次。
- raw score 只在等级判断前 `round_away` 一次；最终 score 不裁剪，发生舍入时生成 `score_rounding` ReasonEntry。
- 每个非零项生成独立 `ReasonEntry`。
- context 修正必须保存来源 check、context key 和 amount，不能只保存合计。
- 所有原因顺序确定，不依赖 Dictionary 遍历顺序。

### Seed isolation

```text
check_seed = stable_hash(contract_seed, phase, check_id)
```

- 每个 check 使用独立 RNG。
- 新增、删除或改名其他 check 不得消耗该 check 的随机流。
- Resolver 不使用全局 RNG、当前时间或 UI 刷新次数。

### MissionContext

- 十个整数字段默认 0，范围 0—10。
- Offer 初值 overlay 按 key 先合并再裁剪一次。
- 单个 check 的同 key delta 先求和，再裁剪一次。
- context 在阶段结束后立即更新；下一阶段读取新的不可变快照。
- `outcome_tags`、`used_method_tags` 按首次出现顺序稳定去重。
- 除 context 外，成员和世界效果只进入待应用列表。

### Tiers and final result

check score 等级：

- `>= 70` Exceptional
- `50—69` Success
- `30—49` Partial
- `10—29` Failure
- `< 10` Severe

合同点数：

```text
Exceptional = 100
Success = 75
Partial = 50
Failure = 25
Severe = 0

contract_score = sum(check_tier_points * result_weight)
```

- 最终等级使用相同 80/60/40/20 阈值。
- 所有 check 固定执行，不重新归一化权重。
- check 为 Failure 或 Severe 时应用其 `failure_result_cap`；多个 cap 取最严格者。

### Purity

- Resolver 不修改 EffectiveContract、ContractPlan、英雄快照或 outcome definitions。
- `context_before` 是独立快照。
- Resolver 不修改 CampaignState，不应用金币、关系、士气或世界钟。
- 任一验证或结算错误只返回失败结果，不返回半成品 Resolution。

## Fixture boundary

使用 `contract_north_road_evacuation` 的四阶段结构和手算 trace 作为主要 fixture，但：

- fixture 以代码内存对象构造，不创建 `.tres`；
- 条款列表为空；
- Approach 固定 balanced；
- 不结算最终报酬、伤病投掷或士气；
- 可保留 CheckOutcome 的风险和世界效果为待应用数据。

## Out of scope

- 计划接受/拒绝和 CampaignState 可用性验证
- cautious/aggressive、供应消耗和金币
- 条款求值、任务前完整认可度、任务后评价
- 最终报酬、提出方关系和成员伤病投掷
- Offer 生成、实例化规则求值、阵营和世界事务
- `.tres`、DataCatalog、UI、消息和存档

## Focused tests

至少覆盖：

1. 四阶段顺序、每阶段一个 check 和非法结构拒绝。
2. 能力、协同、疲劳、伤势、难度、context、variance 和最终舍入的手算 score。
3. 六个关系对的无记录、单向、双向和单向冲突聚合；协同 0/50/100 转换边界。
4. 疲劳 29/30、59/60、79/80 和伤势 0/1、20/21、100 的惩罚边界。
5. 每个非零 score component 都有精确 ReasonEntry；舍入时原因总和等于最终整数 score。
6. 前一阶段 context delta 会确定性影响后续 check。
7. 同一 check 多个同 key delta 先合并后裁剪；不同阶段顺序应用。
8. 同输入和 seed 重复 100 次的完整 phase trace 一致。
9. 改变 seed 只改变随机项，非随机原因不变。
10. 改变一个 check ID 只改变该 check seed；其他三项不变。
11. 五档边界值 9/10、29/30、49/50、69/70，并覆盖 raw score 的 `.5` 舍入。
12. 固定权重手算和 failure cap。
13. member/campaign effects 保持 deferred。
14. Resolver 前后所有输入值相等，`context_before` 无引用串改。
15. 非 balanced、非空补给或非空条款得到明确未支持错误。

## Acceptance tests

运行 focused tests 后运行：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

必须满足完整 suite 退出码 0，并在测试输出中打印一条人工可读的四阶段原因摘要。打印只发生在测试层，领域服务不得直接打印。

## Completion checklist

- [x] Gate A 已在 Accepted 文档中解决并引用具体章节。
- [x] 没有临时零公式或 executable string。
- [x] Resolver 无 scene tree、Autoload 和 CampaignState 依赖。
- [x] seed 隔离、context 传递和输入不变性有测试。
- [x] focused/full suite 实际运行。
- [x] diff 只触及 Allowed files 或报告过的兼容调整。

## Expected report

- Gate A 采用的精确规则来源
- 修改文件与公开 API
- score、seed、context 和 final tier 公式
- fixture 手算与实际 trace 对照
- focused/full 测试命令和结果
- 输入不变性与剩余 Task 004 项目
