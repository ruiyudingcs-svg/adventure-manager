# 巨龙入侵剧本规格 V0.1

状态：Accepted（TODO 21B—21D）  
日期：2026-07-22

## 1. 文档职责

本文是“北境村庄巨龙灾变”局势阶段、结局、阵营目标和五条进度钟的单一权威来源，完成 `docs/16_dragon_invasion_scenario_content_plan.md` 的 TODO 21B、21C 与 21D。

世界问题、阵营直接行动和合同审计已经在 `docs/18_dragon_invasion_problem_and_action_catalog.md` 定案，并引用本文的 ID、阈值和方向。后续若根据实现测试修订上游阈值，必须先修改本文，再修改问题与合同目录。

阵营目标树只用于内容设计、Agenda 配置、界面说明和覆盖审计，不新增运行时 `GoalState`、剧情树或目标求解器。运行时仍然只使用现有进度钟、世界问题、事件、合同、阵营行动和结构化规则。

## 2. 开局世界快照

第 1 周首次进入规划界面时使用以下事实：

- `current_week = 1`。
- `current_phase = phase_early_crisis`。
- 巨龙存活、未被束缚，且尚未定位临时巢穴。
- 北境已经遭受第一次龙袭，部分居民自行逃离，聚落存在初始毁坏与尸体污染。
- 自由冒险者联盟正在组织救援；魔法工会开始追踪巨龙；死灵集团公开身份仍然模糊，但已经在回收战场残留。
- 开局 active 问题固定为 `problem_eastern_road_blocked`、`problem_dragon_location_unknown` 和 `problem_dragon_assault_pressure`。其紧迫度、期限与恶化效果见 `docs/18_dragon_invasion_problem_and_action_catalog.md`。
- 五条钟使用第 6 节的初值。新游戏初始化不额外结算一次被动变化；被动变化从第 1 周结束、进入第 2 周的边界开始，每个周边界恰好应用一次。

## 3. 局势阶段

阶段只表达危机时间窗口并控制合同、行动和问题的可用范围，不承担阵营目标进度。目标进度由钟、事件和问题状态表达。

| phase ID | 周数 | 含义 | 内容重点 |
|---|---:|---|---|
| `phase_early_crisis` | 1—4 | 灾变初期 | 路线侦察、定位巨龙、初步救援与辨认污染 |
| `phase_open_conflict` | 5—8 | 全面危机 | 大规模撤离、样本收集、战线防守与污染扩散 |
| `phase_final_window` | 9—15 | 最终窗口 | 束缚网络、反仪式、最终撤离和巨龙死亡风险 |
| `phase_ended` | — | 局势结束 | 不再生成合同、问题或阵营行动 |

阶段转移固定为：

```text
phase_early_crisis AND week_gte 5
→ phase_open_conflict

phase_open_conflict AND week_gte 9
→ phase_final_window

ending selected
→ phase_ended
```

阶段不因单条钟提前跳转。事件和阈值可以在当前阶段内提前解锁具体问题或合同，但不能跳过阶段。这样可以保证所有对局都有早、中、晚三个可预测的内容窗口。

## 4. 结局定义

### 4.1 稳定选择规则

每次周边界完成合同与阵营行动效果合并、应用一批世界触发器并结算问题后，统一检查全部 `EndingDefinition`：

1. `all_conditions` 必须全部成立。
2. `any_conditions` 为空时不追加限制；非空时至少一项成立。
3. 同时合格时按 `priority` 降序选择一个；仍同分时按 EndingDefinition ID 升序。
4. 只写入一个 `ending_id`，随后把阶段改为 `phase_ended`。
5. `set_ending` 类型的触发器效果只增加一个结局候选，不得绕过上述稳定选择顺序直接覆盖结局。

### 4.2 四个结局

