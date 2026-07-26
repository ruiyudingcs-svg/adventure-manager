# 内容目录、状态事务与局势解析规则 V0.1

状态：Accepted（Gate C）
日期：2026-07-23

## 1. 文档职责

本文固定 Task 005—008 的实现边界，解决 `.tres` authoring、运行时只读
Definition、状态效果合并、补给消费和 SituationResolver 依赖之间的歧义。

本文不改变 Gate A/B 的合同数值，也不提前实现 Offer、阵营规划、周流程、
消息、UI 或存档。

## 2. Authoring Resource 与运行时 Definition

Task 001—004 已使用构造后只读的运行时 Definition 和值对象。为避免破坏这些
API，V0.1 不把现有运行时对象改造成可由 Inspector 任意修改的共享 Resource。

固定数据流：

```text
ContentManifest.tres
→ typed *DefinitionResource authoring graph
→ CatalogValidator
→ compile
→ immutable runtime *Definition graph
→ DataCatalog atomic publish
```

规则：

- `.tres` 只保存带 `@export` 字段的类型化 authoring Resource。
- authoring Resource 不进入 ContractResolver、SituationResolver 或 CampaignState。
- Catalog 编译结果继续使用现有构造后只读的运行时 Definition。
- 编译必须深复制嵌套数组、Dictionary 和子资源；运行时对象不得与 authoring
  Resource 共享可变集合。
- 使用一个显式 `ContentManifest.tres` 声明资源集合和稳定加载顺序，不通过递归
  目录扫描发现内容。
- DataCatalog 先在临时索引中加载、校验和编译；全部成功后才替换已发布目录。
- 失败不得发布部分目录，也不得清空先前合法目录。
- 每个错误包含资源路径、字段路径、稳定错误码和可读说明。
- ID 在整个 manifest 内全局唯一，防止 WorldEffect、StateOperation 和消息引用
  产生类型歧义。

Task 005 创建 DataCatalog 类型但不注册 Autoload。Task 006 提供合法默认 manifest
后，才允许把 `DataCatalog` 注册为唯一新增 Autoload。

## 3. CatalogValidator 边界

Task 005 实现当前已加载类型的完整完整性校验：

- ID、范围、枚举白名单和嵌套结构。
- manifest 内已经存在类型之间的引用。
- Gate A/B、四阶段合同、五档结果、条款、补给和 method tag 规则。
- authoring Resource 到运行时 Definition 的编译结果不为空且不共享可变数据。

完整剧本覆盖检查按拥有该内容的后续任务加入：

- Task 008 增加局势、钟、问题、触发器与结局的语义检查。
- Task 010 增加阵营行动表和 target lock 检查。
- Task 013 增加 12 合同、9 问题、fallback Agenda 和四结局的发布完整性检查。

这不是可绕过验证的运行模式。任何已经实现并加载的类型都必须通过当时已有的
全部规则；后续任务只能增加验证规则，不能关闭既有规则。

## 4. 补给购买与消费

V0.1 不保存补给库存，不实现数量、堆叠、补货、价格波动或市场。

```text
supply_cost_total =
    sum(selected SupplyDefinition.cost)
```

规则：

- 计划使用最多两个不同补给 ID。
- 计划确认和周末提交必须检查 `GuildState.gold >= supply_cost_total`。
- 合同成功生成完整 Resolution 后，原子事务从 gold 扣除
  `supply_cost_total`。
- `consumed_supply_ids` 作为合同历史和原因记录，不对应持久库存删除。
- 合同结算或周末事务失败时不扣金币。
- 不得同时扣库存和金币，也不得在计划预览、Resolver 和周末事务中重复扣费。

ContractResolution 必须锁定 `supply_cost_total` 和 `consumed_supply_ids`，使提交
不需要重新读取可变计划或重新计算价格。

## 5. StateOperation 与 StateChange

待应用意图和已应用审计必须分离。

```text
StateOperation
- target_kind: StringName
- target_id: StringName
- field_id: StringName
- operation: StringName
- value: Variant
- reason_code: StringName
- source_order: int

StateChange
- target_id: StringName
- field_path: String
- old_value: Variant
- new_value: Variant
- reason_codes: Array[StringName]
```

