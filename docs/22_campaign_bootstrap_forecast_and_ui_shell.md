# 新战役初始化、合同预测与应用外壳规则 V0.1

状态：Accepted（Gate F）  
日期：2026-07-25

## 1. 文档职责

本文固定第四批 UI 与存档实现开始前必须统一的三项边界：

1. 唯一 V0.1 战役如何从静态内容构造第 1 周规划状态。
2. 合同准备界面如何给出有用但不泄漏真实锁定结果的预测。
3. 四个主要界面如何共享 Football Manager 风格的应用外壳。

本文不改变合同、周流程、局势、阵营行动或 Gate A—E 的公式。发生冲突时，产品
范围仍以 `docs/01_v0.1_product_spec.md` 为上限，既有 Accepted 领域规格继续负责
各自公式。

## 2. CampaignSetupDefinition

V0.1 增加一个只读 `CampaignSetupDefinition`，由显式 ContentManifest 发布：

```text
id: StringName
situation_definition_id: StringName
adventurer_ids: Array[StringName]
faction_setups: Array[FactionSetupDefinition]
initial_active_problem_ids: Array[StringName]
initial_gold: int
initial_reputation: int
initial_base_cohesion: int
weekly_maintenance: int
```

```text
FactionSetupDefinition
- faction_id: StringName
- initial_relation: int
- initial_influence: int
```

`CampaignSetupDefinition` 是静态初始化内容，不是存档状态，也不允许包含 Node、
Callable、脚本字符串或运行时对象。CatalogValidator 必须校验所有引用、唯一性和
数值范围；DataCatalog 只发布 detached runtime Definition。

正式 V0.1 manifest 恰好发布一个 setup：

```text
id = campaign_setup_dragon_invasion_v0_1
situation_definition_id = situation_dragon_invasion_v0_1
initial_gold = 250
initial_reputation = 20
initial_base_cohesion = 50
weekly_maintenance = 25
```

`adventurer_ids` 恰好显式列出文档 04 的八名成员。三个 faction setup 均使用：

```text
initial_relation = 0
initial_influence = 60
```

开局 active 问题固定为：

```text
problem_eastern_road_blocked
problem_dragon_location_unknown
problem_dragon_assault_pressure
```

## 3. 新战役构造

`CampaignBootstrapper` 是可独立测试的纯 `RefCounted` 服务。它接收 detached setup、
所引用的全部 Definition 和显式 `campaign_seed`，不得隐式读取 Autoload、时间或
全局随机源。

构造顺序固定为：

1. 验证 setup 和全部引用闭包。
2. 创建内部 `week_index = 0` 的 CampaignState。
3. GuildState 使用第 2 节四项固定值。
4. 八名成员使用 fatigue 0、morale 50、无伤、recovery 0、growth 0、available、
   空 relationship delta、两个近期计数 0。
5. 三个阵营使用 setup 中的 relation 与 influence。
6. SituationState 使用 SituationDefinition 的 initial phase 和五条钟初值。
7. 九个问题全部存在；三项开局问题为 active、`opened_week = 1`，
   `response_deadline_week = 1 + response_window_weeks - 1`，其余为 inactive。
8. `starts_unlocked` 合同进入稳定排序的 unlocked 集合。
9. 历史、事件、Offer、计划、行动承诺和消息均为空，拒绝周为 -1。
10. 调用 WeekFlowCoordinator 的第 1 周特殊开场，原子产生三个合同栏和消息，
    成功后才发布正式状态。由于三个阵营开场都没有 pending Offer，第 1 周不产生
    常规直接行动承诺。

第 1 周不得应用维护、恢复、被动钟变化或旧合同生命周期。任一步失败都不得发布
部分 CampaignState。

生产 API 必须显式接收 seed。界面可以在新游戏对话框生成一次 seed，但生成后必须
立即作为普通整数传入并保存；领域层不得读取系统时间。测试使用固定 seed。

## 4. 会话阶段与提交边界

GameSession 只允许以下阶段：

```text
no_campaign
planning
resolution_review
ended
```

- `planning` 是唯一允许保存的阶段，包括已接受、尚未结算的 active plan。
- 一次结束本周命令最多生成一次 WeekResolution；成功结果保存在 GameSession 的
  临时只读 review snapshot 中。
- UI 刷新、切换选项卡或重新进入 Resolution 场景只读取该 snapshot，不再次调用
  Resolver。
- 玩家确认结果后才打开下一周；若已产生 ending，则进入 `ended`。
- `resolution_review` 不保存半结算结果。重新加载上一个 planning 存档后，锁定
  seed 必须重现同一结算。

GameSession 持有唯一正式 CampaignState，但不包含合同、维护、阵营或世界公式。
对 Presenter 和测试只返回 detached snapshot。

## 5. 合同预测

### 5.1 目标

