# Task 005 — DataCatalog and Catalog Validation

状态：Completed
里程碑：Milestone 2（内容数据化）
依赖：Task 004、Gate C

## Goal

建立显式 ContentManifest、类型化 `.tres` authoring Resource、原子
DataCatalog 和 CatalogValidator。合法内容编译为 Task 001—004 已有的只读运行时
Definition；非法内容在进入游戏前返回带路径和字段的结构化错误。

## Required reading

- 根目录 `AGENTS.md`
- `docs/product/01_v0.1_product_spec.md`
- `docs/rules/02_core_loop_and_rules.md`
- `docs/architecture/03_godot_architecture.md` 第 4—7、13、15—16 节
- `docs/architecture/04_data_model.md` 第 1—2、5 节
- `docs/rules/contracts/15_staged_contract_resolution_rules.md` 第 4—5、9 节
- `docs/rules/campaign/19_content_catalog_state_and_situation_rules.md` 第 1—3、8 节
- Task 004 的实际 Definition、Resolver、fixture 和测试 API

## Allowed files

- `game/data/catalogs/**`
- `game/data/definitions/**`
- 当前缺失的只读运行时 Definition：
  - `game/domain/adventurers/trait_definition.gd`
  - `game/domain/contracts/contract_definition.gd`
  - `game/domain/factions/**`
  - `game/domain/situations/**` 中仅静态 Definition 类型
- 为支持深复制和编译所必需的现有 `game/domain/**/**_definition.gd`
- `tests/unit/test_data_catalog.gd`
- `tests/unit/test_catalog_validator.gd`
- `tests/fixtures/catalog_fixtures.gd`
- `tests/run_all.gd`

不得修改 `project.godot` 或注册 Autoload；不得创建正式游戏内容 `.tres`。

## Required behavior

### 1. ContentManifest

使用一个显式 manifest 声明稳定资源集合。至少支持：

- adventurer definitions
- trait definitions
- method tag definitions
- supply definitions
- faction definitions
- contract definitions
- situation、clock、phase、problem 和 ending definitions

不递归扫描目录，不通过文件名推断类型，不自动加载未列入 manifest 的资源。

### 2. Authoring/runtime boundary

每类 authoring Resource：

- 使用 `class_name`、`extends Resource` 和类型化 `@export` 字段。
- 字段与 `docs/architecture/04_data_model.md` 对应，不保存执行字符串。
- 提供纯编译入口，返回现有构造后只读的运行时 Definition。
- 编译时深复制数组、Dictionary 和子资源。
- 不传给 ContractResolver、SituationResolver 或 CampaignState。

不得为了 Inspector 写入而放宽现有运行时 Definition 的只读约束。

### 3. DataCatalog

DataCatalog `extends Node`，可独立 `new()` 测试，但本任务不注册 Autoload。

公开 API 至少包括：

```text
load_manifest(path: String) -> CatalogLoadResult
is_loaded() -> bool
get_adventurer(id) -> AdventurerDefinition
get_trait(id) -> TraitDefinition
get_method_tag(id) -> MethodTagDefinition
get_supply(id) -> SupplyDefinition
get_faction(id) -> FactionDefinition
get_contract(id) -> ContractDefinition
get_situation(id) -> SituationDefinition
get_all_<type>() -> typed Array
```

规则：

- 在临时索引中加载、验证和编译。
- 全部成功后一次性替换已发布索引。
- 失败时保留先前合法索引；首次失败保持 unloaded。
- getter 不修改或重新编译资源。
- `get_all` 使用稳定 ID 升序。
- ID 在整个 manifest 内全局唯一。

### 4. ValidationIssue

每个问题至少包含：

```text
code: StringName
resource_path: String
field_path: String
message: String
```

错误按 manifest 顺序、字段规则顺序、稳定 ID 排序。不得只返回 bool 或打印错误。

### 5. CatalogValidator

Task 005 必须实现：

- Stable ID、全局唯一 ID 和空引用检查。
- 所有基础数值范围。
- trait、method tag 和 taboo intensity 白名单。
- 五类补给的 tag、modifier 数量、条件和值。
- 合同四阶段顺序、唯一 stage/check ID、check type/profile。
- capability weight 与 result weight。
- 五档 CheckOutcome/ContractOutcome。
- Gate A/B 固定伤病修正、条款和效果白名单。
- Bonus 条款不得有 failure 后果或 cap。
- 所有已加载类型之间的引用完整性。
- authoring graph 中不得出现 null、共享可变编译结果或 executable string。

Task 008/010/013 将增加各自拥有的语义和发布完整性规则；不得为此添加关闭既有
验证的 mode。

### 6. Comments

按 `AGENTS.md` 为编译边界、原子发布、稳定排序和共享 Resource 防护添加简短
注释；公共 Catalog API 使用 `##` 文档注释。

## Focused tests

至少覆盖：

1. 合法内存 manifest 编译并可按 ID 查询。
2. getter 和 get_all 顺序稳定。
3. 全局重复 ID 跨类型也失败。
4. 缺失引用、null 子资源和非法 Stable ID 报告精确路径与字段。
5. Gate A/B、补给、条款、阶段和五档结果的非法边界。
6. 同一错误输入重复验证产生完全相同的 issue 顺序。
7. 第二次加载失败保留第一次合法目录。
8. 编译结果与 authoring Resource 不共享数组、Dictionary 或子资源。
9. 修改编译后的测试副本不改变 catalog 或源 Resource。
10. 编译出的基准合同结构可以构造 EffectiveContract 并进入现有 Resolver。

## Out of scope

- 正式 `.tres` 内容
- DataCatalog Autoload 注册
- CampaignState、事务和状态应用
- SituationResolver 规则执行
- Offer、阵营规划、周流程、消息、UI 和存档
- 发布版完整内容数量审计

## Acceptance tests

先运行 Task 005 focused tests，再运行：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

必须满足：

- 完整 suite 退出码 0。
- Task 001—004 golden 不变。
- 失败加载不发布部分 Catalog。
- 输入 authoring Resource 和运行时 Definition 均未被修改。

## Completion checklist

- [x] Gate C authoring/runtime 边界原样实现。
- [x] 没有目录扫描或 executable string。
- [x] 所有错误包含路径、字段和稳定错误码。
- [x] DataCatalog 未注册 Autoload。
- [x] focused/full suite 实际运行。
- [x] diff 不包含正式内容或后续服务。

## Expected report

- authoring Resource 与运行时 Definition 的边界
- Catalog 公开 API 和原子发布行为
- 已实现验证规则与明确延后规则
- 修改文件
- focused/full 测试命令、退出码和结果
- 输入不变性、假设和剩余风险