`StateOperation.operation` 白名单：

- `add_int`
- `set_id`
- `add_unique`
- `remove_unique`
- `append_record`

StateOperation 只通过 `target_kind + field_id` 白名单 dispatch 应用，不允许使用
任意 Object 属性路径、`set()`、表达式字符串或反射执行世界规则。

合并规则：

- 数值按 `target_kind + target_id + field_id` 求和后裁剪一次。
- 集合添加和删除分别稳定去重；同一批对同一值同时添加和删除是冲突。
- 相同 `set_id` 终值合并；不同非空终值是冲突。
- append record 使用稳定 record ID 去重；同 ID 不同内容是冲突。
- reason code 按 `source_order`、再按稳定 reason code 保存。
- 任一非法 target、field、operation、引用或冲突使整批失败。

CampaignTransaction 在 CampaignState 深副本上应用操作，生成 StateChange 并验证
完整临时状态。成功时返回新 CampaignState；失败时原状态、历史、消息和所有
Definition 保持不变。

## 6. SituationResolver 依赖

SituationResolver 只读取：

- week index
- SituationDefinition
- SituationState
- WorldProblemState
- WorldEventState
- contract history 中的稳定完成事实
- 本边界待应用的世界 StateOperation

公开解析入口按 `current_week + definition + state + world_events +
contract_history + base_world_operations + boundary` 接收输入。返回值只包含 Resolver
新生成的世界操作；调用者必须把原始 `base_world_operations` 与返回操作合成一个
完整批次，并且只调用一次 CampaignTransaction。`boundary` 只允许
`week_start` 和 `week_end`。

它不得读取成员、队伍、金币、补给、成员关系或阵营关系。V0.1 世界条件白名单
因此不包含 `faction_relation_gte`，世界效果白名单也不包含
`modify_faction_relation`。合同提出方关系仍由 ContractResolution 和 Task 007
事务投影处理。

## 7. 单批局势解析顺序

每个周边界恰好运行一次：

```text
1. 在临时 CampaignState 上应用本边界基础世界效果
2. 若为周开始边界，合并并应用一次 passive ClockDelta
3. 结算已经越过期限的 active 问题
4. 从当前快照确定全部合格 SituationTrigger
5. 按 priority 降序、稳定 trigger ID 升序应用这一批一次
6. 统一处理问题激活、解决和关闭
7. 统一求值全部 EndingDefinition
8. 按 priority 降序、稳定 ending ID 升序选择最多一个结局
9. 进入唯一 terminal phase
10. 交给 CampaignTransaction 完整验证和原子提交
```

第 4 步锁定批次后，本批效果新满足的其他触发器不追加到本批；它们留到下一次
周开始或周末边界。`once` 触发器只有在事务成功提交后才写入
`triggered_rule_ids`。

新游戏第 1 周直接使用 Definition 初值，不额外运行被动变化。被动变化从进入
第 2 周的边界开始。

CatalogValidator 对该边界再保证：每个局势恰好引用一个 terminal phase；问题紧迫度
规则只使用 `clock_gte`、`clock_lte` 和 `phase_is`；同一问题、同一 clock 的紧迫度
数值区间不得重叠；每个问题的恶化效果至少创建一个稳定世界事件。世界条件和效果
继续排除阵营关系读取与写入。

Task 008 的第 15 周 accepted fixture 为覆盖完整触发链，使用 `+30`
`settlement_destruction` 作为测试专用代价。该值不属于正式巨龙内容，不得在
Task 013 发布内容时当作生产平衡值；正式数值仍须以届时获准的剧本内容为准。

## 8. Task 005—008 阶段门

```text
Task 005 DataCatalog / CatalogValidator
→ Task 006 首批 .tres 与三份基准 golden
→ Task 007 CampaignState / StateOperation / 原子事务
→ Task 008 SituationResolver / 问题 / 触发器 / 结局
```

Task 005 完成前不得手写正式 `.tres` 内容。Task 007 完成前不得让
SituationResolver 原地修改 CampaignState。Task 008 完成后才根据真实世界 API
细化 Task 009—013。
