# Task 004 — Complete Contract Planning and Resolution Policy

状态：Blocked until Task 003 and Gate B  
里程碑：Milestone 1（完整合同结算）  
依赖：Task 003、`tasks/000_v0.1_execution_map.md` Gate B

## Goal

在 Task 003 的稳定四阶段内核上补齐 V0.1 玩家合同政策：计划验证、三种 Approach、补给修正、任务前认可度、任务后成员评价、公开条款、最终报酬、疲劳、伤病与提出方关系。三份基准合同必须共享同一结构化模型，不得出现合同专用脚本或按合同 ID 分支。

## Blocking design check

开始编码前确认 Accepted 文档已经提供：

1. `method_fit` 的性格/禁忌与 method tag 白名单规则。
2. `personal_fit` 的报酬、成长、提出方关系、近期冷落、伤病和风险数值规则。
3. 公开条款进入任务前认可度的明确算法。
4. 合同 `risk_level`、CheckOutcome 风险百分点、ContractOutcome 风险修正、当前疲劳、保护和补给的汇总公式。
5. 每名成员无伤/轻伤/重伤的确定性投掷、阈值和恢复结果。
6. `fatigue_multiplier` 的应用与舍入顺序。
7. 人员安全条款、条款封顶、最终 tier 和 `injury_risk_modifier` 之间不存在循环的唯一结算顺序。

