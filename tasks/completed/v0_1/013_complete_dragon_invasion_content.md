# Task 013 — Complete Dragon Invasion V0.1 Content

状态：Completed
里程碑：Milestone 3（完整剧本内容）
依赖：Task 005—012、Gate E

## Goal

使用已经稳定的 authoring Resource、CatalogValidator、Offer、Faction Planner、
WeekFlow 和消息 API 发布“北境村庄巨龙灾变”的完整 V0.1 内容：8 名英雄、
12 份合同、3 个阵营、5 条钟、9 个问题、14 项行动、4 个结局及其触发闭包。

## Gate E — Accepted remaining contract numerical definitions

Gate E 已于 2026-07-25 Accepted，权威数值见
`docs/rules/contracts/21_remaining_contract_numerical_rules.md`：

- 九份合同的 reward、fatigue、risk、intent ideology 和供应白名单已经固定。
- 36 个 check 的 ID、类型、难度、权重、能力权重、profile、modifier 和 cap
  已经固定。
- 五档 context、伤病风险、世界效果、tags、ideology 和原因 ID 规则已经固定。
- 27 份条款的条件、奖惩、cap 与 ideology 已经固定。
- 三类 final outcome profile 已经固定，且不重复添加数值型世界钟效果。
- 九份合同的 `instantiation_rules` 明确为空。

实现必须保持 `docs/09` 的代表性 Success/Failure 净 delta。共享 authoring 表必须
展开并显式写入 `.tres`，不得在 Resolver 中实现 Gate E 展开公式。三份基准合同
仍由 `docs/rules/contracts/10_baseline_contracts.md` 负责，golden 变化必须另行人工批准。

## Required reading

- 根目录 `AGENTS.md`
- `docs/product/01_v0.1_product_spec.md` 第 5、7、9—13 节
- `docs/architecture/04_data_model.md` 全部 Definition 与验证章节
- `docs/content/contracts/09_contract_template_catalog.md`
- `docs/rules/contracts/10_baseline_contracts.md`
- `docs/rules/campaign/11_contract_proposal_generation.md`
- `docs/rules/campaign/13_unhandled_contract_and_npc_results.md`
- `docs/rules/campaign/14_week_flow_faction_commitments_and_messages.md`
- `docs/rules/contracts/15_staged_contract_resolution_rules.md`
- `docs/content/dragon_invasion/17_dragon_invasion_scenario_spec.md`
- `docs/content/dragon_invasion/18_dragon_invasion_problem_and_action_catalog.md`
- `docs/rules/campaign/19_content_catalog_state_and_situation_rules.md`
- `docs/rules/contracts/21_remaining_contract_numerical_rules.md`
- Task 009—012 的真实 authoring、Catalog 和 headless week API

## Allowed files

- `game/data/definitions/v0_1/**`
- `game/data/catalogs/v0_1_content_manifest.tres`
- `game/data/catalogs/catalog_validator.gd`，仅增加发布完整性规则
- 内容 fixture/golden、Task 013 tests 和 `tests/run_all.gd`
- 权威内容文档，仅在人工已接受数值需要同步时修改

除修复被完整内容暴露的明确阻塞缺陷外，不修改 Resolver、Planner、Transaction、
WeekFlow 或 Message 公式。不得改 Autoload、save schema、UI 或 GameSession。

## Required published content

### Existing content to preserve

- 8 AdventurerDefinition
- 8 TraitDefinition
- 5 SupplyDefinition
- 3 FactionDefinition
- 5 ClockDefinition
- 4 SituationPhaseDefinition
- 三份基准 ContractDefinition 及其 clauses/method tags

三份基准合同先应用已定案的内容锚点修订：

- north road 的问题锚点为 `problem_evacuating_civilians`。
- binding towers 仅 final window 可用，Severe `target_killed` 创建
  `event_dragon_killed` 且保持高毁坏代价。
- corpse recovery 保留最低污染代价；Task 017 调平后的 golden 为 Partial。

### Content to add/complete

- ContractDefinition 总数恰好 12。
- WorldProblemDefinition 总数恰好 9。
- FactionActionDefinition 总数恰好 14：
  - free alliance 5
  - arcane guild 5
  - necrotic collective 4
- EndingDefinition 总数恰好 4。
- 完整 Situation trigger、problem activation/resolution/escalation、contract unlock、
  phase transition 和第 15 周保底杀龙规则。
- 所有合同/行动/问题/事件/target lock/agenda/method/clause 引用闭包。

不得增加第 10 个问题、第 13 份合同、第五个结局或第二个局势。

## Authoring rules