| priority | ending ID | 精确条件 | 世界含义 |
|---:|---|---|---|
| 400 | `ending_necrotic_catastrophe` | `week_gte 10` 且 `necrotic_corruption >= 100` | 污染完成不可逆转化，撤离或捕获成果不再足以阻止灾变 |
| 300 | `ending_dragon_slain_at_cost` | `week_gte 10` 且发生 `event_dragon_killed` | 巨龙死亡，但杀龙路径必须同时造成大规模人员、聚落或奥术代价 |
| 200 | `ending_arcane_capture` | `week_gte 10`、`capture_preparation >= 80`、`dragon_exhaustion >= 60`、`necrotic_corruption <= 59` | 魔法工会完成非致命束缚并取得巨龙控制权 |
| 100 | `ending_mass_evacuation` | `week_gte 10` 且 `villagers_evacuated >= 70` | 大部分居民脱离直接威胁；巨龙仍然存活，可能离开或继续被地区势力牵制 |

高优先级表示更不可逆、更能覆盖同周其他成果。污染灾变覆盖杀龙、捕获与撤离；巨龙死亡覆盖同周刚达到的捕获或撤离；活捕覆盖同周达到的撤离。

任何可能创建 `event_dragon_killed` 的合同结果、阵营行动或世界触发器只能在 `phase_final_window` 生效，并必须同时产生足以支持“地区重创”叙事的高额毁坏或对应灾难事件。`dragon_exhaustion` 只表示可控程度，不能作为巨龙生命值或死亡判定。

### 4.3 第 15 周保底结束

第 15 周边界在应用结局前检查一次 `trigger_last_defense_kills_dragon`。它只在以下条件全部满足时创建 `event_dragon_killed` 与最后防线事件：

- `week_gte 15`。
- 尚未发生 `event_dragon_killed`。
- `necrotic_corruption <= 99`。
- `villagers_evacuated <= 69`。
- 以下至少一项成立：`capture_preparation <= 79`、`dragon_exhaustion <= 59`、`necrotic_corruption >= 60`。

这些条件等价于“前三种非杀龙结局均未成立”。该触发器的 authoring
`priority = 1000`，创建 `event_last_defense`，并使
`settlement_destruction +30`。随后正常结局选择会进入
`ending_dragon_slain_at_cost`，保证对局最迟在第 15 周结束。

### 4.4 可达路径摘要

| 结局 | 主要内容路径 | 预计结束窗口 |
|---|---|---:|
| 大规模撤离 | 侦察道路 → 建立撤离线 → 营救矿村/护送治疗队 → 坚守石桥 → 撤离达到 70 | 10—12 周 |
| 魔法工会活捕 | 定位巢穴 → 收集样本 → 持续削弱巨龙 → 部署束缚塔 → 准备 80、疲劳 60 | 10—13 周 |
| 巨龙被杀 | 晚期高风险行动产生杀龙事件，或第 15 周最后防线强行终结 | 10—15 周 |
| 死灵灾变 | 回收尸体 → 控制或利用污染源 → 设置诱饵 → 推进转化 → 污染达到 100 | 10—14 周 |

这里固定内容路径与目标窗口。代表性每周增量和四条路径已经在 `docs/18_dragon_invasion_problem_and_action_catalog.md` 完成校准。

## 5. 阵营目标树

Task 006 首批 `FactionDefinition.preferred_ideology` 固定如下，顺序为
`L/A/K/P/T`。它表达阵营长期偏好的价值方向，不是阵营关系、声望或当前状态；
Agenda tag 权重仍以 `docs/18_dragon_invasion_problem_and_action_catalog.md`
第 5 节为准。

| faction ID | preferred ideology L/A/K/P/T |
|---|---|
| `faction_free_adventurers` | +4/+1/0/0/-2 |
| `faction_arcane_guild` | +1/+2/+5/+1/+2 |
| `faction_necrotic_collective` | -3/-2/+2/+4/+5 |

### 5.1 自由冒险者联盟

