# Task 003 — Deterministic Staged ContractResolver Kernel

状态：Blocked until Task 002 and Gate A  
里程碑：Milestone 1（阶段结算内核）  
依赖：Task 002、`tasks/000_v0.1_execution_map.md` Gate A

## Goal

实现 UI 无关的固定四阶段合同结算内核：每阶段一个 check、稳定派生 seed、阶段间 MissionContext、五档结果、固定权重总评和延迟效果。条款、完整认可度、Approach 非平衡效果及最终报酬留给 Task 004。

## Blocking design check

开始编码前必须确认 Accepted 文档已明确：

- `cohesion_score → cohesion_modifier`
- 四人队关系、纪律支持和冲突如何确定性汇总为 `cohesion_score`
- 成员疲劳 → `fatigue_penalty`
- 成员伤势 → `injury_penalty`
- `seeded_variance` 的精确分布/区间，以及 score 在等级判断前的精度与舍入

若仍只有评分项名称而没有数值映射，停止任务并报告阻塞。不得自行选择除数、区间、平均方式，也不得把缺失项固定为零。

## Required reading

- 根目录 `AGENTS.md`
- `docs/02_core_loop_and_rules.md` 第 5—7 节
- `docs/03_godot_architecture.md` 第 4、5、7、8、12、13、15 节
- `docs/04_data_model.md` 第 2.5、2.6、3.10、4.6—4.10 节
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
check_score = capability_match
            + cohesion_modifier
            + preparation_modifier
            + context_modifier
            - fatigue_penalty
            - injury_penalty
            - check_difficulty
            + seeded_variance
```

本任务的 `balanced` 不产生 `approach_modifier`；完整 `attitude_modifier` 在 Task 004 加入。不得创建永久返回零的公开 attitude API。

- `seeded_variance` 固定为文档要求的窄随机范围。
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

- `>= 80` Exceptional
- `60—79` Success
- `40—59` Partial
- `20—39` Failure
- `< 20` Severe

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
2. 能力、协同、疲劳、伤势、难度、context 和 variance 的手算 score。
3. 每个非零 score component 都有精确 ReasonEntry。
4. 前一阶段 context delta 会确定性影响后续 check。
5. 同一 check 多个同 key delta 先合并后裁剪；不同阶段顺序应用。
6. 同输入和 seed 重复 100 次的完整 phase trace 一致。
7. 改变 seed 只改变随机项，非随机原因不变。
8. 改变一个 check ID 只改变该 check seed；其他三项不变。
9. 五档边界值 19/20、39/40、59/60、79/80。
10. 固定权重手算和 failure cap。
11. member/campaign effects 保持 deferred。
12. Resolver 前后所有输入值相等，`context_before` 无引用串改。
13. 非 balanced、非空补给或非空条款得到明确未支持错误。

## Acceptance tests

运行 focused tests 后运行：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

必须满足完整 suite 退出码 0，并在测试输出中打印一条人工可读的四阶段原因摘要。打印只发生在测试层，领域服务不得直接打印。

## Completion checklist

- [ ] Gate A 已在 Accepted 文档中解决并引用具体章节。
- [ ] 没有临时零公式或 executable string。
- [ ] Resolver 无 scene tree、Autoload 和 CampaignState 依赖。
- [ ] seed 隔离、context 传递和输入不变性有测试。
- [ ] focused/full suite 实际运行。
- [ ] diff 只触及 Allowed files 或报告过的兼容调整。

## Expected report

- Gate A 采用的精确规则来源
- 修改文件与公开 API
- score、seed、context 和 final tier 公式
- fixture 手算与实际 trace 对照
- focused/full 测试命令和结果
- 输入不变性与剩余 Task 004 项目