预测必须帮助玩家比较队伍、补给和 Approach，但不能显示真实 locked seed 的精确
结果，也不能在 UI 中复制 Resolver 公式。

`ContractForecastService` 接收同一 EffectiveContract 与 ContractPlan，复用正式
ContractResolver 执行 64 个只读样本。它不写 CampaignState，不保存预测值。

### 5.2 样本 seed

第 `i` 个样本 seed 使用：

```text
StableSeed.derive(
    0,
    ["contract_forecast", offer_instance_id, plan_content_signature, i]
)
```

`plan_content_signature` 由 Approach、稳定排序的四个 member ID 和稳定排序的
supply ID 构成；同一选择不因 UI 点击顺序产生不同 signature。`i` 为 0 至 63。
若摘要恰好等于 Offer 的 locked resolution seed，则追加稳定递增的
`"retry_1"`、`"retry_2"`……片段重新派生，直到不同；真实 locked seed 永远不进入
预测样本。

相同 Offer 和 plan 必须产生相同预测。改变四人、补给或 Approach 必须改变 plan
signature，允许产生不同预测。

### 5.3 玩家可见结果

64 个 final tier 按 `Severe < Failure < Partial < Success < Exceptional` 排序。
预测区间取排序后索引 6 与 57，即近似第 10 和第 90 百分位，只显示：

```text
likely_tier_low
likely_tier_high
```

界面使用“较可能结果区间”，不得称为保证、精确概率或真实结果。不得显示：

- 真实 locked seed 或真实四阶段结果
- 精确 AI priority
- 全部五档世界效果表
- 被排除候选或内部 ID 决胜

每名成员的态度仍使用正式规划态度计算。伤病取 64 个 MemberOutcome
`any_injury_chance` 的算术平均并 `round_away` 一次，只显示：

```text
0..14  -> 低
15..29 -> 中
30..49 -> 高
50..100 -> 严重
```

界面不显示该平均值或伪精确概率。条款根据 64 个 ClauseResult 的满足覆盖显示：

```text
64/64        -> 预计满足
45..63/64    -> 有利
20..44/64    -> 不确定
1..19/64     -> 高风险
0/64         -> 预计冲突
```

界面不显示样本计数。成员价值观警告每份合同最多显示两个，继续使用 player 可见
原因的稳定顺序。

### 5.4 缓存

Presenter 可以按 `offer_instance_id + plan_content_signature` 缓存本次场景生命周期
内的 ForecastViewData；缓存不是权威状态，不写存档。刷新缓存不得消耗真实随机源。

## 6. 应用外壳

桌面端使用三层导航：

1. 左侧栏负责四个全局目的地：Dashboard、Contracts、Roster、Resolution。
2. 标题下方只允许一行当前页面的上下文选项卡。
3. 顶部工具栏显示页面标题、周数、Gold、Reputation、未读消息、保存入口和唯一
   主动作。

Resolution 在没有 review snapshot 时禁用；战役 ending 后进入完整结局页。
Dashboard 的 Inbox 是页面选项卡，不新增第五个主要界面。Roster 的关系与近期记录
也是子选项卡，不建立独立全局页面。

顶部主动作按会话阶段固定为：

- planning 且无 active plan：`结束本周`，必须二次确认本周不接合同。
- planning 且有 active plan：`派遣并结束本周`。
- resolution_review：`进入第 N+1 周`。
- ended：隐藏。

最低设计视口为 1280×720；还必须检查 1600×900 和 1920×1080。V0.1 借用管理
游戏的信息架构，不复制 Football Manager 的资源、品牌、具体视觉资产或多层菜单
复杂度。

## 7. UI 所有权

- Screen 只渲染 ViewData、收集输入和发出用户意图。
- Presenter 读取 detached CampaignState 与 detached Definition，生成稳定 ViewData。
- Controller 把 UI draft 转换为已有 typed command。
- UI 不计算剩余回合、态度、风险、工资、紧迫度、合同 tier 或世界效果。
- signal 只作通知；不得建立全局事件总线或隐藏多步控制流。
- 玩家输入错误返回可显示 validation issue，不使用 assert 结束游戏。

## 8. Gate F 验收

1. 同一 setup 与 seed 两次生成相同第 1 周状态、三个 Offer、消息和承诺。
2. 新战役初值与第 2 节完全一致，第 1 周没有维护或被动变化。
3. Setup 引用缺失或非法时不发布部分会话。
4. 相同 Offer/plan 的 64 样本预测完全一致，且不使用真实 locked seed。
5. UI 刷新不改变预测或正式结果。
6. 四屏导航、上下文选项卡和顶部主动作没有重复职责。
7. 所有 Presenter 输入和输出与正式 CampaignState、Definition 隔离。
8. 新增规则不改变 Task 001—013 的领域 golden。