| 字段 | 定义 |
|---|---|
| `final_goal` | 在局势不可逆转前使 `villagers_evacuated >= 70` |
| `success_predicates` | `ending_mass_evacuation`；若居民已经大规模撤离，也可把安全活捕视为可接受的次优结果 |
| `blockers` | 死灵灾变；撤离线相关问题连续恶化；过高毁坏使尚未撤离的居民失去安全路径 |
| `preferred_clock_directions` | 强烈提高撤离；抑制毁坏与污染；可以有限提高巨龙疲劳；不主动追求捕获准备 |
| `problem_interests` | 优先处理道路、平民撤离、战地医疗和矿村问题 |
| `contract_roles` | 把高风险侦察、护送、救援、守线和集中撤离交给玩家公会 |
| `direct_action_roles` | 玩家不介入时进行规模较小、代价更高的撤离、增援与营地稳定行动 |

小目标链：

| small goal | 完成事实 | 主要合同连接 | 对后续的作用 |
|---|---|---|---|
| `free_secure_routes` | 获得可用路线事件 | `contract_scout_eastern_road` | 降低后续撤离压力并开放集中撤离路径 |
| `free_rescue_isolated` | 矿村获救、医疗队抵达或相应问题被解决 | `contract_rescue_mining_village`、`contract_escort_field_healers` | 增加可撤离人口并降低伤亡与污染来源 |
| `free_hold_corridor` | 撤离桥梁与道路在关键周保持可用 | `contract_hold_stone_bridge` | 为连续撤离创造时间，并有限消耗巨龙力量 |
| `free_complete_evacuation` | `villagers_evacuated >= 70` | `contract_north_road_evacuation` 及可重复救援方向 | 达成阵营最终目标与撤离结局 |

### 5.2 魔法工会

| 字段 | 定义 |
|---|---|
| `final_goal` | 在巨龙存活且污染可控时完成活捕 |
| `success_predicates` | `capture_preparation >= 80`、`dragon_exhaustion >= 60`、`necrotic_corruption <= 59`，最终进入 `ending_arcane_capture` |
| `blockers` | `event_dragon_killed`；污染达到 60 后封锁安全束缚窗口；巢穴与捕获窗口问题恶化 |
| `preferred_clock_directions` | 强烈提高捕获准备和巨龙疲劳；压低污染；容忍有限毁坏但不追求毁坏 |
| `problem_interests` | 优先处理巨龙位置、捕获窗口和死灵污染问题 |
| `contract_roles` | 把危险侦察、样本采集、反仪式和束缚设施部署交给玩家公会 |
| `direct_action_roles` | 玩家不介入时进行较低效率的追踪、样本获取、结界与部分设施建设 |

小目标链：

| small goal | 完成事实 | 主要合同连接 | 对后续的作用 |
|---|---|---|---|
| `arcane_locate_target` | 发生巨龙巢穴定位事件 | `contract_locate_dragon_lair` | 允许捕获窗口和后续研究内容出现 |
| `arcane_calibrate_binding` | `capture_preparation >= 30` | `contract_collect_dragon_scales` | 证明束缚参数可用并开放设施部署方向 |
| `arcane_contain_corruption` | 污染保持在 60 以下，并解决关键污染问题 | `contract_disrupt_necrotic_ritual` | 防止捕获结局被污染封锁；魔法工会还可自行设置污染结界 |
| `arcane_complete_capture` | 准备达到 80 且疲劳达到 60 | `contract_deploy_binding_towers` 及相关直接行动 | 达成安全活捕结局 |

### 5.3 死灵集团

