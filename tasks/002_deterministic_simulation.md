# Task 002 — Deterministic Domain Foundations

状态：Completed
里程碑：Milestone 1（基础部分）  
依赖：Task 001

## Goal

实现与场景树无关、可复用且确定性的领域基础：稳定 seed 派生、结构化原因、能力与价值值对象、英雄只读快照，以及四人队能力聚合。本任务不实现 `ContractResolver`。

## Required reading

- 根目录 `AGENTS.md`
- `docs/02_core_loop_and_rules.md` 第 3—7 节
- `docs/03_godot_architecture.md` 第 4、5、12、13、15 节
- `docs/04_data_model.md` 第 1、2.1—2.3、3.3、4.1 节
- `docs/15_staged_contract_resolution_rules.md` 第 4 节的 seed 要求
- `tasks/000_v0.1_execution_map.md`

## Preconditions

- Task 001 的完整 headless suite 通过。
- 实现必须能脱离 scene tree 直接实例化和测试。

## Allowed files

- `game/core/ids/**`
- `game/core/random/**`
- `game/core/result/reason_entry.gd`
- `game/domain/adventurers/**`
- `game/domain/contracts/capability_weights.gd`
- `game/domain/simulation/team_capability_calculator.gd`
- `tests/unit/test_seeded_random.gd`
- `tests/unit/test_capability_values.gd`
- `tests/unit/test_team_capability.gd`
- `tests/fixtures/adventurer_fixtures.gd`
- `tests/run_all.gd`

不得创建合同阶段、判定、Resolver、CampaignState 或 UI 文件。

## Required types

### CapabilityBlock

- 六个字段：`frontline`、`offense`、`scouting`、`support`、`arcana`、`discipline`。
- 每项合法范围为 0—100。
- 提供显式构造、读取、值相等和独立复制能力。
- 非法输入返回结构化验证失败或由明确构造边界拒绝；不要静默裁剪设计数据。

### CapabilityWeights

- 使用同一六维字段，非负。
- 总和必须在统一 epsilon 内接近 1.0。
- 提供与 `CapabilityBlock` 的确定性加权点积。
- 不提供运行时自动归一化，以免掩盖内容错误。

### IdeologyVector

- 五个字段：`protect_life`、`respect_authority`、`seek_knowledge`、`pursue_profit`、`taboo_tolerance`。
- 英雄基础价值合法范围为 -5—+5。
- 提供值相等、独立复制、逐维相加、逐维裁剪和点积。
- “英雄基础值范围”和“任务累计向量 -10—+10”必须通过不同构造/验证入口表达，不能让一个含糊 setter 同时承担两种语义。

### AdventurerDefinition / AdventurerState / AdventurerSnapshot

- Definition 与 State 字段遵循 `docs/04_data_model.md`，Definition 在运行时只读。
- `AdventurerSnapshot` 是结算输入所需的不可变投影，至少包含稳定 ID、能力、价值观、疲劳、士气、伤势、可用性和必要关系数据。
- 从 Definition 与 State 创建 Snapshot 时必须复制嵌套可变值，不能让计算过程改写共享 Resource。
- 不实现职业技能、成长、离队或完整关系图。

### ReasonEntry

- 字段与 `docs/04_data_model.md` 第 4.1 节一致。
- `visibility` 只允许 `player`、`debug`。
- 原因对象是数据，不负责拼接最终 UI 文本或打印日志。

### Stable seed derivation

- 提供基于显式基础 seed 和稳定标识片段的确定性派生函数。
- 不使用 `String.hash()`、Dictionary 遍历顺序、当前时间或全局随机函数作为跨运行稳定依据。
- 相同基础 seed 与相同有序片段必须得到相同 seed；片段边界必须无歧义。
- 提供用派生 seed 创建独立 `RandomNumberGenerator` 的入口，不共享可变 RNG 状态。

## Required calculation

四名成员对每个能力维度独立聚合：

```text
team_capability = highest_member * 0.55
                + second_highest * 0.25
                + average_of_remaining_two * 0.20
```

随后由 `CapabilityWeights` 计算：

```text
capability_match = sum(team_capability[i] * requirement_weight[i])
```

要求：

- 输入必须恰好四名不同成员。
- 聚合与输入成员顺序无关。
- 相同值的排序结果稳定。
- 计算器不得修改成员、能力块或权重。
- 不在此处加入疲劳、伤势、协同、态度、补给或随机修正。

## Out of scope

- `ContractDefinition`、`ContractPlan`、阶段、check、MissionContext
- `ContractResolver` 与任何分数等级
- `StateChange` 和 CampaignState 原子提交
- 疲劳/伤势到判定修正的数值映射
- 认可度、条款、Approach、补给和报酬
- `.tres` 加载、DataCatalog、UI 和存档

不得为未来功能增加返回零的 placeholder 方法或 TODO 公式。

## Focused tests

至少覆盖：

1. 六项能力和五项价值观的边界值与越界拒绝。
2. `CapabilityWeights` 负权重、总和不足和总和超出 epsilon 时失败。
3. 四人单维聚合与手算值一致。
4. 六维能力匹配与手算值一致。
5. 四人排列组合不改变聚合结果。
6. 少于/多于四人、重复成员 ID 均被拒绝。
7. 相同 seed 与片段重复 100 次得到相同派生 seed 和随机序列。
8. 改变一个片段只改变对应派生流，不消耗或改变其他 RNG。
9. 含非 ASCII 文本的稳定 ID 在重复进程中仍产生同一结果。
10. Snapshot 与值对象复制后，修改副本不影响源 Definition/State fixture。
11. `ReasonEntry.visibility` 非白名单值被拒绝。

## Acceptance tests

先运行 Task 002 focused tests，再运行：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

必须满足：

- 完整 suite 退出码 0；
- 同一输入和 seed 重复 100 次完全一致；
- 无 scene tree、Autoload 或 UI 依赖；
- 所有输入 fixture 在测试后与测试前值相等。

## Completion checklist

- [ ] 公共类型有静态类型标注。
- [ ] 没有全局随机函数和时间 seed。
- [ ] 没有临时态度或合同 API。
- [ ] Definition 及其嵌套值没有被修改。
- [ ] focused 与 full suite 均实际运行。
- [ ] diff 仅包含 Allowed files。

## Expected report

- 修改文件和公开 API
- seed 编码与派生规则
- 能力聚合手算样例
- focused/full 测试命令与结果
- Definition/State 不变性检查
- 假设和剩余风险