- 所有正式规则来自显式 manifest 中的 `.tres`，不得在 `.gd` 按 ID 补逻辑。
- authoring Resource 编译后与 runtime Definition 不共享可变子对象。
- 事件键全局语义唯一；同一问题恶化只创建一份事件。
- 同一问题不同 target lock 的效果必须可交换合并，不直接写问题终态。
- settlement destruction 和 villagers evacuated 不得有负 delta。
- 死灵三类合同成功也必须增加 necrotic corruption。
- 只有 final window 的合法内容能创建 `event_dragon_killed`。
- 三个 fallback 开局合法、跨全部非结局阶段、target lock 不同。

## Catalog publication validation

CatalogValidator 增加发布级检查：

1. 精确内容数量、必需 ID 和单一 Situation。
2. 三个阵营各自 action 所有权与 weekly_action_ids 完整。
3. 九问题的 tags、合同白名单和反向锚点一致。
4. 七个 NPC completion action 的 sponsor、lock、cost 和引用一致。
5. 三个 fallback 在第 1 周合法且结果固定为道路侦察、定位巢穴、尸体回收。
6. 每个非结局阶段每阵营至少一个可达合同与可能合法行动；无行动目标允许等待。
7. 每个问题一次性激活、唯一 escalation event 和至少一个解决路径。
8. 四结局条件、priority、terminal phase 和第 15 周保底引用合法。
9. 所有 event/clock/problem/contract/action/clause/method tag 引用存在。
10. 三份基准合同 golden 不变。

这些规则只增加到正式发布 validator；不得新增跳过完整性检查的 production mode。
测试可使用独立最小 manifest 验证单个服务。

## Scenario tests

### Content integrity

- 默认 manifest 完整加载且 issues 为空。
- 精确数量、ID、所有者、引用和稳定 get_all 顺序。
- 每个 Definition/Resource 深复制隔离。
- 12 合同全部能构造 Offer、EffectiveContract 和合法四阶段输入。

### Contract calibration

- 三份基准 golden：Success/242/+9/12、Exceptional/390/+13/14、
  Partial/234/+2/16。
- 其余九份合同分别验证四 check 全 Success/Failure 的净世界 delta 与 `docs/09`
  第 11 节一致。
- 不允许用 final outcome 额外重复累计代表性 delta。
- 相同 seed 重复 100 次完全一致。

### World and planning

- 第 1 周三个 fallback 精确出现且 lock 不冲突。
- 九问题 activation、resolution、deadline escalation 各走一次。
- 14 行动的 cost/effect/event 与 `docs/18` 一致。
- 七个 npc_completed 和所有后备 expired/escalated 路径。
- phase 在 week 5/9 转移，结局后停止 Offer/行动。

### Ending paths

使用真实 WeekFlow、Offer、Planner 和 Content，不调用测试专用 `+30 destruction`
捷径，分别证明：

- mass evacuation 在 week 10—12 可达。
- arcane capture 在 week 10—13 可达。
- necrotic catastrophe 在 week 10—14 可达。
- dragon slain at cost 可由晚期合同或 week 15 fallback 到达。

四条路径测试锁定输入选择和 seed；它们是内容可达性 golden，不是自动平衡器。
任何 golden 差异先报告人工审查。

## Out of scope

- 第 13 份合同、第 10 个问题、额外英雄/阵营/局势/结局
- 动态合同生成、程序化文本、NPC 队伍或行动冲突
- UI、本地化成品文本、SaveService 和导出
- 修改 Gate E 数值或把 authoring 展开公式加入运行时

## Acceptance tests

1. 运行内容/Catalog focused tests。
2. 运行 12 合同与四结局 path tests。
3. 运行 Task 009—012 集成回归。
4. 运行完整 suite。

## Completion checklist

- [x] Gate E 已 Accepted，九份合同没有猜测数值。
- [x] 默认 manifest 发布精确 V0.1 内容闭包。
- [x] 12/9/14/4 数量和所有引用通过 CatalogValidator。
- [x] 三份既有 golden 未自动改写。
- [x] 四种结局由真实 10—15 周路径可达。
- [x] 没有 `.gd` 合同 ID 分支或 V0.2 框架。
- [x] focused/path/full suite 实际运行。

## Expected report

- 各内容类型数量、路径和稳定 ID
- 三份基准与九份新增合同校准结果
- 九问题、十四行动和七个 NPC completion 审计
- 四条结局路径的周数与关键钟 trace
- CatalogValidator 发布规则
- focused/path/full 测试命令、退出码和结果
- 人工审查的任何 golden 差异