| 字段 | 定义 |
|---|---|
| `final_goal` | 把战场尸体、龙血和聚落损失转化为不可逆死灵灾变 |
| `success_predicates` | `necrotic_corruption >= 100`，最终进入 `ending_necrotic_catastrophe` |
| `blockers` | 尸体被净化；污染源被破坏；玩家持续选择撤离与反仪式；安全活捕提前结束局势 |
| `preferred_clock_directions` | 强烈提高污染；利用毁坏制造材料；通过诱饵提高巨龙疲劳；不追求安全撤离或正规捕获 |
| `problem_interests` | 利用战场尸体、巨龙袭击和污染扩散问题，并阻止这些问题被无害化关闭 |
| `contract_roles` | 用高报酬和保密条款让玩家承担尸体回收、诱饵布置以及受控污染源处理 |
| `direct_action_roles` | 玩家不介入时自行回收尸体、播种共振和采用更粗暴的诱饵方案 |

小目标链：

| small goal | 完成事实 | 主要合同连接 | 对后续的作用 |
|---|---|---|---|
| `necrotic_secure_material` | 尸体或龙血样本被死灵集团取得 | `contract_recover_intact_corpses` | 提供基础污染与转化材料 |
| `necrotic_control_source` | 污染源被集团掌握而非销毁 | `contract_investigate_necrotic_source` | 形成第三条玩家可见推进路径，避免只重复两份赚钱合同 |
| `necrotic_shape_battlefield` | 巨龙被引向预设战场且产生新的毁坏与尸体 | `contract_prepare_dragon_bait` | 同时推进疲劳、毁坏和污染 |
| `necrotic_complete_conversion` | `necrotic_corruption >= 100` | 反复合同结果、问题恶化和直接行动共同推进 | 达成阵营最终目标与灾变结局 |

`contract_investigate_necrotic_source` 已改由死灵集团提出并重写为“控制失控的死灵污染源”：成功避免一次更大的无序扩散，但仍把核心交给死灵集团并提高污染。

### 5.4 阵营方向关系

| 内容方向 | 自由联盟 | 魔法工会 | 死灵集团 |
|---|---|---|---|
| 提高撤离 | 核心目标 | 可接受但非核心 | 妨碍材料积累 |
| 提高巨龙疲劳 | 有限支持 | 核心前置 | 诱饵计划也会利用 |
| 提高捕获准备 | 中立 | 核心目标 | 反对安全活捕 |
| 提高毁坏 | 反对 | 容忍有限代价 | 利用 |
| 提高污染 | 强烈反对 | 强烈反对 | 核心目标 |

这张表只定义内容效果方向，不创建 NPC 阵营关系、立场矩阵、谈判或行动冲突规则。

## 6. 五条进度钟

所有钟的合法范围固定为 `0..100`，应用每一批合并效果后统一裁剪。`visibility = player`。玩家看到整数、语义等级和最多两个主要变化原因。

### 6.1 ClockDefinition 总表

| clock ID | initial | passive/week | 正向含义 | 危险或抑制方向 |
|---|---:|---:|---|---|
| `villagers_evacuated` | 5 | 0 | 已经安全离开直接威胁区的居民比例 | 不允许下降；道路与医疗恶化通过阻止后续增长表达 |
| `settlement_destruction` | 10 | +4 | 聚落、道路、物资和公共设施的累计不可逆毁坏 | 不允许下降；稳健行动和保护条款只能减少新增量 |
| `dragon_exhaustion` | 15 | -2 | 巨龙当前被压制、受扰和可被控制的程度 | 自然恢复会降低；它不是生命值，不直接表示受伤或死亡 |
| `capture_preparation` | 0 | 0 | 定位情报、样本校准和束缚设施的综合完成度 | 一般保留，但捕获窗口恶化或设施毁坏可以降低 |
| `necrotic_corruption` | 5 | +2 | 尸体、龙血、禁术和奥术残留造成的地区污染 | 可被净化与反仪式降低，但不会自然恢复 |

### 6.2 `villagers_evacuated`