若任一项仍未定义，停止并报告 Gate B 未满足。特别禁止根据基准样例“无人重伤”倒推概率表。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md` 第 8—9 节
- `docs/02_core_loop_and_rules.md` 第 3—9 节
- `docs/03_godot_architecture.md` 第 5、7、8、12、13、15 节
- `docs/04_data_model.md` 第 2.4—2.7、3.3、3.10、4.6—4.10 节
- `docs/08_contract_clause_spec.md`
- `docs/10_baseline_contracts.md`
- `docs/15_staged_contract_resolution_rules.md`
- Task 002/003 的实际公开 API 和测试

## Allowed files

- `game/domain/adventurers/**`
- `game/domain/contracts/**`
- `game/domain/simulation/contract_resolver.gd`
- `game/domain/simulation/contract_plan_validator.gd`
- `game/domain/simulation/attitude_calculator.gd`
- `game/domain/simulation/clause_evaluator.gd`
- `game/domain/simulation/member_outcome_calculator.gd`
- `game/domain/simulation/reward_calculator.gd`
- `tests/unit/test_contract_plan_validator.gd`
- `tests/unit/test_attitude_calculator.gd`
- `tests/unit/test_approach_policy.gd`
- `tests/unit/test_clause_evaluator.gd`
- `tests/unit/test_member_outcomes.gd`
- `tests/unit/test_complete_contract_resolution.gd`
- `tests/fixtures/contract_resolver_fixtures.gd`
- `tests/fixtures/baseline_contract_fixtures.gd`
- `tests/run_all.gd`

不得创建 CampaignState、Offer 服务、阵营服务、`.tres`、Autoload、UI 或存档代码。

## Required behavior

### 1. ContractPlan validation

- 恰好选择四名不同英雄。
- 英雄 ID 存在、`is_available == true`，且不处于文档定义的严重伤病禁派状态。
- 最多选择两个补给；引用存在、玩家当前可用且 tag 在合同 `allowed_supply_tags` 中。
- Approach 只允许 `cautious`、`balanced`、`aggressive`。
- 任务前预测态度为 Opposed 且 morale `<= 20` 的英雄拒绝派遣；其他 Opposed 英雄必须显式记录为强制派遣。
- 所有失败返回结构化验证结果和原因，不使用 assert 处理玩家输入。
- 验证不扣金币、不消耗补给、不修改英雄状态。

### 2. Task-pre attitude

```text
attitude = ideology_fit + method_fit + personal_fit
```

- `ideology_fit = dot(member_values, expected_contract_vector) / 5`，裁剪到 -40—+40。
- `method_fit` 与 `personal_fit` 严格使用 Gate B 定案白名单和边界。
- 公开合同意图、全部公开条款、预期 method tags 和成员个人状态参与预览；不得读取实际未来骰点。
- 状态阈值：Enthusiastic `>= 40`，Supportive `10—39`，Neutral `-9—9`，Reluctant `-39—-10`，Opposed `<= -40`。
- 每个 check 再按其实际 method tags 计算成员状态；四人判定修正取平均：Enthusiastic `+2`、Supportive/Neutral `0`、Reluctant `-3`、被强制 Opposed `-6`。
- 每个非零来源生成独立原因，不把多个来源压成无法解释的总数。

### 3. Approach

check profile 为 `careful`、`forceful`、`neutral`：

| Approach | careful | forceful | neutral | 合同级效果 |
|---|---:|---:|---:|---|
| cautious | +3 | -3 | 0 | 初始 `time_pressure +1`；每人疲劳 `+1`；重伤风险 `×0.70` |
| balanced | 0 | 0 | 0 | 无 |
| aggressive | -3 | +5 | 0 | 初始 `alert_level/team_strain/collateral_pressure +1`；每人疲劳 `+3`；重伤风险 `×1.30` |

- 合同级 context delta 只在第一个 check 前应用一次。
- Approach check 修正按每个 check profile 应用。
- 重伤乘数在其他风险加减汇总后应用，再裁剪到 0%—100%。
- 以上数值不可由合同模板覆盖。

### 4. Supplies and preparation

- SupplyDefinition 只通过结构化 tag 与白名单 ConditionalModifier 影响相关 check、疲劳或伤病风险。
- 同一修正的匹配条件、数值和来源必须进入原因记录。
- 最多两个补给，不实现装备栏、affix、制作或库存堆叠框架。
- Resolver 只返回待消耗 supply ID；实际扣库存和金币由后续原子事务处理。

### 5. Clause evaluation

实现七类 category：

- `target_state`
- `method`
- `collateral`
- `secrecy`
- `delivery`
- `efficiency`
- `personnel_safety`

只支持 `mandatory` 与 `bonus`，以及 `docs/08_contract_clause_spec.md` 的 condition/effect 白名单。

- 四个 check 完成后读取锁定 plan 和完整 ResolutionTrace，各条款只求值一次。
- 条件只有 `all_conditions`；不实现 OR、脚本表达式或隐藏条款。
- 按 `priority`、稳定 clause ID 求值。
- Bonus 不得有 failure effects 或 cap。
- 多个 mandatory cap 取最严格等级。
- 条款不单独投骰，不直接修改世界钟、士气、成员关系、消息或后续合同。
- 同一行为可以满足多个条款，各来源独立记录。

### 6. Final reward and sponsor relation

严格按以下顺序：

```text
clause_reward_percent_delta = clamp(sum(clause percent effects), -100, 100)
reward_percent = max(0, 100 + clause_reward_percent_delta)
final_reward = max(0, round(
    offered_reward
    * final_tier_reward_multiplier
    * reward_percent / 100
))
```

```text
sponsor_relation_delta = clamp(
    ContractOutcomeTable.sponsor_relation_delta
    + sum(clause sponsor relation effects),
    -20,
    20
)
```

- 只结算提出方关系。
- 其他阵营不响应 outcome tags。
- Resolver 返回待应用值，不修改金币或 FactionState。

### 7. Fatigue and injury

```text
fatigue_gain = contract_base_fatigue
             + approach_fatigue
             + failure_fatigue
             - supply_reduction
```

- 最终等级的 fatigue multiplier 在 Gate B 定案的步骤应用，并按定案规则舍入。
- 每名成员的风险来源、合并、乘数、裁剪、派生 seed、投掷和结果都产生可追踪原因。
- 伤病只有无伤、轻伤、重伤；重伤必须有明确风险来源与 roll 记录。
- 伤病随机流必须从 contract seed 与稳定 member ID 派生，且不能改变四个 check 的随机结果。
- 所有成员结果保持 deferred；Resolver 不修改 AdventurerState。

### 8. Post-mission evaluation

```text
actual_ideology_vector =
    sum(CheckOutcome.ideology_impact)
  + sum(ClauseResult.ideology_impact)

actual_method_vector =
    sum(unique used MethodTagDefinition.ideology_vector)

post_mission_evaluation = clamp(
    dot(member_values, actual_ideology_vector) / 5
  + dot(member_values, actual_method_vector) / 5,
    -40,
    40
)
```

- 两个任务向量各维度先裁剪到 -10—+10。
- 同一 method tag 每份合同只累计一次。
- 所有参与者评价整份任务，不按阶段贡献加权。
- 士气变化：20—40 `+3`，5—19 `+1`，-4—4 `0`，-19—-5 `-1`，-40—-20 `-3`。
- 士气最终应用时裁剪 0—100；本任务只返回待应用 delta 和原因。
- 不实现 departure strikes、永久离队或自动成员关系变化。

### 9. Resolution order and purity

Gate B 必须先给出无循环的固定顺序。实现时至少保持以下不变部分，伤病、条款 cap 和最终结果表三者的相对顺序严格采用 Gate B 定案版本：

```text
1. 验证并锁定 ContractPlan
2. 应用一次合同级 Approach context
3. 顺序完成四个 check
4. 计算未封顶 contract score、初始 tier 和 check caps
5. 按 Gate B 的无循环顺序解析伤病、条款 cap 与最终 ContractOutcomeTable
6. 计算报酬、疲劳、outcome tags 和 ideology impacts
7. 计算任务后成员评价与提出方关系
8. 返回完整、待应用的 ContractResolution
```

任一步失败不得修改输入或正式状态，也不得返回部分可提交结果。

## Baseline fixture requirements

用内存 fixture 完整表达：

1. `contract_north_road_evacuation`
2. `contract_deploy_binding_towers`
3. `contract_recover_dragon_corpses`

三者必须通过同一 Definition、Plan、Resolver 和 ClauseEvaluator 结算。禁止：

- `match contract_id` 选择专用逻辑；
- 可执行字符串；
- fixture 专用子类；
- 为手算样例绕过 seed 或伤病规则。

`.tres` 数据化留给后续任务。

## Out of scope

- CampaignState/StateChange 的实际提交
- Offer 的生成、关系期限/报酬加成和实例化规则求值
- 合同拒绝、倒计时、过期、NPC 完成和恶化
- 阵营行动、世界问题、进度钟和触发器
- `.tres`、DataCatalog、UI、消息、存档
- 多队执行、逐回合战斗、职业专用条款、隐藏条款

## Focused tests

至少覆盖：

1. 四名不同可用英雄、严重伤病、低士气 Opposed、补给数量/tag 和 Approach 白名单。
2. ideology/method/personal fit 的边界、原因和状态阈值。
3. 四人 attitude check modifier 的平均值。
4. 三种 Approach 对三类 profile 的数值和合同级效果只应用一次。
5. 补给只修正匹配 check，且不修改 SupplyDefinition。
6. 所有 TraceCondition 与 ContractEffect 白名单。
7. Mandatory/Bonus 约束、稳定求值顺序、多 cap 取最严格。
8. reward percent `-100/+100` 裁剪、最终报酬四舍五入和非负。
9. sponsor relation 裁剪到 `-20—+20`，且没有其他阵营结果。
10. 同一 method tag 跨多个 check 只参与一次任务后评价。
11. 事后向量和士气边界值。
12. 每名成员伤病 seed 隔离；改变成员 ID 不改变四个 check seed。
13. cautious/aggressive 重伤乘数在汇总后应用并裁剪。
14. 三份基准合同的手算结果、条款 cap、报酬和关系。
15. 同输入/seed 重复 100 次完整 Resolution 相等。
16. 输入 Definition、Plan、英雄和补给 fixture 全部保持不变。

## Acceptance tests

先运行所有 Task 004 focused tests，再运行：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

必须满足：

- 完整 suite 退出码 0；
- 三份基准合同不需要合同专用代码；
- 相同输入和 seed 重复 100 次完整结果与原因顺序一致；
- 结果包含四个 PhaseResult、ClauseResult、最终等级、报酬、成员疲劳/伤病/士气、提出方关系、世界待应用效果和原因；
- Resolver 不引用 scene tree、Autoload 或 CampaignState。

## Completion checklist

- [ ] Gate B 的每项规则都有 Accepted 文档章节。
- [ ] 三份基准合同共享同一代码路径。
- [ ] 无隐藏条款、专用投骰、合同 ID 分支或 executable string。
- [ ] 所有随机流显式且彼此隔离。
- [ ] 所有效果均 deferred，输入无修改。
- [ ] focused/full suite 实际运行。
- [ ] golden 差异未被自动接受。

## Expected report

- Gate B 采用的精确规则来源
- 修改文件和公开 API 变化
- 计划、态度、Approach、条款、报酬、疲劳、伤病与事后评价规则
- 三份基准合同 trace 摘要与手算差异
- focused/full 测试命令、退出码和结果
- 输入不变性、golden 差异、假设与剩余风险
