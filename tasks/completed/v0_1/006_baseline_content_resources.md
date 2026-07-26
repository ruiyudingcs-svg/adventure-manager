# Task 006 — Baseline Content Resources

状态：Completed
里程碑：Milestone 2（内容数据化）
依赖：Task 005、Gate C

## Goal

使用 Task 005 的 authoring Resource 和 ContentManifest 写入首批正式 `.tres`
内容，把三份基准合同从大型构造 fixture 迁移为数据驱动输入，并在合法默认
manifest 存在后注册 DataCatalog Autoload。

## Required reading

- 根目录 `AGENTS.md`
- `docs/architecture/04_data_model.md`
- `docs/content/contracts/09_contract_template_catalog.md`
- `docs/rules/contracts/10_baseline_contracts.md`
- `docs/rules/contracts/15_staged_contract_resolution_rules.md`
- `docs/content/dragon_invasion/17_dragon_invasion_scenario_spec.md`
- `docs/content/dragon_invasion/18_dragon_invasion_problem_and_action_catalog.md`
- `docs/rules/campaign/19_content_catalog_state_and_situation_rules.md`
- Task 005 实际 Catalog API 和验证测试

## Allowed files

- `game/data/definitions/**`
- `game/data/catalogs/v0_1_content_manifest.tres`
- `project.godot`，仅允许注册 `DataCatalog`
- `tests/fixtures/baseline_contract_fixtures.gd`
- `tests/fixtures/catalog_content_fixtures.gd`
- `tests/unit/test_baseline_content.gd`
- `tests/unit/test_complete_contract_resolution.gd`
- `tests/run_all.gd`

除修复 Task 005 明确阻塞缺陷外，不修改 Resolver、Catalog 或验证公式。

## Required content

### 1. Characters and policy

- 8 名 `docs/architecture/04_data_model.md` 指定的首批成员。
- cautious、ambitious、compassionate、ruthless、loyal、independent、
  scholarly、devout 八个 trait。
- 三份基准合同全部引用的 method tags，包含正确 ideology vector 和
  taboo intensity。
- medical、scouting、protection、arcane_binding、rations 五个补给。

### 2. Sponsors and reference closure

- 自由冒险者联盟、魔法工会、死灵集团三个基础 FactionDefinition。
- 三份基准合同引用的三个 WorldProblemDefinition。
- 五条 ClockDefinition 和四个 phase ID。
- 为上述对象形成合法引用闭包所需的最小 SituationDefinition。

这只是首批可验证内容，不要求完整 weekly action table、9 个问题或 12 份合同。
Task 013 负责发布完整性。

### 3. Baseline contracts

- `contract_north_road_evacuation`
- `contract_deploy_binding_towers`
- `contract_recover_intact_corpses`

阶段、难度、权重、结果、条款、补给、价值影响和世界效果严格来自
`docs/rules/contracts/10_baseline_contracts.md`。不得在 `.gd` 中按合同 ID 补逻辑。

## Data flow

```text
v0_1_content_manifest.tres
→ DataCatalog
→ ContractDefinition
→ test-only locked Offer projection
→ EffectiveContract
→ existing ContractResolver
```

test-only projection 只填写当前尚未由 Task 009 拥有的 Offer 锁定字段，不得复制
合同阶段、条款或结果数据。

## Golden requirements

固定 seed 和同一队伍：

| contract | final tier | reward | sponsor relation | fatigue |
|---|---|---:|---:|---:|
| north road evacuation | Success | 242 | +9 | 12 |
| binding towers | Exceptional | 390 | +13 | 14 |
| corpse recovery | Partial | 234 | +2 | 16 |

尸体回收必须保留保密 Mandatory 失败将 Exceptional operational tier 封顶为
Partial 的原因链。

## Autoload

本任务可以且只可以新增：

```text
DataCatalog = res://game/data/catalogs/data_catalog.gd
```

Autoload 使用固定默认 manifest 路径。加载失败时禁止开始新游戏并保留完整问题
列表；不得创建 GameSession、SceneRouter 或 EventBus。

## Focused tests

至少覆盖：

1. 默认 manifest 全部加载且 CatalogValidator 无错误。
2. 内容数量和关键稳定 ID 符合本任务清单。
3. 三份合同由 `.tres` 加载，不由 fixture 重建 Definition graph。
4. 三份完整 golden 与文档一致。
5. 同一内容和 seed 重复 100 次 Resolution 相等。
6. 另一个测试 `.tres` 只改变一个难度或报酬时，结果随数据变化且 Resolver 不变。
7. 三份合同共享同一 projection 和 Resolver 路径。
8. 读取一个 Definition 后不能改变其他 Definition 或源 `.tres`。
9. DataCatalog Autoload 在 headless 主场景中成功加载默认 manifest。

## Out of scope

- 剩余九份合同和六个世界问题
- 完整阵营行动表和 fallback Agenda
- CampaignState、SituationResolver 和周流程
- 正式 Offer 实例化、关系档和期限
- UI、消息和存档

## Acceptance tests

先运行 focused tests，再运行完整 suite。不得自动更新 golden；任何差异先报告。

## Completion checklist

- [x] 所有正式内容来自 `.tres` 和显式 manifest。
- [x] 三份 golden 经数据路径通过。
- [x] 无合同 ID 分支或 fixture 专用 Definition 子类。
- [x] 只新增 DataCatalog 一个 Autoload。
- [x] 默认 Catalog 启动验证通过。
- [x] focused/full suite 实际运行。

## Expected report

- 内容数量、路径和稳定 ID
- fixture 到 `.tres` 的迁移方式
- 三份 golden trace 摘要
- Autoload 变化
- focused/full 测试结果
- 未进入首批内容的明确范围