- 语义：不是单次合同救出人数，而是全地区已经抵达安全区、不会再次进入当前危机的人口比例。
- 主要玩家来源：`contract_north_road_evacuation`、`contract_hold_stone_bridge`、`contract_escort_field_healers`、`contract_rescue_mining_village`。
- 主要 NPC 来源：自由联盟的小规模撤离、增援和搜救行动；精确行动表见 `docs/18_dragon_invasion_problem_and_action_catalog.md`。
- 问题恶化：不直接扣减已经撤离的人口，而是关闭路线、提高后续任务压力或减少未来可获得的撤离增量。
- 关键阈值：15 创建持续撤离压力入口；40 表示主要撤离线已经形成；70 满足大规模撤离结局。
- 玩家解释：`0—14` 零散逃离，`15—39` 有组织撤离，`40—69` 主要人群转移中，`70—100` 大规模撤离完成。
- 被动 ReasonEntry：无；初值使用 `clock_initial_partial_evacuation`。

### 6.3 `settlement_destruction`

- 语义：累计且不可逆的聚落、交通、物资和民用设施损失，不等同于平民死亡数。
- 主要玩家来源：合同失败、激进行动、附带损失与高代价成功；几乎所有现场合同都可能产生少量毁坏。
- 主要 NPC 来源：粗放撤离、诱饵、部分束缚设施和战线行动。
- 问题恶化来源：道路失守、矿村覆灭、医疗崩溃、捕获窗口破裂和龙袭无人处理。
- 抑制方式：稳健倾向、保护能力、附带损失条款和成功侦察只减少本次新增量，不允许负向修改累计毁坏。
- 关键阈值：18 允许矿村危机进入问题图；30 允许医疗崩溃；70 创建一次 `event_humanitarian_collapse` 并显著提高救援类问题紧迫度，但不新增第五种结局。
- 玩家解释：`0—17` 局部损伤，`18—29` 多处失联，`30—69` 基础设施崩溃，`70—100` 地区性人道灾难。
- 被动 ReasonEntry：每周 `+4`，reason code 为 `clock_passive_dragon_raids`。

### 6.4 `dragon_exhaustion`

- 语义：巨龙因持续追击、诱导、战斗和束缚尝试而下降的机动性与反抗能力。
- 主要玩家来源：坚守防线、鳞片采集、束缚塔部署、诱饵以及少量撤离掩护结果。
- 主要 NPC 来源：魔法工会的追踪与压制、自由联盟的防线行动、死灵集团的诱饵行动。
- 问题恶化来源：捕获窗口丢失或队伍严重失败可以使巨龙获得休整，从而降低该钟。
- 抑制方向：每周自然恢复 `-2`；失败撤退和错失捕获窗口可以产生额外负值。
- 关键阈值：25 与巢穴定位事件共同开放捕获窗口；60 是安全活捕的必要条件。
- 玩家解释：`0—24` 活跃且难以接近，`25—59` 已被牵制，`60—79` 可进入束缚窗口，`80—100` 极度疲劳但仍然存活。
- 被动 ReasonEntry：每周 `-2`，reason code 为 `clock_passive_dragon_recovery`。

### 6.5 `capture_preparation`

- 语义：魔法工会掌握的定位情报、样本参数、仪式校准和束缚设施的合并准备度，不单独拆成多个子资源。
- 主要玩家来源：`contract_locate_dragon_lair`、`contract_collect_dragon_scales`、`contract_deploy_binding_towers`。
- 主要 NPC 来源：魔法工会的低效率定位、样本收集、结界和部分设施部署。
- 问题恶化来源：巨龙迁移、捕获窗口关闭和束缚设施毁坏可以降低准备度。
- 抑制方向：没有自然衰减；只有明确的世界事件或问题恶化可以降低。
- 关键阈值：30 表示定位与校准基础完成；60 开放最终束缚部署内容；80 与巨龙疲劳、污染条件共同满足活捕结局。
- 玩家解释：`0—29` 理论与追踪，`30—59` 参数已校准，`60—79` 束缚网络部署中，`80—100` 捕获准备完成。
- 被动 ReasonEntry：无；初值使用 `clock_initial_no_capture_progress`。

### 6.6 `necrotic_corruption`

- 语义：地区环境、尸体和奥术残留被死灵能量侵蚀的综合程度，不等同于死灵集团声望或资源。
- 主要玩家来源：回收尸体、设置诱饵、使用禁术、遗弃伤员和污染控制失败。
- 主要 NPC 来源：死灵集团的尸体回收、共振播种和粗暴诱饵行动。
- 问题恶化来源：战场尸体无人处理、矿村覆灭、医疗崩溃和死灵仪式未被阻止。
- 抑制方式：污染调查、反仪式、净化结果和少数高质量撤离结果；负向效果表示消除尚未固化的污染。
- 关键阈值：25 创建死灵污染扩散问题；60 阻止安全活捕；100 在第 10 周以后触发死灵灾变结局。
- 玩家解释：`0—24` 零散残留，`25—59` 污染扩散，`60—99` 转化临界，`100` 不可逆灾变。
- 被动 ReasonEntry：每周 `+2`，reason code 为 `clock_passive_necrotic_seepage`。

### 6.7 通用变化原因

除三项固定被动原因外，所有内容使用以下来源 reason code 前缀，并在 metadata 中保存具体定义 ID：

- `clock_contract_result`：玩家合同阶段或最终结果。
- `clock_faction_action`：已结算的阵营直接行动或 NPC 完成。
- `clock_problem_escalation`：世界问题期限或未处理合同复用的恶化效果。
- `clock_situation_trigger`：跨钟阈值触发器。
- `clock_value_clamped`：合并后超出 `0..100`，只用于 debug 原因。

### 6.8 跨钟与阈值引用

| 条件 | 结果 | 定案位置 |
|---|---|---|
| `villagers_evacuated >= 15` | 允许创建平民撤离线压力问题 | 文档18问题目录 |
| `settlement_destruction >= 18` | 允许创建矿村失联问题 | 文档18问题目录 |
| `settlement_destruction >= 30` | 允许创建战地医疗崩溃问题 | 文档18问题目录 |
| `settlement_destruction >= 70` | 创建一次人道崩溃事件并提高救援问题紧迫度 | 文档18问题目录 |
| 巢穴已定位且 `dragon_exhaustion >= 25` | 创建巨龙捕获窗口问题 | 文档18问题目录 |
| `capture_preparation >= 30` | 完成捕获校准小目标 | 文档09合同目录 |
| `capture_preparation >= 60` | 开放最终束缚部署内容 | 文档09合同目录 |
| `necrotic_corruption >= 25` | 创建死灵污染扩散问题 | 文档18问题目录 |
| `necrotic_corruption >= 60` | 安全活捕条件失效 | 本文结局定义 |
| `villagers_evacuated >= 70` | 撤离结局候选 | 本文结局定义 |
| 准备 `>=80`、疲劳 `>=60`、污染 `<=59` | 活捕结局候选 | 本文结局定义 |
| `necrotic_corruption >= 100` | 死灵灾变结局候选 | 本文结局定义 |

## 7. 已完成的下游约束

- 九个问题的紧迫度、期限、解决与恶化已经定案，三个开局问题保持不变。
- 三个阵营的行动表覆盖各自小目标，并使用现有 influence 和 target lock 规则。
- 十二份合同的代表性世界增量已经校准，四条结局路径可在目标周数到达，合同总数保持十二。
- 死灵集团获得第三条玩家可见路径：控制失控污染源。
- 束缚塔合同已限制到 `phase_final_window`，其 `target_killed` 映射为 `event_dragon_killed`。
- 任何后续数值若导致毁坏下降、撤离人口下降、疲劳被当作生命值，或在污染达到 60 以上时仍能安全活捕，均视为内容错误。
